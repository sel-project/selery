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
module sel.entity.effect;

import std.conv : to;
import std.typecons : Tuple;

import sel.entity.living : Living;
import sel.util.color : Color;
import sel.util.util : roman;

alias EffectInfo = Tuple!(ubyte, "id", uint, "duration", ubyte, "level", float, "probability");

public @safe EffectInfo effectInfo(ubyte id, uint duration, ubyte level=Effect.BASE_LEVEL, float prob=1) {
	return EffectInfo(id, duration, level, prob);
}

public @safe EffectInfo effectInfo(ubyte id, uint duration, string level, float prob=1) {
	return EffectInfo(id, duration, (level.roman - 1) & 255, prob);
}

public @property @safe EffectInfo noEffect() {
	return effectInfo(0, 0, 0);
}

/** effects identifiers as unsigned bytes */
enum Effects : ubyte {

	SPEED = 1,
	SLOWNESS = 2,
	HASTE = 3,
	MINING_FATIGUE = 4,
	STRENGTH = 5,
	HEALING = 6,
	HARMING = 7,
	JUMP = 8,
	NAUSEA = 9,
	REGENERATION = 10,
	RESISTANCE = 11,
	FIRE_RESISTANCE = 12,
	WATER_BREATHING = 13,
	INVISIBILITY = 14,
	BLINDNESS = 15,
	NIGHT_VISION = 16,
	HUNGER = 17,
	WEAKNESS = 18,
	POISON = 19,
	WITHER = 20,
	HEALTH_BOOST = 21,
	ABSORPTION = 22,
	SATURATION = 23

}

class Effect {
	
	public static immutable ubyte NO_TIMING = 0;
	
	public static immutable ubyte BASE_LEVEL = 0;
	
	private static EffectReference[ubyte] reference;
	
	public static this() {
		@safe uint function(ubyte) regeneration = function(ubyte level){
			switch(level) {
				case 0: return 50;
				case 1: return 25;
				case 2: return 12;
				case 3: return 6;
				case 4: return 3;
				default: return 1;
			}
		};
		//can not call regeneration(level+1) for this 2 functions :(
		@safe uint function(ubyte) poison = function(ubyte level){
			switch(level) {
				case 0: return 25;
				case 1: return 12;
				case 2: return 6;
				case 3: return 3;
				default: return 1;
			}
		};
		@safe uint function(ubyte) wither = function(ubyte level){
			switch(level) {
				case 0: return 40;
				case 1: return 12;
				case 2: return 6;
				case 3: return 3;
				default: return 1;
			}
		};
		@safe uint function(ubyte) every_tick = function(ubyte level){ return 1; };
		reference[Effects.SPEED] = EffectReference("moveSpeed", 124, 175, 198, false);
		reference[Effects.SLOWNESS] = EffectReference("moveSlowdown", 90, 108, 129, false);
		reference[Effects.HASTE] = EffectReference("digSpeed", 217, 192, 67, true);
		reference[Effects.MINING_FATIGUE] = EffectReference("digSlowDown", 74, 66, 23, true);
		reference[Effects.STRENGTH] = EffectReference("damageBoost", 147, 36, 35, false);
		reference[Effects.HEALING] = EffectReference("heal", 248, 36, 35, false);
		reference[Effects.HARMING] = EffectReference("harm", 67, 10, 9, false);
		reference[Effects.JUMP] = EffectReference("jump", 34, 255, 76, true);
		reference[Effects.NAUSEA] = EffectReference("confusion", 85, 29, 74, true);
		reference[Effects.REGENERATION] = EffectReference("regeneration", 205, 92, 171, false, regeneration);
		reference[Effects.RESISTANCE] = EffectReference("resistance", 153, 69, 58, false);
		reference[Effects.FIRE_RESISTANCE] = EffectReference("fireResistance", 228, 154, 58, false);
		reference[Effects.WATER_BREATHING] = EffectReference("waterBreathing", 46, 82, 153, false);
		reference[Effects.INVISIBILITY] = EffectReference("invisibility", 127, 131, 146, false);
		reference[Effects.BLINDNESS] = EffectReference("blindness", 191, 192, 192, true);
		reference[Effects.NIGHT_VISION] = EffectReference("nightVision", 0, 0, 139, true);
		reference[Effects.HUNGER] = EffectReference("hunger", 46, 139, 87, true, every_tick);
		reference[Effects.WEAKNESS] = EffectReference("weakness", 72, 77, 72, false);
		reference[Effects.POISON] = EffectReference("poison", 78, 147, 49, false, poison);
		reference[Effects.WITHER] = EffectReference("wither", 53, 42, 39, false, wither);
		reference[Effects.HEALTH_BOOST] = EffectReference("healthBoost", 248, 125, 35, false);
		reference[Effects.ABSORPTION] = EffectReference("absorption", 36, 107, 251, false);
		reference[Effects.SATURATION] = EffectReference("saturation", 255, 0, 255, true, every_tick);
	}
	
