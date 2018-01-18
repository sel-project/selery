/*
 * Copyright (c) 2018-2018 SEL
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
module selery.util.diet;

import std.algorithm : canFind;
import std.array : Appender;

import diet.html : compileHTMLDietFile;

import selery.about : Software;

string compileDietFile(string filename, E...)() {
	Appender!string appender;
	appender.compileHTMLDietFile!(filename, Software, importStyle, E);
	return appender.data;
}

string minifyStyle(string data) {
	Appender!string ret;
	foreach(c ; data) {
		if(!['\n', '\r', '\t'].canFind(c)) ret.put(c);
	}
	return ret.data;
}

string importStyle(string file)() {
	return minifyStyle(import(file));
}
