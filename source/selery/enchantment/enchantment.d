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
/**
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/enchantment/enchantment.d, selery/enchantment/enchantment.d)
 */
module selery.enchantment.enchantment;

import std.algorithm : min;
import std.conv : to;
import std.regex : ctRegex, replaceAll;
import std.string : toLower, replace, startsWith;

import roman : fromRoman;

static import sel.data.enchantment;
import sel.data.enchantment : Enchantments;

/**
 * Class that represents an enchantment and its level.
 * Example:
 * ---
 * auto e = new Enchantment(Enchantments.sharpness, "V");
 * Enchantment.fromString("luck of the sea", 5);
 * assert(e.bedrock && e.bedrock.id == 9);
 * assert(e.minecraft.id == 16);
 * assert(!Enchantment.fromMinecraft(71).pocket);
 * ---
 */
final class Enchantment {
	
	private static const(sel.data.enchantment.Enchantment)[string] strings;
	private static const(sel.data.enchantment.Enchantment)[ubyte] _java, _bedrock;
	
	public static this() {
		foreach(e ; __traits(allMembers, Enchantments)) {
			mixin("alias ench = Enchantments." ~ e ~ ";");
			strings[ench.name.replace(" ", "_")] = ench;
			if(ench.java) _java[ench.java.id] = ench;
			if(ench.bedrock) _bedrock[ench.bedrock.id] = ench;
		}
	}
	
	/**
	 * Creates an enchantment from a string.
	 * Example:
	 * ---
	 * Enchantment.fromString("sharpness", 1);
	 * Enchantment.fromString("Fire Protection", 4);
	 * Enchantment.fromString("silk-touch", 1);
	 * Enchantment.fromString("minecraft:protection", 2);
	 * ---
	 */
	public static @safe Enchantment fromString(string name, ubyte level) {
		if(name.startsWith("minecraft:")) name = name[10..$];
		auto ret = name.toLower.replaceAll(ctRegex!`[ \-]`, "_") in strings;
		return ret ? new Enchantment(*ret, level) : null;
	}
	
	/**
	 * Creates an enchantment using its Minecraft: Java Edition's id.
	 * Example:
	 * ---
	 * assert(Enchantment.fromJava(9, 1).name == "frost walker");
	 * ---
	 */
	public static @safe Enchantment fromJava(ubyte id, ubyte level) {
		auto ret = id in _java;
		return ret ? new Enchantment(*ret, level) : null;
	}
	
	/**
	 * Creates an enchantment using its Minecraft's id.
	 * Example:
	 * ---
	 * assert(Enchantment.fromBedrock(9, 2).name == "sharpness");
	 * ---
	 */
	public static @safe Enchantment fromBedrock(ubyte id, ubyte level) {
		auto ret = id in _bedrock;
		return ret ? new Enchantment(*ret, level) : null;
	}
	
	public const sel.data.enchantment.Enchantment enchantment;
	public immutable ubyte level;
	
	public pure nothrow @safe @nogc this(sel.data.enchantment.Enchantment enchantment, ubyte level) {
		this.enchantment = enchantment;
		this.level = level == 0 ? ubyte(1) : level;
	}
	
	public @safe this(sel.data.enchantment.Enchantment enchantment, string level) {
		this(enchantment, level.fromRoman & 255);
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
		return this.enchantment.java.id;
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
