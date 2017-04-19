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
module common.path;

import std.path : dirSeparator;

class Paths {

	@disable this();

	public shared static immutable string home, res, lang, music, skin, plugins, resources, logs, crash, worlds, hidden;

	public shared static this() {

		home = "../"; // exe should be in node/ or hub/

		res = "../res/";
		lang = res ~ "lang/";
		music = res ~ "music/";
		skin = res ~ "skin/";
	
		plugins = "../plugins/";
		resources = "../resources/";
		logs = "../logs/";
		crash = "../crash/";
		worlds = "../worlds/";

		hidden = "../.hidden/";

	}

}