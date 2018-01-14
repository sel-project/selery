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
module selery.about;

import std.algorithm : sort, reverse, canFind;
import std.conv : to;
import std.json : JSONValue;
import std.string : toLower, split, join, startsWith;
import std.typetuple : TypeTuple;


alias suuid_t = immutable(ubyte)[17];

alias tick_t = size_t;

alias block_t = ushort;

alias item_t = size_t;


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
	enum string name = "Selery";
	
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
	enum string codename = "Cookie";
	
	/// ditto
	enum string codenameEmoji = "🍪";
	
	/// ditto
	enum string fullCodename = codename ~ " (" ~ codenameEmoji ~ ")";
	
	/**
	 * Version of the software.
	 */
	enum ubyte major = 0;
	
	/// ditto
	enum ubyte minor = 1;
	
	/// ditto
	enum ubyte patch = 0;

	/// ditto
	enum uint build = 0;
	
	/// ditto
	enum ubyte[3] versions = [major, minor, patch];
	
	/**
	 * Indicates whether the current state of the software is stable.
	 * Unstable versions are not fully tested and may fail to compile
	 * on some systems.
	 */
	enum bool stable = build == 0;
	
	/**
	 * Version of the software in format major.minor.patch following the
	 * $(HTTP http://semver.org, Semantic Version 2.0.0) (for example
	 * `1.1.0`) for display purposes.
	 */
	enum string displayVersion = to!string(major) ~ "." ~ to!string(minor) ~ "." ~ to!string(patch);
	
	/**
	 * Full version of the software prefixed with a `v` and suffixed
	 * with a build version if the version is not stable.
	 */
	enum string fullVersion = "v" ~ displayVersion ~ (!stable ? "-build." ~ to!string(build) : "");
	
	/**
	 * Display name of the software that contains both the software name
	 * and the version in the format name/version (for example `Selery/0.0.1`).
	 */
	enum string display = name ~ "/" ~ displayVersion;

	enum string simpleDisplay = name ~ " " ~ to!string(major) ~ "." ~ to!string(minor) ~ (patch != 0 ? "." ~ to!string(patch) : "");
	
	/**
	 * Version of the api used by the software. It's used to check the
	 * compatibility with plugins.
	 */
	enum ubyte api = 1;

	public static JSONValue toJSON() {
		JSONValue[string] ret;
		foreach(member ; TypeTuple!("name", "website", "stable", "displayVersion", "fullVersion", "codename", "display", "api")) {
			ret[member] = JSONValue(mixin(member));
		}
		ret["version"] = ["major": major, "minor": minor, "patch": patch, "build": build];
		return JSONValue(ret);
	}
	
}

/**
 * Protocols supported by the software.
 */
enum supportedJavaProtocols = cast(string[][uint])[
	210: ["1.10", "1.10.1", "1.10.2"],
	315: ["1.11"],
	316: ["1.11.1", "1.11.2"],
	335: ["1.12"],
	338: ["1.12.1"],
	340: ["1.12.2"],
	//351: ["1.13"],
];

/// ditto
enum supportedBedrockProtocols = cast(string[][uint])[
	137: ["1.2.0", "1.2.1", "1.2.2", "1.2.3"],
	141: ["1.2.5"],
	150: ["1.2.6"],
	160: ["1.2.7", "1.2.8"],
];

/**
 * Tuples with the supported protocols.
 */
alias SupportedJavaProtocols = ProtocolsTuple!(supportedJavaProtocols);

/// ditto
alias SupportedBedrockProtocols = ProtocolsTuple!(supportedBedrockProtocols);

alias ProtocolsTuple(string[][uint] protocols) = ProtocolsImpl!(protocols.keys);

private template ProtocolsImpl(uint[] protocols, E...) {
	static if(protocols.length) {
		alias ProtocolsImpl = ProtocolsImpl!(protocols[1..$], E, protocols[0]);
	} else {
		alias ProtocolsImpl = E;
	}
}

/**
 * Array with the protocols for the latest game version.
 * For example 315 and 316 if the latest Minecraft version
 * is 1.11.
 */
enum latestJavaProtocols = latest(supportedJavaProtocols);

/// ditto
enum latestBedrockProtocols = latest(supportedBedrockProtocols);

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

/**
 * Latest protocol released.
 */
enum newestJavaProtocol = latestJavaProtocols[$-1];

/// ditto
enum newestBedrockProtocol = latestBedrockProtocols[$-1];

uint[] validateProtocols(ref uint[] protocols, uint[] accepted, uint[] default_) {
	uint[] ret;
	foreach(protocol ; protocols) {
		if(accepted.canFind(protocol)) ret ~= protocol;
	}
	return (protocols = (ret.length ? ret : default_));
}

version(D_Ddoc) {

	/// Indicates whether the software has been tested on the current OS
	enum bool __supported = true;

} else {

	version(Windows) enum bool __supported = true;
	else version(linux) enum bool __supported = true;
	else version(FreeBSD) enum bool __supported = false;
	else version(OSX) enum bool __supported = false;
	else version(Android) enum bool __supported = false;
	else enum bool __supported = false;

}

version(Main) {

	import std.stdio : write;

	void main(string[] args) {

		write(JSONValue(["software": Software.toJSON(), "java": JSONValue(supportedJavaProtocols.keys), "bedrock": JSONValue(supportedBedrockProtocols.keys)]));

	}

}
