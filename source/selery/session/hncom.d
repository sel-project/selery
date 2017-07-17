/*
 * Copyright (c) 2017 SEL
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
module selery.session.hncom;

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
import std.zlib;

import sel.hncom.about;
import sel.hncom.handler : Handler = HncomHandler;

import selery.about;
import selery.constants;
import selery.hub.server : HubServer, List;
import selery.hub.settings;
import selery.lang : translate;
import selery.network.handler : HandlerThread;
import selery.network.session : Session;
import selery.network.socket;
import selery.session.player : PlayerSession, Skin;
import selery.util.thread : SafeThread;
import selery.util.util : microseconds;
import selery.util.world : WorldSession = World;

import Util = sel.hncom.util;
import Login = sel.hncom.login;
import Status = sel.hncom.status;
import Player = sel.hncom.player;

class HncomHandler : HandlerThread {
	
	private shared JSONValue* additionalJson;

	private shared Address address;

	version(Posix) private shared string unixSocketAddress;
	
	public this(shared HubServer server, shared JSONValue* additionalJson) {
		string ip = "::";
		string[] nodes = cast(string[])server.settings.config.acceptedNodes;
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
		this.additionalJson = additionalJson;
	}
	
	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			Socket client = socket.accept();
			Address address;
			try {
				address = client.remoteAddress;
			} catch(Exception) {
				continue;
			}
			if(this.server.acceptNode(address)) {
				new SafeThread({
					shared ClassicNode node = new shared ClassicNode(this.server, client, this.additionalJson);
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
abstract class AbstractNode : Session, Handler!serverbound {
	
	/+public static Types.Skin hncomSkin(Skin skin) {
		if(skin is null) {
			return Types.Skin.init;
		} else {
			return Types.Skin(skin.name, skin.data);
		}
	}+/

	private shared JSONValue* additionalJson;
	
	private shared bool n_main;
	private shared string n_name;
	
	private shared uint[][ubyte] accepted;
	
	private shared uint n_max;
	public shared Login.NodeInfo.Plugin[] plugins;
	
	private shared PlayerSession[immutable(uint)] players;
	private shared WorldSession[immutable(uint)] worlds;
	
	private uint n_latency;
	
	private shared float n_tps;
	private shared ulong n_ram;
	private shared float n_cpu;
	
	public shared this(shared HubServer server, shared JSONValue* additionalJson) {
		super(server);
		this.additionalJson = additionalJson;
	}

	protected shared void exchageInfo(Receiver!(uint, Endian.littleEndian) receiver) {
		with(cast()server.settings) {
			Login.HubInfo.GameInfo[ubyte] games;
			if(minecraft) games[__JAVA__] = Login.HubInfo.GameInfo(minecraft.motd, minecraft.protocols, minecraft.onlineMode, minecraft.port);
			if(pocket) games[__POCKET__] = Login.HubInfo.GameInfo(pocket.motd, pocket.protocols, pocket.onlineMode, pocket.port);
			this.sendHubInfo(Login.HubInfo(server.id, server.nextPool, displayName, games, server.onlinePlayers, server.maxPlayers, language, acceptedLanguages, cast()*this.additionalJson));
		}
		auto info = this.receiveNodeInfo(receiver);
		this.n_max = info.max;
		this.accepted = cast(shared uint[][ubyte])info.acceptedGames;
		this.plugins = cast(shared)info.plugins;
		foreach(node ; server.nodesList) this.send(node.addPacket.encode());
		server.add(this);
		this.loop(receiver);
		server.remove(this);
		this.onClosed();
	}

	protected abstract shared void sendHubInfo(Login.HubInfo packet);

	protected abstract shared Login.NodeInfo receiveNodeInfo(Receiver!(uint, Endian.littleEndian) receiver);

	protected abstract shared void loop(Receiver!(uint, Endian.littleEndian) receiver);

	public override abstract shared ptrdiff_t send(const(void)[] buffer);

	protected final ptrdiff_t send(const(void)[] buffer) {
		return (cast(shared)this).send(buffer);
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
	 * Indicates whether the node is full.
	 */
	public shared nothrow @property @safe @nogc const bool full() {
		return this.max != Login.NodeInfo.UNLIMITED && this.online >= this.max;
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
		return Status.AddNode(this.id, this.name, this.main, cast(uint[][ubyte])this.accepted);
	}

	protected override void handleUtilUncompressed(Util.Uncompressed packet) {
		assert(packet.id == 0); //TODO
		foreach(p ; packet.packets) {
			if(p.length) this.handleHncom(p.dup);
		}
	}
	
	protected override void handleUtilCompressed(Util.Compressed packet) {
		this.handleUtilUncompressed(packet.uncompress());
	}

	protected override void handleStatusLatency(Status.Latency packet) {
		this.send(packet.encode());
	}

	protected override void handleStatusLog(Status.Log packet) {
		string name = packet.logger;
		if(packet.worldId != -1) {
			auto world = packet.worldId in this.worlds;
			if(world) name = world.name;
		}
		this.server.message((cast(shared)this).name, packet.timestamp, name, packet.message, packet.commandId);
	}

	protected override void handleStatusSendMessage(Status.SendMessage packet) {
		if(packet.addressees.length) {
			foreach(addressee ; packet.addressees) {
				auto node = this.server.nodeById(addressee);
				if(node !is null) node.sendMessage(this.id, false, packet.payload);
			}
		} else {
			foreach(node ; this.server.nodesList) {
				if(node.id != this.id) node.sendMessage(this.id, true, packet.payload);
			}
		}
	}

	protected override void handleStatusUpdateUsage(Status.UpdateUsage packet) {
		this.n_ram = (cast(ulong)packet.ram) * 1024Lu;
		this.n_cpu = packet.cpu;
	}

	protected override void handleStatusAddWorld(Status.AddWorld packet) {
		auto world = new shared WorldSession(packet.worldId, packet.name, packet.dimension);
		if(packet.parent != -1) {
			auto parent = packet.parent in this.worlds;
			if(parent) world.parent = *parent;
		}
		this.worlds[packet.worldId] = world;
	}

	protected override void handleStatusRemoveWorld(Status.RemoveWorld packet) {
		this.worlds.remove(packet.worldId);
	}

	protected override void handleStatusUpdateList(Status.UpdateList packet) {} //TODO

	/+private shared void handleUpdateList(Status.UpdateList packet) {
		shared List list = (){
			final switch(packet.list) {
				case Status.UpdateList.WHITELIST:
					return this.server.whitelist;
				case Status.UpdateList.BLACKLIST:
					return this.server.blacklist;
			}
		}();
		List.Player player;
		switch(packet.type) {
			case Status.UpdateList.ByHubId.TYPE:
				auto pk = packet.new ByHubId();
				pk.decode();
				auto ptr = pk.hubId in this.players;
				if(ptr) {
					/*static if(__onlineMode) player = new List.UniquePlayer((*ptr).game, (*ptr).uuid);
					else*/ player = new List.NamedPlayer((*ptr).username);
				}
				break;
			case Status.UpdateList.ByName.TYPE:
				auto pk = packet.new ByName();
				pk.decode();
				player = new List.NamedPlayer(pk.username);
				break;
			case Status.UpdateList.ByUuid.TYPE:
				auto data = packet.new ByUuid();
				data.decode();
				player = new List.UniquePlayer(data.game, data.uuid);
				break;
			default:
				break;
		}
		if(player !is null) {
			switch(packet.action) {
				case Status.UpdateList.ADD:
					list.add(player);
					break;
				case Status.UpdateList.REMOVE:
					list.remove(player);
					break;
				default:
					break;
			}
		}
	}+/

	protected override void handlePlayerKick(Player.Kick packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			this.players.remove(packet.hubId);
			(*player).kick(packet.reason, packet.translation, packet.parameters);
		}
	}

	protected override void handlePlayerTransfer(Player.Transfer packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			this.players.remove(packet.hubId);
			(*player).connect(Player.Add.TRANSFERRED, packet.node, packet.onFail);
		}
	}

	protected override void handlePlayerUpdateDisplayName(Player.UpdateDisplayName packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).displayName = packet.displayName;
		}
	}

	protected override void handlePlayerUpdateWorld(Player.UpdateWorld packet) {
		auto player = packet.hubId in this.players;
		auto world = packet.worldId in this.worlds;
		if(player && world) {
			(*player).world = *world;
		}
	}

	protected override void handlePlayerUpdateViewDistance(Player.UpdateViewDistance packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).viewDistance = packet.viewDistance;
		}
	}

	protected override void handlePlayerUpdateLanguage(Player.UpdateLanguage packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).language = packet.language;
		}
	}

	protected override void handlePlayerGamePacket(Player.GamePacket packet) {
		//TODO compress if needed and send
	}

	protected override void handlePlayerSerializedGamePacket(Player.SerializedGamePacket packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).sendFromNode(packet.payload);
		}
	}

	protected override void handlePlayerOrderedGamePacket(Player.OrderedGamePacket packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).sendOrderedFromNode(packet.order, packet.payload);
		}
	}
	
	/**
	 * Sends data to the node received from a player.
	 */
	public shared void sendTo(shared PlayerSession player, ubyte[] data) {
		this.send(Player.GamePacket(player.id, data).encode());
	}
	
	/**
	 * Notifies the node that another node has connected
	 * to the hub.
	 */
	public shared void addNode(shared AbstractNode node) {
		this.send(node.addPacket.encode());
	}
	
	/**
	 * Notifies the node that another node has been
	 * disconnected from the hub.
	 */
	public shared void removeNode(shared AbstractNode node) {
		this.send(Status.RemoveNode(node.id).encode());
	}
	
	/**
	 * Sends a message to the node.
	 */
	public shared void sendMessage(uint sender, bool broadcasted, ubyte[] payload) {
		this.send(Status.ReceiveMessage(sender, broadcasted, payload).encode());
	}
	
	/**
	 * Sends the number of online players and maximum number of
	 * players to the node.
	 */
	public shared void updatePlayers(inout uint online, inout uint max) {
		this.send(Status.UpdatePlayers(online, max).encode());
	}
	
	/**
	 * Executes a remote command.
	 */
	public shared void remoteCommand(string command, ubyte origin, Address address, int commandId);
	
	/**
	 * Tells the node to reload its configurations.
	 */
	public shared void reload() {
		with(this.server.settings) {
			string[ubyte] motds;
			if(minecraft) motds[__JAVA__] = minecraft.motd;
			if(pocket) motds[__POCKET__] = pocket.motd;
			this.send(Status.Reload(cast(string)displayName, motds, cast(string)language, cast(string[])acceptedLanguages, cast()*this.additionalJson).encode());
		}
	}
	
	/**
	 * Adds a player to the node.
	 */
	public shared void addPlayer(shared PlayerSession player, ubyte reason) {
		this.players[player.id] = player;
		this.send(Player.Add(player.id, reason, player.type, player.protocol, player.gameVersion, player.uuid, player.username, player.displayName, player.dimension, player.viewDistance, player.address, Player.Add.ServerAddress(player.serverAddress, player.serverPort), Player.Add.Skin(player.skin.name, player.skin.data), player.language, player.hncomAddData()).encode());
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
	protected shared void onPlayerGone(shared PlayerSession player, ubyte reason) {
		if(this.players.remove(player.id)) {
			this.send(Player.Remove(player.id, reason).encode());
		}
	}
	
	/**
	 * Updates a player's latency (usually sent every 30 seconds).
	 */
	public shared void sendLatencyUpdate(shared PlayerSession player) {
		this.send(Player.UpdateLatency(player.id, player.latency).encode());
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
	
	public abstract shared inout string toString();
	
}

class ClassicNode : AbstractNode {

	private shared Socket socket;
	private immutable string remoteAddress;

	public shared this(shared HubServer server, Socket socket, shared JSONValue* additionalJson) {
		super(server, additionalJson);
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
				immutable password = server.settings.hncomPassword;
				auto request = Login.ConnectionRequest.fromBuffer(payload);
				this.n_name = request.name.idup;
				this.n_main = request.main;
				Login.ConnectionResponse response;
				if(request.protocol > __PROTOCOL__) response.status = Login.ConnectionResponse.OUTDATED_HUB;
				else if(request.protocol < __PROTOCOL__) response.status = Login.ConnectionResponse.OUTDATED_NODE;
				else if(password.length && !password.length) response.status = Login.ConnectionResponse.PASSWORD_REQUIRED;
				else if(password.length && password != request.password) response.status = Login.ConnectionResponse.WRONG_PASSWORD;
				else if(!this.n_name.length || this.n_name.length > 32) response.status = Login.ConnectionResponse.INVALID_NAME_LENGTH;
				else if(!this.n_name.matchFirst(ctRegex!r"[^a-zA-Z0-9_+-.,!?:@#$%\/]").empty) response.status = Login.ConnectionResponse.INVALID_NAME_CHARACTERS;
				else if(server.nodeNames.canFind(this.n_name)) response.status = Login.ConnectionResponse.NAME_ALREADY_USED;
				else if(["threads", "usage"].canFind(this.n_name.toLower)) response.status = Login.ConnectionResponse.NAME_RESERVED;
				this.send(response.encode());
				if(response.status == Login.ConnectionResponse.OK) {
					this.exchageInfo(receiver);
				}
			}
		}
		socket.close();
	}

	protected override shared void sendHubInfo(Login.HubInfo packet) {
		this.send(packet.encode());
	}

	protected override shared Login.NodeInfo receiveNodeInfo(Receiver!(uint, Endian.littleEndian) receiver) {
		Socket socket = cast()this.socket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"minutes"(5)); // giving it the time to load resorces and generate worlds
		ubyte[] buffer = new ubyte[512];
		while(true) {
			if(receiver.has) {
				ubyte[] payload = receiver.next;
				if(payload.length && payload[0] == Login.NodeInfo.ID) {
					return Login.NodeInfo.fromBuffer(payload);
				}
			} else {
				auto recv = socket.receive(buffer);
				if(recv > 0) {
					this.server.traffic.receive(recv);
					receiver.add(buffer[0..recv]);
				} else {
					throw new Exception("Connection closed during exchange of informations");
				}
			}
		}
	}

	protected override shared void loop(Receiver!(uint, Endian.littleEndian) receiver) {
		auto _this = cast()this;
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
					return;
				}
				_this.handleHncom(receiver.next);
			}
		}
	}

	public override shared ptrdiff_t send(const(void)[] buffer) {
		buffer = nativeToLittleEndian(buffer.length.to!uint) ~ buffer;
		immutable length = buffer.length;
		Socket socket = cast()this.socket;
		while(true) {
			immutable sent = socket.send(buffer);
			if(sent <= 0 || sent == buffer.length) break;
			buffer = buffer[sent..$];
		}
		this.server.traffic.send(length);
		return length;
	}
	
	public override shared inout string toString() {
		return "Node(" ~ to!string(this.id) ~ ", " ~ this.name ~ ", " ~ this.remoteAddress ~ ", " ~ to!string(this.n_main) ~ ")";
	}

}

