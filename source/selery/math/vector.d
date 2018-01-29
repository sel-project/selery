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
module selery.math.vector;

import std.algorithm : reverse, canFind;
import std.array : join, split;
import std.conv : to, ConvException;
static import std.math;
import std.meta : staticIndexOf;
import std.range.primitives : ElementType;
import std.string : replace;
import std.traits : IntegralTypeOf, isNumeric, isArray, CommonType, isFloatingPointTrait = isFloatingPoint, isImplicitlyConvertible;
import std.typecons : isTuple;
import std.typetuple : TypeTuple;

static import std.typecons;

/**
 * Vector for coordinates storing and operations.
 */
struct Vector(T, char[] c) if(c.length > 1 && areValidCoordinates(c)) {
	
	public alias Type = T;
	public alias coordinates = c;

	mixin("alias Tuple = std.typecons.Tuple!(T, \"" ~ join(coordinates.idup.split(""), "\", T, \"") ~ "\");");
	
	mixin("public enum coords = TypeTuple!('" ~ join(coordinates.idup.split(""), "','") ~ "');");
	
	enum bool isFloatingPoint = isFloatingPointTrait!T;

	private Tuple value;
	
	mixin((){
		string ret;
		foreach(immutable c ; coords) {
			ret ~= "public pure nothrow @property @safe @nogc T " ~ c ~ "(){ return this.value." ~ c ~ "; }";
		}
		return ret;
	}());

	public pure nothrow @safe @nogc this(Tuple value) {
		this.value = value;
	}

	public pure nothrow @safe @nogc this(T value) {
		foreach(immutable c ; coords) {
			mixin("this.value." ~ c ~ " = value;");
		}
	}
	
	public @safe this(F...)(F args) if(F.length == coordinates.length) {
		foreach(i, immutable c; coords) {
			mixin("this.value." ~ c ~ " = cast(T)args[" ~ to!string(i) ~ "];");
		}
	}
	
	public @safe @nogc this(T[coords.length] variables) {
		foreach(i, immutable c; coords) {
			mixin("this.value." ~ c ~ " = variables[i];");
		}
	}
	
	public @safe @nogc this(T[] variables) {
		foreach(i, immutable c; coords) {
			mixin("this.value." ~ c ~ " = variables[i];");
		}
	}

	/**
	 * Gets the vector as a constant tuple.
	 * Example:
	 * ---
	 * auto v = vector(0, 3, 4);
	 * assert(v.tuple == typeof(v).Tuple(0, 3, 4));
	 * ---
	 */
	public pure nothrow @property @safe @nogc const Tuple tuple() {
		return this.value;
	}
	
	/**
	 * Compares the vector with another vector of the same length or with
	 * a single number.
	 * Returns: true if all the values are equals, false otherwise
	 * Example:
	 * ---
	 * assert(Vector2!int(0, 10) == Vector2!int(0, 10));
	 * assert(Vector3!ubyte(1, 1, 255) == Vector3!real(1, 1, 255));
	 * assert(vector(0, 0, 0, 0) == 0);
	 * assert(vector(1, 2) == [1, 2]);
	 * assert(vector(float.nan, float.nan) != vector(float.nan, float.nan));
	 * ---
	 */
	public bool opEquals(F)(F value) {
		static if(isVector!F && coords == F.coords) return this.opEqualsImpl!"this.{c}==value.{c}"(value);
		else static if(isArray!F) return value.length == coords.length && this.opEqualsImpl!"this.{c}==value[{i}]"(value);
		else static if(__traits(compiles, T.init == F.init)) return this.opEqualsImpl!"this.{c}==value"(value);
		else return false;
	}
	
	private bool opEqualsImpl(string op, F)(F value) {
		mixin((){
				string[] ret;
				foreach(i, immutable c; coords) {
					ret ~= op.replace("{c}", to!string(c)).replace("{i}", to!string(i));
				}
				return "return " ~ ret.join("&&") ~ ";";
			}());
	}
	
	/**
	 * Performs an unary operation on the vector.
	 * Returns: the new vector
	 * Example:
	 * ---
	 * auto v = vector(-1, 0, 1);
	 * assert(-v == vector(1, 0, -1));
	 * assert(++v == vector(0, 1, 2)); // this will change the original vector's values!
	 * assert(v-- == vector(0, 1, 2) && v == vector(-1, 0, 1));
	 * ---
	 */
	public typeof(this) opUnary(string op)() if(__traits(compiles, { mixin("T t;t=" ~ op ~ "t;"); })) {
		typeof(this) ret;
		foreach(immutable c ; coords) {
			mixin("ret." ~ c ~ "=" ~ op ~ "this.value." ~ c ~ ";");
		}
		return ret;
	}
	
