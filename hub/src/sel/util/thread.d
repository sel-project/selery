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

import common.crash : logCrash;
import common.path : Paths;
import common.util : seconds;

import sel.settings : Settings;

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
					try {logCrash("hub", Settings.defaultLanguage, t);} catch(Throwable t2) {
						import sel.util.log;
						log(t2);
					}
			}
		});
	}

	public this(T)(string name, T fn) if(is(T == function) || is(T == delegate)) {
		this(fn);
		this.name = name;
	}

}
