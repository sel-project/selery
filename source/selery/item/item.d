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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/item/item.d, selery/item/item.d)
 */
module selery.item.item;

import std.conv : to;
static import std.json;
import std.string : split, join;

import sel.nbt.tags;

import selery.about;
import selery.block.block : Block;
import selery.block.blocks : Blocks;
import selery.enchantment : Enchantments, Enchantment, EnchantmentException;
import selery.entity.entity : Entity;
import selery.item.slot : Slot;
import selery.item.tool : Tools;
import selery.math.vector : BlockPosition, face;
import selery.player.player : Player;
import selery.world.world : World;

static import sel.data.enchantment;
static import sul.items;


/**
 * Base class for an Item.
 */
class Item {

	protected Compound m_pc_tag;
	protected Compound m_pe_tag;

	private string m_name = "";
	private string m_lore = "";
	private Enchantment[ubyte] enchantments;
	private bool m_unbreakable = false;

	private block_t[] canPlaceOn, canDestroy; //TODO

	public pure nothrow @safe @nogc this() {}
	
	/**
	 * Constructs an item with some extra data.
	 * Throws: JSONException if the JSON string is malformed
	 * Example:
	 * ---
	 * auto item = new Items.Apple(`{"customName":"SPECIAL APPLE","enchantments":[{"name":"protection","level":"IV"}]}`);
	 * assert(item.customName == "SPECIAL APPLE");
	 * assert(Enchantments.protection in item);
	 * ---
	 */
	public @trusted this(string data) {
		this(std.json.parseJSON(data));
	}

	/**
	 * Constructs an item adding properties from a JSON.
	 * Throws: RangeError if the enchanting name doesn't exist
	 */
	public @safe this(std.json.JSONValue data) {
		this.parseJSON(data);
	}

	public @trusted void parseJSON(std.json.JSONValue data) {
		if(data.type == std.json.JSON_TYPE.OBJECT) {

			auto name = "customName" in data;
			if(name && name.type == std.json.JSON_TYPE.STRING) this.customName = name.str;

			auto lore = "lore" in data;
			if(lore) {
				if(lore.type == std.json.JSON_TYPE.STRING) this.lore = lore.str;
				else if(lore.type == std.json.JSON_TYPE.ARRAY) {
					string[] l;
					foreach(value ; lore.array) {
						if(value.type == std.json.JSON_TYPE.STRING) l ~= value.str;
					}
					this.lore = l.join("\n");
				}
			}

			void parseEnchantment(std.json.JSONValue ench) @trusted {
				if(ench.type == std.json.JSON_TYPE.ARRAY) {
					foreach(e ; ench.array) {
						if(e.type == std.json.JSON_TYPE.OBJECT) {
							ubyte l = 1;
							auto level = "level" in e;
							auto lvl = "lvl" in e;
							if(level && level.type == std.json.JSON_TYPE.INTEGER) {
								l = cast(ubyte)level.integer;
							} else if(lvl && lvl.type == std.json.JSON_TYPE.INTEGER) {
								l = cast(ubyte)lvl.integer;
							}
							auto name = "name" in e;
							auto java = "java" in e;
							auto bedrock = "bedrock" in e;
							try {
								if(name && name.type == std.json.JSON_TYPE.STRING) {
									this.addEnchantment(Enchantment.fromString(name.str, l));
								} else if(java && java.type == std.json.JSON_TYPE.INTEGER) {
									this.addEnchantment(Enchantment.fromJava(cast(ubyte)java.integer, l));
								} else if(bedrock && bedrock.type == std.json.JSON_TYPE.INTEGER) {
									this.addEnchantment(Enchantment.fromBedrock(cast(ubyte)bedrock.integer, l));
								}
							} catch(EnchantmentException) {}
						}
					}
				}
			}
			if("ench" in data) parseEnchantment(data["ench"]);
			else if("enchantments" in data) parseEnchantment(data["enchantments"]);

			auto unb = "unbreakable" in data;
			if(unb && unb.type == std.json.JSON_TYPE.TRUE) this.unbreakable = true;

		}
	}

