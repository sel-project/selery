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
module sel.block.solid;

import std.conv : to;

import sel.block.block : BlockData, Block, MineableBlock;
import sel.block.flags;
import sel.math.vector : BlockPosition;
import sel.world.world : World;

enum Facing : ubyte {

	UP_DOWN = 0 << 4,
	EAST_WEST = 1 << 4,
	NORTH_SOUTH = 2 << 4,
	BARK = 3 << 4,

	Y = UP_DOWN,
	X = EAST_WEST,
	Z = NORTH_SOUTH,

	SOUTH = 0,
	WEST = 1,
	NORTH = 2,
	EAST = 3,

}

class SpreadingBlock(BlockData blockdata, BlockData[] spread_to, uint r_x, uint r_z, uint r_y_down, uint r_y_up, BlockData suffocation, E...) : MineableBlock!(blockdata, RANDOM_TICK, E) {

	public override void onRandomTick(World world, BlockPosition position) {
		static if(suffocation.id != 0) {
			//checks for suffocation
			if(!this.breathe(world, position)) {
				world[position] = suffocation;
				return;
			}
		}
		//grow
		BlockPosition[] positions;
		foreach(int x ; position.x-r_x..position.x+r_x+1) {
			foreach(int y ; position.y-r_y_down..position.y+r_y_up+1) {
				foreach(int z ; position.z-r_z..position.z+r_z+1) {
					if(y >= 0) positions ~= BlockPosition(x, y, z);
				}
			}
		}
		world.random.shuffle(positions);
		foreach(BlockPosition target ; positions) {
			Block b = world[target];
			if(b == spread_to && b.breathe(world, target)) {
				world[target] = blockdata;
				break;
			}
		}
	}

}

alias SimpleSpreadingBlock(BlockData blockdata, BlockData[] spread_to, uint r_x, uint r_z, uint r_y, BlockData suffocation, E...) = SpreadingBlock!(blockdata, spread_to, r_x, r_z, r_y, r_y, suffocation, E);

/*interface Layer {

	public bool canGrow();

	public void grow();

}

class LayerBlock(string name, bytegroup ids, ubyte stage, ubyte max_stage, float shape_start, float shape_end, ubyte replaceable_until, E...) : MineableBlock!(name, ids, META!stage, SHAPE([shape_start, 0f, shape_start, shape_end, to!float(stage+1)/to!float(max_stage+1), shape_end]), stage <= replaceable_until ? REPLACEABLE : "", E), Layer if(stage <= max_stage) {

	public override bool canGrow() {
		static if(stage == max_stage) return false;
		else return true;
	}

	public override void grow() {
		static if(stage < max_stage) {
			this.world[this.position] = new LayerBlock!(name, ids, stage + 1, max_stage, shape_start, shape_end, replaceable_until, E)();
		}
	}

}*/

