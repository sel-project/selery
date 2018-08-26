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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hncom/io.d, selery/hncom/io.d)
 */
module selery.hncom.io;

import std.json : JSONValue, parseJSON, JSONException;
import std.socket : Address, InternetAddress, Internet6Address, UnknownAddress;
import std.system : Endian;
import std.uuid : UUID;

import xpacket;

alias HncomPacket = PacketImpl!(Endian.littleEndian, ubyte, ushort);

struct HncomUUID {
	
	public static void serialize(UUID value, Buffer buffer) {
		buffer.write(value.data);
	}

	public static UUID deserialize(Buffer buffer) {
		return UUID(read16(buffer));
	}
	
}

struct HncomAddress {
	
	public static void serialize(Address value, Buffer buffer) {
		if(cast(InternetAddress)value) {
			InternetAddress address = cast(InternetAddress)value;
			buffer.write!ubyte(4);
			buffer.write!(Endian.littleEndian)(address.addr);
			buffer.write!(Endian.littleEndian)(address.port);
		} else if(cast(Internet6Address)value) {
			Internet6Address address = cast(Internet6Address)value;
			buffer.write!ubyte(6);
			buffer.write(address.addr);
			buffer.write!(Endian.littleEndian)(address.port);
		} else {
			buffer.write!ubyte(0);
		}
	}
	
	public static Address deserialize(Buffer buffer) {
		switch(buffer.read!ubyte()) {
			case 4: return new InternetAddress(buffer.read!(Endian.littleEndian, int)(), buffer.read!(Endian.littleEndian, ushort)());
			case 6: return new Internet6Address(read16(buffer), buffer.read!(Endian.littleEndian, ushort)());
			default: return new UnknownAddress();
		}
	}
	
}

ubyte[16] read16(Buffer buffer) {
	ubyte[16] ret = buffer.read!(ubyte[])(16);
	return ret;
}

mixin template Make() {

	static import xserial.serial;
	
	mixin({
			
		string ret = "this(";
		foreach(member ; xserial.serial.Members!(typeof(this), null)) {
			ret ~= "typeof(" ~ member ~ ") " ~ member ~ "=typeof(" ~ member ~ ").init,";
		}
		ret ~= "){";
		foreach(member ;xserial.serial.Members!(typeof(this), null)) {
			ret ~= "this." ~ member ~ "=" ~ member ~ ";";
		}
		return ret ~ "}";
		
	}());

	static import xpacket.maker;
	
	mixin xpacket.maker.Make;
	
	static typeof(this) fromBuffer(ubyte[] buffer) {
		typeof(this) ret = new typeof(this)();
		ret.decode(buffer);
		return ret;
	}
	
}
