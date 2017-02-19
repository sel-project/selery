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
 * The Named Binary Tag format is used by Minecraft for the various files in which it saves data. 
 * The format is described by Notch in a very brief <a href="http://web.archive.org/web/20110723210920/http://www.minecraft.net/docs/NBT.txt">specification</a>.
 * The format is designed to store data in a tree structure made up of various tags. All tags have
 * an ID and a name. The original known version was 19132 as introduced in Minecraft Beta 1.3,
 * and since then has been updated to 19133 with Anvil, with the addition of the Int Array tag.
 * The NBT format dates all the way back to Minecraft Indev with tags 0 to 10 in use.<br>
 * From <a href="http://minecraft.gamepedia.com/NBT_format">Minecraft Wiki</a>
 * 
 * NBT tags descripted in this page:<br>
 * <a href="#End">End</a><br>
 * <a href="#Byte">Byte</a> (<a href="#Bool">Bool</a>)<br>
 * <a href="#Short">Short</a><br>
 * <a href="#Int">Int</a><br>
 * <a href="#Long">Long</a><br>
 * <a href="#Float">Float</a><br>
 * <a href="#Double">Double</a><br>
 * <a href="#ByteArray">Byte Array</a><br>
 * <a href="#String">String</a><br>
 * <a href="#List">List</a><br>
 * <a href="#Compound">Compound</a><br>
 * <a href="#IntArray">Int Array</a>
 * 
 * Macros:
 * 		TAGS = <b>Tags:</b> <a href="#End">End</a>, <a href="#Byte">Byte</a> (<a href="#Bool">Bool</a>), <a href="#Short">Short</a>, 
 * 					<a href="#Int">Int</a>, <a href="#Long">Long</a>, <a href="#Float">Float</a>, <a href="#Double">Double</a>, 
 * 					<a href="#ByteArray">Byte Array</a>, <a href="#String">String</a>, <a href="#List">List</a>, 
 * 					<a href="#Compound">Compound</a>, <a href="#IntArray">Int Array</a>
 */
module sel.nbt.tags;

import std.algorithm : canFind;
import std.conv : to;
import std.string : replace, toLower, indexOf;
import std.system : Endian;
import std.traits : isAbstractClass;
import std.typetuple : TypeTuple;

import sel.util.buffers;

/// NBT's ids, as unsigned bytes, used by for client-server and generic io communication.
enum NBT : ubyte {
	
	END = 0,
	BYTE = 1,
	SHORT = 2,
	INT = 3,
	LONG = 4,
	FLOAT = 5,
	DOUBLE = 6,
	BYTE_ARRAY = 7,
	STRING = 8,
	LIST = 9,
	COMPOUND = 10,
	INT_ARRAY = 11
	
}

alias Tags = TypeTuple!(End, Byte, Short, Int, Long, Float, Double, ByteArray, String, List, Compound, IntArray);

/**
 * Base class for every NBT that contains id and encoding
 * functions (the endianness may vary from a Minecraft version
 * to another and the purpose of the tags in the game).
 */
abstract class Tag {
	
	/// The id of the tag, should be one in the NBT enum.
	private ubyte n_id;
	
	public @safe @nogc this(ubyte id) {
		this.n_id = id;
	}
	
	public final pure nothrow @property @safe @nogc ubyte id() {
		return this.n_id;
	}
	
	public abstract override @safe string toString();
	
}

/**
 * $(TAGS)
 * 
 * Tag that marks the end of a Compound tag.
 * Its length is always 1 (its id as a btye) and it's the
 * only tag not named and without a value.
 */
final class End : Tag {
	
	public static End instance;
	
	public static this() {
		instance = new End();
	}
	
	public @safe @nogc this() {
		super(NBT.END);
	}
	
	public override pure nothrow @safe string toString() {
		return "End";
	}
	
}

/**
 * An NBT with a name, usually every tag with a value
 * is a named tag.
 */
abstract class NamedTag : Tag {
	
	protected string n_name;
	
	public @safe @nogc this(string name, ubyte id) {
		super(id);
		this.n_name = name;
	}
	
	/// Gets the name of the tag.
	public final pure nothrow @property @safe @nogc string name() {
		return n_name;
	}
	
}