/*

//TODO it's not a solid! It's a plant

class Sapling : Solid {

	public static immutable ubyte OAK = 0;
	public static immutable ubyte SRUCE = 1;
	public static immutable ubyte BIRCH = 2;
	public static immutable ubyte JUNGLE = 3;
	public static immutable ubyte ACACIA = 4;
	public static immutable ubyte DARK_OAK = 5;

	public this(ubyte type) {
		super(Blocks.SAPLING, type, TRANSPARENT | BURNABLE, null);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.SAPLING.item(this.meta), 1)];
	}

}

class Bedrock : Solid {

	public this() {
		super(Blocks.BEDROCK, 0, NOTHING, Shapes.FULL);
	}

}

class Sand : Gravity {

	public static immutable ubyte NORMAL = 0;
	public static immutable ubyte RED = 1;

	public this(ubyte meta=NORMAL) {
		super(Blocks.SAND, meta, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.SAND.item(this.meta), 1)];
	}

}

class Gravel : Gravity {

	public this() {
		super(Blocks.GRAVEL, 0, NOTHING, Shapes.FULL);
	}

	//TODO drops

}

class GoldOre : Solid {

	public this() {
		super(Blocks.GOLD_ORE, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		if(item !is null && (cast(DiamondPickaxe)item || cast(IronPickaxe)item)) {
			return [new Slot(Items.GOLD_ORE.item, 1)];
		}
		return [];
	}

}

class IronOre : Solid {

	public this() {
		super(Blocks.IRON_ORE, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		if(item !is null && (cast(DiamondPickaxe)item || cast(IronPickaxe)item || cast(StonePickaxe)item)) {
			return [new Slot(Items.IRON_ORE.item, 1)];
		}
		return [];
	}

}

class CoalOre : Solid {

	public this() {
		super(Blocks.COAL_ORE, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		if(item !is null && cast(Pickaxe)item) {
			if(item.hasEnchantment(Enchantments.SILK_TOUCH)) return [new Slot(Items.COAL_ORE.item, 1)];
			else {
				Slot[] ret;
				foreach(uint i ; 0..(item.hasEnchantment(Enchantments.FORTUNE) ? min(4, item.getEnchantmentLevel(Enchantments.FORTUNE) + 1).to!ubyte : 1)) {
					ret ~= new Slot(Items.COAL.item, 1);
				}
				return ret;
			}
		}
		return [];
	}

	public override uint xp(Item item, Human holder) {
		return (item is null || item.hasEnchantment(Enchantments.SILK_TOUCH) || !cast(Pickaxe)item) ? 0 : holder.world.random.range(0, 2);
	}

}

class Wood : Solid {

	public static immutable ubyte OAK = 0;
	public static immutable ubyte SPRUCE = 1;
	public static immutable ubyte BIRCH = 2;
	public static immutable ubyte JUNGLE = 3;

	public static immutable ubyte UP_DOWN = 0 << 4;
	public static immutable ubyte EAST_WEST = 1 << 4;
	public static immutable ubyte NORTH_SOUTH = 2 << 4;
	public static immutable ubyte BARK = 3 << 4;

	public this(ubyte meta) {
		super(Blocks.WOOD, meta, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.WOOD.item(this.meta), 1)];
	}

}

class Leaves : Solid {

	public bool decay = false;
	
	public static immutable ushort OAK = 0;
	public static immutable ushort SPRUCE = 1;
	public static immutable ushort BIRCH = 2;
	public static immutable ushort JUNGLE = 3;

	public static immutable ushort ACACIA = 4;
	public static immutable ushort DARK_OAK = 5;

	enum DEFAULT_SAPLING_DROPS = [.05f, .0625f, .0833f, .1f];
	enum JUNGLE_SAPLING_DROPS = [.025f, .0278f, .03125f, .0417f];

	enum APPLES = [.005f, 000556f, .00625f, .00833f];

	public this(ubyte meta) {
		super(Blocks.LEAVES, meta, BURNABLE, Shapes.FULL);
		this.doRandomTick = true;
	}

	public override Slot[] drops(Item item, Human holder) {
		if(item !is null && cast(Shears)item) {
			return [new Slot(Items.LEAVES.item(this.meta), 1)];
		} else {
		Slot[] ret;
			uint fortune = item !is null && item.hasEnchantment(Enchantments.FORTUNE) ? min(3, item.getEnchantmentLevel(Enchantments.FORTUNE)) : 0;
			if(holder is null ? random(0, 20) == 0 : holder.world.random.probability(this.meta == JUNGLE ? JUNGLE_SAPLING_DROPS[fortune] : DEFAULT_SAPLING_DROPS[fortune])) ret ~= new Slot(Items.SAPLING.item(this.meta), 1);
			if(this.meta == OAK && (holder is null ? random(0, 200) == 0 : holder.world.random.probability(APPLES[fortune]))) ret ~= new Slot(Items.APPLE.item, 1);
			return ret;
		}
	}

	public override void randomTick() {
		if(this.decay) {
			this.world[this.position] = null;
		}
	}

}

class Sponge : Solid {

	public this() {
		super(Blocks.SPONGE, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.SPONGE.item, 1)];
	}

}

class Glass : Solid {

	public this() {
		super(Blocks.GLASS, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		if(item !is null && item.hasEnchantment(Enchantments.SILK_TOUCH)) return [new Slot(Items.GLASS.item, 1)];
		else return [];
	}

}

class LapisLazuliOre : Solid {

	public this() {
		super(Blocks.LAPIS_LAZULI_ORE, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		if(item !is null && (cast(StonePickaxe)item || cast(DiamondPickaxe)item || cast(IronPickaxe)item)) {
			if(item.hasEnchantment(Enchantments.SILK_TOUCH)) return [new Slot(Items.LAPIS_LAZULI_ORE.item, 1)];
			else {
				Slot[] ret;
				foreach(uint i ; 0..(holder.world.random.range(4, 8) * (item.hasEnchantment(Enchantments.FORTUNE) ? holder.world.random.range(2, item.getEnchantmentLevel(Enchantments.FORTUNE) + 1) : 1))) {
					ret ~= new Slot(Items.DYE.item(4), 1);
				}
				return ret;
			}
		}
		return [];
	}

	public override uint xp(Item item, Human holder) {
		if(item is null || item.hasEnchantment(Enchantments.FORTUNE) || (!cast(DiamondPickaxe)item && !cast(StonePickaxe)item && !cast(IronPickaxe)item)) return 0;
		else return holder.world.random.range(2, 5);
	}

}

class LapisLazuliBlock : Solid {

	public this() {
		super(Blocks.LAPIS_LAZULI_BLOCK, 0, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.LAPIS_LAZULI_BLOCK.item, 1)];
	}

}

class Sandstone : Solid {

	public static immutable ubyte CLASSIC = 0;
	public static immutable ubyte CHISELED = 1;
	public static immutable ubyte SMOOTH = 2;

	public this(ubyte type) {
		super(Blocks.SANDSTONE, type, NOTHING, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.SANDSTONE.item(this.meta), 1)];
	}

}

class NoteBlock : Solid {

	public uint note = 0;

	public this() {
		super(Blocks.NOTE_BLOCK, 8, INTERACTABLE, Shapes.FULL);
	}

	public override Slot[] drops(Item item, Human holder) {
		return [new Slot(Items.NOTE_BLOCK.item, 1)];
	}

	public override void interact(Human human, BlockPosition position) {
		human.world.addParticle(Particles.NOTE, position.entityPosition.add(.5, 1.2, .5), this.note);
		++this.note %= 24;
		//TODO play sound
	}

}



class SnowLayer : Gravity {

	public this(ubyte meta) {
		meta &= 7;
		super(Blocks.SNOW_LAYER, meta, NOTHING, [0, 0, 0, 1, meta * .125, 1]);
	}

}*/
