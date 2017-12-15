/*
 * Copyright (c) 2017 SEL
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
/**
 * Module used to load and store the Minecraft's creative inventory.
 * Doing so in the server/player modules causes cyclic dependencies.
 */
module selery.inventory.creative;

import std.base64 : Base64;
import std.conv : to;
import std.json : parseJSON;
import std.zlib : Compress;

import sul.utils.var : varuint;

import selery.about : SupportedBedrockProtocols;
import selery.config : Files;

private __gshared ubyte[][uint] inventories;

/**
 * Loads a creative inventory from the cache or from a JSON file
 * and encodes it.
 * Returns: whether the creative inventory could be loaded.
 */
public bool loadCreativeInventory(uint protocol, const Files files) {
	switch(protocol) {
		foreach(immutable __protocol ; SupportedBedrockProtocols) {
			case __protocol: {
				ubyte[] inventory;
				enum cached = "creative_" ~ __protocol.to!string;
				if(!files.hasTemp(cached)) {
					enum asset = "creative/" ~ __protocol.to!string ~ ".json";
					if(!files.hasAsset(asset)) return false;
					static if(__protocol < 120) immutable pk = "ContainerSetContent";
					else immutable pk = "InventoryContent";
					mixin("import sul.protocol.bedrock" ~ __protocol.to!string ~ ".play : Packet = " ~ pk ~ ";");
					mixin("import sul.protocol.bedrock" ~ __protocol.to!string ~ ".types : Slot;");
					auto packet = new Packet(121);
					foreach(item ; parseJSON(cast(string)files.readAsset(asset))["items"].array) {
						auto obj = item.object;
						auto meta = "meta" in obj;
						auto nbt = "nbt" in obj;
						auto ench = "enchantments" in obj;
						packet.slots ~= Slot(obj["id"].integer.to!int, (meta ? (*meta).integer.to!int << 8 : 0) | 1, nbt && nbt.str.length ? Base64.decode(nbt.str) : []);
					}
					ubyte[] encoded = packet.encode();
					Compress c = new Compress(9);
					inventory = cast(ubyte[])c.compress(varuint.encode(encoded.length.to!uint) ~ encoded);
					inventory ~= cast(ubyte[])c.flush();
					files.writeTemp(cached, inventory);
				} else {
					inventory = cast(ubyte[])files.readTemp(cached);
				}
				inventories[protocol] = inventory;
				return true;
			}
		}
		default: return false;
	}
}

public ubyte[] getCreativeInventory(uint protocol) {
	return inventories.get(protocol, new ubyte[0]);
}
