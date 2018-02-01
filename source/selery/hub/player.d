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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hub/player.d, selery/hub/player.d)
 */
module selery.hub.player;

import core.atomic : atomicOp;

import std.algorithm : sort;
import std.base64 : Base64;
import std.conv : to;
import std.json : JSONValue;
import std.socket : Address;
import std.string : toLower;
import std.uuid : UUID;

import sel.server.client : InputMode, Client;

import selery.about;
import selery.hub.handler.hncom : AbstractNode;
import selery.hub.server : HubServer;

import HncomPlayer = sel.hncom.player;

class World {
	
	public immutable uint id;
	public immutable string name;
	public immutable ubyte dimension;
	
	public World parent;
	
	public shared this(uint id, string name, ubyte dimension) {
		this.id = id;
		this.name = name;
		this.dimension = dimension;
	}
	
}

/**
 * Session for players.
 */
class PlayerSession {

	private shared HubServer server;
	private shared Client client;
	
	private shared AbstractNode _node; // shouldn't be null
	private shared uint last_node = -1;
	
	private shared uint expected;
	private shared ubyte[][size_t] unordered_payloads;
	
	protected immutable string lower_username;
	protected shared string _display_name;

	protected shared ubyte _permission_level;

	protected shared World _world;
	protected shared ubyte _dimension;
	protected shared ubyte _view_distance;

	protected shared string _language;
	protected shared Skin _skin = null;
	
	public shared this(shared HubServer server, shared Client client) {
		this.server = server;
		this.client = client;
		this.lower_username = this._display_name = username;
		this._language = client.language.length ? client.language : server.config.language;
		if(client.skinName.length) this._skin = cast(shared)new Skin(client.skinName, client.skinData, client.skinGeometryName, client.skinGeometryData, client.skinCape);
	}

	public final shared nothrow @property @safe @nogc uint id() {
		return this.client.id;
	}
	
	/**
	 * Gets the game type as an unsigned byte identifier.
	 * The types are indicated in module sel.server.client, in the
	 * Client's class.
	 * Example:
	 * ---
	 * import sel.hncom.about;
	 * 
	 * if(player.type == Client.JAVA) {
	 *    log(player.username, " is on Java Edition");
	 * }
	 * ---
	 */
	public final shared nothrow @property @safe @nogc ubyte type() {
		return this.client.type;
	}

	/**
	 * Gets the protocol number used by the client.
	 * It may be 0 if the packet with the protocol number didn't
	 * come yet.
	 */
	public final shared nothrow @property @safe @nogc uint protocol() {
		return this.client.protocol;
	}

	/**
	 * Gets the client's game name.
	 * Examples:
	 * "Minecraft"
	 * "Minecraft: Java Edition"
	 * "Minecraft: Education Edition"
	 */
	public final shared nothrow @property @safe @nogc string gameName() {
		return this.client.gameName;
	}

	/**
	 * Gets the client's game version, which could either be calculated
	 * from the protocol number or given by the client.
	 * Example:
	 * ---
	 * if(player.type == Client.JAVA)
	 *    assert(supportedMinecraftProtocols[player.protocol].canFind(player.gameVersion));
	 * ---
	 */
	public final shared nothrow @property @safe @nogc string gameVersion() {
		return this.client.gameVersion;
	}
	
	/**
	 * Gets the game type and version as a human-readable string.
	 * Examples:
	 * "Minecraft 1.2.0"
	 * "Minecraft: Java Edition 1.12"
	 * "Minecraft: Education Edition 1.1.5"
	 */
	public final shared nothrow @property @safe string game() {
		return this.client.game;
	}
	
	/**
	 * Gets the UUID. It's unique when online-mode is se to true
	 * and can be used to identify a player.
	 * When online-mode is set to false it is randomly generated
	 * and its uses are very limited.
	 */
	public final shared nothrow @property @safe @nogc UUID uuid() {
		return this.client.uuid;
	}
	
	/**
	 * Gets the SEL UUID, a unique identifier for the player in
	 * the session. It's composed by 17 bytes (type and UUID)
	 * and it will never change for authenticated players.
	 * Example:
	 * ---
	 * assert(session.type == session.suuid[0]);
	 * ---
	 */
	public final shared nothrow @property @safe const(suuid_t) suuid() {
		immutable(ubyte)[17] data = this.type ~ this.uuid.data;
		return data;
	}
	
	/**
	 * Gets the player's username, mantaining the case given
	 * by the login packet.
	 * It doesn't change during the life of the session.
	 */
	public final shared nothrow @property @safe @nogc string username() {
		return this.client.username;
	}
	
