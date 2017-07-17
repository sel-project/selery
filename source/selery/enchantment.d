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
module selery.enchantment;

import std.algorithm : min;
import std.conv : to;
import std.regex : ctRegex, replaceAll;
import std.string : toLower, replace;

import selery.util.util : roman;

static import sul.enchantments;
public import sul.enchantments : Enchantments;

/**
 * Class that represents an enchantment and its level.
 * Example:
 * ---
 * auto e = new Enchantment(Enchantments.sharpness, "V");
 * Enchantment.fromString("luck of the sea", 5);
 * assert(e.pocket && e.pocket.id == 9);
 * assert(e.minecraft.id == 16);
 * assert(!Enchantment.fromMinecraft(71).pocket);
 * ---
 */
final class Enchantment {
	
	private static const(sul.enchantments.Enchantment)[string] strings;
	private static const(sul.enchantments.Enchantment)[ubyte] _minecraft, _pocket;
	
	public static this() {
		foreach(e ; __traits(allMembers, Enchantments)) {
			mixin("alias ench = Enchantments." ~ e ~ ";");
			strings[ench.name.replace(" ", "_")] = ench;
			if(ench.minecraft) _minecraft[ench.minecraft.id] = ench;
			if(ench.pocket) _pocket[ench.pocket.id] = ench;
		}
	}
	
	/**
	 * Creates an enchantment from a string.
	 * Example:
	 * ---
	 * Enchantment.fromString("sharpness", 1);
	 * Enchantment.fromString("Fire Protection", 4);
	 * Enchantment.fromString("silk-touch", 1);
	 * ---
	 */
	public static @safe Enchantment fromString(string name, ubyte level) {
		auto ret = name.toLower.replaceAll(ctRegex!`[ \-]`, "_") in strings;
		return ret ? new Enchantment(*ret, level) : null;
	}
	
	/**
	 * Creates an enchantment using its Minecraft id.
	 * Example:
	 * ---
	 * assert(Enchantment.fromMinecraft(9, 1).name == "frost walker");
	 * ---
	 */
	public static @safe Enchantment fromMinecraft(ubyte id, ubyte level) {
		auto ret = id in _minecraft;
		return ret ? new Enchantment(*ret, level) : null;
	}
	
	/**
	 * Creates an enchantment using its Minecraft: Pocket Edition id.
	 * Example:
	 * ---
	 * assert(Enchantment.fromPocket(9, 2).name == "sharpness");
	 * ---
	 */
	public static @safe Enchantment fromPocket(ubyte id, ubyte level) {
		auto ret = id in _pocket;
		return ret ? new Enchantment(*ret, level) : null;
	}
	
	public const sul.enchantments.Enchantment enchantment;
	public immutable ubyte level;
	
	public @safe this(sul.enchantments.Enchantment enchantment, ubyte level) {
		this.enchantment = enchantment;
		this.level = min(level, ubyte(1));
	}
	
	public @safe this(sul.enchantments.Enchantment enchantment, string level) {
		this(enchantment, level.roman & 255);
	}
	
	/**
	 * Gets the enchantment's id. SEL currently uses Minecraft's
	 * id to uniquely identify an enchantment.
	 * Example:
	 * ---
	 * auto e = Enchantment.fromString("sharpness", 5);
	 * assert(e.id == e.minecraft.id);
	 * ---
	 */
	public pure nothrow @property @safe @nogc ubyte id() {
		return this.enchantment.minecraft.id;
	}
	
	public override bool opEquals(Object o) {
		auto e = cast(Enchantment)o;
		return e !is null && this.id == e.id && this.level == e.level;
	}
	
	alias enchantment this;
	
}

/**
 * Exception thrown when an enchantment does not exist
 * or is used in the wrong way.
 */
class EnchantmentException : Exception {
	
	public @safe this(string message, string file=__FILE__, size_t line=__LINE__) {
		super(message, file, line);
	}
	
}
