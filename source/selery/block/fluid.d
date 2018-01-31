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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/block/fluid.d, selery/block/fluid.d)
 */
module selery.block.fluid;

import selery.about : block_t, item_t;
import selery.block.block;
import selery.math.vector : BlockPosition;

static import sul.blocks;

//TODO
class FluidBlock : Block {

	public this(sul.blocks.Block data) {
		super(data);
	}

	public final override pure nothrow @property @safe @nogc bool fluid() {
		return true;
	}

	/*public override void onUpdate(Update update) {
		static if(curr_level <= max_level) {
			this.scheduleUpdate();
		}
	}

	public override void onScheduledUpdate() {
		this.has_scheduled = false;
		static if(curr_level > 0) {
			//check if the source has been removed
			if((*this.source) is null || ((*this.source) != name && (*this.source).metas.pe != curr_level - per_level)) {
				this = Blocks.AIR;
				return;
			}
		}
		//check bottom
		bool flowed;
		if(this.canFlow(this.down)) {
			//prevent replacing a source
			if(this.down !is null && this.down.name == name && this.down.metas.pe == 0) return;
			static if(curr_level != 0) {
				flowed = true;
			}
			if(this.down !is null) this.world.drops(this.down);
			this.world[this.position.substract(0, 1, 0)] = new FluidBlock!(name, ids, per_level, max_level, per_level, time)(this.world.pointer(this.position));
		}
		static if(curr_level + per_level <= max_level) {
			if(!flowed) {
				foreach(int[2] c ; this.bestWays) {
					BlockPosition position = this.position.add(c[0], 0, c[1]);
					Block b = this.world[position];
					if(this.canFlow!true(b)) {
						if(b !is null) this.world.drops(b);
						this.world[position] = new FluidBlock!(name, ids, curr_level + per_level, max_level, per_level, time)(this.world.pointer(this.position));
					}
				}
			}
		}
	}

	private bool canFlow(bool checkname=false)(Block block) {
		static if(checkname) {
			return block is null || (block.replaceable || block.directBlastResistance == 0) && (block.name != name || block.metas.pe > curr_level + per_level);
		} else {
			return block is null || block.replaceable || block.directBlastResistance == 0;
		}
	}

	private @property int[][] bestWays() {
		int[][] ret;
		foreach(int[] pos ; [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
			Block b = this.world[this.position.add(pos[0], 0, pos[1])];
			if(b is null || b.directBlastResistance == 0) {
				b = this.world[this.position.add(pos[0], -1, pos[1])];
				if(b is null || b.directBlastResistance == 0) {
					ret ~= pos;
				}
			}
		}
		return ret.length == 0 ? [[-1, 0], [1, 0], [0, -1], [0, 1]] : ret;
	}

	private void scheduleUpdate() {
		if(!this.has_scheduled) {
			this.has_scheduled = true;
			this.world.scheduleBlockUpdate(this, time);
		}
	}*/

	public override pure nothrow @property @safe @nogc float fallDamageModifier() {
		return 0;
	}

}
