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
module sel.block.farming;

import std.algorithm : min;
import std.conv : to;
import std.string : split;
import std.traits : isNumeric;

import common.sel;

import sel.player : Player;
import sel.block.block : Block, SimpleBlock, Update;
import sel.block.blocks : Blocks;
import sel.block.solid;
import sel.entity.entity : Entity;
import sel.item.item : Item;
import sel.item.items : Items;
import sel.item.slot : Slot;
import sel.item.tool : Tools;
import sel.math.vector : BlockPosition;
import sel.world.world : World;

static import sul.blocks;

class FertileTerrain(sul.blocks.Block sb, bool hydrated, block_t wetter, block_t dryer) : MineableBlock!(sb, MiningTool(false, Tools.pickaxe, Tools.wood), Drop(Items.dirt, 1)) {

	public final override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}

	/*public override void place(ref World world, BlockPosition position) {
		super.place(world, position);
		if(!this.init) {
			this.init = true;
			this.section = this.world[(this.position.x - 4)..(this.position.x + 5), this.position.y..min(this.position.y+1, $), (this.position.z - 4)..(this.position.z + 5)];
		}
	}*/

	/*public override void onRandomTick() {
		static if(hydrated) {
			//check if the water still there
			Block b;
			if(this.water is null || (b = this.section[this.water.x, this.water.y, this.water.z]) !is null || b != Blocks.WATER) {
				if(!this.searchWater) {
					//it has been de-hydrated
					//TODO should this be done as 'this = this.world.block(Blocks.NYF, this.section, null)' ?
					this.world[this.position] = new Blocks.NotHydratedFarmland(this.section, null);
				}
			}
		} else {
			//check if this block could be hydrated
			if(this.searchWater) {
				//TODO watch the last todo before this one
				this.world[this.position] = new Blocks.HydratedFarmland(this.section, this.water);
			} else if(this.up is null || this.up != Blocks.CROP) {
				this = Blocks.DIRT;
			}
		}
	}*/

	/**
	 * Searches for water in the section.
	 * Returns: true if water was found, false otherwise
	 */
	/*protected @property bool searchWater() {
		foreach(uint x ; 0..this.section.opDollar!0) {
			foreach(uint y ; 0..this.section.opDollar!1) {
				foreach(uint z ; 0..this.section.opDollar!2) {
					Block b;
					if((b = this.section[x, y, z]) !is null && b == Blocks.WATER) {
						this.water = new BlockPosition(x, y, z);
						return true;
					}
				}
			}
		}
		return false;
	}*/

	public override void onUpdated(World world, BlockPosition position, Update update) {
		Block up = world[position + [0, 1, 0]];
		if(up.solid) world[position] = Blocks.dirt;
		//TODO moved by piston
		//TODO stepped
	}

}

class CropBlock(sul.blocks.Block sb, block_t next, Drop[] drops, alias growTo=null) : MineableBlock!(sb, MiningTool.init, drops) {

	private enum mayGrow = is(typeof(growTo) == ushort) || is(typeof(growTo) == ushort[]);

	static if(next != 0 || mayGrow) {
		public override pure nothrow @property @safe @nogc bool doRandomTick() {
			return true;
		}
	}

	public override void onRandomTick(World world, BlockPosition position) {
		if(world.random.probability(world[position - [0, 1, 0]] != Blocks.farmland7 ? .125 : .25)) {
			this.grow(world, position);
		}
	}

	public void grow(World world, BlockPosition position) {
		static if(next != 0) {
			world[position] = next;
		} else static if(mayGrow) {
			//search for a place to grow
			BlockPosition[] positions = [position + [1, 0, 0], position + [0, 0, 1], position - [1, 0, 0], position - [0, 0, 1]];
			world.random.shuffle(positions);
			foreach(BlockPosition pos ; positions) {
				if(world[pos] == Blocks.air) {
					Block s = world[pos - [0, 1, 0]];
					if(s == [Blocks.grass, Blocks.dirt, Blocks.coarseDirt, Blocks.podzol] ~ Blocks.farmland) {
						static if(is(typeof(growTo) == ushort[])) {
							ubyte face;
							if(position.x == pos.x) {
								if(position.z > pos.z) face = Facing.north;
								else face = Facing.south;
							} else {
								if(position.x > pos.x) face = Facing.west;
								else face = Facing.east;
							}
							world[pos] = growTo[face];
						} else {
							world[pos] = growTo;
						}
						break;
					}
				}
			}
		}
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		if(world[position - [0, 1, 0]] != Blocks.farmland) {
			world.drop(this, position);
			world[position] = Blocks.air;
		}
	}

}

