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
import std.base64 : Base64;
import std.conv : to, ConvException;
import std.datetime : Clock;
import std.file : write, read, exists, mkdir, tempDir;
import std.path : dirSeparator;
import std.process : environment;
import std.random : uniform;
import std.socket;
import std.string;
import std.traits : isArray;

import common.path : Paths;
import common.sel;

version(D_Ddoc) {
	
	enum bool __doc = true;
	
} else {
	
	enum bool __doc = false;
	
}

static if(__doc) {
	
	/**
	 * Indicates whether or not it's compiling using only
	 * one node.
	 * 
	 * A server compiled as one node is used a single server
	 * and not as an hub-node one.
	 */
	enum bool __oneNode = false;
	
} else version(OneNode) {
	
	enum bool __oneNode = true;
	
} else {
	
	enum bool __oneNode = false;
	
}

static if(__doc) {
	
	/**
	 * Indicates whether or not the server is running in
	 * education mode for Minecraft: Pocket Edition.
	 */
	enum bool __edu = false;
	
} else version(Edu) {
	
	enum bool __edu = true;
	
} else {
	
	enum bool __edu = false;
	
}

static if(__doc) {
	
	/**
	 * Indicates whether or not the server is running in
	 * realm mode. Realm mode is slighter and has less
	 * options.
	 */
	enum bool __realm = false;
	
} else version(Realm) {
	
	enum bool __realm = true;
	
} else {
	
	enum bool __realm = false;
	
}

enum string __pocketPrefix = __edu ? "" : "pocket-";

static if(__doc || !__traits(compiles, import("hub.txt"))) {
	
	/**
	 * Indicates whether or not the server is running in
	 * online mode and the player should be authenticated
	 * using the games' APIs.
	 */
	enum bool __onlineMode = /*true*/false;
	
	/**
	 * Indicates whether or not the packets sent and received
	 * by Minecraft: Pocket Edition should be encrypted when
	 * online mode is set to true.
	 */
	enum bool __pocketEncryption = __onlineMode;
	
} else {
	
	private enum __settings = CtSettings(import("hub.txt"));
	
	enum bool __onlineMode = __edu ? true : /*__settings.get("online-mode", true)*/false;
	
	enum bool __pocketEncryption = __onlineMode && __settings.get(__pocketPrefix ~ "use-encryption", true);
	
	private struct CtSettings {
		
		private string[string] values;
		
		public this(string file) {
			foreach(string line ; file.split("\n")) {
				string[] spl = line.split(":");
				if(spl.length >= 2) {
					this.values[spl[0].strip.toLower] = spl[1..$].join(":").strip;
				}
			}
		}
		
		public T get(T)(string key, T defaultValue) {
			auto ptr = key in this.values;
			if(ptr) {
				try {
					static if(isArray!T && !is(T == string)) {
						return to!T("[" ~ *ptr ~ "]");
					} else {
						return to!T(*ptr);
					}
				} catch(ConvException) {}
			}
			return defaultValue;
		}
		
	}
	
	private uint[] filter(uint[] array, uint[] check) {
		uint[] ret;
		foreach(value ; array) {
			if(check.canFind(value)) ret ~= value;
		}
		return ret.length ? ret : check;
	}
	
}

private enum __unixSocket = is(UnixAddress);

/**
 * Runtime settings.
 */
struct Settings {

	private static shared(string) n_default_language;

	public static nothrow @property @safe @nogc shared(string) defaultLanguage() {
		return n_default_language;
	}
	
	string displayName;

	bool minecraft;
	
	string minecraftMotd;

	string[] minecraftAddresses;
	
	uint[] minecraftProtocols;

	bool pocket;

	string pocketMotd;

	string[] pocketAddresses;
	
	uint[] pocketProtocols;

	bool allowMcpePlayers;
	
	bool query;
	
	bool whitelist;
	
	bool blacklist;

	string forcedIp;
	
	string language;
	
	string[] acceptedLanguages;
	
	string icon;

	string iconData;
	
	bool controlPanel;
	
	string[] controlPanelAddresses;
	
	bool externalConsole;
	
	string externalConsolePassword;

	string[] externalConsoleAddresses;

	bool externalConsoleRemoteCommands;

	bool externalConsoleAcceptWebsockets;

	string externalConsoleHash;
	
	bool rcon;

	string rconPassword;
	
	string[] rconAddresses;
	
	bool web;

	string[] webAddresses;
	
	string googleAnalytics;

	string[] acceptedNodesRaw;
	