	/**
	 * Gets the player's lowercase username.
	 * Example:
	 * ---
	 * assert(session.username.toLower == session.iusername);
	 * ---
	 */
	public final shared @property @safe string iusername() {
		return this.lower_username;
	}
	
	/**
	 * Gets and sets the player's display name.
	 * It can contain formatting codes and it could change during
	 * the session's lifetime (if modified by a node).
	 * It's usually displayed in the nametag and in the players list.
	 */
	public final shared nothrow @property @safe @nogc string displayName() {
		return this._display_name;
	}

	/// ditto
	public final shared @property string displayName(string displayName) {
		this._node.sendDisplayNameUpdate(this, displayName);
		return this._display_name = displayName;
	}

	public final shared nothrow @property @safe @nogc ubyte permissionLevel() {
		return this._permission_level;
	}

	public final shared @property ubyte permissionLevel(ubyte permissionLevel) {
		this._node.sendPermissionLevelUpdate(this, permissionLevel);
		return this._permission_level = permissionLevel;
	}

	/**
	 * Gets the player's world, which is updated by the node every
	 * time the client changes dimension.
	 */
	public final shared nothrow @property @safe @nogc shared(World) world() {
		return this._world;
	}
	
	public final shared nothrow @property @safe @nogc shared(World) world(shared World world) {
		this._dimension = world.dimension;
		return this._world = world;
	}

	/// ditto
	public final shared nothrow @property @safe @nogc byte dimension() {
		return this._dimension;
	}

	public final shared nothrow @property @safe @nogc ubyte viewDistance() {
		return this._view_distance;
	}

	public final shared @property ubyte viewDistance(ubyte viewDistance) {
		this._node.sendViewDistanceUpdate(this, viewDistance);
		return this._view_distance = viewDistance;
	}

	/**
	 * Gets the player's input mode.
	 */
	public final shared nothrow @property @safe @nogc InputMode inputMode() {
		return this.client.inputMode;
	}

	/**
	 * Gets the player's remote address. it's usually an ipv4, ipv6
	 * or an ipv4-mapped ipv6.
	 * Example:
	 * ---
	 * if(session.address.addressFamily == AddressFamily.INET6) {
	 *    log(session, " is connected through IPv6");
	 * }
	 * ---
	 */
	public final shared nothrow @property @trusted @nogc Address address() {
		return this.client.address;
	}

	/**
	 * IP used by the client to connect to the server.
	 * It's a string and can either be a numerical ip or a full url.
	 */
	public final shared nothrow @property @safe @nogc string serverIp() {
		return this.client.serverIp;
	}

	/**
	 * Port used by the client to connect to the server.
	 */
	public final shared nothrow @property @safe @nogc ushort serverPort() {
		return this.client.serverPort;
	}
	
	/**
	 * Gets the player's latency.
	 * Not being calculated using an ICMP protocol the value may not be
	 * completely accurate.
	 */
	public shared nothrow @property @safe @nogc uint latency() {
		return 0; //TODO
	}
	
	/**
	 * Gets the player's latency.
	 * It returns a floating point value between 0 and 100 where
	 * 0 is no packet loss and 100 is every packet lost since the
	 * last check.
	 * If the client uses a stream-oriented connection the value
	 * will always be 0.
	 */
	public shared nothrow @property @safe @nogc float packetLoss() {
		return 0f; //TODO
	}
	
	/**
	 * Gets/sets the player's language, indicated as code_COUNTRY.
	 */
	public final shared nothrow @property @safe @nogc string language() {
		return this._language;
	}

	public final shared @property string language(string language) {
		this._node.sendLanguageUpdate(this, language);
		return this._language = language;
	}
	
	/**
	 * Gets the player's skin as a Skin object.
	 * If the player has no skin the object will be null.
	 */
	public final shared nothrow @property @trusted @nogc Skin skin() {
		return cast()this._skin;
	}

	public shared JSONValue hncomAddData() {
		return this.client.gameData;
	}
	
	/**
	 * Tries to connect the player to a node.
	 * This function does not notify the old node of the change,
	 * as the old node should have called the function.
	 */
	public shared bool connect(ubyte reason, int nodeId=-1, ubyte[] message=[], ubyte onFail=HncomPlayer.Transfer.DISCONNECT) {
		shared AbstractNode[] nodes;
		if(nodeId < 0) {
			nodes = this.server.mainNodes;
		} else {
			auto node = this.server.nodeById(nodeId);
			if(node !is null) nodes = [node];
		}
		foreach(node ; nodes) {
			if(node.accepts(this.type, this.protocol)) {
				this._node = node;
				this.last_node = node.id;
				this.expected = 0;
				this.unordered_payloads.clear();
				node.addPlayer(this, reason, message);
				return true;
			}
		}
		if(onFail == HncomPlayer.Transfer.AUTO) {
			return this.connect(reason);
		} else if(onFail == HncomPlayer.Transfer.RECONNECT && this.last_node != -1) {
			return this.connect(reason, this.last_node);
		} else {
			this.endOfStream();
			return false;
		}
	}
	
