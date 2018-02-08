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
/**
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/about.d, selery/about.d)
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
	enum ubyte patch = 1;
	
	/// ditto
	enum ubyte[3] versions = [major, minor, patch];
	
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
	enum string fullVersion = "v" ~ displayVersion;
	
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
		foreach(member ; TypeTuple!("name", "website", "displayVersion", "fullVersion", "codename", "display", "api")) {
			ret[member] = JSONValue(mixin(member));
		}
		ret["version"] = ["major": major, "minor": minor, "patch": patch];
		return JSONValue(ret);
	}
	
}

/// Protocols supported by the software.
enum uint[] supportedBedrockProtocols = [137, 141, 150, 160];

/// ditto
enum uint[] supportedJavaProtocols = [210, 315, 316, 335, 338, 340];

/// Newest protocol supported.
enum newestBedrockProtocol = supportedBedrockProtocols[$-1];

/// ditto
enum newestJavaProtocol = supportedJavaProtocols[$-1];

/// Latest protocols (latest version e.g 1.2.*).
enum uint[] latestBedrockProtocols = [137, 141, 150, 160];

/// ditto
enum uint[] latestJavaProtocols = [335, 338, 340];

/// Tuples with the supported protocols.
alias SupportedBedrockProtocols = ProtocolsImpl!(supportedBedrockProtocols);

/// ditto
alias SupportedJavaProtocols = ProtocolsImpl!(supportedJavaProtocols);

private template ProtocolsImpl(uint[] protocols, E...) {
	static if(protocols.length) {
		alias ProtocolsImpl = ProtocolsImpl!(protocols[1..$], E, protocols[0]);
	} else {
		alias ProtocolsImpl = E;
	}
}

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
