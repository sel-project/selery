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
/**
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/lang.d, selery/lang.d)
 */
module selery.lang;

import std.algorithm : canFind;
import std.array : Appender;
import std.conv : to, ConvException;
import std.file : exists, read;
import std.path : dirSeparator;
import std.string;

import selery.config : Files;

deprecated("Use LanguageManager instead") alias Lang = LanguageManager;

/**
 * Stores translatable strings in various languages and provides
 * methods to translate them with the provided arguments.
 */
class LanguageManager {

	private const Files files;

	private string language;
	private string[] acceptedLanguages;

	private string[] additionalFolders;

	private TranslationManager[string][string] messages;
	public string[string][string] raw; // used for web admin

	public this(inout Files files) {
		this.files = files;
	}

	/**
	 * Loads languages in lang/system and lang/messages.
	 * Throws: RangeError if one of the given languages is not supported by the software.
	 */
	public typeof(this) load(string language, string[] acceptedLanguages) {
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
	public typeof(this) add(string dir) {
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
	public inout string translate(inout string message, inout(string)[] params, string language) {
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
	public inout string translate(string message, string lang) {
		return this.translate(message, [], language);
	}

	/// ditto
	public inout string translate(string message, string[] params=[]) {
		return this.translate(message, params, this.language);
	}

	/// ditto
	public inout string translate(inout Translation translation, string language) {
		return this.translate(translation.translatable.default_, translation.parameters, language);
	}

	/// ditto
	public inout string translate(inout Translation translation) {
		return this.translate(translation, this.language);
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
					this.raw[language][message] = text;
					immutable comment = text.indexOf("##");
					Element[] elements;
					string next;
					ptrdiff_t index = -1;
					foreach(i, c; text[0..comment==-1?$:comment]) {
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
					if(elements.length) this.messages[language][message] = TranslationManager(elements);
				}
			}
		}
	}

	private static struct TranslationManager {

		Element[] elements;

		public inout string build(inout(string)[] args) {
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

struct Translation {
	
	public Translatable translatable;
	public string[] parameters;
	
	public this(E...)(Translatable translatable, E parameters) {
		this.translatable = translatable;
		foreach(param ; parameters) {
			static if(is(typeof(param) : string) || is(typeof(param) == string[])) this.parameters ~= param;
			else this.parameters ~= param.to!string;
		}
	}
	
	public this(E...)(string default_, E parameters) {
		this(Translatable.all(default_), parameters);
	}
	
}

/**
 * Translation container for a multi-platform translation.
 * The `default_` translation should never be empty and it should be a string that can be
 * loaded from a language file.
 * The `minecraft` and `bedrock` strings can either be a client-side translated message
 * or empty. In that case the `default_` string is translated server-side and sent
 * to the client.
 * Example:
 * ---
 * // server-side string
 * Translatable("example.test");
 * 
 * // server-side for minecraft and client-side for bedrock
 * Translatable("description.help", "", "commands.help.description");
 * ---
 */
struct Translatable {
	
	//TODO move somewhere else	
	enum MULTIPLAYER_JOINED = all("multiplayer.player.joined");
	enum MULTIPLAYER_LEFT = all("multiplayer.player.left");
	
	public static nothrow @safe @nogc Translatable all(inout string translation) {
		return Translatable(translation, translation, translation);
	}
	
	public static nothrow @safe @nogc Translatable fromJava(inout string translation) {
		return Translatable(translation, translation, "");
	}
	
	public static nothrow @safe @nogc Translatable fromBedrock(inout string translation) {
		return Translatable(translation, "", translation);
	}
	
	/// Values.
	public string default_, java, bedrock;
	
}