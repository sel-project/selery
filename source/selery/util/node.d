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
module selery.util.node;

import std.algorithm : canFind;

import selery.node.server : NodeServer;
import selery.player.player : Player;

/**
 * A node connected to the hub where players can be transferred to.
 */
class Node {

	public shared NodeServer server;
	
	/**
	 * Id of the node, given by the hub.
	 */
	public immutable uint hubId;
	
	/**
	 * Name of the node. It can only be one node with the same name
	 * online at the same time.
	 */
	public const string name;
	
	/**
	 * Indicates whether the can receive player when they first
	 * connect or only when they are transferred.
	 */
	public immutable bool main;
	
	/**
	 * Indicates which games and which protocols the node does accept.
	 * Example:
	 * ---
	 * auto pocket = PE in node.acceptedGames;
	 * if(pocket && (*pocket).canFind(100)) {
	 *    log(node.name, " supports MCPE 1.0");
	 * }
	 * ---
	 */
	uint[][ubyte] acceptedGames;

	public this(shared NodeServer server, uint hubId, string name, bool main, uint[][ubyte] acceptedGames) {
		this.server = server;
		this.hubId = hubId;
		this.name = name;
		this.main = main;
		this.acceptedGames = acceptedGames;
	}
	
	/**
	 * Indicates whether or not the node is still connected to
	 * the hub.
	 * Example:
	 * ---
	 * auto node = server.nodeWithName("node");
	 * assert(node.online);
	 * ---
	 */
	public inout @property @safe bool online() {
		return this.server.nodeWithHubId(this.hubId) !is null;
	}
	
	/**
	 * Indicates whether the node can accept the given player.
	 * If a player is transferred to a node that cannot accept it
	 * it is kicked with the "End of Stream" message by the hub.
	 */
	public inout @safe bool accepts(Player player) {
		auto a = player.gameId in this.acceptedGames;
		return a && (*a).canFind(player.protocol);
	}

	/**
	 * Sends a message to the node.
	 * Example:
	 * ---
	 * // if the other node uses the same JSON protocol
	 * node.sendMessage(`{"reply_with":12}`);
	 * server += (NodeMessageEvent event) {
	 *    if(node == event.node) {
	 *       assert(parseJSON(cast(string)event.payload)["reply"].integer == 12);
	 *    }
	 * }
	 * ---
	 */
	public void sendMessage(ubyte[] payload) {
		this.server.sendMessage(this, payload);
	}

	/// ditto
	public void sendMessage(string message) {
		this.sendMessage(cast(ubyte[])message);
	}

	public override bool opEquals(Object o) {
		auto node = cast(Node)o;
		return node !is null && node.hubId == this.hubId;
	}
	
}
