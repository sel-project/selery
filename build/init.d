/+ dub.sdl:
   name "init"
   authors "sel-project"
   license "LGPL-3.0"
   copyright "(c) 2016-2017 SEL"
   targetType "executable"
   dependency "sel-common" path="../common"
+/
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
module init;

import std.algorithm : sort, canFind, clamp;
import std.array : join, split;
import std.ascii : newline;
import std.conv : ConvException, to;
import std.file;
import std.json;
import std.path : dirSeparator, buildNormalizedPath, absolutePath;
import std.process : executeShell;
import std.string;

import sel.about;
import sel.format : Text, writeln;
import sel.path : Paths;

enum size_t __GENERATOR__ = 56;

void main(string[] args) {

	if(args.canFind("--version")) {
		static import std.stdio;
		return std.stdio.write(Software.displayVersion);
	}

	if(args.canFind("-p") || args.canFind("--portable")) {

		// init for portable (it'll be used only for lite.d)

		if(!exists("views")) mkdir("views");

		import std.zip;

		auto zip = new ZipArchive();

		// get all files in res
		foreach(string file ; dirEntries("../res/", SpanMode.breadth)) {
			if(file.isFile) {
				auto member = new ArchiveMember();
				member.name = file[7..$].replace("\\", "/");
				member.expandedData(cast(ubyte[])read(file));
				member.compressionMethod = CompressionMethod.deflate;
				zip.addMember(member);
			}
		}
		write("views/portable.zip", zip.build());

	} else if(exists("views/portable.zip")) {

		remove("views/portable.zip");
		rmdir("views");

	}

	Paths.create();

	string libraries;
	if(exists(Paths.hidden ~ "libraries")) {
		// should be an absolute normalised path
		libraries = cast(string)read(Paths.hidden ~ "libraries");
	} else {
		// assuming this file is executed in build/ and the libraries are in ../
		libraries = buildNormalizedPath(absolutePath("../"));
	}
	if(!libraries.endsWith(dirSeparator)) libraries ~= dirSeparator;

	JSONValue[string] plugs; // plugs[location] = settingsfile

	void loadPlugin(string path) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		foreach(pack ; ["sel.json", "package.json"]) {
			if(exists(path ~ pack)) {
				auto json = parseJSON(cast(string)read(path ~ pack));
				if(json.type == JSON_TYPE.OBJECT) {
					json["single"] = false;
					plugs[path] = json;
					return;
				}
			}
		}
	}

	void loadSinglePlugin(string location) {
		immutable expectedModule = location[location.lastIndexOf(dirSeparator)+1..$-2];
		auto file = cast(string)read(location);
		auto s = file.split("\n");
		if(s.length) {
			auto fl = s[0].strip;
			if(fl.startsWith("/+") && fl.endsWith(":")) {
				string pack;
				bool closed = false;
				s = s[1..$];
				while(s.length) {
					immutable line = s[0].strip;
					s = s[1..$];
					if(line == "+/") {
						closed = true;
						break;
					} else {
						pack ~= line;
					}
				}
				if(closed && s.length && s[0].strip == "module " ~ expectedModule ~ ";") {
					switch(fl[2..$-1].strip) {
						case "package.json":
						case "sel.json":
							auto json = parseJSON(pack);
							if(json.type == JSON_TYPE.OBJECT) {
								mkdirRecurse(Paths.hidden ~ "single" ~ dirSeparator ~ expectedModule ~ dirSeparator ~ "src");
								writeDiff(Paths.hidden ~ "single" ~ dirSeparator ~ expectedModule ~ dirSeparator ~ "src" ~ dirSeparator ~ expectedModule ~ ".d", file);
								json["single"] = true;
								plugs[Paths.hidden ~ "single" ~ dirSeparator ~ expectedModule] = json;
							}
							break;
						default:
							break;
					}
				}
			}
		}
	}

	// load plugins in plugins folder
	if(exists(Paths.plugins)) {
		foreach(string ppath ; dirEntries(Paths.plugins, SpanMode.breadth)) {
			if(ppath[Paths.plugins.length+1..$].indexOf(dirSeparator) == -1) {
				if(ppath.isDir) {
					loadPlugin(ppath);
				} else if(ppath.isFile && ppath.endsWith(".d")) {
					loadSinglePlugin(ppath);
				}
			}
		}
	}

	Info[string] info;
	
	foreach(path, value; plugs) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		string index = path.split(dirSeparator)[$-2];
		if(index !in info) {
			auto plugin = Info();
			plugin.json = value;
			plugin.id = index;
			plugin.path = buildNormalizedPath(absolutePath(path));
			if(!plugin.path.endsWith(dirSeparator)) plugin.path ~= dirSeparator;
			plugin.single = "single" in value && value["single"].type == JSON_TYPE.TRUE;
			auto target = "target" in value;
			if(target && target.type == JSON_TYPE.STRING) {
				plugin.target = target.str.toLower;
			}
			auto priority = "priority" in value;
			if(priority) {
				if(priority.type == JSON_TYPE.STRING) {
					immutable p = priority.str.toLower;
					plugin.priority = p == "high" ? 10 : (p == "medium" || p == "normal" ? 5 : 1);
				} else if(priority.type == JSON_TYPE.INTEGER) {
					plugin.priority = clamp(priority.integer.to!size_t, 1, 10);
				}
			}
			auto name = "name" in value;
			if(name && name.type == JSON_TYPE.STRING) {
				plugin.name = name.str;
			}
			auto authors = "authors" in value;
			auto author = "author" in value;
			if(authors && authors.type == JSON_TYPE.ARRAY) {
				foreach(a ; authors.array) {
					if(a.type == JSON_TYPE.STRING) {
						plugin.authors ~= a.str;
					}
				}
			} else if(author && author.type == JSON_TYPE.STRING) {
				plugin.authors = [author.str];
			}
			auto main = "main" in value;
			if(main && main.type == JSON_TYPE.STRING) {
				string[] spl = main.str.split(".");
				string[] m;
				foreach(string s ; spl) {
					if(s == s.idup.toLower) {
						m ~= s;
					} else {
						break;
					}
				}
				plugin.mod = m.join(".");
				plugin.main = main.str;
			}
			plugin.api = exists(path ~ "api.d"); //TODO
			if(plugin.single) {
				plugin.vers = "~single";
			}
			info[index] = plugin;
		}
	}

	auto ordered = info.values;

	// sort by priority (or alphabetically)
	sort!"a.priority == b.priority ? a.id < b.id : a.priority > b.priority"(ordered);

	// control api version
	foreach(ref inf ; ordered) {
		if(inf.active) {
			long[] api;
			auto ptr = "api" in inf.json;
			if(ptr) {
				if((*ptr).type == JSON_TYPE.INTEGER) {
					api ~= (*ptr).integer;
				} else if((*ptr).type == JSON_TYPE.ARRAY) {
					foreach(v ; (*ptr).array) {
						if(v.type == JSON_TYPE.INTEGER) api ~= v.integer;
					}
				} else if((*ptr).type == JSON_TYPE.OBJECT) {
					auto from = "from" in *ptr;
					auto to = "to" in *ptr;
					if(from && (*from).type == JSON_TYPE.INTEGER && to && (*to).type == JSON_TYPE.INTEGER) {
						foreach(a ; (*from).integer..(*to).integer+1) {
							api ~= a;
						}
					}
				}
			}
			if(!api.canFind(Software.api)) {
				writeln(Text.white ~ "Cannot load plugin " ~ Text.red ~ inf.name ~ Text.white ~ " because it has a different target API than the one required by this version of " ~ Software.name);
				inf.active = false;
			}
		}
	}

	version(Windows) {
		mkdirRecurse(Paths.hidden ~ "plugin-loader/.dub");
		write(Paths.hidden ~ "plugin-loader/.dub/version.json", JSONValue(["version": join([to!string(Software.major), to!string(Software.minor), to!string(__GENERATOR__)], ".")]).toString());
	}

	JSONValue[] loader;

	foreach(target ; ["hub", "node"]) {

		mkdirRecurse(Paths.hidden ~ "plugin-loader/" ~ target ~ "/src/pluginloader");
	
		size_t count = 0;
			
		string imports = "";
		string loads = "";
		string paths = "";

		string[] fimports;

		JSONValue[string] dub;
		dub["sel-" ~ target] = JSONValue(["path": libraries ~ target]);

		foreach(ref value ; ordered) {
			if(value.target == target && value.active) {
				count++;
				version(Windows) {
					mkdirRecurse(value.path ~ "/.dub");
					write(value.path ~ "/.dub/version.json", JSONValue(["version": value.vers]).toString());
				}
				dub[value.id] = ["path": value.path];
				if("dependencies" !in value.dub) value.dub["dependencies"] = (JSONValue[string]).init;
				value.dub["name"] = value.id;
				value.dub["targetType"] = "library";
				auto dptr = "dependencies" in value.json;
				if(dptr && dptr.type == JSON_TYPE.OBJECT) {
					foreach(name, d; dptr.object) {
						if(name.length > 4 && name.startsWith("dub:")) {
							value.dub["dependencies"][name[4..$]] = d;
						}
					}
				}
				value.dub["dependencies"]["sel-" ~ target] = ["path": libraries ~ target];
				string extra(string path) {
					auto ret = value.path ~ path;
					if((value.main.length || value.api) && exists(ret) && ret.isDir) {
						foreach(f ; dirEntries(ret, SpanMode.breadth)) {
							// at least one element inside
							return "`" ~ buildNormalizedPath(absolutePath(ret)) ~ dirSeparator ~ "`";
						}
					}
					return "null";
				}
				if(value.main.length) {
					imports ~= "static import " ~ value.mod ~ ";";
				}
				if(value.single) {
					//value.dub["sourceFiles"] = [buildNormalizedPath(absolutePath(Paths.plugins ~ value.id ~ ".d"))];
				}
				loads ~= "new PluginOf!(" ~ (value.main.length ? value.main : "Object") ~ ")(`" ~ value.id ~ "`,`" ~ value.name ~ "`," ~ value.authors.to!string ~ ",`" ~ value.vers ~ "`," ~ to!string(value.api) ~ "," ~ extra("lang") ~ "," ~ extra("textures") ~ "),";
			}
		}

		if(paths.length > 2) paths = paths[0..$-2];

		writeDiff(Paths.hidden ~ "plugin-loader/" ~ target ~ "/src/pluginloader/" ~ target ~ ".d", "module pluginloader." ~ target ~ ";import sel.plugin:Plugin;import sel." ~ target ~ ".plugin:PluginOf;" ~ imports ~ "Plugin[] loadPlugins(){return [" ~ loads ~ "];}");
		writeDiff(Paths.hidden ~ "plugin-loader/" ~ target ~ "/dub.json", JSONValue(["name": JSONValue(target), "targetType": JSONValue("library"), "dependencies": JSONValue(dub)]).toPrettyString());

	}

	writeDiff(Paths.hidden ~ "plugin-loader/dub.json", JSONValue([
		"name": JSONValue("plugin-loader"),
		"targetType": JSONValue("none"),
		"dependencies": JSONValue([
			"plugin-loader:hub": "*",
			"plugin-loader:node": "*"
		]),
		"subPackages": JSONValue(["hub", "node"])
	]).toPrettyString());

	foreach(value ; ordered) {
		writeDiff(value.path ~ "dub.json", JSONValue(value.dub).toPrettyString());
	}

}

void writeDiff(string location, const void[] data) {
	if(!exists(location) || read(location) != data) write(location, data);
}

struct Info {

	public string target = "node";

	public JSONValue json;

	public bool single = false;

	public bool active = true;
	public size_t priority = 1;

	public bool api;

	public string name = "";
	public string[] authors = [];
	public string vers = "~local";

	public string id;
	public string path;
	public string mod;
	public string main;

	public JSONValue[string] dub;

}
