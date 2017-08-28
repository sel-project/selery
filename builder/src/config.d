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
import std.string : replace, split, join, toLower, toUpper, endsWith;
import std.traits : isArray, isAssociativeArray;
import std.typetuple : TypeTuple;
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

mixin({
	string[] commands;
	foreach(member ; __traits(allMembers, Config.Node)) {
		static if(member.endsWith("Command")) commands ~= (`"` ~ member[0..$-7] ~ `"`);
	}
	return "alias Commands = TypeTuple!(" ~ commands.join(",") ~ ");";
}());

auto loadConfig(ConfigType type, ubyte _edu, ubyte _realm) {

	immutable filename = (){
		final switch(type) with(ConfigType) {
			case server: return "selery.toml";
			case hub: return "selery.hub.toml";
			case node: return "selery.node.toml";
		}
	}();
	
	immutable isHub = type == ConfigType.server || type == ConfigType.hub;
	immutable isNode = type == ConfigType.server || type == ConfigType.node;

	auto config = new class Config {
	
		public override void reload() {
	
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

				set!"uuid"(this.uuid);
				
				if(isHub) with(this.hub = new Config.Hub()) {
				
					set!"display-name"(displayName);
					set!"edu"(edu);
					set!"realm"(realm);
					set!"java.enabled"(java.enabled);
					set!"java.motd"(java.motd);
					//set!"java.online-mode"(java.onlineMode);
					set!"java.addresses"(java.addresses);
					set!"java.port"(java.port);
					set!"java.accepted-protocols"(java.protocols);
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
				
				if(isNode) with(this.node = new Config.Node()) {
				
					set!"java.enabled"(java.enabled);
					set!"java.accepted-protocols"(java.protocols);
					set!"pocket.enabled"(pocket.enabled);
					set!"pocket.accepted-protocols"(pocket.protocols);
					set!"max-players"(maxPlayers);
					set!"world.gamemode"(gamemode);
					set!"world.difficulty"(difficulty);
					set!"world.deplete-hunger"(depleteHunger);
					set!"world.do-daylight-cycle"(doDaylightCycle);
					set!"world.do-entity-drops"(doEntityDrops);
					set!"world.do-fire-tick"(doFireTick);
					set!"world.do-scheduled-ticks"(doScheduledTicks);
					set!"world.do-weather-cycle"(doWeatherCycle);
					set!"natural-regeneration"(naturalRegeneration);
					set!"world.pvp"(pvp);
					set!"world.random-tick-speed"(randomTickSpeed);
					set!"view-distance"(viewDistance);
					
					// commands
					foreach(command ; Commands) {
						set!("commands." ~ command)(mixin(command ~ "Command"));
					}
					
					// unlimited players
					string unlimited;
					set!"max-players"(unlimited);
					if(unlimited.toLower() == "unlimited") maxPlayers = 0;
					
				}
				
			}
			
			if(!exists(filename) || isHub && (_edu != 0 || _realm != 0)) {
			
				if(isHub) {
					this.hub = new Config.Hub();
					if(_edu != 0) this.hub.edu = _edu == 2;
					if(_realm != 0) this.hub.realm = _realm == 2;
				}
				if(isNode) {
					this.node = new Config.Node();
				}
			
				string file = "# " ~ Software.name ~ " " ~ Software.fullVersion ~ " configuration file" ~ newline ~ newline;
				
				file ~= "uuid = \"" ~ this.uuid.toString().toUpper() ~ "\"" ~ newline;
				if(isHub) file ~= "display-name = \"" ~ this.hub.displayName ~ "\"" ~ newline;
				if(isNode) file ~= "max-players = " ~ (this.node.maxPlayers == 0 ? "\"unlimited\"" : to!string(this.node.maxPlayers)) ~ newline;
				if(isHub) file ~= "whitelist = " ~ to!string(this.hub.whitelist) ~ newline;
				if(isHub) file ~= "blacklist = " ~ to!string(this.hub.blacklist) ~ newline;
				if(isHub && !this.hub.realm) file ~= "query = " ~ to!string(this.hub.query) ~ newline;
				if(isHub) file ~= "language = \"" ~ this.hub.language ~ "\"" ~ newline;
				if(isHub) file ~= "accepted-languages = " ~ to!string(this.hub.acceptedLanguages) ~ newline;
				if(isHub) file ~= "server-ip = \"" ~ this.hub.serverIp ~ "\"" ~ newline;
				if(isHub && !this.hub.edu) file ~= "favicon = \"" ~ this.hub.favicon ~ "\"" ~ newline;
				//if(isHub) file ~= "google-analytics = \"" ~ this.hub.googleAnalytics ~ "\"" ~ newline;
				if(isHub && !this.hub.realm) file ~= "social = {}" ~ newline; //TODO
				if(isHub && !this.hub.edu) with(this.hub.java) {
					file ~= newline ~ "[java]" ~ newline;
					file ~= "enabled = " ~ to!string(enabled) ~ newline;
					file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
					file ~= "online-mode = false" ~ newline;
					file ~= "addresses = " ~ to!string(addresses) ~ newline;
					file ~= "port = " ~ to!string(port) ~ newline;
					file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
				}
				if(isHub) with(this.hub.pocket) {
					file ~= newline ~ "[pocket]" ~ newline;
					file ~= "enabled = " ~ to!string(enabled) ~ newline;
					file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
					file ~= "online-mode = false" ~ newline;
					file ~= "addresses = " ~ to!string(addresses) ~ newline;
					file ~= "port = " ~ to!string(port) ~ newline;
					file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
					if(this.hub.edu) file ~= newline ~ "allow-vanilla-players = " ~ to!string(this.hub.allowVanillaPlayers);
				}
				if(type == ConfigType.node) with(this.node.java) {
					file ~= newline ~ "[java]" ~ newline;
					file ~= "enabled = " ~ to!string(enabled) ~ newline;
					file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
				}
				if(type == ConfigType.node) with(this.node.pocket) {
					file ~= newline ~ "[pocket]" ~ newline;
					file ~= "enabled = " ~ to!string(enabled) ~ newline;
					file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
				}
				if(isNode) with(this.node) {
					file ~= newline ~ "[world]" ~ newline;
					file ~= "gamemode = " ~ to!string(gamemode) ~ newline;
					file ~= "difficulty = " ~ to!string(difficulty) ~ newline;
					file ~= "deplete-hunger = " ~ to!string(depleteHunger) ~ newline;
					file ~= "do-daylight-cycle = " ~ to!string(doDaylightCycle) ~ newline;
					file ~= "do-entity-drops = " ~ to!string(doEntityDrops) ~ newline;
					file ~= "do-fire-tick = " ~ to!string(doFireTick) ~ newline;
					file ~= "do-scheduled-ticks = " ~ to!string(doScheduledTicks) ~ newline;
					file ~= "do-weather-cycle = " ~ to!string(doWeatherCycle) ~ newline;
					file ~= "natural-regeneration = " ~ to!string(naturalRegeneration) ~ newline;
					file ~= "pvp = " ~ to!string(pvp) ~ newline;
					file ~= "random-tick-speed = " ~ to!string(randomTickSpeed) ~ newline;
					file ~= "view-distance = " ~ to!string(viewDistance) ~ newline;
				}
				if(isNode) with(this.node) {
					file ~= newline ~ "[commands]" ~ newline;
					foreach(command ; Commands) {
						file ~= command ~ " = " ~ to!string(mixin(command ~ "Command")) ~ newline;
					}
				}
				if(isHub) with(this.hub) {
					file ~= newline ~ "[panel]" ~ newline;
					file ~= "enabled = " ~ to!string(panel) ~ newline;
					file ~= "addresses = " ~ to!string(panelAddresses) ~ newline;
					foreach(user, password; panelUsers) file ~= "[[panel.users]]" ~ newline ~ "user = \"" ~ user ~ "\"" ~ newline ~ "password = \"" ~ password ~ "\"" ~ newline;
				}
				if(isHub) with(this.hub) {
					file ~= newline ~ "[rcon]" ~ newline;
					file ~= "enabled = " ~ to!string(rcon) ~ newline;
					file ~= "password = \"" ~ rconPassword ~ "\"" ~ newline;
					file ~= "addresses = " ~ to!string(rconAddresses) ~ newline;
					file ~= "port = " ~ to!string(rconPort) ~ newline;
				}
				if(isHub && !this.hub.realm) with(this.hub) {
					file ~= newline ~ "[web]" ~ newline;
					file ~= "enabled = " ~ to!string(web) ~ newline;
					file ~= "addresses = " ~ to!string(webAddresses) ~ newline;
					file ~= "port = " ~ to!string(webPort) ~ newline;
				}
				if(type == ConfigType.hub) with(this.hub) {
					file ~= newline ~ "[hncom]" ~ newline;
					file ~= "accepted-addresses = " ~ to!string(acceptedNodes) ~ newline;
					file ~= "password = \"" ~ hncomPassword ~ "\"" ~ newline;
					file ~= "max = " ~ (maxNodes == 0 ? "\"unlimited\"" : to!string(maxNodes)) ~ newline;
					file ~= "port = " ~ to!string(hncomPort);
					file ~= newline;
				}
				
				write(filename, file);
			
			}
			
			immutable temp = buildNormalizedPath(tempDir() ~ dirSeparator ~ "selery" ~ dirSeparator ~ this.uuid.toString().toUpper());
			mkdirRecurse(temp);
			
			this.files = new Files("assets", temp);
			this.lang = new Lang(this.files);
		
		}
		
	};
	
	config.reload();
	
	return config;

}
