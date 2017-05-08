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
module sel.util.block;

import core.atomic : atomicOp;

import std.socket : Address, InternetAddress, Internet6Address;

class Blocks {

	private shared Block[] blocks;

	public shared nothrow bool block(Address address, size_t seconds) {
		if(cast(InternetAddress)address) {
			this.blocks ~= cast(shared)new IPv4Block(cast(InternetAddress)address, seconds);
			return true;
		} else if(cast(Internet6Address)address) {
			this.blocks ~= cast(shared)new IPv6Block(cast(Internet6Address)address, seconds);
			return true;
		} else {
			return false;
		}
	}

	public shared nothrow @safe @nogc bool isBlocked(Address address) {
		foreach(ref shared Block block ; this.blocks) {
			if(block.equals(address)) return true;
		}
		return false;
	}

	public shared nothrow @safe void remove(size_t seconds) {
		foreach(i, ref shared Block block; this.blocks) {
			block.remove(seconds);
			if(block.expired) {
				this.blocks = this.blocks[0..i] ~ this.blocks[i+1..$];
			}
		}
	}

}

abstract class Block {

	private shared ptrdiff_t seconds;

	public nothrow @safe @nogc this(size_t seconds) {
		this.seconds = seconds;
	}

	public shared nothrow @trusted @nogc void remove(size_t seconds) {
		atomicOp!"-="(this.seconds, seconds);
	}

	public shared nothrow @property @safe @nogc bool expired() {
		return this.seconds <= 0;
	}

	public abstract shared nothrow @safe @nogc bool equals(Address address);

}

class IPv4Block : Block {

	private immutable uint address;

	public nothrow @safe @nogc this(InternetAddress address, size_t seconds) {
		super(seconds);
		this.address = address.addr;
	}

	public override shared nothrow @safe @nogc bool equals(Address address) {
		return cast(InternetAddress)address ? this.address == (cast(InternetAddress)address).addr : false;
	}

}

class IPv6Block : Block {

	private immutable(ubyte)[16] address;

	public nothrow @safe @nogc this(Internet6Address address, size_t seconds) {
		super(seconds);
		this.address = address.addr;
	}

	public override shared nothrow @safe @nogc bool equals(Address address) {
		return cast(Internet6Address)address ? this.address == (cast(Internet6Address)address).addr : false;
	}

}