	AddressRange[] acceptedNodes;

	string nodesPassword;

	uint maxNodes;

	ushort hncomPort;

	bool hncomUseUnixSockets;

	string hncomUnixSocketAddress;

	string website, facebook, twitter, youtube, instagram, googlePlus;

	public static const(Settings) reload(bool all=true) {

		Settings settings;

		string[string] values;
		if(exists(Paths.resources ~ "hub.txt")) {
			foreach(string line ; (cast(string)read(Paths.resources ~ "hub.txt")).split("\n")) {
				string[] s = line.split(":");
				if(s.length >= 2) {
					values[s[0].strip.toLower] = s[1..$].join(":").strip;
				}
			}
		}

		void set(T)(T* value, string file_key, T defaultValue, bool acceptInit=true) {
			if(file_key in values) {
				try {
					static if(isArray!T && !is(T == string)) {
						foreach(v ; values[file_key].split(",")) {
							*value ~= to!(typeof(T.init[0]))(v.strip);
						}
					} else {
						*value = to!T(values[file_key].strip);
					}
					if(acceptInit || *value != T.init) return;
				} catch(Exception) {}
			}
			*value = defaultValue;
		}

		with(settings) {
			set(&displayName, "display-name", "A Minecraft Server", false);
			if(all) set(&minecraft, "minecraft", true);
			set(&minecraftMotd, "minecraft-motd", "A Minecraft Server", false);
			set(&minecraftAddresses, "minecraft-addresses", ["0.0.0.0:25565"], false);
			if(all) set(&minecraftProtocols, "minecraft-accepted-protocols", latestMinecraftProtocols, false);
			if(all) set(&pocket, "pocket", true);
			set(&pocketMotd, __pocketPrefix ~ "motd", "A Minecraft: " ~ (__edu ? "Education" : "Pocket") ~ " Edition Server", false);
			set(&pocketAddresses, __pocketPrefix ~ "addresses", ["0.0.0.0:19132"], false);
			if(all) set(&pocketProtocols, __pocketPrefix ~ "accepted-protocols", latestPocketProtocols, false);
			set(&allowMcpePlayers, "allow-not-edu-players", false);
			set(&query, "query-enabled", !__edu && !__realm);
			set(&whitelist, "whitelist", __edu || __realm);
			set(&blacklist, "blacklist", !whitelist);
			set(&forcedIp, "forced-ip", "");
			set(&language, "language", environment.get("LANGUAGE", "en_GB"), false);
			set(&icon, "icon", "favicon.png", false);
			set(&controlPanel, "control-panel", false);
			set(&controlPanelAddresses, "control-panel-addresses", ["0.0.0.0:8080"], false);
			set(&externalConsole, "external-console-enabled", false);
			set(&externalConsolePassword, "external-console-password", randomPassword);
			set(&externalConsoleAddresses, "external-console-addresses", ["0.0.0.0:19134"], false);
			set(&externalConsoleRemoteCommands, "external-console-remote-commands", true);
			set(&externalConsoleAcceptWebsockets, "external-console-accept-websockets", true);
			set(&externalConsoleHash, "external-console-hash-algorithm", "sha256");
			set(&rcon, "rcon-enabled", false);
			set(&rconPassword, "rcon-password", randomPassword);
			set(&rconAddresses, "rcon-addresses", ["0.0.0.0:25575"], false);
			set(&web, "web-enabled", false);
			set(&webAddresses, "web-addresses", ["*:80"], false);
			set(&nodesPassword, "nodes-password", "");
			set(&maxNodes, "max-nodes", 0);
			set(&hncomPort, "hncom-port", 28232);
			set(&hncomUseUnixSockets, "hncom-use-unix-sockets", false);
			set(&hncomUnixSocketAddress, "hncom-unix-socket-address", replace(tempDir() ~ "/sel/" ~ randomPassword, "//", "/"));
			set(&googleAnalytics, "google-analytics", "");
			set(&website, "website", "");
			set(&facebook, "facebook", "");
			set(&twitter, "twitter", "");
			set(&youtube, "youtube", "");
			set(&instagram, "instagram", "");
			set(&googlePlus, "google-plus", "");
		}

		static if(__edu) {
			settings.minecraft = false;
			settings.pocket = true;
		}

		settings.minecraftMotd = unpad(settings.minecraftMotd);
		settings.pocketMotd = unpad(settings.pocketMotd.replace(";", ""));

		filter(settings.minecraftProtocols, supportedMinecraftProtocols.keys);
		filter(settings.pocketProtocols, supportedPocketProtocols.keys);

		if(!settings.minecraftProtocols.length) settings.minecraftProtocols = latestMinecraftProtocols;
		if(!settings.pocketProtocols.length) settings.pocketProtocols = latestPocketProtocols;

		static if(__realm) {
			settings.whitelist = true;
			settings.blacklist = false;
		}

		// icon
		//TODO check file header to match PNG and size (64x64)
		if(exists(Paths.resources ~ settings.icon)) settings.iconData = "data:image/png;base64," ~ Base64.encode(cast(ubyte[])read(Paths.resources ~ settings.icon)).idup;

		string[] available = availableLanguages;
		if("accepted-languages" in values) {
			foreach(string v ; values["accepted-languages"].split(",")) {
				v = v.strip;
				if(available.canFind(v)) {
					settings.acceptedLanguages ~= v;
				}
			}
		}
		if(settings.acceptedLanguages.length == 0) {
			settings.acceptedLanguages = available;
		}

		if(!settings.acceptedLanguages.canFind(settings.language)) {
			string similar = settings.language.split("_")[0] ~ "_";
			bool found = false;
			foreach(string al ; settings.acceptedLanguages) {
				if(al.startsWith(similar)) {
					found = true;
					settings.language = al;
					break;
				}
			}
			if(!found) settings.language = settings.acceptedLanguages.canFind("en_GB") ? "en_GB" : settings.acceptedLanguages[0];
		}

		n_default_language = settings.language;

		settings.externalConsoleHash = settings.externalConsoleHash.replace("-", "").toLower;

		// accepted nodes
		if("accepted-nodes" in values) {
			string value = values["accepted-nodes"];
			if(value.length) {
				foreach(string ar ; value.split(",")) {
					settings.acceptedNodesRaw ~= ar.strip;
					settings.acceptedNodes ~= AddressRange.parse(ar.strip);
				}
			}
		} else {
			immutable node = getAddress("localhost", 0)[0].addressFamily == AddressFamily.INET6 ? "::1" : "127.0.*.*";
			settings.acceptedNodesRaw ~= node;
			settings.acceptedNodes ~= AddressRange.parse(node);
		}

		if("max-nodes" in values && values["max-nodes"].toLower == "unlimited") {
			settings.maxNodes = 0;
		}

		settings.save();

		return settings;

	}