/**
 * Simple tag with a value of type T, if T is a primitive type
 * or it can be written in the buffer.
 * Example:
 * ---
 * assert(new Short(1) == 1);
 * assert(new Int("name", 100) == new Byte(100));
 * assert(new SimpleTag!(char, 12)('c') == 'c');
 * ---
 */
class SimpleTag(T, ubyte type, string sof) : NamedTag {
	
	alias Type = T;
	
	enum ID = type;
	
	public T value;
	
	public @safe @nogc this(string name, T value=T.init) {
		super(name, type);
		this.value = value;
	}
	
	public @safe @nogc this(T value=T.init) {
		this("", value);
	}
	
	public override bool opEquals(Object object) {
		if(cast(typeof(this))object) {
			auto cmp = cast(typeof(this))object;
			return this.value == cmp.value && this.name == cmp.name;
		}
		return false;
	}
	
	public bool opEquals(T value) {
		return this.value == value;
	}
	
	public override @safe string toString() {
		return stringof ~ "(\"" ~ this.name ~ "\", " ~ to!string(this.value) ~ ")";
	}
	
	alias value this;
	
	enum stringof = sof;
	
}

/**
 * $(TAGS)
 * 
 * Tag with a signed byte, usually used to store small
 * values like the progress of an action or the type of
 * an entity.
 * An unsigned version of the tag can be obtained doing a
 * cast to ubyte.
 * <a href="#ByteArray">Byte Array</a> is a tag with an array
 * of unsigned bytes.
 * Example:
 * ---
 * assert(cast(ubyte)(new Byte(-1)) == 255);
 * ---
 */
alias Byte = SimpleTag!(byte, NBT.BYTE, "Byte");

/**
 * $(TAGS)
 * 
 * Byte tag that only uses the values 1 and 0 to indicate
 * respectively true and false.
 * It's usually used by SEL to store boolean values instead
 * of a byte tag.
 * Example:
 * ---
 * assert(new Byte(1) == new Bool(true));
 * ---
 */
alias Bool = Byte;

/**
 * $(TAGS)
 * 
 * Tag with a signed short, used when the 255 bytes (or 127
 * if only the positive part is counted) is not enough.
 * This tag can also be converted to its unsigned version
 * doing a simple cast to ushort.
 */
alias Short = SimpleTag!(short, NBT.SHORT, "Short");

/**
 * $(TAGS)
 * 
 * Tag with a signed integer, used to store values that
 * don't usually fit in the short tag, like entity's ids.
 * This tag can aslo be converted to its unsigned version
 * (uint) with a simple cast to it.
 * <a href="#IntArray">Int Array</a> is a tag with an array
 * of signed integers.
 */
alias Int = SimpleTag!(int, NBT.INT, "Int");

/**
 * $(TAGS)
 * 
 * Tag with a signed long.
 */
alias Long = SimpleTag!(long, NBT.LONG, "Long");

/**
 * $(TAGS)
 * 
 * Tag with a 4-bytes floating point value, usually used to
 * store non-blocks coordinates or points in the world.
 * The float.nan value can be used and recognized by the
 * SEL-derived systems, but couldn't be recognized by other
 * softwares based on different programming languages that
 * doesn't support the not-a-number value.
 * More informations about the NaN value and its encoding
 * can be found on <a href="#https://en.wikipedia.org/wiki/NaN">Wikipedia</a>.
 */
alias Float = SimpleTag!(float, NBT.FLOAT, "Float");

/**
 * $(TAGS)
 * 
 * Tag with an 8-bytes float point value used instead of the
 * Float tag if the precision or the available number's range
 * must be higher.
 * See <a href="#Float">Float</a>'s documentation for informations
 * about the NaN value and its support inside and outside SEL.
 */
alias Double = SimpleTag!(double, NBT.DOUBLE, "Double");

/**
 * $(TAGS)
 * 
 * Tag with an UTF-8 string encoded as its length as short and
 * its content casted to btyes.
 * The 1-parameter constructor takes the value, not the name.
 * Example:
 * ---
 * assert(new String("test") == new String("name", "test"));
 * ---
 */
