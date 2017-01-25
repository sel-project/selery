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
module sel.util.color;

import std.conv : to;

/**
 * Container for an rgba colour.
 * Example:
 * ---
 * Color c = new Color(255, 0, 0);
 * c.blue = 255;
 * assert(c == new Color(255, 0, 255));
 * ---
 */
class Color {

	public ubyte r, g, b, a;

	alias red = this.r;
	alias green = this.g;
	alias blue = this.b;
	alias alpha = this.a;

	/**
	 * Constructs a colour using rgb(a) values (in range 0..255).
	 * By default alpha is 0% transparent (255).
	 */
	public @safe @nogc this(ubyte r, ubyte g, ubyte b, ubyte a=0xFF) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

	/**
	 * Creates the average colour of the given one.
	 * Example:
	 * ---
	 * assert(new Color([new Color(200, 0, 0), new Color(0, 200, 0)]) == new Color(100, 100, 0));
	 * ---
	 */
	public @safe this(Color[] colors) {
		uint r, g, b, a;
		foreach(Color color ; colors) {
			r += color.r;
			g += color.g;
			b += color.b;
			a += color.a;
		}
		this.r = to!ubyte(r / colors.length);
		this.g = to!ubyte(g / colors.length);
		this.b = to!ubyte(b / colors.length);
		this.a = to!ubyte(a / colors.length);
	}

	/**
	 * Encodes the colour as an unsigned integer to
	 * be used in the network operations or to be saved.
	 */
	public @property @safe uint rgb() {
		return (this.r << 16) | (this.g << 8) | this.b;
	}

	/// ditto
	public @property @safe uint rgba() {
		return (this.rgb << 8) | a;
	}

	/// ditto
	public @property @safe uint argb() {
		return (a << 24) | this.rgb;
	}

	/**
	 * Checks if the colour is completely transparent (with
	 * the alpha channel equals to 0.
	 * Example:
	 * ---
	 * assert(!new Color(0, 0, 0, 1).transparent);
	 * assert(Colors.TRANSPARENT.transparent);
	 * ---
	 */
	public @property @safe @nogc bool transparent() {
		return this.alpha == 0;
	}

	/**
	 * Sets the colour as transparent (with alpha = 0) or
	 * opaque (with alpha = 255).
	 */
	public @property @safe @nogc bool transparent(bool transparent) {
		return (this.alpha = (transparent ? 0 : 255)) == 0;
	}

	/**
	 * Compares two colours.
	 * Returns: true if re, green, blue an alpha are equals, false otherwise
	 */
	public override @safe bool opEquals(Object o) {
		if(cast(Color)o) {
			Color c = cast(Color)o;
			return this.r == c.r && this.g == c.g && this.b == c.b && this.a == c.a;
		}
		return false;
	}

}

/**
 * Creates a colour from an encoded integer.
 * Params:
 * 		encoding = 4 characters indicating the encoding type (argb by default)
 * 		value = the encoded value
 * Example:
 * ---
 * assert(color!"argb"(255 << 24) == color!"rgba"(255));
 * ---
 */
public @safe Color color(string encoding="argb")(uint value) if(encoding.length == 4) {
	Color ret = new Color(0, 0, 0);
	foreach(uint index, char c; encoding) {
		ubyte v = (value >> ((3 - index) * 8)) & 255;
		switch(c) {
			case 'r':
				ret.r = v;
				break;
			case 'g':
				ret.g = v;
				break;
			case 'b':
				ret.b = v;
				break;
			case 'a':
				ret.a = v;
				break;
			default:
				assert(0, "Invalid colour: " ~ c);
		}
	}
	return ret;
}

unittest {

	assert(new Color(1, 88, 190, 1) == color!"rgba"(new Color(1, 88, 190, 1).rgba));

}

/**
 * Interface for object that have colours.
 * Example:
 * ---
 * if(cast(Colorable)object) {
 *    object.to!Colorable.color = Color(1, 100, 5);
 * }
 * ---
 */
interface Colorable {

	/**
	 * Gets the current colour.
	 * Example:
	 * ---
	 * if(col.color.transparent) {
	 *    d("There's no colour!");
	 * }
	 * ---
	 */
	public @property @safe Color color();

	/**
	 * Sets the colour for this object.
	 */
	public @property @safe Color color(Color color);

}

/**
 * Useful collection of colours to be used for dying, choosing
 * block's colours and colouring maps.
 * Example:
 * ---
 * leatherHelmet.color = Colors.COCOA;
 * 
 * world[0, 64, 0] = Blocks.WOOL[Colors.Wool.BROWN];
 * ---
 */
final class Colors {

	@disable this();

	public static const(Color) TRANSPARENT = new Color(0, 0, 0, 0);

	public static const(Color) BLACK = color(0x191919);
	public static const(Color) RED = color(0x993333);
	public static const(Color) GREEN = color(0x667F33);
	public static const(Color) COCOA = color(0x664C33);
	public static const(Color) LAPIS = color(0x334CB2);
	public static const(Color) PURPLE = color(0x7F3FB2);
	public static const(Color) CYAN = color(0x4C7F99);
	public static const(Color) LIGHT_GREY = color(0x999999);
	public static const(Color) GREY = color(0x4C4C4C);
	public static const(Color) PINK = color(0xF27FA5);
	public static const(Color) LIME = color(0x7FCC19);
	public static const(Color) YELLOW = color(0xE5E533);
	public static const(Color) BLUE = color(0x6699D8);
	public static const(Color) MAGENTA = color(0xB24CD8);
	public static const(Color) ORANGE = color(0xD87F33);
	public static const(Color) WHITE = color(0xFFFFFF);

	enum Wool : ubyte {

		WHITE = 0,
		ORANGE = 1,
		MAGENTA = 2,
		LIGHT_BLUE = 3,
		YELLOW = 4,
		LIME = 5,
		PINK = 6,
		GRAY = 7,
		LIGHT_GRAY = 8,
		CYAN = 9,
		PURPLE = 10,
		BLUE = 11,
		BROWN = 12,
		GREEN = 13,
		RED = 14,
		BLACK = 15

	}

	alias Carpet = Wool;

	alias Sheep = Wool;

	alias HardenedClay = Wool;

}
