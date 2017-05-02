/+ dub.sdl:
   name "init"
   authors "sel-project"
   dependency "sel-common" path="../packages/common"
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
import std.path : dirSeparator;
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
	
	foreach(string path, JSONValue value; plugs) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		string index = path.split(dirSeparator)[$-2];
		if(index !in info) {
			info[index] = Info();
			info[index].json = value;
			info[index].id = index[index.lastIndexOf("/")+1..$];
			info[index].path = path;
			if("target" in value && value["target"].type == JSON_TYPE.STRING) {
				info[index].target = value["target"].str;
			}
			if("priority" in value && value["priority"].type == JSON_TYPE.STRING) {
				info[index].priority = value["priority"].str;
			}
			if("priority" in value && value["priority"].type == JSON_TYPE.INTEGER) {
				size_t i = value["priority"].integer.to!size_t;
				info[index].prior = i > 10 ? 10 : (i < 0 ? 0 : i);
			}
			if("name" in value && value["name"].type == JSON_TYPE.STRING) {
				info[index].name = value["name"].str;
			}
			if("author" in value && value["author"].type == JSON_TYPE.STRING) {
				info[index].authors = [value["author"].str];
			}
			if("authors" in value && value["authors"].type == JSON_TYPE.ARRAY) {
				foreach(author ; value["authors"].array) {
					if(author.type == JSON_TYPE.STRING) {
						info[index].authors ~= author.str;
					}
				}
			}
			if("version" in value && value["version"].type == JSON_TYPE.STRING) {
				//info[index].vers = value["version"].str;
			}
			if("main" in value && value["main"].type == JSON_TYPE.STRING) {
				string main = value["main"].str;
				string[] spl = main.split(".");
				string[] m;
				foreach(string s ; spl) {
					if(s == s.idup.toLower) {
						m ~= s;
					} else {
						break;
					}
				}
				info[index].mod = m.join(".");
				info[index].main = main;
			}
			info[index].api = exists(path ~ "api.d");
		}
	}

	// order
	Info[] ordered = info.values;
	foreach(ref inf ; ordered) {
		inf.prior = inf.priority == "high" ? 10 : (inf.priority == "medium" ? 5 : clamp(inf.prior, 0, 10));
	}
	sort!"a.prior == b.prior ? a.id < b.id : a.prior > b.prior"(ordered);

	// control api version
	foreach(ref Info inf ; ordered) {
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
			if(api.canFind(Software.api)) {
				//writeln(Text.white ~ "Loading plugin " ~ Text.blue ~ inf.name ~ Text.white ~ " version " ~ Text.aqua ~ inf.vers);
			} else {
				writeln(Text.white ~ "Cannot load plugin " ~ Text.red ~ inf.name ~ Text.white ~ " because it has a different target API than the one required by this version of " ~ Software.name);
				inf.active = false;
			}
		}
	}

	foreach(target ; ["hub", "node"]) {

		mkdirRecurse(Paths.hidden ~ "plugin-loader/" ~ target ~ "/src");

		version(Windows) {
			mkdirRecurse(Paths.hidden ~ "plugin-loader/" ~ target ~ "/.dub");
			write(Paths.hidden ~ "plugin-loader/" ~ target ~ "/.dub/version.json", JSONValue(["version": join([to!string(Software.major), to!string(Software.minor), to!string(__GENERATOR__)], ".")]).toString());
		}
	
		size_t count = 0;
			
		string imports = "";
		string loads = "";

		string paths = "";

		string[] fimports;

		JSONValue[string] dub;
		dub["sel-" ~ target] = JSONValue(["path": "../../../packages/" ~ target]);

		foreach(Info value ; ordered) {
			if(value.target == target && value.active) {
				count++;
				version(Windows) {
					mkdirRecurse(value.path ~ "/.dub");
					write(value.path ~ "/.dub/version.json", JSONValue(["version": value.vers]).toString());
				}
				dub[value.id] = ["path": value.path.startsWith(Paths.plugins) ? "../../../plugins/" ~ value.id : value.path];
				JSONValue[string] deps = ["sel-" ~ target: JSONValue(["path": "../../packages/" ~ target])];
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
				auto lang = value.path ~ "lang" ~ dirSeparator;
				if((value.main.length || value.api) && exists(lang) && lang.isDir) {
					// use full path
					version(Windows) {
						lang = executeShell("cd " ~ lang ~ " && cd").output.strip;
					} else {
						lang = executeShell("cd " ~ lang ~ " && pwd").output.strip;
					}
					if(!lang.endsWith(dirSeparator)) lang ~= dirSeparator;
					if(exists(lang)) lang = "`" ~ lang ~ "`";
					else lang = "null";
				} else {
					lang = "null";
				}
				if(value.main.length) {
					imports ~= "static import " ~ value.mod ~ ";";
				}
				loads ~= "new PluginOf!(" ~ (value.main.length ? value.main : "Object") ~ ")(`" ~ value.id ~ "`, `" ~ value.name ~ "`, " ~ value.authors.to!string ~ ", `" ~ value.vers ~ "`, " ~ to!string(value.api) ~ ", " ~ lang ~ "),";
			}
		}

		if(paths.length > 2) paths = paths[0..$-2];

		write(Paths.hidden ~ "plugin-loader/" ~ target ~ "/src/pluginloader.d", "module plugindata;import " ~ (target=="node" ? "sel.plugin" : "hub.util") ~ ".plugin : Plugin, PluginOf;" ~ imports ~ "Plugin[] loadPlugins(){ return [" ~ loads ~ "]; }");

		write(Paths.hidden ~ "plugin-loader/" ~ target ~ "/dub.json", JSONValue(["name": JSONValue(target ~ "-plugin-loader"), "targetType": JSONValue("library"), "dependencies": JSONValue(dub)]).toString());

	}

}

struct Info {

	public string target = "node";

	public JSONValue json;

	public bool active = true;
	public string priority = "low";
	public size_t prior = 0;

	public size_t order;
	public bool api;

	public string name = "";
	public string[] authors = [];
	public string vers = "~local";

	public string id;
	public string path;
	public string mod;
	public string main;

}
