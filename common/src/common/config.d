module common.config;

import std.algorithm : sort;
import std.ascii : newline;
import std.conv : to;
import std.datetime : Clock;
import std.file : read, write, exists;
import std.json;
import std.random : uniform;
import std.socket : getAddress, AddressFamily;
import std.string : split, join, strip, replace, startsWith, toLower;
import std.traits : isArray, isAssociativeArray;

import common.sel;
import common.path : Paths;

enum ConfigType {

	hub,
	node,
	full

}

struct Config {

	public static struct Game {

		bool enabled;
		string motd;
		bool onlineMode;
		string[] addresses;
		uint[] protocols;

		alias enabled this;

	}

	ConfigType type;

	bool edu, realm;

	string displayName = "A Minecraft Server";

	Game minecraft, pocket;

	bool allowVanillaPlayers = false;

	uint maxPlayers = size_t.sizeof * 8;

	bool whitelist, blacklist;

	bool query;

	string language = "en_GB";

	string[] acceptedLanguages = ["en_GB", "it_IT"];

	string serverIp;

	string icon = "favicon.png";

	string gamemode = "survival";

	string difficulty = "normal";

	bool pvp = true;

	bool pvm = true;

	bool doDaylightCycle = true;

	bool doWeatherCycle = true;

	uint randomTickSpeed = 3;

	bool doScheduledTicks = true;

	string[string] plugins;

	bool panel = false;

	string[string] panelUsers;

	string[] panelAddresses;

	bool externalConsole = false;

	string externalConsolePassword;

	string[] externalConsoleAddresses = ["0.0.0.0:19134"];

	bool externalConsoleRemoteCommands = true;

	bool externalConsoleAcceptWebsockets = true;

	string externalConsoleHashAlgorithm = "sha256";

	bool rcon = false;

	string rconPassword;

	string[] rconAddresses = ["0.0.0.0:25575"];

	bool web = false;

	string[] webAddresses = ["*:80"];

	string googleAnalytics;

	JSONValue social = parseJSON("{}");

	string[] acceptedNodes;

	string hncomPassword;

	uint maxNodes = 0;

	ushort hncomPort = 28232;

	bool hncomUseUnixSockets = false;

	string hncomUnixSocketAddress;

	public this(ConfigType type, bool edu, bool realm) {

		this.type = type;
		this.edu = edu;
		this.realm = realm;

		this.minecraft = Game(!edu, "A Minecraft Server", false, ["0.0.0.0:25565"], latestMinecraftProtocols);
		this.pocket = Game(true, "A Minecraft Server", false, ["0.0.0.0:19132"], latestPocketProtocols);

		this.whitelist = edu || realm;
		this.blacklist = !edu && !realm;
		this.query = !edu && !realm;

		this.acceptedNodes ~= getAddress("localhost", 0)[0].addressFamily == AddressFamily.INET6 ? "::1" : "127.0.*.*";
		
		this.panelUsers = ["admin": randomPassword];
		this.externalConsolePassword = randomPassword;
		this.rconPassword = randomPassword;
		this.hncomUnixSocketAddress = "/tmp/sel/" ~ randomPassword;

	}

