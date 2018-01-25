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
module init;

import std.algorithm : sort, canFind, clamp;
import std.array : join, split;
import std.ascii : newline;
import std.conv : ConvException, to;
import std.file;
import std.json;
import std.path : dirSeparator, buildNormalizedPath, absolutePath, relativePath;
import std.process : executeShell;
import std.regex : matchFirst, ctRegex;
import std.stdio : writeln;
import std.string;
import std.zip;

import selery.about;

import toml;
import toml.json;

enum size_t __GENERATOR__ = 38;

void main(string[] args) {

	string libraries;
	if(exists(".selery/libraries")) {
		// should be an absolute normalised path
		libraries = cast(string)read(".selery/libraries");
	} else {
		// assuming this file is executed in ../
		libraries = buildNormalizedPath(absolutePath(".."));
	}
	if(!libraries.endsWith(dirSeparator)) libraries ~= dirSeparator;
	
	bool portable = false;
	string type = "default";
	
	bool plugins = true;
	
	foreach(arg ; args) {
		switch(arg.toLower()) {
			case "--generate-files":
				write("version.txt", Software.displayVersion);
				write("build.txt", Software.stable ? "0" : "1");
				string[] notes;
				string history = cast(string)read("../docs/history.md");
				immutable v = "### " ~ Software.displayVersion;
				immutable start = history.indexOf(v) + v.length;
				immutable end = history[start..$].indexOf("##");
				write("notes.txt", history[start..(end==-1?$:end)].strip.replace("\n", "\\n"));
				return;
			case "--no-plugins":
				plugins = false;
				break;
			case "--portable":
				portable = true;
				break;
			case "default":
			case "classic":
			case "allinone":
			case "all-in-one":
				type = "default";
				break;
			case "hub":
				type = "hub";
				break;
			case "node":
				type = "node";
				break;
			default:
				break;
		}		
	}

	writeln("Loading plugins for " ~ Software.name ~ " " ~ Software.fullVersion ~ " configuration \"" ~ type ~ "\"");

	if(portable) {

		auto zip = new ZipArchive();

		// get all files in assets
		foreach(string file ; dirEntries("../assets/", SpanMode.breadth)) {
			immutable name = file[10..$].replace("\\", "/");
			if(file.isFile && !name.startsWith(".") && !name.endsWith(".ico") && (!name.startsWith("web/") || name.endsWith("/main.css") || name.indexOf("/res/") != -1)) {
				//TODO optimise .lang files by removing empty lines, windows endings and comments
				auto data = read(file);
				auto member = new ArchiveMember();
				member.name = name;
				member.expandedData(cast(ubyte[])(file.endsWith(".json") ? parseJSON(cast(string)data).toString() : data));
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

	bool loadPlugin(string path) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		foreach(pack ; ["plugin.toml", "plugin.json"]) {
			if(exists(path ~ pack)) {
				if(pack.endsWith(".toml")) {
					auto toml = parseTOML(cast(string)read(path ~ pack));
					toml["single"] = false;
					plugs[path] = toml;
					return true;
				} else {
					auto json = parseJSON(cast(string)read(path ~ pack));
					if(json.type == JSON_TYPE.OBJECT) {
						json["single"] = false;
						plugs[path] = TOMLDocument(toTOML(json).table);
						return true;
					}
				}
			}
		}
		return false;
	}
	
	void loadZippedPlugin(string path) {
		// unzip and load as normal plugin
		auto data = read(path);
		auto zip = new ZipArchive(data);
		immutable name = path[path.lastIndexOf("/")+1..$-4];
		immutable dest = ".selery/plugins/" ~ name ~ "/";
		bool update = true;
		if(exists(dest)) {
			if(exists(dest ~ "crc32")) {
				update = false;
				auto json = parseJSON(cast(string)read(dest ~ "crc32")).object;
				// compare file names
				if(sort(json.keys).release() != sort(zip.directory.keys).release()) update = true;
				else {
					// compare file's crc32
					foreach(name, member; zip.directory) {
						if(member.crc32 != json[name].integer) {
							update = true;
							break;
						}
					}
				}
			}
			if(update) {
				foreach(string file ; dirEntries(dest, SpanMode.breadth)) {
					if(file.isFile) remove(file);
				}
			}
		} else {
			mkdirRecurse(dest);
		}
		if(update) {
			JSONValue[string] files;
			foreach(name, member; zip.directory) {
				files[name] = member.crc32;
				if(!name.endsWith("/")) {
					zip.expand(member);
					if(name.indexOf("/") != -1) mkdirRecurse(dest ~ name[0..name.lastIndexOf("/")]);
					write(dest ~ name, member.expandedData);
				}
			}
			write(dest ~ "crc32", JSONValue(files).toString());
		}
		if(!loadPlugin(dest)) loadPlugin(dest ~ name);
	}

	void loadSinglePlugin(string location) {
		immutable name = location[location.lastIndexOf("/")+1..$-2].replace("-", "_");
		foreach(line ; split(cast(string)read(location), "\n")) {
			if(line.strip.startsWith("module") && line[6..$].strip.startsWith(name ~ ";")) {
				string main = name ~ ".";
				bool uppercase = true;
				foreach(c ; name) {
					if(c == '_') {
						uppercase = true;
					} else {
						if(uppercase) main ~= toUpper("" ~ c);
						else main ~= c;
						uppercase = false;
					}
				}
				plugs[location] = TOMLDocument(["name": TOMLValue(name.replace("_", "-")), "main": TOMLValue(main)]);
				break;
			}
		}
	}

	if(plugins) {

		// load plugins in plugins folder
		if(exists("../plugins")) {
			foreach(string ppath ; dirEntries("../plugins/", SpanMode.shallow)) {
				if(ppath.isDir) {
					loadPlugin(ppath);
				} else if(ppath.isFile && ppath.endsWith(".zip")) {
					loadZippedPlugin(ppath);
				} else if(ppath.isFile && ppath.endsWith(".d")) {
					loadSinglePlugin(ppath);
				}
			}
		}

	}

	Info[string] info;
	
	foreach(path, value; plugs) {
		Info plugin;
		plugin.name = value["name"].str;
		checkName(plugin.name);
		if(path.isFile) {
			plugin.single = buildNormalizedPath(absolutePath(path));
		} else {
			if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		}
		if(plugin.name !in info) {
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
				if(plugin.single.length) {
					plugin.mod = spl[0];
					plugin.main = main.str;
				} else {
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
			}
			if(plugin.single.length) {
				plugin.version_ = "~single";
			} else {
				foreach(string file ; dirEntries(plugin.path ~ "src", SpanMode.breadth)) {
					if(file.isFile && file.endsWith(dirSeparator ~ "api.d")) {
						plugin.api = true;
						break;
					}
				}
			}
			info[plugin.name] = plugin;
		} else {
			throw new Exception("Plugin '" ~ plugin.name ~ " at " ~ plugin.path ~ " conflicts with a plugin with the same name at " ~ info[plugin.name].path);
		}
	}

	auto ordered = info.values;

	// sort by priority (or alphabetically)
	sort!"a.priority == b.priority ? a.name < b.name : a.priority > b.priority"(ordered);

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
			if(api.length == 0 || api.canFind(Software.api)) {
				writeln(inf.name, " ", inf.version_, ": loaded");
			} else {
				writeln(inf.name, " ", inf.version_, ": cannot load due to wrong api ", api);
				inf.active = false;
			}
		}
	}
	
	JSONValue[string] builder;
	builder["name"] = "selery-builder";
	builder["targetType"] = "executable";
	builder["targetName"] = (type == "default" ? "selery" : ("selery-" ~ type)) ~ (portable ? "-" ~ Software.displayVersion : "");
	builder["targetPath"] = "..";
	builder["workingDirectory"] = "..";
	builder["sourceFiles"] = ["main/" ~ type ~ ".d", ".selery/builder.d"];
	builder["configurations"] = [["name": type]];
	builder["dependencies"] = [
		"selery": ["path": ".."],
		"toml": ["version": "~>0.4.0-rc.4"],
		"toml:json": ["version": "~>0.4.0-rc.4"],
	];
	builder["subPackages"] = new JSONValue[0];
	
	size_t count = 0;
		
	string imports = "";
	string loads = "";

	string[] fimports;
	
	if(!exists(".selery")) mkdir(".selery");

	foreach(ref value ; ordered) {
		if(value.active) {
			count++;
			if(value.single.length) {
				builder["sourceFiles"].array ~= JSONValue(relativePath(value.single));
			} else {
				JSONValue[string] sub;
				sub["name"] = value.name;
				sub["targetType"] = "library";
				sub["targetPath"] = ".." ~ dirSeparator ~ "libs";
				sub["configurations"] = [["name": "plugin"]];
				sub["dependencies"] = ["selery": ["path": ".."]];
				sub["sourcePaths"] = [relativePath(value.path ~ "src")];
				sub["importPaths"] = [relativePath(value.path ~ "src")];
				auto dptr = "dependencies" in value.toml;
				if(dptr && dptr.type == TOML_TYPE.TABLE) {
					foreach(name, d; dptr.table) {
						if(name.startsWith("dub:")) {
							sub["dependencies"][name[4..$]] = toJSON(d);
						} else {
							//TODO depends on another plugin
						}
					}
				}
				builder["subPackages"].array ~= JSONValue(sub);
				builder["dependencies"][":" ~ value.name] = "*";
			}
			string extra(string path) {
				auto ret = value.path ~ path;
				if((value.main.length || value.api) && exists(ret) && ret.isDir) {
					foreach(f ; dirEntries(ret, SpanMode.breadth)) {
						// at least one element inside
						if(f.isFile) return "`" ~ buildNormalizedPath(absolutePath(ret)) ~ dirSeparator ~ "`";
					}
				}
				return "null";
			}
			if(value.main.length) {
				imports ~= "static import " ~ value.mod ~ ";\n";
			}
			string load = "ret ~= new PluginOf!(" ~ (value.main.length ? value.main : "Object") ~ ")(`" ~ value.name ~ "`, " ~ value.authors.to!string ~ ", `" ~ value.version_ ~ "`, " ~ to!string(value.api) ~ ", " ~ extra("lang") ~ ", " ~ extra("textures") ~ ");";
			auto conditions = "conditions" in value.toml;
			if(conditions && conditions.type == TOML_TYPE.TABLE) {
				string[] conds;
				foreach(key, value; conditions.table) {
					if(value.type == TOML_TYPE.BOOL) conds ~= "cond!(`" ~ key ~ "`, is_node)(config, " ~ to!string(value.boolean) ~ ")";
				}
				load = "if(" ~ conds.join("&&") ~ "){ " ~ load ~ " }";
			}
			if(value.main.length) load = "static if(is(" ~ value.main ~ " : T)){ " ~ load ~ " }";
			if(value.single.length) load = "static if(is(" ~ value.main ~ " == class)){ " ~ load ~ " }";
			loads ~= "\t" ~ load ~ "\n";
		}
		
	}

	writeDiff(".selery/builder.d", "module pluginloader;\n\nimport selery.config : Config;\nimport selery.plugin : Plugin;\n\nimport condition;\n\n" ~ imports ~ "\nPlugin[] loadPlugins(alias PluginOf, T, bool is_node)(inout Config config){\n\tPlugin[] ret;\n" ~ loads ~ "\treturn ret;\n}");
	
	writeDiff("dub.json", JSONValue(builder).toString());

}

enum invalid = ["selery", "sel", "toml", "default", "hub", "node", "builder", "condition", "config", "starter", "pluginloader"];

void checkName(string name) {
	void error(string message) {
		throw new Exception("Cannot load plugin '" ~ name ~ "': " ~ message);
	}
	if(name.matchFirst(ctRegex!`[^a-z0-9\-]`)) error("Name contains characters outside the range a-z0-9-");
	if(name.length == 0 || name.length > 64) error("Invalid name length: " ~ name.length.to!string ~ " is not between 1 and 64");
	if(invalid.canFind(name)) error("Name is reserved");
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
	public string version_ = "~local";
	
	public string path;
	public string mod;
	public string main;

}