class ChanceCropBlock(sul.blocks.Block sb, ushort next, Drop[] drops, ubyte a, ubyte b) : CropBlock!(sb, next, drops, null) {

	public override void onRandomTick(World world, BlockPosition position) {
		if(world.random.next(b) < a) {
			super.onRandomTick(world, position);
		}
	}

}

class StemBlock(sul.blocks.Block sb, block_t next, item_t drop, alias growTo=null) : CropBlock!(sb, next, [], growTo) {

	public override Slot[] drops(World world, Player player, Item item) {
		immutable amount = (){
			immutable r = world.random.next(0, 125);
			if(r < 100) return 0;
			else if(r < 120) return 1;
			else if(r < 124) return 2;
			else return 3;
		}();
		if(amount) {
			auto func = world.items.getConstructor(drop);
			if(func !is null) {
				Slot[] ret;
				foreach(i ; 0..amount) {
					ret ~= Slot(func(0), 1);
				}
				return ret;
			}
		}
		return [];
	}

}

class GrowingBlock(sul.blocks.Block sb, block_t next, block_t[] compare, size_t height, bool waterNeeded, block_t[] requiredBlock, Drop drops) : MineableBlock!(sb, MiningTool.init, drops) {

	public override void onRandomTick(World world, BlockPosition position) {
		//TODO check if there's water around
		static if(next == 0) {
			@property bool tooHigh() {
				size_t h = 1;
				auto pos = position - [0, 1, 0];
				while(world[pos] == compare && ++h < height) pos -= [0, 1, 0];
				return h >= height;
			}
			auto up = position + [0, 1, 0];
			if(world[up] == Blocks.air && !tooHigh) {
				world[up] = compare[0];
			}
		} else {
			world[position] = next;
		}
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		auto down = world[position - [0, 1, 0]];
		if(down != compare && (down != requiredBlock || !this.searchWater(world, position))) {
			world.drop(this, position);
			world[position] = Blocks.air;
		}
	}

	private bool searchWater(World world, BlockPosition position) {
		static if(waterNeeded) {
			foreach(p ; [[0, -1, 1], [1, -1, 0], [0, -1, -1], [-1, -1, 0]]) {
				if(world[position + p] == Blocks.water) return true;
			}
			return false;
		} else {
			return true;
		}
	}

}

alias SugarCanesBlock(sul.blocks.Block sb, block_t next) = GrowingBlock!(sb, next, Blocks.sugarCanes, 3, true, [Blocks.sand, Blocks.redSand, Blocks.dirt, Blocks.coarseDirt, Blocks.podzol, Blocks.grass], Drop(Items.sugarCanes, 1));

class CactusBlock(sul.blocks.Block sb, block_t next) : GrowingBlock!(sb, next, Blocks.cactus, 3, false, [Blocks.sand, Blocks.redSand], Drop(Items.cactus, 1)) {

	//TODO do cactus damage on step and on contact

}

class NetherCrop(sul.blocks.Block sb, block_t next, Drop drop) : CropBlock!(sb, next, [drop]) {

	public override void onRandomTick(World world, BlockPosition position) {
		this.grow(world, position);
	}

}

class BeansBlock(sul.blocks.Block sb, block_t next, ubyte facing, MiningTool miningTool, Drop drop) : MineableBlock!(sb, miningTool, drop) {

	static if(next != 0) {

		public override pure nothrow @property @safe @nogc bool doRandomTick() {
			return true;
		}

		public override void onRandomTick(World world, BlockPosition position) {
			world[position] = next; // every random tick?
		}

	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		//TODO verify facing
		static if(facing == Facing.north) {
			auto attached = position + [0, 0, 1];
		} else static if(facing == Facing.south) {
			auto attached = position - [0, 0, 1];
		} else static if(facing == Facing.west) {
			auto attached = position + [1, 0, 0];
		} else {
			auto attached = position - [1, 0, 0];
		}
		if(world[attached] != Blocks.jungleWood) {
			world.drop(this, position);
			world[attached] = Blocks.air;
		}
	}

}
