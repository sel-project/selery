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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/block/tile.d, selery/block/tile.d)
 */
module selery.block.tile;

import std.algorithm : canFind;
import std.conv : to;
import std.json;
import std.traits : isAbstractClass;
import std.typecons : Tuple;
import std.typetuple : TypeTuple;

import sel.nbt.tags;

import selery.about;
import selery.block.block;
import selery.block.blocks : Blocks;
import selery.block.solid : Facing;
import selery.entity.entity : Entity;
import selery.item.item : Item;
import selery.item.items : Items;
import selery.item.slot : Slot;
import selery.math.vector : BlockPosition, entityPosition;
import selery.player.player : Player;
import selery.world.world : World;

static import sul.blocks;

mixin("import sul.protocol.java" ~ newestJavaProtocol.to!string ~ ".clientbound : UpdateBlockEntity;");

/**
 * A special block that contains additional data.
 */
abstract class Tile : Block {

	private static uint count = 0;

	private immutable uint n_tid;

	private bool n_placed = false;
	private World n_world;
	private BlockPosition n_position;

	public this(sul.blocks.Block data) {
		super(data);
		this.n_tid = ++count;
	}

	public final pure nothrow @property @safe @nogc uint tid() {
		return this.n_tid;
	}

	/**
	 * Gets the tile's spawn id for Minecraft and Minecraft: Pocket
	 * Edition.
	 * They're usually in snake case in Minecraft (flower_pot) and
	 * in pascal case in Minecraft: Pocket Edition (FlowerPot).
	 */
	public abstract pure nothrow @property @safe string javaSpawnId();

	/// ditto
	public abstract pure nothrow @property @safe string pocketSpawnId();

	/**
	 * Gets the named binary tag.
	 * The tag may be null if the tile does not exists in the game's
	 * version or when the tile is in its inital state (or empty).
	 */
	public abstract @property Compound javaCompound();

	/// ditto
	public abstract @property Compound pocketCompound();

	/**
	 * Parses a non-null compound saved in the Minecraft's Anvil
	 * format.
	 */
	public abstract void parseJavaCompound(Compound compound);

	/**
	 * Parses a non-null compound saved from a Minecraft: Pocket
	 * Edition's LevelDB format.
	 */
	public abstract void parsePocketCompound(Compound compound);

	public void place(World world, BlockPosition position) {
		this.n_placed = true;
		this.n_world = world;
		this.n_position = position;
		this.update();
	}

	public void unplace() {
		this.n_placed = false;
		this.n_world = null;
		this.n_position = BlockPosition.init;
	}

	/**
	 * Indicates whether the tile has been placed in a world.
	 * Example:
	 * ---
	 * if(tile.placed) {
	 *    assert(tile.world !is null);
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc bool placed() {
		return this.n_placed;
	}
	/**
	 * Gets the world the tile is placed in, if placed is true.
	 */
	public final pure nothrow @property @safe @nogc World world() {
		return this.n_world;
	}

	/**
	 * Gets the tile's position in the world, if placed.
	 * Example:
	 * ---
	 * if(tile.placed) {
	 *    assert(tile.tid == tile.world.tileAt(tile.position).tid);
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

	/**
	 * Gets the action type of the tile, used in Minecraft's
	 * UpdateBlockEntity packet.
	 */
	public abstract pure nothrow @property @safe @nogc ubyte action();

	// function called when the custom data changes and the viewers should be updated.
	protected void update() {
		if(this.placed) {
			this.world.updateTile(this, this.position);
		}
	}

}

/**
 * Sign with methods to get and set the text.
 * Example:
 * ---
 * auto sign = world.tileAt!Sign(10, 44, 90);
 * if(sign !is null) {
 *    sign[1] = "Click to go to";
 *    sign[2] = "world";
 *    assert(sign[] == ["", "Click to go to", "world", ""]);
 * }
 * ---
 */
abstract class Sign : Tile {
	
	/// Indicates the line.
	public static immutable size_t FIRST_LINE = 0;
	
	/// ditto
	public static immutable size_t SECOND_LINE = 1;
	
	/// ditto
	public static immutable size_t THIRD_LINE = 2;
	
	/// ditto
	public static immutable size_t FOURTH_LINE = 3;

	private Compound n_compound;
	private Named!String[4] texts;

	private Compound java_compound;
	private Named!String[4] java_texts;

	public this(sul.blocks.Block data, string a, string b, string c, string d) {
		super(data);
		foreach(i ; TypeTuple!(0, 1, 2, 3)) {
			enum text = "Text" ~ to!string(i + 1);
			this.texts[i] = new Named!String(text, "");
			this.java_texts[i] = new Named!String(text, "");
		}
		this.n_compound = new Compound(this.texts[0], this.texts[1], this.texts[2], this.texts[3]);
		this.java_compound = new Compound(this.java_texts[0], this.java_texts[1], this.java_texts[2], this.java_texts[3]);
		this.setImpl(0, a);
		this.setImpl(1, b);
		this.setImpl(2, c);
		this.setImpl(3, d);
	}