	/**
	 * Calls the connect function using 'first join' as reason
	 * and, if it successfully connects to a node, add the player
	 * to the server.
	 */
	public shared bool firstConnect() {
		return this.connect(HncomPlayer.Add.FIRST_JOIN);
	}
	
	/**
	 * Function called when the player is manually
	 * transferred by the hub to a node.
	 */
	public shared void transfer(uint node) {
		this._node.onPlayerTransferred(this);
		this.connect(HncomPlayer.Add.TRANSFERRED, node);
	}
	
	/**
	 * Sends the latency to the connected node.
	 */
	protected shared void sendLatency() {
		this._node.sendLatencyUpdate(this);
	}
	
	/**
	 * Sends the packet loss to the connected node.
	 */
	protected shared void sendPacketLoss() {
		this._node.sendPacketLossUpdate(this);
	}

	/**
	 *  Forwards a game packet to the node.
	 */
	public shared void sendToNode(ubyte[] payload) {
		this._node.sendTo(this, payload);
	}
	
	/**
	 * Sends a packet from the node and mantains the order.
	 */
	public final shared void sendOrderedFromNode(uint order, ubyte[] payload) {
		if(order == this.expected) {
			this.sendFromNode(payload);
			atomicOp!"+="(this.expected, 1);
			if(this.unordered_payloads.length) {
				size_t[] keys = this.unordered_payloads.keys;
				sort(keys);
				while(keys.length && keys[0] == this.expected) {
					this.sendFromNode(cast(ubyte[])this.unordered_payloads[keys[0]]);
					this.unordered_payloads.remove(keys[0]);
					keys = keys[1..$];
					atomicOp!"+="(this.expected, 1);
				}
			}
		} else {
			this.unordered_payloads[order] = cast(shared ubyte[])payload;
		}
	}
	
	/**
	 * Sends an encoded packet to client that has been created
	 * and encoded by the node.
	 */
	public shared void sendFromNode(ubyte[] payload) {
		this.client.directSend(payload);
	}
	
	/**
	 * Function called when the player tries to connect to
	 * a node that doesn't exist, either because the name is
	 * wrong or because there aren't available ones.
	 */
	protected shared void endOfStream() {
		this.kick("disconnect.endOfStream", true, []);
	};
	
	/**
	 * Function called when the player is kicked (by the
	 * hub or the node).
	 * The function should send a disconnection message
	 * and close the session.
	 */
	public shared void kick(string reason, bool translation, string[] params) {
		this.client.disconnect(reason, translation, params);
	}
	
	/**
	 * Function called when the client times out.
	 */
	protected shared void onTimedOut() {
		this._node.onPlayerTimedOut(this);
	}
	
	/**
	 * Function called when the connection is manually closed
	 * by the client clicking the disconnect button on the
	 * game's interface.
	 */
	protected shared void onClosedByClient() {
		this._node.onPlayerLeft(this);
	}
	
	/**
	 * Function called when the client is kicked from
	 * the hub (not from the node).
	 */
	public shared void onKicked(string reason) {
		this._node.onPlayerKicked(this);
		this.kick(reason, false, []);
	}

	public shared void onClosed() {
		this._node.onPlayerLeft(this);
	}
	
}

class Skin {
	
	public immutable string name;
	public immutable(ubyte)[] data;
	public string geometryName;
	public immutable(ubyte)[] geometryData;
	public immutable(ubyte)[] cape;

	public ubyte[192] face;
	public string faceBase64;
	
	public this(string name, immutable(ubyte)[] data, string geometryName, immutable(ubyte)[] geometryData, immutable(ubyte)[] cape) {
		this.name = name;
		this.data = data;
		this.geometryName = geometryName;
		this.geometryData = geometryData;
		this.cape = cape;
		ubyte[192] face;
		size_t i = 0;
		foreach(y ; 0..8) {
			foreach(x ; 0..8) {
				size_t layer = ((x + 40) + ((y + 8) * 64)) * 4;
				if(data[layer] == 0) {
					layer = ((x + 8) + ((y + 8) * 64)) * 4;
				}
				face[i++] = this.data[layer++];
				face[i++] = this.data[layer++];
				face[i++] = this.data[layer++];
			}
		}
		this.face = face;
		this.faceBase64 = Base64.encode(face);
	}
	
}
