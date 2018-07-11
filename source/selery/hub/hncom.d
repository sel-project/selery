/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hub/hncom.d, selery/hub/hncom.d)
 */
module selery.hub.hncom;

import core.atomic : atomicOp;
import core.thread : Thread;

import std.algorithm : canFind;
import std.concurrency : spawn;
import std.conv : to;
import std.datetime : dur;
import std.json : JSONValue;
import std.math : round;
import std.regex : ctRegex, matchFirst;
import std.socket;
import std.string;
import std.system : Endian;
import std.zlib;

import sel.net.modifiers : LengthPrefixedStream;
import sel.net.stream : TcpStream;
import sel.server.query : Query;
import sel.server.util;

import selery.about;
import selery.hncom.about;
import selery.hncom.handler : Handler = HncomHandler;
import selery.hncom.io : HncomAddress, HncomUUID;
import selery.hub.player : WorldSession = World, PlayerSession, Skin;
import selery.hub.server : HubServer;
import selery.util.thread : SafeThread;
import selery.util.util : microseconds;

import Login = selery.hncom.login;
import Status = selery.hncom.status;
import Player = selery.hncom.player;

alias HncomStream = LengthPrefixedStream!(uint, Endian.littleEndian);

class HncomHandler {

	private shared HubServer server;
	
	private shared JSONValue* additionalJson;

	private shared Address address;
	
	public shared this(shared HubServer server, shared JSONValue* additionalJson) {
		this.server = server;
		this.additionalJson = additionalJson;
	}

	public shared void start(inout(string)[] accepted, ushort port) {
		bool v4, v6, public_;
		foreach(address ; accepted) {
			switch(address) {
				case "127.0.0.1":
					v4 = true;
					break;
				case "::1":
					v6 = true;
					break;
				default:
					if(address.canFind(":")) v6 = true;
					else v4 = true;
					public_ = true;
					break;
			}
		}
		Address address = getAddress(public_ ? (v4 ? "0.0.0.0" : "::") : (v4 ? "127.0.0.1" : "::1"), port)[0];
		Socket socket = new TcpSocket(v4 && v6 ? AddressFamily.INET | AddressFamily.INET6 : address.addressFamily);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		socket.setOption(SocketOptionLevel.IPV6, SocketOption.IPV6_V6ONLY, !v4 || !v6);
		socket.blocking = true;
		socket.bind(address);
		socket.listen(8);
		this.address = cast(shared)address;
		spawn(&this.acceptClients, cast(shared)socket);
	}
	
