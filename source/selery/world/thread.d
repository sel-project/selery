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
module selery.world.thread;

import core.thread : Thread;

import std.concurrency : Tid, receiveTimeout;
import std.conv : to;
import std.datetime : dur;
import std.traits : isAbstractClass, Parameters;

import selery.config : Difficulty, Gamemode;
import selery.node.info : PlayerInfo, WorldInfo;
import selery.node.server : NodeServer;
import selery.player.player : PermissionLevel;
import selery.world.world : World;

void spawnWorld(T:World, E...)(shared NodeServer server, shared WorldInfo info, bool default_, E args) if(!isAbstractClass!T && __traits(compiles, new T(args))) {

	Thread.getThis().name = "world#" ~ to!string(info.id);

	try {

		T world = new T(args);

		//TODO register default events
		//TODO register specific events

		World.startWorld(server, info, world, null, default_);
		world.startMainWorldLoop();
		//TODO stop

	} catch(Throwable t) {

		server.logger.logError(t);
		throw t;

	}

}

// server to world
struct AddPlayer {

	shared PlayerInfo player;
	bool transferred;

}

// server to world
struct RemovePlayer {

	uint playerId;

}

// world to server
struct KickPlayer {
	
	uint playerId;
	string reason;
	bool translation;
	string[] args;

}

// world to server
struct TransferPlayer {
	
	uint playerId;

}

// world to server
struct MovePlayer {

	uint playerId;
	uint worldId;

}

// server to world
struct GamePacket {

	uint playerId;
	immutable(ubyte)[] payload;

}

// server to world
struct Broadcast {

	string message;

}

// server to world
struct UpdateDifficulty {

	Difficulty difficulty;

}

// server to world
struct UpdatePlayerGamemode {

	uint playerId;
	Gamemode gamemode;

}

// server to world
struct UpdatePlayerPermissionLevel {

	uint playerId;
	PermissionLevel permissionLevel;

}

// server to world
struct Close {}

// world to server
struct CloseResult {

	enum ubyte REMOVED = 0;
	enum ubyte PLAYERS_ONLINE = 1;

	uint worldId;
	ubyte status;

}
