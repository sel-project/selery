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
module starter;

import std.algorithm : canFind;
import std.conv : to;
import std.file : exists, write, read;
import std.json : JSONValue, toJSON;
import std.stdio : writeln;

import selery.about : Software;
import selery.config : Config;

import config;

void start(ConfigType type, ref string[] args, void delegate(Config) startFunction) {

	if(args.canFind("--about") || args.canFind("-a")) {

		import std.system : endian;

		static if(__traits(compiles, import("notes.txt"))) {}
		
		JSONValue[string] json;
		json["type"] = cast(string)type;
		json["software"] = Software.toJSON();
		json["system"] = ["endian": JSONValue(cast(int)endian), "bits": JSONValue(size_t.sizeof*8)];
		json["build"] = ["date": JSONValue(__DATE__), "time": JSONValue(__TIME__), "timestamp": JSONValue(__TIMESTAMP__), "vendor": JSONValue(__VENDOR__), "version": JSONValue(__VERSION__)];
		static if(__traits(compiles, import("release.json"))) json["release"] = parseJSON(import("release"));
		else json["release"] = (JSONValue[string]).init;
		debug json["debug"] = true;
		else json["debug"] = false;
		auto j = JSONValue(json);
		writeln(toJSON(j, args.canFind("--pretty")));
		return;

	} else if(args.canFind("--changelog") || args.canFind("-c")) {
		
		static if(__traits(compiles, import("notes.txt")) && __traits(compiles, import("version.txt")) && Software.displayVersion == import("version.txt")) {
			import std.string : replace;
			writeln("Release notes for ", Software.name, " ", Software.displayVersion, ":\n\n", replace(import("notes.txt"), "\\n", "\n")); //TODO remove links
		} else {
			writeln("Release notes were not included in this build.");
		}
		return;
		
	}
	
	Config config = loadConfig(type, args);

	if(!args.canFind("--init") && !args.canFind("-i")) startFunction(config);

}
