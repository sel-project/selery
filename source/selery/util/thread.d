/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
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