	public this(sul.blocks.Block data) {
		this(data, "", "", "", "");
	}

	public this(sul.blocks.Block data, string[uint] texts) {
		auto a = 0 in texts;
		auto b = 1 in texts;
		auto c = 2 in texts;
		auto d = 3 in texts;
		this(data, a ? *a : "", b ? *b : "", c ? *c : "", d ? *d : "");
	}
	
	public override pure nothrow @property @safe string javaSpawnId() {
		return "sign";
	}
	
	public override pure nothrow @property @safe string pocketSpawnId() {
		return "Sign";
	}

	/**
	 * Gets the array with the text in the four lines.
	 * Example:
	 * ---
	 * sign[2] = "test";
	 * assert(sign[] == ["", "", "test", ""]);
	 * ---
	 */
	public @safe @nogc string[4] opIndex() {
		string[4] ret;
		foreach(i, text; this.texts) {
			ret[i] = text.value;
		}
		return ret;
	}

	/**
	 * Gets the text at the given line.
	 * Params:
	 * 		index = the line of the sign
	 * Returns: a string with the text that has been written at the given line
	 * Throws: RangeError if index is not on the range 0..4
	 * Example:
	 * ---
	 * d("First line of sign is: ", sign[Sign.FIRST_LINE]);
	 * ---
	 */
	public @safe string opIndex(size_t index) {
		return this.texts[index].value;
	}

	private @trusted void setImpl(size_t index, string data) {
		this.texts[index].value = data;
		this.java_texts[index].value = JSONValue(["text": data]).toString();
	}

	/**
	 * Sets all the four lines of the sign.
	 * Params:
	 * 		texts = four strings to be set in sign's lines
	 * Example:
	 * ---
	 * sign[] = ["a", "b", "", "d"];
	 * assert(sign[0] == "a");
	 * ---
	 */
	public void opIndexAssign(string[4] texts) {
		foreach(i ; 0..4) {
			this.setImpl(i, texts[i]);
		}
		this.update();
	}

	/**
	 * Sets the given texts in every line of the sign.
	 * Params:
	 * 		text = the text to be set in every line
	 * Example:
	 * ---
	 * sign[] = "line";
	 * assert(sign[] == ["line", "line", "line", "line"]);
	 * ---
	 */
	public void opIndexAssign(string text) {
		foreach(i ; 0..4) {
			this.setImpl(i, text);
		}
		this.update();
	}

	/**
	 * Sets the text at the given line.
	 * Params:
	 * 		text = the new text for the given line
	 * 		index = the line to place the text into
	 * Throws: RangeError if index is not on the range 0..4
	 * Example:
	 * ---
	 * string text = "New text for line 2";
	 * sign[Sign.SECOND_LINE] = text;
	 * assert(sign[Sign.SECOND_LINE] == text);
	 * ---
	 */
	public void opIndexAssign(string text, size_t index) {
		this.setImpl(index, text);
		this.update();
	}

	/**
	 * Checks whether or not every sign's line is
	 * an empty string.
	 * Example:
	 * ---
	 * if(!sign.empty) {
	 *    sign[] = "";
	 *    assert(sign.empty);
	 * }
	 * ---
	 */
	public final @property @safe bool empty() {
		return this[0].length == 0 && this[1].length == 0 && this[2].length == 0 && this[3].length == 0;
	}

	public override @property Compound javaCompound() {
		return this.java_compound;
	}

	public override @property Compound pocketCompound() {
		return this.n_compound;
	}

	public override void parseJavaCompound(Compound compound) {
		void parse(size_t i, string data) {
			auto json = parseJSON(data);
			if(json.type == JSON_TYPE.OBJECT) {
				auto text = "text" in json;
				if(text && (*text).type == JSON_TYPE.STRING) {
					this.setImpl(i, (*text).str);
				}
			}
		}
		foreach(i ; TypeTuple!(0, 1, 2, 3)) {
			mixin("auto text = \"Text" ~ to!string(i) ~ "\" in compound;");
			if(text && cast(String)*text) parse(i, cast(String)*text);
		}
	}

	public override void parsePocketCompound(Compound compound) {
		foreach(i ; TypeTuple!(0, 1, 2, 3)) {
			mixin("auto text = \"Text" ~ to!string(i) ~ "\" in compound;");
			if(text && cast(String)*text) this.setImpl(i, cast(String)*text);
		}
	}
	
	public override @property @safe @nogc ubyte action() {
		static if(is(typeof(UpdateBlockEntity.SIGN_TEXT))) {
			return UpdateBlockEntity.SIGN_TEXT;
		} else {
			return 0;
		}
	}

	public override Slot[] drops(World world, Player player, Item item) {
		return [Slot(world.items.get(Items.sign), 1)];
	}

}

class SignBlock : Sign {
	
	public this(E...)(E args) {
		super(args);
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		if(!world[position - [0, 1, 0]].solid) {
			world.drop(this, position);
			world[position] = Blocks.air;
		}
	}

}

