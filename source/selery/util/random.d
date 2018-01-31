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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/random.d, selery/util/random.d)
 */
module selery.util.random;

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
