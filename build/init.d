/+ dub.sdl:
   name "init"
   authors "sel-project"
   dependency "common" path="../common"
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

import com.format : Text, writeln;
import com.path : Paths;
import com.sel;

enum size_t __GENERATOR__ = 41;

void main(string[] args) {

	JSONValue[string] plugs; // plugs[location] = settingsfile

	void loadPlugin(string path) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		if(exists(path ~ "package.json")) {
			try {
				plugs[path] = parseJSON(cast(string)read(path ~ "package.json"));
			} catch(JSONException e) {
				writeln(Text.red ~ "JSONException whilst reading " ~ path ~ dirSeparator ~ "package.json: " ~ e.msg);
			}
		}
	}

	// load plugins in plugins folder
	if(exists(Paths.plugins)) {
		foreach(string ppath ; dirEntries(Paths.plugins, SpanMode.breadth)) {
			if(ppath[Paths.plugins.length+1..$].indexOf(dirSeparator) == -1) {
				if(ppath.isDir) {
					loadPlugin(ppath);
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
			plugin.id = index[index.lastIndexOf("/")+1..$];
			plugin.path = path;
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
			plugin.api = exists(path ~ "api.d");
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

	mkdirRecurse(Paths.hidden ~ "plugin-loader/src/pluginloader");
	version(Windows) {
		mkdirRecurse(Paths.hidden ~ "plugin-loader/.dub");
		write(Paths.hidden ~ "plugin-loader/.dub/version.json", JSONValue(["version": join([to!string(Software.major), to!string(Software.minor), to!string(__GENERATOR__)], ".")]).toString());
	}

	foreach(target ; ["hub", "node"]) {

		mkdirRecurse(Paths.hidden ~ "plugin-loader/" ~ target ~ "/src/pluginloader");
	
		size_t count = 0;
			
		string imports = "";
		string loads = "";
		string paths = "";

		string[] fimports;

		JSONValue[string] dub;
		dub["sel-server:" ~ target] = JSONValue(["path": "../../../"]);

		foreach(Info value ; ordered) {
			if(value.target == target && value.active) {
				count++;
				version(Windows) {
					mkdirRecurse(value.path ~ "/.dub");
					write(value.path ~ "/.dub/version.json", JSONValue(["version": value.vers]).toString());
				}
				dub[value.id] = ["path": value.path.startsWith(Paths.plugins) ? "../../../plugins/" ~ value.id : value.path];
				JSONValue[string] deps = ["sel-server:" ~ target: JSONValue(["path": "../../"])];
				auto dptr = "dependencies" in value.json;
				if(dptr && dptr.type == JSON_TYPE.OBJECT) {
					foreach(name, d; dptr.object) {
						if(name.length > 4 && name.startsWith("dub/")) deps[name[4..$]] = d;
					}
				}
				write(value.path ~ "dub.json", JSONValue([
					"name": JSONValue(value.id),
					"targetType": JSONValue("library"),
					"dependencies": JSONValue(deps),
					"versions": JSONValue([capitalize(target)])
				]).toString());
				auto lang = value.path ~ "lang";
				if((value.main.length || value.api) && exists(lang) && lang.isDir) {
					lang = "`" ~ buildNormalizedPath(absolutePath(lang)) ~ dirSeparator ~ "`";
				} else {
					lang = "null";
				}
				if(value.main.length) {
					imports ~= "static import " ~ value.mod ~ ";";
				}
				loads ~= "new PluginOf!(" ~ (value.main.length ? value.main : "Object") ~ ")(`" ~ value.id ~ "`,`" ~ value.name ~ "`," ~ value.authors.to!string ~ ",`" ~ value.vers ~ "`," ~ to!string(value.api) ~ "," ~ lang ~ "),";
			}
		}

		if(paths.length > 2) paths = paths[0..$-2];

		write(Paths.hidden ~ "plugin-loader/" ~ target ~ "/src/pluginloader/" ~ target ~ ".d", "module pluginloader." ~ target ~ ";import " ~ (target=="node" ? "sel.plugin" : "hub.util") ~ ".plugin : Plugin,PluginOf;" ~ imports ~ "Plugin[] loadPlugins(){return [" ~ loads ~ "];}");
		write(Paths.hidden ~ "plugin-loader/" ~ target ~ "/dub.json", JSONValue(["name": JSONValue(target), "targetType": JSONValue("library"), "dependencies": JSONValue(dub)]).toString());

	}

	write(Paths.hidden ~ "plugin-loader/dub.json", JSONValue([
		"name": JSONValue("plugin-loader"),
		"targetType": JSONValue("none"),
		"dependencies": JSONValue([
			"plugin-loader:hub": "*",
			"plugin-loader:node": "*"
		]),
		"subPackages": JSONValue([
			"./hub/",
			"./node/"
		])
	]).toString());

}

struct Info {

	public string target = "node";

	public JSONValue json;

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

}