	/**
	 * Gets the item's data.
	 */
	public pure nothrow @property @safe @nogc const sul.items.Item data() {
		return sul.items.Item.init;
	}

	/**
	 * Indicates wether the item exists in Minecraft.
	 */
	public pure nothrow @property @safe @nogc bool java() {
		return this.data.java.exists;
	}

	/// ditto
	public pure nothrow @property @safe @nogc ushort javaId() {
		return this.data.java.id;
	}

	/// ditto
	public pure nothrow @property @safe @nogc ushort javaMeta() {
		return this.data.java.meta;
	}

	/**
	 * Indicates whether the item exists in Minecraft.
	 */
	public pure nothrow @property @safe @nogc bool bedrock() {
		return this.data.bedrock.exists;
	}

	public pure nothrow @property @safe @nogc ushort bedrockId() {
		return this.data.bedrock.id;
	}

	public pure nothrow @property @safe @nogc ushort bedrockMeta() {
		return this.data.bedrock.meta;
	}

	/**
	 * Gets the name (not the custom name!) of the item.
	 * Example:
	 * ---
	 * if(item.name == "string")
	 *    item.customName = "Special String";
	 * ---
	 */
	public pure nothrow @property @safe @nogc string name() {
		return this.data.name;
	}

	/** 
	 * Indicates the highest number of items that can be stacked in a slot.
	 * This number is the default slot's count if not specified when created.
	 * Returns: a number between 1 and 64 (usually 1, 16 or 64).
	 * Example:
	 * ---
	 * Slot slot = new Items.Beetroot();
	 * assert(slot.count == 64 && slot.item.max == 64);
	 * assert(slot.item.max == 64);
	 * 
	 * slot = new Slot(new Items.Beetroot(), 23);
	 * assert(slot.count != 64 && slot.count == 23);
	 * ---
	 */
	public pure nothrow @property @safe @nogc ubyte max() {
		return this.data.stack;
	}

	/**
	 * Indicates whether the item is a tool.
	 * A tool can be used on blocks and entities
	 * and its meta will vary.
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().tool == false);
	 * assert(new Items.DiamondSword().tool == true);
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool tool() {
		return false;
	}

	/**
	 * Gets the item's tool type.
	 * Returns: Tools.none if the item is not a tool or a number higher
	 * 			than 0 indicating the tool type.
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().toolType == Tools.none);
	 * assert(new Items.DiamondSword().toolType == Tools.sword);
	 * ---
	 */
	public pure nothrow @property @safe @nogc ubyte toolType() {
		return Tools.none;
	}

	/**
	 * Gets the tool's material if the item is a tool.
	 * Items with ID 0 have unspecified material, 1 is the minimum (wood)
	 * and 5 is the maximum (diamond).
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().toolMaterial == NO_TOOL);
	 * assert(new Items.DiamondSword().toolMaterial == DIAMOND);
	 * ---
	 */
	public pure nothrow @property @safe @nogc ubyte toolMaterial() {
		return Tools.none;
	}

	/**
	 * If the item is a tool, checks whether its damage is higher than
	 * its durability.
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().finished == false); // beetroots aren't tools
	 * assert(new Items.DiamondSword().finished == false);
	 * assert(new Items.DiamondSword(Items.DiamondSword.DURABILITY + 1).finished == true);
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool finished() {
		return false;
	}

	/**
	 * Indicates the damage caused by the item when used as a weapon.
	 * The value indicates the base damage without the influence of
	 * enchantments or effects.
	 * Example:
	 * ---
	 * if(item.attack > 1)
	 *    assert(item.tool);
	 * ---
	 */
	public pure nothrow @property @safe @nogc uint attack() {
		return 1;
	}

	/**
	 * Indicates whether or not an item can be eaten/drunk.
	 * If true, Item::onConsumed(Human consumer) will be called
	 * when this item is eaten/drunk.
	 * Example:
	 * ---
	 * if(item.consumeable) {
	 *    Item residue;
	 *    if((residue = item.onConsumed(player)) !is null) {
	 *       player.held = residue;
	 *    }
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool consumeable() {
		return false;
	}

	/**
	 * Indicates whether the item can be consumed when the holder's
	 * hunger is full.
	 */
	public pure nothrow @property @safe @nogc bool alwaysConsumeable() {
		return true;
	}

