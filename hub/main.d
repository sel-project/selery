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
import std.string : replace;

import sel.server;
import sel.settings;

void main(string[] args) {

	version(D_Ddoc) {

		// do not start the server when generating documentation

	} else {

		if(args.length >= 2 && args[1] == "about") {

			import std.stdio : writeln;
			import common.sel;
			writeln("{\"software\":\"" ~ Software.display ~ "\"}");

		} else {

			new shared Server();

		}

	}

}
