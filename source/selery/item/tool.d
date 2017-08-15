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
module selery.item.tool;

import std.conv : ConvException;
import std.json : JSONValue, JSON_TYPE;

import sel.nbt.tags;

import selery.about;
import selery.block.block : Block, Faces;
import selery.block.blocks : Blocks;
import selery.entity.entity : Entity;
import selery.entity.living : Living;
import selery.item.item : Item;
import selery.math.vector : BlockPosition;
import selery.player.player : Player;
import selery.util.color : Color, Colorable;

static import sul.items;

enum Durability : ushort {

	gold = 31,
	wood = 60,
	stone = 132,
	iron = 251,
	diamond = 1562,
	shears = 238,
	fishingRod = 65,
	flintAndSteel = 65,
	carrotOnAStick = 26,
	bow = 385,
	
}

enum Tools : ubyte {

	none = 0,
	shovel = 1,
	pickaxe = 2,
	axe = 3,
	hoe = 4,
	armor = 5,
	shears = 6,
	sword = 8, // flag

	all = 0,
	wood = 1,
	stone = 2,
	gold = 3,
	iron = 4,
	diamond = 5,

}

abstract class Tool : Item {
	
	protected ushort damage;
	
	public @safe this(E...)(E args) {
		static if(E.length > 0 && is(typeof(E[0]) : int)) {
			super(args[1..$]);
			this.damage = args[0] & ushort.max;
		} else {
			super(args);
		}
	}
	
	public override pure nothrow @property @safe @nogc ushort javaMeta() {
		return this.damage;
	}
	
	public override pure nothrow @property @safe @nogc ushort pocketMeta() {
		return this.damage;
	}
	
	public override pure nothrow @property @safe @nogc bool tool() {
		return true;
	}

	public abstract pure nothrow @property @safe @nogc ushort durability();
	
	public override pure nothrow @property @safe @nogc bool finished() {
		return this.damage >= this.durability;
	}
	
	protected void applyDamage(ushort amount) {
		if(!this.unbreakable) this.damage += amount;
	}
	
	alias unbreakable = super.unbreakable;
	
	public override @property @safe bool unbreakable(bool unbreakable) {
		if(super.unbreakable(unbreakable)) {
			this.damage = 0;
			return true;
		} else {
			return false;
		}
	}
	
}

class ToolItem(sul.items.Item si, ubyte _type, ubyte _material, ushort _durability, uint _attack=1) : Tool {
	
	public @safe this(E...)(E args) {
		super(args);
	}

	public override pure nothrow @property @safe @nogc const sul.items.Item data() {
		return si;
	}
	
	public override pure nothrow @property @safe @nogc ubyte toolType() {
		return _type;
	}
	
	public override pure nothrow @property @safe @nogc ubyte toolMaterial() {
		return _material;
	}
	
	public override pure nothrow @property @safe @nogc ushort durability() {
		return _durability;
	}
	
	public override pure nothrow @property @safe @nogc uint attack() {
		return _attack;
	}
	
	alias slot this;
	
}

class SwordItem(sul.items.Item si, ubyte material, ushort durability, uint attack) : ToolItem!(si, Tools.sword, material, durability, attack) {

	public this(E...)(E args) {
		super(args);
	}
	
	public override bool destroyOn(Player player, Block block, BlockPosition position) {
		if(!block.instantBreaking) {
			this.applyDamage(2);
			return true;
		}
		return false;
	}
	
	public override bool attackOnEntity(Player player, Entity entity) {
		if(cast(Living)entity) {
			this.applyDamage(1);
			return true;
		}
		return false;
	}
	
	alias slot this;
	
}

class MiningItem(sul.items.Item si, ubyte tool, ubyte material, ushort durability, uint attack) : ToolItem!(si, tool, material, durability, attack) {

	public this(E...)(E args) {
		super(args);
	}

	public override bool destroyOn(Player player, Block block, BlockPosition position) {
		if(!block.instantBreaking) {
			this.applyDamage(1);
			return true;
		}
		return false;
	}

	public override bool attackOnEntity(Player player, Entity entity) {
		if(cast(Living)entity) {
			this.applyDamage(2);
			return true;
		}
		return false;
	}
	
	alias slot this;

}

alias PickaxeItem(sul.items.Item si, ubyte material, ushort durability, uint attack) = MiningItem!(si, Tools.pickaxe, material, durability, attack);

alias AxeItem(sul.items.Item si, ubyte material, ushort durability, uint attack) = MiningItem!(si, Tools.axe, material, durability, attack);

class ShovelItem(sul.items.Item si, ubyte material, ushort durability, uint attack) : MiningItem!(si, Tools.shovel, material, durability, attack) {

	public this(E...)(E args) {
		super(args);
	}

	public override bool useOnBlock(Player player, Block block, BlockPosition position, ubyte face) {
		if(face != Faces.DOWN && block == Blocks.grass && player.world[position + [0, 1, 0]] == Blocks.air) {
			player.world[position] = Blocks.grassPath;
			this.applyDamage(1);
			return true;
		}
		return false;
	}
	
