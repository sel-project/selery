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

import kiss.net : TcpListener, TcpStream;

//import sel.server.query : Query;
import sel.server.util;
import sel.server.server : Server;
import sel.stream : Stream, LengthPrefixedModifier;

import selery.about;
import selery.hncom.about;
import selery.hncom.handler : Handler = HncomHandler;
import selery.hncom.io : HncomPacket, HncomAddress, HncomUUID;
import selery.hub.player : WorldSession = World, PlayerSession, Skin;
import selery.hub.server : HubServer;
import selery.util.thread : SafeThread;
import selery.util.util : microseconds;

import xbuffer : Buffer;

import Login = selery.hncom.login;
import Status = selery.hncom.status;
import Player = selery.hncom.player;

class HncomServer : Server {

	private HubServer server;
	
	private JSONValue* additionalJson;
	
	public this(HubServer server, JSONValue* additionalJson) {
		super(server.eventLoop, server.info);
		this.server = server;
		this.additionalJson = additionalJson;
	}

	public override ushort defaultPort() {
		return 28232;
	}

	protected override void hostImpl(Address address) {
		TcpListener listener = new TcpListener(this.eventLoop, address.addressFamily);
		listener.bind(address);
		listener.listen(1024);
		listener.onConnectionAccepted = &this.handle;
		listener.start();
	}
	
	private void handle(TcpListener sender, TcpStream conn) {
		if(this.server.acceptNode(conn.remoteAddress)) {
			new Node(this.server, this.additionalJson, conn);
		} else {
			conn.close();
		}
	}

	public override void stop() {
		//TODO
	}
	
}

/**
 * A node client.
 */
class Node : Handler!serverbound {

	private static shared uint _id;

	public immutable uint id;
	
	private HubServer server;
	private JSONValue* additionalJson;

	private Stream stream;
	private void delegate(Buffer) handler;

	private immutable string remoteAddress;
	
	private bool _main;
	private string _name;
	
	private uint[][ubyte] accepted;
	
	private uint _max;
	public Login.NodeInfo.Plugin[] plugins;
	
	private PlayerSession[uint] players;
	private WorldSession[uint] _worlds;
	
	private uint _latency;
	
	private float _tps;
	private ulong _ram;
	private float _cpu;
	
	public this(HubServer server, JSONValue* additionalJson, TcpStream conn) {
		this.id = atomicOp!"+="(_id, 1);
		this.server = server;
		this.additionalJson = additionalJson;
		this.remoteAddress = conn.remoteAddress.toString();
		this.stream = new Stream(conn, &this.handle);
		this.stream.onClose = { onClosed(false); };
		this.stream.modify!(LengthPrefixedModifier!(uint, Endian.littleEndian))();
		this.handler = &this.handleConnectionRequest;
	}

	private void handle(Buffer buffer) {
		this.handler(buffer);
	}

	private void handleConnectionRequest(Buffer buffer) {
		if(buffer.peek!ubyte == Login.ConnectionRequest.ID) {
			immutable password = server.config.hub.hncomPassword;
			Login.ConnectionRequest request = Login.ConnectionRequest.fromBuffer(buffer);
			_name = request.name.idup;
			_main = request.main;
			Login.ConnectionResponse response = new Login.ConnectionResponse();
			if(request.protocol > __PROTOCOL__) response.status = Login.ConnectionResponse.OUTDATED_HUB;
			else if(request.protocol < __PROTOCOL__) response.status = Login.ConnectionResponse.OUTDATED_NODE;
			else if(password.length && !password.length) response.status = Login.ConnectionResponse.PASSWORD_REQUIRED;
			else if(password.length && password != request.password) response.status = Login.ConnectionResponse.WRONG_PASSWORD;
			else if(!_name.length || _name.length > 32) response.status = Login.ConnectionResponse.INVALID_NAME_LENGTH;
			else if(!_name.matchFirst(ctRegex!r"[^a-zA-Z0-9_+-.,!?:@#$%\/]").empty) response.status = Login.ConnectionResponse.INVALID_NAME_CHARACTERS;
			else if(server.nodeNames.canFind(_name)) response.status = Login.ConnectionResponse.NAME_ALREADY_USED;
			else if(["reload", "stop"].canFind(_name.toLower)) response.status = Login.ConnectionResponse.NAME_RESERVED;
			this.send(response);
			if(response.status == Login.ConnectionResponse.OK) {
				with(server.config.hub) {
					Login.HubInfo.GameInfo[ubyte] games;
					if(bedrock) games[__BEDROCK__] = Login.HubInfo.GameInfo(bedrock.motd, bedrock.protocols.dup, bedrock.onlineMode, ushort(0));
					if(java) games[__JAVA__] = Login.HubInfo.GameInfo(java.motd, java.protocols.dup, java.onlineMode, ushort(0));
					this.send(new Login.HubInfo(server.id, server.nextPool, displayName, games, server.onlinePlayers, server.maxPlayers, server.config.lang.acceptedLanguages.dup, false, (cast()*this.additionalJson).toString()));
				}
				this.handler = &this.handleNodeInfo;
			} else {
				this.close();
			}
		} else {
			this.close();
		}
	}

