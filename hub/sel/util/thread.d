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
 * Source: $(HTTP www.github.com/sel-project/sel-server/blob/master/hub/sel/util/thread.d, sel/util/thread.d)
 */
module sel.util.thread;

import core.thread;

import std.ascii : newline;
import std.conv : to;
import std.datetime : dur;
import std.file : exists, write, mkdirRecurse;

import common.path : Paths;
import common.util.time : seconds;

import sel.util.log;

/**
 * Safe thread that handles errors and exceptions
 * and writes a crash file before stopping the server.
 */
class SafeThread : Thread {

	public this(T)(T fn) if(is(T == function) || is(T == delegate)) {
		super({
			try {
				fn();
			} catch(Throwable t) {
				log("Thread ", this.name, " has crashed: ", t.msg);
				crash(this.name, t);
			}
		});
	}

}

/**
 * Saves the details of a crash into a file.
 */
public void crash(string name, Throwable t) {
	string data = "Error in thread " ~ name ~ ": " ~ t.msg ~ newline ~ newline;
	data ~= t.info.toString() ~ newline;
	if(!exists(Paths.crash)) mkdirRecurse(Paths.crash);
	write(Paths.crash ~ "hub_" ~ to!string(seconds) ~ ".txt", data);
}
