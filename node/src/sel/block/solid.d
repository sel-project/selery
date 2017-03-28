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

import std.algorithm : canFind, min;
import std.conv : to;
import std.math : ceil;

import common.sel;

import sel.block.block : Update, Remove, Block, SimpleBlock, Instance;
import sel.block.blocks : Blocks;
import sel.entity.entity : Entity;
import sel.entity.projectile : FallingBlock;
import sel.item.enchanting : Enchantments;
import sel.item.item : Item;
import sel.item.items : Items;
import sel.item.slot : Slot;
import sel.item.tool : Tools;
import sel.math.vector : BlockPosition;
import sel.player : Player;
import sel.util.random : Random;
import sel.world.world : World;

static import sul.blocks;

enum Facing : ubyte {

	upDown = 0 << 4,
	eastWest = 1 << 4,
	northSouth = 2 << 4,
	bark = 3 << 4,

	y = upDown,
	x = eastWest,
	z = northSouth,

	south = 0,
	west = 1,
	north = 2,
	east = 3,

}

/**
 * Class for a block that drops one or more items when mined.
 * ---
 */
class MineableBlock(sul.blocks.Block sb, MiningTool miningTool, Drop[] cdrops, Experience exp=Experience.init) : SimpleBlock!(sb) {

	mixin Instance;

	static if(cdrops.length) {

		private template DropsTuple(Drop[] a, E...) {
			static if(a.length) {
				alias DropsTuple = DropsTuple!(a[1..$], E, a[0]);
			} else {
				alias DropsTuple = E;
			}
		}

		// use a typetuple for the drops
		alias dropsTuple = DropsTuple!(cdrops[1..$], cdrops[0]);
		
		public override Slot[] drops(World world, Player player, Item item) {
			static if(miningTool.material != Tools.all) {
				// validate the tool
				if(item is null || item.toolType != miningTool.type || item.toolMaterial != miningTool.material) return [];
			}
			ubyte[item_t] ret;
			foreach(drop ; dropsTuple) {
				static if(drop.silkTouch != 0) {
					if(item !is null && Enchantments.silkTouch in item) return [Slot(world.items.get(drop.silkTouch))];
				} else static if(drop.item != 0) {
					static if(drop.max <= drop.min) {
						ubyte amount = cast(ubyte)drop.min;
					} else static if(drop.min <= 0) {
						immutable a = world.random.range(drop.min, drop.max);
						if(a <= 0) return [];
						ubyte amount = cast(ubyte)a;
					} else {
						ubyte amount = cast(ubyte)world.random.range(drop.min, drop.max);
					}
					static if(drop.fortune !is null) {
						if(item.hasEnchantment(Enchantments.fortune)) drop.fortune(amount, item.getEnchantmentLevel(Enchantments.fortune), world.random);
					}
					ret[drop.item] += amount;
				}
			}
			Slot[] slots;
			foreach(item, amount; ret) {
				auto func = world.items.getConstructor(item);
				if(func !is null) {
					//TODO do not drop more than 3/4 items (group them)
					foreach(i ; 0..amount) {
						slots ~= Slot(func(0), 1);
					}
				}
			}
			return slots;
		}

	}

	public override uint xp(World world, Player player, Item item) {
		static if(miningTool.material != Tools.all) {
			// validate the tool
			if(item is null || item.toolType != miningTool.type || item.toolMaterial != miningTool.material) return 0;
		}
		static if(cdrops.length) {
			foreach(drop ; dropsTuple) {
				static if(drop.silkTouch != 0) {
					// do not drop experience when mined with silk touch
					if(item !is null && Enchantments.silkTouch in item) return 0;
				}
			}
		}
		static if(exp.max <= exp.min) {
			uint amount = exp.min;
		} else {
			uint amount = world.random.range(exp.min, exp.max);
		}
		static if(exp.fortune) {
			auto fortune = Enchantments.fortune in item;
			if(fortune) amount += min((*fortune).level, 3) * exp.fortune;
		}
		return amount;
	}

	public override tick_t miningTime(Player player, Item item) {
		static if(miningTool.type & Tools.sword) {
			if(item !is null && item.toolType == Tools.sword) return cast(tick_t)ceil(sb.hardness * 20);
		}
		double time = sb.hardness; // from seconds to ticks
		static if(miningTool.material == Tools.all) {
			time *= 1.5;
		} else {
			time *= item !is null && item.toolMaterial >= miningTool.material ? 1.5 : 5;
		}
		static if([Tools.pickaxe, Tools.axe, Tools.shovel].canFind(miningTool.type & 7)) {
			if(item.toolType == (miningTool.type & 7)) {
				final switch(item.toolMaterial) {
					case Tools.wood:
						time /= 2;
						break;
					case Tools.stone:
						time /= 4;
						break;
					case Tools.iron:
						time /= 6;
						break;
					case Tools.diamond:
						time /= 8;
						break;
					case Tools.gold:
						time /= 12;
						break;
				}
			}
		}
		return cast(tick_t)ceil(time * 20);
	}
	
}