	private void handleNodeInfo(Buffer buffer) {
		if(buffer.peek!ubyte == Login.NodeInfo.ID) {
			Login.NodeInfo info = Login.NodeInfo.fromBuffer(buffer);
			_max = info.max;
			this.accepted = info.acceptedGames;
			this.plugins = info.plugins;
			foreach(node ; server.nodesList) this.send(new Status.AddNode(node.id, node.name, node.main, node.accepted));
			server.add(this);
			this.handler = &this.handleConnected;
		} else {
			this.close();
		}
	}

	private void handleConnected(Buffer buffer) {
		this.handleHncom(buffer);
	}

	private void close() {
		this.stream.conn.close();
	}
	
	/*
	 * Called when the client closes the connection.
	 * Tries to transfer every connected player to the main node.
	 */
	public void onClosed(bool transfer=true) {
		if(transfer) {
			foreach(PlayerSession player ; this.players) {
				player.connect(Player.Add.FORCIBLY_TRANSFERRED);
			}
		} else {
			foreach(PlayerSession player ; this.players) {
				player.kick("disconnect.close", true, []);
			}
		}
	}

	private void send(ubyte[] buffer) {
		this.stream.send(buffer);
	}

	private void send(HncomPacket packet) {
		this.send(packet.encode());
	}

	/**
	 * Gets the name of the node. The name is different for every node
	 * connected to hub and it should be used other nodes with
	 * the transfer function.
	 */
	public nothrow @property @safe @nogc const string name() {
		return _name;
	}
	
	/**
	 * Indicates whether or not this is a main node.
	 * A main node is able to receive players without the
	 * use of the transfer function.
	 * Every hub should have at least one main node, otherwise
	 * every player that tries to connect will be disconnected with
	 * the 'end of stream' message.
	 */
	public nothrow @property @safe @nogc bool main() {
		return _main;
	}
	
	/**
	 * Gets the highest number of players that can connect to the node.
	 */
	public nothrow @property @safe @nogc uint max() {
		return _max;
	}
	
	/**
	 * Gets the number of players connected to the node.
	 */
	public nothrow @property @safe @nogc uint online() {
		version(X86_64) {
			return cast(uint)this.players.length;
		} else {
			return this.players.length;
		}
	}
	
	/**
	 * Indicates whether the node is full.
	 */
	public nothrow @property @safe @nogc bool full() {
		return this.max != Login.NodeInfo.UNLIMITED && this.online >= this.max;
	}

	/**
	 * Gets the list of worlds loaded on the node.
	 */
	public nothrow @property WorldSession[] worlds() {
		return this._worlds.values;
	}
	
	/**
	 * Gets the node's latency (it may not be precise).
	 */
	public nothrow @property @safe @nogc const uint latency() {
		return _latency;
	}
	
	/**
	 * Gets the node's usage, updated with the ResourcesUsage packet.
	 */
	public nothrow @property @safe @nogc const float tps() {
		return _tps;
	}
	
	/// ditto
	public nothrow @property @safe @nogc const ulong ram() {
		return _ram;
	}
	
	/// ditto
	public nothrow @property @safe @nogc const float cpu() {
		return _cpu;
	}
	
	public nothrow @property @safe bool accepts(ubyte game, uint protocol) {
		auto p = game in this.accepted;
		return p && (*p).canFind(protocol);
	}

	protected override void handleStatusLatency(Status.Latency packet) {
		this.send(packet.encode());
	}

	protected override void handleStatusLog(Status.Log packet) {
		string name;
		if(packet.worldId != -1) {
			auto world = packet.worldId in this._worlds;
			if(world) name = world.name;
		}
		this.server.handleLog(this.name, packet.message, packet.timestamp, packet.commandId, packet.worldId, name);
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
		_max = packet.max;
		this.server.updateMaxPlayers();
	}

	protected override void handleStatusUpdateUsage(Status.UpdateUsage packet) {
		_ram = (cast(ulong)packet.ram) * 1024Lu;
		_cpu = packet.cpu;
	}

	protected override void handleStatusUpdateLanguageFiles(Status.UpdateLanguageFiles packet) {
		this.server.config.lang.add(packet.language, packet.messages);
	}

	protected override void handleStatusAddWorld(Status.AddWorld packet) {
		//TODO notify the panel
		_worlds[packet.worldId] = new WorldSession(packet.worldId, packet.groupId, packet.name, packet.dimension);
	}

