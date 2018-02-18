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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/block/solid.d, selery/block/solid.d)
 */
module selery.block.solid;

import std.algorithm : canFind, min;
import std.conv : to;
import std.math : ceil;
import std.random : Random, uniform, uniform01, randomShuffle;

import selery.about : block_t, item_t, tick_t;
import selery.block.block : Update, Remove, Block;
import selery.block.blocks : Blocks;
import selery.enchantment : Enchantments;
import selery.entity.entity : Entity;
import selery.entity.projectile : FallingBlock;
import selery.item.item : Item;
import selery.item.items : Items;
import selery.item.slot : Slot;
import selery.item.tool : Tools;
import selery.math.vector : BlockPosition;
import selery.player.player : Player;
import selery.world.world : World;

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

/+class MineableBlock(sul.blocks.Block sb, MiningTool miningTool, Drop[] cdrops, Experience exp=Experience.init) : SimpleBlock!(sb) {

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
	
}+/

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

	void function(ref ubyte, ubyte, ref Random) fortune = null;

	static void plusOne(ref ubyte amount, ubyte level, ref Random random) {
		amount += level > 3 ? 3 : level;
	}

}

struct Experience {

	uint min, max, fortune;

}

class MineableBlock : Block {

	private const MiningTool _miningTool;
	private const Drop[] _drops;
	private const Experience _exp;

	private bool delegate(Item) validateTool;

	public this(sul.blocks.Block data, inout MiningTool miningTool, inout Drop[] drops, inout Experience exp=Experience.init) {
		super(data);
		this._miningTool = miningTool;
		this._drops = drops;
		this._exp = exp;
		if(miningTool.material == Tools.none || drops.length == 0) {
			this.validateTool = &validateToolNo;
		} else {
			this.validateTool = &validateToolYes;
		}
	}

	public this(sul.blocks.Block data, inout MiningTool miningTool, inout Drop drop, inout Experience exp=Experience.init) {
		this(data, miningTool, [drop], exp);
	}

	public override Slot[] drops(World world, Player player, Item item) {
		if(this.validateTool(item)) {
			bool silkTouch = item !is null && Enchantments.silkTouch in item; //TODO only calculate if needed
			ubyte[item_t] ret;
			foreach(drop ; this._drops) {
				if(drop.silkTouch && silkTouch) {
					ret[drop.silkTouch] = 1;
				} else if(drop.item) {
					if(drop.max) {
						auto res = uniform!"[]"(drop.min, drop.max, world.random);
						if(res > 0) ret[drop.item] = cast(ubyte)res;
					} else {
						ret[drop.item] = cast(ubyte)drop.min;
					}
				}
			}
			if(ret.length) {
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
		return [];
	}

	//TODO exp

	//TODO mining time

	// functions

	private bool validateToolNo(Item item) {
		return true;
	}

	private bool validateToolYes(Item item) {
		return item !is null && item.toolType == this._miningTool.type && item.toolMaterial >= this._miningTool.material;
	}

}

class StoneBlock : Block {

	private immutable item_t drop, silk_touch;

	public this(sul.blocks.Block data, item_t item, item_t silkTouch=0) {
		super(data);
		this.drop = item;
		this.silk_touch = silkTouch;
	}

	public override Slot[] drops(World world, Player player, Item item) {
		if(item !is null) {
			if(Enchantments.silkTouch in item) {
				return [Slot(world.items.get(this.silk_touch))]; //TODO may be 0
			} else if(item.toolType == Tools.pickaxe) {
				return [Slot(world.items.get(this.drop))];
			}
		}
		return [];
	}

	//TODO mining time

}

class RedstoneOreBlock(bool lit) : MineableBlock {

	private block_t change;

	public this(sul.blocks.Block data, block_t change) {
		super(data, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.redstoneDust, 4, 5, Items.redstoneOre), Experience(1, 5, 1));
		this.change = change;
	}

	//TODO +1 with fortune

	static if(lit) {

		public final override pure nothrow @property @safe @nogc bool doRandomTick() {
			return true;
		}

		public final override void onRandomTick(World world, BlockPosition position) {
			world[position] = this.change;
		}

	} else {

		public override void onEntityStep(Entity entity, BlockPosition position, float fallDistance) {
			entity.world[position] = this.change;
		}

		public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
			player.world[position] = this.change;
			return false;
		}

	}
	
}

class SpreadingBlock : MineableBlock {

	private block_t[] spreadTo;

