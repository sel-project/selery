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
module config;

import std.ascii : newline;
import std.conv : to;
import std.file : exists, read, write, tempDir, mkdirRecurse;
import std.json : JSONValue;
import std.path : dirSeparator, buildNormalizedPath;
import std.string : replace, split, toLower, toUpper;
import std.traits : isArray, isAssociativeArray;
import std.uuid : UUID, parseUUID;

import selery.about;
import selery.config : Config;
import selery.files : Files;
import selery.lang : Lang;

import toml;
import toml.json;

enum ConfigType {

	server, // default
	hub,
	node

}

auto loadConfig(ConfigType type, ubyte _edu, ubyte _realm) {

	immutable filename = (){
		final switch(type) with(ConfigType) {
			case server: return "selery.toml";
			case hub: return "selery.hub.toml";
			case node: return "selery.node.toml";
		}
	}();

	Config config = new Config();
	
	immutable hub = type == ConfigType.server || type == ConfigType.hub;
	immutable node = type == ConfigType.server || type == ConfigType.node;
	
	if(exists(filename)) {
		
		auto document = parseTOML(cast(string)read(filename));
		
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
			} else static if(is(T == UUID)) {
				return parseUUID(get!string(target));
			} else static if(is(T == JSONValue)) {
				return toJSON(target);
			} else {
				static assert(0);
			}
		}
		
		void set(string jv, T)(ref T value) {
			try {
				mixin("value = get!T(document" ~ replace(to!string(jv.split(".")), ",", "][") ~ ");");
			} catch(Throwable) {}
		}

		set!"uuid"(config.uuid);
		
		if(hub) with(config.hub = new Config.Hub()) {
		
			set!"display-name"(displayName);
			set!"edu"(edu);
			set!"realm"(realm);
			set!"minecraft.enabled"(minecraft.enabled);
			set!"minecraft.motd"(minecraft.motd);
			//set!"minecraft.online-mode"(minecraft.onlineMode);
			set!"minecraft.addresses"(minecraft.addresses);
			set!"minecraft.port"(minecraft.port);
			set!"minecraft.accepted-protocols"(minecraft.protocols);
			set!"pocket.enabled"(pocket.enabled);
			set!"pocket.motd"(pocket.motd);
			//set!"pocket.online-mode"(pocket.onlineMode);
			set!"pocket.addresses"(pocket.addresses);
			set!"pocket.port"(pocket.port);
			set!"pocket.accepted-protocols"(pocket.protocols);
			set!"pocket.allow-vanilla-players"(allowVanillaPlayers);
			set!"whitelist"(whitelist);
			set!"blacklist"(blacklist);
			set!"query"(query);
			set!"language"(language);
			set!"accepted-languages"(acceptedLanguages);
			set!"server-ip"(serverIp);
			set!"favicon"(favicon);
			set!"panel.enabled"(panel);
			//set!"panel.users"(panelUsers); //TODO
			set!"panel.addresses"(panelAddresses);
			set!"panel.port"(panelPort);
			set!"rcon.enabled"(rcon);
			set!"rcon.password"(rconPassword);
			set!"rcon.addresses"(rconAddresses);
			set!"rcon.port"(rconPort);
			set!"web.enabled"(web);
			set!"web.addresses"(webAddresses);
			set!"web.port"(webPort);
			set!"hncom.accepted-addresses"(acceptedNodes);
			set!"hncom.password"(hncomPassword);
			set!"hncom.max"(maxNodes);
			set!"hncom.port"(hncomPort);
			set!"google-analytics"(googleAnalytics);
			set!"social"(social);
			
			// unlimited nodes
			string unlimited;
			set!"hncom.max"(unlimited);
			if(unlimited.toLower() == "unlimited") maxNodes = 0;
			
		}
		
		if(node) with(config.node = new Config.Node()) {
		
			set!"minecraft.enabled"(minecraft.enabled);
			set!"minecraft.accepted-protocols"(minecraft.protocols);
			set!"pocket.enabled"(pocket.enabled);
			set!"pocket.accepted-protocols"(pocket.protocols);
			set!"max-players"(maxPlayers);
			set!"world.gamemode"(gamemode);
			set!"world.difficulty"(difficulty);
			set!"world.pvp"(pvp);
			set!"world.pvm"(pvm);
			set!"world.do-daylight-cycle"(doDaylightCycle);
			set!"world.do-weather-cycle"(doWeatherCycle);
			set!"world.random-tick-speed"(randomTickSpeed);
			set!"world.do-scheduled-ticks"(doScheduledTicks);
			
			// unlimited players
			string unlimited;
			set!"max-players"(unlimited);
			if(unlimited.toLower() == "unlimited") maxPlayers = 0;
			
		}
		
	}
	
	if(!exists(filename) || hub && (_edu != 0 || _realm != 0)) {
	
		if(hub) {
			config.hub = new Config.Hub();
			if(_edu != 0) config.hub.edu = _edu == 2;
			if(_realm != 0) config.hub.realm = _realm == 2;
		}
		if(node) {
			config.node = new Config.Node();
		}
	
		string file = "# " ~ Software.name ~ " " ~ Software.fullVersion ~ " configuration file" ~ newline ~ newline;
		
		file ~= "uuid = \"" ~ config.uuid.toString().toUpper() ~ "\"" ~ newline;
		if(hub) file ~= "display-name = \"" ~ config.hub.displayName ~ "\"" ~ newline;
		if(node) file ~= "max-players = " ~ (config.node.maxPlayers == 0 ? "\"unlimited\"" : to!string(config.node.maxPlayers)) ~ newline;
		if(hub) file ~= "whitelist = " ~ to!string(config.hub.whitelist) ~ newline;
		if(hub) file ~= "blacklist = " ~ to!string(config.hub.blacklist) ~ newline;
		if(hub && !config.hub.realm) file ~= "query = " ~ to!string(config.hub.query) ~ newline;
		if(hub) file ~= "language = \"" ~ config.hub.language ~ "\"" ~ newline;
		if(hub) file ~= "accepted-languages = " ~ to!string(config.hub.acceptedLanguages) ~ newline;
		if(hub) file ~= "server-ip = \"" ~ config.hub.serverIp ~ "\"" ~ newline;
		if(hub && !config.hub.edu) file ~= "favicon = \"" ~ config.hub.favicon ~ "\"" ~ newline;
		//if(hub) file ~= "google-analytics = \"" ~ config.hub.googleAnalytics ~ "\"" ~ newline;
		if(hub && !config.hub.realm) file ~= "social = {}" ~ newline; //TODO
		if(hub && !config.hub.edu) with(config.hub.minecraft) {
			file ~= newline ~ "[minecraft]" ~ newline;
			file ~= "enabled = " ~ to!string(enabled) ~ newline;
			file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
			file ~= "online-mode = false" ~ newline;
			file ~= "addresses = " ~ to!string(addresses) ~ newline;
			file ~= "port = " ~ to!string(port) ~ newline;
			file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
		}
		if(hub) with(config.hub.pocket) {
			file ~= newline ~ "[pocket]" ~ newline;
			file ~= "enabled = " ~ to!string(enabled) ~ newline;
			file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
			file ~= "online-mode = false" ~ newline;
			file ~= "addresses = " ~ to!string(addresses) ~ newline;
			file ~= "port = " ~ to!string(port) ~ newline;
			file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
			if(config.hub.edu) file ~= newline ~ "allow-vanilla-players = " ~ to!string(config.hub.allowVanillaPlayers);
		}
		if(type == ConfigType.node) with(config.node.minecraft) {
			file ~= newline ~ "[minecraft]" ~ newline;
			file ~= "enabled = " ~ to!string(enabled) ~ newline;
			file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
		}
		if(type == ConfigType.node) with(config.node.pocket) {
			file ~= newline ~ "[pocket]" ~ newline;
			file ~= "enabled = " ~ to!string(enabled) ~ newline;
			file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
		}
		if(node) {
			file ~= newline ~ "[world]" ~ newline;
			file ~= "gamemode = \"" ~ config.node.gamemode ~ "\"" ~ newline;
			file ~= "difficulty = \"" ~ config.node.difficulty ~ "\"" ~ newline;
			file ~= "pvp = " ~ to!string(config.node.pvp) ~ newline;
			file ~= "pvm = " ~ to!string(config.node.pvm) ~ newline;
			file ~= "do-daylight-cycle = " ~ to!string(config.node.doDaylightCycle) ~ newline;
			file ~= "do-weather-cycle = " ~ to!string(config.node.doWeatherCycle) ~ newline;
			file ~= "random-tick-speed = " ~ to!string(config.node.randomTickSpeed) ~ newline;
			file ~= "do-scheduled-ticks = " ~ to!string(config.node.doScheduledTicks) ~ newline;
		}
		if(hub) {
			file ~= newline ~ "[panel]" ~ newline;
			file ~= "enabled = " ~ to!string(config.hub.panel) ~ newline;
			file ~= "addresses = " ~ to!string(config.hub.panelAddresses) ~ newline;
			foreach(user, password; config.hub.panelUsers) file ~= "[[panel.users]]" ~ newline ~ "user = \"" ~ user ~ "\"" ~ newline ~ "password = \"" ~ password ~ "\"" ~ newline;
		}
		if(hub) {
			file ~= newline ~ "[rcon]" ~ newline;
			file ~= "enabled = " ~ to!string(config.hub.rcon) ~ newline;
			file ~= "password = \"" ~ config.hub.rconPassword ~ "\"" ~ newline;
			file ~= "addresses = " ~ to!string(config.hub.rconAddresses) ~ newline;
			file ~= "port = " ~ to!string(config.hub.rconPort) ~ newline;
		}
		if(hub && !config.hub.realm) {
			file ~= newline ~ "[web]" ~ newline;
			file ~= "enabled = " ~ to!string(config.hub.web) ~ newline;
			file ~= "addresses = " ~ to!string(config.hub.webAddresses) ~ newline;
			file ~= "port = " ~ to!string(config.hub.webPort) ~ newline;
		}
		if(type == ConfigType.hub) {
			file ~= newline ~ "[hncom]" ~ newline;
			file ~= "accepted-addresses = " ~ to!string(config.hub.acceptedNodes) ~ newline;
			file ~= "password = \"" ~ config.hub.hncomPassword ~ "\"" ~ newline;
			file ~= "max = " ~ (config.hub.maxNodes == 0 ? "\"unlimited\"" : to!string(config.hub.maxNodes)) ~ newline;
			file ~= "port = " ~ to!string(config.hub.hncomPort);
			file ~= newline;
		}
		
		write(filename, file);
	
	}
	
	immutable temp = buildNormalizedPath(tempDir() ~ dirSeparator ~ "selery" ~ dirSeparator ~ config.uuid.toString().toUpper());
	mkdirRecurse(temp);
	
	config.files = new Files("assets", temp);
	config.lang = new Lang(config.files);
	
	return config;

}
