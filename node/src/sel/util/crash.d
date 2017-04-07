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
module sel.util.crash;

import std.algorithm : min, max;
import std.ascii : newline;
import std.conv : to;
import std.file : read, exists, mkdirRecurse, write;
import std.string : split;

import common.path : Paths;
import common.sel;
import common.util.time : seconds;

import sel.server : server;
import sel.util.lang : translate;
import sel.util.log;

/**
 * Creates a crash-log file from a Throwable, usually throwed
 * during the execution of SEL.
 * The file is saved in crash/crash_(uinx date in seconds).txt
 */
public @trusted void crash(Throwable e) {

	error_log(translate("{warning.crash}", server.settings.language, [typeid(e).to!string.split(".")[$-1], e.msg, e.file, e.line.to!string]));

	string filename = Paths.crash ~ "node_" ~ seconds.to!string ~ ".txt";

	string file = "Critical " ~ (cast(Error)e ? "error" : "exception") ~ " on " ~ Software.display ~ newline ~ newline;
	file ~= "MESSAGE: " ~ e.msg ~ newline;
	file ~= "TYPE: " ~ typeid(e).to!string.split(".")[$-1] ~ newline;
	file ~= "FILE: " ~ e.file ~ newline;
	file ~= "LINE: " ~ e.line.to!string ~ newline ~ newline;
	file ~= e.info.to!string ~ newline;
	if(exists(e.file)) {
		file ~= newline;
		string[] errfile = (cast(string)read(e.file)).split(newline);
		foreach(uint i ; to!uint(max(0, e.line-32))..to!uint(min(errfile.length, e.line+32))) {
			file ~= "[" ~ (i + 1).to!string ~ "] " ~ errfile[i] ~ newline;
		}
	}
	if(!exists(Paths.crash)) mkdirRecurse(Paths.crash);
	if(!exists(Paths.hidden)) mkdirRecurse(Paths.hidden);
	write(filename, file);
	write(Paths.hidden ~ "crash", filename);

	error_log(translate("{warning.savedCrash}", server.settings.language, [filename]));

}