	public static @safe bool exists(ubyte id) {
		return (id in reference) ? true : false;
	}
	
	public static @safe string effectName(ubyte id) {
		if(id in reference) return reference[id].name;
		else return "";
	}
	
	public static @safe Color effectColor(ubyte id) {
		if(id in reference) return reference[id].color;
		else return null;
	}
	
	public static @safe bool playerOnly(ubyte id) {
		if(id in reference) return reference[id].player;
		else return false;
	}
	
	private static @safe uint function(ubyte) @safe timingFunction(ubyte id) {
		if(id in reference) return reference[id].timing;
		else return null;
	}

	public immutable ubyte id;
	
	//the duration is measured in ticks
	//the tick is measured by the counter (called by Entity::onUpdate)
	private uint m_duration;
	private uint counter;
	
	//used for the effect that repeat every x ticks
	public bool n_repeat = false;
	private uint repeat_at;
	
	//where 0 is a level 1 effect (0-255)
	public immutable ubyte level;
	
	private ulong repeat_at_tick;
	
	//who throw the splash potion or generally who cause the effect
	private Living n_thrower;
	
	public @safe this(ubyte effect, uint duration, ubyte level=BASE_LEVEL, Living thrower=null) {
		if(!exists(effect)) throw new Exception(to!string(effect) ~ " is not a valid effect id");
		this.id = effect;
		this.m_duration = this.counter = (duration * 20); // duration is passed in seconds
		if((this.repeat_at = timingFunction(effect)(level)) > NO_TIMING) {
			this.n_repeat = true;
		}
		this.level = level;
		this.n_thrower = thrower;
	}

	/// ditto
	public @safe this(ubyte effect, uint duration, string level, Living thrower=null) {
		this(effect, duration, to!ubyte(level.roman - 1), thrower);
	}

	/**
	 * Returns: the total duration of the effect in ticks
	 */
	public @property @safe @nogc uint duration() {
		return this.m_duration;
	}
	
	public @safe @nogc uint durate() {
		return --this.counter;
	}
	
	public @property @safe @nogc ubyte levelFromOne() {
		return (this.level + 1) & 255;
	}
	
	public @safe void setStartTick(ulong tick) {
		if(this.repeat) this.repeat_at_tick = tick % this.repeat_at;
	}
	
	public @property @safe @nogc bool repeat() {
		return this.n_repeat;
	}

	public @property @safe bool repeat(ulong tick) {
		return tick % this.repeat_at == this.repeat_at_tick;
	}
	
	public @property @safe @nogc Living thrower() {
		return this.n_thrower;
	}
	
	public override @safe string toString() {
		return "Effect(" ~ effectName(this.id) ~ "," ~ to!string(this.levelFromOne()) ~ ")";
	}
	
	struct EffectReference {
		
		public immutable string name;
		public immutable string identifier;
		public Color color;
		public immutable bool player;
		private @safe uint function(ubyte) n_timing;
		
