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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/log.d, selery/log.d)
 */
module selery.log;

import std.algorithm : canFind;
import std.conv : to;
import std.string : indexOf;
import std.traits : EnumMembers;

import terminalcolor;

import selery.lang : LanguageManager, Translation, Translatable;

/**
 * Formatting codes for Minecraft and the system's console.
 */
enum Format : string {
	
	black = "§0",
	darkBlue = "§1",
	darkGreen = "§2",
	darkAqua = "§3",
	darkRed = "§4",
	darkPurple = "§5",
	gold = "§6",
	gray = "§7",
	darkGray = "§8",
	blue = "§9",
	green = "§a",
	aqua = "§b",
	red = "§c",
	lightPurple = "§d",
	yellow = "§e",
	white = "§f",
	
	obfuscated = "§k",
	bold = "§l",
	strikethrough = "§m",
	underlined = "§n",
	italic = "§o",
	
	reset = "§r"
	
}

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
		foreach(message ; messages) {
			final switch(message.type) {
				case Message.FORMAT:
					this.applyFormat(message.format);
					break;
				case Message.TEXT:
					this.writeText(message.text);
					break;
				case Message.TRANSLATION:
					this.writeText(this.lang.translate(message.translation.translatable.default_, message.translation.parameters));
					break;
			}
		}
		// add new line, reset formatting and print unflushed data
		this.terminal.writelnr();
	}

	private void writeText(string text) {
		immutable p = text.indexOf("§");
		if(p != -1 && p < text.length - 2 && "0123456789abcdefklmnor".canFind(text[p+2])) {
			this.terminal.write(text[0..p]);
			this.applyFormat(this.getFormat(text[p+2]));
			this.writeText(text[p+3..$]);
		} else {
			this.terminal.write(text);
		}
	}

	private Format getFormat(char c) {
		final switch(c) {
			foreach(immutable member ; __traits(allMembers, Format)) {
				case mixin("Format." ~ member)[$-1]: return mixin("Format." ~ member);
			}
		}
	}

	private void applyFormat(Format format) {
		final switch(format) {
			case Format.black:
				this.terminal.foreground = Color.black;
				break;
			case Format.darkBlue:
				this.terminal.foreground = Color.blue;
				break;
			case Format.darkGreen:
				this.terminal.foreground = Color.green;
				break;
			case Format.darkAqua:
				this.terminal.foreground = Color.cyan;
				break;
			case Format.darkRed:
				this.terminal.foreground = Color.red;
				break;
			case Format.darkPurple:
				this.terminal.foreground = Color.magenta;
				break;
			case Format.gold:
				this.terminal.foreground = Color.yellow;
				break;
			case Format.gray:
				this.terminal.foreground = Color.lightGray;
				break;
			case Format.darkGray:
				this.terminal.foreground = Color.gray;
				break;
			case Format.blue:
				this.terminal.foreground = Color.brightBlue;
				break;
			case Format.green:
				this.terminal.foreground = Color.brightGreen;
				break;
			case Format.aqua:
				this.terminal.foreground = Color.brightCyan;
				break;
			case Format.red:
				this.terminal.foreground = Color.brightRed;
				break;
			case Format.lightPurple:
				this.terminal.foreground = Color.brightMagenta;
				break;
			case Format.yellow:
				this.terminal.foreground = Color.brightYellow;
				break;
			case Format.white:
				this.terminal.foreground = Color.white;
				break;
			case Format.bold:
				this.terminal.bold = true;
				break;
			case Format.strikethrough:
				this.terminal.strikethrough = true;
				break;
			case Format.underlined:
				this.terminal.underlined = true;
				break;
			case Format.italic:
				this.terminal.italic = true;
				break;
			case Format.reset:
				this.terminal.reset();
				break;
			case Format.obfuscated:
				// not supported
				break;
		}
	}
	
}

deprecated("Use Logger instead") void setLogger(void delegate(string, int, int) func) {}

deprecated("Use Logger.log instead") void log(E...)(E args) {}

deprecated("Use Logger.logWarning instead") void warning_log(E...)(E args) {}

deprecated("Use Logger.logError instead") void error_log(E...)(E args) {}

deprecated("Use Logger.log instead") void raw_log(E...)(E args) {}