	protected override void handleStatusRemoveWorld(Status.RemoveWorld packet) {
		//TODO notify the panel
		_worlds.remove(packet.worldId);
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
	public void sendTo(PlayerSession player, ubyte[] data) {
		this.send(new Player.GamePacket(player.id, data));
	}
	
	/**
	 * Executes a remote command.
	 */
	public void remoteCommand(string command, ubyte origin, Address address, int commandId) {
		this.send(new Status.RemoteCommand(origin, address, command, commandId));
	}
	
	/**
	 * Notifies the node that another node has connected
	 * to the hub.
	 */
	public void addNode(Node node) {
		this.send(new Status.AddNode(node.id, node.name, node.main, node.accepted));
	}
	
	/**
	 * Notifies the node that another node has been
	 * disconnected from the hub.
	 */
	public void removeNode(Node node) {
		this.send(new Status.RemoveNode(node.id));
	}
	
	/**
	 * Sends a message to the node.
	 */
	public void sendMessage(uint sender, bool broadcasted, ubyte[] payload) {
		this.send(new Status.ReceiveMessage(sender, broadcasted, payload));
	}
	
	/**
	 * Sends the number of online players and maximum number of
	 * players to the node.
	 */
	public void updatePlayers(uint online, uint max) {
		this.send(new Status.UpdatePlayers(online, max));
	}
	
	/**
	 * Adds a player to the node.
	 */
	public void addPlayer(PlayerSession player, ubyte reason, ubyte[] transferMessage) {
		this.players[player.id] = player;
		this.send(new Player.Add(player.id, reason, transferMessage, player.type, player.protocol, player.uuid, player.username, player.displayName, player.gameName, player.gameVersion, player.permissionLevel, player.dimension, player.viewDistance, player.address, Player.Add.ServerAddress(player.serverIp, player.serverPort), player.skin is null ? Player.Add.Skin.init : Player.Add.Skin(player.skin.name, player.skin.data.dup, player.skin.cape.dup, player.skin.geometryName, player.skin.geometryData.dup), player.language, cast(ubyte)player.inputMode, player.hncomAddData().toString()));
	}
	
	/**
	 * Called when a player is transferred by the hub (not by the node)
	 * to another node.
	 */
	public void onPlayerTransferred(PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.TRANSFERRED);
	}
	
	/**
	 * Called when a player lefts the server using the disconnect
	 * button or closing the socket.
	 */
	public void onPlayerLeft(PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.LEFT);
	}
	
	/**
	 * Called when a player times out.
	 */
	public void onPlayerTimedOut(PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.TIMED_OUT);
	}
	
	/**
	 * Called when a player is kicked (not by the node).
	 */
	public void onPlayerKicked(PlayerSession player) {
		this.onPlayerGone(player, Player.Remove.KICKED);
	}
	
	/**
	 * Generic function that removes a player from the
	 * node's list and sends a PlayerDisconnected packet to
	 * notify the node of the disconnection.
	 */
	protected void onPlayerGone(PlayerSession player, ubyte reason) {
		if(this.players.remove(player.id)) {
			this.send(new Player.Remove(player.id, reason));
		}
	}

	public void sendDisplayNameUpdate(PlayerSession player, string displayName) {
		this.send(new Player.UpdateDisplayName(player.id, displayName));
	}

	public void sendPermissionLevelUpdate(PlayerSession player, ubyte permissionLevel) {
		this.send(new Player.UpdatePermissionLevel(player.id, permissionLevel));
	}

	public void sendViewDistanceUpdate(PlayerSession player, uint viewDistance) {
		this.send(new Player.UpdateViewDistance(player.id, viewDistance));
	}

	public void sendLanguageUpdate(PlayerSession player, string language) {
		this.send(new Player.UpdateLanguage(player.id, language));
	}
	
	/**
	 * Updates a player's latency (usually sent every 30 seconds).
	 */
	public void sendLatencyUpdate(PlayerSession player) {
		this.send(new Player.UpdateLatency(player.id, player.latency));
	}
	
	/**
	 * Updates a player's packet loss (usually sent every 30 seconds).
	 */
	public void sendPacketLossUpdate(PlayerSession player) {
		this.send(new Player.UpdatePacketLoss(player.id, player.packetLoss));
	}
	
	public override string toString() {
		return "Node(" ~ to!string(this.id) ~ ", " ~ this.name ~ ", " ~ this.remoteAddress ~ ", " ~ to!string(this.main) ~ ")";
	}
	
}

/*class ClassicNode : AbstractNode {

	private TcpStream conn;
	private immutable string remoteAddress;

	public this(HubServer server, JSONValue* additionalJson, TcpStream conn) {
		super(server, additionalJson);
		this.conn = conn;
		this.remoteAddress = .remoteAddress.toString();
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
			stream.send(response.encode());
			if(response.status == Login.ConnectionResponse.OK) {
				this.exchageInfo(stream);
			}
		}
		socket.close();
	}

	protected override void sendHubInfo(HncomStream stream, Login.HubInfo packet) {
		stream.send(packet.encode());
	}

	protected override Login.NodeInfo receiveNodeInfo(HncomStream stream) {
		stream.stream.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"minutes"(5)); // giving it the time to load resorces and generate worlds
		auto payload = stream.receive();
		if(payload.length && payload[0] == Login.NodeInfo.ID) return Login.NodeInfo.fromBuffer(payload);
		else return Login.NodeInfo.init;
	}

	protected override void loop(HncomStream stream) {
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

}*/

/*class LiteNode : AbstractNode {

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
	
}*/
