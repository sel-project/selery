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
module sel.item.tool;

import common.sel;

import sel.player : Player;
import sel.block.block : Block, Blocks, Faces;
import sel.entity.entity : Entity;
import sel.entity.living : Living;
import sel.item.flags : META;
import sel.item.item;
import sel.math.vector : BlockPosition;
import sel.util.color : Color;

enum Durability : ushort {
	
	GOLD = 31,
	WOOD = 60,
	STONE = 132,
	IRON = 251,
	DIAMOND = 1562,
	SHEARS = 238,
	FISHING_RODS = 65,
	FLINT_AND_STEEL = 65,
	CARRONT_ON_A_STICK = 26,
	BOW = 385,
	
}

enum Tool : ubyte {

	NO = 0,

	SWORD = 1,
	SHOVEL = 2,
	PICKAXE = 3,
	AXE = 4,
	HOE = 5,
	ARMOR = 6,

	WOODEN = 1,
	STONE = 2,
	GOLDEN = 3,
	IRON = 4,
	DIAMOND = 5,
	GENERIC = 6,

}

class SwordItem(string name, shortgroup ids, ubyte material, ushort durability, uint attack) : ToolItem!(name, ids, META!0, Tool.SWORD, material, durability, attack) {

	public this(F...)(F args) {
		super(args);
	}
	
	public override bool destroyOn(Player player, Block block, BlockPosition position) {
		if(player.consumeTools && !block.instantBreaking) {
			this.damage += 2;
			return true;
		}
		return false;
	}
	
	public override bool attackOnEntity(Player player, Entity entity) {
		if(player.consumeTools && cast(Living)entity) {
			this.damage++;
			return true;
		}
		return false;
	}
	
	alias slot this;
	
}

class MiningItem(string name, shortgroup ids, ubyte tool, ubyte material, ushort durability, uint attack) : ToolItem!(name, ids, META!0, tool, material, durability, attack) {

	public this(F...)(F args) {
		super(args);
	}

	public override bool destroyOn(Player player, Block block, BlockPosition position) {
		if(player.consumeTools && !block.instantBreaking) {
			this.damage++;
			return true;
		}
		return false;
	}

	public override bool attackOnEntity(Player player, Entity entity) {
		if(player.consumeTools && cast(Living)entity) {
			this.damage += 2;
			return true;
		}
		return false;
	}
	
	alias slot this;

}

alias PickaxeItem(string name, shortgroup ids, ubyte material, ushort durability, uint attack) = MiningItem!(name, ids, Tool.PICKAXE, material, durability, attack);

alias AxeItem(string name, shortgroup ids, ubyte material, ushort durability, uint attack) = MiningItem!(name, ids, Tool.AXE, material, durability, attack);

class ShovelItem(string name, shortgroup ids, ubyte material, ushort durability, uint attack) : MiningItem!(name, ids, Tool.SHOVEL, material, durability, attack) {

	public this(F...)(F args) {
		super(args);
	}

	public override bool useOnBlock(Player player, Block block, BlockPosition position, ubyte face) {
		if(face != Faces.DOWN && block == Blocks.GRASS && player.world[position + [0, 1, 0]] == Blocks.AIR) {
			player.world[position] = Blocks.GRASS_PATH;
			if(player.consumeTools) {
				this.damage++;
				return true;
			}
		}
		return false;
	}
	
	alias slot this;

}

class HoeItem(string name, shortgroup ids, ubyte material, ushort durability) : ToolItem!(name, ids, META!0, Tool.HOE, material, durability, 1) {

	public this(F...)(F args) {
		super(args);
	}

	public override bool useOnBlock(Player player, Block block, BlockPosition position, ubyte face) {
		if(face != Faces.DOWN && (block == [Blocks.DIRT, Blocks.GRASS]) && player.world[position + [0, 1, 0]] == Blocks.AIR) {
			player.world[position] = Blocks.NOT_HYDRATED_FARMLAND;
			if(player.consumeTools) {
				this.damage++;
				return true;
			}
		}
		return false;
	}

	public override bool attackOnEntity(Player player, Entity entity) {
		if(player.consumeTools && cast(Living)entity) {
			this.damage++;
			return true;
		}
		return false;
	}
	
	alias slot this;

}

interface Armor {

	public static immutable uint HELMET = 0;
	public static immutable uint CHESTPLATE = 1;
	public static immutable uint LEGGINGS = 2;
	public static immutable uint BOOTS = 3;

	public static immutable uint CAP = HELMET;
	public static immutable uint TUNIC = CHESTPLATE;
	public static immutable uint PANTS = LEGGINGS;

	public @property uint type();

	public @property uint protection();

	public bool doDamage(Player player);

}

class ArmorItem(string name, shortgroup ids, ushort durability, uint atype, uint aprotection, E...) : ToolItem!(name, ids, META!0, Tool.ARMOR, Tool.GENERIC, durability, 1, E), Armor if(atype >= 0 && atype <= 3) {

	public this(F...)(F args) {
		super(args);
	}

	public override @property uint type() {
		return atype;
	}

	public override @property uint protection() {
		return aprotection;
	}

	public override bool doDamage(Player player) {
		if(player.consumeTools) {
			this.damage++;
			return true;
		}
		return false;
	}
	
	alias slot this;

}

class ColorableArmorItem(string name, shortgroup ids, ushort durability, uint atype, uint aprotection, E...) : ArmorItem!(name, ids, durability, atype, aprotection, E), Colorable {

	private Color m_color;

	public this(F...)(F args) {
		super(args);
	}

	public override @property Color color() {
		return this.m_color;
	}

	public override @property Color color(Color color) {
		return this.m_color = color;
	}
	
	alias slot this;

}

class PlaceableArmor(string name, shortgroup ids, E...) : ArmorItem!(name, ids, 1, 0, 0) {

	public this(F...)(F args) {
		super(args);
	}

	public override bool doDamage(Player player) {
		return false;
	}
	
	alias slot this;

}
