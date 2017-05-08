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

import core.thread : Thread, dur;

import std.algorithm : canFind;
import std.concurrency : LinkTerminated;
import std.conv : to;
import std.file : read, write, exists, mkdirRecurse;
import std.string : toLower;

import sel.about : Software;
import sel.config;
import sel.crash : logCrash;
import sel.path : Paths;
import sel.utils : UnloggedException;
import sel.network.hncom : TidAddress;
import sel.session.hncom : MessagePassingNode;

static import sel.hub.server;
static import sel.node.server;

static import pluginloader.hub;
static import pluginloader.node;

void main(string[] args) {

	static if(__traits(compiles, import("portable.txt"))) {
		// should be executed in an empty directory
		Paths.load("." ~ dirSeparator);
		mkdirRecurse(Paths.res);
		foreach(name, data; mixin(import("portable.txt"))) {
			if(name.indexOf("/") != -1) mkdirRecurse(Paths.res ~ name[0..name.lastIndexOf("/")]);
			write(Paths.res ~ name, data);
		}
	}
	
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

		import std.stdio : writeln;

		writeln(Software.toJSON("lite").toString());

	} else if(action == "init") {

		Config(ConfigType.lite, arg("edu"), arg("realm")).load();

	} else {

		new Thread({ new shared sel.hub.server.Server(true, arg("edu"), arg("realm"), pluginloader.hub.loadPlugins()); }).start();

		while(!MessagePassingNode.ready) Thread.sleep(dur!"msecs"(10)); //TODO add a limit in case of failure
		
		try {
			
			new sel.node.server.Server(new TidAddress(cast()MessagePassingNode.tid), "", "", true, pluginloader.node.loadPlugins());
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("node", sel.node.server.server is null ? "en_GB" : sel.node.server.server.settings.language, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(1);
			
		}
	}
	
}

