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
/**
 * License: $(HTTP www.gnu.org/licenses/lgpl-3.0.html, GNU General Lesser Public License v3).
 * 
 * Source: $(HTTP www.github.com/sel-project/sel-server/blob/master/hub/sel/main.d, main.d)
 */
module main;

import std.conv : to;
import std.string : replace, toLower;

import sel.server;
import sel.settings;

void main(string[] args) {

	version(D_Ddoc) {

		// do not start the server when generating documentation

	} else {

		immutable action = args.length >= 2 ? args[1].toLower : "";

		if(action == "about") {

			import std.json : JSONValue;
			import std.stdio : writeln;
			import common.sel;

			auto json = JSONValue([
				"type": JSONValue("hub"),
				"software": JSONValue([
					"name": JSONValue(Software.name),
					"version": JSONValue(Software.displayVersion),
					"stable": JSONValue(Software.stable)
				])
			]);

			writeln(json.toString());

		} else if(action == "init") {

			Settings.reload();

		} else {

			new shared Server();

		}

	}

}
