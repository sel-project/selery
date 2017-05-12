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
module sel.lang;

import std.algorithm : canFind;
import std.array : Appender;
import std.conv : to;
import std.file : exists, read;
import std.string;
import std.traits : isArray;

import sel.format : Text;

shared struct Lang {

	private static shared(Lang) instance;

	public static void init(string[] langs, string[] dirs) {
		instance = shared(Lang)(langs, dirs);
	}

	private shared string[] supported;
	private shared string[string][string] langs;

	// ["../res/lang/system/", "../plugins/example/lang/"]
	private shared this(string[] langs, string[] dirs) {
		this.supported = cast(shared)langs;
		foreach(string lang ; langs) {
			foreach(string ppath ; dirs) {
				string realpath = (ppath ~ lang ~ ".lang");
				if(!exists(realpath)) realpath = (ppath ~ lang.split("_")[0] ~ ".lang");
				if(exists(realpath)) {
					foreach(string line ; (cast(string)read(realpath)).split("\n")) {
						if(line.split("=").length > 1) this.langs[lang][line.split("=")[0].strip] = line.split("=")[1..$].join("=").strip;
					}
				}
			}
		}
	}

	private shared bool hasImpl(string lang, string str) {
		auto ptr = lang in this.langs;
		return ptr && str in *ptr;
	}
	
	private shared string getImpl(string lang, string str) {
		return this.langs[lang][str];
	}
	
	/**
	 * Checks if a string is loaded.
	 * Returns: true if the string was found, false otherwise
	 */
	public static bool has(string lang, string str) {
		return instance.hasImpl(lang, str);
	}
	
	/**
	 * Gets a string from the pool.
	 * Throws: RangeError if has(lang, str) is false
	 */
	public static string get(string lang, string str) {
		return instance.getImpl(lang, str);
	}

	public static string getBestLanguage(string lang) {
		if(lang.length < 5 || lang[2] != '_') return instance.supported[0];
		else if(instance.supported.canFind(lang)) return lang;
		else {
			foreach(supp ; instance.supported) {
				if(lang.startsWith(supp[0..2])) return supp;
			}
			return instance.supported[0];
		}
	}

	private static class Translatable {

		public abstract string build(string[]);

	}

	private static class Static : Translatable {

		private string str;

		public this(string str) {
			this.str = str;
		}

		public override string build(string[] args) {
			return this.str;
		}

	}
	
}

public string translate(Translation translation, string lang, string[] args=[]) {
	string message = translation.sel;
	if(Lang.has(lang, message)) {
		message = Lang.get(lang, message);
		foreach(i, arg; args) {
			//TODO faster solution
			message = message.replace("{" ~ to!string(i) ~ "}", arg);
		}
	}
	return message;
}

deprecated alias translateSel = translate;

struct Translation {

	enum CONNECTION_JOIN = Translation("connection.join", "multiplayer.player.joined", "multiplayer.player.joined");
	enum CONNECTION_LEFT = Translation("connection.left", "multiplayer.player.left", "multiplayer.player.left");

	public string sel, minecraft, pocket;

}

interface Messageable {

	public void sendMessage(E...)(E args) {
		static if(E.length && (is(E[0] == Text) && E.length > 1 && is(E[1] : Translation) || is(E[0] : Translation))) {
			string[] message_args;
			static if(is(E[0] == Text)) {
				alias _args = args[2..$];
			} else {
				alias _args = args[1..$];
			}
			foreach(arg ; _args) {
				static if(is(typeof(arg) : string) || (isArray!(typeof(arg)) && is(typeof(arg[0]) : string))) {
					message_args ~= arg;
				} else {
					message_args ~= to!string(arg);
				}
			}
			static if(is(E[0] == Text)) {
				this.sendColoredTranslationImpl(args[0], args[1], message_args);
			} else {
				this.sendTranslationImpl(args[0], message_args);
			}
		} else {
			Appender!string message;
			foreach(i, arg; args) {
				static if(is(typeof(arg) : string)) {
					message.put(arg);
				} else {
					message.put(to!string(arg));
				}
			}
			this.sendMessageImpl(message.data);
		}
	}
	
	protected void sendMessageImpl(string);
	
	protected void sendTranslationImpl(Translation, string[]);
	
	protected void sendColoredTranslationImpl(Text, Translation, string[]);

}
