/*
 * Copyright (c) 2017 SEL
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
module selery.config;

import std.algorithm : sort, uniq, filter, canFind;
import std.array : array;
import std.ascii : newline;
import std.conv : to;
import std.datetime : Clock;
import std.file : read, write, exists, tempDir;
import std.json : JSONValue, JSON_TYPE;
import std.path : dirSeparator;
import std.process : environment;
import std.random : uniform;
import std.socket : getAddress, AddressFamily;
import std.string;
import std.traits : isArray, isAssociativeArray;

import selery.about;
import selery.path : Paths;

import toml;
import toml.json : toJSON;

enum ConfigType {

	hub,
	node,
	lite

}

struct Config {

	public static struct Game {

		bool enabled;
		string motd;
		bool onlineMode;
		string[] addresses;
		ushort port;
		uint[] protocols;

		alias enabled this;

	}

	ConfigType type;

	bool edu, realm;

	string displayName;

	Game minecraft, pocket;

	bool allowVanillaPlayers;

	uint maxPlayers = size_t.sizeof.to!uint * 8;

	bool whitelist, blacklist;

	bool query;

	string language;

	string[] acceptedLanguages;

	string serverIp;

	string icon;

	string gamemode = "survival";

	string difficulty = "normal";

	bool pvp = true;

	bool pvm = true;

	bool doDaylightCycle = true;

	bool doWeatherCycle = true;

	uint randomTickSpeed = 3;

	bool doScheduledTicks = true;

	JSONValue[] plugins;

	bool panel;

	string[string] panelUsers;

	string[] panelAddresses;

	ushort panelPort = 19134;

	bool externalConsole;

	string externalConsolePassword;

	string[] externalConsoleAddresses;

	ushort externalConsolePort = 19134;

	bool externalConsoleRemoteCommands = true;

	bool externalConsoleAcceptWebsockets = true;

	string externalConsoleHashAlgorithm = "sha256";

	bool rcon;

	string rconPassword;

	string[] rconAddresses;

	ushort rconPort = 25575;

	bool web;

	string[] webAddresses;

	ushort webPort = 80;

	string googleAnalytics;

	JSONValue social;

	string[] acceptedNodes;

	string hncomPassword;

	uint maxNodes;

	ushort hncomPort = 28232;

	bool hncomUseUnixSockets = false;

	string hncomUnixSocketAddress;

	public this(ConfigType type, bool edu, bool realm) {

		this.type = type;
		this.edu = edu;
		this.realm = realm;

		this.acceptedLanguages = availableLanguages();
		version(Windows) {
			import std.utf : toUTF8;
			import core.sys.windows.winnls;
			wchar[] lang = new wchar[3];
			wchar[] country = new wchar[3];
			GetLocaleInfo(GetUserDefaultUILanguage(), LOCALE_SISO639LANGNAME, lang.ptr, 3);
			GetLocaleInfo(GetUserDefaultUILanguage(), LOCALE_SISO3166CTRYNAME, country.ptr, 3);
			this.language = fromStringz(toUTF8(lang).ptr) ~ "_" ~ fromStringz(toUTF8(country).ptr);
		} else {
			this.language = environment.get("LANG", "en_GB");
		}
		this.language = bestLanguage(this.language, this.acceptedLanguages);

		this.acceptedNodes ~= getAddress("localhost", 0)[0].addressFamily == AddressFamily.INET6 ? "::1" : "127.0.*.*";

		this.hncomUnixSocketAddress = tempDir();
		if(!this.hncomUnixSocketAddress.endsWith(dirSeparator)) this.hncomUnixSocketAddress ~= dirSeparator;
		this.hncomUnixSocketAddress ~= "sel" ~ dirSeparator ~ randomPassword;

	}

	private @property string header() {

		string file;

		enum C = "#";

		with(Software) file ~= C ~ newline ~ C ~ "  " ~ name ~ " " ~ displayVersion ~ (stable ? " " : "-dev ") ~ codename ~ " " ~ codenameEmoji ~ newline;
		with(Clock.currTime()) file ~= C ~ "  " ~ toSimpleString().split(".")[0] ~ " " ~ timezone.dstName ~ newline ~ C ~ newline;

		void protocols(string[][uint] s) {
			uint[] keys = s.keys;
			sort(keys);
			foreach(uint p ; keys) {
				file ~= C ~ "  \t" ~ to!string(p) ~ ": " ~ s[p].to!string.replace("[", "").replace("]", "").replace("\"", "") ~ newline;
			}
		}
		if(edu) {
			file ~= C ~ "  Minecraft: Education Edition supported protocols/versions:" ~ newline;
			protocols(supportedPocketProtocols);
			file ~= C ~ newline;
		} else {
			file ~= C ~ "  Minecraft supported protocols/versions:" ~ newline;
			protocols(supportedMinecraftProtocols);
			file ~= C ~ newline;
			file ~= C ~ "  Minecraft: Pocket Edition supported protocols/versions:" ~ newline;
			protocols(supportedPocketProtocols);
			file ~= C ~ newline;
		}

		return file;

	}

	public void save() {

		string file = header() ~ newline;

		if(type != ConfigType.node) file ~= "display-name = \"A Minecraft Server\"" ~ newline;
		if(type != ConfigType.hub) file ~= "max-players = " ~ to!string(size_t.sizeof * 8) ~ newline;
		if(type != ConfigType.node) file ~= "whitelist = " ~ to!string(edu || realm) ~ newline;
		if(type != ConfigType.node) file ~= "blacklist = " ~ to!string(!edu && !realm) ~ newline;
		if(type != ConfigType.node && !realm) file ~= "query = " ~ to!string(!edu && !realm) ~ newline;
		if(type != ConfigType.node) file ~= "language = " ~ JSONValue(this.language).toString() ~ newline;
		if(type != ConfigType.node) file ~= "accepted-languages = " ~ to!string(this.acceptedLanguages) ~ newline;
		if(type != ConfigType.node) file ~= "server-ip = \"\"" ~ newline;
		if(type != ConfigType.node && !edu) file ~= "icon = \"favicon.png\"" ~ newline;
		if(type != ConfigType.node) file ~= "google-analytics = \"\"" ~ newline;
		if(type != ConfigType.node && !realm) file ~= "social = {}" ~ newline;
		if(type != ConfigType.node && !edu) {
			file ~= newline ~ "[minecraft]" ~ newline;
			file ~= "enabled = true" ~ newline;
			file ~= "motd = \"A Minecraft Server\"" ~ newline;
			file ~= "online-mode = false" ~ newline;
			file ~= "addresses = [\"0.0.0.0\"]" ~ newline;
			file ~= "port = 25565" ~ newline;
			file ~= "accepted-protocols = " ~ to!string(latestMinecraftProtocols) ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= newline ~ "[pocket]" ~ newline;
			file ~= "enabled = true" ~ newline;
			file ~= "motd = \"A Minecraft Server\"" ~ newline;
			file ~= "online-mode = false" ~ newline;
			file ~= "addresses = [\"0.0.0.0\"]" ~ newline;
			file ~= "port = 19132" ~ newline;
			file ~= "accepted-protocols = " ~ to!string(latestPocketProtocols);
			if(edu) file ~= newline ~ "allow-vanilla-players = false";
			file ~= newline;
		}
		if(type != ConfigType.hub) {
			file ~= newline ~ "[world]" ~ newline;
			file ~= "gamemode = \"survival\"" ~ newline;
			file ~= "difficulty = \"normal\"" ~ newline;
			file ~= "pvp = true" ~ newline;
			file ~= "pvm = true" ~ newline;
			file ~= "do-daylight-cycle = true" ~ newline;
			file ~= "do-weather-cycle = true" ~ newline;
			file ~= "random-tick-speed = 3" ~ newline;
			file ~= "do-scheduled-ticks = true" ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= newline ~ "[panel]" ~ newline;
			file ~= "enabled = false" ~ newline;
			file ~= "addresses = [\"0.0.0.0\"]" ~ newline;
			file ~= "[[panel.users]]" ~ newline ~ "name = \"Admin\"" ~ newline ~ "password = \"" ~ randomPassword() ~ "\"" ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= newline ~ "[external-console]" ~ newline;
			file ~= "enabled = false" ~ newline;
			file ~= "password = \"" ~ randomPassword() ~ "\"" ~ newline;
			file ~= "addresses = [\"0.0.0.0\"]" ~ newline;
			file ~= "port = 19134" ~ newline;
			file ~= "remote-commands = true" ~ newline;
			file ~= "accept-websockets = true" ~ newline;
			file ~= "hash-algorithm = \"sha256\"" ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= newline ~ "[rcon]" ~ newline;
			file ~= "enabled = false" ~ newline;
			file ~= "password = \"" ~ randomPassword() ~ "\"" ~ newline;
			file ~= "addresses = [\"0.0.0.0\"]" ~ newline;
			file ~= "port = 25575" ~ newline;
		}
		if(type != ConfigType.node && !realm) {
			file ~= newline ~ "[web]" ~ newline;
			file ~= "enabled = false" ~ newline;
			file ~= "addresses = [\"0.0.0.0\", \"::\"]" ~ newline;
			file ~= "port = 80" ~ newline;
		}
		if(type == ConfigType.hub) {
			file ~= newline ~ "[hncom]" ~ newline;
			file ~= "accepted-addresses = " ~ to!string(this.acceptedNodes) ~ newline;
			file ~= "password = \"\"" ~ newline;
			file ~= "max = \"unlimited\"" ~ newline;
			file ~= "port = 28232";
			version(Posix) {
				file ~= newline ~ "use-unix-sockets = false" ~ newline;
				file ~= "unix-socket-address = \"" ~ this.hncomUnixSocketAddress ~ "\"";
			}
			file ~= newline;
		}
		file ~= newline;

		write(Paths.home ~ "server.toml", file);

	}

	public void load() {

		if(!exists(Paths.home ~ "server.toml")) this.save();

		TOMLDocument toml = parseTOML(cast(string)read(Paths.home ~ "server.toml"));
		
		T get(T)(TOMLValue target) {
			static if(is(T == string)) {
				return target.str;
			} else static if(isArray!T) {
				T ret;
				foreach(value ; target.array) {
					ret ~= get!(typeof(ret[0]))(value);
				}
				return ret;
			} else static if(isAssociativeArray!T) {
				T ret;
				foreach(key, value; target.table) {
					ret[key] = get!(typeof(ret[""]))(value);
				}
				return ret;
			} else static if(is(T == bool)) {
				return target.boolean;
			} else static if(is(T == float) || is(T == double) || is(T == real)) {
				return cast(T)target.floating;
			} else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
				return cast(T)target.integer;
			} else static if(is(T == JSONValue)) {
				return toJSON(target);
			} else {
				static assert(0);
			}
		}
		
		void set(string jv, T)(ref T value) {
			try {
				mixin("value = get!T(toml" ~ replace(to!string(jv.split(".")), ",", "][") ~ ");");
			} catch(Throwable) {}
		}

		set!"display-name"(this.displayName);
		set!"minecraft.enabled"(this.minecraft.enabled);
		set!"minecraft.motd"(this.minecraft.motd);
		//set!"minecraft.online-mode"(this.minecraft.onlineMode);
		set!"minecraft.addresses"(this.minecraft.addresses);
		set!"minecraft.port"(this.minecraft.port);
		set!"minecraft.accepted-protocols"(this.minecraft.protocols);
		set!"pocket.enabled"(this.pocket.enabled);
		set!"pocket.motd"(this.pocket.motd);
		//set!"pocket.online-mode"(this.pocket.onlineMode);
		set!"pocket.addresses"(this.pocket.addresses);
		set!"pocket.port"(this.pocket.port);
		set!"pocket.accepted-protocols"(this.pocket.protocols);
		set!"pocket.allow-vanilla-players"(this.allowVanillaPlayers);
		set!"max-players"(this.maxPlayers);
		set!"whitelist"(this.whitelist);
		set!"blacklist"(this.blacklist);
		set!"query"(this.query);
		set!"language"(this.language);
		set!"accepted-languages"(this.acceptedLanguages);
		set!"server-ip"(this.serverIp);
		set!"icon"(this.icon);
		set!"world.gamemode"(this.gamemode);
		set!"world.difficulty"(this.difficulty);
		set!"world.pvp"(this.pvp);
		set!"world.pvm"(this.pvm);
		set!"world.do-daylight-cycle"(this.doDaylightCycle);
		set!"world.do-weather-cycle"(this.doWeatherCycle);
		set!"world.random-tick-speed"(this.randomTickSpeed);
		set!"world.do-scheduled-ticks"(this.doScheduledTicks);
		//set!"plugins"(this.plugins);
		set!"panel.enabled"(this.panel);
		set!"panel.users"(this.panelUsers);
		set!"panel.addresses"(this.panelAddresses);
		set!"panel.port"(this.panelPort);
		set!"external-console.enabled"(this.externalConsole);
		set!"external-console.password"(this.externalConsolePassword);
		set!"external-console.addresses"(this.externalConsoleAddresses);
		set!"external-console-port"(this.externalConsolePort);
		set!"external-console.remote-commands"(this.externalConsoleRemoteCommands);
		set!"external-console.accept-websockets"(this.externalConsoleAcceptWebsockets);
		set!"external-console.hash-algorithm"(this.externalConsoleHashAlgorithm);
		set!"rcon.enabled"(this.rcon);
		set!"rcon.password"(this.rconPassword);
		set!"rcon.addresses"(this.rconAddresses);
		set!"rcon.port"(this.rconPort);
		set!"web.enabled"(this.web);
		set!"web.addresses"(this.webAddresses);
		set!"web.port"(this.webPort);
		set!"hncom.accepted-addresses"(this.acceptedNodes);
		set!"hncom.password"(this.hncomPassword);
		set!"hncom.max"(this.maxNodes);
		set!"hncom.port"(this.hncomPort);
		set!"hncom.use-unix-sockets"(this.hncomUseUnixSockets);
		set!"hncom.unix-socket-address"(this.hncomUnixSocketAddress);
		set!"google-analytics"(this.googleAnalytics);
		set!"social"(this.social);

		void checkProtocols(ref uint[] protocols, uint[] accepted) {
			sort(protocols);
			protocols = protocols.uniq.filter!(a => accepted.canFind(a)).array;
		}

		checkProtocols(this.minecraft.protocols, supportedMinecraftProtocols.keys);
		if(this.minecraft.protocols.length == 0) this.minecraft.enabled = false;

		checkProtocols(this.pocket.protocols, supportedPocketProtocols.keys);
		if(this.pocket.protocols.length == 0) this.pocket.enabled = false;

		if("max-players" in toml && toml["max-players"].type == TOML_TYPE.STRING && toml["max-players"].str.toLower == "unlimited") this.maxPlayers = 0;
		
		if("max-nodes" in toml && toml["max-nodes"].type == TOML_TYPE.STRING && toml["max-nodes"].str.toLower == "unlimited") this.maxNodes = 0;

		if(this.social.type != JSON_TYPE.OBJECT) {
			this.social = JSONValue((JSONValue[string]).init);
		}

	}

}

public @property string randomPassword() {
	char[] password = new char[uniform!"[]"(8, 12)];
	foreach(ref char c ; password) {
		c = uniform!"[]"('a', 'z');
		if(!uniform!"[]"(0, 4)) c -= 32;
	}
	return password.idup;
}

public @property string[] availableLanguages() {
	string[] ret;
	import std.file : dirEntries, SpanMode, isFile;
	foreach(string path ; dirEntries(Paths.langSystem, SpanMode.breadth)) {
		if(path.isFile && path.endsWith(".lang")) {
			if((cast(string)read(path)).indexOf(" COMPLETE") != -1) {
				ret ~= path[path.lastIndexOf(dirSeparator)+1..$-5];
			}
		}
	}
	return ret;
}

public string bestLanguage(string lang, string[] accepted) {
	if(accepted.canFind(lang)) return lang;
	string similar = lang.split("_")[0] ~ "_";
	foreach(al ; accepted) {
		if(al.startsWith(similar)) return al;
	}
	return accepted.canFind("en_GB") ? "en_GB" : accepted[0];
}
