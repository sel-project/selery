/*
 * Copyright (c) 2017-2018 SEL
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
module selery.world.thread;

import core.thread : Thread;

import std.concurrency : Tid, receiveTimeout;
import std.conv : to;
import std.datetime : dur;
import std.traits : isAbstractClass, Parameters;

import selery.config : Difficulty, Gamemode;
import selery.node.info : PlayerInfo, WorldInfo;
import selery.node.server : NodeServer;
import selery.world.world : World;

void spawnWorld(T:World, E...)(shared NodeServer server, shared WorldInfo info, E args) if(!isAbstractClass!T && __traits(compiles, new T(args))) {

	Thread.getThis().name = "World#" ~ to!string(info.id);

	try {

		T world = new T(args);

		//TODO register default events
		//TODO register specific events

		World.startWorld(server, info, world, null);
		world.startMainWorldLoop();

	} catch(Throwable t) {

		import selery.log;
		error_log(t);
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
	bool children;

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
struct UpdatePlayerOpStatus {

	uint playerId;
	bool op;

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