class String : SimpleTag!(string, NBT.STRING, "String") {
	
	public @safe @nogc this(string name, string value) {
		super(name, value);
	}
	
	public @safe this(string value="") {
		this("", value);
	}
	
	alias value this;
	
}

unittest {
	
	assert(new Byte(1) == new Byte(1));
	assert(new Int("test", 12) == new Int("test", 12));
	assert(new Long(44) == 44);
	assert(new Double("test", 0) != new Double("test!", 0));
	assert(12f == new Float(12f));
	
}

/**
 * Simple tag with array-related functions.
 * Example:
 * ---
 * assert(new ByteArray([2, 3, 4]).length == new IntArray([9, 0, 12]).length);
 * 
 * auto b = new ByteArray("test");
 * assert(b.empty);
 * b ~= 14;
 * assert(b.length == 1 && b[0] == 14);
 * ---
 */
class ArrayTag(T, ubyte type, string sof) : SimpleTag!(T[], type, sof) {
	
	public @safe @nogc this(string name, T[] value...) {
		super(name, value);
	}
	
	public @safe this(T[] value...) {
		this("", value);
	}
	
	/**
	 * Gets the value at the given index.
	 * Returns: the value of type T at the given index
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * assert(new IntArray([1, 14, 900])[1] == 14);
	 * ---
	 */
	public @safe T opIndex(size_t index) {
		return this.value[index];
	}
	
	/**
	 * Sets the value at the given index.
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 14, 900]);
	 * array[1] = 1;
	 * assert(array == [1, 1, 900]);
	 * ---
	 */
	public @safe void opIndexAssign(E)(E value, size_t index) if(!is(T == immutable)) {
		this.value[index] = cast(T)value;
	}
	
	/**
	 * Checks if the array contains value.
	 * Returns: true if one the value in the array is equals to value, false otherwise
	 * ---
	 * auto array = new ByteArray(1, 2, 3, 4, 5);
	 * assert(array.contains(1));
	 * assert(!array.contains(0));
	 * assert(array.contains(new Byte("test", 3)));
	 * ---
	 */
	public @trusted bool contains(T value) {
		foreach(T v ; this.value) {
			if(v == value) return true;
		}
		return false;
	}
	
	/**
	 * Concatenates T, an array of T or a NBT array of T to the tag.
	 * Example:
	 * ---
	 * auto array = new IntArray([1]);
	 * 
	 * array ~= 1;
	 * assert(array == [1, 1]);
	 * 
	 * array ~= [1, 2, 3];
	 * assert(array == [1, 1, 1, 2, 3]);
	 *
	 * array ~= new IntArray([100, 99]);
	 * assert(array == [1, 1, 1, 2, 3, 100, 99]);
	 * ---
	 */
	public @safe void opOpAssign(string op, G)(G value) if(op == "~" && (is(G == T) || is(G == T[]))) {
		this.value ~= value;
	}
	
	/**
	 * Does the same job opOpAssign does, but creates a new instance
	 * of typeof(this) with the same name of the tag and returns it.
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 2, 3]);
	 * assert(array ~ [2, 1] == [1, 2, 3, 2, 1] && array == [1, 2, 3]);
	 * ---
	 */
	public @safe typeof(this) opBinary(string op, G)(G value) if(op == "~" && (is(G == T) || is(G == T[]))) {
		return new typeof(this)(this.name, this.value ~ value);
	}
	
	/**
	 * Removes the element at the given index from the array.
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 2, 3]);
	 * array.remove(0);
	 * assert(array == [2, 3]);
	 * ---
	 */
	public @safe void remove(size_t index) {
		this.value = this.value[0..index] ~ this.value[index+1..$];
	}
	
	/**
	 * Gets the length of the array as an unsigned integer.
	 * Example:
	 * ---
	 * auto array = new IntArray("empty");
	 * assert(array.length == 0);
	 * array ~= 1;
	 * assert(array.length == 1);
	 * assert(array[$-1] == 1);
	 * ---
	 */
	public final pure nothrow @property @safe @nogc size_t length() {
		return this.value.length;
	}
	
