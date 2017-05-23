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
 * Source: $(HTTP www.github.com/sel-project/sel-server/blob/master/hub/sel/util/log.d, sel/util/log.d)
 */
module sel.util.logh;

import std.conv : to;

import sel.format : writeln;

void log(E...)(E args) {
	string message;
	foreach(e ; args) {
		static if(is(typeof(e) : string)) {
			message ~= e;
		} else {
			message ~= to!string(e);
		}
	}
	synchronized writeln(message);
}
