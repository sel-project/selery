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
module sel.item.enchanting;

import std.conv : to;
import std.string : toUpper, toLower, replace;

import sel.util : roman;

private @property @safe ushort ids(ubyte pe, ubyte pc)() { 
	return ((pe.to!ushort << 8) | pc) & ushort.max; 
}

enum Enchantments : ushort {

	PROTECTION = ids!(0, 0),
	FIRE_PROTECTION = ids!(1, 1),
	FEATHER_FALLING = ids!(2, 2),
	BLAST_PROTECTION = ids!(3, 3),
	PROJECTILE_PROTECTION = ids!(4, 4),
	THORNS = ids!(5, 7),
	RESPIRATION = ids!(6, 5),
	DEPTH_STRIDER = ids!(7, 8),
	AQUA_AFFINITY = ids!(8, 6),
	
	SHARPNESS = ids!(9, 16),
	SMITE = ids!(10, 17),
	BANE_OF_ARTHROPODS = ids!(11, 18),
	KNOCKBACK = ids!(12, 19),
	FIRE_ASPECT = ids!(13, 20),
	LOOTING = ids!(14, 21),
	EFFICENCY = ids!(15, 32),
	SILK_TOUCH = ids!(16, 33),
	UNBREAKING = ids!(17, 34),
	FORTUNE = ids!(18, 35),
	POWER = ids!(19, 48),
	PUNCH = ids!(20, 49),
	FLAME = ids!(21, 50),
	INFINITY = ids!(22, 51),
	LUCK_OF_THE_SEA = ids!(23, 61),
	LURE = ids!(24, 62),

}

public @property @safe ubyte pe(ushort ench) {
	return (ench >> 8) & 255;
}

public @property @safe ubyte pc(ushort ench) {
	return ench & 255;
}

struct Enchantment {

	private static ushort[string] strings;
	private static ushort[ubyte] pes;
	private static ushort[ubyte] pcs;

	public static this() {
		foreach(e ; __traits(allMembers, Enchantments)) {
			ushort ids = to!ushort(__traits(getMember, Enchantments, e));
			this.strings[e.toLower] = ids;
			this.strings[e.toLower.replace("_", "")] = ids;
			this.pcs[ids & 255] = ids;
			this.pes[(ids >> 8) & 255] = ids;
		}
	}

	public static @safe ushort fromString(string ench) {
		ench = ench.toLower;
		return ench in strings ? strings[ench] : 0;
	}

	public static @safe ushort pe(ubyte ench) {
		return ench in pes ? pes[ench] : 0;
	}

	public static @safe ushort pc(ubyte ench) {
		return ench in pcs ? pcs[ench] : 0;
	}

	public immutable ushort id;
	public immutable ubyte level;

	public @safe this(ushort id, ubyte level) {
		this.id = id;
		this.level = level;
	}

	public @safe this(ushort id, string level) {
		this.id = id;
		this.level = level.roman & 255;
	}

}