	alias slot this;

}

class HoeItem(sul.items.Item si, ubyte material, ushort durability) : ToolItem!(si, Tools.hoe, material, durability, 1) {

	public this(E...)(E args) {
		super(args);
	}

	public override bool useOnBlock(Player player, Block block, BlockPosition position, ubyte face) {
		if(face != Faces.DOWN && (block == [Blocks.dirt, Blocks.grass, Blocks.grassPath]) && player.world[position + [0, 1, 0]] == Blocks.air) {
			player.world[position] = Blocks.farmland0;
			this.applyDamage(1);
			return true;
		}
		return false;
	}

	public override bool attackOnEntity(Player player, Entity entity) {
		if(cast(Living)entity) {
			this.applyDamage(1);
			return true;
		}
		return false;
	}
	
	alias slot this;

}

interface Armor {

	public enum ubyte helmet = 0;
	public enum ubyte chestplate = 1;
	public enum ubyte leggings = 2;
	public enum ubyte boots = 3;

	public alias cap = helmet;
	public alias tunic = chestplate;
	public alias pants = leggings;

	public @property ubyte type();

	public @property uint protection();

	public bool doDamage(Player player);

}

class ArmorItem(sul.items.Item si, ushort durability, ubyte atype, uint aprotection, E...) : ToolItem!(si, Tools.armor, 0, durability, 1, E), Armor if(atype <= 3) {

	public this(E...)(E args) {
		super(args);
	}

	public override @property ubyte type() {
		return atype;
	}

	public override @property uint protection() {
		return aprotection;
	}

	public override bool doDamage(Player player) {
		this.applyDamage(1);
		return true;
	}
	
	alias slot this;

}

class ColorableArmorItem(sul.items.Item si, ushort durability, ubyte atype, uint aprotection) : ArmorItem!(si, durability, atype, aprotection), Colorable {

	private Color m_color;

	public this(E...)(E args) {
		static if(E.length && is(typeof(E[0] == Color))) {
			if(args[0] !is null) {
				super(args[1..$]);
				this.color = args[0];
			}
		} else {
			super(args);
		}
	}

	public override @trusted void parseJSON(JSONValue data) {
		super.parseJSON(data);
		if(data.type == JSON_TYPE.OBJECT) {
			auto c = "color" in data;
			if(c) {
				if(c.type == JSON_TYPE.STRING && c.str.length == 6) {
					try {
						auto color = Color.fromString(c.str);
						if(color !is null) this.color = color;
					} catch(ConvException) {}
				} else if(c.type == JSON_TYPE.INTEGER) {
					this.color = Color.fromRGB(cast(uint)c.integer);
				}
			}
		}
	}

	public override void parseJavaCompound(Compound compound) {
		super.parseJavaCompound(compound);
		compound = compound.get!Compound("", compound);
		auto display = compound.get!Compound("display", new Compound());
		if(display.has!Int("color")) this.color = Color.fromRGB(display.getValue!Int("color", 0));
	}

	public override void parsePocketCompound(Compound compound) {
		super.parsePocketCompound(compound);
		compound = compound.get!Compound("", compound);
		if(compound.has!Int("customColor")) this.color = Color.fromRGB(compound.getValue!Int("customColor", 0));
	}

	/**
	 * Gets the item's custom colour.
	 */
	public override pure nothrow @property @safe @nogc Color color() {
		return this.m_color;
	}

	/**
	 * Sets the item's custom colour.
	 */
	public override @property Color color(Color color) {
		if(color is null) {
			// remove
			{
				auto display = this.m_pc_tag.get!Compound("display", null);
				display.remove("color");
				if(display.empty) {
					this.m_pc_tag.remove("display");
					if(this.m_pc_tag.empty) this.m_pc_tag = null;
				}
			}
			{
				this.m_pe_tag.remove("customColor");
				if(this.m_pe_tag.empty) this.m_pe_tag = null;
			}
		} else {
			// add
			uint rgb = color.rgb;
			{
				auto cc = new Named!Int("color", rgb);
				if(this.m_pc_tag is null) this.m_pc_tag = new Compound(new Named!Compound("display", cc));
				else if(!this.m_pc_tag.has!Compound("display")) this.m_pc_tag["display"] = new Compound(cc);
				else this.m_pc_tag.get!Compound("display", null)[] = cc;
			}
			{
				auto cc = new Named!Int("customColor", rgb);
				if(this.m_pe_tag is null) this.m_pe_tag = new Compound(cc);
				else this.m_pe_tag[] = cc;
			}
		}
		return this.m_color = color;
	}
	
	alias slot this;

}

class PlaceableArmor(sul.items.Item si, E...) : ArmorItem!(si, 1, 0, 0) {

	public this(E...)(E args) {
		super(args);
	}

	public override pure nothrow @property @safe @nogc bool tool() {
		return false;
	}

	public override bool doDamage(Player player) {
		return false;
	}
	
	alias slot this;

}