	protected void save() {

		string file = "";
		with(Software) file ~= "## " ~ name ~ " " ~ displayVersion ~ (stable ? " " : "-dev ") ~ fullCodename ~ newline;
		with(Clock.currTime()) file ~= "## " ~ toSimpleString().split(".")[0] ~ " " ~ timezone.dstName ~ newline ~ newline;

		void protocols(string[][uint] s) {
			uint[] keys = s.keys;
			sort(keys);
			foreach(uint p ; keys) {
				file ~= "##   " ~ to!string(p) ~ ": " ~ s[p].to!string.replace("[", "").replace("]", "").replace("\"", "") ~ newline;
			}
		}
		static if(__edu) {
			file ~= "## Minecraft: Education Edition supported protocols/versions:" ~ newline;
			protocols(supportedPocketProtocols);
			file ~= newline;
		} else {
			file ~= "## Minecraft supported protocols/versions:" ~ newline;
			protocols(supportedMinecraftProtocols);
			file ~= newline;
			file ~= "## Minecraft: Pocket Edition supported protocols/versions:" ~ newline;
			protocols(supportedPocketProtocols);
			file ~= newline;
		}
		
		file ~= "## Documentation can be found at https://github.com/sel-project/sel-server/blob/master/README.md" ~ newline ~ newline;

		void add(T)(string key, T value) {
			static if(isArray!T && !is(T == string)) {
				string[] values;
				foreach(v ; value) {
					values ~= to!string(v);
				}
				add(key, values.join(", "));
			} else {
				file ~= key ~ ": " ~ to!string(value) ~ newline;
			}
		}
		add("display-name", this.displayName);
		//static if(!__edu) add("online-mode", __onlineMode);
		static if(!__edu) add("minecraft", this.minecraft);
		static if(!__edu) add("minecraft-motd", pad(this.minecraftMotd));
		static if(!__edu) add("minecraft-addresses", this.minecraftAddresses);
		static if(!__edu) add("minecraft-accepted-protocols", this.minecraftProtocols);
		static if(!__edu) add("pocket", this.pocket);
		add(__pocketPrefix ~ "motd", pad(this.pocketMotd));
		add(__pocketPrefix ~ "addresses", this.pocketAddresses);
		add(__pocketPrefix ~ "accepted-protocols", this.pocketProtocols);
		//add(__pocketPrefix ~ "use-encryption", __pocketEncryption);
		static if(__edu) add("allow-not-edu-players", allowMcpePlayers);
		static if(!__realm) add("query-enabled", this.query);
		static if(!__realm) add("whitelist", this.whitelist);
		static if(!__realm) if(!__edu || this.whitelist) add("blacklist", this.blacklist);
		add("forced-ip", this.forcedIp);
		add("language", this.language);
		add("accepted-languages", sort(this.acceptedLanguages).release());
		add("control-panel", this.controlPanel);
		add("control-panel-addresses", this.controlPanelAddresses);
		add("external-console-enabled", this.externalConsole);
		add("external-console-password", this.externalConsolePassword);
		add("external-console-addresses", this.externalConsoleAddresses);
		add("external-console-remote-commands", this.externalConsoleRemoteCommands);
		add("external-console-accept-websockets", this.externalConsoleAcceptWebsockets);
		add("external-console-hash-algorithm", this.externalConsoleHash);
		add("rcon-enabled", this.rcon);
		add("rcon-password", this.rconPassword);
		add("rcon-addresses", this.rconAddresses);
		add("web-enabled", this.web);
		add("web-addresses", this.webAddresses);
		static if(!__oneNode) add("accepted-nodes", this.acceptedNodes);
		static if(!__oneNode) add("nodes-password", this.nodesPassword);
		static if(!__oneNode) add("max-nodes", this.maxNodes == 0 ? "unlimited" : to!string(this.maxNodes));
		static if(!__oneNode) add("hncom-port", this.hncomPort);
		static if(!__oneNode && __unixSocket) add("hncom-use-unix-sockets", this.hncomUseUnixSockets);
		static if(!__oneNode && __unixSocket) add("hncom-unix-socket-address", this.hncomUnixSocketAddress);
		add("google-analytics", this.googleAnalytics);
		static if(!__edu && !__realm) {
			file ~= newline ~ "# social" ~ newline;
			add("website", this.website);
			add("facebook", this.facebook);
			add("twitter", this.twitter);
			add("youtube", this.youtube);
			add("instagram", this.instagram);
			add("google-plus", this.googlePlus);
		}

		if(!exists(Paths.resources)) mkdir(Paths.resources);
		write(Paths.resources ~ "hub.txt", file);

	}

}