	/**
	 * Performs a binary operation on the vector.
	 * Params:
	 * 		value = a number, a vector or an array with the same size
	 * Returns: the new vector
	 * Example:
	 * ---
	 * assert(vector(1, 1) - 1 == vector(0, 0));
	 * assert(vector(10, 10) * vector(0, 9) == vector(0, 90));
	 * assert(vector(16, 15) & [15, 3] == vector(0, 3));
	 * assert(1 - vector(100, 0, -100) == vector(-99, 1, 101));
	 * ---
	 */
	public typeof(this) opBinary(string op, F)(F value) if(op != "in") {
		return this.dup.opOpAssign!op(value);
	}
	
	public typeof(this) opBinaryRight(string op, F)(F value) if(op != "in" && __traits(compiles, typeof(this)(value))) {
		return typeof(this)(value).opBinary!op(this);
	}
	
	/**
	 * Performs an assign operation on the vector, modifying it.
	 * Params:
	 * 		value = a number, a vector or an array with the same size
	 * Returns:
	 * Example:
	 * ---
	 * auto v = vector(1, 2);
	 * v += 4;
	 * v *= [0, 2];
	 * assert(v == vector(0, 12));
	 * ---
	 */
	public typeof(this) opOpAssign(string op, F)(F value) if(isVector!F && coordinates == F.coordinates) {
		return this.opAssignImpl!("this.value.{c}" ~ op ~ "=value.{c}")(value);
	}
	
	/// ditto
	public typeof(this) opOpAssign(string op, F)(F value) if(isArray!F) {
		return this.opAssignImpl!("this.value.{c}" ~ op ~ "=value[{i}]")(value);
	}
	
	/// ditto
	public typeof(this) opOpAssign(string op, F)(F value) if(isImplicitlyConvertible!(F, T)) {
		return this.opAssignImpl!("this.value.{c}" ~ op ~ "=value")(value);
	}
	
	private typeof(this) opAssignImpl(string query, F)(F value) {
		foreach(i, immutable c; coords) {
			mixin(query.replace("{c}", to!string(c)).replace("{i}", to!string(i)) ~ ";");
		}
		return this;
	}
	
	/**
	 * Converts the vector to the given one, mantaining the variables's
	 * value when possible.
	 * Example:
	 * ---
	 * assert(cast(Vector2!int)vector(.1, .1, 14) == vector(0, 14));
	 * assert(cast(Vector4!real)vector(.5, 100) == vector(.5, 0, 100, 0));
	 * // this will only return the vector
	 * assert(cast(Vector2!int
	 * ---
	 */
	public @safe auto opCast(F)() if(isVector!F) {
		static if(is(T == F) && coordinates == F.coordinates) {
			return this;
		} else {
			F ret;
			foreach(immutable c; F.coords) {
				static if(coordinates.canFind(c)) {
					mixin("ret.value." ~ c ~ "=to!(F.Type)(this." ~ c ~ ");");
				}
			}
			return ret;
		}
	}
	
	/**
	 * Converts the vector into an array of the same size.
	 * Example:
	 * ---
	 * assert(cast(int[])vector(1, 2) == [1, 2]);
	 * assert(cast(long[])vector(.1, 1.5, -.1) == [0L, 1L, 0L]);
	 * ---
	 */
	public @safe auto opCast(F)() if(isArray!F) {
		F array;
		foreach(immutable c ; coords) {
			mixin("array ~= to!(typeof(T.init[0]))(this." ~ c ~ ");");
		}
		return array;
	}
	
	/**
	 * Changes the vector's type.
	 */
	public auto type(F)() if(isImplicitlyConvertible!(F, T)) {
		Vector!(F, coordinates) ret;
		foreach(immutable c ; coords) {
			mixin("ret.value." ~ c ~ "=this." ~ c ~ ";");
		}
		return ret;
	}
	
	/**
	 * Duplicates the vector, mantaing the type, variables'
	 * names and their value.
	 * Example:
	 * ---
	 * assert(vector(1, 1).dup == vector(1, 1));
	 * ---
	 */
	alias dup = type!T;

