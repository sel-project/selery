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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/util.d, selery/util/util.d)
 */
module selery.util.util;

import core.stdc.time : time_t, time;

import std.conv : to, ConvException;
import std.datetime : Clock, UTC;
import std.traits : isArray, isAssociativeArray, isSafe;

/**
 * Gets the seconds from January 1st, 1970.
 */
public @property @safe time_t seconds() {
	return time(null);
}

/**
 * Gets the milliseconds from January 1st, 1970.
 */
public @property @safe ulong milliseconds() {
	auto t = Clock.currTime(UTC());
	return t.toUnixTime!long * 1000 + t.fracSecs.total!"msecs";
}

/**
 * Gets the microseconds from January 1st, 1970.
 */
public @property @safe ulong microseconds() {
	auto t = Clock.currTime(UTC());
	return t.toUnixTime!long * 1000 + t.fracSecs.total!"usecs";
}

/** 
 * Calls a function on every element in the array.
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
 * Performs a safe conversion.
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
