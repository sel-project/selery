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
module selery.log;

import std.conv : to;
import std.string : startsWith, replace, join;

import selery.format : Text, writeln;

private shared void delegate(string, string, int, int) logFunction;

shared static this() {
	logFunction = (string logger, string message, int worldId, int outputId){
		synchronized writeln("[" ~ logger ~ "] " ~ message);
	};
}

void setLogger(void delegate(string, string, int, int) func) {
	logFunction = func;
}

void logImpl(E...)(string logger, int worldId, int outputId, E args) {
	logFunction(logger, mixin(createMessage!E), worldId, outputId);
}

private string createMessage(E...)() {
	static if(E.length) {
		string[] ret;
		foreach(i, T; E) {
			static if(is(T : string)) {
				ret ~= "args[" ~ to!string(i) ~ "]";
			} else {
				ret ~= "to!string(args[" ~ to!string(i) ~ "])";
			}
		}
		return ret.join("~");
	} else {
		return "\"\"";
	}
}

void log(string mod=__MODULE__, E...)(E args) {
	static if(mod.startsWith("selery.")) {
		enum m = mod[7..$].replace(".", "/");
	} else {
		enum m = "plugin/" ~ mod.replace(".", "/");
	}
	logImpl(m, -1, -1, args);
}

void warning_log(string mod=__MODULE__, E...)(E args) {
	log!mod(cast(string)Text.yellow, args);
}

void error_log(string mod=__MODULE__, E...)(E args) {
	log!mod(cast(string)Text.red, args);
}

void debug_log(E...)(E args) {
	writeln("[debug] " ~ Text.blue ~ mixin(createMessage!E));
}

void raw_log(E...)(E args) {
	writeln(mixin(createMessage!E));
}
