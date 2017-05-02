/+ dub.sdl:
   name "sel-lite"
   authors "sel-project"
   targetType "executable"
   dependency "sel-server" path="../"
   dependency "plugin-loader" path="../.sel/plugin-loader"
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
module buildlite;

import core.thread : Thread;

import std.algorithm : canFind;
import std.concurrency : LinkTerminated;
import std.conv : to;
import std.file : read, write, exists, mkdirRecurse;
import std.string : toLower;

import com.config;
import com.crash : logCrash;
import com.path : Paths;
import com.sel : Software;
import com.util : UnloggedException;

//import sel.plugin; // it seems that not importing this causes compiler errors

static import hub.server;
static import sel.server;

static import pluginloader.hub;
static import pluginloader.node;

void main(string[] args) {
	
	@property bool arg(string name) {
		if(exists(Paths.hidden ~ name)) {
			return to!bool(cast(string)read(Paths.hidden ~ name));
		} else {
			bool ret = args.canFind("-" ~ name);
			write(Paths.hidden ~ name, to!string(ret));
			return ret;
		}
	}

	immutable action = args.length >= 2 ? args[1].toLower : "";

	if(action == "about") {

		import std.json : JSONValue;
		import std.stdio : writeln;
		import com.sel;

		auto json = JSONValue([
			"type": JSONValue("lite"),
			"software": JSONValue([
				"name": JSONValue(Software.name),
				"version": JSONValue(Software.displayVersion),
				"stable": JSONValue(Software.stable)
			])
		]);

		writeln(json.toString());

	} else if(action == "init") {

		Config(ConfigType.lite, arg("edu"), arg("realm")).load();

	} else {
		
		try {

			new Thread({ new shared hub.server.Server(true, arg("edu"), arg("realm"), pluginloader.hub.loadPlugins()); }).start();
			
			new sel.server.Server(null, "", "", true, pluginloader.node.loadPlugins());
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("lite", sel.server.server is null ? "en_GB" : sel.server.server.settings.language, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(1);
			
		}
	}
	
}

