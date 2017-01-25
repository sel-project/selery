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
module sel.block.miscellaneous;

import sel.block.block : BlockData, Block, Blocks, SimpleBlock;
import sel.block.flags;
import sel.math.vector;
import sel.world.world : World;

class FireBlock(BlockData blockdata) : SimpleBlock!(blockdata, RANDOM_TICK, REPLACEABLE) {

	public override void onRandomTick(World world, BlockPosition position) {

		// check for rain
		if(world.downfall && this.seesSky(world, position)) {
			world[position] = Blocks.AIR;
			return;
		}

		Block burning;
		BlockPosition p;
		foreach(BlockPosition pos ; [position - [0, 1, 0], position + [1, 0, 0], position + [0, 0, 1], position - [1, 0, 0], position + [0, 0, 1]]) {
			burning = world[p = pos];
			if(burning.flammable) break;
		}

		if(burning is null) {
			// extinguish
			world[position] = Blocks.AIR;
		} else {
			if(world.random.probability(.75)) {
				// try to spread
				foreach(BlockPosition pos ; [p - [0, 1, 0], p + [1, 0, 0], p + [0, 0, 1], p - [1, 0, 0], p + [0, 0, 1]]) {
					Block b = world[pos];
					if(b == Blocks.AIR) {
						world[p] = blockdata;
						return;
					}
				}
			}
			// burn out
			world[p] = Blocks.AIR;
			world[position] = Blocks.AIR;
		}

	}

}
