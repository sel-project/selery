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

import std.conv : to;
import std.traits : isAbstractClass;
import std.typecons : Tuple;

import sel.player : Player;
import sel.block.block;
import sel.block.flags;
import sel.entity.entity : Entity;
import sel.entity.human : Human;
import sel.item.inventory : Inventory, NotifiedInventory, InventoryHolder;
import sel.item.item : Item, Items;
import sel.item.slot : Slot;
import sel.math.vector : BlockAxis, BlockPosition, entityPosition;
import sel.nbt.tags : Byte, Compound, Int, Short, String;
import sel.util.color : Color, Colors;
import sel.util.lang : GenericTranslatable = Translatable;
import sel.world.particle : Particles;
import sel.world.world : World;

/**
 * Tile's interface implemented by a class that extends Block.
 * Example:
 * ---
 * if(block.tags) {
 *   player.sendTile(block);
 * }
 * ---
 */
interface Tile {

	/// Gets the server's unique tile id.
	public @property @safe @nogc uint tid();

	/// Checks if the tile has custom data.
	public @property @safe bool tags();

	/// Gets the tags as Compound tags.
	public @property @safe Compound petag();

	/// ditto
	public @property @safe Compound pctag();

	/// Sets the custom data.
	public @property @safe Compound petag(Compound tag);

	/// ditto
	public @property @safe Compound pctag(Compound tag);

	/// Gets tags that are never null, even if tags() is false.
	public @property @safe Compound alwayspetag();

	/// ditto
	public @property @safe Compound alwayspctag();

	public void place(World world, BlockPosition position);

	public @safe void unplace();

	/// Checks whether or not the tile has been placed in a world.
	public @property @safe @nogc bool placed();

	/// Gets the world the tile is placed in, if placed is true.
	public @property @safe @nogc World world();

	/// Gets the tile's position in the world.
	public @property @safe @nogc BlockPosition position();

	/// Gets the action type of the tile.
	public pure nothrow @property @safe @nogc ubyte action();

	public static immutable ubyte MOB = 1;
	public static immutable ubyte COMMAND = 2;
	public static immutable ubyte BEACON = 3;
	public static immutable ubyte SKULL = 4;
	public static immutable ubyte FLOWER_POT = 5;
	public static immutable ubyte SIGN = 9;

}

/**
 * Block's implementation of the Tile's interface.
 */
class TileBlock(BlockData blockdata, E...) : SimpleBlock!(blockdata, E), Tile {

	private static uint count = 0;

	private immutable uint n_tid;

	protected Compound m_pe_tag;
	protected Compound m_pc_tag;

	private World n_world;
	private BlockPosition n_position;

	public @safe this() {
		this.n_tid = ++count;
	}

	public final override @property @safe @nogc uint tid() {
		return this.n_tid;
	}

	public override @property @safe bool tags() {
		return this.petag !is null || this.pctag !is null;
	}

	public override @property @safe Compound petag() {
		return this.m_pe_tag;
	}

	public override @property @safe Compound pctag() {
		return this.m_pc_tag;
	}

	public override @property @safe Compound petag(Compound tag) {
		return this.petag;
	}

	public override @property @safe Compound pctag(Compound tag) {
		return this.pctag;
	}

	public override @property @safe Compound alwayspetag() {
		return this.petag is null ? new Compound() : this.petag;
	}

	public override @property @safe Compound alwayspctag() {
		return this.pctag is null ? new Compound() : this.pctag;
	}

	public override void place(World world, BlockPosition position) {
		this.n_world = world;
		this.n_position = position;
		this.update();
	}

	public final override @safe void unplace() {
		this.n_world = null;
	}

	public final override @property @safe @nogc bool placed() {
		return this.world !is null;
	}

	public final override @property @safe @nogc World world() {
		return this.n_world;
	}

	public final override @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

	public abstract override pure nothrow @property @safe @nogc ubyte action();

