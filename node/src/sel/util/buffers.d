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
deprecated module sel.util.buffers;

static import std.bitmanip;
import std.meta : staticIndexOf;
import std.system : Endian, system_endian = endian;
import std.typetuple;

import sul.utils.var : var;

alias ubyte[] buffer_t;

alias StandardTypes = TypeTuple!(bool, byte, ubyte, short, ushort, int, uint, long, ulong, float, double, char, wchar, dchar);

abstract class AbstractBuffer {

	public @trusted void write(T, Endian endianness)(T value, ref buffer_t buffer) if(staticIndexOf!(T, StandardTypes) >= 0) {
		size_t index = buffer.length;
		buffer.length += T.sizeof;
		std.bitmanip.write!(T, endianness)(buffer, value, &index);
	}
	
	public @trusted T read(T, Endian endianness)(ref buffer_t buffer) if(staticIndexOf!(T, StandardTypes) >= 0) {
		if(buffer.length < T.sizeof) buffer.length = T.sizeof;
		return std.bitmanip.read!(T, endianness)(buffer);
	}
	
	mixin((){
		string ret = "";
		foreach(T ; StandardTypes) {
			ret ~= "public abstract @safe void write_" ~ T.stringof ~ "(" ~ T.stringof ~ " value, ref buffer_t buffer);";
			ret ~= "public abstract @safe " ~ T.stringof ~ " read_" ~ T.stringof ~ "(ref buffer_t buffer);";
		}
		return ret;
	}());

}

class Buffer(Endian endian) : AbstractBuffer {

	mixin Instance;

	public final pure nothrow @property @safe @nogc Endian endianness() {
		return endian;
	}
	
	mixin((){
		string ret = "";
		foreach(T ; StandardTypes) {
			ret ~= "public override @safe void write_" ~ T.stringof ~ "(" ~ T.stringof ~ " value, ref buffer_t buffer){ this.write!(" ~ T.stringof ~ ", endian)(value, buffer); }";
			ret ~= "public override @safe " ~ T.stringof ~ " read_" ~ T.stringof ~ "(ref buffer_t buffer){ return this.read!(" ~ T.stringof ~ ", endian)(buffer); }";
			static if(__traits(compiles, var!T(T.init))) {
				ret ~= "public @safe void write_var" ~ T.stringof ~ "(var!" ~ T.stringof ~ " value, ref buffer_t buffer){ buffer ~= var!" ~ T.stringof ~ ".encode(value); }";
				ret ~= "public @safe var!" ~ T.stringof ~ " read_var" ~ T.stringof ~ "(ref buffer_t buffer){ return var!" ~ T.stringof ~ ".fromBuffer(buffer); }";
			}
		}
		return ret;
	}());
	
	public @safe ubyte[] read_ubyte_array(size_t length, ref buffer_t buffer) {
		if(buffer.length < length) buffer.length = length;
		ubyte[] ret = buffer[0..length];
		buffer = buffer[length..$];
		return ret;
	}

}

alias BigEndianBuffer = Buffer!(Endian.bigEndian);

alias LittleEndianBuffer = Buffer!(Endian.littleEndian);

alias DefaultBuffer = Buffer!system_endian;

mixin template Instance() {

	private static typeof(this) n_instance;

	public static this() {
		n_instance = new typeof(this)();
	}

	public static nothrow @property @safe @nogc typeof(this) instance() {
		return n_instance;
	}

}

struct Writer {

	public AbstractBuffer writer;
	public buffer_t n_buffer;

	public @safe @nogc this(AbstractBuffer writer) {
		this.writer = writer;
	}

	public @safe void write(T)(T value) if(staticIndexOf!(T, StandardTypes) >= 0) {
		mixin("this.writer.write_" ~ T.stringof ~ "(value, this.buffer);");
	}

	public pure nothrow @property @safe @nogc ref buffer_t buffer() {
		return this.n_buffer;
	}

	public pure nothrow @safe void reset() {
		this.buffer.length = 0;
	}

	alias buffer this;

}

struct Reader {

	public AbstractBuffer reader;
	public buffer_t buffer;

	public @safe @nogc this(AbstractBuffer reader, buffer_t buffer=buffer_t.init) {
		this.reader = reader;
		this.buffer = buffer;
	}

	public @safe T read(T)() if(staticIndexOf!(T, StandardTypes) >= 0) {
		mixin("return this.reader.read_" ~ T.stringof ~ "(this.buffer);");
	}

	public @safe ubyte[] read(size_t length) {
		if(this.buffer.length < length) this.buffer.length = length;
		ubyte[] ret = this.buffer[0..length];
		this.buffer = this.buffer[length..$];
		return ret;
	}

	public pure nothrow @property @safe @nogc bool eof() {
		return this.buffer.length == 0;
	}

	alias buffer this;

}

unittest {

	auto buffer = DefaultBuffer.instance;
	buffer_t payload;
	
	buffer.write_uint(1, payload);
	version(BigEndian) {
		assert(payload == [0, 0, 0, 1]);
		assert(buffer.read_long(payload) == 1L << 32);
	} else {
		assert(payload == [1, 0, 0, 0]);
		assert(buffer.read_long(payload) == 1L);
	}
	
	buffer.write_varshort(var!short(12), payload);
	buffer.write_varuint(var!uint(128), payload);
	assert(payload == [24, 128, 1]);
	
	assert(buffer.read_varshort(payload) == 12);
	assert(buffer.read_varuint(payload) == 128);

}
