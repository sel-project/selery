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
module sel.world.particle;

import sel.block.block;
import sel.math.vector : EntityPosition;
import sel.util.color : Color;

final class Particles {

	@disable this();

	public static alias Bubble = SimpleParticle!(1, 4);
	public static alias Critical = SimpleParticle!(2, 9);
	public static alias Smoke = SimpleParticle!(3, 11);
	public static alias Explosion = SimpleParticle!(4, 0);
	public static alias WhiteSmoke = SimpleParticle!(5, 11);
	public static alias Flame = SimpleParticle!(6, 26);
	public static alias Lava = SimpleParticle!(7, 27);
	public static alias LargeSmoke = SimpleParticle!(8, 12);
	public static alias Redstone = SimpleParticle!(9, 30);
	public static alias ItemBreak = SimpleParticle!(10, 36);
	public static alias SnowballPoof = SimpleParticle!(11, 31);
	public static alias LargeExplosion = SimpleParticle!(12, 1);
	public static alias HugeExplosion = SimpleParticle!(13, 2);
	public static alias MobFlame = SimpleParticle!(14, 26);
	public static alias Heart = SimpleParticle!(15, 34);
	public static alias Terrain = SimpleParticle!(16, 28);
	public static alias TownAura = SimpleParticle!(17, 22);
	public static alias Portal = SimpleParticle!(18, 24);
	public static alias Splash = SimpleParticle!(19, 5);
	public static alias Wake = SimpleParticle!(20, 6);
	public static alias DripWater = SimpleParticle!(21, 18);
	public static alias DripLava = SimpleParticle!(22, 19);
	public static alias Dust = SimpleParticle!(23, 0);				//PE ONLY
	public static alias MobSpell = SimpleParticle!(24, 15);
	public static alias MobSpellAmbient = SimpleParticle!(25, 16);
	public static alias MobSpellInstantaneous = SimpleParticle!(26, 14);
	public static alias Ink = SimpleParticle!(27, 0);				// PE ONLY
	public static alias Slime = SimpleParticle!(28, 33);
	public static alias RainSplash = SimpleParticle!(29, 39);
	public static alias AngryVillager = SimpleParticle!(30, 20);
	public static alias HappyVillager = SimpleParticle!(31, 21);
	public static alias EnchantmentTable = SimpleParticle!(32, 25);
	public static alias Note = SimpleParticle!(33, 23);

	public static alias Shoot = SimpleParticle!(2000, 0);					// PE ONLY
	public static alias Destroy = SimpleParticle!(2001, 37);
	//public static alias Splash = SimpleParticle!(2002, 38);
	public static alias EyeDespawn = SimpleParticle!(2003, 0);				// PE ONLY
	public static alias Spawn = SimpleParticle!(2004, 0);					// PE ONLY

}

abstract class Particle {

	public abstract @property @safe @nogc ushort peid();

	public abstract @property @safe @nogc uint pcid();

	public abstract @property @safe @nogc EntityPosition position();

	public abstract @property @safe @nogc uint count();

	public uint pedata;

	public uint pcdata;
	public uint[] pcmoredata;

}

class SimpleParticle(ushort pe, uint pc) : Particle {

	private EntityPosition n_position;
	private uint n_count;

	public @safe @nogc this(EntityPosition position, uint count=1) {
		this.n_position = position;
		this.n_count = count;
	}

	public @safe this(EntityPosition position, Color color, uint count=1) {
		this(position, count);
		this.pedata = this.pcdata = color.rgb;
	}
	
	/*public @safe this(EntityPosition position, BlockData block, uint count=1) {
		this(position);
		this.pedata = block.ids.pe | (block.metas.pe << 12);
		this.pcmoredata = [block.ids.pc | (block.metas.pc << 12)];
	}
	
	public @safe this(EntityPosition position, Block block, uint count=1) {
		this(position, block.data, count);
	}*/

	public override @property @safe @nogc ushort peid() {
		return pe;
	}

	public override @property @safe @nogc uint pcid() {
		return pc;
	}

	public override @property @safe @nogc EntityPosition position() {
		return this.n_position;
	}

	public override @property @safe @nogc uint count() {
		return this.n_count;
	}

}
