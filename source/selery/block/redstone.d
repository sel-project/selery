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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/block/redstone.d, selery/block/redstone.d)
 */
module selery.block.redstone;

import selery.about : block_t;
import selery.block.block;
import selery.block.solid;
import selery.item.item : Item;
import selery.item.items : Items;
import selery.math.vector;
import selery.player.player : Player;

static import sul.blocks;

class SwitchingBlock(bool restoneOnly=false) : MineableBlock {

	private block_t change;

	public this(sul.blocks.Block data, MiningTool miningTool, Drop drop, block_t change) {
		super(data, miningTool, drop);
		this.change = change;
	}

	static if(!restoneOnly) {
		public override bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
			player.world[position] = this.change;
			return true;
		}
	}
	
}
