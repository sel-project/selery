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
module common.lang;

import std.conv : to;
import std.file : exists, read;
import std.string;
import std.traits : EnumMembers;

import common.path : Paths;
import common.format : Text;

struct Lang {
	
	private static Lang instance;

	public static void init(string[] langs, string[] dirs) {
		instance = Lang(langs, dirs);
	}
	
	private string[string][string] langs;

	// ["../res/lang/", "resources/plugins/example/res/lang/"]
	private this(string[] langs, string[] dirs) {
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
		//add colours in all the languages
		string[string] colors;
		foreach(immutable color ; EnumMembers!Text) {
			mixin("colors[\"" ~ color.to!string ~ "\"] = \"" ~ color ~ "\";");
			mixin("colors[\"" ~ color.to!string.toLower ~ "\"] = \"" ~ color ~ "\";");
		}
		foreach(string lang, string[string] val; this.langs) {
			foreach(string cname, string color; colors) {
				this.langs[lang][cname] = color;
			}
		}
	}
	
	private @safe bool hasImpl(string lang, string str) {
		auto ptr = lang in this.langs;
		return ptr && str in *ptr;
	}
	
	private @safe string getImpl(string lang, string str) {
		return this.langs[lang][str];
	}
	
	/**
	 * Checks if a string is loaded.
	 * Returns: true if the string was found, false otherwise
	 */
	public static @safe bool has(string lang, string str) {
		return instance.hasImpl(lang, str);
	}
	
	/**
	 * Gets a string from the pool.
	 * Throws: RangeError if has(lang, str) is false
	 */
	public static @safe string get(string lang, string str) {
		return instance.getImpl(lang, str);
	}
	
}

/**
 * Translates the translatable content of a string between two brackets
 * and replaces the dollars symbols with the given parameters.
 * Params:
 * 		message = A string that may contain a translation
 * 		lang = The language to translate the string to in format
 * 		params = Optional parameters that will be used intead of dollar symbols
 * 		variables = instances of aliases to the Variable struct that contains specific variables
 * Returns: the new string, translated if possible
 * Standards:
 * 		The langauges are encoded as (ISO 639-1 language code)_(ISO 3166-1 alpha-2 country code).
 * 		If the language is not in the ISO 639-1 list ISO 639-3 is used instead.
 * Example:
 * ---
 * string simple = "{language.name}";
 * assert(simple.translate("en_GB") == "English (United Kingdom)");
 * 
 * string complex = "Test string ({}): {connection.join}";
 * assert(complex.translate("en_GB", ["12345", "Steve"]) == "Test string (12345): Steve joined the game");
 * 
 * string notranslate = "Don't! {{language.name}}";
 * assert(notranslate.translate("en_GB") == "Don't! {language.name}");
 * ---
 */
public @safe string translate(E...)(string message, string lang, string[] params, E variables) {
	size_t open = -1;
	for(size_t index=0; index<message.length; index++) {
		switch(message[index]) {
			case '{':
				if(index < message.length - 1 && message[index + 1] == '{') {
					message = message[0..index] ~ message[index+1..$];
				} else {
					open = index;
				}
				break;
			case '}':
				if(index < message.length - 1 && message[index + 1] == '}') {
					message = message[0..index] ~ message[index+1..$];
				} else {
					string translation = message[open+1..index];
					string msg = null;
					if(translation.length == 0) {
						// translated with next args
						if(params.length > 0) {
							// do not cause range errors
							msg = params[0];
							params = params[1..$];
						}
					} else if((){foreach(char c;translation){if(c<'0'||c>'9')return false;}return true;}()) {
						// translated with an argument
						auto i = to!size_t(translation);
						if(i < params.length) msg = params[i];
					} else {
						auto i = translation.indexOf(":");
						if(i >= 0) {
							// translated with a variable
							string name = translation[0..i];
							foreach(var ; variables) {
								if(var.name == name) {
									msg = var.get(translation[i+1..$]);
									break;
								}
							}
						} else if(Lang.has(lang, translation)) {
							// translated with a lang string
							msg = Lang.get(lang, translation);
						}
					}
					if(msg !is null) {
						message = message[0..open] ~ msg ~ message[index+1..$];
						index = open - 1;
						open = -1;
					}
				}
				break;
			default:
				break;
		}
	}
	return message;
}