	/// ditto
	public final pure nothrow @property @safe size_t length(size_t length) {
		this.value.length = length;
		return this.length;
	}
	
	/// ditto
	public @safe @nogc size_t opDollar() {
		return this.value.length;
	}
	
	/**
	 * Checks whether or not the array's length is equals to 0.
	 */
	public final @property @safe @nogc bool empty() {
		return this.length == 0;
	}
	
	alias value this;
	
}

/**
 * $(TAGS)
 * 
 * Array of unsigned bytes (clients and other softwares may
 * interpret the bytes as signed due to limitations of the
 * programming language).
 * The tag is usually used by Minecraft's worlds to store
 * blocks' ids and metas.
 * 
 * If a signed byte is needed a cast operation can be done.
 * Example:
 * ---
 * auto unsigned = new ByteArray([0, 1, 255]);
 * auto signed = cast(byte[])unsigned;
 * assert(signed == [0, 1, -1]);
 * ---
 */
alias ByteArray = ArrayTag!(ubyte, NBT.BYTE_ARRAY, "ByteArray");

/**
 * $(TAGS)
 * 
 * Array of signed integers, introduced in the last version
 * of the NBT format. Used by anvil worlds.
 * 
 * The same cast rules also apply for this tag's values.
 * Example:
 * ---
 * auto signed = new IntArray([-1]);
 * assert(cast(uint[])signed == [uint.max]);
 * ---
 */
alias IntArray = ArrayTag!(int, NBT.INT_ARRAY, "IntArray");

interface ListParameters {
	
	public @property @safe ubyte childId();
	
	public @property @safe NamedTag[] namedTags();
	
}

/**
 * $(TAGS)
 * 
 * Array of named tags of the same type.
 * Example:
 * ---
 * new ListOf!String();           // String[] -> string[]
 * new ListOf!Compound();         // Compound[] -> NamedTag[string][]
 * new ListOf!(List!Compound)();  // Compound[][] -> NamedTag[string][][]
 * ---
 */
class List : ArrayTag!(NamedTag, NBT.LIST, "List"), ListParameters {
	
	public @safe @nogc this(string name, NamedTag[] tags) {
		super(name, tags);
	}
	
	public @safe this(NamedTag[] tags) {
		this("", tags);
	}
	
	public final override @property @safe ubyte childId() {
		return this.length == 0 ? NBT.BYTE : this[0].id; // an empty list is a list of Byte (first named tag)
	}
	
	public final override pure nothrow @property @safe @nogc NamedTag[] namedTags() {
		return this.value;
	}
	
	public @safe T opCast(T)() if(is(T.TagType : NamedTag)) {
		//TODO they must be validated
		T.TagType[] array = new T.TagType[this.length];
		foreach(size_t i, ref T.TagType tag; array) {
			tag = cast(T.TagType)this[i];
		}
		return new T(this.name, array);
	}
	
	public override bool opEquals(Object object) {
		if(cast(NamedTag)object && cast(ListParameters)object) {
			return this.name == object.to!NamedTag.name && this.value == object.to!ListParameters.namedTags;
		}
		return false;
	}
	
	alias value this;
	
}

/// ditto
class ListOf(T:NamedTag) : ArrayTag!(T, NBT.LIST, "ListOf!" ~ (T.stringof.indexOf("!")==-1 ? T.stringof : ("(" ~ T.stringof ~ ")"))), ListParameters if(!isAbstractClass!T) {
	
	alias TagType = T;
	
	public @safe @nogc this(string name, T[] tags...) {
		super(name, tags);
	}
	
	public @safe @nogc this(T[] tags...) {
		this("", tags);
	}
	
	static if(is(typeof(T.ID) == ubyte)) {
		public final override pure nothrow @property @safe @nogc ubyte childId() {
			return T.ID;
		}
	} else {
		public final override @property @safe ubyte childId() {
			return new T().id;
		}
	}
	
	public final override @property @trusted NamedTag[] namedTags() {
		return cast(NamedTag[])this[];
	}
	
	public T opCast(T)() if(is(T == List)) {
		return new List(this.name, cast(NamedTag[])this[]);
	}
	
