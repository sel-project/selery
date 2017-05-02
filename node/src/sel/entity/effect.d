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

import com.sel : tick_t;

import sel.entity.human : Human;
import sel.entity.living : Living;
import sel.event.world.damage;
import sel.event.world.entity : EntityHealEvent;
import sel.player.player : isPlayerInstance;

static import sul.effects;
public import sul.effects : Effects;

class Effect {

	public enum tick_t UNLIMITED = int.max / 20;

	public static Effect fromId(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker=null) {
		switch(effect.minecraft.id) {
			case Effects.speed.minecraft.id: return new SpeedChange(effect, victim, level, duration, attacker);
			case Effects.slowness.minecraft.id: return new SpeedChange(effect, victim, level, duration, attacker);
			case Effects.instantHealth.minecraft.id: return new InstantHealth(effect, victim, level, attacker);
			case Effects.instantDamage.minecraft.id: return new InstantDamage(effect, victim, level, attacker);
			case Effects.regeneration.minecraft.id: return new Regeneration(effect, victim, level, duration, attacker);
			case Effects.invisibility.minecraft.id: return new Invisibility(effect, victim, level, duration, attacker);
			case Effects.hunger.minecraft.id: return new Hunger(effect, victim, level, duration, attacker);
			case Effects.poison.minecraft.id: return new Poison(effect, victim, level, duration, attacker);
			case Effects.wither.minecraft.id: return new Wither(effect, victim, level, duration, attacker);
			//TODO health boost
			//TODO absorption
			case Effects.saturation.minecraft.id: return new Saturation(effect, victim, level, duration, attacker);
			case Effects.levitation.minecraft.id: return new Levitation(effect, victim, level, duration, attacker);
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

	public final pure nothrow @property @safe @nogc ubyte id() {
		return this.effect.minecraft;
	}

	public final pure nothrow @property @safe @nogc Living victim() {
		return this.n_victim;
	}

	public final pure nothrow @property @safe @nogc Living attacker() {
		return this.n_attacker;
	}

	public pure nothrow @property @safe @nogc bool instant() {
		return false;
	}

	// called after the effect is added
	public void onStart() {}

	// called after the effect id removed
	public void onStop() {}

	public void tick() {
		this.ticks++;
	}

	public final pure nothrow @property @safe @nogc bool finished() {
		return this.ticks >= this.duration;
	}

	public bool opEquals(sul.effects.Effect e) {
		return this.id == e.minecraft.id;
	}

	alias effect this;

}

class SpeedChange : Effect {

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}

	public override void onStart() {
		this.victim.recalculateSpeed();
	}

	public override void onStop() {
		this.victim.recalculateSpeed();
	}

}

abstract class InstantEffect : Effect {

	public this(sul.effects.Effect, Living victim, ubyte level, Living attacker) {
		super(effect, victim, level, 0, attacker);
	}

	public final override pure nothrow @property @safe @nogc bool instant() {
		return true;
	}

	public override void onStart() {
		this.apply();
	}

	protected abstract void apply();

}

class InstantHealth : InstantEffect {
	
	public this(sul.effects.Effect, Living victim, ubyte level, Living attacker) {
		super(effect, victim, level, attacker);
	}
	
	protected override void apply() {
		//TODO heal entity (or damage undeads)
	}
	
}

class InstantDamage : InstantEffect {
	
	public this(sul.effects.Effect, Living victim, ubyte level, Living attacker) {
		super(effect, victim, level, attacker);
	}
	
	protected override void apply() {
		//TODO damage entity (or heal undeads)
	}
	
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

class Regeneration : RepetitionEffect!([50, 25, 12, 6, 3, 1]) {

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}

	public override void onRepeat() {
		this.victim.heal(new EntityHealEvent(this.victim, 1));
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
			this.victim.attack(new EntityDamageByPoisonEvent(this.victim)); //TODO thrown by player
		}
	}
	
}

class Wither : RepetitionEffect!([40, 20, 10, 5, 2, 1]) {
	
	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
	}
	
	public override void onRepeat() {
		this.victim.attack(new EntityDamageByWitherEffectEvent(this.victim)); //TODO thrown by player
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

	private void delegate() apply;
	private immutable double distance;

	public this(sul.effects.Effect effect, Living victim, ubyte level, tick_t duration, Living attacker) {
		super(effect, victim, level, duration, attacker);
		this.distance = .9 * this.levelFromOne / 20;
		if(!isPlayerInstance(victim)) {
			this.apply = &this.move;
		} else {
			this.apply = &this.doNothing;
		}
	}

	public override void tick() {
		super.tick();
		this.apply();
	}

	private void move() {
		//TODO check flying and underwater
		//TODO do not move into a block
		this.victim.move(this.victim.position + [0, this.distance, 0]);
	}

	private void doNothing() {}

}
