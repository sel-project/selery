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
module selery.config;

import std.algorithm : canFind;
import std.conv : to;
import std.json : JSONValue;
import std.random : uniform;
import std.socket : getAddress;
import std.string : indexOf, startsWith;
import std.uuid : UUID, randomUUID;

import selery.about;
import selery.files : Files;
import selery.lang : Lang;

class Config {

	enum LANGUAGES = ["en_GB", "en_US", "it_IT"];

	UUID uuid;

	Files files;
	Lang lang;

	Hub hub;
	Node node;

	public this(UUID uuid=randomUUID()) {
		this.uuid = uuid;
	}

	static class Hub {

		static struct Address {

			string ip;
			ushort port;

			inout string toString() {
				return (this.ip.canFind(":") ? "[" ~ this.ip ~ "]" : this.ip) ~ ":" ~ this.port.to!string;
			}

		}

		static struct Game {
			
			bool enabled;
			string motd;
			bool onlineMode;
			Address[] addresses;
			uint[] protocols;
			
			alias enabled this;
			
		}

		bool edu, realm;

		string displayName;
		
		Game bedrock = Game(true, "", false, [Address("0.0.0.0", 19132)], supportedBedrockProtocols);
		
		Game java = Game(true, "", false, [Address("0.0.0.0", 25565)], supportedJavaProtocols);
		
		bool allowVanillaPlayers = false;

		bool whitelist = false;

		bool blacklist = true;
		
		bool query = true;
		
		string language;
		
		string[] acceptedLanguages = LANGUAGES;
		
		string serverIp;
		
		string favicon = "favicon.png";
		
		bool rcon = false;
		
		string rconPassword;
		
		Address[] rconAddresses = [Address("0.0.0.0", 25575)];
		
		bool webView = false;
		
		Address[] webViewAddresses = [Address("0.0.0.0", 80), Address("::", 80)];

		bool webAdmin = true;

		Address[] webAdminAddresses = [Address("127.0.0.1", 19134)];

		string webAdminPassword = "";

		uint webAdminMaxClients = 1;
		
		JSONValue social;
		
		string[] acceptedNodes;
		
		string hncomPassword;
		
		uint maxNodes = 0;
		
		ushort hncomPort = 28232;

		public this() {

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
				this.language = environment.get("LANG", "en_GB");
			}
			this.language = bestLanguage(this.language, this.acceptedLanguages);

			this.displayName = this.java.motd = this.bedrock.motd = (){
				switch(language[0..language.indexOf("_")]) {
					case "es": return "Un Servidor de Minecraft";
					case "it": return "Un Server di Minecraft";
					case "pt": return "Um Servidor de Minecraft";
					default: return "A Minecraft Server";
				}
			}();

			this.rconPassword = randomPassword();

			this.acceptedNodes ~= getAddress("localhost")[0].toAddrString();
		}

	}

	static class Node {

		static struct Game {

			bool enabled;
			uint[] protocols;

			alias enabled this;

		}

		Game java = Game(true, supportedJavaProtocols);

		Game bedrock = Game(true, supportedBedrockProtocols);

		uint maxPlayers = 20;

		uint gamemode = Gamemode.survival;

		uint difficulty = Difficulty.normal;

		bool depleteHunger = true;
		
		bool doDaylightCycle = true;

		bool doEntityDrops = true;

		bool doFireTick = true;
		
		bool doScheduledTicks = true;
		
		bool doWeatherCycle = true;

		bool naturalRegeneration = true;
		
		bool pvp = true;
		
		uint randomTickSpeed = 3;

		uint viewDistance = 10;
		
		bool aboutCommand = true;

		bool deopCommand = true;

		bool difficultyCommand = true;

		bool gamemodeCommand = true;

		bool gameruleCommand = true;

		bool helpCommand = true;

		bool kickCommand = true;

		bool listCommand = true;

		bool meCommand = true;

		bool opCommand = true;
		
		bool reloadCommand = true;

		bool sayCommand = true;

		bool seedCommand = true;

		bool setmaxplayersCommand = true;

		bool stopCommand = true;

		bool tellCommand = true;

		bool timeCommand = true;

		bool toggledownfallCommand = true;

		bool transferCommand = true;

		bool transferserverCommand = true;

		bool weatherCommand = true;

	}

	/**
	 * Loads the configuration for the first time.
	 */
	public void load() {}

	/**
	 * Reloads the configuration.
	 */
	public void reload() {}

	/**
	 * Saves the configuration.
	 */
	public void save() {}

}

enum Gamemode : ubyte {
	
	survival = 0, s = 0,
	creative = 1, c = 1,
	adventure = 2, a = 2,
	spectator = 3, sp = 3,
	
}

enum Difficulty : ubyte {
	
	peaceful = 0, p = 0,
	easy = 1, e = 0,
	normal = 2, n = 0,
	hard = 3, h = 0,
	
}

enum Dimension : ubyte {
	
	overworld = 0,
	nether = 1,
	end = 2,
	
}

public @property string randomPassword() {
	char[] password = new char[uniform!"[]"(8, 12)];
	foreach(ref char c ; password) {
		c = uniform!"[]"('a', 'z');
		if(!uniform!"[]"(0, 4)) c -= 32;
	}
	return password.idup;
}

//TODO move to selery/lang.d
public string bestLanguage(string lang, string[] accepted) {
	if(accepted.canFind(lang)) return lang;
	string similar = lang[0..lang.indexOf("_")+1];
	foreach(al ; accepted) {
		if(al.startsWith(similar)) return al;
	}
	return accepted.canFind("en_GB") ? "en_GB" : accepted[0];
}