	/**
	 * Gets the vector's length.
	 */
	public @property double length() {
		double length = 0;
		foreach(immutable c ; coords) {
			mixin("length += this.value." ~ c ~ " * this.value." ~ c ~ ";");
		}
		return std.math.sqrt(length);
	}

	/**
	 * Sets the vector's length.
	 */
	public @property double length(double length) {
		double mult = length / this.length;
		foreach(immutable c ; coords) {
			mixin("this.value." ~ c ~ " = cast(T)(this.value." ~ c ~ " * mult);");
		}
		return length;
	}
	
	/**
	 * Converts the vector into a string for logging and debugging purposes.
	 */
	public string toString() {
		string[] cs;
		foreach(i, coord; coords) {
			mixin("cs ~= to!string(this." ~ coord ~ ");");
		}
		return "Vector!(" ~ T.stringof ~ ", \"" ~ coordinates.idup ~ "\")(" ~ cs.join(", ") ~ ")";
	}
	
}

/// ditto
alias Vector(T, string coords) = Vector!(T, coords.dup);

/// ditto
alias Vector2(T) = Vector!(T, "xz");

/// ditto
alias Vector3(T) = Vector!(T, "xyz");

/// ditto
alias Vector4(T) = Vector!(T, "xyzw");

private bool areValidCoordinates(char[] coords) {
	foreach(i, char c; coords[0..$-1]) {
		if(coords[i+1..$].canFind(c)) return false;
	}
	return true;
}

/**
 * Automatically creates a vector if the number of the
 * given arguments matches one of the default vectors.
 * Example:
 * ---
 * assert(is(typeof(vector(1, 1)) == Vector2!int));
 * assert(is(typeof(vector(2Lu, 4)) == Vector2!ulong));
 * assert(is(typeof(vector(5, 5, 19.0)) == Vector3!double));
 * assert(is(typeof(vector(0, real.nan, double.nan, float.nan)) == Vector4!real));
 * ---
 */
public auto vector(E...)(E args) if(E.length > 1 && E.length <= 4 && !is(CommonType!E == void)) {
	mixin("return Vector" ~ to!string(E.length) ~ "!(CommonType!E)(args);");
}

/// Checks if the given type is a vector
enum bool isVector(T) = __traits(compiles, Vector!(T.Type, T.coordinates)(T.Type.init));

public nothrow @safe T mathFunction(alias func, T)(T vector) if(isVector!T) {
	T.Type[] values;
	foreach(immutable c ; T.coords) {
		mixin("values ~= cast(T.Type)func(vector." ~ c ~ ");");
	}
	return T(values);
}

/**
 * Rounds a vector to the nearest integer.
 * Example:
 * ---
 * assert(round(vector(.25, .5, .75)) == vector(0, 1, 1));
 * ---
 */
public nothrow @safe T round(T)(T vector) if(isVector!T) {
	return mathFunction!(std.math.round)(vector);
}

/**
 * Floors a vector to the nearest integer.
 * Example:
 * ---
 * assert(floor(vector(.25, .5, .75)) == vector(0, 0, 0));
 * ---
 */
public nothrow @safe T floor(T)(T vector) if(isVector!T) {
	return mathFunction!(std.math.floor)(vector);
}

/**
 * Ceils a vector to the nearest integer.
 * Example:
 * ---
 * assert(ceil(vector(.25, .5, .75)) == vector(1, 1, 1));
 * ---
 */
public nothrow @safe T ceil(T)(T vector) if(isVector!T) {
	return mathFunction!(std.math.ceil)(vector);
}

/**
 * Calculate the absolute value of the array.
 * Example:
 * ---
 * assert(abs(vector(-1, 0, 90)) == vector(1, 0, 90));
 * ---
 */
public nothrow @safe T abs(T)(T vector) if(isVector!T) {
	return mathFunction!(std.math.abs)(vector);
}

/**
 * Checks whether or not every member of the vector is finite
 * (not infite, -inifite, nan).
 * Example:
 * ---
 * assert(isFinite(vector(1, 2)));
 * assert(isFinite(vector(float.min, float.max)));
 * assert(!isFinite(vector(1, float.nan)));
 * assert(!isFinite(vector(-float.infinity, 1f/0f)));
 * ---
 */