class WallSignBlock(ubyte facing) : Sign if(facing < 4) {

	public this(E...)(E args) {
		super(args);
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		static if(facing == Facing.north) {
			BlockPosition pc = position + [0, 0, 1];
		} else static if(facing == Facing.south) {
			BlockPosition pc = position - [0, 0, 1];
		} else static if(facing == Facing.west) {
			BlockPosition pc = position + [1, 0, 0];
		} else {
			BlockPosition pc = position - [1, 0, 0];
		}
		if(!world[pc].solid) {
			world.drop(this, position);
			world[pc] = Blocks.air;
		}
	}

}

/**
 * A pot that can contain a plant.
 */
class FlowerPot : Tile {

	private enum javaItems = cast(string[ushort])[
		6: "sapling",
		31: "tallgrass",
		32: "deadbush",
		37: "yellow_flower",
		38: "red_flower",
		39: "brown_mushroom",
		40: "red_mushroom",
		81: "cactus",
	];

	private Item m_item;

	private Compound pocket_compound, java_compound;

	public this(sul.blocks.Block data, Item item=null) {
		super(data);
		if(item !is null) this.item = item;
	}
	
	public override pure nothrow @property @safe string javaSpawnId() {
		return "flower_pot";
	}
	
	public override pure nothrow @property @safe string pocketSpawnId() {
		return "FlowerPot";
	}

	/**
	 * Gets the current item placed in the pot.
	 * It may be null if the pot is empty.
	 * Example:
	 * ---
	 * if(pot.item is null) {
	 *    pot.item = new Items.OxeyeDaisy();
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc Item item() {
		return this.m_item;
	}

	/**
	 * Places or removes an item from the pot.
	 * Example:
	 * ---
	 * pot.item = new Items.OxeyeDaisy(); // add
	 * pot.item = null; // remove
	 * ---
	 */
	public @property Item item(Item item) {
		if(item !is null) {
			item.clear(); // remove enchantments and custom name
			this.pocket_compound = new Compound(new Named!Short("item", item.bedrockId), new Named!Int("mData", item.bedrockMeta));
			this.java_compound = new Compound(new Named!String("Item", (){ auto ret=item.javaId in javaItems; return ret ? "minecraft:"~(*ret) : ""; }()), new Named!Int("Data", item.javaMeta));
		} else {
			this.pocket_compound = null;
			this.java_compound = null;
		}
		this.update();
		return this.m_item = item;
	}

	public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
		if(this.item !is null) {
			// drop
			if(player.inventory.held.empty) player.inventory.held = Slot(this.item, ubyte(1));
			else if(player.inventory.held.item == this.item && !player.inventory.held.full) player.inventory.held = Slot(this.item, cast(ubyte)(player.inventory.held.count + 1));
			else if(!(player.inventory += Slot(this.item, 1)).empty) player.world.drop(Slot(this.item, 1), position.entityPosition + [.5, .375, .5]);
			this.item = null;
			return true;
		} else if(item !is null && item.javaId in javaItems) {
			// place
			this.item = item;
			ubyte c = player.inventory.held.count;
			player.inventory.held = --c ? Slot(item, c) : Slot(null);
			return true;
		}
		return false;
	}

	public override @property Compound javaCompound() {
		return this.java_compound;
	}

	public override @property Compound pocketCompound() {
		return this.pocket_compound;
	}

	public override void parseJavaCompound(Compound compound) {
		if(this.world !is null) {
			auto item = "Item" in compound;
			auto meta = "Data" in compound;
			if(item && cast(String)*item) {
				immutable name = (cast(String)*item).value;
				foreach(id, n; javaItems) {
					if(name == n) {
						this.item = this.world.items.fromJava(cast(ushort)id, cast(ushort)(meta && cast(Int)*meta ? cast(Int)*meta : 0));
						break;
					}
				}
			}
		}
	}

	public override void parsePocketCompound(Compound compound) {
		if(this.world !is null) {
			auto id = "item" in compound;
			auto meta = "mData" in compound;
			if(id && cast(Short)*id) {
				this.item = this.world.items.fromBedrock(cast(Short)*id, meta && cast(Int)*meta ? cast(ushort)cast(Int)*meta : 0);
			}
		}
	}

	public override ubyte action() {
		static if(is(typeof(UpdateBlockEntity.FLOWER_POT_FLOWER))) {
			return UpdateBlockEntity.FLOWER_POT_FLOWER;
		} else {
			return 0;
		}
	}

}

//TODO
abstract class Container : Tile {

	public this(sul.blocks.Block data) {
		super(data);
	}

}

template TileImpl(sul.blocks.Block data, T:Tile) {

	class TileImpl : T {

		public this(E...)(E args) {
			super(data, args);
		}

	}

}

interface Tiles {

	alias FlowerPot = TileImpl!(sul.blocks.Blocks.flowerPot, selery.block.tile.FlowerPot);

}
