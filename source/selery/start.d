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
module selery.start;

import std.algorithm : canFind;
import std.conv : to;
import std.file : exists, write, read;
import std.json : JSONValue;
import std.stdio : writeln;

import selery.about : Software;
import selery.config : ConfigType, Config;
import selery.path : Paths;

/**
 * Returns: whether the application should be started
 */
bool startup(ConfigType type, const string type_str, ref string[] args, ref bool edu, ref bool realm) {

	args = args[1..$];

	if(args.canFind("--about") || args.canFind("-a")) {

		import std.system : endian;

		JSONValue[string] json;
		json["type"] = type_str;
		json["software"] = Software.toJSON();
		json["system"] = ["endian": JSONValue(cast(int)endian), "bits": JSONValue(size_t.sizeof*8)];
		json["build"] = ["date": JSONValue(__DATE__), "time": JSONValue(__TIME__), "timestamp": JSONValue(__TIMESTAMP__), "vendor": JSONValue(__VENDOR__), "version": JSONValue(__VERSION__)];
		debug {
			json["debug"] = true;
		} else {
			json["debug"] = false;
		}
		writeln(JSONValue(json));
		return false;

	}

	Paths.create();

	for(size_t i=0; i<args.length; i++) {
		void remove(ref bool set) {
			set = true;
			args = args[0..i] ~ args[i+1..$];
		}
		if(args[i] == "-edu") remove(edu);
		if(args[i] == "-realm") remove(realm);
	}

	void save(string t)() {
		if(exists(Paths.hidden ~ t)) {
			mixin(t) = to!bool(cast(string)read(Paths.hidden ~ t));
		} else {
			write(Paths.hidden ~ t, to!string(mixin(t)));
		}
	}
	save!"edu"();
	save!"realm"();

	if(args.canFind("--init") || args.canFind("-i")) {

		Config(type, edu, realm).load();
		return false;

	}

	return true;

}

/// ditto
bool startup(ConfigType type, const string type_str, ref string[] args) {
	bool edu, realm;
	return startup(type, type_str, args, edu, realm);
}
