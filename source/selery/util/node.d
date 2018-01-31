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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/node.d, selery/util/node.d)
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
