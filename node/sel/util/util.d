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
 * Miscellaneous of various useful function to be
 * used by SEL and the plugins.
 */
module sel.util.util;

import std.algorithm : canFind;
import std.array : split;
import std.conv : to, ConvException;
import std.string : toUpper;
import std.traits : isArray, isAssociativeArray, isSafe;

/**
 * Check if all elements of values are in array.
 * Params:
 * 		values = the values that should be in the array
 * 		array = the array where the values should be into
 * Returns: true if all the values are in the array, false otherwise
 * Example:
 * ---
 * string pattern = "abcdefghijklmnopqrstuvwxyz";
 * assert(array_in_array("ciao", pattern));
 * assert(!array_in_array("Ciao!", pattern));
 * ---
 */
public deprecated @property @trusted bool array_in_array(T, E)(T[] values, E[] array) /*if(__traits(compiles, T.init == E.init))*/ {
	foreach(T value ; values) {
		if(!array.canFind(value)) return false;
	}
	return true;
}

unittest {

	auto pattern = "abcdefghijklmonpqrstuvwxyz";
	assert(array_in_array("ciao", pattern));
	assert(!array_in_array("ciao!", pattern));

}

/**
 * Remove an element from an array.
 * Params:
 * 		value = the value to be removed from the array
 * 		array = the array where the value should be removed from
 * Returns: true if something has been removed, false otherwise
 * Example:
 * ---
 * auto arr = [0, 1, 2, 3];
 * assert(array_remove(2, [0, 1, 2, 3]) && arr = [0, 1, 3]);
 * 
 * string s = "test";
 * assert(s.remove('t') && s == "es");
 * ---
 */
public @property @trusted bool array_remove(T, E)(T value, ref E[] array) /*if(__traits(compiles, T.init == E.init))*/ {
	foreach(uint i, E val; array) {
		if(val == value) {
			array = array[0..i] ~ array[i+1..$];
			return true;
		}
	}
	return false;
}

/// ditto
alias remove = array_remove;

unittest {

	auto array = [1, 2, 3, 4, 5];
	assert(array_remove(3, array));
	assert(array == [1, 2, 4, 5]);

}

/**
 * Find a value in a array.
 * Params:
 * 		value = the value to be searched in the array
 * 		array = the array to search into
 * Returns: the index where the value has been found, -1 otherwise
 * Example:
 * ---
 * assert(array_index(1, [1, 2, 3] == 0));
 * assert(array_index(0, [1, 2, 3] == -1));
 * assert("test".indexOf('e') == 1);
 * ---
 */
public @property @trusted ptrdiff_t array_index(T, E)(T value, E[] array) /*if(__traits(compiles, T.init == E.init))*/ {
	foreach(uint i, E avalue; array) {
		if(value == avalue) return i;
	}
	return -1;
}

/// ditto
public deprecated @property ptrdiff_t indexOf(E, T)(E[] array, T value) {
	return array_index(value, array);
}

unittest {

	assert(array_index(8, [0, 8, 8]) == 1);
	assert(array_index(7, [0, 8, 8]) == -1);
	assert([8, 9, 10].indexOf(10) == 2);

}

/**
 * Removes duplicates from an array.
 * Example:
 * ---
 * assert(uniq([1, 1, 2, 3, 3, 4]) == [1, 2, 3, 4]);
 * ---
 */
public deprecated @property @safe T[] uniq(T)(T[] array) {
	T[] ret;
	foreach(T value ; array) {
		if(!ret.canFind(value)) ret ~= value;
	}
	return ret;
}

unittest {

	assert(uniq([1, 2, 3, 3]) == [1, 2, 3]);

}

/** Transform an object/value in a string by appending an empty string to it */
public deprecated @property @safe string str(T)(T value) {
	return value ~ "";
}

/** 
 * Convert from roman to an integer.
 * Example:
 * ---
 * assert("I".roman == 1);
 * assert("V".roman == 5);
 * assert("XX".roman == 20);
 * assert("XL".roman == 40);
 * assert("MCMXCVI".roman == 1996);
 * assert("MMXCI".roman == 2016);
 * ---
 */
public @property @safe uint roman(string str) {
	return str.toUpper.proman;
}