	public override bool opEquals(Object object) {
		if(cast(NamedTag)object && cast(ListParameters)object) {
			return this.name == object.to!NamedTag.name && this.namedTags == object.to!ListParameters.namedTags;
		}
		return false;
	}
	
	alias value this;
	
}

unittest {
	
	auto list = new ListOf!Byte([new Byte(1), new Byte(2)]);
	assert(cast(List)list !is null);
	
}

/**
 * $(TAGS)
 * 
 * Associative array of named tags (that can be of different types).
 * Example:
 * ---
 * auto compound = new Compound();
 * compound["string"] = new String("test");
 * compound["byte"] = new Byte(18);
 * ---
 */
class Compound : SimpleTag!(NamedTag[string], NBT.COMPOUND, "Compound") {
	
	public @safe this(string name, NamedTag[] tags...) {
		super(name, this.value);
		foreach(NamedTag tag ; tags) {
			this[] = tag;
		}
	}
	
	public @safe this(NamedTag[] tags...) {
		this("", tags);
	}
	
	/**
	 * Checks whether or not a value is in the associative array.
	 * Returns: true if the key is found, false otherwise
	 */
	public @safe bool has(string key) {
		return key in this.value ? true : false;
	}
	
	/**
	 * Checks if the key is associated to a value and that the value
	 * is of the same type of T.
	 * Returns: true if the value is found and is of the type T, false otherwise
	 */
	public @trusted bool has(T:NamedTag)(string key) {
		if(!this.has(key)) return false;
		if(cast(T)this.value[key]) {
			return true;
		} else {
			static if(is(T : ListParameters)) {
				if(cast(ListParameters)this.value[key]) {
					static if(is(T == List)) {
						// T is List, value is ListOf
						return true;
					} else {
						// T is ListOf, value is List
						return (cast(List)this.value[key]).childId == T.TagType.ID;
					}
				}
			}
			return false;
		}
	}
	
	/**
	 * Gets the pointer to the tag associated with the given key.
	 * Returns: the pointer to a NamedTag in the array or null if the given key isn't in the array
	 * Example:
	 * ---
	 * NameTag* test;
	 * if(test = ("test" in compound)) {
	 *    d("test is in the compound: ", *test);
	 * }
	 * ---
	 */
	public @safe NamedTag* opBinaryRight(string op)(string key) if(op == "in") {
		return key in this.value;
	}
	
	/**
	 * Gets the array of named tags (without the keys).
	 * To get the associative array of named tags use the
	 * property value.
	 * Example:
	 * ---
	 * Compound compound = new Compound([new Byte(1), new Int(2)]);
	 * assert(compound[] == compound.value.values);
	 * ---
	 */
	public @trusted NamedTag[] opIndex() {
		return this.value.values;
	}
	
	/**
	 * Gets the element at the given index.
	 * Throws: RangeError if the given index is not in the array
	 * Example:
	 * ---
	 * assert(new Compound("", ["test": new String("test")])[0] == "test");
	 * ---
	 */
	public @safe NamedTag opIndex(string index) {
		return this.value[index];
	}
	
	/**
	 * Gets the element at the given index, casting it to T.
	 * Returns: the named tag of type T or null if the conversion has failed
	 * Example:
	 * ---
	 * auto compound = new Compound("", ["test": new String("value")]);
	 * assert(is(typeof(compound["test"]) == NamedTag));
	 * assert(is(typeof(compound.get!String("test")) == String));
	 * ---
	 */
	public @trusted T get(T:NamedTag)(string index) {
		NamedTag ret = this.value[index];
		if(cast(T)ret) return cast(T)ret;
		static if(is(T : ListParameters)) {
			if(cast(ListParameters)ret) {
				static if(is(T == List)) {
					// T is List, ret is ListOf
					return new List(ret.name, (cast(List)ret).namedTags);
				} else {
					// T is ListOf, ret is List
					if((cast(ListParameters)ret).childId == T.TagType.ID) {
						return cast(T)cast(List)ret;
					}
				}
			}
		}
		return null;
	}
	