public pure nothrow @safe @nogc bool isFinite(T)(T vector) if(isVector!T && T.isFloatingPoint) {
	foreach(immutable c ; T.coords) {
		mixin("if(!std.math.isFinite(vector." ~ c ~ ")) return false;");
	}
	return true;
}

/**
 * Checks whether or not at least one member of the vector
 * is not a number (nan).
 * Example:
 * ---
 * assert(!isNaN(vector(0, 2.1)));
 * assert(isNaN(vector(float.init, -double.init)));
 * assert(isNaN(vector(0, float.nan)));
 * ---
 */
public pure nothrow @safe @nogc bool isNaN(T)(T vector) if(isVector!T && T.isFloatingPoint) {
	foreach(immutable c ; T.coords) {
		mixin("if(std.math.isNaN(vector." ~ c ~ ")) return true;");
	}
	return false;
}

public @safe double distanceSquared(F, G)(F vector1, G vector2) if(isVector!F && isVector!G && F.coordinates == G.coordinates) {
	double sum = 0;
	foreach(immutable c ; F.coords) {
		mixin("sum += std.math.pow(vector1." ~ c ~ " - vector2." ~ c ~ ", 2);");
	}
	return sum;
}

/**
 * Calculates the distance between to vectors of the
 * same length.
 * Params:
 * 		vector1 = the first vector
 * 		vector2 = the second vector
 * Returns: the distance between the two vectors (always higher or equals than  0)
 * Example:
 * ---
 * assert(distance(vector(0, 0), vector(1, 0)) == 1);
 * assert(distance(vector(0, 0, 0) == vector(1, 1, 1)) == 3 ^^ .5); // 3 ^^ .5 is the squared root of 3
 * ---
 */
public @safe double distance(T, char[] coords, E)(Vector!(T, coords) vector1, Vector!(E, coords) vector2) {
	return std.math.sqrt(distanceSquared(vector1, vector2));
}

public pure nothrow @safe double dot(T, char[] coords, E)(Vector!(T, coords) vector1, Vector!(E, coords) vector2) {
	double dot = 0;
	foreach(immutable c ; Vector!(T, coords).coords) {
		mixin("dot += vector1." ~ c ~ " * vector2." ~ c ~ ";");
	}
	return dot;
}

public pure nothrow @safe Vector!(CommonType!(A, B), coords) cross(A, B, char[] coords)(Vector!(A, coords) a, Vector!(B, coords) b) {
	foreach(immutable exc ; Vector!(T, coords).coords) {

	}
}

/**
 * Example:
 * ---
 * alias DoublePosition = Vector3!float;
 * 
 * ---
 */
deprecated("Use the vector's constructor instead") public V vector(V, T)(T tuple) if(isVector!V && isTuple!T) {
	mixin((){
		string[] ret;
		foreach(field ; T.fieldNames) {
			ret ~= "conv!(V.Type)(tuple." ~ field ~ ")";
		}
		return "return V(" ~ ret.join(",") ~ ");";
	}());
}

deprecated("Use vector's .tuple property instead") public T tuple(T, V)(V vector) if(isTuple!T && isVector!V) {
	T tup;
	mixin((){
		string ret = "";
		foreach(i, immutable c; V.coords) {
			ret ~= "tup." ~ c ~ "=conv!(T.Types[" ~ to!string(i) ~ "])(vector." ~ c ~ ");";
		}
		return ret;
	}());
	return tup;
}

To conv(To, From)(From from) {
	static if(is(From == To)) return from;
	else return cast(To)from;
}