	private @property string header() {

		string file;

		with(Software) file ~= "//" ~ newline ~ "//  " ~ name ~ " " ~ displayVersion ~ (stable ? " " : "-dev ") ~ fullCodename ~ newline;
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
			file ~= "*" ~ newline;
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

		if(type != ConfigType.node) file ~= "\t\"display-name\": " ~ JSONValue(this.displayName).toString() ~ "," ~ newline;
		if(!edu) {
			file ~= "\t\"minecraft\": {" ~ newline;
			file ~= "\t\t\"enabled\": " ~ to!string(this.minecraft.enabled) ~ "," ~ newline;
			if(type != ConfigType.node) file ~= "\t\t\"motd\": " ~ JSONValue(this.minecraft.motd).toString() ~ "," ~ newline;
			if(type != ConfigType.node) file ~= "\t\t\"online-mode\": " ~ to!string(this.minecraft.onlineMode) ~ "," ~ newline;
			if(type != ConfigType.node) file ~= "\t\t\"addresses\": " ~ JSONValue(this.minecraft.addresses).toString() ~ "," ~ newline;
			file ~= "\t\t\"accepted-protcols\": " ~ to!string(this.minecraft.protocols) ~ newline;
			file ~= "\t}," ~ newline;
		}
		{
			file ~= "\t\"pocket\": {" ~ newline;
			file ~= "\t\t\"enabled\": " ~ to!string(this.pocket.enabled) ~ "," ~ newline;
			if(type != ConfigType.node) file ~= "\t\t\"motd\": " ~ JSONValue(this.pocket.motd).toString() ~ "," ~ newline;
			if(type != ConfigType.node) file ~= "\t\t\"online-mode\": " ~ to!string(this.pocket.onlineMode) ~ "," ~ newline;
			if(type != ConfigType.node) file ~= "\t\t\"addresses\": " ~ JSONValue(this.pocket.addresses).toString() ~ "," ~ newline;
			file ~= "\t\t\"accepted-protcols\": " ~ to!string(this.pocket.protocols);
			if(type != ConfigType.node && edu) file ~= "," ~ newline ~ "\t\t\"allow-vanilla-players\": " ~ to!string(this.allowVanillaPlayers);
			file ~= newline ~ "\t}," ~ newline;
		}
		if(type != ConfigType.hub) file ~= "\t\"max-players\": " ~ to!string(this.maxPlayers) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"whitelist\": " ~ to!string(this.whitelist) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"query\": " ~ to!string(this.query) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"language\": " ~ JSONValue(this.language).toString() ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"accepted-languages\": " ~ to!string(this.acceptedLanguages) ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"server-ip\": " ~ JSONValue(this.serverIp).toString() ~ "," ~ newline;
		if(type != ConfigType.node) file ~= "\t\"icon\": " ~ JSONValue(this.icon).toString() ~ "," ~ newline;
		if(type != ConfigType.hub) {
			file ~= "\t\"world\": {" ~ newline;
			file ~= "\t\t\"gamemode\": \"" ~ this.gamemode ~ "\"," ~ newline;
			file ~= "\t\t\"difficulty\": \"" ~ this.difficulty ~ "\"," ~ newline;
			file ~= "\t\t\"pvp\": " ~ to!string(this.pvp) ~ "," ~ newline;
			file ~= "\t\t\"pvm\": " ~ to!string(this.pvm) ~ "," ~ newline;
			file ~= "\t\t\"do-daylight-cycle\": " ~ to!string(this.doDaylightCycle) ~ "," ~ newline;
			file ~= "\t\t\"do-weather-cycle\": " ~ to!string(this.doWeatherCycle) ~ "," ~ newline;
			file ~= "\t\t\"random-tick-speed\": " ~ to!string(this.randomTickSpeed) ~ "," ~ newline;
			file ~= "\t\t\"do-scheduled-ticks\": " ~ to!string(this.doScheduledTicks) ~ newline;
			file ~= "\n}," ~ newline;
		}
		if(type != ConfigType.hub && !realm) file ~= "\t\"plugins: []," ~ newline;
		/*if(type != ConfigType.node) {
			file ~= "\t\"panel\": {" ~ newline;
			file ~= "\t\t\"enabled\": " ~ to!string(this.panel) ~ "," ~ newline;
			file ~= "\t\t\"users\": " ~ JSONValue(this.panelUsers).toString() ~ "," ~ newline;
			file ~= "\t\t\"addresses\": " ~ replace(to!string(this.panelAddresses), ",", ", ") ~ newline;
			file ~= "\t},\n";
		}*/
		if(type != ConfigType.node) {
			file ~= "\t\"external-console\": {" ~ newline;
			file ~= "\t\t\"enabled\": " ~ to!string(this.externalConsole) ~ "," ~ newline;
			file ~= "\t\t\"password\": " ~ JSONValue(this.externalConsolePassword).toString() ~ "," ~ newline;
			file ~= "\t\t\"addresses\": " ~ JSONValue(this.externalConsoleAddresses).toString() ~ "," ~ newline;
			file ~= "\t\t\"remote-commands\": " ~ to!string(this.externalConsoleRemoteCommands) ~ "," ~ newline;
			file ~= "\t\t\"accept-websockets\": " ~ to!string(this.externalConsoleAcceptWebsockets) ~ "," ~ newline;
			file ~= "\t\t\"hash-algorithm\": " ~ JSONValue(this.externalConsoleHashAlgorithm).toString() ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type != ConfigType.node) {
			file ~= "\t\"rcon\": {" ~ newline;
			file ~= "\t\t\"enabled\": " ~ to!string(this.rcon) ~ "," ~ newline;
			file ~= "\t\t\"password\": " ~ JSONValue(this.rconPassword).toString() ~ "," ~ newline;
			file ~= "\t\t\"addresses\": " ~ JSONValue(this.rconAddresses).toString() ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type != ConfigType.node && !realm) {
			file ~= "\t\"web\": {" ~ newline;
			file ~= "\t\t\"enabled\": " ~ to!string(this.web) ~ "," ~ newline;
			file ~= "\t\t\"addresses\": " ~ JSONValue(this.webAddresses).toString() ~ newline;
			file ~= "\t}," ~ newline;
		}
		if(type == ConfigType.hub) {
			file ~= "\t\"hncom\": {" ~ newline;
			file ~= "\t\t\"accepted-addresses\": " ~ to!string(this.acceptedNodes) ~ "," ~ newline;
			file ~= "\t\t\"password\": " ~ JSONValue(this.hncomPassword).toString() ~ "," ~ newline;
			file ~= "\t\t\"max\": " ~ (this.maxNodes==0 ? "\"unlimited\"" : to!string(this.maxNodes)) ~ "," ~ newline;
			file ~= "\t\t\"port\": " ~ to!string(this.hncomPort);
			version(Posix) {
				file ~= "," ~ newline ~ "\t\t\"use-unix-sockets\": " ~ to!string(this.hncomUseUnixSockets) ~ "," ~ newline;
				file ~= "\t\t\"unix-socket-address\": " ~ this.hncomUnixSocketAddress;
			}
			file ~= newline ~ "\t}," ~ newline;
		}
		if(type != ConfigType.node) file ~= "\t\"google-analytics\": " ~ JSONValue(this.googleAnalytics).toString() ~ "," ~ newline;
		if(type != ConfigType.node && !realm) file ~= "\t\"social\": " ~ this.social.toString() ~ "," ~ newline;

		file = file[0..$-1-newline.length] ~ newline ~ "}" ~ newline;

		write(Paths.home ~ "sel.json", file);

	}

