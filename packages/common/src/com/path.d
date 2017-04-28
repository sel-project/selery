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
module com.path;

import std.file : setAttributes;
import std.path : dirSeparator;

class Paths {

	@disable this();

	public shared static string home, res, langSystem, langMessages, music, skin, plugins, resources, logs, crash, worlds, hidden;

	public shared static this() {
		load(".." ~ dirSeparator);
	}

	public static void load(string h) {

		home = h;

		res = home ~ "res" ~ dirSeparator;
		langSystem = res ~ "lang" ~ dirSeparator ~ "system" ~ dirSeparator;
		langMessages = res ~ "lang" ~ dirSeparator ~ "messages" ~ dirSeparator;
		music = res ~ "music" ~ dirSeparator;
		skin = res ~ "skin" ~ dirSeparator;
	
		plugins = home ~ "plugins" ~ dirSeparator;
		resources = home ~ "resources" ~ dirSeparator;
		logs = home ~ "logs" ~ dirSeparator;
		crash = home ~ "crash" ~ dirSeparator;
		worlds = home ~ "worlds" ~ dirSeparator;

		hidden = home ~ ".sel" ~ dirSeparator;

		version(Windows) {
			// hide hidden
			import core.sys.windows.winnt : FILE_ATTRIBUTE_HIDDEN;
			setAttributes(hidden, FILE_ATTRIBUTE_HIDDEN);
		}

	}

}