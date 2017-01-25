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

version(Realm) {

	enum bool __realm = true;

} else {

	enum bool __realm = false;

}

version(Edu) {

	enum bool __edu = true;

} else {

	enum bool __edu = false;

}

static if(__traits(compiles, import("protocols." ~ to!string(PC)))) {

	enum uint[] __minecraftProtocols = parse(import("protocols." ~ to!string(PC)), supportedMinecraftProtocols.keys);

}

static if(__traits(compiles, import("protocols." ~ to!string(PE)))) {

	enum uint[] __pocketProtocols = parse(import("protocols." ~ to!string(PE)), supportedPocketProtocols.keys);

}

private uint[] parse(string str, uint[] check) {
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
	return sort(ret).release();
}

static if(!is(typeof(__minecraftProtocols))) {

	enum uint[] __minecraftProtocols = !__edu ? reverse(latestMinecraftProtocols) : [];

}

static if(!is(typeof(__pocketProtocols))) {

	enum uint[] __pocketProtocols = reverse(latestPocketProtocols);

}

uint[] reverse(uint[] a) {
	uint[] ret;
	foreach_reverse(v ; a) ret ~= v;
	return ret;
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

// runtime settings

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
