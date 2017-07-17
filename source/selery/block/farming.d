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
module selery.block.farming;

import selery.about : block_t, item_t;
import selery.block.block : Block, Update;
import selery.block.blocks : Blocks;
import selery.block.solid;
import selery.entity.entity : Entity;
import selery.item.item : Item;
import selery.item.items : Items;
import selery.item.slot : Slot;
import selery.item.tool : Tools;
import selery.math.vector : BlockPosition;
import selery.player.player : Player;
import selery.world.world : World;

static import sul.blocks;

class FertileTerrainBlock(bool hydrated) : MineableBlock {

	private block_t wetter, dryer;

	public this(sul.blocks.Block data, block_t wetter, block_t dryer) {
		super(data, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1));
		this.wetter = wetter;
		this.dryer = dryer;
	}

	public final override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}

	public override void onRandomTick(World world, BlockPosition position) {
		static if(hydrated) {
			//TODO check if the water still there, otherwise convert to dryer
		} else {
			//TODO check if this block could be hydrated and convert to wetter, otherwise convert to dryer (if not 0)
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
	}*/

	public override void onUpdated(World world, BlockPosition position, Update update) {
		Block up = world[position + [0, 1, 0]];
		if(up.solid) world[position] = Blocks.dirt;
		//TODO moved by piston
		//TODO stepped
	}

}

class FarmingBlock : MineableBlock {

	public this(sul.blocks.Block data, Drop[] drops) {
		super(data, MiningTool.init, drops);
	}
	
	public override void onUpdated(World world, BlockPosition position, Update update) {
		if(world[position - [0, 1, 0]] != Blocks.farmland) {
			world.drop(this, position);
			world[position] = Blocks.air;
		}
	}

}

class GrowingFarmingBlock : FarmingBlock {

	public this(sul.blocks.Block data, Drop[] drops) {
		super(data, drops);
	}

	public override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}

	public override void onRandomTick(World world, BlockPosition position) {
		if(world.random.probability(world[position - [0, 1, 0]] != Blocks.farmland7 ? .125 : .25)) {
			this.grow(world, position);
		}
	}

	public abstract void grow(World, BlockPosition);

}

class StageCropBlock : GrowingFarmingBlock {

	private block_t next;

	public this(sul.blocks.Block data, Drop[] drops, block_t next) {
		super(data, drops);
		this.next = 0;
	}

	public this(sul.blocks.Block data, block_t next, Drop[] drops=[]) {
		this(data, drops, next);
	}

	public override void grow(World world, BlockPosition position) {
		world[position] = this.next;
	}

}

class FruitCropBlock(bool isArray) : GrowingFarmingBlock {

	static if(isArray) {
		alias grow_t = block_t[4];
	} else {
		alias grow_t = block_t;
	}

	private grow_t growTo;

	public this(sul.blocks.Block data, Drop[] drops, grow_t growTo) {
		super(data, drops);
	}

	public this(sul.blocks.Block data, grow_t growTo, Drop[] drops=[]) {
		this(data, drops, growTo);
	}

	public override void grow(World world, BlockPosition position) {
		//search for a place to grow
		BlockPosition[] positions = [position + [1, 0, 0], position + [0, 0, 1], position - [1, 0, 0], position - [0, 0, 1]];
		world.random.shuffle(positions);
		foreach(BlockPosition pos ; positions) {
			if(world[pos] == Blocks.air) {
				Block s = world[pos - [0, 1, 0]];
				if(s == Blocks.dirts) {
					static if(isArray) {
						ubyte face;
						if(position.x == pos.x) {
							if(position.z > pos.z) face = Facing.north;
							else face = Facing.south;
						} else {
							if(position.x > pos.x) face = Facing.west;
							else face = Facing.east;
						}
						world[pos] = this.growTo[face];
					} else {
						world[pos] = this.growTo;
					}
					break;
				}
			}
		}
	}

}

class ChanceCropBlock : StageCropBlock {

	private ubyte a, b;

	public this(sul.blocks.Block data, Drop[] drops, block_t next, ubyte a, ubyte b) {
		super(data, drops, next);
		this.a = a;
		this.b = b;
	}

	public this(sul.blocks.Block data, block_t next, Drop[] drops, ubyte a, ubyte b) {
		this(data, drops, next, a, b);
	}

	public override void onRandomTick(World world, BlockPosition position) {
		if(world.random.next(this.b) < this.a) {
			//TODO call this.grow ?
			super.onRandomTick(world, position);
		}
	}

}

//class StemBlock(bool isArray) : FruitCropBlock!isArray {