unittest {
	
	Vector3!int v3 = Vector3!int(-1, 0, 12);
	
	// comparing
	assert(v3.x == -1);
	assert(v3.y == 0);
	assert(v3.z == 12);
	assert(v3 == Vector3!int(-1, 0, 12));
	assert(v3 == Vector3!float(-1, 0, 12));
	assert(v3 != Vector3!double(-1, 0, 12.00000001));
	
	// unary
	assert(-v3 == Vector3!int(1, 0, -12));
	assert(++v3 == Vector3!int(0, 1, 13) && v3 == Vector3!int(0, 1, 13));
	assert(v3-- == Vector3!int(0, 1, 13) && v3 == Vector3!int(-1, 0, 12));
	
	// binary operator
	assert(v3 + 3 == Vector3!int(2, 3, 15));
	assert(v3 * 100 == Vector3!int(-100, 0, 1200));
	assert(v3 - v3 == Vector3!int(0, 0, 0));
	assert(Vector3!double(.5, 0, 0) + v3 == Vector3!double(-.5, 0, 12));
	assert(v3 * [1, 2, 3] == Vector3!int(-1, 0, 36));
	assert((v3 & 1) == Vector3!int(1, 0, 0));
	assert(1 - v3 == Vector3!int(2, 1, -11));
	
	// assign operator
	assert((v3 *= 3) == Vector3!int(-3, 0, 36));
	assert(v3 == Vector3!int(-3, 0, 36));
	v3 >>= 1;
	assert(v3 == Vector3!int(-2, 0, 18));
	
	// cast
	Vector3!float v3f = cast(Vector3!float)v3;
	Vector2!int reduced = cast(Vector2!int)v3;
	Vector4!long bigger = cast(Vector4!long)v3;
	assert(v3f == Vector3!float(-2, 0, 18));
	assert(reduced == Vector2!float(-2, 18));
	assert(bigger == Vector4!long(-2, 0, 18, 0));
	
	// vector function
	assert(vector(8, 19).Type.stringof == "int");
	assert(vector(1.0, 2, 99.9).Type.stringof == "double");
	assert(vector(1f, .01, 12L).Type.stringof == "double");
	
	// math functions
	assert(round(vector(.2, .7)) == vector(0, 1));
	assert(floor(vector(.2, .7)) == vector(0, 0));
	assert(ceil(vector(.2, .7)) == vector(1, 1));
	assert(abs(vector(-.2, .7)) == vector(.2, .7));
	
	// distance
	assert(distance(vector(0, 0), vector(0, 1)) == 1);
	assert(distance(vector(0, 0, 0), vector(1, 1, 1)) == 3 ^^ .5);
	
}

/// Vectors usually used by Minecraft
alias ChunkPosition = Vector2!int;

/// ditto
alias EntityPosition = Vector3!double;

/// ditto
alias BlockPosition = Vector3!int;

/// Gets a ushort that indicates a position in a chunk.
public @property @safe ushort shortBlockPosition(BlockPosition position) {
	return (position.y << 8 | position.z << 4 | position.x) & ushort.max;
}

/// Gets a BlockPosition from an ushort that indicates a position in a chunk.
public @property @safe BlockPosition blockPositionShort(ushort position) {
	return BlockPosition(cast(int)(position & 255), cast(int)(position >> 8), cast(int)((position >> 4) & 255));
}

/// Casts a BlockPosition to an EntityPosition using vector's opCast.
public @property @safe EntityPosition entityPosition(BlockPosition block) {
	return cast(EntityPosition)block;
}

/// Casts an EntityPosition to a BlockPosition using vector's opCast.
public @property @safe BlockPosition blockPosition(EntityPosition entity) {
	return cast(BlockPosition)entity;
}

enum Face : uint {
	
	DOWN = 0,
	UP = 1,
	NORTH = 2,
	SOUTH = 3,
	WEST = 4,
	EAST = 5
	
}

// Gets the block position from a tap.
public @property @safe BlockPosition face(BlockPosition from, uint face) {
	switch(face) {
		case Face.DOWN: return from - [0, 1, 0];
		case Face.UP: return from + [0, 1, 0];
		case Face.NORTH: return from - [0, 0, 1];
		case Face.SOUTH: return from + [0, 0, 1];
		case Face.WEST: return from - [1, 0, 0];
		case Face.EAST: return from + [1, 0, 0];
		default: return from;
	}
}

abstract class Box(T) {
	
	public abstract @safe bool intersects(Box!T box);
	public abstract @safe bool intersects(Box!T box, bool deep);
	
	public abstract @property @safe @nogc Vector3!T minimum();
	public abstract @property @safe @nogc Vector3!T maximum();
	
	public abstract @property @safe Box!T dup();
	public abstract override @safe string toString();
	
}

abstract class ClassicBox(T) : Box!T {
	
	public override @safe bool intersects(Box!T box) {
		return this.intersects(box, true);
	}
	