	/// Function called when the custom data changes and the viewers should be updated.
	protected void update() {
		if(this.placed) {
			this.world.updateTile(this, this.position);
		}
	}

}

/**
 * Interface for a Sign, should be implemented in a block.
 * Example:
 * ---
 * auto sign = world.tileAt!Sign(10, 44, 90);
 * if(sign !is null) {
 *    sign.remove(0);
 *    sign[1] = "Click to go to";
 *    sign[2] = "world";
 *    sign.remove(3);
 *    assert(sign[] == ["", "Click to go to", "world", ""]);
 * }
 * ---
 */
interface Sign {

	/// Lines indicators.
	public static immutable uint FIRST_LINE = 0;

	/// ditto
	public static immutable uint SECOND_LINE = 1;

	/// ditto
	public static immutable uint THIRD_LINE = 2;

	/// ditto
	public static immutable uint FOURTH_LINE = 3;

	/**
	 * Gets the array with the four strings.
	 * Example:
	 * ---
	 * sign[2] = "test";
	 * assert(sign[] == ["", "", "test", ""]);
	 * ---
	 */
	public @safe @nogc string[4] opIndex();

	/**
	 * Gets the string at the given index.
	 * Params:
	 * 		index = the line of the sign
	 * Returns: a string with the text that has been written at the given line
	 * Throws: RangeError if index is not on the range 0..4
	 * Example:
	 * ---
	 * d("First line of sign is: \"", sign[Sign.FIRST_LINE], "\"");
	 * ---
	 */
	public @safe string opIndex(uint index);

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
	 * Sets the given texts in the first empty line found.
	 * Params:
	 * 		text = the text to be set in the first empty line
	 * Returns: the number of the line where the text has been placed, or -1 if it wasn't placed
	 * Example:
	 * ---
	 * sign[] = ["first", "second", "third", ""];
	 * assert((sign[] = "fourth") == Sign.FOURTH_LINE);
	 * assert((sign[] = "fifth") == -1)
	 * sign.remove(Sign.FIRST_LINE);
	 * assert((sign[] = "first") == Sign.FIRST_LINE);
	 * ---
	 */
	public int opIndexAssign(string text);

	/**
	 * Sets the text at the given index.
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
	public void opIndexAssign(string text, uint index);

	/**
	 * Sets a line to an empty string.
	 * Params:
	 * 		index = the line that will be set as an empty string
	 * Thrown: RangeError if index is not on the range 0..4
	 * Example:
	 * ---
	 * sign.remove(Sign.FOURTH_LINE);
	 * assert(sign[Sign.FOURTH_LINE] == "");
	 * ---
	 */
	public void remove(uint index);

	/**
	 * Checks whether or not every sign's line is
	 * an empty string.
	 * Example:
	 * ---
	 * if(!sign.empty) {
	 *    foreach(uint i ; 0..4) {
	 *       sign.remove(i);
	 *    }
	 *    assert(sign.empty);
	 * }
	 * ---
	 */
	public @property @safe bool empty();

}

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
}

/**
 * Block's implementation of the sign's interface.
 * Example:
 * ---
 * world[10, 10, 10] = new Blocks.Sign([1: "Hello", 2: "World!"]);
 * ---
 */
abstract class GenericSign(BlockData blockdata, E...) : TileBlock!(blockdata, E), Sign {

	private string[4] texts;

	protected Compound n_tag;

	public @safe this() {
		this("", "", "", "");
	}

	public @safe this(string a, string b, string c, string d) {
		super();
		this.n_tag = new Compound("");
		foreach(uint i, string text; [a, b, c, d]) {
			this.texts[i] = text;
			this.n_tag[] = new String("Text" ~ to!string(i + 1), text);
		}
	}

	public @safe this(string[uint] texts) {
		this(0 in texts ? texts[0] : "", 1 in texts ? texts[1] : "", 2 in texts ? texts[2] : "", 3 in texts ? texts[3] : "");
	}