private string unpad(string str) {
	if(str.length >= 2 && str.startsWith("\"") && str.endsWith("\"")) return str[1..$-1];
	else return str;
}

private string pad(string str) {
	if(str.startsWith(" ") || str.endsWith(" ")) return "\"" ~ str ~ "\"";
	else return str;
}

private @property string randomPassword() {
	char[] password = new char[8];
	foreach(ref char c ; password) {
		c = uniform!"[]"('a', 'z');
		if(!uniform!"[]"(0, 4)) c -= 32;
	}
	return password.idup;
}

private @property string[] availableLanguages() {
	string[] ret;
	import std.file : dirEntries, SpanMode, isFile;
	foreach(string path ; dirEntries(Paths.lang, SpanMode.breadth)) {
		if(path.isFile && path.endsWith(".lang")) {
			if((cast(string)read(path)).indexOf(" COMPLETE") != -1) {
				ret ~= path[path.lastIndexOf(dirSeparator)+1..$-5];
			}
		}
	}
	return ret;
}

/**
 * Stores a range of ip addresses.
 */
struct AddressRange {
	
	/**
	 * Parses an ip string into an AddressRange.
	 * Throws:
	 * 		ConvException if one of the numbers is not an unsigned byte
	 */
	public static AddressRange parse(string address) {
		AddressRange ret;
		string[] spl = address.split(".");
		if(spl.length == 4) {
			// ipv4
			ret.addressFamily = AddressFamily.INET;
			foreach(string s ; spl) {
				if(s == "*") {
					ret.ranges ~= Range(ubyte.min, ubyte.max);
				} else if(s.indexOf("-") > 0) {
					auto range = Range(to!ubyte(s[0..s.indexOf("-")]), to!ubyte(s[s.indexOf("-")+1..$]));
					if(range.min > range.max) {
						auto sw = range.max;
						range.max = range.min;
						range.min = sw;
					}
					ret.ranges ~= range;
				} else {
					ubyte value = to!ubyte(s);
					ret.ranges ~= Range(value, value);
				}
			}
			return ret;
		} else {
			// try ipv6
			ret.addressFamily = AddressFamily.INET6;
			spl = address.split("::");
			if(spl.length) {
				string[] a = spl[0].split(":");
				string[] b = (spl.length > 1 ? spl[1] : "").split(":");
				if(a.length + b.length <= 8) {
					while(a.length + b.length != 8) {
						a ~= "0";
					}
					foreach(s ; a ~ b) {
						if(s == "*") {
							ret.ranges ~= Range(ushort.min, ushort.max);
						} else if(s.indexOf("-") > 0) {
							auto range = Range(s[0..s.indexOf("-")].to!ushort(16), s[s.indexOf("-")+1..$].to!ushort(16));
							if(range.min > range.max) {
								auto sw = range.max;
								range.max = range.min;
								range.min = sw;
							}
						} else {
							ushort num = s.to!ushort(16);
							ret.ranges ~= Range(num, num);
						}
					}
				}
			}
		}
		return ret;
	}