template StemBlock(T) {

	class StemBlock : T {

		private item_t drop;

		public this(E...)(sul.blocks.Block data, item_t drop, E args) {
			super(data, args);
			this.drop = drop;
		}

		public override Slot[] drops(World world, Player player, Item item) {
			immutable amount = (){
				immutable r = world.random.next(0, 125);
				if(r < 100) return 0;
				else if(r < 120) return 1;
				else if(r < 124) return 2;
				else return 3;
			}();
			if(amount) {
				auto func = world.items.getConstructor(this.drop);
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

}

//class GrowingBlock(sul.blocks.Block sb, block_t next, block_t[] compare, size_t height, bool waterNeeded, block_t[] requiredBlock, Drop drops) : MineableBlock!(sb, MiningTool.init, drops) {

class GrowingBlock(bool needsWater) : MineableBlock {

	private block_t next;
	private block_t[] compare, requiredBlock;
	private size_t height;

	public this(sul.blocks.Block data, Drop[] drops, block_t next, block_t[] compare, block_t[] requiredBlock, size_t height) {
		super(data, MiningTool.init, drops);
		this.next = next;
		this.compare = compare;
		this.requiredBlock = requiredBlock;
		this.height = height;
	}

	public override void onRandomTick(World world, BlockPosition position) {
		//TODO check if there's water around
		if(this.next == 0) { //TODO do this check when constructed
			@property bool tooHigh() {
				size_t h = 1;
				auto pos = position - [0, 1, 0];
				while(world[pos] == compare && ++h < this.height) pos -= [0, 1, 0];
				return h >= this.height;
			}
			auto up = position + [0, 1, 0];
			if(world[up] == Blocks.air && !tooHigh) {
				world[up] = this.compare[0];
			}
		} else {
			world[position] = this.next;
		}
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		auto down = world[position - [0, 1, 0]];
		if(down != this.compare && (down != this.requiredBlock || !this.searchWater(world, position))) {
			world.drop(this, position);
			world[position] = Blocks.air;
		}
	}

	private bool searchWater(World world, BlockPosition position) {
		static if(needsWater) {
			foreach(p ; [[0, -1, 1], [1, -1, 0], [0, -1, -1], [-1, -1, 0]]) {
				if(world[position + p] == Blocks.water) return true;
			}
			return false;
		} else {
			return true;
		}
	}

}

class SugarCanesBlock : GrowingBlock!true {

	public this(sul.blocks.Block data, block_t next) {
		super(data, [Drop(Items.sugarCanes, 1)], next, Blocks.sugarCanes, [Blocks.sand, Blocks.redSand, Blocks.dirt, Blocks.coarseDirt, Blocks.podzol, Blocks.grass], 3);
	}

}

class CactusBlock : GrowingBlock!false {

	public this(sul.blocks.Block data, block_t next) {
		super(data, [Drop(Items.cactus, 1)], next, Blocks.cactus, [Blocks.sand, Blocks.redSand], 3);
	}

	//TODO do cactus damage on step and on contact

}

class NetherCropBlock : MineableBlock {

	public this(sul.blocks.Block data, Drop drop) {
		super(data, MiningTool.init, drop);
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		auto pos = position - [0, 1, 0];
		if(world[pos] != Blocks.soulSand) {
			world.drop(this, position);
			world[pos] = Blocks.air;
		}
	}

}

class StageNetherCropBlock : NetherCropBlock {

	private block_t next;

	public this(sul.blocks.Block data, block_t next, Drop drop) {
		super(data, drop);
		this.next = next;
	}

	public override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}

	public override void onRandomTick(World world, BlockPosition position) {
		world[position] = this.next;
	}

}

class BeansBlock : MineableBlock {

	private BlockPosition facing;

	public this(sul.blocks.Block data, MiningTool miningTool, Drop drop, ubyte facing) {
		super(data, miningTool, [drop]);
		if(facing == Facing.north) {
			this.facing = BlockPosition(0, 0, 1);
		} else if(facing == Facing.south) {
			this.facing = BlockPosition(0, 0, -1);
		} else if(facing == Facing.west) {
			this.facing = BlockPosition(1, 0, 0);
		} else {
			this.facing = BlockPosition(-1, 0, 0);
		}
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		//TODO verify facing
		auto attached = position + this.facing;
		if(world[attached] != Blocks.jungleWood) {
			world.drop(this, position);
			world[attached] = Blocks.air;
		}
	}

}

class GrowingBeansBlock : BeansBlock {

	private block_t next;

	public this(sul.blocks.Block data, MiningTool miningTool, Drop drop, ubyte facing, block_t next) {
		super(data, miningTool, drop, facing);
	}

	public override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}
	
	public override void onRandomTick(World world, BlockPosition position) {
		world[position] = this.next; // every random tick?
	}

}
