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
module sel.network.session;

import core.atomic : atomicOp;

import std.bitmanip : read;
import std.conv : to;
import std.socket;
import std.string;
import std.system : Endian;

import sel.server;
import sel.settings;
import sel.network.handler;
import sel.util.log : log;

alias session_t = immutable(ubyte)[];

abstract class Session {

	public static session_t code(Address address) {
		if(cast(InternetAddress)address) {
			auto v4 = cast(InternetAddress)address;
			return idup(cast(ubyte[])[v4.addr & 255, (v4.addr >> 8) & 255, (v4.addr >> 16) & 255, (v4.addr >> 24) & 255, v4.port & 255, (v4.port >> 8) & 255]);
		} else if(cast(Internet6Address)address) {
			auto v6 = cast(Internet6Address)address;
			return idup(v6.addr ~ cast(ubyte[])[v6.port & 255, (v6.port >> 8) & 255]);
		} else {
			throw new Exception("Unsupported protocol");
		}
	}

	private static shared uint count = 0;

	public shared immutable uint id;

	protected shared Server server;

	public shared this(shared Server server) {
		atomicOp!"+="(count, 1);
		this.id = count;
		this.server = server;
	}

	public shared abstract ptrdiff_t send(const(void)[] buffer);

	static class Receiver(T, Endian endianness=Endian.bigEndian) {

		private enum bool var = T.stringof.startsWith("var");

		public size_t length;

		public ubyte[] buffer;

		public nothrow @safe void add(ubyte[] buffer) {
			this.buffer ~= buffer;
		}

		public nothrow @property @safe bool has() {
			if(this.length > 0) return this.length <= this.buffer.length;
			if(this.canReadLength) {
				static if(var) {
					this.length = T.fromBuffer(this.buffer);
				} else {
					this.length = read!(T, endianness)(this.buffer);
				}
				if(this.length == 0) return false; //TODO throw exception ?
				return this.has;
			} else {
				return false;
			}
		}

		protected nothrow @safe bool canReadLength() {
			static if(var) {
				foreach(i ; 0..T.MAX_BYTES) {
					if(i >= this.buffer.length) return false;
					if(!(this.buffer[i] & 0x80)) break;
				}
				return true; // may overflow but that's fine
			} else {
				return this.buffer.length >= T.sizeof;
			}
		}

		public nothrow @property @safe ubyte[] next() {
			ubyte[] ret = this.buffer[0..this.length];
			this.buffer = this.buffer[this.length..$];
			this.length = 0;
			return ret;
		}

	}

}