	/**
	 * If consumeable is true, this function is called.
	 * when the item is eaten/drunk by its holder, who's passed
	 * as the first arguments.
	 * Return:
	 * 		null: the item count will be reduced by 1
	 * 		item: the item will substitutes the consumed item
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().onConsumed(player) is null);
	 * assert(new Items.BeetrootSoup().onConsumed(player) == Items.BOWL);
	 * ---
	 */
	public Item onConsumed(Player player) {
		return null;
	}
	
	/**
	 * Indicates whether or not the item can be placed.
	 * If this function returns true, Item::place(World world) will be probably
	 * called next for place a block
	 */
	public pure nothrow @property @safe @nogc bool placeable() {
		return false;
	}

	/**
	 * Function called when the item is ready to be placed by
	 * a player (the event for the player has already been called).
	 * Returns: true if a block has been placed, false otherwise
	 */
	public bool onPlaced(Player player, BlockPosition tpos, uint tface) {
		BlockPosition position = tpos.face(tface);
		//TODO calling events on player and on block
		auto placed = this.place(player.world, position, tface);
		if(placed != 0) {
			player.world[position] = placed;
			return true;
		} else {
			return false;
		}
	}
	
	/**
	 * If Item::placeable returns true, this function
	 * should return an instance of the block that will
	 * be placed.
	 * Params:
	 * 		world = the world where the block has been placed
	 * 		position = where the item should place the block
	 * 		face = side of the block touched when placed
	 */
	public ushort place(World world, BlockPosition position, uint face) {
		return Blocks.air;
	}

	/** 
	 * Function called when the item is used on a block
	 * clicking the right mouse button or performing a long pressure on the screen.
	 * Returns: true if the item is a tool and it has been cosnumed, false otherwise
	 * Example:
	 * ---
	 * // N.B. that this will not work as the block hasn't been placed
	 * world[0, 64, 0] = Blocks.DIRT;
	 * assert(world[0, 64, 0] == Blocks.DIRT);
	 * 
	 * new Items.WoodenShovel().useOnBlock(player, world[0, 64, 0], Faces.TOP);
	 * 
	 * assert(world[0, 64, 0] == Blocks.GRASS_PATH);
	 * ---
	 */
	public bool useOnBlock(Player player, Block block, BlockPosition position, ubyte face) {
		return false;
	}

	/**
	 * Function called when the item is used to the destroy a block.
	 * Returns: true if the item is a tool and it has been consumed, false otherwise
	 * Example:
	 * ---
	 * auto dirt = new Blocks.Dirt();
	 * auto sword = new Items.DiamondSword(Items.DiamondSword.DURABILITY - 2);
	 * auto shovel = new Items.DiamondShovel(Items.DiamondShovel.DURABILITY - 2);
	 * 
	 * assert(sword.finished == false);
	 * assert(shovel.finished == false);
	 * 
	 * sword.destroyOn(player, dirt);	// 2 uses
	 * shovel.destroyOn(player, dirt);	// 1 use
	 * 
	 * assert(sword.finished == true);
	 * assert(shovel.finished == false);
	 * ---
	 */
	public bool destroyOn(Player player, Block block, BlockPosition position) {
		return false;
	}

	/**
	 * Function called when the item is used on an entity as
	 * right click or long screen pressure.
	 * Returns: true if the items is a tool and it has been consumed, false otherwise
	 */
	public bool useOnEntity(Player player, Entity entity) {
		return false;
	}

	/**
	 * Function called when the item is used against an
	 * entity as a left click or screen tap.
	 * Returns: true if the items is a tool and it has been consumed, false otherwise
	 */
	public bool attackOnEntity(Player player, Entity entity) {
		return false;
	}

	/**
	 * Function called when the item is throwed or aimed.
	 * Returns: true if the item count should be reduced by 1, false otherwise
	 */
	public bool onThrowed(Player player) {
		return false;
	}

