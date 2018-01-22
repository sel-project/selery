/*
 * Copyright (c) 2017-2018 SEL
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
module selery.crash;

import std.algorithm : min, max;
import std.ascii : newline;
import std.conv : to;
import std.datetime : Clock;
import std.file : write, read, exists, mkdir;
import std.stdio : writeln;
import std.string : split, replace;

import selery.about : Software;
import selery.lang : LanguageManager;
import selery.log : Format;

public string logCrash(string type, inout LanguageManager lang, Throwable e) {

	string filename = "crash/" ~ type ~ "_" ~ Clock.currTime().toSimpleString().split(".")[0].replace(" ", "_").replace(":", ".") ~ ".txt";

	writeln(lang.translate("warning.crash", [typeid(e).to!string.split(".")[$-1], e.msg, e.file, e.line.to!string])); //TODO use Terminal to change colour

	string file = "Critical " ~ (cast(Error)e ? "error" : "exception") ~ " on " ~ Software.display ~ newline ~ newline;
	file ~= "Message: " ~ e.msg ~ newline;
	file ~= "Type: " ~ typeid(e).to!string.split(".")[$-1] ~ newline;
	file ~= "File: " ~ e.file ~ newline;
	file ~= "Line: " ~ e.line.to!string ~ newline ~ newline;
	file ~= e.info.to!string.replace("\n", newline) ~ newline;
	if(exists(e.file)) {
		file ~= newline;
		string[] errfile = (cast(string)read(e.file)).split(newline);
		foreach(uint i ; to!uint(max(0, e.line-32))..to!uint(min(errfile.length, e.line+32))) {
			file ~= "[" ~ (i + 1).to!string ~ "] " ~ errfile[i] ~ newline;
		}
	}
	if(!exists("crash")) mkdir("crash");
	write(filename, file);

	writeln(lang.translate("warning.savedCrash", [filename])); //TODO use Terminal to change colour

	return filename;

}
