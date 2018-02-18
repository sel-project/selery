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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/color.d, selery/util/color.d)
 */
module selery.util.color;

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
	public pure nothrow @safe @nogc this(ubyte r, ubyte g, ubyte b, ubyte a=0xFF) {
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
	public pure nothrow @property @safe @nogc uint rgb() {
		return (this.r << 16) | (this.g << 8) | this.b;
	}

	/// ditto
	public pure nothrow @property @safe @nogc uint rgba() {
		return (this.rgb << 8) | a;
	}

	/// ditto
	public pure nothrow @property @safe @nogc uint argb() {
		return (a << 24) | this.rgb;
	}

	/**
	 * Checks if the colour is completely transparent (with
	 * the alpha channel equals to 0).
	 * Example:
	 * ---
	 * assert(!new Color(0, 0, 0, 1).transparent);
	 * assert(Colors.TRANSPARENT.transparent);
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool transparent() {
		return this.alpha == 0;
	}

	/**
	 * Sets the colour as transparent (with alpha = 0) or
	 * opaque (with alpha = 255).
	 */
	public pure nothrow @property @safe @nogc bool transparent(bool transparent) {
		return (this.alpha = (transparent ? 0 : 255)) == 0;
	}

	/**
	 * Compares two colours.
	 * Returns: true if red, green, blue an alpha are equals, false otherwise
	 */
	public override bool opEquals(Object o) {
		if(cast(Color)o) {
			Color c = cast(Color)o;
			return this.r == c.r && this.g == c.g && this.b == c.b && this.a == c.a;
		}
		return false;
	}

	/**
	 * Converts and hexadecimal representation of a colour into
	 * a Color object.
	 * Returns: a Color object or null if the string's length is invalid
	 * Throws:
	 * 		ConvException if one of the string is not an hexadecimal number
	 * Example:
	 * ---
	 * assert(Color.fromString("00CC00").green == 204);
	 * assert(Color.fromString("123456").rgb == 0x123456);
	 * assert(Color.fromString("01F") == Color.fromString("0011FF"));
	 * ---
	 */
	public static pure @safe Color fromString(string c) {
		if(c.length == 6) {
			return new Color(to!ubyte(c[0..2], 16), to!ubyte(c[2..4], 16), to!ubyte(c[4..6], 16));
		} else if(c.length == 3) {
			return fromString([c[0], c[0], c[1], c[1], c[2], c[2]].idup);
		} else {
			return null;
		}
	}

	/**
	 * Converts an rgb-encoded integer to a Color.
	 * Example:
	 * ---
	 * assert(Color.fromRGB(0x0000FF).blue == 255);
	 * assert(Color.fromRGB(0x111111).green == 17);
	 * ---
	 */
	public static pure nothrow @safe Color fromRGB(uint c) {
		return new Color((c >> 16) & 255, (c >> 8) & 255, c & 255);
	}

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
	 * if(object.color is null || object.color.transparent) {
	 *    writeln("There's no colour!");
	 * }
	 * ---
	 */
	public @property @safe Color color();

	/**
	 * Sets the colour for this object.
	 * Example:
	 * ---
	 * if(object.color is null) {
	 *    object.color = Color.fromString("003311");
	 * }
	 * ---
	 */
	public @property @safe Color color(Color color);

}

/**
 * Useful collection of colours to be used for dying, choosing
 * block's colours and colouring maps.
 * Example:
 * ---
 * leatherHelmet.color = Colors.cocoa;
 * 
 * world[0, 64, 0] = Blocks.wool[Colors.Wool.brown];
 * ---
 */
final class Colors {

	@disable this();

	public static const(Color) transparent = new Color(0, 0, 0, 0);

	public static const(Color) black = Color.fromRGB(0x191919);
	public static const(Color) red = Color.fromRGB(0x993333);
	public static const(Color) green = Color.fromRGB(0x667F33);
	public static const(Color) cocoa = Color.fromRGB(0x664C33);
	public static const(Color) lapis = Color.fromRGB(0x334CB2);
	public static const(Color) purple = Color.fromRGB(0x7F3FB2);
	public static const(Color) cyan = Color.fromRGB(0x4C7F99);
	public static const(Color) lightGray = Color.fromRGB(0x999999);
	public static const(Color) gray = Color.fromRGB(0x4C4C4C);
	public static const(Color) pink = Color.fromRGB(0xF27FA5);
	public static const(Color) lime = Color.fromRGB(0x7FCC19);
	public static const(Color) yellow = Color.fromRGB(0xE5E533);
	public static const(Color) blue = Color.fromRGB(0x6699D8);
	public static const(Color) magenta = Color.fromRGB(0xB24CD8);
	public static const(Color) orange = Color.fromRGB(0xD87F33);
	public static const(Color) white = Color.fromRGB(0xFFFFFF);

	enum Wool : ubyte {

		white = 0,
		orange = 1,
		magenta = 2,
		lightBlue = 3,
		yellow = 4,
		lime = 5,
		pink = 6,
		gray = 7,
		lightGray = 8,
		cyan = 9,
		purple = 10,
		blue = 11,
		brown = 12,
		green = 13,
		red = 14,
		black = 15

	}

	alias Carpet = Wool;

	alias Sheep = Wool;

	alias StainedClay = Wool;

	alias StainedGlass = Wool;

}
