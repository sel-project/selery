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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/block.d, selery/util/block.d)
 */
module selery.util.block;

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
