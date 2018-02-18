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
/**
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/crash.d, selery/crash.d)
 */
module selery.crash;

import std.algorithm : min, max;
import std.ascii : newline;
import std.conv : to;
import std.datetime : Clock;
import std.file : write, read, exists, mkdir;
import std.string : split, replace;

import sel.format : Format, writeln;

import selery.about : Software;
import selery.lang : LanguageManager;

public string logCrash(string type, inout LanguageManager lang, Throwable e) {

	string filename = "crash/" ~ type ~ "_" ~ Clock.currTime().toSimpleString().split(".")[0].replace(" ", "_").replace(":", ".") ~ ".txt";

	writeln(Format.red ~ lang.translate("warning.crash", [typeid(e).to!string.split(".")[$-1], e.msg, e.file, e.line.to!string]));

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

	writeln(Format.red ~ lang.translate("warning.savedCrash", [filename]));

	return filename;

}
