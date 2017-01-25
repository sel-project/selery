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

/*version(OneNode) {
	version = ResBack;
	version = ResourcesBack;
}*/

version(ResBack) {

	private enum string __res = ".." ~ dirSeparator;

} else {

	private enum string __res = "";

}

version(ResourcesBack) {

	private enum string __resources = ".." ~ dirSeparator;

} else {

	private enum string __resources = "";

}

class Paths {

	@disable this();
	
	version(ResNoSrc) {
		
		enum string res = __res ~ dirSeparator ~ "res" ~ dirSeparator;
	
	} else {

		enum string res = __res ~ "src" ~ dirSeparator ~ "res" ~ dirSeparator;
		
	}

	enum string crash = __res ~ "crash" ~ dirSeparator;

	enum string lang = res ~ "lang" ~ dirSeparator;

	enum string music = res ~ "music" ~ dirSeparator;

	enum string skin = res ~ "skin" ~ dirSeparator;

	enum string resources = __resources ~ "resources" ~ dirSeparator;

	enum string plugins = __resources ~ "plugins" ~ dirSeparator;

	enum string logs = __resources ~ "logs" ~ dirSeparator;

	enum string hidden = __res ~ ".hidden" ~ dirSeparator;

	enum string worlds = __res ~ "worlds" ~ dirSeparator;

}