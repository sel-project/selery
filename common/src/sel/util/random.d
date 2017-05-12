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
module sel.util.random;

import std.math : acos;
import std.random : uniform, Rand = Random, unpredictableSeed, randomShuffle;

/**
 * Generates random values using the same seed.
 * Use 0 as a seed in the constructor to choose an seed using the
 * std.random.unpredictableSeed as seed.
 */
struct Random {
	
	private Rand rand;
	
	public @safe this(uint seed) {
		if(seed == 0) {
			seed = unpredictableSeed;
		}
		this.rand = Rand(seed);
	}
	
	/// Gets a random number between min (included) and max (excluded).
	public @safe T next(T)(T min, T max) {
		return uniform!("[)", T)(min, max, this.rand);
	}
	
	/// Gets a random number between 0 (included) and max (excluded).
	public @safe T next(T)(T max) {
		return this.next!T(0, max);
	}
	
	/// Gets a random floating point number between 0 and 1 (both included).
	public @safe T next(T)() if(is(T == float) || is(T == double) || is(T == real)) {
		return uniform!("[]", T)(0, 1, this.rand);
	}
	
	/// Gets a random number between min (included) and max (included).
	public @safe T range(T)(T min, T max) {
		return uniform!("[]", T)(min, max, this.rand);
	}
	
	/// Gets a random numver between 0 (included) and max (included).
	public @safe T range(T)(T max=T.max) {
		return this.range!T(0, max);
	}
	
	/// Gets a random number between min (excluded) and max (excluded).
	public @safe T between(T)(T min, T max) {
		return uniform!("()", T)(min, max, this.rand);
	}
	
	/// Gets a random number between 0 (excluded) and max (excluded).
	public @safe T between(T)(T max=T.max) {
		return this.between!T(0, max);
	}
	
	/**
	 * Gets a probability using a percentage between 0 and 1.
	 * Example:
	 * ---
	 * if(random.probability(.25)) {}      // 25%
	 * if(random.probability(.99.999)) {}  // 99.999%
	 * ---
	 */
	public @safe bool probability(float amount) {
		return this.next!float <= amount;
	}
	
	/** 
	 * Gets a random value from an array.
	 * Example:
	 * ---
	 * Random random = Random(0);
	 * Object a, b, c;
	 * writeln(random.array(a, b, c));
	 * writeln(random.array([a, b, c]));
	 * ---
	 */
	public @safe T array(T)(T[] args ...) {
		return args[this.next($)];
	}
	
	/** Get an uniformly distribuited random on an arc (0 - PI) */
	public @safe T arc(T=double)() {
		return acos(this.range!T(-1, 1));
	}
	
	/**
	 * Shuffles an array using std.random.randomShuffle and
	 * the struct's seed.
	 * Example:
	 * ---
	 * int[] array = [1, 2, 3, 4];
	 * random.shuffle(array);
	 * ---
	 */
	public @safe void shuffle(T)(ref T[] array) {
		randomShuffle(array, this.rand);
	}
	
}
