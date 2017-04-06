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
/**
 * Tiles, also known as block entities, are blocks with additional data stored in an NBT tag.
 * License: <a href="http://www.gnu.org/licenses/lgpl-3.0.html" target="_blank">GNU General Lesser Public License v3</a>
 */
module sel.block.tile;

import std.algorithm : canFind;
import std.conv : to;
import std.json;
import std.traits : isAbstractClass;
import std.typecons : Tuple;
import std.typetuple : TypeTuple;

import common.sel;

import sel.player : Player;
import sel.block.block;
import sel.block.blocks : Blocks;
import sel.block.solid : Facing;
import sel.entity.entity : Entity;
import sel.entity.human : Human;
import sel.item.inventory : Inventory, NotifiedInventory, InventoryHolder;
import sel.item.item : Item;
import sel.item.items : Items;
import sel.item.slot : Slot;
import sel.math.vector : BlockAxis, BlockPosition, entityPosition;
import sel.nbt.tags;
import sel.settings;
import sel.util.color : Color, Colors;
import sel.util.lang : GenericTranslatable = Translatable;
import sel.world.particle : Particles;
import sel.world.world : World;

static import sul.blocks;

static if(__minecraft) {
	mixin("import sul.protocol.minecraft" ~ __minecraftProtocols[$-1].to!string ~ ".clientbound : UpdateBlockEntity;");
}

/**
 * Tile's interface implemented by a class that extends Block.
 * Example:
 * ---
 * if(cast(Tile)block) {
 *    player.sendTile(block);
 * }
 * ---
 */
interface Tile {

	public pure nothrow @property @safe @nogc uint tid();

	/**
	 * Gets the tile's spawn id for Minecraft and Minecraft: Pocket
	 * Edition.
	 * They're usually in snake case in Minecraft (flower_pot) and
	 * in pascal case in Minecraft: Pocket Edition (FlowerPot).
	 */
	public pure nothrow @property @safe group!string spawnId();

	/**
	 * Gets the named binary tag for Minecraft and Minecraft: Pocket
	 * Edition as a group.
	 * The tag may be null if the tile does not exists in the game's
	 * version or when the tile is in its inital state (or empty).
	 */
	public @property group!Compound compound();

	/**
	 * Parses a non-null compound saved in the Minecraft's Anvil
	 * format.
	 */
	public abstract void parseMinecraftCompound(Compound compound);

	/**
	 * Parses a non-null compound saved from a Minecraft: Pocket
	 * Edition's LevelDB format.
	 */
	public abstract void parsePocketCompound(Compound compound);

	public void place(World world, BlockPosition position);

	public @safe void unplace();

	/**
	 * Indicates whether the tile has been placed in a world.
	 * Example:
	 * ---
	 * if(tile.placed) {
	 *    assert(tile.world !is null);
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool placed();

	/**
	 * Gets the world the tile is placed in, if placed is true.
	 */
	public pure nothrow @property @safe @nogc World world();

	/**
	 * Gets the tile's position in the world, if placed.
	 * Example:
	 * ---
	 * if(tile.placed) {
	 *    assert(tile.tid == tile.world.tileAt(tile.position).tid);
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc BlockPosition position();

	/**
	 * Gets the action type of the tile, used in Minecraft's
	 * UpdateBlockEntity packet.
	 */
	public pure nothrow @property @safe @nogc ubyte action();

}

abstract class TileBlock(sul.blocks.Block sb) : SimpleBlock!(sb), Tile {

	private static uint count = 0;

	private immutable uint n_tid;

	private bool n_placed = false;
	private World n_world;
	private BlockPosition n_position;

	public @safe this() {
		this.n_tid = ++count;
	}

	public final override pure nothrow @property @safe @nogc uint tid() {
		return this.n_tid;
	}
	
	public override abstract pure nothrow @property @safe group!string spawnId();

	public override abstract @property group!Compound compound();
	
