/*
 * Copyright (c) 2017-2019 sel-project
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
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/log.d, selery/log.d)
 */
module selery.log;

import std.algorithm : canFind;
import std.array : Appender;
import std.conv : to;
import std.string : indexOf;
import std.traits : EnumMembers;

import sel.format : Format;
import sel.terminal : writeln;

import terminal : Terminal;

import selery.lang : LanguageManager, Translation, Translatable;

/**
 * Indicates a generic message. It can be a formatting code, a raw string
 * or a translatable content.
 */
struct Message {

	enum : ubyte {

		FORMAT = 1,
		TEXT = 2,
		TRANSLATION = 3

	}

	ubyte type;

	union {

		Format format;
		string text;
		Translation translation;

	}

	this(Format format) {
		this.type = FORMAT;
		this.format = format;
	}

	this(string text) {
		this.type = TEXT;
		this.text = text;
	}

	this(Translation translation) {
		this.type = TRANSLATION;
		this.translation = translation;
	}

	/**
	 * Converts data into an array of messages.
	 */
	static Message[] convert(E...)(E args) {
		Message[] messages;
		foreach(arg ; args) {
			alias T  = typeof(arg);
			static if(is(T == Message) || is(T == Message[])) {
				messages ~= arg;
			} else static if(is(T == Format) || is(T == Translation)) {
				messages ~= Message(arg);
			} else static if(is(T == Translatable)) {
				messages ~= Message(Translation(arg));
			} else {
				messages ~= Message(to!string(arg));
			}
		}
		return messages;
	}

}

class Logger {

	public Terminal terminal;
	private const LanguageManager lang;

	public this(Terminal terminal, inout LanguageManager lang) {
		this.terminal = terminal;
		this.lang = cast(const)lang;
	}
	
	public void log(E...)(E args) {
		this.logMessage(Message.convert(args));
	}
	
	public void logWarning(E...)(E args) {
		this.log(Format.yellow, args);
	}
	
	public void logError(E...)(E args) {
		this.log(Format.red, args);
	}

	public void logMessage(Message[] messages) {
		this.logImpl(messages);
	}

	protected void logImpl(Message[] messages) {
		Appender!string text;
		foreach(message ; messages) {
			final switch(message.type) {
				case Message.FORMAT:
					text.put(cast(string)message.format);
					break;
				case Message.TEXT:
					text.put(message.text);
					break;
				case Message.TRANSLATION:
					text.put(this.lang.translate(message.translation.translatable.default_, message.translation.parameters));
					break;
			}
		}
		writeln(this.terminal, text.data);
	}
	
}
