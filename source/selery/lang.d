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
import std.path : dirSeparator;
import std.string;
import std.traits : isArray, staticIndexOf;

import selery.files : Files;
import selery.format : Text;

final class Lang {

	private const Files files;

	private string language;
	private string[] acceptedLanguages;

	private string[] additionalFolders;

	private Translatable[string][string] messages;

	public this(inout Files files) {
		this.files = files;
	}

	/**
	 * Loads languages in lang/system and lang/messages.
	 * Throws: RangeError if one of the given languages is not supported by the software.
	 */
	public Lang load(string language, string[] acceptedLanguages) {
		assert(acceptedLanguages.canFind(language));
		this.language = language;
		this.acceptedLanguages = acceptedLanguages;
		foreach(type ; ["system", "messages"]) {
			foreach(lang ; acceptedLanguages) {
				immutable file = "lang" ~ dirSeparator ~ type ~ dirSeparator ~ lang ~ ".lang";
				if(this.files.hasAsset(file)) this.loadImpl(lang, this.files.readAsset(file));
			}
		}
		foreach(dir ; this.additionalFolders) this.loadDir(dir);
		return this;
	}

	/**
	 * loads languages from a specific directory.
	 */
	public Lang add(string dir) {
		this.additionalFolders ~= dir;
		this.loadDir(dir);
		return this;
	}

	/**
	 * Translates a message in the given language with the given parameters.
	 * If the language is omitted the message is translated using the default
	 * language.
	 * Returns: the translated message if the language and the message exist or the message if not
	 */
	public inout string translate(string message, string language, string[] params=[]) {
		auto lang = language in this.messages;
		if(lang) {
			auto translatable = message in *lang;
			if(translatable) {
				return (*translatable).build(params);
			}
		}
		return message;
	}

	/// ditto
	public inout string translate(string message, string[] params=[]) {
		return this.translate(message, this.language, params);
	}

	/// ditto
	public inout string translate(inout Translation message, string language, string[] params=[]) {
		return this.translate(message.sel, language, params);
	}

	/// ditto
	public inout string translate(inout Translation message, string[] params=[]) {
		return this.translate(message.sel, this.language, params);
	}

	private void loadDir(string dir) {
		if(!dir.endsWith(dirSeparator)) dir ~= dirSeparator;
		foreach(language ; this.acceptedLanguages) {
			if(!this.loadFile(language, dir ~ language ~ ".lang")) this.loadFile(language, dir ~ language[0..language.indexOf("_")] ~ ".lang");
		}
	}

	private bool loadFile(string language, string file) {
		if(exists(file)) {
			this.loadImpl(language, read(file));
			return true;
		} else {
			return false;
		}
	}

	private void loadImpl(string language, void[] data) {
		foreach(string line ; split(cast(string)data, "\n")) {
			immutable equals = line.indexOf("=");
			if(equals != -1) {
				immutable message = line[0..equals].strip;
				immutable text = line[equals+1..$].strip;
				if(message.length) {
					Element[] elements;
					string next;
					ptrdiff_t index = -1;
					foreach(i, c; text) {
						if(index >= 0) {
							if(c == '}') {
								try {
									auto num = to!size_t(text[index+1..i]);
									if(next.length) {
										elements ~= Element(next);
										next.length = 0;
									}
									elements ~= Element(num);
								} catch(ConvException) {
									next ~= text[index..i+1];
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
					if(index >= 0) next ~= text[index..$];
					if(next.length) elements ~= Element(next);
					if(elements.length) this.messages[language][message] = Translatable(elements);
				}
			}
		}
	}

	private static struct Translatable {

		Element[] elements;

		public inout string build(string[] args) {
			Appender!string ret;
			foreach(element ; this.elements) {
				if(element.isString) {
					ret.put(element.data);
				} else if(element.index < args.length) {
					ret.put(args[element.index]);
				} else {
					ret.put("{");
					ret.put(to!string(element.index));
					ret.put("}");
				}
			}
			return ret.data;
		}

	}

	private static struct Element {

		union {
			string data;
			size_t index;
		}

		public bool isString;

		public this(string data) {
			this.data = data;
			this.isString = true;
		}

		public this(size_t index) {
			this.index = index;
			this.isString = false;
		}

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
	
	enum MULTIPLAYER_JOINED = all("multiplayer.player.joined");
	enum MULTIPLAYER_LEFT = all("multiplayer.player.left");

	public static nothrow @safe @nogc Translation all(const string translation) {
		return Translation(translation, translation, translation);
	}

	/// Values.
	public string sel, minecraft, pocket; //TODO change to selery

}

struct Message {

	private bool _ismsg;

	union {

		string message;
		Translation translation;

	}

	public this(string message) {
		this._ismsg = true;
		this.message = message;
	}

	public this(Translation translation) {
		this._ismsg = false;
		this.translation = translation;
	}
	
	public inout pure nothrow @property @safe @nogc bool isMessage() {
		return this._ismsg;
	}
	
	public inout pure nothrow @property @safe @nogc bool isTranslation() {
		return !this._ismsg;
	}

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
