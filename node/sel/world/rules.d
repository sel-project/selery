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

import common.path : Paths;

import sel.world.world : Gamemode, Difficulty;

struct Rules {

	private static Rules def;

	public static nothrow @property @safe @nogc const(Rules) defaultRules() {
		return def;
	}

	public static void reload(string[string] data) {
		void set(T)(string key, ref T dest) {
			auto p = key in data;
			if(p) {
				try {
					dest = to!T(*p);
				} catch(Exception) {}
			}
		}
		Rules rules;
		Gamemode g;
		Difficulty d;
		with(rules) {
			set("gamemode", g);
			set("difficulty", d);
			set("immutable-world", immutableWorld);
			set("pvp", pvp);
			set("pvm", pvm);
			set("daylight-cycle", daylightCycle);
			set("toggle-downfall", toggledownfall);
			set("chunk-tick", chunkTick);
			set("random-tick", randomTick);
			set("scheduled-ticks", scheduledTicks);
			set("thunders", thunders);
			set("chunks-autosending", chunksAutosending);
			set("view-distance", viewDistance);
		}
		rules.gamemode = g;
		rules.difficulty = d;
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

	public inout @safe Tuple!(string, string)[] serialize() {
		return [
			tuple("gamemode", to!string(cast(Gamemode)this.gamemode)),
			tuple("difficulty", to!string(cast(Difficulty)this.difficulty)),
			tuple("immutable-world", to!string(this.immutableWorld)),
			tuple("pvp", to!string(this.pvp)),
			tuple("pvm", to!string(this.pvm)),
			tuple("daylight-cycle", to!string(this.daylightCycle)),
			tuple("toggle-downfall", to!string(this.toggledownfall)),
			tuple("chunk-tick", to!string(this.chunkTick)),
			tuple("random-tick", to!string(this.randomTick)),
			tuple("scheduled-ticks", to!string(this.scheduledTicks)),
			tuple("thunders", to!string(this.thunders)),
			tuple("chunks-autosending", to!string(this.chunksAutosending)),
			tuple("view-distance", to!string(this.viewDistance)),
		];
	}
	
}