	private BlockPosition[] positions;

	public this(sul.blocks.Block data, MiningTool miningTool, Drop[] drops, block_t[] spreadTo, uint r_x, uint r_z, uint r_y_down, uint r_y_up) {
		super(data, miningTool, drops);
		this.spreadTo = spreadTo;
		// instantiate positions here instead of instatiate them every time onRandomTick is called
		BlockPosition[] positions;
		foreach(int x ; r_x..r_x+1) {
			foreach(int y ; r_y_down..r_y_up+1) {
				foreach(int z ; r_z..r_z+1) {
					this.positions ~= BlockPosition(x, y, z);
				}
			}
		}
	}

	public final override pure nothrow @property @safe @nogc bool doRandomTick() {
		return true;
	}

	public override void onRandomTick(World world, BlockPosition position) {
		// spread
		randomShuffle(this.positions, world.random);
		foreach(check ; this.positions) {
			BlockPosition target = position + check;
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

class SuffocatingSpreadingBlock : SpreadingBlock {

	private block_t suffocation;

	public this(sul.blocks.Block data, MiningTool miningTool, Drop[] drops, block_t[] spreadTo, uint r_x, uint r_z, uint r_y_down, uint r_y_up, block_t suffocation) {
		super(data, miningTool, drops, spreadTo, r_x, r_z, r_y_down, r_y_up);
	}

	public override void onRandomTick(World world, BlockPosition position) {
		auto up = world[position + [0, 1, 0]];
		if(up.opacity == 15 || up.fluid) {
			world[position] = this.suffocation;
			return;
		}
		super.onRandomTick(world, position);
	}

}

class SaplingBlock : MineableBlock {

	private block_t[4] logs, leaves;

	public this(sul.blocks.Block data, size_t drop, block_t[] logs, block_t[4] leaves) {
		super(data, MiningTool.init, Drop(drop, 1));
		this.logs = logs;
		this.leaves = leaves;
	}

	//TODO grow with bone meal

}

class GravityBlock : MineableBlock {

	public this(sul.blocks.Block data, MiningTool miningTool, Drop[] drops) {
		super(data, miningTool, drops);
	}

	public this(sul.blocks.Block data, MiningTool miningTool, Drop drop) {
		this(data, miningTool, [drop]);
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		if(!world[position].solid) {
			world[position] = Blocks.air;
			world.spawn!FallingBlock(this, position);
		}
	}

}

final class GravelBlock : GravityBlock {

	public this(sul.blocks.Block data) {
		super(data, MiningTool.init, []);
	}

	public override Slot[] drops(World world, Player player, Item item) {
		Slot[] impl(float prob) {
			return [Slot(world.items.get(uniform01(world.random) <= prob ? Items.flint : Items.gravel), 1)];
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

class WoodBlock : MineableBlock {

	public this(sul.blocks.Block data, item_t drop) {
		super(data, MiningTool(false, Tools.axe, Tools.wood), Drop(drop, 1));
	}

}

class LeavesBlock(bool decayable, bool dropApples) : Block {

	private enum ubyte[4] bigSaplingDrop = [20, 16, 12, 10];
	private enum ubyte[4] smallSaplingDrop = [40, 36, 32, 24];
	private enum ubyte[4] appleDrop = [200, 180, 160, 120];

	private immutable item_t drop, sapling;

	private ubyte[4] saplingDrop;

	public this(sul.blocks.Block data, item_t drop, item_t sapling, bool smallDrop) {
		super(data);
		this.drop = drop;
		this.sapling = sapling;
		if(smallDrop) {
			this.saplingDrop = smallSaplingDrop;
		} else {
			this.saplingDrop = bigSaplingDrop;
		}
	}

	public override Slot[] drops(World world, Player player, Item item) {
		if(item !is null && item == Items.shears) {
			return [Slot(world.items.get(this.drop), 1)];
		} else if(player !is null) {
			size_t lvl = 0;
			if(item !is null) {
				auto fortune = Enchantments.fortune in item;
				if(fortune) lvl = min(3, (*fortune).level);
			}
			return this.decayDrop(world, this.saplingDrop[lvl], appleDrop[lvl]);
		} else {
			return [];
		}
	}

	private Slot[] decayDrop(World world, ubyte sp, ubyte ap) {
		Slot[] ret;
		if(uniform(0, sp, world.random) == 0) {
			ret ~= Slot(world.items.get(this.sapling), 1);
		}
		static if(dropApples) {
			if(uniform(0, ap, world.random) == 0) {
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

class AbsorbingBlock : MineableBlock {

	public this(sul.blocks.Block data, item_t drop, block_t wet, block_t[] absorb, size_t maxDistance, size_t maxBlocks) {
		super(data, MiningTool.init, Drop(drop, 1));
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		// also called when the block is placed
		//TODO try to absorb water
	}

}

class FlowerBlock : MineableBlock {

	public this(sul.blocks.Block data, item_t drop) {
		super(data, MiningTool.init, Drop(drop, 1));
	}

}

class DoublePlantBlock : Block {

	private int y;
	private block_t other;
	private item_t drop;
	private ubyte count;

	public this(sul.blocks.Block data, bool top, block_t other, item_t drop, ubyte count=1) {
		super(data);
		this.count = count;
		this.y = top ? -1 : 1;
		this.other = other;
		this.drop = drop;
		this.count = count;
	}

	public override Slot[] drops(World world, Player player, Item item) {
		return [Slot(world.items.get(this.drop), this.count)];
	}

	public override void onUpdated(World world, BlockPosition position, Update update) {
		auto pos = position + [0, this.y, 0];
		if(world[pos] != this.other) {
			world[pos] = Blocks.air;
		}
	}

}

class GrassDoublePlantBlock : DoublePlantBlock {

	public this(sul.blocks.Block data, bool top, block_t other, item_t drop) {
		super(data, top, other, drop, 2);
	}

	public override Slot[] drops(World world, Player player, Item item) {
		if(item !is null && item.toolType == Tools.shears) return super.drops(world, player, item);
		else return [];
	}

}

class PlantBlock : Block {

	private item_t shears;
	private Drop hand;

	public this(sul.blocks.Block data, item_t shears, Drop hand) {
		super(data);
		this.shears = shears;
		this.hand = hand;
	}

	public override Slot[] drops(World world, Player player, Item item) {
		Slot[] ret;
		if(item !is null && item.toolType == Tools.shears) {
			ret ~= Slot(world.items.get(this.shears), 1);
		} else {
			ubyte count = cast(ubyte)uniform!"[]"(this.hand.min, this.hand.max, world.random);
			if(count) {
				auto f = world.items.getConstructor(this.hand.item);
				if(f !is null) {
					foreach(i ; 0..count) {
						ret ~= Slot(f(0), 1);
					}
				}
			}
		}
		return ret;
	}

}

class StairsBlock : MineableBlock {

	public this(sul.blocks.Block data, ubyte facing, bool upsideDown, MiningTool miningTool, item_t drop) {
		super(data, miningTool, Drop(drop, 1));
	}

	//TODO

}

class CakeBlock : Block {

	private block_t next;

	public this(sul.blocks.Block data, block_t next) {
		super(data);
		this.next = next;
	}

	public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
		player.hunger = player.hunger + 2;
		player.saturate(.4f);
		player.world[position] = this.next;
		return true;
	}

	public override tick_t miningTime(Player player, Item item) {
		return 15;
	}

}

class MonsterEggBlock : Block {

	private block_t disguise;

	private bool silkTouch = false;

	public this(sul.blocks.Block data, block_t disguise) {
		super(data);
		this.disguise = disguise;
	}

	public override Slot[] drops(World world, Player player, Item item) {
		this.silkTouch = item !is null && Enchantments.silkTouch in item;
		if(this.silkTouch) {
			return [Slot(world.items.get(this.disguise), 1)];
		} else {
			return [];
		}
	}

	//TODO mining time

	public override void onRemoved(World world, BlockPosition position, Remove type) {
		if(type == Remove.broken && !this.silkTouch || type == Remove.exploded) {
			//world.spawn!Silverfish(position.entityPosition + .5);
			//TODO spawn silverfish
		}
	}

}

class InactiveEndPortalBlock : Block {

	private block_t active;
	public immutable ubyte direction;

	public this(sul.blocks.Block data, block_t active, ubyte direction) {
		super(data);
		this.active = active;
		this.direction = direction;
	}

	public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
		if(!player.inventory.held.empty && player.inventory.held.item == Items.eyeOfEnder) {
			player.inventory.held = player.inventory.held.count == 1 ? Slot(null) : Slot(player.inventory.held.item, cast(ubyte)(player.inventory.held.count - 1));
			player.world[position] = this.active;
			//TODO check for portal creation (or check when active is placed)
			return true;
		} else {
			return false;
		}
	}

}
