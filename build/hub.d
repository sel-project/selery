/+ dub.sdl:
   name "sel-hub"
   authors "sel-project"
   targetType "executable"
   dependency "sel-server:common" path="../"
   dependency "sel-server:hub" path="../"
   dependency "plugin-loader:hub" path="../.sel/plugin-loader"
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
module buildhub;

import std.algorithm : canFind;
import std.conv : to;
import std.file : exists, read, write, mkdirRecurse;
import std.string : replace, toLower;

import sel.about : Software;
import sel.path : Paths;
import sel.hub.server;
import sel.hub.settings;

import pluginloader.hub : loadPlugins;

void main(string[] args) {

	Paths.create();

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

		writeln(Software.toJSON("hub").toString());

	} else if(action == "init") {

		Settings(false, arg("edu"), arg("realm")).load();

	} else {

		new shared Server(false, arg("edu"), arg("realm"), loadPlugins());

	}

}
