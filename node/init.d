/+ dub.json:
{
	"name": "sel-node-init",
	"authors": ["sel-project"],
	"dependencies": {
		"sel-common": {
			"path": "../common"
		}
	}
}
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

version(Windows) import core.sys.windows.winnt : FILE_ATTRIBUTE_HIDDEN;

import std.algorithm : sort, canFind, clamp;
import std.array : join, split, replace;
import std.ascii : newline;
static import std.bitmanip;
import std.conv : ConvException, to;
import std.datetime : Clock;
import std.file;
import std.json;
import std.path : dirSeparator;
import std.process : executeShell;
import std.random : uniform;
import std.stdio : writecmd = write;
import std.string;
import std.uuid : randomUUID;
import std.zlib : compress, UnCompress;

import common.config;
import common.format : Text, writeln;
import common.path : Paths;
import common.sel;

enum size_t __GENERATOR__ = 21;

void main(string[] args) {

	mkdirRecurse(Paths.hidden);

	Config config = Config(ConfigType.node, false, false);
	config.load();
	config.save();

	string[] protocols = ["module __protocols;"];

	protocols ~= "enum uint[] __minecraftProtocols = " ~ to!string(config.minecraft ? config.minecraft.protocols : new uint[0]) ~ ";";
	protocols ~= "enum uint[] __pocketProtocols = " ~ to!string(config.pocket ? config.pocket.protocols : new uint[0]) ~ ";";

	write("src" ~ dirSeparator ~ "__protocols.d", protocols.join(newline));

	JSONValue[string] plugs; // plugs[location] = settingsfile

	version(Windows) {
		setAttributes(Paths.hidden, FILE_ATTRIBUTE_HIDDEN);
	}

	string temp;
	if(exists(Paths.hidden ~ "temp")) {
		temp = cast(string)read(Paths.hidden ~ "temp");
	} else {
		temp = randomUUID.toString().toUpper();
		write(Paths.hidden ~ "temp", temp);
	}
	temp = tempDir() ~ dirSeparator ~ "sel" ~ dirSeparator ~ temp ~ dirSeparator;

	if(!exists(temp)) mkdirRecurse(temp);

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

	//TODO load plugins from config.plugins

	// load plugins
	if(exists(Paths.plugins)) {
		foreach(string ppath ; dirEntries(Paths.plugins, SpanMode.breadth)) {
			if(ppath[Paths.plugins.length+1..$].indexOf(dirSeparator) == -1) {
				if(ppath.isDir) {
					loadPlugin(ppath);
				} else if(ppath.isFile && ppath.endsWith(".ssa")) {
					string name = ppath[Paths.plugins.length..$-4];
					ubyte[] file = cast(ubyte[])read(ppath);
					if(file.length > 5 && cast(string)file[0..5] == "plugn") {
						file = file[5..$];
						auto pack = readPluginArchive(file);
						if(pack.type == JSON_TYPE.OBJECT) {
							auto vers = "version" in pack.object;
							if(vers && (*vers).type == JSON_TYPE.STRING) {
								bool copy = !exists(temp ~ name ~ dirSeparator ~ "package.json");
								if(!copy) {
									try {
										auto v = "version" in parseJSON(cast(string)read(temp ~ name ~ dirSeparator ~ "package.json"));
										copy = v && (*v).type == JSON_TYPE.STRING && (*v).str != (*vers).str;
									} catch(JSONException) {}
								}
								if(copy) {
									write(temp ~ name ~ ".sa", file);
									executeShell("cd " ~ temp ~ " && sel uncompress " ~ name ~ ".sa " ~ name);
									remove(temp ~ name ~ ".sa");
								}
							}
						}
					}
				}
			}
		}
	}

	// load plugins from temp
	foreach(string ppath ; dirEntries(temp, SpanMode.breadth)) {
		if(ppath[temp.length..$].indexOf(dirSeparator) == -1) {
			loadPlugin(ppath);
		}
	}

	Info[string] info;
	
	foreach(string path, JSONValue value; plugs) {
		if(!path.endsWith(dirSeparator)) path ~= dirSeparator;
		string index = path.split(dirSeparator)[$-2];
		if(index !in info || info[index].path.startsWith(temp)) {
			info[index] = Info();
			info[index].json = value;
			info[index].id = index[index.lastIndexOf("/")+1..$];
			info[index].path = path;
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
				info[index].vers = value["version"].str;
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
	
	size_t count = 0;
		
	string imports = "";
	string loads = "";

	string paths = "";

	string[] fimports;

	foreach(Info value ; ordered) {
		if(value.active) {
			count++;
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
			} else {
				lang = "null";
			}
			if(value.main.length) {
				imports ~= "static import " ~ value.mod ~ ";" ~ newline;
			}
			loads ~= newline ~ "\t\tnew PluginOf!(" ~ (value.main.length ? value.main : "Object") ~ ")(`" ~ value.id ~ "`, `" ~ value.name ~ "`, " ~ value.authors.to!string ~ ", `" ~ value.vers ~ "`, " ~ to!string(value.api) ~ ", " ~ lang ~ "),";
		}
	}

	if(paths.length > 2) paths = paths[0..$-2];

	write("src" ~ dirSeparator ~ "__plugins.d", "// This file has been automatically generated and it shouldn't be edited." ~ newline ~ "// date: " ~ Clock.currTime().toSimpleString().split(".")[0] ~ " " ~ Clock.currTime().timezone.dstName ~ newline ~ "// generator: " ~ to!string(__GENERATOR__) ~ newline ~ "// plugins: " ~ to!string(count) ~ newline ~ "module __plugins;" ~ newline ~ newline ~ "import sel.plugin.plugin : Plugin, PluginOf;" ~ newline ~ newline ~ imports ~ newline ~ "Plugin[] __load_plugins() {" ~ newline ~ newline ~ "\treturn [" ~ loads ~ newline ~ "\t];" ~ newline ~ newline ~ "}" ~ newline);

	// delete every folder that is not sel (so dub will not include it)
	foreach(string file ; dirEntries("src", SpanMode.breadth)) {
		if(file.isFile && !file.startsWith("src" ~ dirSeparator ~ "sel") && !file.split(dirSeparator).length >= 2) {
			remove(file);
		}
	}

	// copy to src
	foreach(plug ; ordered) {
		if(plug.active) {
			foreach(string file ; dirEntries(plug.path, SpanMode.breadth)) {
				if(file.isFile && file.endsWith(".d")) {
					immutable p = file[plug.path.length..$];
					mkdirRecurse("src" ~ dirSeparator ~ plug.id ~ dirSeparator ~ p[0..p.lastIndexOf(dirSeparator)+1]);
					write("src" ~ dirSeparator ~ plug.id ~ dirSeparator ~ p, read(file));
				}
			}
		}
	}

}

struct Info {

	public JSONValue json;

	public bool active = true;
	public string priority = "low";
	public size_t prior = 0;

	public size_t order;
	public bool api;

	public string name = "?";
	public string[] authors = [];
	public string vers = "1.0.0";

	public string id;
	public string path;
	public string mod;
	public string main;

}

JSONValue readPluginArchive(ref ubyte[] file) {
	if(file.length > 4) {
		size_t length = std.bitmanip.read!uint(file);
		if(length <= file.length) {
			UnCompress uc = new UnCompress();
			ubyte[] data = cast(ubyte[])uc.uncompress(file[0..length].dup);
			data ~= cast(ubyte[])uc.flush();
			auto json = parseJSON(cast(string)data);
			file = file[length..$];
			return json;
		}
	}
	return JSONValue.init;
}