	/**
	 * Function called when the item is released, usually after
	 * it has been throwed (which is used as aim-start function).
	 * Returns: true if the item has been consumed, false otherwise
	 */
	public bool onReleased(Player holder) {
		return false;
	}

	/**
	 * Gets the item's compound tag with the custom data of the item.
	 * It may be null if the item has no custom behaviours.
	 * Example:
	 * ---
	 * if(item.minecraftCompound is null) {
	 *    assert(item.customName == "");
	 * }
	 * item.customName = "not empty";
	 * assert(item.pocketCompound !is null);
	 * ---
	 */
	public final pure nothrow @property @safe @nogc Compound javaCompound() {
		return this.m_pc_tag;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc Compound pocketCompound() {
		return this.m_pe_tag;
	}

	/**
	 * Parses a compound, usually received from the client or
	 * saved in a world.
	 * The tag should never be null as the method doesn't check it.
	 * Example:
	 * ---
	 * item.parseMinecraftCompound(new Compound(new Compound("display", new String("Name", "custom"))));
	 * assert(item.customName == "custom");
	 * ---
	 */
	public @safe void parseJavaCompound(Compound compound) {
		this.clear();
		this.parseCompound(compound, &Enchantment.fromJava);
	}

	/// ditto
	public @safe void parseBedrockCompound(Compound compound) {
		this.clear();
		this.parseCompound(compound, &Enchantment.fromBedrock);
	}

	private @trusted void parseCompound(Compound compound, Enchantment function(ubyte, ubyte) @safe get) {
		compound = compound.get!Compound("", compound); //TODO is this still required?
		auto display = compound.get!Compound("display", null);
		if(display !is null) {
			immutable name = display.getValue!String("Name", "");
			if(name.length) this.customName = name;
			//TODO lore
		}
		auto ench = compound.get!(ListOf!Compound)("ench", null);
		if(ench !is null) {
			foreach(e ; ench) {
				auto getted = get(cast(ubyte)e.getValue!Short("id", short.init), cast(ubyte)e.getValue!Short("lvl", short.init));
				if(getted !is null) this.addEnchantment(getted);
			}
		}
		if(compound.getValue!Byte("Unbreakable", 0) != 0) {
			this.unbreakable = true;
		}
	}

	/**
	 * Removes the custom behaviours of the item, like custom name
	 * and enchantments.
	 * Example:
	 * ---
	 * item.customName = "name";
	 * assert(item.customName == "name");
	 * item.clear();
	 * assert(item.customName == "");
	 * ---
	 */
	public @trusted void clear() {
		this.m_pc_tag = null;
		this.m_pe_tag = null;
		this.m_name = "";
		this.m_lore = "";
		this.enchantments.clear();
	}

	/**
	 * Gets the item's custom name.
	 */
	public pure nothrow @property @safe @nogc string customName() {
		return this.m_name;
	}

	/**
	 * Sets the item's custom name.
	 * Example:
	 * ---
	 * item.customName = "§aColoured!";
	 * item.customName = ""; // remove
	 * ---
	 */
	public @property @safe string customName(string name) {
		if(name.length) {
			void set(ref Compound compound) {
				auto n = new Named!String("Name", name);
				if(compound is null) compound = new Compound(new Named!Compound("display", n));
				else if(!compound.has!Compound("display")) compound["display"] = new Compound(n);
				else compound.get!Compound("display", null)[] = n;
			}
			set(this.m_pc_tag);
			set(this.m_pe_tag);
		} else {
			void reset(ref Compound compound) {
				auto display = cast(Compound)compound["display"];
				display.remove("Name");
				if(display.empty) {
					compound.remove("display");
					if(compound.empty) compound = null;
				}
			}
			reset(this.m_pc_tag);
			reset(this.m_pe_tag);
		}
		return this.m_name = name;
	}

	/**
	 * Gets the item's lore or description which is displayed under
	 * the item's name when the item is hovered in the player's inventory.
	 */
	public pure nothrow @property @safe @nogc string lore() {
		return this.m_lore;
	}

	public @property @safe string lore(string[] lore) {
		if(lore.length) {
			void set(ref Compound compound) {
				auto n = new Named!(ListOf!String)("Lore", lore);
				if(compound is null) compound = new Compound(new Named!Compound("display", n));
				else if(!compound.has!Compound("display")) compound["display"] = new Compound(n);
				else compound.get!Compound("display", null)[] = n;
			}
			set(this.m_pc_tag);
		} else {
			void reset(ref Compound compound) {
				auto display = cast(Compound)compound["display"];
				display.remove("Lore");
				if(display.empty) {
					compound.remove("display");
					if(compound.empty) compound = null;
				}
			}
			reset(this.m_pc_tag);
		}
		return this.m_lore = lore.join("\n");
	}

	public @property @safe string lore(string lore) {
		return this.lore = lore.split("\n");
	}

	/**
	 * Adds an enchantment to the item.
	 * Throws: EnchantmentException if the enchantment doesn't exist
	 * Example:
	 * ---
	 * item.addEnchantment(new Enchantment(Enchantments.sharpness, 1));
	 * item.addEnchantment(Enchantments.power, 5);
	 * item.addEnchantment(Enchantments.fortune, "X");
	 * item += new Enchantment(Enchantments.smite, 2);
	 * ---
	 */
	public @safe void addEnchantment(Enchantment ench) {
		if(ench is null) throw new EnchantmentException("Invalid enchantment given");
		auto e = ench.id in this.enchantments;
		if(e) {
			// modify
			*e = ench;
			void modify(ref Compound compound, ubyte id) @safe {
				foreach(ref tag ; compound.get!(ListOf!Compound)("ench", null)) {
					if(tag.getValue!Short("id", -1) == id) {
						tag.get!Short("lvl", null).value = ench.level;
						break;
					}
				}
			}
			if(ench.java) modify(this.m_pc_tag, ench.java.id);
			if(ench.bedrock) modify(this.m_pe_tag, ench.bedrock.id);
		} else {
			// add
			this.enchantments[ench.id] = ench;
			void add(ref Compound compound, ubyte id) @safe {
				auto ec = new Compound([new Named!Short("id", id), new Named!Short("lvl", ench.level)]);
				if(compound is null) compound = new Compound([new Named!(ListOf!Compound)("ench", [ec])]);
				else if(!compound.has!(ListOf!Compound)("ench")) compound["ench"] = new ListOf!Compound(ec);
				else compound.get!(ListOf!Compound)("ench", null) ~= ec;
			}
			if(ench.java) add(this.m_pc_tag, ench.java.id);
			if(ench.bedrock) add(this.m_pe_tag, ench.bedrock.id);
		}
	}

	/// ditto
	public @safe void addEnchantment(sel.data.enchantment.Enchantment ench, ubyte level) {
		this.addEnchantment(new Enchantment(ench, level));
	}

	/// ditto
	public @safe void addEnchantment(sel.data.enchantment.Enchantment ench, string level) {
		this.addEnchantment(new Enchantment(ench, level));
	}

	/// ditto
	public @safe void opBinaryRight(string op : "+")(Enchantment ench) {
		this.addEnchantment(ench);
	}

	/// ditto
	alias enchant = addEnchantment;

	/**
	 * Gets a pointer to the enchantment.
	 * This method can be used to check if the item has an
	 * enchantment and its level.
	 * Example:
	 * ---
	 * auto e = Enchantments.protection in item;
	 * if(!e || e.level != 5) {
	 *    item.enchant(Enchantment.protection, 5);
	 * }
	 * assert(Enchantments.protection in item);
	 * ---
	 */
	public @safe Enchantment* opBinaryRight(string op : "in")(inout sel.data.enchantment.Enchantment ench) {
		return ench.java.id in this.enchantments;
	}

	/**
	 * Removes an enchantment from the item.
	 * Example:
	 * ---
	 * item.removeEnchantment(Enchantments.sharpness);
	 * item -= Enchantments.fortune;
	 * ---
	 */
	public @safe void removeEnchantment(inout sel.data.enchantment.Enchantment ench) {
		if(ench.java.id in this.enchantments) {
			this.enchantments.remove(ench.java.id);
			void remove(ref Compound compound, ubyte id) @safe {
				auto list = compound.get!(ListOf!Compound)("ench", null);
				if(list.length == 1) {
					compound.remove("ench");
					if(compound.empty) compound = null;
				} else {
					foreach(i, e; list) {
						if(e.getValue!Short("id", short(-1)) == id) {
							list.remove(i);
							break;
						}
					}
				}
			}
			if(ench.java) remove(this.m_pc_tag, ench.java.id);
			if(ench.bedrock) remove(this.m_pe_tag, ench.bedrock.id);
		}
	}

	/// ditto
	public @safe void opBinaryRight(string op : "-")(inout sul.enchantments.Enchantment ench) {
		this.removeEnchantment(ench);
	}

	/**
	 * If the item is a tool, indicates whether the item is consumed
	 * when used for breaking or combat.
	 */
	public pure nothrow @property @safe @nogc bool unbreakable() {
		return this.m_unbreakable;
	}

	public @property @safe bool unbreakable(bool unbreakable) {
		if(unbreakable) {
			auto u = new Named!Byte("Unbreakable", true);
			if(this.m_pc_tag is null) this.m_pc_tag = new Compound(u);
			else this.m_pc_tag[] = u;
		} else {
			this.m_pc_tag.remove("Unbreakable");
			if(this.m_pc_tag.empty) this.m_pc_tag = null;
		}
		return this.m_unbreakable = unbreakable;
	}

	/**
	 * Deep comparation of 2 instantiated items.
	 * Compare ids, metas, custom names and enchantments.
	 * Example:
	 * ---
	 * Item a = new Items.Beetroot();
	 * Item b = a.dup;
	 * assert(a == b);
	 * 
	 * a.customName = "beetroot";
	 * assert(a != b);
	 * 
	 * b.customName = "beetroot";
	 * a.enchant(Enchantments.protection, "IV");
	 * b.enchant(Enchantments.protection, "IV");
	 * assert(a == b);
	 * ---
	 */
	public override bool opEquals(Object o) {
		if(cast(Item)o) {
			Item i = cast(Item)o;
			return this.javaId == i.javaId &&
				this.bedrockId == i.bedrockId &&
				this.javaMeta == i.javaMeta &&
				this.bedrockMeta == i.bedrockMeta &&
				this.customName == i.customName &&
				this.lore == i.lore &&
				this.enchantments == i.enchantments;
		}
		return false;
	}

	/**
	 * Compare an item with its type as a string or a group of strings.
	 * Example:
	 * ---
	 * Item item = new Items.Beetroot();
	 * assert(item == Items.beetroot);
	 * assert(item == [Items.beetrootSoup, Items.beetroot]);
	 * ---
	 */
	public @safe @nogc bool opEquals(item_t item) {
		return item == this.data.index;
	}

	/// ditto
	public @safe @nogc bool opEquals(item_t[] items) {
		foreach(item ; items) {
			if(this.opEquals(item)) return true;
		}
		return false;
	}

	/**
	 * Returns the item as string in format "name" or "name:damage" for tools.
	 */
	public override string toString() {
		//TODO override in tools to print damage
		return this.name ~ "(" ~ this.customName ~ ", " ~ to!string(this.enchantments.values) ~ ")";
	}

	/**
	 * Create a slot with the Item::max as count
	 * Example:
	 * ---
	 * Slot a = new Slot(new Items.Beetroot(), 12);
	 * Slot b = new Items.Beetroot(); // same as new Items.Beetroot().slot;
	 * 
	 * assert(a.count == 12);
	 * assert(b.count == 64);
	 * ---
	 */
	public final @property @safe Slot slot() {
		return Slot(this);
	}

	alias slot this;

}

//TODO the translatable should affect the compound tag
/*template Translatable(T:Item) {
	alias Translatable = GenericTranslatable!("this.customName", T);
}*/

class SimpleItem(sul.items.Item _data) : Item {

	public @safe this(E...)(E args) {
		super(args);
	}

	public override pure nothrow @property @safe @nogc const sul.items.Item data() {
		return _data;
	}
	
	alias slot this;

}