		public @safe this(string name, ubyte r, ubyte g, ubyte b, bool player) {
			this(name, new Color(r, g, b), player, function(ubyte level) @safe { return cast(uint)NO_TIMING; });
		}
		public @safe this(string name, ubyte r, ubyte g, ubyte b, bool player, uint function(ubyte) @safe timing) {
			this(name, new Color(r, g, b), player, timing);
		}
		public @safe this(string name, Color color, bool player, uint function(ubyte) @safe timing) {
			this.name = name;
			this.identifier = "%potion." ~ name;
			this.color = color;
			this.player = player;
			this.n_timing = timing;
		}
		
		public @property @safe @nogc uint function(ubyte) @safe timing() {
			return this.n_timing;
		}
		
	}
	
}

enum Potions : EffectInfo {
	
	// EXTENDED = duration extended
	// PLUS = level 1 (default is 0)
	
	WATER_BOTTLE = noEffect,
	MUNDANE = noEffect,
	MUNDANE_EXTENDED = noEffect,
	THICK = noEffect,
	AWKWARD = noEffect,

	NIGHT_VISION = effectInfo(Effects.NIGHT_VISION, 180, "I"),
	NIGHT_VISION_EXTENDED = effectInfo(Effects.NIGHT_VISION, 480, "I"),
	INVISIBILITY = effectInfo(Effects.INVISIBILITY, 180, "I"),
	INVISIBILITY_EXTENDED = effectInfo(Effects.INVISIBILITY, 480, "I"),
	LEAPING = effectInfo(Effects.JUMP, 180, "I"),
	LEAPING_EXTENDED = effectInfo(Effects.JUMP, 480, "I"),
	LEAPING_PLUS = effectInfo(Effects.JUMP, 90, "II"),
	FIRE_RESISTANCE = effectInfo(Effects.FIRE_RESISTANCE, 180, "I"),
	FIRE_RESISTANCE_EXTENDED = effectInfo(Effects.FIRE_RESISTANCE, 480, "I"),
	SPEED = effectInfo(Effects.SPEED, 180, "I"),
	SPEED_EXTENDED = effectInfo(Effects.SPEED, 480, "I"),
	SPEED_PLUS = effectInfo(Effects.SPEED, 90, "II"),
	SLOWNESS = effectInfo(Effects.SLOWNESS, 60, "I"),
	SLOWNESS_EXTENDED = effectInfo(Effects.SLOWNESS, 240, "I"),
	WATER_BREATHING = effectInfo(Effects.WATER_BREATHING, 180, "I"),
	WATER_BREATHING_EXTENDED = effectInfo(Effects.WATER_BREATHING, 480, "I"),
	HEALING = effectInfo(Effects.HEALING, 0, "I"),
	HEALING_PLUS = effectInfo(Effects.HEALING, 0, "II"),
	HARMING = effectInfo(Effects.HARMING, 0, "I"),
	HARMING_PLUS = effectInfo(Effects.HARMING, 0, "II"),
	POISON = effectInfo(Effects.POISON, 45, "I"),
	POISON_EXTENDED = effectInfo(Effects.POISON, 120, "I"),
	POISON_PLUS = effectInfo(Effects.POISON, 22, "II"),
	REGENERATION = effectInfo(Effects.REGENERATION, 45, "I"),
	REGENERATION_EXTENDED = effectInfo(Effects.REGENERATION, 120, "I"),
	REGENERATION_PLUS = effectInfo(Effects.REGENERATION, 22, "II"),
	STRENGTH = effectInfo(Effects.STRENGTH, 180, "I"),
	STRENGTH_EXTENDED = effectInfo(Effects.STRENGTH, 480, "I"),
	STRENGTH_PLUS = effectInfo(Effects.STRENGTH, 90, "II"),
	WEAKNESS = effectInfo(Effects.WEAKNESS, 90, "I"),
	WEAKNESS_EXTENDED = effectInfo(Effects.WEAKNESS, 240, "I")
	
}
