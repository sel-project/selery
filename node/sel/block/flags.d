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
/// DDOC_EXCLUDE
module sel.block.flags;

import common.sel;

import sel.block.block : Shapes;

struct ShapeFlag {
	
	public float[] shape;
	
}

struct SolidFlag {
	
	public immutable double blastResistance;
	
	public pure nothrow @safe @nogc this(double br) {
		this.blastResistance = br;
	}
	
}

struct ToolFlag {

	public ubyte type;
	public ubyte material;

}

struct HardnessFlag {

	public double hardness;

}

public pure nothrow @property @safe @nogc auto ID(ubyte id)() { return bytegroup(id, id); }

public pure nothrow @property @safe @nogc auto IDS(ubyte pe, ubyte pc)() { return bytegroup(pe, pc); }

public pure nothrow @property @safe @nogc auto META(ubyte id)() { return bytegroup(id, id); }

public pure nothrow @property @safe @nogc auto METAS(ubyte pe, ubyte pc)() { return bytegroup(pe, pc); }

public nothrow @property @safe auto SHAPE(float[] shape) { return ShapeFlag(shape); }

public nothrow @property @safe auto SHAPELESS() { return ShapeFlag([]); }

public nothrow @property @safe auto FULLSHAPE() { return ShapeFlag(Shapes.FULL); }

public pure nothrow @property @safe @nogc auto SOLID(double br)() { return SolidFlag(br); }

public pure nothrow @property @safe @nogc auto TOOL(ubyte type, ubyte material)() { return ToolFlag(type, material); }

public pure nothrow @property @safe @nogc auto HARDNESS(double hardness)() { return HardnessFlag(hardness); }

public enum RANDOM_TICK = "randomTick";

public enum GRAVITY = "gravity";

public enum FLAMMABLE = "flammable";

public enum INSTANT_BREAKING = "instantBreaking";

public enum REPLACEABLE = "replaceable";

public enum NO_FALL_DAMAGE = "noFallDamage";

public enum SILK_TOUCH = "silkTouch";

public enum FORTUNE = "fortune";

public enum CROP = "crop";
