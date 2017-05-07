module com.config;

import std.algorithm : sort, uniq, filter, canFind;
import std.array : array;
import std.ascii : newline;
import std.conv : to;
import std.datetime : Clock;
import std.file : read, write, exists, tempDir;
import std.json;
import std.path : dirSeparator;
import std.process : environment;
import std.random : uniform;
import std.socket : getAddress, AddressFamily;
import std.string;
import std.traits : isArray, isAssociativeArray;

import com.sel;
import com.path : Paths;

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

		with(Software) file ~= "//" ~ newline ~ "//  " ~ name ~ " " ~ displayVersion ~ (stable ? " " : "-dev ") ~ codename ~ " " ~ codenameEmoji ~ newline;
		with(Clock.currTime()) file ~= "//  " ~ toSimpleString().split(".")[0] ~ " " ~ timezone.dstName ~ newline ~ "//" ~ newline;
		
		void protocols(string[][uint] s) {
			uint[] keys = s.keys;
			sort(keys);
			foreach(uint p ; keys) {
				file ~= "//  \t" ~ to!string(p) ~ ": " ~ s[p].to!string.replace("[", "").replace("]", "").replace("\"", "") ~ newline;
			}
		}
		if(edu) {
			file ~= "//  Minecraft: Education Edition supported protocols/versions:" ~ newline;
			protocols(supportedPocketProtocols);
			file ~= "//" ~ newline;
		} else {
			file ~= "//  Minecraft supported protocols/versions:" ~ newline;
			protocols(supportedMinecraftProtocols);
			file ~= "//" ~ newline;
			file ~= "//  Minecraft: Pocket Edition supported protocols/versions:" ~ newline;
			protocols(supportedPocketProtocols);
			file ~= "//" ~ newline;
		}
		
		file ~= "//  Documentation can be found at https://github.com/sel-project/sel-server/blob/master/README.md" ~ newline ~ "//" ~ newline;

		return file;

	}

	public void save() {

		string file = header ~ "{" ~ newline;

		if(type != ConfigType.node) file ~= "\t\"display-name\": \"A Minecraft Server\"," ~ newline;
		if(type != ConfigType.node && !edu) {
			file ~= "\t\"minecraft\": {" ~ newline;
			file ~= "\t\t\"enabled\": true," ~ newline;
			file ~= "\t\t\"motd\": \"A Minecraft Server\"," ~ newline;
			file ~= "\t\t\"online-mode\": false," ~ newline;
			file ~= "\t\t\"addresses\": [\"0.0.0.0\"]," ~ newline;
			file ~= "\t\t\"port\": 25565," ~ newline;
			file ~= "\t\t\"accepted-protocols\": " ~ to!string(latestMinecraftProtocols) ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= "\t\"pocket\": {" ~ newline;
			file ~= "\t\t\"enabled\": true," ~ newline;
			file ~= "\t\t\"motd\": \"A Minecraft Server\"," ~ newline;
			file ~= "\t\t\"online-mode\": false," ~ newline;
			file ~= "\t\t\"addresses\": [\"0.0.0.0\"]," ~ newline;
			file ~= "\t\t\"port\": 19132," ~ newline;
			file ~= "\t\t\"accepted-protocols\": " ~ to!string(latestPocketProtocols);
			if(edu) file ~= "," ~ newline ~ "\t\t\"allow-vanilla-players\": false";
			file ~= newline ~ "\t}," ~ newline;
		}
		if(type != ConfigType.hub) file ~= "\t\"max-players\": " ~ to!string(size_t.sizeof * 8) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"whitelist\": " ~ to!string(edu || realm) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"blacklist\": " ~ to!string(!edu && !realm) ~ "," ~ newline;
		if(type != ConfigType.node && !realm) file ~= "\t\"query\": " ~ to!string(!edu && !realm) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"language\": " ~ JSONValue(this.language).toString() ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"accepted-languages\": " ~ to!string(this.acceptedLanguages) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"server-ip\": \"\"," ~ newline;
		if(type != ConfigType.node && !edu) file ~= "\t\"icon\": \"favicon.png\"," ~ newline;
		if(type != ConfigType.hub) {
			file ~= "\t\"world\": {" ~ newline;
			file ~= "\t\t\"gamemode\": \"survival\"," ~ newline;
			file ~= "\t\t\"difficulty\": \"normal\"," ~ newline;
			file ~= "\t\t\"pvp\": true," ~ newline;
			file ~= "\t\t\"pvm\": true," ~ newline;
			file ~= "\t\t\"do-daylight-cycle\": true," ~ newline;
			file ~= "\t\t\"do-weather-cycle\": true," ~ newline;
			file ~= "\t\t\"random-tick-speed\": 3," ~ newline;
			file ~= "\t\t\"do-scheduled-ticks\": true" ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type != ConfigType.hub && !realm) file ~= "\t\"plugins\": []," ~ newline;
		/*if(type != ConfigType.node) {
			file ~= "\t\"panel\": {" ~ newline;
			file ~= "\t\t\"enabled\": false," ~ newline;
			file ~= "\t\t\"users\": " ~ JSONValue(this.panelUsers).toString() ~ "," ~ newline;
			file ~= "\t\t\"addresses\": " ~ replace(to!string(this.panelAddresses), ",", ", ") ~ newline;
			file ~= "\t},\n";
		}*/
		if(type != ConfigType.node) {
			file ~= "\t\"external-console\": {" ~ newline;
			file ~= "\t\t\"enabled\": false," ~ newline;
			file ~= "\t\t\"password\": \"" ~ randomPassword() ~ "\"," ~ newline;
			file ~= "\t\t\"addresses\": [\"0.0.0.0\"]," ~ newline;
			file ~= "\t\t\"port\": 19134," ~ newline;
			file ~= "\t\t\"remote-commands\": true," ~ newline;
			file ~= "\t\t\"accept-websockets\": true," ~ newline;
			file ~= "\t\t\"hash-algorithm\": \"sha256\"" ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= "\t\"rcon\": {" ~ newline;
			file ~= "\t\t\"enabled\": false," ~ newline;
			file ~= "\t\t\"password\": \"" ~ randomPassword() ~ "\"," ~ newline;
			file ~= "\t\t\"addresses\": [\"0.0.0.0\"]," ~ newline;
			file ~= "\t\t\"port\": 25575" ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type != ConfigType.node && !realm) {
			file ~= "\t\"web\": {" ~ newline;
			file ~= "\t\t\"enabled\": false," ~ newline;
			file ~= "\t\t\"addresses\": [\"0.0.0.0\", \"::\"]," ~ newline;
			file ~= "\t\t\"port\": 80" ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type == ConfigType.hub) {
			file ~= "\t\"hncom\": {" ~ newline;
			file ~= "\t\t\"accepted-addresses\": " ~ to!string(this.acceptedNodes) ~ "," ~ newline;
			file ~= "\t\t\"password\": \"\"," ~ newline;
			file ~= "\t\t\"max\": \"unlimited\"," ~ newline;
			file ~= "\t\t\"port\": 28232";
			version(Posix) {
				file ~= "," ~ newline ~ "\t\t\"use-unix-sockets\": false," ~ newline;
				file ~= "\t\t\"unix-socket-address\": \"" ~ this.hncomUnixSocketAddress ~ "\"";
			}
			file ~= newline ~ "\t}," ~ newline;
		}
		if(type != ConfigType.node) file ~= "\t\"google-analytics\": \"\"," ~ newline;
		if(type != ConfigType.node && !realm) file ~= "\t\"social\": {}," ~ newline;

		file = file[0..$-1-newline.length] ~ newline ~ "}" ~ newline;

		write(Paths.home ~ "sel.json", file);

	}

	public void load(bool update=true) {

		if(exists(Paths.home ~ "sel.json")) {

			bool add = false;
			string[] lines;

			foreach(line ; split(cast(string)read(Paths.home ~ "sel.json"), "\n")) {
				if(!add && line.strip.startsWith("{")) add = true;
				if(add) lines ~= line;
			}

			string file = lines.join("\n");

			if(update) write(Paths.home ~ "sel.json", header ~ file);

			auto json = parseJSON(file);

			T get(T)(JSONValue target) {
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
					foreach(key, value; target.object) {
						ret[key] = get!(typeof(ret[""]))(value);
					}
					return ret;
				} else static if(is(T == JSONValue)) {
					return target;
				} else static if(is(T == bool)) {
					return target.type == JSON_TYPE.TRUE;
				} else static if(is(T == float) || is(T == double) || is(T == real)) {
					return cast(T)target.floating;
				} else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
					return cast(T)target.integer;
				} else {
					static assert(0);
				}
			}

			void set(string jv, T)(ref T value) {
				try {
					mixin("value = get!T(json" ~ replace(to!string(jv.split(".")), ",", "][") ~ ");");
				} catch(JSONException) {}
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
			set!"plugins"(this.plugins);
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

			if("max-players" in json && json["max-players"].type == JSON_TYPE.STRING && json["max-players"].str.toLower == "unlimited") this.maxPlayers = 0;
			
			if("max-nodes" in json && json["max-nodes"].type == JSON_TYPE.STRING && json["max-nodes"].str.toLower == "unlimited") this.maxNodes = 0;

			if(social.type != JSON_TYPE.OBJECT) {
				social = parseJSON("{}");
			}

		} else if(update) {

			this.save();

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
