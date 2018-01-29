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
modules causes cyclic dependencies.
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
