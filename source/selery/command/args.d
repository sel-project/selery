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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/command/args.d, selery/command/args.d)
 */
module selery.command.args;

import std.conv : ConvException;
import std.string : strip, indexOf;

import selery.command.util : Target, Position;

/**
 * Reads various types of strings from a single stream.
 * Example:
 * ---
 * auto reader = StringReader(`a " quoted " long string`);
 * assert(reader.readString() == "a");
 * assert(reader.readQuotedString() == " quoted ");
 * assert(reader.readText() == "long string");
 * ---
 */
struct StringReader {

	private string str;
	private size_t index = 0;

	public this(string str) {
		this.str = str.strip;
	}

	/**
	 * Indicates whether the string has been fully readed.
	 */
	public @property bool eof() {
		return this.str.length <= this.index;
	}

	/**
	 * Skips spaces.
	 * Example:
	 * ---
	 * auto r = StringReader(`   test  test`);
	 * r.skip();
	 * assert(r.index == 3); // private variable
	 * ---
	 */
	public void skip() {
		while(!this.eof() && this.str[this.index] == ' ') this.index++;
	}

	private void skipAndThrow() {
		this.skip();
		if(this.eof()) throw new StringTerminatedException();
	}

	/*
	 * Reads a string without skipping the white characters,
	 * assuming that they've already been skipped.
	 */
	private string readStringImpl() {
		size_t start = this.index;
		while(!this.eof && this.str[this.index] !=  ' ') this.index++;
		return this.str[start..this.index];
	}

	/**
	 * Reads a string until the next space character.
	 * Throws:
	 * 		StringTerminatedException if there's nothing left to read
	 * Example:
	 * ---
	 * auto r = StringReader(`hello world`);
	 * assert(r.readString() == "hello");
	 * assert(r.readString() == "world");
	 * ---
	 */
	public string readString() {
		this.skipAndThrow();
		return this.readStringImpl();
	}

	/**
	 * Reads a string that may be quoted.
	 * Throws:
	 * 		StringTerminatedException if there's nothing left to read
	 * 		QuotedStringNotClosedException if the string is quoted but never terminated
	 * Example:
	 * ---
	 * auto r = StringReader(`quoted "not quoted"`);
	 * assert(r.readQuotedString() == "quoted");
	 * assert(r.readQuotedString() == "not quoted");
	 * 
	 * // escaping is not supported
	 * r = StringReader(`"escaped \""`);
	 * assert(r.readQuotedString() == `escaped \`);
	 * try {
	 *    r.readQuotedString();
	 *    assert(0);
	 * } catch(QuotedStringNotTerminatedException) {}
	 * ---
	 */
	public string readQuotedString() {
		this.skipAndThrow();
		if(this.str[this.index] == '"') {
			auto start = ++this.index;
			if(this.eof()) throw new QuotedStringNotClosedException();
			while(this.str[this.index] != '"') {
				if(++this.index == this.str.length) throw new QuotedStringNotClosedException();
			}
			return this.str[start..++this.index-1];
		} else {
			return this.readStringImpl();
		}
	}

	/**
	 * Reads the remaining text.
	 * Throws:
	 * 		StringTerminatedException if there's nothing left to read
	 * Example:
	 * ---
	 * auto r = StringReader(`this is not a string`);
	 * assert(r.readString() == "this");
	 * assert(r.readQuotedString() == "is");
	 * assert(r.readText() == "not a string");
	 * ---
	 */
	public string readText() {
		this.skipAndThrow();
		size_t start = this.index;
		this.index = this.str.length;
		return this.str[start..$];
	}

}

class StringTerminatedException : ConvException {

	public this(string file=__FILE__, size_t line=__LINE__) {
		super("The string is terminated", file, line);
	}

}

class QuotedStringNotClosedException : ConvException {

	public this(string file=__FILE__, size_t line=__LINE__) {
		super("The quoted string isn't closed", file, line);
	}

}
