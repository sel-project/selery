/++ dub.sdl:
name "selery-init"
dependency "toml" version="~>0.4.0-rc.3"
dependency "toml:json" version="~>0.4.0-rc.3"
+/
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
module init;

import std.algorithm : sort, canFind, clamp;
import std.array : join, split;
import std.ascii : newline;
import std.conv : ConvException, to;
import std.file;
import std.json;
import std.path : dirSeparator, buildNormalizedPath, absolutePath;
import std.process : executeShell;
import std.stdio : writeln;
import std.string;

import toml;
import toml.json;

enum size_t __GENERATOR__ = 10;

void main(string[] args) {

	string type = "default";
	
	if(args.length > 1) type = args[1].toLower();
	
	if(!["default", "hub", "node", "portable"].canFind(type)) {
		writeln("Invalid type: ", type);
		return;
	}

	string libraries;
	if(exists(".selery/libraries")) {
		// should be an absolute normalised path
		libraries = cast(string)read(".selery/libraries");
	} else {
		// assuming this file is executed in ../
		libraries = buildNormalizedPath(absolutePath(".."));
	}
	if(!libraries.endsWith(dirSeparator)) libraries ~= dirSeparator;
	
	auto software = loadAbout(libraries);

	writeln("Loading plugins for " ~ software.name ~ " " ~ software.version_ ~ " configuration \"" ~ type ~ "\"");

	if(type == "portable") {

		import std.zip;

		auto zip = new ZipArchive();

		// get all files in assets
		foreach(string file ; dirEntries("../assets/", SpanMode.breadth)) {
			if(file.isFile) {
				auto member = new ArchiveMember();
				member.name = file[7..$].replace("\\", "/");
				member.expandedData(cast(ubyte[])read(file));
				member.compressionMethod = CompressionMethod.deflate;
				zip.addMember(member);
			}
		}
		mkdirRecurse("views");
		write("views/portable.zip", zip.build());

	} else if(exists("views/portable.zip")) {

		remove("views/portable.zip");
		rmdir("views");

	}

	TOMLDocument[string] plugs; // plugs[location] = settingsfile

	void loadPlugin(string path) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		foreach(pack ; ["selery.toml", "selery.json", "package.json"]) {
			if(exists(path ~ pack)) {
				if(pack.endsWith(".toml")) {
					auto toml = parseTOML(cast(string)read(path ~ pack));
					toml["single"] = false;
					plugs[path] = toml;
					return;
				} else {
					auto json = parseJSON(cast(string)read(path ~ pack));
					if(json.type == JSON_TYPE.OBJECT) {
						json["single"] = false;
						plugs[path] = TOMLDocument(toTOML(json).table);
						return;
					}
				}
			}
		}
	}

	void addSinglePlugin(string path, string mod, TOMLDocument toml) {
		//TODO name must not be a field
		toml["name"] = mod;
		plugs[path] = toml;
	}

	void loadSinglePlugin(string location) {
		immutable expectedModule = location[location.lastIndexOf("/")+1..$-2];
		auto file = cast(string)read(location);
		auto s = file.split("\n");
		if(s.length) {
			auto fl = s[0].strip;
			if(fl.startsWith("/+") && fl.endsWith(":")) {
				string[] pack;
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
						case "selery.toml":
							return addSinglePlugin(location, expectedModule, parseTOML(pack.join("\n")));
						case "selery.json":
						case "package.json":
							auto json = parseJSON(pack.join(""));
							return addSinglePlugin(location, expectedModule, TOMLDocument(toTOML(json).table));
						default:
							break;
					}
				}
			}
			addSinglePlugin(location, expectedModule, parseTOML(""));
		}
	}

	if(!args.canFind("--no-plugins")) {

		// load plugins in plugins folder
		if(exists("../plugins")) {
			foreach(string ppath ; dirEntries("../plugins/", SpanMode.breadth)) {
				if(ppath["../plugins/".length+1..$].indexOf(dirSeparator) == -1) {
					if(ppath.isDir) {
						loadPlugin(ppath);
					} else if(ppath.isFile && ppath.endsWith(".d")) {
						loadSinglePlugin(ppath);
					}
				}
			}
		}

	}

	Info[string] info;
	
	foreach(path, value; plugs) {
		Info plugin;
		plugin.id = plugin.name = value["name"].str; //TODO must be checked [a-z0-9_]{1,}
		if(path.isFile) {
			plugin.single = buildNormalizedPath(absolutePath(path));
		} else {
			if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
			plugin.single = "";
		}
		if(plugin.id !in info) {
			plugin.toml = value;
			plugin.path = buildNormalizedPath(absolutePath(path));
			if(!plugin.path.endsWith(dirSeparator)) plugin.path ~= dirSeparator;
			auto priority = "priority" in value;
			if(priority) {
				if(priority.type == TOML_TYPE.STRING) {
					immutable p = priority.str.toLower;
					plugin.priority = (p == "high" || p == "🔥") ? 10 : (p == "medium" || p == "normal" ? 5 : 1);
				} else if(priority.type == TOML_TYPE.INTEGER) {
					plugin.priority = clamp(priority.integer.to!size_t, 1, 10);
				}
			}
			auto authors = "authors" in value;
			auto author = "author" in value;
			if(authors && authors.type == TOML_TYPE.ARRAY) {
				foreach(a ; authors.array) {
					if(a.type == TOML_TYPE.STRING) {
						plugin.authors ~= a.str;
					}
				}
			} else if(author && author.type == TOML_TYPE.STRING) {
				plugin.authors = [author.str];
			}
			auto main = "main" in value;
			if(main && main.type == TOML_TYPE.STRING) {
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
			if(plugin.single.length) {
				plugin.vers = "~single";
			}
			info[plugin.id] = plugin;
		}
	}

	auto ordered = info.values;

	// sort by priority (or alphabetically)
	sort!"a.priority == b.priority ? a.id < b.id : a.priority > b.priority"(ordered);

	// control api version
	foreach(ref inf ; ordered) {
		if(inf.active) {
			long[] api;
			auto ptr = "api" in inf.toml;
			if(ptr) {
				if((*ptr).type == TOML_TYPE.INTEGER) {
					api ~= (*ptr).integer;
				} else if((*ptr).type == TOML_TYPE.ARRAY) {
					foreach(v ; (*ptr).array) {
						if(v.type == TOML_TYPE.INTEGER) api ~= v.integer;
					}
				} else if((*ptr).type == TOML_TYPE.TABLE) {
					auto from = "from" in *ptr;
					auto to = "to" in *ptr;
					if(from && (*from).type == TOML_TYPE.INTEGER && to && (*to).type == TOML_TYPE.INTEGER) {
						foreach(a ; (*from).integer..(*to).integer+1) {
							api ~= a;
						}
					}
				}
			}
			if(api.length == 0 || api.canFind(software.api)) {
				writeln(inf.name, " ", inf.vers, ": loaded");
			} else {
				writeln(inf.name, " ", inf.vers, ": cannot load due to wrong api ", api);
				inf.active = false;
			}
		}
	}
	
	JSONValue[string] builder;
	builder["name"] = "selery-builder";
	builder["targetPath"] = "..";
	builder["targetName"] = "selery-" ~ type;
	builder["targetType"] = "executable";
	builder["sourceFiles"] = ["loader/" ~ (type == "portable" ? "default" : type) ~ ".d", ".selery/builder.d"];
	builder["configurations"] = [["name": type]];
	builder["dependencies"] = ["selery": ["path": ".."]];
	
	size_t count = 0;
		
	string imports = "";
	string loads = "";
	string paths = "";

	string[] fimports;

	JSONValue[string] dub;
	dub["selery"] = JSONValue(["path": libraries]);

	foreach(ref value ; ordered) {
		if(value.active) {
			count++;
			if(!exists(".selery/plugins/" ~ value.id)) mkdirRecurse(".selery/plugins/" ~ value.id);
			string[] sourceFiles;
			if(value.single.length) {
				sourceFiles = [value.single];
			} else {
				/*value.dub["sourcePaths"] = [value.path ~ "src"];
				value.dub["importPaths"] = [value.path ~ "src"];*/
				foreach(string file ; dirEntries(value.path ~ "src", SpanMode.breadth)) {
					if(file.isFile) sourceFiles ~= file;
				}
			}
			value.dub["sourceFiles"] = sourceFiles;
			version(Windows) {
				mkdirRecurse(".selery/plugins/" ~ value.id ~ "/.dub");
				write(".selery/plugins/" ~ value.id ~ "/.dub/version.json", JSONValue(["version": value.vers]).toString());
			}
			builder["dependencies"][value.id] = ["path": ".selery/plugins/" ~ value.id];
			if("dependencies" !in value.dub) value.dub["dependencies"] = (JSONValue[string]).init;
			value.dub["name"] = value.id;
			value.dub["targetType"] = "library";
			value.dub["configurations"] = [JSONValue(["name": "plugin"])];
			auto dptr = "dependencies" in value.toml;
			if(dptr && dptr.type == TOML_TYPE.TABLE) {
				foreach(name, d; dptr.table) {
					if(name.startsWith("dub:")) {
						value.dub["dependencies"][name[4..$]] = toJSON(d);
					}
				}
			}
			value.dub["dependencies"]["selery"] = ["path": libraries];
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
			immutable load = "ret ~= new PluginOf!(" ~ (value.main.length ? value.main : "Object") ~ ")(`" ~ value.id ~ "`,`" ~ value.name ~ "`," ~ value.authors.to!string ~ ",`" ~ value.vers ~ "`," ~ to!string(value.api) ~ "," ~ extra("lang") ~ "," ~ extra("textures") ~ ");";
			if(value.main.length) {
				loads ~= "static if(is(" ~ value.main ~ " : T)){ " ~ load ~ " }";
			} else {
				loads ~= load;
			}
		}
		
	}

	if(paths.length > 2) paths = paths[0..$-2];

	writeDiff(".selery/builder.d", "module pluginloader;import selery.plugin:Plugin;" ~ imports ~ "Plugin[] loadPlugins(alias PluginOf, T)(){Plugin[] ret;" ~ loads ~ "return ret;}");

	foreach(value ; ordered) {
		writeDiff(".selery/plugins/" ~ value.id ~ "/dub.json", JSONValue(value.dub).toPrettyString());
	}
	
	writeDiff("dub.json", JSONValue(builder).toPrettyString());

}

void writeDiff(string location, const void[] data) {
	if(!exists(location) || read(location) != data) write(location, data);
}

struct Info {

	public TOMLDocument toml;

	public string single;

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

auto loadAbout(string libs) {

	struct About {
	
		string name;
		string version_;
		long api;
	
	}
	
	try {

		string file = cast(string)read(libs ~ "source/selery/about.d");
		
		T search(T)(string variable) {
			immutable data = split(file, variable ~ " =")[1].split(";")[0].strip;
			static if(is(T == string)) {
				return data[1..$-1];
			} else {
				return to!T(data);
			}
		}
		
		return About(search!string("name"), to!string(search!ubyte("major")) ~ "." ~ to!string(search!ubyte("minor")) ~ "." ~ to!string(search!ubyte("patch")), search!long("api"));
		
	} catch(Throwable) {}
	
	return About("Selery", "~unknown", 0);

}
