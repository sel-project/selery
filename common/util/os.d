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
module common.util.os;

import std.process : environment;

enum Os : ubyte {

	windows = 0,
	linux = 1,
	freeBSD = 2,
	openBSD = 3,
	osx = 4,
	android = 5,
	ios = 6,

	unknown = 255

}

version(Windows) {
	enum os = Os.windows;
} else version(linux) {
	enum os = Os.linux;
} else version(FreeBSD) {
	enum os = Os.freeBSD;
} else version(OpenBSD) {
	enum os = Os.openBSD;
} else version(OSX) {
	enum os = Os.osx;
} else version(Android) {
	enum os = Os.android;
} else version(iOS) {
	enum os = Os.ios;
} else {
	enum os = Os.unknown;
}

@property bool gui() {
	return environment.get("DISPLAY") !is null;
}