	public override abstract void parseMinecraftCompound(Compound compound);
	
	public override abstract void parsePocketCompound(Compound compound);

	public override void place(World world, BlockPosition position) {
		this.n_placed = true;
		this.n_world = world;
		this.n_position = position;
		this.update();
	}

	public final override void unplace() {
		this.n_placed = false;
		this.n_world = null;
		this.n_position = BlockPosition.init;
	}

	public final override pure nothrow @property @safe @nogc bool placed() {
		return this.n_placed;
	}

	public final override pure nothrow @property @safe @nogc World world() {
		return this.n_world;
	}

	public final override pure nothrow @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

	public override abstract pure nothrow @property @safe @nogc ubyte action();

	// function called when the custom data changes and the viewers should be updated.
	protected void update() {
		if(this.placed) {
			this.world.updateTile(this, this.position);
		}
	}

}

/**
 * Interface for a Sign with methods to edit the text.
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
interface Sign {

	/// Indicates the line.
	public static immutable size_t FIRST_LINE = 0;

	/// ditto
	public static immutable size_t SECOND_LINE = 1;

	/// ditto
	public static immutable size_t THIRD_LINE = 2;

	/// ditto
	public static immutable size_t FOURTH_LINE = 3;

	/**
	 * Gets the array with the text in the four lines.
	 * Example:
	 * ---
	 * sign[2] = "test";
	 * assert(sign[] == ["", "", "test", ""]);
	 * ---
	 */
	public @safe @nogc string[4] opIndex();

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
	public @safe string opIndex(size_t index);
	
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
	public void opIndexAssign(string text, size_t index);

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
	public void opIndexAssign(string[4] texts);

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
	public void opIndexAssign(string text);

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
	public @property @safe bool empty();

}
/+
/**
 * Implementation of Translable template for sign.
 * The lines will be translted for every player like a message
 * in sendMessage. The parameters can be set in the constructor
 * (as last argument) or by modifying the params variable.
 * Example:
 * ---
 * world[0, 0, 0] = new Translatable!(Blocks.SignSouth)("---", "{minigame.countdown}", "{language.name}", "", [[], [], ["50"], []]);
 * // players with english as lanugage => ["---", "The game will start in 50 seconds", "English", ""]
 * // players with italian as language => ["---", "La partita inizierà in 50 secondi", "Italiano", ""]
 * 
 * // get it
 * world.tileAt!(Translatable!(Blocks.SignSouth))(0, 0, 0);
 * ---
 */
template Translatable(T:Sign) {
	alias Translatable = GenericTranslatable!(["this.n_tag.get!(sel.util.nbt.String)(\"Text1\").value", "this.n_tag.get!(sel.util.nbt.String)(\"Text2\").value", "this.n_tag.get!(sel.util.nbt.String)(\"Text3\").value", "this.n_tag.get!(sel.util.nbt.String)(\"Text4\").value"], T);
}+/

abstract class GenericSign(sul.blocks.Block sb) : TileBlock!(sb), Sign {

	private Compound n_compound;
	private String[4] texts;

	static if(__minecraft) {
		private Compound minecraft_compound;
		private String[4] minecraft_texts;
	}

	public @safe this(string a, string b, string c, string d) {
		super();
		foreach(i ; TypeTuple!(0, 1, 2, 3)) {
			enum text = "Text" ~ to!string(i + 1);
			this.texts[i] = new String(text, "");
			static if(__minecraft) this.minecraft_texts[i] = new String(text, "");
		}
		this.n_compound = new Compound("", this.texts[0], this.texts[1], this.texts[2], this.texts[3]);
		static if(__minecraft) this.minecraft_compound = new Compound("", this.minecraft_texts[0], this.minecraft_texts[1], this.minecraft_texts[2], this.minecraft_texts[3]);
		this.setImpl(0, a);
		this.setImpl(1, b);
		this.setImpl(2, c);
		this.setImpl(3, d);
	}

