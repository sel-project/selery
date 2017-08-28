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

import std.algorithm : canFind;
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

		static struct Game {
			
			bool enabled;
			string motd;
			bool onlineMode;
			string[] addresses;
			ushort port;
			uint[] protocols;
			
			alias enabled this;
			
		}

		bool edu, realm;

		string displayName;
		
		Game java = Game(true, "", false, ["0.0.0.0"], ushort(25565), latestJavaProtocols);

		Game pocket = Game(true, "", false, ["0.0.0.0"], ushort(19132), latestPocketProtocols);
		
		bool allowVanillaPlayers = false;

		bool whitelist = false;

		bool blacklist = true;
		
		bool query = true;
		
		string language;
		
		string[] acceptedLanguages = LANGUAGES;
		
		string serverIp;
		
		string favicon = "favicon.png";
		
		bool panel = false;
		
		string[string] panelUsers;
		
		string[] panelAddresses = ["0.0.0.0"];
		
		ushort panelPort = 19134;
		
		bool rcon = false;
		
		string rconPassword;
		
		string[] rconAddresses = ["0.0.0.0"];
		
		ushort rconPort = 25575;
		
		bool web = false;
		
		string[] webAddresses = ["0.0.0.0", "::"];
		
		ushort webPort = 80;
		
		string googleAnalytics;
		
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

			this.displayName = this.java.motd = this.pocket.motd = (){
				switch(language[0..language.indexOf("_")]) {
					case "es": return "Un Servidor de Minecraft";
					case "it": return "Un Server di Minecraft";
					case "pt": return "Um Servidor de Minecraft";
					default: return "A Minecraft Server";
				}
			}();

			this.panelUsers["admin"] = randomPassword();
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

		Game java = Game(true, latestJavaProtocols);

		Game pocket = Game(true, latestPocketProtocols);

		uint maxPlayers = 20;

		uint gamemode = 0;

		uint difficulty = 2;

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

	public void reload() {}

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
