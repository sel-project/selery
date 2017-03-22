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
 * Chunk's classes and various utilities.
 * License: <a href="http://www.gnu.org/licenses/lgpl-3.0.html" target="_blank">GNU General Lesser Public License v3</a>
 */
module sel.world.chunk;

import core.memory : GC;
import std.algorithm : sort;
import std.conv : to;
import std.math : abs, ceil, log2;
import std.path : dirSeparator;
import std.string : split, join, endsWith;

import common.path : Paths;
import common.sel;

import sel.block.block : Block;
import sel.block.blocks : Blocks;
import sel.block.tile : Tile;
import sel.math.vector;
import sel.util;
import sel.util.lang : ITranslatable;
import sel.world.io;
import sel.world.world : World;

/**
 * Classic chunk with the size of 16 * 16.
 */
class Chunk {

	// default height
	public static immutable uint HEIGHT = 256;
	
	private ChunkPosition n_position;
	private World n_world;
	public immutable string location;

	private Section[size_t] n_sections;
	private size_t highest_section;

	public ubyte[16 * 16 * 2] lights = 255;
	public ubyte[16 * 16] biomes = 1;

	public bool saveChangedBlocks = false;
	public BlockPosition[] changed_blocks;
	public Tile[uint] changed_tiles;

	private immutable(ubyte)[] m_compressed_pe;
	private immutable(ubyte)[] m_compressed_pc;
	
	public Tile[ushort] tiles;
	public Tile[uint] translatable_tiles;

	// snowing informations
	private Vector2!ubyte[] next_snow;

	public @safe this(World world, ChunkPosition position, string location=null) {
		this.n_world = world;
		if(location is null) {
			this.location = Paths.worlds ~ world.name ~ dirSeparator ~ "chunks" ~ dirSeparator ~ to!string(position.x) ~ "_" ~ to!string(position.z) ~ ".sc";
		} else {
			assert(location.endsWith(dirSeparator ~ to!string(position.x) ~ "_" ~ to!string(position.z) ~ ".sc"));
			this.location = location;	
		}
		this.n_position = position;
	}