	public void load() {

		if(exists(Paths.home ~ "sel.json")) {

			bool add = false;
			string[] lines;

			foreach(line ; split(cast(string)read(Paths.home ~ "sel.json"), "\n")) {
				if(!add && line.strip.startsWith("{")) add = true;
				if(add) lines ~= line;
			}

			string file = lines.join("\n");

			write(Paths.home ~ "sel.json", header ~ file);

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
			set!"minecraft.online-mode"(this.minecraft.onlineMode);
			set!"minecraft.addresses"(this.minecraft.addresses);
			set!"minecraft.accepted-protocols"(this.minecraft.protocols);
			set!"pocket.enabled"(this.pocket.enabled);
			set!"pocket.motd"(this.pocket.motd);
			set!"pocket.online-mode"(this.pocket.onlineMode);
			set!"pocket.addresses"(this.pocket.addresses);
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
			//set!"plugins"(this.plugins); // used in init.d
			set!"panel.enabled"(this.panel);
			set!"panel.users"(this.panelUsers);
			set!"panel.addresses"(this.panelAddresses);
			set!"external-console.enabled"(this.externalConsole);
			set!"external-console.password"(this.externalConsolePassword);
			set!"external-console.addresses"(this.externalConsoleAddresses);
			set!"external-console.remote-commands"(this.externalConsoleRemoteCommands);
			set!"external-console.accept-websockets"(this.externalConsoleAcceptWebsockets);
			set!"external-console.hash-algorithm"(this.externalConsoleHashAlgorithm);
			set!"rcon.enabled"(this.rcon);
			set!"rcon.password"(this.rconPassword);
			set!"rcon.addresses"(this.rconAddresses);
			set!"web.enabled"(this.web);
			set!"web.addresses"(this.webAddresses);
			set!"hncom.accepted-addresses"(this.acceptedNodes);
			set!"hncom.password"(this.hncomPassword);
			set!"hncom.max"(this.maxNodes);
			set!"hncom.port"(this.hncomPort);
			set!"hncom.use-unix-sockets"(this.hncomUseUnixSockets);
			set!"hncom.unix-socket-address"(this.hncomUnixSocketAddress);
			set!"google-analytics"(this.googleAnalytics);
			set!"social"(this.social);
			
			if("max-players" in json && json["max-players"].type == JSON_TYPE.STRING && json["max-players"].str.toLower == "unlimited") this.maxPlayers = 0;
			
			if("max-nodes" in json && json["max-nodes"].type == JSON_TYPE.STRING && json["max-nodes"].str.toLower == "unlimited") this.maxNodes = 0;

			if(social.type != JSON_TYPE.OBJECT) {
				social = parseJSON("{}");
			}

		} else {
			this.save();
		}

	}

}

private @property string randomPassword() {
	char[] password = new char[uniform!"[]"(8, 12)];
	foreach(ref char c ; password) {
		c = uniform!"[]"('a', 'z');
		if(!uniform!"[]"(0, 4)) c -= 32;
	}
	return password.idup;
}
