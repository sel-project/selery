/+ dub.sdl:
   name "hub"
   authors "sel-project"
   targetType "executable"
   dependency "sel-common" path="../common"
   dependency "sel-hub" path="../hub"
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
import sel.config : ConfigType;
import sel.path : Paths;
import sel.start : startup;
import sel.hub.server;
import sel.hub.settings;

import pluginloader.hub : loadPlugins;

void main(string[] args) {

	bool edu, realm;

	if(startup(ConfigType.hub, "hub", args, edu, realm)) {

		new shared Server(false, edu, realm, loadPlugins());

	}

}