/// ditto
alias MineableBlock(sul.blocks.Block sb, MiningTool miningTool, Drop drop, Experience exp=Experience.init) = MineableBlock!(sb, miningTool, [drop], exp);

struct MiningTool {

	ubyte type = Tools.none;
	ubyte material = Tools.all;

	public this(ubyte type, ubyte material) {
		this.type = type;
		this.material = material;
	}

	public this(bool required, ubyte type, ubyte material) {
		this(type, required ? material : Tools.all);
	}

}

struct Drop {

	public item_t item;
	public int min;
	public int max;

	public item_t silkTouch;

	ubyte function(ref ubyte, ubyte, ref Random) fortune = null;

	/*static ubyte plusOne(ref ubyte amount, ubyte level, ref Random random) {
		amount += min(level, 3);
	}*/

}

struct Experience {

	uint min, max, fortune;

}

alias StoneBlock(sul.blocks.Block sb, item_t item, item_t silkTouch=0) = MineableBlock!(sb, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(item, 1, 1, silkTouch));

class RedstoneOreBlock(sul.blocks.Block sb, bool lit, block_t change) : MineableBlock!(sb, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.redstoneDust, 4, 5, Items.redstoneOre), Experience(1, 5, 1)) {

	//TODO +1 with fortune

	mixin Instance;

	static if(lit) {

		public final override pure nothrow @property @safe @nogc bool doRandomTick() {
			return true;
		}

		public final override void onRandomTick(World world, BlockPosition position) {
			world[position] = change;
		}

	} else {

		public override void onEntityStep(Entity entity, BlockPosition position, float fallDistance) {
			entity.world[position] = change;
		}

		public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
			player.world[position] = change;
			return false;
		}

	}
	
}

class SpreadingBlock(sul.blocks.Block sb, MiningTool miningTool, Drop[] drops, block_t[] spreadTo, uint r_x, uint r_z, uint r_y_down, uint r_y_up, block_t suffocation) : MineableBlock!(sb, miningTool, drops) {

	mixin Instance;

	public final override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}

	public override void onRandomTick(World world, BlockPosition position) {
		static if(suffocation != 0) {
			//checks for suffocation
			auto up = world[position + [0, 1, 0]];
			if(up.opacity == 15) { //TODO also fluids
				world[position] = suffocation;
				return;
			}
		}
		//grow
		BlockPosition[] positions; //TODO calculate at compile time
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
			if(b == spreadTo) {
				auto sup = world[target + [0, 1, 0]];
				if(!sup.hasBoundingBox) {
					world[target] = this.id;
					break;
				}
			}
		}
	}

}

alias SimpleSpreadingBlock(sul.blocks.Block sb, MiningTool miningTool, Drop[] drops, block_t[] spreadTo, uint r_x, uint r_z, uint r_y, block_t suffocation) = SpreadingBlock!(sb, miningTool, drops, spreadTo, r_x, r_z, r_y, r_y, suffocation);

class SaplingBlock(sul.blocks.Block sb, size_t drop, block_t[] logs, block_t[] leaves) : MineableBlock!(sb, MiningTool.init, Drop(drop, 1)) if(logs.length == 4 && leaves.length == 4) {

	mixin Instance;

}

class GravityBlock(sul.blocks.Block sb, MiningTool miningTool, Drop drop) : MineableBlock!(sb, miningTool, drop) {

	mixin Instance;

	public override void onUpdated(World world, BlockPosition position, Update update) {
		if(!world[position].solid) {
			world[position] = Blocks.air;
			world.spawn!FallingBlock(this, position);
		}
	}

}

final class GravelBlock(sul.blocks.Block sb) : GravityBlock!(sb, MiningTool.init, Drop.init) {

	mixin Instance;

	public override Slot[] drops(World world, Player player, Item item) {
		Slot[] impl(float prob) {
			return [Slot(world.items.get(world.random.next!float <= prob ? Items.flint : Items.gravel), 1)];
		}
		if(item !is null) {
			auto fortune = Enchantments.fortune in item;
			if(fortune && Enchantments.silkTouch !in item) {
				switch((*fortune).level) {
					case 1: return impl(.14f);
					case 2: return impl(.25f);
					default: return [Slot(world.items.get(Items.flint), 1)];
				}
			}
		}
		return impl(.1f);
	}

}

alias WoodBlock(sul.blocks.Block sb, item_t drop) = MineableBlock!(sb, MiningTool(false, Tools.axe, Tools.wood), Drop(drop, 1));

