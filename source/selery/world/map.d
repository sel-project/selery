/*
 * Copyright (c) 2017 SEL
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
module selery.world.map;

import std.conv : to;
import std.math : log2, floor, abs;
import std.traits : EnumMembers;

import selery.math.vector : ChunkPosition;
import selery.util.color;
import selery.world.world : World;

class Map {

	public static immutable ubyte ONE_BLOCK_PER_PIXEL = 0;
	public static immutable ubyte TWO_BLOCKS_PER_PIXEL = 1;
	public static immutable ubyte FOUR_BLOCKS_PER_PIXEL = 2;
	public static immutable ubyte EIGHT_BLOCKS_PER_PIXEL = 3;
	public static immutable ubyte SIXTEEN_BLOCKS_PER_PIXEL = 4;

	private World world;

	public immutable ushort id;

	private ubyte n_scale;
	private MapColor[] m_data;

	public @safe this(World world, ushort id, ubyte scale=0, MapColor[] data=null) {
		this.world = world;
		this.id = id;
		this.scale = scale;
		if(data !is null) this.data = data;
	}

	public @property @safe @nogc ubyte scale() {
		return this.n_scale;
	}

	public @property @safe ubyte scale(ubyte scale) {
		assert(scale <= 4, "Invalid scale given");
		return this.n_scale = scale;
	}

	public @property @safe @nogc MapColor[] data() {
		return this.m_data;
	}

	public @property @safe MapColor[] data(MapColor[] data) {
		assert(data.length == 128 * 128, "wrong buffer length");
		this.m_data = data;
		//this.world.compress(this);
		return this.m_data;
	}

	public @safe MapColor opIndexAssign(uint x, uint z) {
		return this.m_data[x + z * 128];
	}

	public @safe void opIndexAssign(MapColor color, uint x, uint z) {
		this.m_data[x + z * 128] = color;
	}

	/*protected @property @safe ubyte[] pedata() {
		ubyte[] buffer;
		buffer.reserve(128 * 128 * 4);
		foreach(ref MapColor color ; this.m_data) {
			buffer ~= color.r;
			buffer ~= color.g;
			buffer ~= color.b;
			buffer ~= 255;
		}
		return buffer;
	}

	protected @property @safe ubyte[] pcdata() {
		ubyte[] buffer;
		buffer.reserve(128 * 128);
		foreach(ref MapColor color ; this.m_data) {
			buffer ~= color.id;
		}
		return buffer;
	}*/

	public enum Colors : MapColors {

		TRANSPARENT = MapColors(0, 0, 0, 0),
		GRASS = MapColors(1, 127, 178, 56),
		SAND = MapColors(2, 244, 230, 161),
		BED = MapColors(3, 199, 199, 199),
		LAVA = MapColors(4, 252, 0, 0),
		ICE = MapColors(5, 158, 158, 252),
		IRON = MapColors(6, 165, 165, 165),
		LEAVES = MapColors(7, 0, 123, 0),
		SNOW = MapColors(8, 252, 252, 252),
		CLAY = MapColors(9, 162, 166, 182),
		DIRT = MapColors(10, 149, 108, 76),
		STONE = MapColors(11, 111, 111, 111),
		WATER = MapColors(12, 63, 63, 252),
		WOOD = MapColors(13, 141, 118, 71),
		QUARTZ = MapColors(14, 252, 249, 242),
		ORANGE = MapColors(15, 213, 125, 50),
		MAGENTA = MapColors(16, 176, 75, 213),
		LIGHT_BLUE = MapColors(17, 101, 151, 213),
		YELLOW = MapColors(18, 226, 226, 50),
		LIME = MapColors(19, 125, 202, 25),
		PINK = MapColors(20, 239, 125, 163),
		GRAY = MapColors(21, 75, 75, 75),
		LIGHT_GRAY = MapColors(22, 151, 151, 151),
		CYAN = MapColors(23, 75, 125, 151),
		PURPLE = MapColors(24, 125, 62, 176),
		BLUE = MapColors(25, 50, 75, 176),
		BROWN = MapColors(26, 101, 75, 50),
		GREEN = MapColors(27, 101, 125, 50),
		RED = MapColors(28, 151, 50, 50),
		BLACK = MapColors(29, 25, 25, 25),
		GOLD = MapColors(30, 247, 235, 76),
		DIAMOND = MapColors(31, 91, 216, 210),
		LAPIS_LAZULI = MapColors(32, 73, 129, 252),
		EMERALD = MapColors(33, 0, 214, 57),
		PODZOL = MapColors(34, 127, 85, 48),
		NETHERRACK = MapColors(35, 111, 2, 0),

	}

	public static @safe MapColor closestColor(Color color) {
		if(color.a != 255) return Colors.TRANSPARENT.light;
		uint difference = uint.max;
		MapColor ret;
		foreach(MapColors mc ; [EnumMembers!Colors]) {
			if(mc[0].id == 0) continue;
			foreach(MapColor c ; mc) {
				uint d = 0;
				d += abs(to!int(c.r) - color.r);
				d += abs(to!int(c.g) - color.g);
				d += abs(to!int(c.b) - color.b);
				if(d < difference) {
					difference = d;
					ret = c;
				}
			}
		}
		return ret;
	}

}

class CustomMap : Map {

	private ubyte[] image_data;

	public @safe this(World world, ushort id, ubyte scale, ubyte[] image_data) {
		assert(image_data.length == 128 * 128 * 4, "Invalid image data length");
		super(world, id, scale);
		this.image_data = image_data;
		MapColor[] m;
		m.reserve(128 * 128);
		foreach(uint i ; 0..128*128) {
			uint j = i * 4;
			m ~= Map.closestColor(new Color(image_data[j++], image_data[j++], image_data[j++], image_data[j]));
		}
		this.data = m;
	}

	/*protected override @property @safe ubyte[] pedata() {
		return this.image_data;
	}*/

}

struct MapColors {

	public MapColor[4] colors;

	public @safe this(ubyte id, uint r, uint g, uint b) {
		id *= 4;
		this.colors[0] = new MapColor(id++, m(r, 180), m(g, 180), m(b, 180));
		this.colors[1] = new MapColor(id++, m(r, 220), m(g, 220), m(b, 220));
		this.colors[2] = new MapColor(id++, r & 255, g & 255, b & 255);
		this.colors[3] = new MapColor(id++, m(r, 135), m(g, 135), m(b, 135));
	}

	private @safe ubyte m(uint num, uint amount) {
		return (num * amount / 255) & 255;
	}

	public @property @safe MapColor light() {
		return this.colors[2];
	}

	public @property @safe MapColor normal() {
		return this.colors[1];
	}

	public @property @safe MapColor dark() {
		return this.colors[0];
	}

	public @property @safe MapColor veryDark() {
		return this.colors[3];
	}

	alias colors this;

}

class MapColor : Color {

	public immutable ubyte id;

	public @safe @nogc this(ubyte id, ubyte r, ubyte g, ubyte b) {
		super(r, g, b);
		this.id = id;
	}

}
