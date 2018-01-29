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
module selery.item.placeable;

import selery.about : block_t, item_t;
import selery.block.block : compareBlock;
import selery.block.blocks : Blocks;
import selery.item.item;
import selery.math.vector;
import selery.player.player : Player;
import selery.world.world : World;

static import sul.items;

class GenericPlaceableItem : Item {

	//TODO ctor

	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}

	public override block_t place(World world, BlockPosition position, uint face) {
		return this.block;
	}

	public abstract pure nothrow @property @safe @nogc block_t block();

}

class PlaceableOnBlockItem : GenericPlaceableItem {

	//TODO ctor

	public override block_t place(World world, BlockPosition position, uint face) {
		if(world[position - [0, 1, 0]] == this.supportBlocks) {
			return super.place(world, position, face);
		} else {
			return 0;
		}
	}

	public abstract pure nothrow @property @safe block_t[] supportBlocks();

}

template PlaceableItem(sul.items.Item _data, block_t _block, E...) {

	static if(E.length == 0) {

		class PlaceableItem : GenericPlaceableItem {

			public override pure nothrow @property @safe @nogc const sul.items.Item data() {
				return _data;
			}

			public override pure nothrow @property @safe @nogc block_t block() {
				return _block;
			}

			alias slot this;

		}

	} else static if(is(typeof(E[0]) == block_t[])) {
		
		class PlaceableItem : PlaceableOnBlockItem {
			
			public override pure nothrow @property @safe @nogc const sul.items.Item data() {
				return _data;
			}
			
			public override pure nothrow @property @safe @nogc block_t block() {
				return _block;
			}
			
			public override pure nothrow @property @safe block_t[] supportBlocks() {
				return E[0];
			}
			
			alias slot this;
			
		}

	} else {

		class PlaceableItem : GenericPlaceableItem {

			public override pure nothrow @property @safe @nogc const sul.items.Item data() {
				return _data;
			}

			public override block_t place(World world, BlockPosition position, uint face) {
				auto down = world[position - [0, 1, 0]];
				if(mixin((){
					import std.string : join;
					string[] ret;
					foreach(cmp ; E) {
						ret ~= "down." ~ cmp;
					}
					return ret.join("&&");
				}())) {
					return super.place(world, position, face);
				} else {
					return 0;
				}

			}
			
			public override pure nothrow @property @safe @nogc block_t block() {
				return _block;
			}

		}

	}

}

alias PlaceableOnSolidItem(sul.items.Item _data, block_t _block) = PlaceableItem!(_data, _block, "fullUpperShape", "solid", "opacity==15");

class WoodItem(sul.items.Item si, block_t[] blocks) : SimpleItem!(si) if(blocks.length == 4) {

	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		switch(face) {
			case Face.EAST:
			case Face.WEST:
				return blocks[1];
			case Face.NORTH:
			case Face.SOUTH:
				return blocks[2];
			default:
				return blocks[0];
		}
	}
	
	alias slot this;

}

class TorchItem(sul.items.Item si, block_t[] blocks) : SimpleItem!(si) if(blocks.length == 5) {

	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		//TODO place if valid surface
		return blocks[0];
	}
	
	alias slot this;

}

class BeansItem(sul.items.Item si, block_t[] blocks) : SimpleItem!(si) if(blocks.length == 4) {

	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		//TODO place if valid surface
		return blocks[0];
	}
	
	alias slot this;

}

class SlabItem(sul.items.Item si, block_t down, block_t up, block_t doubl) : SimpleItem!(si) {
	
	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		//TODO override onPlaced
		return down;
	}
	
	alias slot this;
	
}

class StairsItem(sul.items.Item si, block_t[] orientations) : SimpleItem!(si) if(orientations.length == 8) {

	// [east, west, south, north, upper east, upper west, upper south, upper north]

	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		//TODO override onPlaced
		return orientations[0];
	}
	
	alias slot this;
	
}
