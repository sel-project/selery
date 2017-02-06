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
module sel.util.node;

import std.algorithm : canFind;

import sel.server : server;
import sel.player : Player;

/**
 * A node connected to the hub where players can be transferred to.
 */
class Node {
	
	/**
	 * Id of the node, given by the hub.
	 */
	uint hubId;
	
	/**
	 * Name of the node. It can only be one node with the same name
	 * online at the same time.
	 */
	string name;
	
	/**
	 * Indicates whether the can receive player when they first
	 * connect or only when they are transferred.
	 */
	bool main;
	
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
	
	public this(uint hubId, string name, bool main) {
		this.hubId = hubId;
		this.name = name;
		this.main = main;
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
		return server.nodeWithHubId(this.hubId) !is null;
	}
	
	/**
	 * Indicates whether the node can accept the given player.
	 * If a player is transferred to a node that cannot accept it
	 * it is kicked with the "End of Stream" message by the hub.
	 */
	public inout @safe bool accepts(Player player) {
		auto a = player.gameVersion in this.acceptedGames;
		return a && (*a).canFind(player.protocol);
	}
	
	/**
	 * Transfers a player to the node.
	 * This methos does the same as player.transfer(Node).
	 */
	public void transfer(Player player) {
		server.transfer(player, this);
	}
	
}