	public AddressFamily addressFamily;

	private Range[] ranges;

	/**
	 * Checks if the given address is in this range.
	 * Params:
	 * 		address = an address of ip version 4 or 6
	 * Returns: true if it's in the range, false otherwise
	 * Example:
	 * ---
	 * auto range = AddressRange.parse("192.168.0-64.*");
	 * assert(range.contains(new InternetAddress("192.168.0.1"), 0));
	 * assert(range.contains(new InternetAddress("192.168.64.255"), 0));
	 * assert(range.contains(new InternetAddress("192.168.255.255"), 0));
	 * ---
	 */
	public bool contains(Address address) {
		size_t[] bytes;
		if(cast(InternetAddress)address) {
			if(this.addressFamily != addressFamily.INET) return false;
			InternetAddress v4 = cast(InternetAddress)address;
			bytes = [(v4.addr >> 24) & 255, (v4.addr >> 16) & 255, (v4.addr >> 8) & 255, v4.addr & 255];
		} else if(cast(Internet6Address)address) {
			if(this.addressFamily != AddressFamily.INET6) return false;
			ubyte last;
			foreach(i, ubyte b; (cast(Internet6Address)address).addr) {
				if(i % 2 == 0) {
					last = b;
				} else {
					bytes ~= last << 8 | b;
				}
			}
		}
		if(bytes.length == this.ranges.length) {
			foreach(size_t i, Range range; this.ranges) {
				if(bytes[i] < range.min || bytes[i] > range.max) return false;
			}
			return true;
		} else {
			return false;
		}
	}

	/**
	 * Converts this range into a string.
	 * Returns: the address range formatted into a string
	 * Example:
	 * ---
	 * assert(AddressRange.parse("*.0-255.79-1.4-4").toString() == "*.*.1-79.4");
	 * ---
	 */
	public string toString() {
		string pre, suf;
		string[] ret;
		size_t max = this.addressFamily == AddressFamily.INET ? ubyte.max : ushort.max;
		bool hex = this.addressFamily == AddressFamily.INET6;
		Range[] ranges = this.ranges;
		if(hex) {
			if(ranges[0].is0) {
				pre = "::";
				while(ranges.length && ranges[0].is0) {
					ranges = ranges[1..$];
				}
			} else if(ranges[$-1].is0) {
				suf = "::";
				while(ranges.length && ranges[$-1].is0) {
					ranges = ranges[0..$-1];
				}
			} else {
				//TODO zeroes in the centre
			}
		}
		foreach(Range range ; ranges) {
			ret ~= range.toString(max, hex);
		}
		return pre ~ ret.join(hex ? ":" : ".") ~ suf;
	}

	private static struct Range {

		size_t min, max;

		public pure nothrow @property @safe @nogc bool is0() {
			return this.min == 0 && this.max == 0;
		}

		public string toString(size_t max, bool hex) {
			string conv(size_t num) {
				if(hex) return to!string(num, 16).toLower;
				else return to!string(num);
			}
			if(this.min == 0 && this.max >= max) {
				return "*";
			} else if(this.min != this.max) {
				return conv(this.min) ~ "-" ~ conv(this.max);
			} else {
				return conv(this.min);
			}
		}

	}

}

void filter(ref uint[] protocols, uint[] valids) {
	sort(protocols);
	uint[] ret;
	foreach(p ; protocols) {
		if((!ret.length || p != ret[$-1]) && valids.canFind(p)) ret ~= p;
	}
	protocols = ret;
}
