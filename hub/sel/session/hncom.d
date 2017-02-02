/*
 * Copyright (c) 2016-2017 SEL
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 * 
 */
/**
 * Hncom (hub-node communication) is the protocol used by SEL to
 * exchange informations between the hub and the connected nodes.
 * 
 * License: $(HTTP www.gnu.org/licenses/lgpl-3.0.html, GNU General Lesser Public License v3).
 * 
 * Source: $(HTTP www.github.com/sel-project/sel-server/blob/master/hub/sel/network/rcon.d, sel/network/rcon.d)
 */
module sel.session.hncom;

import core.thread : Thread;

import std.algorithm : canFind;
import std.bitmanip : nativeToLittleEndian;
import std.conv : to;
import std.datetime : dur;
import std.json : JSONValue;
import std.math : round;
import std.regex : ctRegex, matchFirst;
import std.socket;
import std.string;
import std.system : Endian;

import common.sel;
import common.util.lang : translate;
import common.util.time : microseconds;

import sel.constants;
import sel.server : Server, List;
import sel.settings;
import sel.network.handler : HandlerThread;
import sel.network.session : Session;
import sel.network.socket;
import sel.session.player : PlayerSession, Skin;
import sel.util.log : log;
import sel.util.thread : SafeThread;

mixin("import Types = sul.protocol.hncom" ~ Software.hncom.to!string ~ ".types;");
mixin("import Login = sul.protocol.hncom" ~ Software.hncom.to!string ~ ".login;");
mixin("import Status = sul.protocol.hncom" ~ Software.hncom.to!string ~ ".status;");
mixin("import Generic = sul.protocol.hncom" ~ Software.hncom.to!string ~ ".generic;");
mixin("import Player = sul.protocol.hncom" ~ Software.hncom.to!string ~ ".player;");

class HncomHandler : HandlerThread {
	
	private shared string* socialJson;

	private immutable ushort pocketPort, minecraftPort;

	private shared Address address;

	version(Posix) private shared string unixSocketAddress;
	
	public this(shared Server server, shared string* socialJson, ushort pocketPort, ushort minecraftPort) {
		version(OneNode) {
			string ip = "::1";
		} else {
			string ip = "::";
			string[] nodes = cast(string[])server.settings.acceptedNodesRaw;
			if(nodes.length) {
				if(nodes.length == 1) {
					if(nodes[0] == "::1") ip = "::1";
					else if(nodes[0].startsWith("127.0.")) ip = "127.0.0.1";
					else if(nodes[0].startsWith("192.168.") && !nodes[0].canFind('-') && (!nodes[0].canFind('*') || nodes[0].indexOf("*") < nodes[0].lastIndexOf("."))) ip = nodes[0][0..nodes[0].lastIndexOf(".")] ~ ".255";
				}
				if(ip == "::") {
					ip = "0.0.0.0";
					foreach(range ; server.settings.acceptedNodes) {
						if(range.addressFamily != AddressFamily.INET) {
							ip = "::";
							break;
						}
					}
				}
			}
		}
		Socket socket = null;
		version(Posix) {
			if(server.settings.hncomUseUnixSockets && (ip == "127.0.0.1" || ip == "::1")) {
				this.unixSocketAddress = server.settings.hncomUnixSocketAddress;
				socket = new BlockingSocket!UnixSocket(new UnixAddress(this.unixSocketAddress));
			}
		}
		if(socket is null) socket = new BlockingSocket!TcpSocket(ip, server.settings.hncomPort, 8);
		this.address = cast(shared)socket.localAddress;
		super(server, [cast(shared)socket]);
		this.socialJson = socialJson;
		this.pocketPort = pocketPort;
		this.minecraftPort = minecraftPort;
	}
	
	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			Socket client = socket.accept();
			Address address;
			try {
				address = client.remoteAddress;
			} catch(Exception) {
				version(OneNode) {
					this.server.shutdown();
					return;
				} else {
					continue;
				}
			}
			if(this.server.acceptNode(address)) {
				new SafeThread({
					shared Node node = new shared Node(this.server, client, *this.socialJson, this.pocketPort, this.minecraftPort);
					delete node;
				}).start();
			} else {
				client.close();
			}
		}
	}

	public shared pure nothrow @property @safe @nogc shared(Address) localAddress() {
		return this.address;
	}
	
	public override shared void shutdown() {
		foreach(shared Socket sharedSocket ; this.sharedSockets) {
			Socket socket = cast()sharedSocket;
			socket.close();
			version(Posix) {
				if(this.unixSocketAddress.length) {
					//TODO close the socket without exceptions
					import core.stdc.stdio : remove;
					import std.internal.cstring : tempCString;
					remove(this.unixSocketAddress.tempCString());
				}
			}
		}
	}
	
}