	public override @safe bool intersects(Box!T box, bool deep) {
		Vector3!T tmin = this.minimum;
		Vector3!T tmax = this.maximum;
		Vector3!T bmin = box.minimum;
		Vector3!T bmax = box.maximum;
		if(tmin.x > bmin.x && tmin.x < bmax.x || tmax.x > bmin.x && tmax.x < bmax.x) {
			if(tmin.y >= bmin.y && tmin.y <= bmax.y || tmax.y >= bmin.y && tmax.y <= bmax.y) {
				if(tmin.z > bmin.z && tmin.z < bmax.z || tmax.z > bmin.z && tmax.z < bmax.z) {
					return true;
				}
			}
		}
		return deep && box.intersects(this, false);
	}
	
	public override @safe string toString() {
		return "min: " ~ this.minimum.to!string ~ ", max: " ~ this.maximum.to!string;
	}
	
}

class ClassicEntityBox(T) : ClassicBox!T {
	
	private T width, height;
	
	private Vector3!T position;
	private Vector3!T min, max;
	
	public @safe this(T width, T height, Vector3!T position) {
		this.width = width;
		this.height = height;
		this.position = position;
		this.update();
	}
	
	public override @safe @nogc Vector3!T minimum() {
		return this.min;
	}
	
	public override @safe @nogc Vector3!T maximum() {
		return this.max;
	}
	
	public @safe void update(T width, T height) {
		this.width = width;
		this.height = height;
		this.update();
	}
	
	public @safe void update(Vector3!T position) {
		this.position = position;
		this.update();
	}
	
	protected @safe void update() {
		this.min = this.position - [this.width / 2f, 0, this.width / 2f];
		this.max = this.position + [this.width / 2f, this.height, this.width / 2f];
	}
	
	public @safe ClassicEntityBox!T grow(T width, T height) {
		return new ClassicEntityBox!T(width * 2, height * 2, this.position- [0, height, 0]);
	}
	
	public override @property @safe Box!T dup() {
		return new ClassicEntityBox!T(this.width, this.height, this.position);
	}
	
}

class ClassicBlockBox(T) : ClassicBox!T {
	
	private Vector3!T size_start, size_end;
	private Vector3!T start, end;
	//private bool updated;
	
	public @safe this(Vector3!T start, Vector3!T end) /*in { assert(start.x.one && start.y.one &&  start.z.one && end.x.one && end.y.one && end.z.one, "Blocks' sizes must be between 0 and 1"); } body*/ {
		this.size_start = start;
		this.size_end = end;
		//this.updated = false;
	}
	
	public @safe this(T startx, T starty, T startz, T endx, T endy, T endz) {
		this(Vector3!T(startx, starty, startz), Vector3!T(endx, endy, endz));
	}
	
	public @safe void update(Vector3!T position)/* in { assert(!this.updated, "ClassicBlockBox can only be updated once"); } body*/ {
		this.start = position + this.size_start;
		this.end = position + this.size_end;
	}
	
	public override @property @safe @nogc Vector3!T minimum() {
		return this.start;
	}
	
	public override @property @safe @nogc Vector3!T maximum() {
		return this.end;
	}
	
	public override @property @safe Box!T dup() {
		ClassicBlockBox!T ret = new ClassicBlockBox!T(this.start, this.end);
		//ret.updated = this.updated;
		return ret;
	}
	
}

/*class ComplexBox(T, bool block, E...) : Box!(T, block) {

	private Box!(T, block)[] boxes;

	public this(E args) {
		super(0, 0, null, null, null);
		foreach(e ; args) {
			if(typeid(e) == Box!(T, block)) {
				this.boxes ~= cast(Box!(T, block))e;
			}
		}
	}

	public override void update(Vector3!T position) {
		foreach(Box!(T, block) box ; this.boxes) {
			box.update(position);
		}
	}

	public override @property Vector3!T minimum() {
		Vector3!T ret;
		foreach(Box!(T, block) box ; this.boxes) {
			Vector3!T min = box.minimum;
			if(ret is null || (min.x < ret.x && min.y < ret.y && min.z < ret.z)) ret = min;
		}
		return ret;
	}

	public override @property Vector3!T maximum() {
		Vector3!T ret;
		foreach(Box!(T, block) box ; this.boxes) {
			Vector3!T max = box.maximum;
			if(ret is null || (max.x > ret.x && max.y > ret.y && max.z > ret.z)) ret = max;
		}
		return ret;
	}

	public override string toString() {
		return this.boxes.to!string;
	}

}*/

alias EntityAxis = ClassicEntityBox!(EntityPosition.Type);
alias BlockAxis = ClassicBlockBox!(EntityPosition.Type);
