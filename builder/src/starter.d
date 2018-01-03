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
module starter;

import std.algorithm : canFind;
import std.conv : to;
import std.file : exists, write, read;
import std.json : JSONValue;
import std.stdio : writeln;

import selery.about : Software;
import selery.config : Config;

import config;

public import config : ConfigType;

void start(ConfigType type, const string type_str, ref string[] args, void delegate(Config) startFunction) {

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
		return;

	}
	
	ubyte edu, realm; // 0 = keep config's, 1 = false, 2 = true

	for(size_t i=0; i<args.length; i++) {
		void remove(ref ubyte set) {
			set = true;
			args = args[0..i] ~ args[i+1..$];
		}
		if(args[i] == "-edu" || args[i] == "--edu") remove(edu);
		if(args[i] == "-realm" || args[i] == "--realm") remove(realm);
	}
	
	Config config = loadConfig(type, edu, realm);

	if(!args.canFind("--init") && !args.canFind("-i")) startFunction(config);

}
