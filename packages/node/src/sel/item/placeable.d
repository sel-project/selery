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
module sel.item.placeable;

import com.sel;

import sel.block.block : compareBlock;
import sel.block.blocks : Blocks;
import sel.item.item;
import sel.math.vector;
import sel.player.player : Player;
import sel.world.world : World;

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