	/// Returns the position of the chunk in the world.
	public final pure nothrow @property @safe @nogc const ChunkPosition position() {
		return this.n_position;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc const int x() {
		return this.position.x;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc const int z() {
		return this.position.z;
	}

	/// Gets the chunk's world.
	public final pure nothrow @property @safe @nogc World world() {
		return this.n_world;
	}
	
	/// Gets the world's blocks
	public final pure nothrow @property @safe @nogc Blocks blocks() {
		return this.world.blocks;
	}

	/**
	 * Gets a block in the chunk.
	 * Params:
	 * 		x = x coordinates in range 0..16
	 * 		y = y coordinate in range 0..HEIGHT
	 * 		z = z coordinate in range 0..16
	 */
	public @safe Block** opIndex(BlockPosition position) {
		return this.opIndex(position.x & 15, position.y, position.z & 15);
	}

	/// ditto
	public @safe Block** opIndex(ubyte x, size_t y, ubyte z) {
		immutable sectiony = y >> 4;
		if(auto s = (sectiony in this.n_sections)) {
			return (*s)[x, y & 15, z];
		} else {
			return null;
		}
	}

	/**
	 * Sets a block in the chunk.
	 * Params:
	 * 		block = the block to be set
	 * 		x = x coordinates in range 0..16
	 * 		y = y coordinate in range 0..HEIGHT
	 * 		z = z coordinate in range 0..16
	 */
	public @safe Block** opIndexAssign(Block* block, ubyte x, size_t y, ubyte z) {

		if(block && (*block).id == 0) block = null;

		immutable sy = y >> 4;
		if(sy !in this.n_sections) {
			if(block is null) return null;
			this.createSection(sy);
		}

		BlockPosition position = BlockPosition(x, y, z);
		
		Section section = this.n_sections[sy];
		auto ptr = section[x & 15, y & 15, z & 15] = block;

		if(section.empty) {
			this.removeSection(sy);
		}

		//TODO recalculate highest air block

		if(this.saveChangedBlocks) {
			this.changed_blocks ~= position;
		}

		auto spos = shortBlockPosition(position);
		if(spos in this.tiles) {
			this.translatable_tiles.remove(this.tiles[spos].tid);
			this.tiles[spos].unplace();
			this.tiles.remove(spos);
		}

		return ptr;
	}

	/// ditto
	public @safe Block** opIndexAssign(block_t block, ubyte x, size_t y, ubyte z) {
		return this.opIndexAssign(block in this.blocks, x, y, z);
	}

	/// Registers a tile.
	public @safe void registerTile(T)(T tile) if(is(T : Tile) && is(T : Block)) {
		this.tiles[shortBlockPosition(tile.position & [15, 255, 15])] = tile;
		static if(is(T : ITranslatable)) {
			this.translatable_tiles[tile.tid] = tile;
		} else {
			this.changed_tiles[shortBlockPosition(tile.position)] = tile;
		}
	}

	/// Gets a tile.
	public @safe T tileAt(T)(BlockPosition position) {
		auto s = shortBlockPosition(position) in this.tiles;
		if(s) {
			return cast(T)*s;
		} else {
			return null;
		}
	}

	/**
	 * Gets the y position of the first non-air block
	 * from top.
	 * Returns: the y position of the block or -1
	 * Example:
	 * ---
	 * if(chunk.firstBlock(12, 9) == -1) {
	 *    d("The column is air-only");
	 * }
	 * ---
	 */
	public @safe ptrdiff_t firstBlock(ubyte x, ubyte z) {
		foreach_reverse(size_t y ; 0..(this.highest_section*16)+16) {
			if(this[x, y, z] !is null) return y;
		}
		return -1;
	}

	/**
	 * Checks whether or not a section is empty
	 * (has no blocks in it).
	 */
	public @safe bool emptySection(size_t y) {
		auto ptr = y in this.n_sections;
		return ptr is null || (*ptr).empty;
	}

	/**
	 * Checks if a section contains blocks with the random tick.
	 */
	public @safe bool tickSection(size_t y) {
		return y in this.n_sections ? this.n_sections[y].tick : false;
	}

	/**
	 * Gets a section.
	 */
	public @safe Section sectionAt(size_t y) {
		return this.n_sections[y];
	}

	/// ditto
	public @safe Section opIndex(size_t y) {
		return this.sectionAt(y);
	}

	public Section* opBinaryRight(string op)(size_t y) if(op == "in") {
		return y in this.n_sections;
	}

	public @safe void createSection(size_t y) {
		this.n_sections[y] = new Section();
		if(y > this.highest_section) {
			this.highest_section = y;
		}
	}

	public @trusted void removeSection(size_t y) {
		this.n_sections.remove(y);
		if(y == this.highest_section) {
			size_t[] keys = this.n_sections.keys;
			if(keys.length) {
				sort(keys);
				this.highest_section = keys[$-1];
			} else {
				this.highest_section = 0;
			}
		}
	}

	/**
	 * Gets the sections.
	 */
	public final pure nothrow @property @safe @nogc Section[size_t] sections() {
		return this.n_sections;
	}

	/**
	 * Checks whether or not the chunks is air.
	 */
	public final pure nothrow @property @safe @nogc bool empty() {
		return this.n_sections.length == 0;
	}

	/**
	 * Gets or generate the position for the next block
	 * where the snow should fall.
	 */
	public @property @safe Vector2!ubyte nextSnow() {
		if(this.next_snow.length == 0) {
			Vector2!ubyte[] positions;
			foreach(ubyte x ; 0..16) {
				foreach(ubyte z ; 0..16) {
					positions ~= Vector2!ubyte(x, z);
				}
			}
			this.world.random.shuffle(positions);
			this.next_snow = positions;
		}
		auto ret = this.next_snow[$-1];
		this.next_snow.length = this.next_snow.length - 1;
		return ret;
	}

	/// Resets the snow
	public @safe void resetSnow() {
		this.next_snow.length = 0;
	}

	public void save() {
		
		DefaultSel.writeChunk(this, this.location);
		
	}

	/// Unloads a chunks and frees its memory
	public void unload() {
		this.save();
		//this.sections.call!"unload"();
		foreach(Tile tile ; this.tiles) {
			tile.unplace();
		}
	}

}

class UnsaveableChunk : Chunk {

	public @safe this(World world, ChunkPosition position, string location=null) {
		super(world, position, location);
	}

	public override @safe @nogc void save() {}

}

class Section {

	public enum order = "yxz".dup;

	private Block*[4096] n_blocks;
	private ubyte[2048] n_sky_light = 255;
	private ubyte[2048] n_blocks_light = 0;

	private size_t n_amount = 0;
	private size_t n_random_ticked = 0;

	public pure nothrow @property @safe @nogc ref auto blocks() {
		return this.n_blocks;
	}
	
	public @property auto blocks(Block*[4096] blocks) {
		this.n_blocks = blocks;
		foreach(ref Block* block ; this.n_blocks) {
			if(block) {
				if((*block).id == 0) {
					block = null;
				} else {
					this.n_amount++;
					if((*block).doRandomTick) this.n_random_ticked++;
				}
			}
		}
		return this.n_blocks;
	}

	public pure nothrow @property @safe @nogc auto skyLight() {
		return this.n_sky_light;
	}
	
	public pure nothrow @property @safe auto skyLight(ubyte[2048] skyLight) {
		return this.n_sky_light = skyLight.dup;
	}

	public pure nothrow @property @safe @nogc auto blocksLight() {
		return this.n_blocks_light;
	}
	
	public pure nothrow @property @safe auto blocksLight(ubyte[2048] blocksLight) {
		return this.n_blocks_light = blocksLight.dup;
	}

	public pure nothrow @property @safe @nogc bool empty() {
		return this.n_amount == 0;
	}

	public pure nothrow @property @safe @nogc bool full() {
		return this.n_amount == 4096;
	}

	public pure nothrow @property @safe @nogc bool tick() {
		return this.n_random_ticked > 0;
	}

	public @trusted Block** opIndex(ubyte x, ubyte y, ubyte z) {
		return &this.n_blocks[y << 8 | x << 4 | z];
	}

	public @safe Block** opIndexAssign(Block* block, ubyte x, ubyte y, ubyte z) {
		Block** ptr = this[x, y, z];

		if(block && (*block).id == 0) block = null;
		Block* old = *ptr;

		bool old_air = old is null;
		bool new_air = block is null;

		// update the number of blocks
		if(old_air ^ new_air) {
			if(old_air) this.n_amount++;
			else this.n_amount--;
		}

		bool old_rt = !old_air && (*old).doRandomTick;
		bool new_rt = !new_air && (*block).doRandomTick;

		// update the number of random-ticked blocks
		if(old_rt ^ new_rt) {
			if(old_rt) this.n_random_ticked--;
			else this.n_random_ticked++;
		}

		/*
		if(old is null && block !is null) {
			this.n_amount++;
		} else if(old !is null && block is null) {
			this.n_amount--;
		}
		
		if((old is null || !(*old).doRandomTick) && (block !is null && (*block).doRandomTick)) {
			this.n_random_ticked++;
		} else if((old !is null && (*old).doRandomTick) && (block is null || !(*block).doRandomTick)) {
			this.n_random_ticked--;
		}
		*/

		*ptr = block;

		return ptr;
	}

}
