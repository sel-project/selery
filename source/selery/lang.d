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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/lang.d, selery/lang.d)
 */
module selery.lang;

import std.algorithm : canFind;
import std.array : Appender;
import std.conv : to, ConvException;
import std.file : exists, read;
import std.json : parseJSON;
import std.path : dirSeparator;
import std.string : toUpper, toLower, endsWith, split, indexOf, strip;

import selery.config : Files;
import selery.plugin : Plugin;

deprecated("Use LanguageManager instead") alias Lang = LanguageManager;

/**
 * Stores translatable strings in various languages and provides
 * methods to translate them with the provided arguments.
 */
class LanguageManager {

	private const Files files;
	public immutable string[] acceptedLanguages;
	public immutable string language;

	private string[string] defaults;

	private TranslationManager[string][string] messages;
	public string[string][string] raw; // used for web admin

	public this(inout Files files, string language) {
		this.files = files;
		string[] accepted;
		bool languageAccepted = false;
		foreach(lang, countries; parseJSON(cast(string)files.readAsset("lang/languages.json")).object) {
			foreach(i, country; countries.array) {
				immutable code = lang ~ "_" ~ country.str.toUpper;
				accepted ~= code;
				if(i == 0) this.defaults[lang] = code;
			}
		}
		this.acceptedLanguages = accepted.idup;
		this.language = this.best(language);
	}

	public inout string best(string language) {
		language = language.toLower;
		// return full language matching full language (en_GB : en_GB)
		foreach(lang ; this.acceptedLanguages) {
			if(language == lang.toLower) return lang;
		}
		// return full language matching language only (en : en_GB)
		if(language.length >= 2) {
			auto d = language[0..2] in this.defaults;
			if(d) return *d;
		}
		// return server's language
		return this.language;
	}

	/**
	 * Loads languages in assets/lang/system and assets/lang/messages.
	 * Throws: RangeError if one of the given languages is not supported by the software.
	 */
	public inout void load() {
		foreach(type ; ["system", "messages"]) {
			foreach(lang ; acceptedLanguages) {
				immutable file = "lang/" ~ type ~ "/" ~ lang ~ ".lang";
				if(this.files.hasAsset(file)) this.add(lang, this.parseFile(cast(string)this.files.readAsset(file)));
			}
		}
	}

	/**
	 * Loads languages from plugin's assets files, located in plugins/$plugin/assets/lang.
	 */
	public inout string[string][string] loadPlugin(Plugin plugin) {
		immutable folder = "lang" ~ dirSeparator;
		string[string][string] ret;
		bool loadImpl(string lang, string file) {
			if(this.files.hasPluginAsset(plugin, file)) {
				ret[lang] = this.parseFile(cast(string)this.files.readPluginAsset(plugin, file));
				return true;
			} else {
				return false;
			}
		}
		foreach(lang ; acceptedLanguages) {
			if(!loadImpl(lang, folder ~ lang ~ ".lang")) loadImpl(lang, folder ~ lang[0..2] ~ ".lang");
		}
		return ret;
	}

	private inout string[string] parseFile(string data) {
		string[string] ret;
		foreach(string line ; split(data, "\n")) {
			immutable equals = line.indexOf("=");
			if(equals != -1) {
				immutable message = line[0..equals].strip;
				immutable text = line[equals+1..$].strip;
				if(message.length && message[0] != '#') ret[message] = text;
			}
		}
		return ret;
	}

	/**
	 * Adds messages using the given associative array of message:text.
	 */
	public void add(string language, string[string] messages) {
		foreach(message, text; messages) {
			this.raw[language][message] = text;
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
			if(elements.length) this.messages[language][message] = TranslationManager(elements);
		}
	}

	/// ditto
	public const void add(string language, string[string] messages) {
		(cast()this).add(language, messages);
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

	public static Translation server(E...)(string default_, E parameters) {
		return Translation(Translatable(default_), parameters);
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