/*
 * Copyright (c) 2017-2019 sel-project
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

import std.algorithm : canFind, filter;
import std.array : array;
import std.conv : to;
import std.json : JSONValue, parseJSON;
import std.stdio : write, writeln;

import selery.about : Software;
import selery.config : Config;

import config;

void start(ConfigType type, ref string[] args, void delegate(Config) startFunction) {

	if(args.canFind("--about") || args.canFind("-a")) {

		import std.system : os, endian;
		
		import pluginloader : info;
		
		JSONValue[string] json;
		json["type"] = cast(string)type;
		json["portable"] = portable;
		json["software"] = Software.toJSON();
		json["system"] = ["os": JSONValue(os.to!string), "endian": JSONValue(endian.to!string), "bits": JSONValue(size_t.sizeof*8)];
		json["build"] = ["d": ["date": JSONValue(__DATE__), "time": JSONValue(__TIME__), "timestamp": JSONValue(__TIMESTAMP__), "vendor": JSONValue(__VENDOR__), "version": JSONValue(__VERSION__)]];
		if(type == ConfigType.default_) json["plugins"] = parseJSON(info);
		else json["plugins"] = parseJSON(info).array.filter!(a => a["target"].str == type).array;
		static if(__traits(compiles, import("build_git.json"))) json["build"]["git"] = parseJSON(import("build_git.json"));
		static if(__traits(compiles, import("build_ci.json"))) json["build"]["ci"] = parseJSON(import("build_ci.json"));
		debug json["build"]["debug"] = true;
		else json["build"]["debug"] = false;
		version(X86) json["system"]["arch"] = "x86";
		else version(X86_64) json["system"]["arch"] = "x86-64";
		else version(ARM) json["system"]["arch"] = "arm";
		else version(AArch64) json["system"]["arch"] = "aarch64";
		else json["system"]["arch"] = "unknown";
		if(args.canFind("--min")) write(JSONValue(json).toString());
		else writeln(JSONValue(json).toPrettyString());

	} else if(args.canFind("--changelog") || args.canFind("-c")) {
		
		static if(__traits(compiles, import("notes.txt")) && __traits(compiles, import("version.txt")) && Software.displayVersion == import("version.txt")) {
			import std.string : strip, split, endsWith;
			writeln("Release notes for ", Software.name, " ", Software.displayVersion, ":\n");
			foreach(note ; import("notes.txt").split("\\n\\n")) {
				string[] lines;
				foreach(line ; note.split("\\n")) {
					if(lines.length && !lines[$-1].endsWith(".")) lines[$-1] ~= " " ~ line.strip;
					else lines ~= line.strip;
				}
				foreach(line ; lines) {
					writeln(line);
				}
				writeln();
			}
		} else {
			writeln("Release notes were not included in this build.");
		}
		
	} else {
	
		Config config = loadConfig(type, args);

		if(!args.canFind("--init") && !args.canFind("-i")) startFunction(config);
		
	}

}
