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
module sel.block.redstone;

import common.sel;

import sel.block.block;
import sel.block.solid;
import sel.item.item : Item;
import sel.item.items : Items;
import sel.math.vector;
import sel.player.player : Player;

static import sul.blocks;

class SwitchingBlock(sul.blocks.Block sb, MiningTool miningTool, Drop drop, block_t change, bool restoneOnly=false) : MineableBlock!(sb, miningTool, drop) {
	
	mixin Instance;
	
	static if(!restoneOnly) {
		public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
			player.world[position] = change;
			return true;
		}
	}
	
}
