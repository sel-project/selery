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

import common.sel;

import sel.block.block : Blocks, compareBlock;
import sel.item.item;
import sel.math.vector;
import sel.player.player : Player;
import sel.world.world : World;

static import sul.items;

class PlaceableItem(sul.items.Item si, block_t block, E...) : SimpleItem!(si) {
	
	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		static if(E.length) {
			auto u = world[position - [0, 1, 0]];
			static if(is(typeof(E[0]) == block_t[])) {
				if(compareBlock!(E[0])(u)) return block;
				else return Blocks.air;
			} else {
				foreach(prop ; E) {
					if(mixin("!(u." ~ prop ~ ")")) return Blocks.air;
				}
				return block;
			}
		} else {
			return block;
		}
	}
	
	alias slot this;
	
}

alias PlaceableOnSolidItem(sul.items.Item si, block_t block) = PlaceableItem!(si, block, "fullUpperShape", "solid", "opacity==15");

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
