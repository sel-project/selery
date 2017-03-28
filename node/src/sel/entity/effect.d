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

import common.sel;

import sel.entity.human : Human;
import sel.entity.living : Living;

static import sul.effects;
import sul.effects : _ = Effects;

enum Effects : sul.effects.Effect {

	speed = _.SPEED,
	slowness = _.SLOWNESS,
	haste = _.HASTE,
	miningFatigue = _.MINING_FATIGUE,
	strength = _.STRENGTH,
	instantHealth = _.INSTANT_HEALTH,
	instantDamage = _.INSTANT_DAMAGE,
	jumpBoost = _.JUMP_BOOST,
	nausea = _.NAUSEA,
	regeneration = _.REGENERATION,
	resistance = _.RESISTANCE,
	fireResistance = _.FIRE_RESISTANCE,
	waterBreathing = _.WATER_BREATHING,
	invisibility = _.INVISIBILITY,
	blindness = _.BLINDNESS,
	nightVision = _.NIGHT_VISION,
	hunger = _.HUNGER,
	weakness = _.WEAKNESS,
	poison = _.POISON,
	wither = _.WITHER,
	healthBoost = _.HEALTH_BOOST,
	absorption = _.ABSORPTION,
	saturation = _.SATURATION,
	glowing = _.GLOWING,
	levitation = _.LEVITATION,
	luck = _.LUCK,
	badLuck = _.BAD_LUCK,

}

class Effect {

	public static Effect fromId(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker=null) {
		switch(effect.id) {
			case _.INSTANT_HEALTH.id: return new InstantHealth(effect, victim, level, attacker);
			case _.INSTANT_DAMAGE.id: return new InstantDamage(effect, victim, level, attacker);
			case _.REGENERATION.id: return new Regeneration(effect, victim, level, duration, attacker);
			case _.INVISIBILITY.id: return new Invisibility(effect, victim, level, duration, attacker);
			case _.HUNGER.id: return new Hunger(effect, victim, level, duration, attacker);
			case _.POISON.id: return new Poison(effect, victim, level, duration, attacker);
			case _.WITHER.id: return new Wither(effect, victim, level, duration, attacker);
			case _.SATURATION.id: return new Saturation(effect, victim, level, duration, attacker);
			case _.LEVITATION.id: return new Levitation(effect, victim, level, duration, attacker);
			default: return new Effect(effect, victim, level, duration, attacker);
		}
	}

	public static Effect fromId(sul.effects.Effect effect, Living victim, ubyte level, Living attacker=null) {
		return fromId(effect, victim, level, 30, attacker);
	}

	//TODO from string

	//TODO from minecraft

	//TODO from pocket

	public const sul.effects.Effect effect;

	private Living n_victim;
	private Living n_attacker;

	public immutable ubyte level;
	public immutable uint levelFromOne;

	public immutable tick_t duration;
	protected tick_t ticks = 0;

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		this.effect = effect;
		this.n_victim = victim;
		this.n_attacker = attacker;
		this.level = level;
		this.levelFromOne = 1 + level;
		this.duration = duration * 20;
	}

	public final pure nothrow @property @safe @nogc Living victim() {
		return this.n_victim;
	}

	public final pure nothrow @property @safe @nogc Living attacker() {
		return this.n_attacker;
	}

	public void onStart() {}

	public void onStop() {}

	public void tick() {
		this.ticks++;
	}

	public final pure nothrow @property @safe @nogc bool finished() {
		return this.ticks >= this.duration;
	}

	public bool opEquals(sul.effects.Effect e) {
		return this.id == e.id;
	}

	alias effect this;

}

abstract class InstantEffect : Effect {

	public this(sul.effects.Effect, Living victim, ubyte level, Living attacker) {
		super(effect, victim, level, 0, attacker);
	}

	public abstract void apply();

}

abstract class RepetitionEffect(tick_t[] repetitions) : Effect {
	
	protected immutable tick_t repeat;
	
	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
		static if(repetitions.length > 1) {
			this.repeat = level < repetitions.length ? repetitions[level] : repetitions[$-1];
		} else {
			this.repeat = repetitions[0];
		}
	}
	
	public override void tick() {
		super.tick();
		if(this.ticks % this.repeat == 0) {
			this.onRepeat();
		}
	}
	
	public abstract void onRepeat();
	
}

class InstantHealth : InstantEffect {
	
	public this(sul.effects.Effect, Living victim, ubyte level, Living attacker) {
		super(effect, victim, level, attacker);
	}
	
	public override void apply() {
		//TODO heal entity (or damage undeads)
	}
	
}

class InstantDamage : InstantEffect {
	
	public this(sul.effects.Effect, Living victim, ubyte level, Living attacker) {
		super(effect, victim, level, attacker);
	}
	
	public override void apply() {
		//TODO damage entity (or heal undeads)
	}
	
}

class Regeneration : RepetitionEffect!([50, 25, 12, 6, 3, 1]) {

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}

	public override void onRepeat() {
		//TODO call event and heal
	}

}

class Invisibility : Effect {

	private bool invisible, show_nametag;

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}

	public override void onStart() {
		this.invisible = this.victim.invisible;
		this.show_nametag = this.victim.showNametag;
		this.victim.invisible = true;
		this.victim.showNametag = false;
	}

	public override void onStop() {
		this.victim.invisible = this.invisible;
		this.victim.showNametag = this.show_nametag;
	}

}

class Hunger : Effect {

	private Human human;
	private immutable float exhaustion;

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
		this.human = cast(Human)victim; //TODO assert this
		this.exhaustion = .005f * levelFromOne;
	}

	public override void tick() {
		super.tick();
		this.human.exhaust(this.exhaustion);
	}

}

class Poison : RepetitionEffect!([25, 12, 6, 3, 1]) {
	
	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}
	
	public override void onRepeat() {
		if(this.victim.health > 1) {
			//TODO call event and damage
		}
	}
	
}

class Wither : RepetitionEffect!([40, 20, 10, 5, 2, 1]) {
	
	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}
	
	public override void onRepeat() {
		//TODO call event and damage
	}
	
}

class Saturation : Effect {

	private Human human;
	private immutable uint food;
	private immutable float saturation;

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
		this.human = cast(Human)victim; //TODO assert this
		this.food = this.levelFromOne;
		this.saturation = this.levelFromOne * 2;
	}

	public override void tick() {
		super.tick();
		if(this.human.hunger < 20) this.human.hunger = this.human.hunger + this.food;
		this.human.saturate(this.saturation);
	}

}

class Levitation : Effect {

	private immutable double distance;

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
		this.distance = .9 * this.levelFromOne / 20;
	}

	public override void tick() {
		super.tick();
		//TODO check flying and underwater
		//TODO do not move into a block
		this.victim.move(this.victim.position + [0, this.distance, 0]);
	}

}
