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

import common.format : Text, writeln;
import common.path : Paths;
import common.sel;

enum size_t __GENERATOR__ = 6;

void main(string[] args) {

	mkdirRecurse(Paths.worlds);
	mkdirRecurse(Paths.resources);
	mkdirRecurse(Paths.plugins);
	mkdirRecurse(Paths.hidden);

	JSONValue[string] plugs; //plugs[location] = settingsfile

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

	//load plugins
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
			info[index].id = index;
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
				info[index].author = value["author"].str;
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

	// read activation file
	string active = Paths.resources ~ "plugins.txt";
	if(exists(active) && active.isFile) {
		foreach(string line ; (cast(string)read(active)).split("\n")) {
			string[] lsp = line.split(":");
			if(lsp.length == 2) {
				auto plugin = lsp[0].strip in info;
				if(plugin && lsp[1].strip.toLower == "off") {
					(*plugin).main.length = 0;
					(*plugin).active = false;
				}
			}
		}
	}

	// rewrite activation file
	string[] rewrite;
	foreach(string name ; sort(info.keys).release()) {
		auto plugin = *(name in info);
		if(!plugin.api || plugin.mod.length) {
			rewrite ~= plugin.id ~ ": " ~ (plugin.active ? "on" : "off");
		}
	}
	write(active, rewrite.join(newline) ~ newline);


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
				writeln(Text.white ~ "Loading plugin " ~ Text.blue ~ inf.name ~ Text.white ~ " by " ~ Text.aqua ~ inf.author ~ Text.white ~ " version " ~ Text.aqua ~ inf.vers);
			} else {
				writeln(Text.white ~ "Cannot load plugin " ~ Text.red ~ inf.name ~ Text.white ~ " because it has a different target API than the one required by this version of " ~ Software.name);
				inf.active = false;
			}
		}
	}

	string cfile = "";
	foreach(Info value ; ordered) {
		cfile ~= value.path ~ ";" ~ (value.active ? "+" : "-") ~ ";" ~ value.prior.to!string ~ ";" ~ value.name ~ ";" ~ value.author ~ ";" ~ value.vers ~ ";" ~ value.main ~ ";";
	}

	auto file = new ubyte[size_t.sizeof] ~ cast(ubyte[])compress(cfile);
	std.bitmanip.write(file, __GENERATOR__, 0);

	if(!exists(Paths.hidden ~ "data") || file != read(Paths.hidden ~ "data")) {

		write(Paths.hidden ~ "data", file);
		
		string imports = "";
		string loads = "";

		string paths = "";

		string[] fimports;

		foreach(Info value ; ordered) {
			if(value.active) {
				auto lang = value.path ~ "lang" ~ dirSeparator;
				if((value.main.length || value.api) && exists(lang) && lang.isDir) {
					// use full path
					version(Windows) {
						lang = executeShell("cd " ~ lang ~ " && cd").output.strip;
					} else {
						lang = executeShell("cd " ~ lang ~ " && pwd").output.strip;
					}
					if(!lang.endsWith(dirSeparator)) lang ~= dirSeparator;
					if(exists(lang)) paths ~= "`" ~ lang ~ "`, ";
				}
				if(value.main.length) {
					imports ~= "static import " ~ value.mod ~ ";" ~ newline;
				}
				loads ~= newline ~ "\t\tPlugin.create!(" ~ (value.main.length ? value.main : "Object") ~ ")(Plugin(`" ~ value.id ~ "`, `" ~ value.name ~ "`, `" ~ value.author ~ "`, `" ~ value.vers ~ "`, " ~ to!string(value.api) ~ ")),";
			}
		}

		if(paths.length > 2) paths = paths[0..$-2];
		
		// reset src/plugins
		if(exists("src" ~ dirSeparator ~ "plugins")) {
			foreach(string f ; dirEntries("src" ~ dirSeparator ~ "plugins", SpanMode.breadth)) {
				if(f.isFile) remove(f);
			}
		} else {
			mkdirRecurse("src" ~ dirSeparator ~ "plugins");
		}

		write("src" ~ dirSeparator ~ "plugins.d", "// This file has been automatically generated and it shouldn't be edited." ~ newline ~ "// date: " ~ Clock.currTime().toSimpleString().split(".")[0] ~ " " ~ Clock.currTime().timezone.dstName ~ newline ~ "// generator: " ~ to!string(__GENERATOR__) ~ newline ~ "// plugins: " ~ to!string(info.length) ~ newline ~ "module plugins;" ~ newline ~ newline ~ "import sel.plugin.plugin : Plugin;" ~ newline ~ newline ~ imports ~ newline ~ "enum string[] __plugin_lang_paths = [" ~ paths ~ "];" ~ newline ~ newline ~ "Plugin[] __load_plugins() {" ~ newline ~ newline ~ "\treturn [" ~ loads ~ newline ~ "\t];" ~ newline ~ newline ~ "}" ~ newline);

		// copy plugins into src/plugins
		foreach(p ; ordered) {
			if(p.active) {
				foreach(string f ; dirEntries(p.path, SpanMode.breadth)) {
					if(f.isFile) {
						mkdirRecurse("src" ~ dirSeparator ~ f[0..f.lastIndexOf(dirSeparator)]);
						write("src" ~ dirSeparator ~ f, read(f));
					}
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

	public string name = "Unknown plugin";
	public string author = "Unknown author";
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
