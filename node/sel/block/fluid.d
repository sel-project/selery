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
/**
 * Fluid blocks and utilities.
 * License: <a href="http://www.gnu.org/licenses/lgpl-3.0.html" target="_blank">GNU General Lesser Public License v3</a>
 */
module sel.block.fluid;

import common.sel;

import sel.block.block;
import sel.math.vector : BlockPosition;

static import sul.blocks;

/**
 * Class for fluids.
 * Params:
 * 		curr_level = current level of the fluid, in range 0..max_level
 * 		max_level = lowest level of the fluid
 * 		per_level = number of levels to add to curr_level when fluid expands
 * 		time = number of ticks used by the fluid to expand
 */
class FluidBlock(sul.blocks.Block sb, block_t next, ubyte per_level=0, uint time=0) : SimpleBlock!(sb) {

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

}