/**
 * Session of a node. It's executed in a dedicated thread.
 */
class Node : Session {
	
	public static Types.Address hncomAddress(Address address) {
		Types.Address ret;
		if(cast(InternetAddress)address) {
			auto v4 = cast(InternetAddress)address;
			ret.bytes.length = 4;
			ret.bytes[0] = (v4.addr >> 24) & 255;
			ret.bytes[1] = (v4.addr >> 16) & 255;
			ret.bytes[2] = (v4.addr >> 8) & 255;
			ret.bytes[3] = v4.addr & 255;
			ret.port = v4.port;
		} else if(cast(Internet6Address)address) {
			auto v6 = cast(Internet6Address)address;
			ubyte[16] bytes = v6.addr;
			if(bytes[10] == 255 && bytes[11] == 255) {
				ret.bytes = bytes[12..16];
			} else {
				ret.bytes = bytes;
			}
			ret.port = v6.port;
		}
		return ret;
	}

	public static Types.Skin hncomSkin(Skin skin) {
		if(skin is null) {
			return Types.Skin.init;
		} else {
			return Types.Skin(skin.name, skin.data);
		}
	}
	
	private shared Socket socket;
	private immutable string remoteAddress;

	private shared bool n_main;
	private shared string n_name;

	private shared uint[][ubyte] accepted;

	private shared uint n_max;
	public shared Types.Plugin[] plugins;
	
	private shared PlayerSession[immutable(uint)] players;

	private uint n_latency;

	private shared float n_tps;
	private shared ulong n_ram;
	private shared float n_cpu;
	
