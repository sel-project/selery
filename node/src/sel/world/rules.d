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
module sel.world.rules;

import std.conv : to;
import std.typecons : Tuple, tuple;

import sel.config : Config;
import sel.path : Paths;

enum Gamemode : ubyte {

	survival = 0, s = 0,
	creative = 1, c = 1,
	adventure = 2, a = 2,
	spectator = 3, sp = 3,

}

enum Difficulty : ubyte {

	peaceful = 0,
	easy = 1,
	normal = 2,
	hard = 3,

}

struct Rules {

	private static Rules def;

	public static nothrow @property @safe @nogc const(Rules) defaultRules() {
		return def;
	}

	public static void reload(Config config) {
		Rules rules;
		rules.gamemode = to!Gamemode(config.gamemode);
		rules.difficulty = to!Difficulty(config.difficulty);
		rules.pvp = config.pvp;
		rules.pvm = config.pvm;
		rules.daylightCycle = config.doDaylightCycle;
		rules.toggledownfall = config.doWeatherCycle;
		rules.randomTick = config.randomTickSpeed;
		rules.scheduledTicks = config.doScheduledTicks;
		def = rules;
	}
	
	ubyte gamemode = Gamemode.survival;
	
	bool immutableWorld = false;
	bool pvp = true;
	bool pvm = true;
	bool daylightCycle = true;
	
	bool toggledownfall = true;
	bool chunkTick = true;
	size_t randomTick = 3;
	bool scheduledTicks = true;
	
	float thunders = 1f / 100000f;
	
	ubyte difficulty = Difficulty.normal;
	
	bool chunksAutosending = true; //check if chunks will be sent automatically (calling the event)
	size_t viewDistance = 16; // ~800 chunks
	
	bool entityDrops = true;
	bool fireTick = true;
	bool mobLoot = true;
	bool mobSpawning = true;
	bool tileDrops = true;
	bool keepInventory = false;
	bool mobGriefing = true;
	bool naturalRegeneration = true;
	bool depleteHunger = true;
	
	public inout @property @safe Rules dup() {
		return Rules(this.gamemode, this.immutableWorld, this.pvp, this.pvm, this.daylightCycle, this.toggledownfall, this.chunkTick, this.randomTick, this.scheduledTicks,
			this.thunders, this.difficulty,
			this.chunksAutosending, this.viewDistance,
			this.entityDrops, this.fireTick, this.mobLoot, this.mobSpawning, this.tileDrops, this.keepInventory, this.mobGriefing, this.naturalRegeneration, this.depleteHunger);
	}
	
}