	public @safe this() {
		this("", "", "", "");
	}

	public @safe this(string[uint] texts) {
		auto a = 0 in texts;
		auto b = 1 in texts;
		auto c = 2 in texts;
		auto d = 3 in texts;
		this(a ? *a : "", b ? *b : "", c ? *c : "", d ? *d : "");
	}
	
	public override pure nothrow @property @safe group!string spawnId() {
		return group!string("Sign", "sign");
	}

	public override @safe @nogc string[4] opIndex() {
		string[4] ret;
		foreach(i, text; this.texts) {
			ret[i] = text;
		}
		return ret;
	}

	public override @safe string opIndex(size_t index) {
		return this.texts[index];
	}

	private @trusted void setImpl(size_t index, string data) {
		this.texts[index] = data;
		static if(__minecraft) this.minecraft_texts[index] = JSONValue(["text": data]).toString();
	}

	public override void opIndexAssign(string[4] texts) {
		foreach(i ; 0..4) {
			this.setImpl(i, texts[i]);
		}
		this.update();
	}

	public override void opIndexAssign(string text) {
		foreach(i ; 0..4) {
			this.setImpl(i, text);
		}
		this.update();
	}

	public override void opIndexAssign(string text, size_t index) {
		this.setImpl(index, text);
		this.update();
	}

	public final override @property @safe bool empty() {
		return this[0] == "" && this[1] == "" && this[2] == "" && this[3] == "";
	}

	public override @property group!Compound compound() {
		static if(__minecraft) {
			return group!Compound(this.n_compound, this.minecraft_compound);
		} else {
			return group!Compound(this.n_compound, null);
		}
	}