	private shared void acceptClients(shared Socket _socket) {
		debug Thread.getThis().name = "hncom_server@" ~ (cast()_socket).localAddress.toString();
		Socket socket = cast()_socket;
		while(true) {
			Socket client = socket.accept();
			Address address;
			try {
				address = client.remoteAddress;
			} catch(Exception) {
				continue;
			}
			if(this.server.acceptNode(address)) {
				new SafeThread(this.server.config.lang, {
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
	
}

/**
 * Session of a node. It's executed in a dedicated thread.
 */
abstract class AbstractNode : Handler!serverbound {

	private static shared uint _id;

	public immutable uint id;
	
	private shared HubServer server;
	private shared JSONValue* additionalJson;

	protected HncomStream stream;
	
	private shared bool n_main;
	private shared string n_name;
	
	private shared uint[][ubyte] accepted;
	
	private shared uint n_max;
	public shared Login.NodeInfo.Plugin[] plugins;
	
	private shared PlayerSession[uint] players;
	private shared WorldSession[uint] _worlds;
	
	private uint n_latency;
	
	private shared float n_tps;
	private shared ulong n_ram;
	private shared float n_cpu;
	
	public shared this(shared HubServer server, shared JSONValue* additionalJson) {
		this.id = atomicOp!"+="(_id, 1);
		this.server = server;
		this.additionalJson = additionalJson;
	}

	protected shared void exchageInfo(HncomStream stream) {
		with(cast()server.config.hub) {
			Login.HubInfo.GameInfo[ubyte] games;
			if(bedrock) games[__BEDROCK__] = Login.HubInfo.GameInfo(bedrock.motd, bedrock.protocols, bedrock.onlineMode, ushort(0));
			if(java) games[__JAVA__] = Login.HubInfo.GameInfo(java.motd, java.protocols, java.onlineMode, ushort(0));
			this.sendHubInfo(stream, new Login.HubInfo(server.id, server.nextPool, displayName, games, server.onlinePlayers, server.maxPlayers, server.config.lang.acceptedLanguages.dup, false, (cast()*this.additionalJson).toString()));
		}
		auto info = this.receiveNodeInfo(stream);
		this.n_max = info.max;
		this.accepted = cast(shared uint[][ubyte])info.acceptedGames;
		this.plugins = cast(shared)info.plugins;
		foreach(node ; server.nodesList) stream.send(node.addPacket.autoEncode());
		server.add(this);
		this.loop(stream);
		server.remove(this);
		this.onClosed();
	}

	protected abstract shared void sendHubInfo(HncomStream stream, Login.HubInfo packet);

	protected abstract shared Login.NodeInfo receiveNodeInfo(HncomStream stream);

	protected abstract shared void loop(HncomStream stream);

	protected abstract void send(ubyte[] buffer);

	protected shared void send(ubyte[] buffer) {
		return (cast()this).send(buffer);
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
	 * Gets the list of worlds loaded on the node.
	 */
	public shared nothrow @property shared(WorldSession)[] worlds() {
		return this._worlds.values;
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
		return new Status.AddNode(this.id, this.name, this.main, cast(uint[][ubyte])this.accepted);
	}

	protected override void handleStatusLatency(Status.Latency packet) {
		this.send(packet.autoEncode());
	}

	protected override void handleStatusLog(Status.Log packet) {
		string name;
		if(packet.worldId != -1) {
			auto world = packet.worldId in this._worlds;
			if(world) name = world.name;
		}
		this.server.handleLog((cast(shared)this).name, packet.message, packet.timestamp, packet.commandId, packet.worldId, name);
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

	protected override void handleStatusUpdateMaxPlayers(Status.UpdateMaxPlayers packet) {
		this.n_max = packet.max;
		this.server.updateMaxPlayers();
	}

	protected override void handleStatusUpdateUsage(Status.UpdateUsage packet) {
		this.n_ram = (cast(ulong)packet.ram) * 1024Lu;
		this.n_cpu = packet.cpu;
	}

	protected override void handleStatusUpdateLanguageFiles(Status.UpdateLanguageFiles packet) {
		this.server.config.lang.add(packet.language, packet.messages);
	}

	protected override void handleStatusAddWorld(Status.AddWorld packet) {
		//TODO notify the panel
		this._worlds[packet.worldId] = new shared WorldSession(packet.worldId, packet.groupId, packet.name, packet.dimension);
	}

	protected override void handleStatusRemoveWorld(Status.RemoveWorld packet) {
		//TODO notify the panel
		this._worlds.remove(packet.worldId);
	}

	protected override void handleStatusRemoveWorldGroup(Status.RemoveWorldGroup packet) {
		//TODO notify the panel
		foreach(world ; _worlds) {
			if(world.groupId == packet.groupId) this._worlds.remove(world.id);
		}
	}

	protected override void handleStatusAddPlugin(Status.AddPlugin packet) {}

	protected override void handleStatusRemovePlugin(Status.RemovePlugin packet) {}

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
			(*player).connect(Player.Add.TRANSFERRED, packet.node, packet.message, packet.onFail);
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
		auto world = packet.worldId in this._worlds;
		if(player && world) {
			(*player).world = *world;
		}
	}

	protected override void handlePlayerUpdatePermissionLevel(Player.UpdatePermissionLevel packet) {
		auto player = packet.hubId in this.players;
		if(player) {
			(*player).permissionLevel = packet.permissionLevel;
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
		this.send(new Player.GamePacket(player.id, data).autoEncode());
	}
	
	/**
	 * Executes a remote command.
	 */
	public shared void remoteCommand(string command, ubyte origin, Address address, int commandId) {
		this.send(new Status.RemoteCommand(origin, HncomAddress(address), command, commandId).autoEncode());
	}
	
	/**
	 * Notifies the node that another node has connected
	 * to the hub.
	 */
	public shared void addNode(shared AbstractNode node) {
		this.send(node.addPacket.autoEncode());
	}
	
	/**
	 * Notifies the node that another node has been
	 * disconnected from the hub.
	 */
	public shared void removeNode(shared AbstractNode node) {
		this.send(new Status.RemoveNode(node.id).autoEncode());
	}
	
	/**
	 * Sends a message to the node.
	 */
	public shared void sendMessage(uint sender, bool broadcasted, ubyte[] payload) {
		this.send(new Status.ReceiveMessage(sender, broadcasted, payload).autoEncode());
	}
	
	/**
	 * Sends the number of online players and maximum number of
	 * players to the node.
	 */
	public shared void updatePlayers(inout uint online, inout uint max) {
		this.send(new Status.UpdatePlayers(online, max).autoEncode());
	}
	
	/**
	 * Adds a player to the node.
	 */
	public shared void addPlayer(shared PlayerSession player, ubyte reason, ubyte[] transferMessage) {
		this.players[player.id] = player;
		this.send(new Player.Add(player.id, reason, transferMessage, player.type, player.protocol, HncomUUID(player.uuid), player.username, player.displayName, player.gameName, player.gameVersion, player.permissionLevel, player.dimension, player.viewDistance, HncomAddress(player.address), Player.Add.ServerAddress(player.serverIp, player.serverPort), player.skin is null ? Player.Add.Skin.init : Player.Add.Skin(player.skin.name, player.skin.data.dup, player.skin.cape.dup, player.skin.geometryName, player.skin.geometryData.dup), player.language, cast(ubyte)player.inputMode, player.hncomAddData().toString()).autoEncode());
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
			this.send(new Player.Remove(player.id, reason).autoEncode());
		}
	}

	public shared void sendDisplayNameUpdate(shared PlayerSession player, string displayName) {
		this.send(new Player.UpdateDisplayName(player.id, displayName).autoEncode());
	}

	public shared void sendPermissionLevelUpdate(shared PlayerSession player, ubyte permissionLevel) {
		this.send(new Player.UpdatePermissionLevel(player.id, permissionLevel).autoEncode());
	}

	public shared void sendViewDistanceUpdate(shared PlayerSession player, uint viewDistance) {
		this.send(new Player.UpdateViewDistance(player.id, viewDistance).autoEncode());
	}

	public shared void sendLanguageUpdate(shared PlayerSession player, string language) {
		this.send(new Player.UpdateLanguage(player.id, language).autoEncode());
	}
	
	/**
	 * Updates a player's latency (usually sent every 30 seconds).
	 */
	public shared void sendLatencyUpdate(shared PlayerSession player) {
		this.send(new Player.UpdateLatency(player.id, player.latency).autoEncode());
	}
	
	/**
	 * Updates a player's packet loss (usually sent every 30 seconds).
	 */
	public shared void sendPacketLossUpdate(shared PlayerSession player) {
		this.send(new Player.UpdatePacketLoss(player.id, player.packetLoss).autoEncode());
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

import std.stdio;

class ClassicNode : AbstractNode {

	private shared Socket socket;
	private immutable string remoteAddress;

	public shared this(shared HubServer server, Socket socket, shared JSONValue* additionalJson) {
		super(server, additionalJson);
		this.socket = cast(shared)socket;
		this.remoteAddress = socket.remoteAddress.toString();
		debug Thread.getThis().name = "hncom_client#" ~ to!string(this.id);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(2500));
		socket.blocking = true;
		auto stream = new HncomStream(new TcpStream(socket, 4096));
		this.stream = cast(shared)stream;
		auto payload = stream.receive();
		if(payload.length && payload[0] == Login.ConnectionRequest.ID) {
			immutable password = server.config.hub.hncomPassword;
			auto request = Login.ConnectionRequest.fromBuffer(payload);
			this.n_name = request.name.idup;
			this.n_main = request.main;
			Login.ConnectionResponse response = new Login.ConnectionResponse();
			if(request.protocol > __PROTOCOL__) response.status = Login.ConnectionResponse.OUTDATED_HUB;
			else if(request.protocol < __PROTOCOL__) response.status = Login.ConnectionResponse.OUTDATED_NODE;
			else if(password.length && !password.length) response.status = Login.ConnectionResponse.PASSWORD_REQUIRED;
			else if(password.length && password != request.password) response.status = Login.ConnectionResponse.WRONG_PASSWORD;
			else if(!this.n_name.length || this.n_name.length > 32) response.status = Login.ConnectionResponse.INVALID_NAME_LENGTH;
			else if(!this.n_name.matchFirst(ctRegex!r"[^a-zA-Z0-9_+-.,!?:@#$%\/]").empty) response.status = Login.ConnectionResponse.INVALID_NAME_CHARACTERS;
			else if(server.nodeNames.canFind(this.n_name)) response.status = Login.ConnectionResponse.NAME_ALREADY_USED;
			else if(["reload", "stop"].canFind(this.n_name.toLower)) response.status = Login.ConnectionResponse.NAME_RESERVED;
			stream.send(response.autoEncode());
			if(response.status == Login.ConnectionResponse.OK) {
				this.exchageInfo(stream);
			}
		}
		socket.close();
	}

	protected override shared void sendHubInfo(HncomStream stream, Login.HubInfo packet) {
		stream.send(packet.autoEncode());
	}

	protected override shared Login.NodeInfo receiveNodeInfo(HncomStream stream) {
		stream.stream.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"minutes"(5)); // giving it the time to load resorces and generate worlds
		auto payload = stream.receive();
		if(payload.length && payload[0] == Login.NodeInfo.ID) return Login.NodeInfo.fromBuffer(payload);
		else return Login.NodeInfo.init;
	}

	protected override shared void loop(HncomStream stream) {
		auto _this = cast()this;
		stream.stream.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(0)); // blocking without timeout
		while(true) {
			auto payload = stream.receive();
			if(payload.length) _this.handleHncom(payload);
			else break; // connection closed or error
		}
	}

	protected override void send(ubyte[] payload) {
		this.stream.send(payload);
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
		tid = cast(shared)std.concurrency.thisTid;
		ready = true;
		this.node = cast(shared)std.concurrency.receiveOnly!(std.concurrency.Tid)();
		this.n_main = true;
		this.exchageInfo(null);
	}

	protected override shared void sendHubInfo(HncomStream stream, Login.HubInfo packet) {
		std.concurrency.send(cast()this.node, cast(shared)packet);
	}

	protected override shared Login.NodeInfo receiveNodeInfo(HncomStream stream) {
		return cast()std.concurrency.receiveOnly!(shared Login.NodeInfo)();
	}

	protected override shared void loop(HncomStream stream) {
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
	
	protected override void send(ubyte[] buffer) {
		std.concurrency.send(this.node, buffer.idup);
	}
	
	protected override shared void send(ubyte[] buffer) {
		std.concurrency.send(cast()this.node, buffer.idup);
	}
	
	public override shared inout string toString() {
		return "LiteNode(" ~ to!string(this.id) ~ ")";
	}
	
}
