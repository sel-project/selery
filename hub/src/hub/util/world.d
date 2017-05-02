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
module hub.util.world;

import std.conv : to;
import std.typecons : Tuple;

import com.sel;

mixin("import sul.protocol.hncom" ~ to!string(Software.hncom) ~ ".world : Add;");

enum Gamemode : ubyte {

	survival = Add.SURVIVAL,
	creative = Add.CREATIVE,
	adventure = Add.ADVENTURE,
	spectator = Add.SPECTATOR,

}

enum Difficulty : ubyte {

	peaceful = Add.PEACEFUL,
	easy = Add.EASY,
	normal = Add.NORMAL,
	hard = Add.HARD,
	hardcore = Add.HARDCORE,

}

alias Position(T) = Tuple!(T, "x", T, "y", T, "z");

alias Point = Tuple!(int, "x", int, "z");

class World {

	public immutable uint id;
	public immutable string name;
	public immutable ubyte dimension;
	public immutable ubyte generator;
	public const Point spawnPoint;
	public immutable int seed;

	public ubyte difficulty;
	public ubyte gamemode;
	public ushort time;

	public World parent;

	public shared this(uint id, string name, ubyte dimension, ubyte generator, ubyte difficulty, ubyte gamemode, Point spawnPoint, ushort time, int seed) {
		this.id = id;
		this.name = name;
		this.dimension = dimension;
		this.generator = generator;
		this.difficulty = difficulty;
		this.gamemode = gamemode;
		this.spawnPoint = spawnPoint;
		this.time = time;
		this.seed = seed;
	}

}
