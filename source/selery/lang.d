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
module selery.lang;

import std.algorithm : canFind;
import std.array : Appender;
import std.conv : to, ConvException;
import std.file : exists, read;
import std.string;
import std.traits : isArray, staticIndexOf;

import selery.format : Text;

shared struct Lang {

	private static shared(Lang) instance;

	public static void init(string[] langs, string[] dirs) {
		instance = shared(Lang)(langs, dirs);
	}

	private shared string[] supported;
	private shared Translatable[string][string] langs;

	// ["../res/lang/system/", "../plugins/example/lang/"]
	private shared this(string[] langs, string[] dirs) {
		this.supported = cast(shared)langs;
		foreach(string lang ; langs) {
			foreach(string ppath ; dirs) {
				string realpath = (ppath ~ lang ~ ".lang");
				if(!exists(realpath)) realpath = (ppath ~ lang.split("_")[0] ~ ".lang");
				if(exists(realpath)) {
					foreach(string line ; (cast(string)read(realpath)).split("\n")) {
						auto eq = line.split("=");
						if(eq.length > 1) {
							Element[] elements;
							immutable message = eq[1..$].join("=").strip;
							string next;
							ptrdiff_t index = -1;
							foreach(i, c; message) {
								if(index >= 0) {
									if(c == '}') {
										try {
											auto num = to!size_t(message[index+1..i]);
											if(next.length) {
												elements ~= Element(next);
												next.length = 0;
											}
											elements ~= Element(num);
										} catch(ConvException) {
											next ~= message[index..i+1];
										}
										index = -1;
									}
								} else {
									if(c == '{') {
										index = i;
									} else {
										next ~= c;
									}
								}
							}
							if(index >= 0) next ~= message[index..$];
							if(next.length) elements ~= Element(next);
							if(elements.length) this.langs[lang][eq[0].strip] = cast(shared)Translatable(elements);
						}
					}
				}
			}
		}
	}
	
	/**
	 * Gets the pointer to a translation from a combination
	 * of a language and a string that identifies a translation.
	 */
	public static shared(Translatable)* get(string lang, string str) {
		auto l = lang in instance.langs;
		return l ? str in *l : null;
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

	private static struct Translatable {

		Element[] elements;

		public shared string build(string[] args) {
			Appender!string ret;
			foreach(element ; this.elements) {
				if(element.isString) {
					ret.put(element.store.data);
				} else if(element.store.index < args.length) {
					ret.put(args[element.store.index]);
				}
			}
			return ret.data;
		}

	}

	private static struct Element {

		private union Store {
			string data;
			size_t index;
		}

		public Store store;
		public bool isString;

		public this(string data) {
			this.store.data = data;
			this.isString = true;
		}

		public this(size_t index) {
			this.store.index = index;
			this.isString = false;
		}

	}
	
}

/**
 * Translates a translatable elements into a string in the given language.
 */
public string translate(Translation translation, string lang, string[] args=[]) {
	auto t = Lang.get(lang, translation.sel);
	if(t) {
		return (*t).build(args);
	} else {
		return translation.sel;
	}
}

/**
 * Translation container for a multi-platform translation.
 * The `sel` translation should never be empty and it should be a string
 * loaded from a language file.
 * The `minecraft` and `pocket` strings can either be a client-side translated message
 * or empty. In that case the `sel` string is translated server-side and sent
 * to the client.
 * Example:
 * ---
 * // server-side string
 * Translation("example.test");
 * 
 * // server-side for minecraft and client-side for pocket
 * Translation("description.help", "", "commands.help.description");
 * ---
 */
struct Translation {

	enum DISCONNECT_CLOSED = all("disconnect.closed");
	enum DISCONNECT_TIMEOUT = all("disconnect.timeout");
	enum DISCONNECT_END_OF_STREAM = all("disconnect.endOfStream");
	enum DISCONNECT_LOST = all("disconnect.lost");
	enum DISCONNECT_SPAM = all("disconnect.spam");

	enum CONNECTION_JOIN = Translation("connection.join", "multiplayer.player.joined", "multiplayer.player.joined");
	enum CONNECTION_LEFT = Translation("connection.left", "multiplayer.player.left", "multiplayer.player.left");

	public static nothrow @safe @nogc Translation all(const string translation) {
		return Translation(translation, translation, translation);
	}

	/// Values.
	public string sel, minecraft, pocket;

}

/**
 * Interface implemented by a class that can receive raw
 * and translatable messages.
 */
interface Messageable {

	public void sendMessage(E...)(E args) {
		static if(isTranslation!E) {
			string[] message_args;
			Text[] formats;
			foreach(arg ; args[staticIndexOf!(Translation, E)+1..$]) {
				static if(is(typeof(arg) : string) || (isArray!(typeof(arg)) && is(typeof(arg[0]) : string))) {
					message_args ~= arg;
				} else {
					message_args ~= to!string(arg);
				}
			}
			foreach(arg ; args[0..staticIndexOf!(Translation, E)]) {
				formats ~= arg;
			}
			this.sendTranslationImpl(args[staticIndexOf!(Translation, E)], message_args, formats);
		} else {
			Appender!string message;
			foreach(i, arg; args) {
				static if(is(typeof(arg) == string)) {
					message.put(arg);
				} else static if(is(typeof(arg) : string)) {
					message.put(cast(string)arg);
				} else {
					message.put(to!string(arg));
				}
			}
			this.sendMessageImpl(message.data);
		}
	}
	
	protected void sendMessageImpl(string);
	
	protected void sendTranslationImpl(const Translation, string[], Text[]);

}

private bool isTranslation(E...)() {
	static if(staticIndexOf!(Translation, E) >= 0) {
		return isText!(E[0..staticIndexOf!(Translation, E)]);
	} else {
		return false;
	}
}

private bool isText(E...)() {
	static if(E.length == 0) {
		return true;
	} else {
		return is(E[0] == Text) && (E.length == 1 || isText!(E[1..$]));
	}
}
