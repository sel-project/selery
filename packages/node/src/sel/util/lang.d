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
module sel.util.lang;

import std.conv : to;

public import com.lang;

struct Variables(string n_name, E...) {

	alias name = n_name;

	mixin(variablesArgs!E);

}

private string variablesArgs(E...)() {
	string vars = "";
	string ctor = "public @safe @nogc this(";
	string ccon = "";
	string gets = "public @trusted string get(string var){ switch(var){";
	bool lstring = false;
	foreach(uint index, e; E) {
		static if(index % 2 == 0) {
			vars ~= "private E[" ~ to!string(index) ~ "]* n_";
			ctor ~= "E[" ~ to!string(index) ~ "]* ";
			lstring = is(e == string);
		} else {
			vars ~= e ~ ";";
			ctor ~= e ~ ",";
			ccon ~= "this.n_" ~ e ~ " = " ~ e ~ ";";
			gets ~= "case \"" ~ e ~ "\": return (*this.n_" ~ e ~ ")" ~ (!lstring ? ".to!string" : "") ~ ";";
		}
	}
	return vars ~ ctor[0..$-1] ~ "){" ~ ccon ~ "}" ~ gets ~ "default: return null;}}";
}

// interface for translatable content, shouldn't be used by the average user
interface ITranslatable {

	public @safe void translateStrings(string lang);

	public @safe void untranslateStrings();

}

/**
 * Object with a translatable property (or properties).
 * The property must be a string and must be visible and 
 * editable by a child class (for example it must be public,
 * protected or a public @property).
 * Params:
 * 		properties = The names of the properties to be translated
 * Example:
 * ---
 * class Test {
 *    
 *    public string name;
 * 
 *    public this(string name) {
 *       this.name = name;
 *    }
 * 
 * }
 * 
 * auto test = new Translatable!("this.name", Test)("{language.name}");
 * assert(test.name == "{language.name}");
 * 
 * ((ITranslate)test).translateString("en_GB");
 * assert(test.name == "English");
 * ---
 * Example:
 * ---
 * class Test {
 * 
 *    public string[3] messages;
 * 
 *    public this(string[3] messages) {
 *       this.messages = messages;
 *    }
 * 
 * }
 * 
 * // assuming that minigame.start = "The game will start in {1} minutes"
 * // note the constructor that has 1 argument more than the amount required by Test class
 * auto test = new Translatable!(["this.messages[0]", "this.messages[2]"], Test)(["{minigame.start}", "{minigame.start}", ""], ["2"]);
 * assert(test.messages == ["{minigame.start}", "{minigame.start}", ""]);
 * 
 * ((ITranslatable)test).translateStrings("en_GB");
 * assert(test.messages == ["The game will start in 2 minutes", "{minigame.start}", ""]);
 * ---
 */
template Translatable(string[] properties, T) if(is(T == class)) {

	class Translatable : T, ITranslatable {

		public string[][properties.length] params;

		private string[properties.length] cache;

		public @safe this(E...)(E args) {
			static if(E.length > 0 && (is(E[$-1] == string[][]) || is(E[$-1] == immutable(string)[][]))) {
				super(args[0..$-1]);
				this.params = args[$-1];
			} else {
				super(args);
			}
		}

		public override @safe void translateStrings(string lang) {
			mixin(translations!properties);
		}

		public override @safe void untranslateStrings() {
			mixin(untranslations!properties);
		}

	}

}

private @property string translations(string[] properties)() {
	string ret = "";
	foreach(uint index, string property; properties) {
		ret ~= property ~ " = translate(this.cache[" ~ to!string(index) ~ "] = " ~ property ~ ", lang, this.params[" ~ to!string(index) ~ "]);";
	}
	return ret;
}

private @property string untranslations(string[] properties)() {
	string ret = "";
	foreach(uint index, string property; properties) {
		ret ~= property ~ " = this.cache[" ~to!string(index) ~ "];";
	}
	return ret;
}

/// ditto
template Translatable(string property, T) if(is(T == class)) {

	class Translatable : T, ITranslatable {

		public string[] params;

		private string cache;

		public @safe this(E...)(E args) {
			static if(E.length > 0 && (is(E[$-1] == string[]) || is(E[$-1] == immutable(string)[]))) {
				super(args[0..$-1]);
				this.params = args[$-1];
			} else static if(__traits(compiles, T.__ctor(args))) {
				super(args);
			}
		}

		public override @safe void translateStrings(string lang) {
			mixin(property ~ " = translate(this.cache = " ~ property ~ ", lang, this.params);");
		}

		public override @safe void untranslateStrings() {
			mixin(property ~ " = this.cache;");
		}

	}

}