	public shared this(shared Server server, Socket socket, string social, ushort pocket_port, ushort minecraft_port) {
		super(server);
		if(Thread.getThis().name == "") Thread.getThis().name = "nodeSession#" ~ to!string(this.id);
		this.socket = cast(shared)socket;
		this.remoteAddress = socket.remoteAddress.toString();
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(2500));
		auto receiver = new Receiver!(uint, Endian.littleEndian)();
		ubyte[] buffer = new ubyte[256];
		auto recv = socket.receive(buffer);
		if(recv > 0) {
			this.server.traffic.receive(recv);
			receiver.add(buffer[0..recv]);
		}
		if(receiver.has) {
			ubyte[] payload = receiver.next;
			if(payload.length && payload[0] == Login.ConnectionRequest.ID) {
				immutable password = server.settings.nodesPassword;
				auto request = Login.ConnectionRequest.fromBuffer(payload);
				this.n_name = request.name.idup;
				this.n_main = request.main;
				auto response = new Login.ConnectionResponse(Software.hncom, Login.ConnectionResponse.OK);
				if(request.protocol > Software.hncom) response.status = Login.ConnectionResponse.OUTDATED_HUB;
				else if(request.protocol < Software.hncom) response.status = Login.ConnectionResponse.OUTDATED_NODE;
				else if(password.length && !password.length) response.status = Login.ConnectionResponse.PASSWORD_REQUIRED;
				else if(password.length && password != request.password) response.status = Login.ConnectionResponse.WRONG_PASSWORD;
				else if(!this.n_name.length || this.n_name.length > 32) response.status = Login.ConnectionResponse.INVALID_NAME_LENGTH;
				else if(!this.n_name.matchFirst(ctRegex!r"[^a-zA-Z0-9_+-.,!?:@#$%\/]").empty) response.status = Login.ConnectionResponse.INVALID_NAME_CHARACTERS;
				else if(server.nodeNames.canFind(this.n_name)) response.status = Login.ConnectionResponse.NAME_ALREADY_USED;
				else if(["about", "disconnect", "kick", "latency", "nodes", "players", "reload", "say", "stop", "threads", "transfer"].canFind(this.n_name.toLower)) response.status = Login.ConnectionResponse.NAME_RESERVED;
				this.send(response.encode());
				if(response.status == Login.ConnectionResponse.OK) {
					// send info packets
					with(cast()server.settings) {
						Types.GameInfo[] games;
						if(pocket) games ~= Types.GameInfo(Types.Game(Types.Game.POCKET, pocketProtocols), pocketMotd, pocket_port);
						if(minecraft) games ~= Types.GameInfo(Types.Game(Types.Game.MINECRAFT, minecraftProtocols), minecraftMotd, minecraft_port);
						JSONValue[string] additionalJson;
						additionalJson["software"] = ["name": Software.name, "version": Software.displayVersion];
						additionalJson["minecraft"] = ["edu": __edu, "realm": __realm];
						//TODO system info
						this.send(new Login.HubInfo(microseconds, server.id, server.nextPool, displayName, __onlineMode, games, server.onlinePlayers, maxPlayers, language, acceptedLanguages, social, JSONValue(additionalJson).toString()).encode());
					}
					socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"minutes"(5)); // giving it the time to load resorces and generates worlds
					while(true) {
						if(receiver.has) {
							payload = receiver.next;
							if(payload.length && payload[0] == Login.NodeInfo.ID) {
								auto info = Login.NodeInfo.fromBuffer(payload);
								this.n_latency = cast(uint)round(to!float(microseconds - info.time) / 1000f);
								this.n_max = info.max;
								foreach(game ; info.acceptedGames) this.accepted[game.type] = cast(shared uint[])game.protocols;
								this.plugins = cast(shared)info.plugins;
								server.add(this);
								foreach(node ; server.nodesList) this.send(node.addPacket.encode());
								this.loop(receiver);
								server.remove(this);
								this.onClosed();
							}
							break;
						} else {
							recv = socket.receive(buffer);
							if(recv > 0) {
								this.server.traffic.receive(recv);
								receiver.add(buffer[0..recv]);
							} else {
								break;
							}
						}
					}
				}
			}
		}
		socket.close();
		version(OneNode) {
			this.server.shutdown();
		}
	}
	
	/**
	 * Gets the name of the node. The name is different for every node
	 * connected to hub and it should be used other nodes with
	 * the transfer function.
	 */
	public shared nothrow @property @safe @nogc const string name() {
		return this.n_name;
	}
	
	/**
	 * Indicates whether or not this is a main node.
	 * A main node is able to receive players without the
	 * use of the transfer function.
	 * Every hub should have at least one main node, otherwise
	 * every player that tries to connect will be disconnected with
	 * the 'end of stream' message.
	 */
	public shared nothrow @property @safe @nogc const bool main() {
		return this.n_main;
	}

	/**
	 * Gets the highest number of players that can connect to the node.
	 */
	public shared nothrow @property @safe @nogc const uint max() {
		return this.n_max;
	}

	/**
	 * Gets the number of players connected to the node.
	 */
	public shared nothrow @property @safe @nogc const uint online() {
		version(X86_64) {
			return cast(uint)this.players.length;
		} else {
			return this.players.length;
		}
	}

	/**
	 * Gets the node's latency (it may not be precise).
	 */
	public shared nothrow @property @safe @nogc const uint latency() {
		return this.n_latency;
	}

	/**
	 * Gets the node's usage, updated with the ResourcesUsage packet.
	 */
	public shared nothrow @property @safe @nogc const float tps() {
		return this.n_tps;
	}

	/// ditto
	public shared nothrow @property @safe @nogc const ulong ram() {
		return this.n_ram;
	}

	/// ditto
	public shared nothrow @property @safe @nogc const float cpu() {
		return this.n_cpu;
	}

	public shared nothrow @property @safe bool accepts(ubyte game, uint protocol) {
		auto p = game in this.accepted;
		return p && (*p).canFind(protocol);
	}

	public shared @property Status.AddNode addPacket() {
		auto packet = new Status.AddNode(this.id, this.name);
		foreach(game, protocols; this.accepted) packet.acceptedGames ~= Types.Game(game, cast(uint[])protocols);
		return packet;
	}
	
	protected shared void loop(Receiver!(uint, Endian.littleEndian) receiver) {
		Socket socket = cast()this.socket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(0)); // blocking without timeout
		ubyte[] buffer = new ubyte[NODE_BUFFER_SIZE];
		while(true) {
			auto recv = socket.receive(buffer);
			if(recv <= 0) break; // closed
			this.server.traffic.receive(recv);
			// stack up
			receiver.add(buffer[0..recv]);
			while(receiver.has) {
				if(receiver.length == 0) {
					// connection is interrupted when the data length is 0!
					log("receiver length is 0 in ", this.toString());
					return;
				}
				ubyte[] payload = receiver.next;
				switch(payload[0]) {
					case Status.ResourcesUsage.ID:
						auto packet = Status.ResourcesUsage.fromBuffer(payload);
						this.n_tps = packet.tps;
						this.n_ram = packet.ram;
						this.n_cpu = packet.cpu;
						break;
					case Generic.Logs.ID:
						this.handleLogs(Generic.Logs.fromBuffer(payload));
						break;
					case Generic.UpdateList.ID:
						this.handleUpdateList(Generic.UpdateList.fromBuffer(payload));
						break;
					case Player.Kick.ID:
						this.handleKickPlayer(Player.Kick.fromBuffer(payload));
						break;
					case Player.Transfer.ID:
						this.handleTransferPlayer(Player.Transfer.fromBuffer(payload));
						break;
					case Player.UpdateLanguage.ID:
						auto ul = Player.UpdateLanguage.fromBuffer(payload);
						auto player = ul.hubId in this.players;
						if(player) {
							(*player).language = ul.language;
						}
						break;
					case Player.UpdateDisplayName.ID:
						auto udn = Player.UpdateDisplayName.fromBuffer(payload);
						auto player = udn.hubId in this.players;
						if(player) {
							(*player).displayName = udn.displayName;
						}
						break;
					case Player.UpdateWorld.ID:
						auto uw = Player.UpdateWorld.fromBuffer(payload);
						auto player = uw.hubId in this.players;
						if(player) {
							(*player).world = uw.world;
							(*player).dimension = uw.dimension;
						}
						break;
					case Player.GamePacket.ID:
						this.handleGamePacket(Player.GamePacket.fromBuffer(payload));
						break;
					case Player.OrderedGamePacket.ID:
						this.handleOrderedGamePacket(Player.OrderedGamePacket.fromBuffer(payload));
						break;
					default:
						log("unknown packet by ", this.toString(), " with id ", payload[0], " (", payload.length, " bytes)");
						return; // closes connection
				}
			}
		}
	}
	
	/**
	 * Logs some messages to the server and the connected
	 * external consoles.
	 */
	private shared void handleLogs(Generic.Logs logs) {
		foreach(l ; logs.messages) {
			this.server.message(this.name, l.timestamp, l.logger, l.message);
		}
	}
	
	/**
	 * Updates a list (whitelist or blacklist), adding or removing
	 * a player by hubId, name or suuid.
	 */
	private shared void handleUpdateList(Generic.UpdateList packet) {
		shared List list = (){
			final switch(packet.list) {
				case Generic.UpdateList.WHITELIST:
					return this.server.whitelist;
				case Generic.UpdateList.BLACKLIST:
					return this.server.blacklist;
			}
		}();
		List.Player player;
		switch(packet.type) {
			case Generic.UpdateList.ByHubId.TYPE:
				auto pk = packet.new ByHubId();
				pk.decode();
				auto ptr = pk.hubId in this.players;
				if(ptr) {
					static if(__onlineMode) player = new List.UniquePlayer((*ptr).game, (*ptr).uuid);
					else player = new List.NamedPlayer((*ptr).username);
				}
				break;
			case Generic.UpdateList.ByName.TYPE:
				auto pk = packet.new ByName();
				pk.decode();
				player = new List.NamedPlayer(pk.username);
				break;
			case Generic.UpdateList.ByUuid.TYPE:
				auto data = packet.new ByUuid();
				data.decode();
				player = new List.UniquePlayer(data.game, data.uuid);
				break;
			default:
				break;
		}
		if(player !is null) {
			switch(packet.action) {
				case Generic.UpdateList.ADD:
					list.add(player);
					break;
				case Generic.UpdateList.REMOVE:
					list.remove(player);
					break;
				default:
					break;
			}
		}
	}
	
	/**
	 * Kicks a player from the server (not just from the node).
	 * 
	 * Usage:
	 * (node) removes player from its list
	 * (node to hub) send KickPlayer packet
	 * (hub) removes from the node's players
	 * (hub) send kick message to client
	 * (hub) closes socket and frees resources
	 * (hub) removes it from the server
	 */
	private shared void handleKickPlayer(Player.Kick packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			this.players.remove(packet.hubId);
			(*player).kick(packet.reason, packet.translation, packet.parameters);
		}
	}
	
	/**
	 * Transfers a player to another node using its name.
	 * This function removes the player if exists and tries to
	 * transfer it to the given node. If the given node doesn't
	 * exist the player will be kicked with 'end of stream' message.
	 * The node already knowns that the player has been removed
	 * from it and the PlayerDisconnected packet is not sent.
	 * 
	 * Usage:
	 * (node) removes player from its list
	 * (node to hub) send TransferPlayer packet
	 * (hub) removes from the node's players
	 * (hub) calls PlayerSession::connect function
	 */
	private shared void handleTransferPlayer(Player.Transfer packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			this.players.remove(packet.hubId);
			(*player).connect(Player.Add.TRANSFERRED, packet.node);
		}
	}
	
	/**
	 * Sends a packet from the node to the target client.
	 */
	private shared void handleGamePacket(Player.GamePacket packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).sendFromNode(packet.packet);
		}
	}

	/// ditto
	private shared void handleOrderedGamePacket(Player.OrderedGamePacket packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).sendOrderedFromNode(packet.order, packet.packet);
		}
	}
	
	/**
	 * Sends a buffer of data, prepending its length as a
	 * little endian 4-bytes unsigned integer.
	 */
	public override shared ptrdiff_t send(const(void)[] buffer) {
		buffer = nativeToLittleEndian(buffer.length.to!uint) ~ buffer;
		immutable length = buffer.length;
		auto socket = cast()this.socket;
		while(true) {
			immutable sent = socket.send(buffer);
			if(sent <= 0 || sent == buffer.length) break;
			buffer = buffer[sent..$];
		}
		this.server.traffic.send(length);
		return length;
	}
	
	/**
	 * Sends data to the node received from a player.
	 */
	public shared void sendTo(shared PlayerSession player, ubyte[] data) {
		this.send(new Player.GamePacket(player.id, data).encode());
	}

	/**
	 * Sends the number of online players and maximum number of
	 * players to the node.
	 */
	public shared void updatePlayers(inout uint online, inout uint max) {
		this.send(new Status.Players(online, max).encode());
	}
	
	/**
	 * Notifies the node that another node has connected
	 * to the hub.
	 */
	public shared void addNode(shared Node node) {
		this.send(node.addPacket.encode());
	}
	
	/**
	 * Notifies the node that another node has been
	 * disconnected from the hub.
	 */
	public shared void removeNode(shared Node node) {
		this.send(new Status.RemoveNode(node.id).encode());
	}
	
	/**
	 * Executes a remote command.
	 */
	public shared void remoteCommand(string command, ubyte origin, Address address) {
		this.send(new Generic.RemoteCommand(origin, hncomAddress(address !is null ? address : (cast()this.socket).localAddress), command).encode());
	}

	/**
	 * Tells the node to reload its configurations.
	 */
	public shared void reload() {
		this.send(new Generic.Reload().encode());
	}
	
	/**
	 * Adds a player to the node.
	 * 
	 * Usage:
	 * (hub) adds player to the node's list
	 * (hub to node) send AddPlayer packet
	 * (node) adds player to its list
	 */
	public shared void addPlayer(shared PlayerSession player, ubyte reason) {
		this.players[player.id] = player;
		auto packet = new Player.Add(player.id, reason, player.type, player.protocol, player.gameVersion, player.username, player.displayName, player.dimension, hncomAddress(player.address), player.serverAddress, player.serverPort, cast()player.uuid, hncomSkin(player.skin), player.latency, player.language);
		this.send(player.encodeHncomAddPacket(packet));
	}
	
	/**
	 * Called when a player is transferred by the hub (not by the node)
	 * to another node.
	 */
	public shared void onPlayerTransferred(shared PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.TRANSFERRED);
	}
	
	/**
	 * Called when a player lefts the server using the disconnect
	 * button or closing the socket.
	 */
	public shared void onPlayerLeft(shared PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.LEFT);
	}
	
	/**
	 * Called when a player times out.
	 */
	public shared void onPlayerTimedOut(shared PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.TIMED_OUT);
	}
	
	/**
	 * Called when a player is kicked (not by the node).
	 */
	public shared void onPlayerKicked(shared PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.KICKED);
	}

	/**
	 * Generic function that removes a player from the
	 * node's list and sends a PlayerDisconnected packet to
	 * notify the node of the disconnection.
	 */
	private shared void onPlayerGone(shared PlayerSession player, ubyte reason) {
		if(this.players.remove(player.id)) {
			this.send(new Player.Remove(player.id, reason).encode());
		}
	}
	
	/**
	 * Updates a player's latency (usually sent every 30 seconds).
	 */
	public shared void sendLatencyUpdate(shared PlayerSession player) {
		this.send(new Player.UpdateLatency(player.id, player.latency).encode());
	}
	
	/**
	 * Updates a player's packet loss (usually sent every 30 seconds).
	 */
	public shared void sendPacketLossUpdate(shared PlayerSession player) {
		this.send(new Player.UpdatePacketLoss(player.id, player.packetLoss).encode());
	}
	
	/**
	 * Called when the client closes the connection.
	 * Tries to transfer every connected player to the main node.
	 */
	public shared void onClosed(bool transfer=true) {
		if(transfer) {
			foreach(shared PlayerSession player ; this.players) {
				player.connect(Player.Add.FORCIBLY_TRANSFERRED);
			}
		} else {
			foreach(shared PlayerSession player ; this.players) {
				player.kick("disconnect.close", true, []);
			}
		}
	}
	
	public shared inout string toString() {
		return "Node(" ~ to!string(this.id) ~ ", " ~ this.name ~ ", " ~ this.remoteAddress ~ ", " ~ to!string(this.n_main) ~ ")";
	}
	
}
