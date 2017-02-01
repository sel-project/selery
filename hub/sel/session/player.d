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
module sel.session.player;

import core.atomic : atomicOp;

import std.algorithm : sort;
import std.base64 : Base64;
import std.conv : to;
import std.socket : Address;
import std.string : toLower;
import std.uuid : UUID;

import common.sel;

import sel.server : Server;
import sel.network.session : Session;
import sel.session.hncom : Node;

mixin("import HncomPlayer = sul.protocol.hncom" ~ Software.hncom.to!string ~ ".player;");

/**
 * Session for players.
 */
abstract class PlayerSession : Session {
	
	protected shared Node n_node;
	
	private shared uint expected;
	private shared ubyte[][size_t] unordered_payloads;
	
	protected shared uint n_protocol;
	
	protected shared UUID n_uuid;
	
	protected shared string n_username;
	protected shared string n_display_name;

	protected shared string n_world;
	protected shared byte n_dimension;
	
	protected shared Address n_address;
	protected shared string n_server_address;
	protected shared ushort n_server_port;
	protected shared string n_language;
	protected shared Skin n_skin = null;
	
	public shared this(shared Server server) {
		super(server);
	}
	
	/**
	 * Gets the game type as an unsigned byte identifier.
	 * The types are indicated in module common.sel and will
	 * likely never change.
	 * Example:
	 * ---
	 * if(session.type == PE) {
	 *    log(session, " is on Pocket Edition");
	 * }
	 * ---
	 */
	public abstract shared nothrow @property @safe @nogc immutable(ubyte) type();
	
	/**
	 * Gets the game type and version as a human-readable string.
	 * Examples:
	 * "Minecraft 1.11.0"
	 * "Minecraft: Pocket Edition 0.16.1"
	 * "Minecraft: Education Edition 1.0.2"
	 */
	public abstract shared nothrow @property @safe const(string) game();
	
	/**
	 * Gets the protocol number used by the client.
	 * It may be 0 if the packet with the protocol number didn't
	 * come yet.
	 */
	public final shared nothrow @property @safe @nogc immutable(uint) protocol() {
		return this.n_protocol;
	}
	