	public override void parseMinecraftCompound(Compound compound) {
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

class SignBlock(sul.blocks.Block sb) : GenericSign!(sb) {
	
	public @safe this(E...)(E args) {
		super(args);
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		if(!world[position - [0, 1, 0]].solid) {
			world.drop(this, position);
			world[position] = Blocks.air;
		}
	}

}

class WallSignBlock(sul.blocks.Block sb, ubyte facing) : GenericSign!(sb) if(facing < 4) {

	public @safe this(E...)(E args) {
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
 * Interface for a flower pot, which can contain a
 * plant.
 */
interface FlowerPot {

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
	public pure nothrow @property @safe @nogc Item item();

	/**
	 * Places or removes an item from the pot.
	 * Example:
	 * ---
	 * pot.item = new Items.OxeyeDaisy(); // add
	 * pot.item = null; // remove
	 * ---
	 */
	public @property Item item(Item item);

	protected enum minecraftItems = cast(string[ushort])[
		6: "sapling",
		31: "tallgrass",
		32: "deadbush",
		37: "yellow_flower",
		38: "red_flower",
		39: "brown_mushroom",
		40: "red_mushroom",
		81: "cactus",
	];

}

final class FlowerPotTile(sul.blocks.Block sb) : TileBlock!(sb), FlowerPot {

	private Item m_item;

	private Compound pocket_compound, minecraft_compound;

	public @trusted this(Item item=null) {
		super();
		if(item !is null) this.item = item;
	}
	
	public override pure nothrow @property @safe group!string spawnId() {
		return group!string("FlowerPot", "flower_pot");
	}

	public override pure nothrow @property @safe @nogc Item item() {
		return this.m_item;
	}

	public override @property Item item(Item item) {
		if(item !is null) {
			item.clear(); // remove enchantments and custom name
			static if(__pocket) this.pocket_compound = new Compound("", new Short("item", item.pocketId), new Int("mData", item.pocketMeta));
			static if(__minecraft) this.minecraft_compound = new Compound("", new String("Item", (){ auto ret=item.minecraftId in minecraftItems; return ret ? "minecraft:"~(*ret) : ""; }()), new Int("Data", item.minecraftMeta));
		} else {
			this.pocket_compound = null;
			this.minecraft_compound = null;
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
		} else if(item !is null && item.minecraftId in minecraftItems) {
			// place
			this.item = item;
			ubyte c = player.inventory.held.count;
			player.inventory.held = --c ? Slot(item, c) : Slot(null);
			return true;
		}
		return false;
	}

	public override @property group!Compound compound() {
		return group!Compound(this.pocket_compound, this.minecraft_compound);
	}

	public override void parseMinecraftCompound(Compound compound) {
		if(this.world !is null) {
			auto item = "Item" in compound;
			auto meta = "Data" in compound;
			if(item && cast(String)*item) {
				immutable name = (cast(String)*item).value;
				foreach(id, n; minecraftItems) {
					if(name == n) {
						this.item = this.world.items.fromMinecraft(cast(ushort)id, cast(ushort)(meta && cast(Int)*meta ? cast(Int)*meta : 0));
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
				this.item = this.world.items.fromPocket(cast(Short)*id, meta && cast(Int)*meta ? cast(ushort)cast(Int)*meta : 0);
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

/**
 * Interface for a container that should be implemented in a block.
 */
interface Container {

	/**
	 * 
	 */
	public @property @safe Inventory inventory();

}

/*template Translatable(T:Container) {
	alias Translatable = GenericTranslatable!("this.n_tag.get!(sel.util.nbt.String(\"CustomName\").value", T);
}*/

/*class ContainerBlock(BlockData data, E...) : TileBlock!(data, E), Container, InventoryHolder {

	private Inventory n_inventory;

	public this(size_t length) {
		this.n_inventory = new NotifiedInventory(this, length);
	}

	public override pure nothrow @property @safe Inventory inventory() {
		return this.n_inventory;
	}

	public override void slotUpdated(size_t slot) {

	}

	alias inventory this;

}*/

/*

final class ItemFrame : Tile {

	public static immutable ubyte SOUTH = 0;
	public static immutable ubyte WEST = 1;
	public static immutable ubyte NORTH = 2;
	public static immutable ubyte EAST = 3;

	private Slot m_item;
	private ubyte m_rotation;

	public this(ubyte facing, Slot item=null, ubyte rotation=0) {
		super(Blocks.ITEM_FRAME, facing & 3, TRANSPARENT | INTERACTABLE, null);
		this.item = item;
		this.rotation = rotation;
	}

	public @property Slot item() {
		return this.m_item;
	}

	public @property Slot item(Slot item) {
		if(item is null) {
			if(this.m_tag !is null && this.m_tag.has("Item")) {
				this.m_tag.remove("Item");
			}
		} else {
			item.count = 1;
			if(this.m_tag is null) this.m_tag = new Compound("");
			this.m_tag["Item"] = item.fulltag;
		}
		return this.m_item = item;
	}

	alias slot = this.item;

	public @property ubyte rotation() {
		return this.m_rotation;
	}

	public @property ubyte rotation(ubyte rotation) {
		rotation &= 7;
		if(this.m_tag is null) this.m_tag = new Compound("");
		this.m_tag["ItemRotation"] = new Byte(rotation);
		return this.m_rotation = rotation;
	}

	public override Slot[] drops(Item item, Human holder) {
		Slot[] ret = [new Slot(Items.ITEM_FRAME.item, 1)];
		if(this.item !is null) ret ~= this.item;
		return ret;
	}

}

final class FlowerPot : Tile {

	private ushort id;
	private ubyte data;

	public this() {
		super(Blocks.FLOWER_POT_BLOCK, 0, SOLID | INTERACTABLE, Shapes.POT);
	}

	public this(Item flower) {
		this();
		this.flower = flower;
	}

	public @property Item flower() {
		return new Item(this.id, this.data);
	}

	public @property Item flower(Item flower) {
		if(flower is null || flower.id == 0) {
			this.id = 0;
			this.data = 0;
			flower = null;
			if(this.m_tag !is null) {
				this.m_tag = null;
			}
		} else {
			this.id = flower.id;
			this.data = flower.damage & 15;
			if(this.m_tag is null) this.m_tag = new Compound("");
			this.m_tag["item"] = new Short(this.id);
			this.m_tag["mData"] = new Int(this.data);
		}
		this.update();
		return flower;
	}

	alias item = this.flower;
	alias content = this.flower;
	alias plant = this.flower;

	public @property bool empty() {
		return this.id == 0;
	}

	public override Slot[] drops(Item item, Human holder) {
		Slot[] ret = [new Slot(Items.FLOWER_POT.item, 1)];
		if(this.item !is null) ret ~= new Slot(this.item, 1);
		return ret;
	}

}

final class MonsterSpawner : Tile {

	private uint m_entity_id = 0;
	private Entity m_entity;

	public this(uint entity=0) {
		super(Blocks.MONSTER_SPAWNER, 0, SOLID | INTERACTABLE, Shapes.FULL);
		if(entity != 0) {
			this.entity = entity;
		}
	}

	public this(T:Entity)(T entity) {
		super(Blocks.MONSTER_SPAWNER);
		this.entity = entity;
	}

	public @property uint entityId() {
		return this.m_entity_id;
	}

	public @property Entity entity() {
		return this.m_entity;
	}

	public @property Entity entity(uint entity) {
		this.m_entity_id = entity.to!ubyte;
		if(this.m_tag is null) this.m_tag = new Compound("");
		this.m_tag["EntityId"] = new Int(entity);
		return this.m_entity;
	}

	public @property Entity entity(Entity entity) {
		if(entity is null) {
			this.m_entity_id = 0;
			this.m_entity = null;
			this.m_tag = null;
		} else {
			this.m_entity_id = entity.type.pe;
			this.m_entity = entity;
			if(this.m_tag is null) this.m_tag = new Compound("");
			this.m_tag["EntityId"] = new Int(this.m_entity_id);
			//TODO entity tag (for special data)
		}
		return this.m_entity;
	}

	public @property bool empty() {
		return this.m_entity_id == 0;
	}

	public override uint xp(Item item, Human holder) {
		return cast(Pickaxe)item ? holder.world.random.range(15u, 43u) : 0;
	}

}

// works like crap
class Cauldron : Tile {

	public static immutable ubyte EMPTY = 0;
	public static immutable ubyte FULL = 6;

	private ushort m_potion = 0;
	private Color m_color = null;

	public this(ubyte level=EMPTY) {
		super(Blocks.CAULDRON, level, SOLID | INTERACTABLE, Shapes.FULL);
	}

	public @property ushort potion() {
		return this.m_potion;
	}

	public @property ushort potion(ushort potion) {
		if(this.m_tag is null) this.m_tag = new Compound("");
		this.m_tag["PotionId"] = new Short(potion == 0 ? ushort.max : potion);
		this.update();
		return this.m_potion = potion;
	}

	public final Color color() {
		return this.m_color;
	}

	public final Color color(Color color) {
		if(color is null) {
			if(this.tags && this.m_tag.has!Int("CustomColor")) {
				this.m_tag.remove("CustomColor");
			}
		} else {
			if(this.m_tag is null) this.m_tag = new Compound("");
			this.m_tag["CustomColor"] = new Int(color.rgba);
			this.update();
		}
		return this.m_color = color;
	}

	public final void empty(World world, BlockPosition position) {
		this.m_tag = null;
		this.particles(Particles.WHITE_SMOKE, 8, 0, world, position);
	}

	public final void particles(ushort particle, uint amount, float level, World world, BlockPosition position, uint data=0) {
		foreach(uint i ; 0..amount) {
			world.addParticle(particle, position.entityPosition.add(world.random.next!float, level / FULL + world.random.next!float / 10, world.random.next!float), data);
		}
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.CAULDRON.item, 1)];
	}
	
	public override void interact(Human human, BlockPosition position) {
		if(human.inventory.held !is null) {
			Item hand = human.inventory.held.item;
			byte meta = this.meta;
			if(hand.id == Items.BUCKET && hand.damage == Items.WATER && (this.meta < FULL || this.potion != 0)) {
				//update the water level to full
				if(this.potion == 0) {
					meta = FULL;
					this.color = null;
					this.particles(Particles.BUBBLE, 6, meta, human.world, position);
				} else {
					meta = 0;
					this.empty(human.world, position);
				}
				human.inventory.held = new Slot(Items.BUCKET.item, 1);
			} else if(hand.id == Items.BUCKET && hand.damage == 0 && this.meta == FULL) {
				//fill a bucket
				meta = 0;
				Slot slot = new Slot(Items.BUCKET.item(Items.WATER), 1);
				if(human.inventory.held.count == 1) human.inventory.held = new Slot(Items.BUCKET.item(Items.WATER), 1);
				else {
					human.inventory.held.count--;
					human.inventory.held = human.inventory.held;
					if((slot = human.inventory.add(slot)) !is null) human.drop(slot);
				}
			} else if(hand.id == Items.GLASS_BOTTLE && this.meta > EMPTY) {
				//fill the bottle (with potion?)
				Slot slot = new Slot(Items.POTION.item(this.potion), 1);
				if(human.inventory.held.count == 1) human.inventory.held = slot;
				else {
					human.inventory.held.count--;
					human.inventory.held = human.inventory.held;
					if((slot = human.inventory.add(slot)) !is null) human.drop(slot);
				}
				meta -= 2;
			} else if(hand.id == Items.POTION && (this.meta < FULL || hand.damage == 0 && this.potion != 0)) {
				if(this.meta == 0 || this.potion == hand.damage) {
					//just add the potion
					meta += 2;
					if(this.meta == 0) this.potion = hand.damage;
					if(hand.damage == 0) this.particles(Particles.BUBBLE, 6, meta, human.world, position);
					else this.particles(Particles.MOB_SPELL_AMBIENT, 4, meta, human.world, position, Effect.effectColor(hand.damage.to!ubyte.effect.id).rgb);
				} else if(this.potion != hand.damage) {
					//remove everything
					meta = 0;
					this.empty(human.world, position);
				}
				human.inventory.held = new Slot(Items.GLASS_BOTTLE.item, 1);
			} else if(cast(DyeableArmor)hand && this.meta > EMPTY) {
				meta--;
				//add a colour to the armour
				hand.to!DyeableArmor.color = this.color;
				human.inventory.held = new Slot(hand, 1);
			} else if(hand.id == Items.DYE && this.potion == 0 && this.meta > EMPTY) {
				this.color = Colors.RED; //TODO right colours
				human.inventory.held.count--;
				human.inventory.held = human.inventory.held.empty ? null : human.inventory.held;
				this.particles(Particles.BUBBLE, 6, meta, human.world, position, this.color.rgb);
			}
			//update the block!
			if(this.meta != meta) {
				Cauldron nblock = new Cauldron(meta < EMPTY ? EMPTY : (meta > FULL ? FULL : meta));
				if(meta > EMPTY) {
					if(this.potion != 0) nblock.potion = this.potion;
					if(this.color !is null) nblock.color = this.color;
				}
				//TODO add colour
				human.world[position] = nblock;
			}
		}
	}

}

abstract class Container : Tile {

	public static immutable ubyte CHEST = 0;
	public static immutable ubyte CRAFTING = 1;
	public static immutable ubyte FURNACE = 2;
	public static immutable ubyte ENCHANTMENT_TABLE = 3;
	public static immutable ubyte BREWING_STAND = 5;
	public static immutable ubyte ANVIL = 6;
	public static immutable ubyte DISPENSER = 9;

	public immutable ubyte type;
	public Inventory inventory;

	protected BlockPosition position; //estimated
	protected bool drop_on_close = false;

	private Player[ulong] viewers;

	public this(ubyte id, ubyte meta, float[] box, ubyte type, uint inventorysize) {
		super(id, meta, SOLID | INTERACTABLE, box);
		this.type = type;
		this.inventory = new Inventory(inventorysize);
	}

	public @property uint length() {
		return this.inventory.length;
	}

	public override Slot[] drops(Item item, Human holder) {
		Slot[] ret;
		foreach(Slot slot ; this.inventory) {
			if(slot !is null) {
				ret ~= slot;
			}
		}
		return ret;
	}

	public override void interact(Human human, BlockPosition position) {
		if(cast(Player)human && human.to!Player.container is null) {
			Player player = human.to!Player;
			this.viewers[player.id] = player;
			player.openContainer(this, position);
		}
		this.position = position;
	}

	public void close(Player from) {
		this.viewers.remove(from.id);
		if(this.drop_on_close && !this.inventory.empty) {
			if(this.position !is null) {
				foreach(Slot slot ; this.inventory) {
					if(slot !is null) {
						from.world.drop(slot, this.position.entityPosition.add(.5, 1, .5));
					}
				}
			}
			this.inventory.empty = true;
		}
	}

	public void update(Player except=null) {
		foreach(Player player ; this.viewers) {
			if(except is null || player != except) this.sendContents(player);
		}
	}

	public void update(uint slot, Player except=null) {
		if(this.viewers.length > 0 && (except is null || this.viewers.length != 1 || except.id !in this.viewers)) {
			//ContainerSetSlot packet = new ContainerSetSlot(to!ubyte(this.type + 1), slot.to!ushort, 0, this.inventory[slot]);
			//foreach(Player player ; this.viewers) {
			//	if(except is null || player != except) player.sendPacket(packet);
			//}
		}
	}

	public void sendContents(Player player) {
		//player.sendPacket(new ContainerSetContent(to!ubyte(this.type + 1), this.inventory));
	}

}

class Chest : Container {

	public this() {
		super(Blocks.CHEST, 0, Shapes.FULL, CHEST, 27);
	}

	public override Slot[] drops(Item item, Human holder) {
		return super.drops(item, holder) ~ new Slot(Items.CHEST.item, 1);
	}

}

class Furnace : Container {

	public static immutable uint OFF = 0;
	public static immutable uint ON = 1;

	public this() {
		super(Blocks.FURNACE, 0, Shapes.FULL, FURNACE, 3);
	}

	public override Slot[] drops(Item item, Human holder) {
		return super.drops(item, holder) ~ new Slot(Items.FURNACE.item, 1);
	}

	public @property Slot ingredient() {
		return this.inventory[0];
	}

	public @property Slot ingredient(Slot slot) {
		this.inventory[0] = slot;
		return this.ingredient;
	}

	public @property Slot fuel() {
		return this.inventory[1];
	}

	public @property Slot fuel(Slot slot) {
		this.inventory[1] = slot;
		return this.fuel;
	}

	public @property Slot result() {
		return this.inventory[2];
	}

	public @property Slot result(Slot slot) {
		this.inventory[2] = slot;
		return this.result;
	}

	alias product = this.result;

}

class BrewingStand : Container {

	public this() {
		super(Blocks.BREWING_STAND, 0, Shapes.BREWING_STAND, BREWING_STAND, 3);
	}

	public override Slot[] drops(Item item, Human holder) {
		return super.drops(item, holder) ~ new Slot(Items.BREWING_STAND.item, 1);
	}

}

class EnchantmentTable : Container {

	public this() {
		super(Blocks.ENCHANTMENT_TABLE, 0, Shapes.THREE_FOURTH, ENCHANTMENT_TABLE, 2);
		this.drop_on_close = true;
	}

	public override Slot[] drops(Item item, Human holder) {
		return super.drops(item, holder) ~ new Slot(Items.ENCHANTMENT_TABLE.item, 1);
	}

}*/

//class Dropper

//class Dispenser

//class Hopper