class LeavesBlock(sul.blocks.Block sb, bool decayable, item_t drop, item_t sapling, float smallDrop, bool dropApples) : SimpleBlock!(sb) {

	mixin Instance;

	static if(smallDrop) {
		enum float[] saplingDrop = [.05, .0625, .0833, .1];
	} else {
		enum float[] saplingDrop = [.025, .0278, .03125, .0417];
	}

	enum float[] appleDrop = [.005, .00556, .00625, .0833];

	public override Slot[] drops(World world, Player player, Item item) {
		if(item !is null && item == Items.shears) {
			return [Slot(world.items.get(drop), 1)];
		} else if(player !is null) {
			size_t lvl = 0;
			if(item !is null) {
				auto fortune = Enchantments.fortune in item;
				if(fortune) lvl = min(3, (*fortune).level);
			}
			return this.decayDrop(world, saplingDrop[lvl], appleDrop[lvl]);
		} else {
			return [];
		}
	}

	private Slot[] decayDrop(World world, float sp, float ap) {
		Slot[] ret;
		if(world.random.next!float <= sp) {
			ret ~= Slot(world.items.get(sapling), 1);
		}
		static if(dropApples) {
			if(world.random.next!float <= ap) {
				ret ~= Slot(world.items.get(Items.apple), 1);
			}
		}
		return ret;
	}

	static if(decayable) {

		public final override pure nothrow @property @safe @nogc bool doRandomTick() {
			return true;
		}

		public override void onRandomTick(World world, BlockPosition position) {
			//TODO check decay
		}

	}

}

class AbsorbingBlock(sul.blocks.Block sb, item_t drop, block_t wet, block_t[] absorb, size_t maxDistance, size_t maxBlocks) : MineableBlock!(sb, MiningTool.init, Drop(drop, 1)) {

	public override void onUpdated(World world, BlockPosition position, Update update) {
		// also called when the block is placed
		//TODO try to absorb water
	}

}

alias FlowerBlock(sul.blocks.Block sb, item_t drop) = MineableBlock!(sb, MiningTool.init, Drop(drop, 1));

class DoublePlantBlock(sul.blocks.Block sb, bool top, block_t other, item_t drop, bool isGrass=false) : SimpleBlock!(sb) {

	mixin Instance;

	enum count = isGrass ? 2 : 1;

	public override Slot[] drops(World world, Player player, Item item) {
		static if(isGrass) {
			if(item is null || item.toolType != Tools.shears) return [];
		}
		return [Slot(world.items.get(drop), count)];
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		static if(top) {
			auto pos = position - [0, 1, 0];
		} else {
			auto pos = position + [0, 1, 0];
		}
		if(world[pos] != other) {
			world[pos] = Blocks.air;
		}
	}

}

class PlantBlock(sul.blocks.Block sb, item_t shears, Drop hand) : SimpleBlock!(sb) {

	mixin Instance;

	public override Slot[] drops(World world, Player player, Item item) {
		Slot[] ret;
		if(item !is null && item.toolType == Tools.shears) {
			ret ~= Slot(world.items.get(shears), 1);
		} else {
			foreach(i ; 0..world.random.range(hand.min, hand.max)) {
				ret ~= Slot(world.items.get(hand.item), 1);
			}
		}
		return ret;
	}

}

class StairsBlock(sul.blocks.Block sb, ubyte facing, bool upsideDown, MiningTool miningTool, item_t drop) : MineableBlock!(sb, miningTool, Drop(drop, 1)) {

	mixin Instance;

	//TODO

}

class CakeBlock(sul.blocks.Block sb, block_t next) : SimpleBlock!(sb) {

	mixin Instance;

	public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
		player.hunger = player.hunger + 2;
		player.saturate(.4f);
		player.world[position] = next;
		return true;
	}

	public override tick_t miningTime(Player player, Item item) {
		return 15;
	}

}

class MonsterEggBlock(sul.blocks.Block sb, block_t disguise) : MineableBlock!(sb, MiningTool.init, Drop(0, 0, 0, disguise)) {

	mixin Instance;

	public override void onRemoved(World world, BlockPosition position, Remove type) {
		if(type == Remove.broken || type == Remove.exploded) {
			//TODO spawn silverfish
			//TODO only if not silk touch
		}
	}

}

class InactiveEndPortalBlock(sul.blocks.Block sb, block_t active, ubyte dir) : SimpleBlock!(sb) {

	mixin Instance;

	public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
		if(!player.inventory.held.empty && player.inventory.held.item == Items.eyeOfEnder) {
			player.inventory.held = player.inventory.held.count == 1 ? Slot(null) : Slot(player.inventory.held.item, cast(ubyte)(player.inventory.held.count - 1));
			player.world[position] = active;
			//TODO check for portal creation
			return true;
		} else {
			return false;
		}
	}

}
