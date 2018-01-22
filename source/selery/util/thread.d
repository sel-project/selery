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
module selery.util.thread;

import core.thread;

import std.ascii : newline;
import std.conv : to;
import std.datetime : dur;
import std.file : exists, write, mkdirRecurse;

import selery.crash : logCrash;
import selery.lang : LanguageManager;
import selery.util.util : seconds;

/**
 * Safe thread that handles errors and exceptions
 * and writes a crash file before stopping the server.
 */
class SafeThread : Thread {

	public this(T)(const LanguageManager lang, T fn) if(is(T == function) || is(T == delegate)) {
		super({
			try {
				fn();
			} catch(Throwable t) {
				logCrash("hub", lang, t);
			}
		});
	}

	public this(T)(string name, const LanguageManager lang, T fn) if(is(T == function) || is(T == delegate)) {
		this(lang, fn);
		this.name = name;
	}

}
