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
module sel.nbt.io;

import std.conv : to;
import std.string : replace, toLower;
import std.system : Endian;
import std.typetuple : TypeTuple;

import sel.nbt.tags;
import sel.util.buffers;

import sul.utils.var : varint, varuint;

class NbtBuffer(Endian endianness) : Buffer!endianness {
	
	mixin Instance;

	public @safe void writeTag(Tag tag, ref ubyte[] buffer) {
		this.writeId(tag.id, buffer);
		if(cast(NamedTag)tag) this.writeString((cast(NamedTag)tag).name, buffer);
		this.writeBody(tag, buffer);
	}
	
	public @trusted void writeBody(Tag tag, ref ubyte[] buffer) {
		switch(tag.id) {
			case NBT.BYTE:
				this.write_byte(cast(Byte)tag, buffer);
				break;
			case NBT.SHORT:
				this.write_short(cast(Short)tag, buffer);
				break;
			case NBT.INT:
				this.write_int(cast(Int)tag, buffer);
				break;
			case NBT.LONG:
				this.write_long(cast(Long)tag, buffer);
				break;
			case NBT.FLOAT:
				this.write_float(cast(Float)tag, buffer);
				break;
			case NBT.DOUBLE:
				this.write_double(cast(Double)tag, buffer);
				break;
			case NBT.STRING:
				this.writeString(cast(String)tag, buffer);
				break;
			case NBT.BYTE_ARRAY:
				auto ba = cast(ByteArray)tag;
				this.writeLength(ba.value.length, buffer);
				buffer ~= ba.value;
				break;
			case NBT.INT_ARRAY:
				auto ia = cast(IntArray)tag;
				this.writeLength(ia.value.length, buffer);
				foreach(value ; ia) this.write_int(value, buffer);
				break;
			case NBT.LIST:
				this.writeList(cast(ListParameters)tag, buffer);
				break;
			case NBT.COMPOUND:
				this.writeCompound(cast(Compound)tag, buffer);
				break;
			default:
				// end or unknown tag
				break;
		}
	}

	public @safe void writeId(ubyte id, ref ubyte[] buffer) {
		this.write_ubyte(id, buffer);
	}
	
	public @safe void writeLength(size_t length, ref ubyte[] buffer) {
		this.write_uint(length.to!uint, buffer);
	}
	
	public @trusted void writeString(string str, ref ubyte[] buffer) {
		this.write_ushort(cast(ushort)str.length, buffer);
		buffer ~= cast(ubyte[])str;
	}
	
	public @safe void writeList(ListParameters tag, ref ubyte[] buffer) {
		this.writeId(tag.childId, buffer);
		auto tags = tag.namedTags;
		this.writeLength(tags.length, buffer);
		foreach(namedTag ; tags) {
			this.writeBody(namedTag, buffer); // names and ids are ignored!
		}
	}
	
	public @safe void writeCompound(Compound tag, ref ubyte[] buffer) {
		foreach(namedTag ; tag[]) {
			this.writeTag(namedTag, buffer);
		}
		this.writeId(NBT.END, buffer);
	}

	public @safe Tag readTag(ref ubyte[] buffer) {
		ubyte id = this.readId(buffer);
		string name;
		if(id > NBT.END) {
			name = this.readString(buffer);
		}
		return this.readBody(id, name, buffer);
	}
	
	public @safe Tag readBody(ubyte id, string name, ref ubyte[] buffer) {
		switch(id) {
			case NBT.BYTE:
				return new Byte(name, this.read_byte(buffer));
			case NBT.SHORT:
				return new Short(name, this.read_short(buffer));
			case NBT.INT:
				return new Int(name, this.read_int(buffer));
			case NBT.LONG:
				return new Long(name, this.read_long(buffer));
			case NBT.FLOAT:
				return new Float(name, this.read_float(buffer));
			case NBT.DOUBLE:
				return new Double(name, this.read_double(buffer));
			case NBT.BYTE_ARRAY:
				return new ByteArray(name, this.read_ubyte_array(this.readLength(buffer), buffer));
			case NBT.INT_ARRAY:
				int[] array = new int[this.readLength(buffer)];
				foreach(ref i ; array) i = this.read_int(buffer);
				return new IntArray(name, array);
			case NBT.STRING:
				return new String(name, this.readString(buffer));
			case NBT.LIST:
				return this.readList(name, buffer);
			case NBT.COMPOUND:
				return this.readCompound(name, buffer);
			default:
				return End.instance;
		}
	}
	
	public @safe ubyte readId(ref ubyte[] buffer) {
		return this.read_ubyte(buffer);
	}
	
	public @safe size_t readLength(ref ubyte[] buffer) {
		return this.read_uint(buffer);
	}
	
	public @trusted string readString(ref ubyte[] buffer) {
		return cast(string)this.read_ubyte_array(this.read_ushort(buffer), buffer);
	}
	
	public @safe List readList(string name, ref ubyte[] buffer) {
		ubyte id = this.readId(buffer);
		NamedTag[] tags = new NamedTag[this.readLength(buffer)];
		foreach(ref namedTag ; tags) {
			namedTag = cast(NamedTag)this.readBody(id, "", buffer);
		}
		return new List(name, tags);
	}
	
	public @safe Compound readCompound(string name, ref ubyte[] buffer, size_t max=ushort.max) {
		Compound compound = new Compound(name);
		Tag tag;
		while(cast(NamedTag)(tag = this.readTag(buffer)) && compound.length < max) { // stops on tag End (also works when the buffer is empty)
			compound[] = cast(NamedTag)tag;
		}
		return compound;
	}
	
}

class VarintNbtBuffer(Endian endianness) : NbtBuffer!endianness {

	mixin Instance;

	public override void writeBody(Tag tag, ref ubyte[] buffer) {
		if(tag.id == NBT.INT) {
			buffer ~= varint.encode(cast(Int)tag);
		} else {
			super.writeBody(tag, buffer);
		}
	}

	public override void writeLength(size_t length, ref ubyte[] buffer) {
		buffer ~= varuint.encode(length.to!uint);
	}

	public override @trusted void writeString(string str, ref ubyte[] buffer) {
		buffer ~= varuint.encode(str.length.to!uint);
		buffer ~= cast(ubyte[])str;
	}

	public override Tag readBody(ubyte id, string name, ref ubyte[] buffer) {
		if(id == NBT.INT) {
			return new Int(name, varint.fromBuffer(buffer));
		} else {
			return super.readBody(id, name, buffer);
		}
	}

	public override size_t readLength(ref ubyte[] buffer) {
		return varuint.fromBuffer(buffer);
	}

	public override @trusted string readString(ref ubyte[] buffer) {
		return cast(string)this.read_ubyte_array(varuint.fromBuffer(buffer), buffer);
	}

}
