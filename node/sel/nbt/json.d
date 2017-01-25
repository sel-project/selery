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
module sel.nbt.json;

import std.json : JSONValue;

import sel.nbt.tags;

/**
 * Converts a tag to a JSONValue.
 * Example:
 * ---
 * assert(new Byte(12).toJSON().toString() == `{"id":0,"value":12}`);
 * assert(new Compound("test", ["int": new Int(12)]).toSimpleJSON().toString() == `{"name":"test","value":{"int":12}}`);
 * ---
 */
public @property JSONValue toJSON(bool writeIds=true)(Tag tag, bool name=true) {
	JSONValue[string] json;
	static if(writeIds) json["id"] = tag.id;
	if(name && cast(NamedTag)tag) json["name"] = (cast(NamedTag)tag).name;
	if(tag.id != NBT.END) json["value"] = toJSONImpl!writeIds(tag);
	return JSONValue(json);
}

/// ditto
alias toSimpleJSON = toJSON!false;

private JSONValue toJSONImpl(bool writeIds)(Tag tag) {
	final switch(tag.id) {
		case NBT.BYTE:
			return JSONValue((cast(Byte)tag).value);
		case NBT.SHORT:
			return JSONValue((cast(Short)tag).value);
		case NBT.INT:
			return JSONValue((cast(Int)tag).value);
		case NBT.LONG:
			return JSONValue((cast(Long)tag).value);
		case NBT.FLOAT:
			return JSONValue((cast(Float)tag).value);
		case NBT.DOUBLE:
			return JSONValue((cast(Double)tag).value);
		case NBT.STRING:
			return JSONValue((cast(String)tag).value);
		case NBT.BYTE_ARRAY:
			return JSONValue((cast(ByteArray)tag).value);
		case NBT.INT_ARRAY:
			return JSONValue((cast(IntArray)tag).value);
		case NBT.LIST:
			JSONValue[] list;
			auto lp = cast(ListParameters)tag;
			foreach(value ; lp.namedTags) {
				list ~= toJSONImpl!writeIds(value);
			}
			return JSONValue(["id": JSONValue(lp.childId), "value": JSONValue(list)]);
		case NBT.COMPOUND:
			JSONValue[string] compound;
			foreach(value ; (cast(Compound)tag).value) {
				compound[value.name] = toJSON!writeIds(value, false);
			}
			return JSONValue(compound);
	}
}