/// ditto
private @property @safe uint proman(string str) {
	if(str == "") return 0;
	if(str[0..1] == "M") return 1000 + str[1..$].proman;
	if(str.length > 1 && str[0..2] == "CM") return 900 + str[2..$].proman;
	if(str[0..1] == "D") return 500 + str[1..$].proman;
	if(str.length > 1 && str[0..2] == "CD") return 400 + str[2..$].proman;
	if(str[0..1] == "C") return 100 + str[1..$].proman;
	if(str.length > 1 && str[0..2] == "XC") return 90 + str[2..$].proman;
	if(str[0..1] == "L") return 50 + str[1..$].proman;
	if(str.length > 1 && str[0..2] == "XL") return 40 + str[2..$].proman;
	if(str[0..1] == "X") return 10 + str[1..$].proman;
	if(str.length > 1 && str[0..2] == "IX") return 9 + str[2..$].proman;
	if(str[0..1] == "V") return 5 + str[1..$].proman;
	if(str.length > 1 && str[0..2] == "IV") return 4 + str[2..$].proman;
	if(str[0..1] == "I") return 1 + str[1..$].proman;
	return 0;
}

unittest {

	assert("I".roman == 1);
	assert("V".roman == 5);
	assert("L".roman == 50);
	assert("CCIV".roman == 204);

}

/** Check if a value is between 0 and 1 */
public @property @safe @nogc bool one(double value) {
	return value >= 0f && value <= 1f;
}

/** 
 * Set the value between two numbers.
 * Example:
 * ---
 * assert(between(22, 0, 10) == 2);
 * assert(between(-1, 0, 10) == 9);
 * ---
 */
public deprecated @safe @nogc T between(T)(T number, T min, T max) {
	if(max <= min) return number;
	while(number < min) number += max;
	while(number > max) number -= max;
	return number;
}

/** 
 * Call a function on every element in the array.
 * Example:
 * ---
 * Effect effect = new Effect(Effects.REGENERATION, 60, "V");
 * 
 * // classic method
 * foreach(ref Player player ; players) {
 *    player.addEffect(effect);
 * }
 * 
 * // faster and easier method
 * players.call!"addEffect"(effect);
 * ---
 */
public void call(string func, T, E...)(T array, E args) if((isArray!T || isAssociativeArray!T) && !isSafe!(__traits(getMember, typeof(T.init[0]), func))) {
	foreach(ref element ; array) {
		mixin("element." ~ func ~ "(args);");
	}
}

/// ditto
public @safe void call(string func, T, E...)(T array, E args) if((isArray!T || isAssociativeArray!T) && isSafe!(__traits(getMember, typeof(T.init[0]), func))) {
	foreach(ref element ; array) {
		mixin("element." ~ func ~ "(args);");
	}
}

/**
 * Filters an array and returns one that contains only
 * the requested type.
 * Example:
 * ---
 * Entity[] entities = [entity, creeper, player, bat, cow, zombie, arrow, skeleton];
 * assert(entities.filter!Living == [creeper, player, bat, cow, zombie, skeleton]);
 * 
 * Block[] blocks = [gravel, wallSign, sand, noteblock, bedrock, shrub, postSign];
 * assert(blocks.filter!Tile == [wallSign, noteblock, postSign]);
 * ---
 */
public deprecated @property @safe T[] filter(T, E)(E[] array) {
	T[] ret;
	foreach(ref E e ; array) {
		if(cast(T)e) ret ~= cast(T)e;
	}
	return ret;
}

/**
 * Perform a safe conversion.
 * Example:
 * ---
 * assert(90.safe!ubyte == 90);
 * assert(256.safe!ubyte == 255);
 * ---
 */
public @property @safe T safe(T, E)(E value) {
	try {
		return value > T.max ? T.max : (value < T.min ? T.min : to!T(value));
	} catch(ConvException e) {
		return T.init;
	}
}

/**
 * Searches for an instance of a type in a typetuple.
 * Returns: the index if found, -1 otherwise
 */
public @property @safe ptrdiff_t staticInstanceIndex(T, E...)() {
	int f = -1;
	foreach(size_t index, F; E) {
		static if(is(typeof(F) == T)) {
			f = index;
			break;
		}
	}
	return f;
}

///
unittest {

	import std.typetuple;

	alias Z = TypeTuple!("string", string, 44u);
	static assert(staticInstanceIndex!(string, Z) == 0);
	static assert(staticInstanceIndex!(int, Z) == -1);
	static assert(staticInstanceIndex!(uint, Z) == 2);

	struct Test { uint i; }
	alias A = TypeTuple!();
	alias B = TypeTuple!(Test, Test(1));
	static assert(staticInstanceIndex!(Test, A) == -1);
	static assert(staticInstanceIndex!(Test, B) == 1);

}

class UnloggedException : Exception {
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
}
