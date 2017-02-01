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

import sel.player : Player;
import sel.block.block : BlockData, BlockDataArray, Blocks, Block, SimpleBlock, MineableBlock, Update;
import sel.block.flags;
import sel.block.solid : Facing;
import sel.item.item : Item;
import sel.item.slot : Slot;
import sel.math.vector : BlockPosition;
import sel.world.world : World;

class FertileTerrain(BlockData blockdata, bool hydrated, E...) : MineableBlock!(blockdata, RANDOM_TICK, E) {

	/*public override void place(ref World world, BlockPosition position) {
		super.place(world, position);
		if(!this.init) {
			this.init = true;
			this.section = this.world[(this.position.x - 4)..(this.position.x + 5), this.position.y..min(this.position.y+1, $), (this.position.z - 4)..(this.position.z + 5)];
		}
	}

	public override void onRandomTick() {
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
	}

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
	}

	public override void onUpdate(Update update) {
		if(update == Update.NEAREST_CHANGED && !this.breathe(false)) {
			this = Blocks.DIRT;
		}
		//TODO moved by piston
		//TODO stepped
	}*/

}

class CropBlock(BlockData blockdata, BlockData next, string[string] dropped_items, alias grow_to=null,) : SimpleBlock!(blockdata, SHAPELESS, INSTANT_BREAKING) if(isValidDrop!dropped_items && (is(typeof(grow_to) == typeof(null)) || is(typeof(grow_to) == BlockData) || is(typeof(grow_to) == BlockDataArray))) {

	private byte[string] min, max;

	public this() {
		static if(dropped_items !is null) {
			this.min = minDrop!dropped_items;
			this.max = maxDrop!dropped_items;
		}
	}

	public override Slot[] drops(World world, Player player, Item item) {
		Slot[] items;
		foreach(string item, byte m; this.min) {
			if(world.items.has(item)) {
				//TODO apply fortune enchantment?
				byte amount = m == this.max[item] ? m : world.random.range!byte(m, this.max[item]);
				if(amount > 0) {
					foreach(uint i ; 0..amount) {
						items ~= Slot(world.items.get(item), 1);
					}
				}
			}
		}
		return items;
	}

	public override pure nothrow @property @safe @nogc bool doRandomTick() {
		static if(next != Blocks.AIR || !is(typeof(grow_to) == typeof(null))) {
			return true;
		} else {
			return false;
		}
	}

	public override void onRandomTick(World world, BlockPosition position) {
		if(world.random.probability(world[position - [0, 1, 0]] != Blocks.HYDRATED_FARMLAND ?/* .125 : .25*/.25 : .5)) {
			this.grow(world, position);
		}
	}

	public void grow(World world, BlockPosition position) {
		static if(next != Blocks.AIR) {
			world[position] = next;
		} else static if(!is(typeof(grow_to) == typeof(null))) {
			if(this.checkFruit(world, position)) {
				//search for a place to grow
				BlockPosition[] positions = [position + [1, 0, 0], position + [0, 0, 1], position - [1, 0, 0], position - [0, 0, 1]];
				world.random.shuffle(positions);
				foreach(BlockPosition pos ; positions) {
					if(world[pos] == Blocks.AIR) {
						Block s = world[pos - [0, 1, 0]];
						if(s == ([Blocks.DIRT, Blocks.GRASS, Blocks.PODZOL] ~ Blocks.FARMLAND)) {
							static if(is(typeof(grow_to) == BlockDataArray)) {
								ubyte face;
								if(position.x == pos.x) {
									if(position.z > pos.z) face = Facing.NORTH;
									else face = Facing.SOUTH;
								} else {
									if(position.x > pos.x) face = Facing.WEST;
									else face = Facing.EAST;
								}
								world[pos] = grow_to[face];
							} else {
								world[pos] = grow_to;
							}
							break;
						}
					}
				}
			}
		}
	}

	private bool checkFruit(World world, BlockPosition position) {
		static if(!(is(typeof(grow_to) == typeof(null)))) {
			foreach(BlockPosition pos ; [position + [0, 0, 1], position - [0, 0, 1], position + [1, 0, 0], position - [1, 0, 0]]) {
				if(world[pos] == grow_to) return false;
			}
		}
		return true;
	}

	public override void onUpdate(World world, BlockPosition position, Update update) {
		if(update == Update.PLACED || update == Update.NEAREST_CHANGED) {
			if(world[position - [0, 1, 0]] != Blocks.FARMLAND) {
				//end my existance
				world.drop(this, position);
				world[position] = Blocks.AIR;
			}
		}
	}

}

private bool isValidDrop(string[string] drops)() {
	if(drops is null) return true;
	foreach(string n, string drop; drops) {
		if(drop.split("..").length > 2) return false;
		/*if(drop.split("..").length == 1 && !drop.isNumeric) return false;
		if(!drop.split("..")[0].isNumeric || !drop.split("..").isNumeric) return false;*/
	}
	return true;
}

alias minDrop(string[string] drops) = getDrops!(0, drops);

alias maxDrop(string[string] drops) = getDrops!(1, drops);

private byte[string] getDrops(uint index, string[string] drops)() {
	byte[string] ret;
	if(drops is null) return ret;
	foreach(string i, string d; drops) {
		if(d.split("..").length == 1) {
			ret[i] = to!byte(d);
		} else {
			ret[i] = to!byte(d.split("..")[index]);
		}
	}
	return ret;
}