	/**
	 * Sets the value at the given index.
	 * If the tag's name is different from the given index, the tag's
	 * name will be changed to the given index's one.
	 * Example:
	 * ---
	 * auto str = new String("test", "test");
	 * new Compound("")["auto"] = str;
	 * assert(str.name == "auto");
	 * ---
	 */
	public @safe void opIndexAssign(NamedTag value, string index) {
		value.n_name = index;
		this.value[index] = value;
	}
	
	/**
	 * Sets the value using the named tag's name as the index.
	 * Example:
	 * ---
	 * auto compound = new Compound("");
	 * compound[] = new String("test", "value");
	 * assert(compound["test"] == "value");
	 * ---
	 */
	public @safe void opIndexAssign(NamedTag value) {
		this.value[value.name] = value;
	}
	
	/**
	 * Removed the given index from the array, if set.
	 * Example:
	 * ---
	 * auto compound = new Compound("", ["string", new String("test")]);
	 * assert("string" in compound);
	 * compound.remove("string");
	 * assert("string" !in compound);
	 * ---
	 */
	public @safe void remove(string index) {
		this.value.remove(index);
	}
	
	/// Gets the length of the array (or the number of NamedTags in it).
	public final pure nothrow @property @safe @nogc size_t length() {
		return this.value.length;
	}
	
	/// Checks whether or not the array is empty (its length is equal to 0).
	public final pure nothrow @property @safe @nogc bool empty() {
		return this.length == 0;
	}
	
	/**
	 * Gets the keys (indexes of the array).
	 * Example:
	 * ---
	 * assert(new Compound("", ["a": new String("a"), "b": new String("b")]).keys == ["a", "b"]);
	 * ---
	 */
	public @property @trusted string[] keys() {
		return this.value.keys;
	}

	/**
	 * Creates an exact duplicate of the tag.
	 */
	public @property Compound dup() {
		return new Compound(this.name, this.value.values);
	}
	
	public override bool opEquals(Object object) {
		if(cast(Compound)object) {
			Compound compound = cast(Compound)object;
			return this.name == compound.name && this.opEquals(compound.value);
		}
		return false;
	}
	
	public override bool opEquals(NamedTag[string] tags) {
		if(tags.length != this.length) return false;
		foreach(NamedTag tag ; tags) {
			if(tag.name !in this.value || this[tag.name] != tag) return false;
		}
		return true;
	}
	
}

unittest {
	
	Compound compound = new Compound();
	
	compound[] = new ListOf!Byte("test");
	assert(compound.has!List("test"));
	assert(compound.get!List("test") == compound.get!(ListOf!Byte)("test"));
	
}

/**
 * Compound with some default varibales for an easier and fancier use.
 * Example:
 * ---
 * alias TwoStrings = DefinedCompound!(String, "a", String, "b");
 * auto ts = new TwoStrings("");
 * ts.a = new String("test");
 * assert(ts.a == "test");
 * assert(ts.b is null);
 * ---
 */
template DefinedCompound(E...) if(isValidDefinedCompound!E) {
	
	class DefinedCompound : Compound {
		
		public @safe this(F...)(F args) {
			super(args);
		}
		
		mixin((){
			string get, set, type;
			foreach(size_t index, e; E) {
				static if(index % 2 == 0) {
					type = e.stringof;
					get ~= "public @property @safe " ~ type ~ " ";
					set ~= "public @property @safe " ~ type ~ " ";
				} else {
					get ~= e ~ "(){ return this.has!(" ~ type ~ ")(\"" ~ e ~ "\") ? this.get!(" ~ type ~ ")(\"" ~ e ~ "\") : null; }";
					set ~= e ~ "(" ~ type ~ " value){ this[\"" ~ e ~ "\"] = value; return value; }";
				}
			}
			return get ~ set;
		}());
		
	}
	
}

private bool isValidDefinedCompound(E...)() {
	string[] keys;
	foreach(size_t index, F; E) {
		static if(index % 2 == 0) {
			static if(!is(F == class) || !is(F : NamedTag) || isAbstractClass!F) return false;
		} else {
			static if(!is(typeof(F) == string) && !is(typeof(F) == immutable(string))) return false;
			else {
				if(keys.canFind(F)) return false;
				else keys ~= F;
			}
		}
	}
	return true;
}