class LiteNode : AbstractNode {

	static import std.concurrency;
	
	public shared static bool ready = false;
	public shared static std.concurrency.Tid tid;
	
	private std.concurrency.Tid node;

	public shared this(shared HubServer server, shared JSONValue* additionalJson) {
		super(server, additionalJson);
		ready = true;
		this.node = cast(shared)std.concurrency.receiveOnly!(std.concurrency.Tid)();
		this.n_main = true;
		this.exchageInfo(null);
	}

	protected override shared void sendHubInfo(Login.HubInfo packet) {
		std.concurrency.send(cast()this.node, cast(shared)packet);
	}

	protected override shared Login.NodeInfo receiveNodeInfo(Receiver!(uint, Endian.littleEndian) receiver) {
		return cast()std.concurrency.receiveOnly!(shared Login.NodeInfo)();
	}

	protected override shared void loop(Receiver!(uint, Endian.littleEndian) receiver) {
		auto _this = cast()this;
		while(true) {
			ubyte[] payload = std.concurrency.receiveOnly!(immutable(ubyte)[])().dup;
			if(payload.length) {
				_this.handleHncom(payload);
			} else {
				break;
			}
		}
	}

	public override shared ptrdiff_t send(const(void)[] buffer) {
		std.concurrency.send(cast()this.node, buffer.idup);
		return buffer.length;
	}
	
	public override shared inout string toString() {
		return "LiteNode(" ~ to!string(this.id) ~ ")";
	}
	
}

/**
 * Session of a node. It's executed in a dedicated thread.
 */
/+class Node(bool lite) : AbstractNode {
	
	protected override shared void loop(Receiver!(uint, Endian.littleEndian) receiver) {
		static if(lite) {

		} else {
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
						return;
					}
					(cast()this).handleHncom(receiver.next);
				}
			}
		}
	}
	
}+/
