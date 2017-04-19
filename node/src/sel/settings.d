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

import common.config;
import common.path : Paths;
import common.sel;

version(OneNode) {

	enum bool __oneNode = true;

} else {

	enum bool __oneNode = false;
}

version(NoSocket) {

	enum __noSocket = true;

} else {

	enum __noSocket = false;

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

	enum uint[] __minecraftProtocols = latestMinecraftProtocols;

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
	
	public Config config;

	public bool edu, realm;

	public void load() {

		this.config = Config(__oneNode ? ConfigType.full : ConfigType.node, false, false);
		this.config.load();

	}
	
	alias config this;

}
