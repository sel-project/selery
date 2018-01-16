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
module config;

import std.ascii : newline;
import std.conv : to, ConvException;
import std.file : exists, read, write, tempDir, mkdirRecurse;
import std.json : JSONValue;
import std.path : dirSeparator, buildNormalizedPath;
import std.socket : Address;
import std.string : replace, split, join, toLower, toUpper, startsWith, endsWith;
import std.traits : isArray, isAssociativeArray;
import std.typetuple : TypeTuple;
import std.uuid : UUID, parseUUID;
import std.zip : ZipArchive;

import selery.about;
import selery.config : Config;
import selery.files : Files, CompressedFiles;
import selery.lang : Lang;

import toml;
import toml.json;

enum bool portable = __traits(compiles, import("portable.zip"));

enum ConfigType : string {

	default_ = "default",
	hub = "hub",
	node = "node"

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
			case default_: return "selery.toml";
			case hub: return "selery.hub.toml";
			case node: return "selery.node.toml";
		}
	}();
	
	immutable isHub = type == ConfigType.default_ || type == ConfigType.hub;
	immutable isNode = type == ConfigType.default_ || type == ConfigType.node;

	auto config = new class Config {
	
		public override void load() {
		
			this.reload();
		
			immutable temp = buildNormalizedPath(tempDir() ~ dirSeparator ~ "selery" ~ dirSeparator ~ this.uuid.toString().toUpper());
			mkdirRecurse(temp);
			
			static if(portable) {
				
				this.files = new CompressedFiles(new ZipArchive(cast(void[])import("portable.zip")), temp);
				
			} else {
	
				this.files = new Files("assets", temp);
				
			}
			
			this.lang = new Lang(this.files);
		
		}
	
		public override void reload() {
	
			if(exists(filename)) {
				
				TOMLDocument document;

				try document = parseTOML(cast(string)read(filename));
				catch(TOMLException) {}
				
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
						return toJSON(target); //TODO handle conversion errors
					} else static if(is(T == Config.Hub.Address)) {
						Config.Hub.Address address;
						auto s = target.str.split(":");
						if(s.length >= 2) {
							try {
								address.port = to!ushort(s[$-1]);
							} catch(ConvException) {}
							address.ip = s[0..$-1].join(":");
							if(address.ip.startsWith("[")) address.ip = address.ip[1..$];
							if(address.ip.endsWith("]")) address.ip = address.ip[0..$-1];
						}
						return address;
					} else {
						static assert(0);
					}
				}
				
				TOMLValue getValue(TOMLValue[string] table, const(string)[] keys) {
					auto value = keys[0] in table;
					if(value) {
						if(keys.length == 1) return *value;
						else return getValue((*value).table, keys[1..$]); // throws exception if not a table
					} else {
						throw new TOMLException(keys[0] ~ " not in table");
					}
				}
				
				void set(T)(ref T value, const(string)[] keys...) {
					try {
						value = get!T(getValue(document.table, keys));
					} catch(TOMLException) {}
				}

				set(this.uuid, "uuid");
				
				if(isHub) with(this.hub = new Config.Hub()) {
				
					// override default
					webAdmin = type == ConfigType.default_;
				
					set(displayName, "display-name");
					set(edu, "edu");
					set(realm, "realm");
					set(bedrock.enabled, "bedrock", "enabled");
					set(bedrock.motd, "bedrock", "motd");
					//set!"bedrock.online-mode"(bedrock.onlineMode);
					set(bedrock.addresses, "bedrock", "addresses");
					set(bedrock.protocols, "bedrock", "accepted-protocols");
					set(allowVanillaPlayers, "bedrock", "allow-vanilla-players");
					set(java.enabled, "java", "enabled");
					set(java.motd, "java", "motd");
					//set!"java.online-mode"(java.onlineMode);
					set(java.addresses, "java", "addresses");
					set(java.protocols, "java", "accepted-protocols");
					set(whitelist, "whitelist");
					set(blacklist, "blacklist");
					set(query, "query");
					set(language, "language");
					set(acceptedLanguages, "accepted-languages");
					set(serverIp, "server-ip");
					set(favicon, "favicon");
					set(rcon, "rcon", "enabled");
					set(rconPassword, "rcon", "password");
					set(rconAddresses, "rcon", "addresses");
					set(webView, "web-view", "enabled");
					set(webViewAddresses, "web-view", "addresses");
					set(webAdmin, "web-admin", "enabled");
					set(webAdminAddresses, "web-admin", "addresses");
					set(webAdminPassword, "web-admin", "password");
					set(webAdminMaxClients, "web-admin", "max-clients");
					set(acceptedNodes, "hncom", "accepted-addresses");
					set(hncomPassword, "hncom", "password");
					set(maxNodes, "hncom", "node-limit");
					set(hncomPort, "hncom", "port");
					set(social, "social");
					
					// unlimited nodes
					string unlimited;
					set(unlimited, "hncom", "node-limit");
					if(unlimited.toLower() == "unlimited") maxNodes = 0;
					
				}
				
				if(isNode) with(this.node = new Config.Node()) {
				
					set(bedrock.enabled, "bedrock", "enabled");
					set(bedrock.protocols, "bedrock", "accepted-protocols");
					set(java.enabled, "java", "enabled");
					set(java.protocols, "java", "accepted-protocols");
					set(maxPlayers, "max-players");
					set(gamemode, "world", "gamemode");
					set(difficulty, "world", "difficulty");
					set(depleteHunger, "world", "deplete-hunger");
					set(doDaylightCycle, "world", "do-daylight-cycle");
					set(doEntityDrops, "world", "do-entity-drops");
					set(doFireTick, "world", "do-fire-tick");
					set(doScheduledTicks, "world", "do-scheduled-ticks");
					set(doWeatherCycle, "world", "do-weather-cycle");
					set(naturalRegeneration, "natural-regeneration");
					set(pvp, "world", "pvp");
					set(randomTickSpeed, "world", "random-tick-speed");
					set(viewDistance, "view-distance");
					
					// commands
					foreach(command ; Commands) {
						set(mixin(command ~ "Command"), "commands", command);
					}
					
					// unlimited players
					string unlimited;
					set(unlimited, "max-players");
					if(unlimited.toLower() == "unlimited") maxPlayers = 0;
					
				}
				
			}
			
			if(!exists(filename) || isHub && (_edu != 0 || _realm != 0)) {
			
				this.save();
			
			}
		
		}
		
		public override void save() {
		
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
			if(isHub && !this.hub.realm) file ~= "social = {}" ~ newline; //TODO
			if(isHub) with(this.hub.bedrock) {
				file ~= newline ~ "[bedrock]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
				file ~= "online-mode = false" ~ newline;
				file ~= "addresses = " ~ addressString(addresses) ~ newline;
				file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
				if(this.hub.edu) file ~= newline ~ "allow-vanilla-players = " ~ to!string(this.hub.allowVanillaPlayers);
			}
			if(isHub && !this.hub.edu) with(this.hub.java) {
				file ~= newline ~ "[java]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
				file ~= "online-mode = false" ~ newline;
				file ~= "addresses = " ~ addressString(addresses) ~ newline;
				file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
			}
			if(type == ConfigType.node) with(this.node.java) {
				file ~= newline ~ "[java]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "accepted-protocols = " ~ to!string(protocols) ~ newline;
			}
			if(type == ConfigType.node) with(this.node.bedrock) {
				file ~= newline ~ "[bedrock]" ~ newline;
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
			if(isHub && !this.hub.realm) with(this.hub) {
				file ~= newline ~ "[rcon]" ~ newline;
				file ~= "enabled = " ~ to!string(rcon) ~ newline;
				file ~= "password = \"" ~ rconPassword ~ "\"" ~ newline;
				file ~= "addresses = " ~ addressString(rconAddresses) ~ newline;
			}
			if(isHub && !this.hub.realm) with(this.hub) {
				file ~= newline ~ "[web-view]" ~ newline;
				file ~= "enabled = " ~ to!string(webView) ~ newline;
				file ~= "addresses = " ~ addressString(webViewAddresses) ~ newline;
			}
			if(isHub) with(this.hub) {
				file ~= newline ~ "[web-admin]" ~ newline;
				file ~= "enabled = " ~ to!string(webAdmin) ~ newline;
				file ~= "addresses = " ~ addressString(webAdminAddresses) ~ newline;
				file ~= "password = \"" ~ webAdminPassword ~ "\"" ~ newline;
				file ~= "max-clients = " ~ to!string(webAdminMaxClients) ~ newline;
			}
			if(type == ConfigType.hub) with(this.hub) {
				file ~= newline ~ "[hncom]" ~ newline;
				file ~= "accepted-addresses = " ~ to!string(acceptedNodes) ~ newline;
				file ~= "password = \"" ~ hncomPassword ~ "\"" ~ newline;
				file ~= "node-limit = " ~ (maxNodes == 0 ? "\"unlimited\"" : to!string(maxNodes)) ~ newline;
				file ~= "port = " ~ to!string(hncomPort);
				file ~= newline;
			}
			
			write(filename, file);
		
		}
		
	};
	
	config.load();
	
	return config;

}

string addressString(Config.Hub.Address[] addresses) {
	string[] ret;
	foreach(address ; addresses) {
		ret ~= address.toString();
	}
	return to!string(ret);
}
