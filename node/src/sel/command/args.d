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
module sel.command.args;

import std.conv : ConvException;
import std.string : strip, indexOf;

import sel.command.util : Target, Position;

/**
 * Reads various types of strings from a single stream.
 * Example:
 * ---
 * auto reader = StringReader(`a " quoted " long string`);
 * assert(reader.readString() == "a");
 * assert(reader.readQuotedString() == " quoted ");
 * assert(reader.readText() == "long string");
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

/**
 * Indicates a pre-defined argument.
 * Valid types are Target, Position, bool, long and double.
 * Example:
 * ---
 * assert(CommandArg(22).type == CommandArg.Type.integer);
 * assert(CommandArg("").type == CommandArg.Type.string);
 * assert(CommandArg(.1).floating == .1);
 * ---
 */
struct CommandArg {
	
	enum Type {
		target,
		position,
		boolean,
		integer,
		floating,
		string
	}
	
	private union Store {
		Target target;
		Position position;
		bool boolean;
		long integer;
		double floating;
		string str;
	}
	public Store store;
	private Type n_type;
	
	public this(Target target) {
		this.store.target = target;
		this.n_type = Type.target;
	}
	
	public this(Position position) {
		this.store.position = position;
		this.n_type = Type.position;
	}
	
	public this(bool boolean) {
		this.store.boolean = boolean;
		this.n_type = Type.boolean;
	}
	
	public this(long integer) {
		this.store.integer = integer;
		this.n_type = Type.integer;
	}
	
	public this(double floating) {
		this.store.floating = floating;
		this.n_type = Type.floating;
	}
	
	public this(string str) {
		this.store.str = str;
		this.n_type = Type.string;
	}
	
	public pure nothrow @property @safe @nogc Type type() {
		return this.n_type;
	}

	alias store this;
	
}
