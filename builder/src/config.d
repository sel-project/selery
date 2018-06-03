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
module config;

import std.ascii : newline;
import std.conv : to, ConvException;
import std.file : exists, read, write, remove, tempDir, mkdirRecurse;
import std.json : JSONValue;
import std.path : dirSeparator, buildNormalizedPath;
import std.socket : Address;
import std.string : replace, split, join, toLower, toUpper, startsWith, endsWith;
import std.traits : isArray, isAssociativeArray, isIntegral, isFloatingPoint;
import std.typetuple : TypeTuple;
import std.uuid : UUID, parseUUID;
import std.zip : ZipArchive;

import selery.about;
import selery.config : Config, Files;
import selery.lang : LanguageManager;
import selery.plugin : Plugin;

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

auto loadConfig(ConfigType type, ref string[] args) {

	immutable filename = (){
		final switch(type) with(ConfigType) {
			case default_: return "selery.toml";
			case hub: return "selery.hub.toml";
			case node: return "selery.node.toml";
		}
	}();
	
	immutable isHub = type == ConfigType.default_ || type == ConfigType.hub;
	immutable isNode = type == ConfigType.default_ || type == ConfigType.node;
	
	bool hasArg(string a) {
		foreach(i, arg; args) {
			if(arg == a) {
				args = args[0..i] ~ args[i+1..$];
				return true;
			}
		}
		return false;
	}

	auto config = new class Config {
	
		private string language;
	
		public override void load() {
		
			version(Windows) {
				import std.utf : toUTF8;
				import std.string : fromStringz;
				import core.sys.windows.winnls;
				wchar[] lang = new wchar[3];
				wchar[] country = new wchar[3];
				GetLocaleInfo(GetUserDefaultUILanguage(), LOCALE_SISO639LANGNAME, lang.ptr, 3);
				GetLocaleInfo(GetUserDefaultUILanguage(), LOCALE_SISO3166CTRYNAME, country.ptr, 3);
				this.language = fromStringz(toUTF8(lang).ptr) ~ "_" ~ fromStringz(toUTF8(country).ptr);
			} else {
				import std.process : environment;
				this.language = environment.get("LANGUAGE", environment.get("LANG", "en_US"));
			}
		
			this.reload();
		
			immutable temp = buildNormalizedPath(tempDir() ~ dirSeparator ~ "selery" ~ dirSeparator ~ this.uuid.toString().toUpper());
			mkdirRecurse(temp);
			
			static if(portable) {
				
				this.files = new CompressedFiles(new ZipArchive(cast(void[])import("portable.zip")), temp);
				
			} else {
	
				this.files = new Files("assets", temp);
				
			}
			
			this.lang = new LanguageManager(this.files, this.language);
			this.lang.load();
		
		}
	
		public override void reload() {
		
			TOMLDocument document;
	
			if(exists(filename)) document = parseTOML(cast(string)read(filename));
				
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
					return target.type == TOML_TYPE.TRUE;
				} else static if(isFloatingPoint!T) {
					return cast(T)target.floating;
				} else static if(isIntegral!T) {
					return cast(T)target.integer;
				} else static if(is(T == UUID)) {
					return parseUUID(get!string(target));
				} else static if(is(T == JSONValue)) {
					return toJSON(target); //TODO handle conversion errors
				} else static if(is(T == Config.Hub.Address)) {
					return convertAddress(target.str);
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
				static if(is(T == string) || isIntegral!T || isFloatingPoint!T || is(T == bool) || isArray!T) {
					// override using --key=value
					immutable option = "--" ~ keys.join("-");
					foreach(i, arg; args) {
						if(arg.startsWith(option ~ "=")) {
							args = args[0..i] ~ args[i+1..$];
							try {
								immutable data = arg[option.length+1..$];
								static if(isArray!T && !is(T == string)) {
									T _value;
									alias A = typeof(_value[0]);
									foreach(s_data ; split(data, ",")) {
										static if(is(A == Config.Hub.Address)) _value ~= convertAddress(s_data);
										else _value ~= to!A(s_data);
									}
									value = _value;
								} else {
									value = to!T(data);
								}
							} catch(ConvException) {}
							return;
						}
					}
				}
				try {
					value = get!T(getValue(document.table, keys));
				} catch(TOMLException) {}
			}
			
			void setProtocols(ref uint[] value, uint[] all, uint[] latest, const(string)[] keys...) {
				string s;
				set(s, keys);
				if(s == "all" || s == "*") value = all;
				else if(s == "latest") value = latest;
				else set(value, keys);
			}

			set(this.uuid, "uuid");
			set(this.language, "language");
			
			if(isHub) with(this.hub = new Config.Hub()) {
			
				set(displayName, "display-name");
				set(edu, "edu");
				set(bedrock.enabled, "bedrock", "enabled");
				set(bedrock.motd, "bedrock", "motd");
				set(bedrock.addresses, "bedrock", "addresses");
				setProtocols(bedrock.protocols, supportedBedrockProtocols, latestBedrockProtocols, "bedrock", "accepted-protocols");
				set(allowVanillaPlayers, "bedrock", "allow-vanilla-players");
				set(java.enabled, "java", "enabled");
				set(java.motd, "java", "motd");
				set(java.addresses, "java", "addresses");
				setProtocols(java.protocols, supportedJavaProtocols, latestJavaProtocols, "java", "accepted-protocols");
				set(query, "query-enabled");
				set(serverIp, "server-ip");
				set(favicon, "favicon");
				set(rcon, "rcon", "enabled");
				set(rconPassword, "rcon", "password");
				set(rconAddresses, "rcon", "addresses");
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
			
				// override default
				transferCommand = type != ConfigType.default_;
			
				set(name, "hub", "name");
				set(password, "hub", "password");
				set(ip, "hub", "ip");
				set(port, "hub", "port");
				set(main, "hub", "main");
				set(bedrock.enabled, "bedrock", "enabled");
				setProtocols(bedrock.protocols, supportedBedrockProtocols, latestBedrockProtocols, "bedrock", "accepted-protocols");
				set(java.enabled, "java", "enabled");
				setProtocols(java.protocols, supportedJavaProtocols, latestJavaProtocols, "java", "accepted-protocols");
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
					set(mixin(command ~ "Command"), "command", command);
				}
				
				// unlimited players
				string unlimited;
				set(unlimited, "max-players");
				if(unlimited.toLower() == "unlimited") maxPlayers = 0;
				
			}
			
			if(!exists(filename)) this.save();
		
		}
		
		public override void save() {
		
			string serializeProtocols(uint[] protocols, uint[] all, uint[] latest) {
				if(protocols == latest) return `"latest"`;
				else if(protocols == all) return `"all"`;
				else return to!string(protocols);
			}
		
			// is this needed?
			if(this.hub is null) this.hub = new Config.Hub();
			if(this.node is null) this.node = new Config.Node();
		
			string file = "# " ~ Software.name ~ " " ~ Software.fullVersion ~ " configuration file" ~ newline ~ newline;
			
			file ~= "uuid = \"" ~ this.uuid.toString().toUpper() ~ "\"" ~ newline;
			if(isHub) file ~= "display-name = \"" ~ this.hub.displayName ~ "\"" ~ newline;
			if(isNode) file ~= "max-players = " ~ (this.node.maxPlayers == 0 ? "\"unlimited\"" : to!string(this.node.maxPlayers)) ~ newline;
			file ~= "language = \"" ~ this.language ~ "\"" ~ newline;
			if(isHub) file ~= "server-ip = \"" ~ this.hub.serverIp ~ "\"" ~ newline;
			if(isHub) file ~= "query-enabled = " ~ to!string(this.hub.query) ~ newline;
			if(isHub && !this.hub.edu) file ~= "favicon = \"" ~ this.hub.favicon ~ "\"" ~ newline;
			if(isHub) file ~= "social = {}" ~ newline; //TODO
			if(isHub) with(this.hub.bedrock) {
				file ~= newline ~ "[bedrock]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
				file ~= "online-mode = false" ~ newline;
				file ~= "addresses = " ~ addressString(addresses) ~ newline;
				file ~= "accepted-protocols = " ~ serializeProtocols(protocols, supportedBedrockProtocols, latestBedrockProtocols) ~ newline;
				if(this.hub.edu) file ~= newline ~ "allow-vanilla-players = " ~ to!string(this.hub.allowVanillaPlayers);
			}
			if(isHub && !this.hub.edu) with(this.hub.java) {
				file ~= newline ~ "[java]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "motd = \"" ~ motd ~ "\"" ~ newline;
				file ~= "online-mode = false" ~ newline;
				file ~= "addresses = " ~ addressString(addresses) ~ newline;
				file ~= "accepted-protocols = " ~ serializeProtocols(protocols, supportedJavaProtocols, latestJavaProtocols) ~ newline;
			}
			if(type == ConfigType.node) with(this.node) {
				file ~= newline ~ "[hub]" ~ newline;
				file ~= "name = \"" ~ name ~ "\"" ~ newline;
				file ~= "password = \"" ~ password ~ "\"" ~ newline;
				file ~= "ip = \"" ~ ip ~ "\"" ~ newline;
				file ~= "port = " ~ to!string(port) ~ newline;
				file ~= "main = " ~ to!string(main) ~ newline;
			}
			if(type == ConfigType.node) with(this.node.bedrock) {
				file ~= newline ~ "[bedrock]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "accepted-protocols = " ~ serializeProtocols(protocols, supportedBedrockProtocols, latestBedrockProtocols) ~ newline;
			}
			if(type == ConfigType.node) with(this.node.java) {
				file ~= newline ~ "[java]" ~ newline;
				file ~= "enabled = " ~ to!string(enabled) ~ newline;
				file ~= "accepted-protocols = " ~ serializeProtocols(protocols, supportedJavaProtocols, latestJavaProtocols) ~ newline;
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
				file ~= newline ~ "[command]" ~ newline;
				foreach(command ; Commands) {
					file ~= command ~ " = " ~ to!string(mixin(command ~ "Command")) ~ newline;
				}
			}
			if(isHub) with(this.hub) {
				file ~= newline ~ "[rcon]" ~ newline;
				file ~= "enabled = " ~ to!string(rcon) ~ newline;
				file ~= "password = \"" ~ rconPassword ~ "\"" ~ newline;
				file ~= "addresses = " ~ addressString(rconAddresses) ~ newline;
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
	
	if(hasArg("--reset") || hasArg("-r")) remove(filename);
	
	config.load();
	
	if(hasArg("--update-config") || hasArg("-uc")) config.save();
	
	return config;

}

class ReleaseFiles : Files {

	public this(string assets, string temp) {
		super(assets, temp);
	}
	
	public override inout bool hasPluginAsset(Plugin plugin, string file) {
		return exists(this.assets ~ "plugins" ~ dirSeparator ~ plugin.name ~ dirSeparator ~ file);
	}
	
	public override inout void[] readPluginAsset(Plugin plugin, string file) {
		return read(this.assets ~ "plugins" ~ dirSeparator ~ plugin.name ~ dirSeparator ~ file);
	}

}

class CompressedFiles : Files {
	
	private ZipArchive archive;
	
	public this(ZipArchive archive, string temp) {
		super("", temp);
		this.archive = archive;
	}
	
	public override inout bool hasAsset(string file) {
		return !!(convert(file) in (cast()this.archive).directory);
	}
	
	public override inout void[] readAsset(string file) {
		auto member = (cast()this.archive).directory[convert(file)];
		if(member.expandedData.length != member.expandedSize) (cast()this.archive).expand(member);
		return cast(void[])member.expandedData;
	}
	
	public override inout bool hasPluginAsset(Plugin plugin, string file) {
		return this.hasAsset("plugins/" ~ plugin.name ~ "/" ~ file);
	}
	
	public override inout void[] readPluginAsset(Plugin plugin, string file) {
		return this.readAsset("plugins/" ~ plugin.name ~ "/" ~ file);
	}
	
	private static string convert(string file) {
		version(Windows) file = file.replace("\\", "/");
		while(file[$-1] == '/') file = file[0..$-1];
		return file;
	}
	
}

/**
 * Throws: ConvException
 */
Config.Hub.Address convertAddress(string str) {
	Config.Hub.Address address;
	auto s = str.split(":");
	if(s.length >= 2) {
		address.port = to!ushort(s[$-1]);
		address.ip = s[0..$-1].join(":");
		if(address.ip.startsWith("[")) address.ip = address.ip[1..$];
		if(address.ip.endsWith("]")) address.ip = address.ip[0..$-1];
	}
	return address;
}

string addressString(Config.Hub.Address[] addresses) {
	string[] ret;
	foreach(address ; addresses) {
		ret ~= address.toString();
	}
	return to!string(ret);
}
