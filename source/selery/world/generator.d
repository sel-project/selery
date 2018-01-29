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
module selery.world.generator;

import std.algorithm : min;
import std.conv : to;

import selery.block.block : Block;
import selery.block.blocks : Blocks;
import selery.math.vector : ChunkPosition, BlockPosition, distance;
import selery.util.random : Random;
import selery.world.chunk : Chunk;
import selery.world.world : World;

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
				foreach(uint y ; 0..this.layers.length.to!uint) {
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
			foreach(y ; this.layers.length..this.layers.length+height) {
				chunk[7, cast(uint)y, 7] = Blocks.woodUpDown[tree];
			}
			//leaves
			BlockPosition center = BlockPosition(7, this.layers.length.to!int + height, 7);
			foreach(ubyte xx ; to!ubyte(7 - foliage)..to!ubyte(7 + foliage + 1)) {
				foreach(ubyte zz ; to!ubyte(7 - foliage)..to!ubyte(7 + foliage + 1)) {
					foreach(uint yy ; (center.y - foliage)..(center.y + foliage + 1)) {
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