	public override @safe @nogc string[4] opIndex() {
		return this.texts;
	}

	public override @safe string opIndex(uint index) {
		return this.texts[index];
	}

	public override void opIndexAssign(string[4] texts) {
		foreach(uint i ; 0..4) {
			this[i] = texts[i];
		}
	}

	public override int opIndexAssign(string text) {
		foreach(int i ; 0..4) {
			if(this.texts[i] == "") {
				this[i] = text;
				return i;
			}
		}
		return -1;
	}

	public override void opIndexAssign(string text, uint index) {
		if(text is null) text = "";
		if(text != this.texts[index]) {
			this.texts[index] = text;
			this.n_tag[] = new String("Text" ~ to!string(index + 1), text);
			this.update();
		}
	}

	public final override void remove(uint index) {
		this.opIndexAssign(null, index);
	}

	public final override @property @safe bool empty() {
		return this[0] == "" && this[1] == "" && this[2] == "" && this[3] == "";
	}

	public override @property @safe bool tags() {
		return true;
	}

	public override @property @safe @nogc Compound petag() {
		return this.n_tag;
	}

	public override @property @safe @nogc Compound pctag() {
		/*Compound tag = new Compound("");
		foreach(string index ; ["Text1", "Text2", "Text3", "Text4"]) {
			tag[] = new String(index, "{text:\"" ~ this.n_tag.get!String(index).value ~ "\"}");
		}
		tag[] = new String("id", "Sign");
		tag[] = new Int("x", this.position.x);
		tag[] = new Int("y", this.position.y);
		tag[] = new Int("z", this.position.z);
		return tag;*/
		return this.n_tag;
	}
	
	public override @property @safe @nogc ubyte action() {
		return SIGN;
	}

	public override @safe Slot[] drops(Player player, Item item) {
		return [Slot(player.world.items.get(Items.SIGN), 1)];
	}

}

class SignBlock(BlockData blockdata, E...) : GenericSign!(blockdata, E) {
	
	public @safe this(F...)(F args) {
		super(args);
	}

	public override void onUpdate(World world, BlockPosition position, Update update) {
		if(update != Update.REMOVED) {
			if(world[position - [0, 1, 0]] == Blocks.AIR) {
				world.drops(this, position);
				world[position] = Blocks.AIR;
			}
		}
	}

}

class WallSignBlock(BlockData blockdata, E...) : GenericSign!(blockdata, E) {
	
	public @safe this(F...)(F args) {
		super(args);
	}

	public override void onUpdate(World world, BlockPosition position, Update update) {
		if(update != Update.REMOVED) {
			static if(blockdata.id == Blocks.WALL_SIGN_NORTH.id) {
				BlockPosition pc = position + [0, 0, 1];
			} else static if(blockdata.id == Blocks.WALL_SIGN_SOUTH.id) {
				BlockPosition pc = position - [0, 0, 1];
			} else static if(blockdata.id == Blocks.WALL_SIGN_WEST.id) {
				BlockPosition pc = position + [1, 0, 0];
			} else static if(blockdata.id == Blocks.WALL_SIGN_EAST.id) {
				BlockPosition pc = position - [1, 0, 0];
			} else {
				return;
			}
			if(world[pc] == Blocks.AIR) {
				world.drops(this, position);
				world[pc] = Blocks.AIR;
			}
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

	alias inventory this;

}

/*template Translatable(T:Container) {
	alias Translatable = GenericTranslatable!("this.n_tag.get!(sel.util.nbt.String(\"CustomName\").value", T);
}*/

class ContainerBlock(BlockData data, E...) : TileBlock!(data, E), Container, InventoryHolder {

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

}



interface MonsterSpawner {}

class MonsterSpawnerBlock(BlockData data, E...) : TileBlock!(data, E), MonsterSpawner {



}

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
