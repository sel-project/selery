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
module sel.world.generator;

import std.algorithm : min;
import std.conv : to;

import sel.block.block : Block, Blocks;
import sel.math.vector : ChunkPosition, BlockPosition, distance;
import sel.util.random : Random;
import sel.world.chunk : Chunk;
import sel.world.world : World;

abstract class Generator {

	protected World world;
	private uint m_seed;

	public @safe @nogc this(World world) {
		this.world = world;
	}

	public abstract @property @safe BlockPosition spawn();

	public abstract Chunk generate(ChunkPosition position);

	public pure nothrow @property @safe @nogc uint seed() {
		return this.m_seed;
	}

	public pure nothrow @property @safe @nogc uint seed(uint seed) {
		return this.m_seed = seed;
	}

	public abstract pure nothrow @property @safe string type();

}

class Empty : Generator {

	public @safe @nogc this(World world) {
		super(world);
	}

	public override @property @safe BlockPosition spawn() {
		return BlockPosition(0, 0, 0);
	}

	public override @safe Chunk generate(ChunkPosition position) {
		return new Chunk(this.world, position);
	}

	public override pure nothrow @property @safe string type() {
		return "flat";
	}

}

class Flat : Generator {

	private ushort[] layers;
	protected bool trees;

	public @safe this(World world, ushort[] layers=[Blocks.bedrock, Blocks.dirt, Blocks.dirt, Blocks.dirt, Blocks.grass], bool trees=true) {
		super(world);
		this.layers = layers;
		this.trees = trees;
	}

	public override @property @safe BlockPosition spawn() {
		return BlockPosition(0, this.layers.length.to!int, 0);
	}

	public override Chunk generate(ChunkPosition position) {
		Chunk chunk = new Chunk(this.world, position);
		foreach(ubyte xx ; 0..16) {
			foreach(ubyte zz ; 0..16) {
				foreach(size_t y ; 0..this.layers.length) {
					chunk[xx, y, zz] = this.layers[y];
				}
			}
		}
		if(this.trees && this.world.random.probability(.75)) {
			//test a tree
			ubyte tree = this.world.random.next!ubyte(6);
			ubyte height = this.world.random.range!ubyte(4, 24);
			ubyte foliage = this.world.random.range!ubyte(3, min(height, cast(ubyte)7));
			//logs
			foreach(size_t y ; this.layers.length..this.layers.length+height) {
				chunk[7, y, 7] = Blocks.woodUpDown[tree];
			}
			//leaves
			BlockPosition center = BlockPosition(7, this.layers.length.to!int + height, 7);
			foreach(ubyte xx ; to!ubyte(7 - foliage)..to!ubyte(7 + foliage + 1)) {
				foreach(ubyte zz ; to!ubyte(7 - foliage)..to!ubyte(7 + foliage + 1)) {
					foreach(size_t yy ; (center.y - foliage)..(center.y + foliage + 1)) {
						BlockPosition pos = BlockPosition(xx, yy, zz);
						if(pos.distance(center) <= foliage) {
							auto current = chunk[xx, yy, zz];
							if(current is null || *current is null) {
								chunk[xx, yy, zz] = Blocks.leavesDecay[tree];
							}
						}
					}
				}
			}
		}
		return chunk;
	}

	public override pure nothrow @property @safe string type() {
		return "flat";
	}

}
