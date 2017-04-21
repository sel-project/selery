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

import common.config;
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

deprecated enum bool __onlineMode = false;

deprecated enum bool __pocketEncryption = __onlineMode;

private enum __unixSocket = is(UnixAddress);

/**
 * Runtime settings.
 */
struct Settings {

	private static shared(string) n_default_language;

	public static nothrow @property @safe @nogc shared(string) defaultLanguage() {
		return n_default_language;
	}

	public Config config;

	string iconData;
	
	AddressRange[] acceptedNodes;

	alias config this;

	public static const(Settings) reload(bool all=true) {

		Settings settings;

		settings.config = Config(__oneNode ? ConfigType.full : ConfigType.hub, __edu, __realm);
		settings.config.load();

		settings.config.minecraft.motd = unpad(settings.config.minecraft.motd);
		settings.config.pocket.motd = unpad(settings.config.pocket.motd.replace(";", ""));

		// icon
		//TODO check file header to match PNG and size (64x64)
		if(exists(Paths.home ~ settings.config.icon)) settings.iconData = "data:image/png;base64," ~ Base64.encode(cast(ubyte[])read(Paths.home ~ settings.config.icon)).idup;

		string[] available = availableLanguages;
		string[] accepted;
		foreach(lang ; settings.config.acceptedLanguages) {
			lang = lang.strip;
			if(available.canFind(lang)) {
				accepted ~= lang;
			}
		}
		if(accepted.length == 0) {
			settings.config.acceptedLanguages = available;
		} else {
			settings.config.acceptedLanguages = accepted;
		}
		settings.language = bestLanguage(settings.language, settings.acceptedLanguages);

		n_default_language = settings.config.language;

		settings.config.externalConsoleHashAlgorithm = settings.config.externalConsoleHashAlgorithm.replace("-", "").toLower;

		foreach(node ; settings.config.acceptedNodes) {
			settings.acceptedNodes ~= AddressRange.parse(node);
		}

		return settings;

	}

}

private string unpad(string str) {
	if(str.length >= 2 && str.startsWith("\"") && str.endsWith("\"")) return str[1..$-1];
	else return str;
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