	/**
	 * Gets the UUID. It's unique when online-mode is se to true
	 * and can be used to identify a player.
	 * When online-mode is set to false it is randomly generated
	 * and its uses are very limited.
	 */
	public final shared nothrow @property @safe @nogc UUID uuid() {
		return cast()this.n_uuid;
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
	public final shared nothrow @property @safe @nogc const(string) username() {
		return this.n_username;
	}
	
	/**
	 * Gets the player's lowercase username.
	 * Example:
	 * ---
	 * assert(session.username.toLower == session.iusername);
	 * ---
	 */
	public final shared @property @safe const(string) iusername() {
		return this.n_username.toLower;
	}
	
	/**
	 * Gets and sets the player's display name.
	 * It can contain formatting codes and it could change during
	 * the session's lifetime (if modified by a node).
	 * It's usually displayed in the nametag and in the players list.
	 */
	public final shared nothrow @property @safe @nogc const(string) displayName() {
		return this.n_display_name;
	}

	public final shared nothrow @property @safe @nogc const(string) displayName(string displayName) {
		return this.n_display_name = displayName;
	}

	/**
	 * Gets the player's world, which is updated by the node every
	 * time the client changes dimension.
	 */
	public final shared nothrow @property @safe @nogc const(string) world() {
		return this.n_world;
	}
	
	public final shared nothrow @property @safe @nogc const(string) world(string world) {
		return this.n_world = world;
	}

	/// ditto
	public final shared nothrow @property @safe @nogc const(byte) dimension() {
		return this.n_dimension;
	}

	public final shared nothrow @property @safe @nogc const(byte) dimension(byte dimension) {
		return this.n_dimension = dimension;
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
		return cast()this.n_address;
	}

	/**
	 * Address used by the client to connect to the server.
	 * It's a string and can either be a numerical ip or a full url.
	 */
	public final shared nothrow @property @safe @nogc string serverAddress() {
		return this.n_server_address;
	}

	/**
	 * Port used by the client to connect to the server.
	 */
	public final shared nothrow @property @safe @nogc ushort serverPort() {
		return this.n_server_port;
	}
	
	/**
	 * Gets the player's latency.
	 * Not being calculated using an ICMP protocol the value may not be
	 * completely accurate.
	 */
	public abstract shared nothrow @property @safe @nogc immutable(uint) latency();
	
	/**
	 * Gets the player's latency.
	 * It returns a floating point value between 0 and 100 where
	 * 0 is no packet loss and 100 is every packet lost since the
	 * last check.
	 * If the client uses a stream-oriented connection the value
	 * will always be 0.
	 */
	public shared nothrow @property @safe @nogc immutable(float) packetLoss() {
		return 0f;
	}
	
	/**
	 * Gets/sets the player's language, indicated as code_COUNTRY.
	 */
	public final shared nothrow @property @safe @nogc const(string) language() {
		return this.n_language;
	}

	public final shared nothrow @property @safe @nogc const(string) language(string language) {
		return this.n_language = language;
	}
	
	/**
	 * Gets the player's skin as a Skin object.
	 * If the player has no skin the object will be null.
	 */
	public final shared nothrow @property @trusted @nogc Skin skin() {
		return cast()this.n_skin;
	}

	public abstract shared nothrow @safe ubyte[] encodeHncomAddPacket(HncomPlayer.Add packet);
	
	/**
	 * Tries to connect the player to a node.
	 * This function does not notify the old node of the change,
	 * as the old node should have called the function.
	 */
	public shared bool connect(ubyte reason, string nodeName=null) {
		this.n_node = nodeName is null ? this.server.mainNode : this.server.nodeByName(nodeName);
		if(this.n_node is null) {
			this.endOfStream();
			return false;
		} else {
			this.n_node.addPlayer(this, reason);
			this.expected = 0;
			this.unordered_payloads.clear();
			return true;
		}
	}
	
	/**
	 * Calls the connect function using 'first join' as reason
	 * and, if it successfully connects to a node, add the player
	 * to the server.
	 */
	protected shared void firstConnect() {
		if(this.connect(HncomPlayer.Add.FIRST_JOIN)) {
			this.server.add(this);
		}
	}
	
	/**
	 * Function called when the player is manually
	 * transferred by the hub to a node.
	 */
	public shared void transfer(string node) {
		if(this.n_node !is null) {
			this.n_node.onPlayerTransferred(this);
		}
		this.connect(HncomPlayer.Add.TRANSFERRED, node);
	}
	
	/**
	 * Sends the latency to the connected node.
	 */
	protected shared void sendLatency() {
		if(this.n_node !is null) {
			this.n_node.sendLatencyUpdate(this);
		}
	}
	
	/**
	 * Sends the packet loss to the connected node.
	 */
	protected shared void sendPacketLoss() {
		if(this.n_node !is null) {
			this.n_node.sendPacketLossUpdate(this);
		}
	}
	
	/**
	 * Sends a packet from the node and mantain the order.
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
	public abstract shared void sendFromNode(ubyte[] payload);
	
	/**
	 * Function called when the player tries to connect to
	 * a node that doesn't exist, either because the name is
	 * wrong or because there aren't available ones.
	 */
	protected abstract shared void endOfStream();
	
	/**
	 * Function called when the player is kicked (by the
	 * hub or the node).
	 * The function should send a disconnection message
	 * and close the session.
	 */
	public abstract shared void kick(string reason, bool translation, string[] params);
	
	/**
	 * Function called when the client times out.
	 */
	protected shared void onTimedOut() {
		if(this.n_node !is null) {
			this.n_node.onPlayerTimedOut(this);
		}
		this.close();
	}
	
	/**
	 * Function called when the connection is manually closed
	 * by the client clicking the disconnect button on the
	 * game's interface.
	 */
	protected shared void onClosedByClient() {
		if(this.n_node !is null) {
			this.n_node.onPlayerLeft(this);
		}
		this.close();
	}
	
	/**
	 * Function called when the client is kicked from
	 * the hub (not from the node).
	 */
	public shared void onKicked(string reason) {
		if(this.n_node !is null) {
			this.n_node.onPlayerKicked(this);
		}
		this.kick(reason, false, []);
	}
	
	/**
	 * Closes every connection with the client and
	 * removes the session from the handler and the
	 * server (if registered to it).
	 */
	protected shared void close() {
		this.server.remove(this);
	}
	
}

class Skin {
	
	public immutable string name;
	public ubyte[] data;
	public string face;
	
	public this(string name, ubyte[] data) {
		this.name = name;
		this.data = data;
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
		this.face = Base64.encode(face);
	}
	
}
