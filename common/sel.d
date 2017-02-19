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
module common.sel;

import std.algorithm : sort, reverse;
import std.conv : to;
import std.string : toLower, split, join, startsWith;
import std.typecons : Tuple;


alias size_t tick_t;

alias immutable(ubyte)[17] suuid_t;

alias group(T) = Tuple!(T, "pe", T, "pc");
alias bytegroup = group!ubyte;
alias shortgroup = group!ushort;
alias intgroup = group!uint;
alias longgroup = group!ulong;


enum ubyte PE = 1;

alias POCKET = PE;

alias MCPE = PE;

alias MINECRAFT_POCKET_EDITION = PE;

enum ubyte PC = 2;

alias MINECRAFT = PC;

alias MC = PC;


/**
 * Informations about the software, like name, codename,
 * versions and protocols used.
 */
const struct Software {

	@disable this();

	/**
	 * Formatted name of the software.
	 * It should be used for display and usage purposes.
	 * Example:
	 * ---
	 * writeln("You're running ", Software.name, " based on SEL");
	 * ---
	 */
	enum string name = "SEL";

	/**
	 * Lowercase name of the software.
	 * Example:
	 * ---
	 * assert(Software.name.toLower == Software.lname);
	 * ---
	 */
	enum string lname = name.toLower;

	/**
	 * Website of the software.
	 * Source code should be at website/source and downloads
	 * at website/downloads.
	 * Example:
	 * ---
	 * download("http://" ~ Software.website ~ "/downloads/1.0.0.sa", "1.0.0.sa");
	 * ---
	 */
	enum string website = "";

	/**
	 * Codename and representations related to the version or
	 * the group of versions of the software.
	 * Used only for display purposes.
	 */
	enum string codename = "Aubergine";

	/// ditto
	enum string codenameEmoji = "🍆";

	/// ditto
	enum string fullCodename = codename ~ " (" ~ codenameEmoji ~ ")";

	enum ubyte major = 1;

	enum ubyte minor = 0;

	enum ubyte revision = 4;

	enum ubyte[3] versions = [major, minor, revision];

	enum bool stable = false;

	enum string displayVersion = to!string(major) ~ "." ~ to!string(minor) ~ "." ~ to!string(revision);

	enum string fullVersion = "v" ~ displayVersion ~ (stable ? "" : "-dev");

	enum string display = name ~ "/" ~ displayVersion;

	enum ubyte api = 1;

	enum sul = 54;

	enum ubyte hncom = 1;

	enum ubyte externalConsole = 2;

}

static if(!is(typeof(__sul))) {
	// do not print an error message if sul cannot be found
	enum __sul = Software.sul;
}

static assert(__sul >= Software.sul, "sul is outdated. Update it with 'sel update utils' and try again");

enum supportedPocketProtocols = cast(string[][uint])[
	100: ["1.0.0", "1.0.1", "1.0.2"],
	101: ["1.0.3"],
	//102: ["1.0.4"],
];

enum supportedMinecraftProtocols = cast(string[][uint])[
	210: ["1.10", "1.10.1", "1.10.2"],
	315: ["1.11"],
	316: ["1.11.1", "1.11.2"],
	//317: ["1.12"],
];

enum latestPocketProtocols = latest(supportedPocketProtocols);

enum latestMinecraftProtocols = latest(supportedMinecraftProtocols);

private uint[] latest(string[][uint] protocols) {
	uint[] keys = protocols.keys;
	if(keys.length == 1) return [keys[0]];
	sort!"a > b"(keys);
	string start = protocols[keys[0]][0].split(".")[0..2].join(".");
	size_t i = 1;
	while(i < keys.length && protocols[keys[i]][0].startsWith(start)) i++;
	keys = keys[0..i];
	reverse(keys);
	return keys;
}

enum newestPocketProtocol = latestPocketProtocols[$-1];

enum newestMinecraftProtocol = latestMinecraftProtocols[$-1];
