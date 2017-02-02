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
module sel.settings;

import std.algorithm : sort, canFind;
import std.ascii : newline;
import std.conv : to;
import std.file;
import std.string : join, split, strip;
import std.typetuple : TypeTuple;

import common.path : Paths;
import common.sel;

version(OneNode) {

	// try to read supported protocols from hub.txt
	static if(__traits(compiles, import("hub.txt"))) {

		private enum __hub = (){ string[string] ret;foreach(line;split(import("hub.txt"), "\n")){auto s=line.split(":");if(s.length>=2){ret[s[0].strip]=s[1..$].join("=").strip;}}return ret; }();

		static if(("minecraft" !in __hub || __hub["minecraft"] != "false") && "minecraft-accepted-protocols" in __hub) {
			enum uint[] __minecraftProtocols = parse(__hub["minecraft-accepted-protocols"], supportedMinecraftProtocols.keys, latestMinecraftProtocols);
		}

		static if(("pocket" !in __hub || __hub["pocket"] != "false") && "pocket-accepted-protocols" in __hub) {
			enum uint[] __pocketProtocols = parse(__hub["pocket-accepted-protocols"], supportedPocketProtocols.keys, latestPocketProtocols);
		}

	}

}

static if(!is(typeof(__minecraftProtocols)) && __traits(compiles, import("protocols." ~ to!string(PC)))) {

	enum uint[] __minecraftProtocols = parse(import("protocols." ~ to!string(PC)), supportedMinecraftProtocols.keys);

}

static if(!is(typeof(__pocketProtocols)) && __traits(compiles, import("protocols." ~ to!string(PE)))) {

	enum uint[] __pocketProtocols = parse(import("protocols." ~ to!string(PE)), supportedPocketProtocols.keys);

}

private uint[] parse(string str, uint[] check, uint[] def=[]) {
	uint[] protocols;
	foreach(string s ; str.split(",")) {
		try {
			uint protocol = to!uint(s.strip);
			if(!protocols.canFind(protocol)) protocols ~= protocol;
		} catch(Exception) {}
	}
	uint[] ret;
	foreach(protocol ; protocols) {
		if(check.canFind(protocol)) ret ~= protocol;
	}
	if(ret.length) {
		return sort(ret).release();
	} else {
		return def;
	}
}

static if(!is(typeof(__minecraftProtocols))) {

	enum uint[] __minecraftProtocols = !__edu ? latestMinecraftProtocols : [];

}

static if(!is(typeof(__pocketProtocols))) {

	enum uint[] __pocketProtocols = latestPocketProtocols;

}

enum bool __minecraft = __minecraftProtocols.length != 0;

enum bool __pocket = __pocketProtocols.length != 0;

void saveProtocols(ubyte type, uint[] protocols) {
	string[] str;
	foreach(protocol ; protocols) {
		str ~= to!string(protocol);
	}
	mkdirRecurse(Paths.hidden);
	write(Paths.hidden ~ "protocols." ~ to!string(type), join(str, ","));
}

mixin("alias __minecraftProtocolsTuple = TypeTuple!(" ~ __minecraftProtocols.to!string[1..$-1] ~ ");");

mixin("alias __pocketProtocolsTuple = TypeTuple!(" ~ __pocketProtocols.to!string[1..$-1] ~ ");");

enum __supportedImpl(string op, uint protocol, uint[] supported) = (){
	static if(supported.length) {
		mixin("return supported[0] " ~ op ~ " protocol || __supportedImpl!(op, protocol, supported[1..$]);");
	} else {
		return false;
	}
}();

enum __minecraftSupported(uint protocol) = __minecraftProtocols.canFind(protocol);

enum __pocketSupported(uint protocol) = __pocketProtocols.canFind(protocol);

alias __minecraftSupportedHigher(uint protocol) = __supportedImpl!(">", protocol, __minecraftProtocols);

alias __pocketSupportedHigher(uint protocol) = __supportedImpl!(">", protocol, __pocketProtocols);

alias __minecraftSupportedHigherEquals(uint protocol) = __supportedImpl!(">=", protocol, __minecraftProtocols);

alias __pocketSupportedHigherEquals(uint protocol) = __supportedImpl!(">=", protocol, __pocketProtocols);

alias __minecraftSupportedLower(uint protocol) = __supportedImpl!("<", protocol, __minecraftProtocols);

alias __pocketSupportedLower(uint protocol) = __supportedImpl!("<", protocol, __pocketProtocols);

alias __minecraftSupportedLowerEquals(uint protocol) = __supportedImpl!("<=", protocol, __minecraftProtocols);

alias __pocketSupportedLowerEquals(uint protocol) = __supportedImpl!("<=", protocol, __pocketProtocols);

enum __minecraftSupportedBetween(uint a, uint b) = __minecraftSupportedHigherEquals!a && __minecraftSupportedLowerEquals!b;

enum __pocketSupportedBetween(uint a, uint b) = __pocketSupportedHigherEquals!a && __pocketSupportedLowerEquals!b;

// runtime settings

struct Settings {
	
	public bool onlineMode;
	
	public string name;
	
	public GameInfo pocket;
	public GameInfo minecraft;

	public bool edu, realm;
	
	public string language;
	public string[] acceptedLanguages;
	
	private static struct GameInfo {
		
		public bool accepted;
		
		public string motd;
		public ushort port;
		public uint[] protocols;
		
		alias accepted this;
		
	}
	
}

/**
 * Returns: the maximum number of players accepted by the node
 */
uint reloadSettings() {

	uint ret = cast(uint)size_t.sizeof * 8;

	import sel.world.rules : Rules;

	if(exists(Paths.resources ~ "node.txt")) {
		string[string] data;
		foreach(line ; split(cast(string)read(Paths.resources ~ "node.txt"), "\n")) {
			string[] spl = line.split(":");
			if(spl.length >= 2) {
				data[spl[0].strip] = spl[1..$].join(":").strip;
			}
		}
		Rules.reload(data);
		auto m = "max-players" in data;
		if(m) {
			try {
				ret = to!uint(*m);
			} catch(Exception) {
				if(*m == "unlimited") ret = 0;
			}
		}
	}

	mkdirRecurse(Paths.resources);

	string data = "max-players: " ~ (ret == 0 ? "unlimited" : to!string(ret)) ~ newline;
	foreach(line ; Rules.defaultRules.serialize()) {
		data ~= line[0] ~ ": " ~ line[1] ~ newline;
	}
	write(Paths.resources ~ "node.txt", data);

	return ret;

}
