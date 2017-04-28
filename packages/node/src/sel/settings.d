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

import com.config;
import com.path : Paths;
import com.sel;

import sel.world.rules : Rules;

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

//public import data : __minecraftProtocols, __pocketProtocols;

//TODO read during compilation

enum __minecraftProtocols = supportedMinecraftProtocols.keys.sort().release;

enum __pocketProtocols = supportedPocketProtocols.keys.sort().release;

enum bool __minecraft = __minecraftProtocols.length != 0;

enum bool __pocket = __pocketProtocols.length != 0;

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

	public void load(bool edu, bool realm) {

		this.config = Config(__oneNode ? ConfigType.lite : ConfigType.node, edu, realm);
		this.config.load();

		Rules.reload(this.config);

	}
	
	alias config this;

}
