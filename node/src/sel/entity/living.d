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
module sel.entity.living;

import std.conv : to;
import std.math : round, isNaN;

import common.sel;
import common.util : safe, call;

import sel.settings;
import sel.entity.effect : Effect, Effects;
import sel.entity.entity : Entity, Rotation;
import sel.entity.metadata;
import sel.event.world;
import sel.math.vector;
import sel.player.player : Player;
import sel.util.color : Color;
import sel.world.world : World;

static import sul.effects;

public class Living : Entity {

	protected Health m_health;
	protected Effect[ubyte] effects;

	public bool immortal = false;

	protected tick_t last_received_attack = 0;
	protected tick_t last_void_damage = 0;

	protected float m_body_yaw = Rotation.WEST;

	private float n_speed = .1;
	private float n_base_speed = .1;

	private tick_t despawn_after = 0;

	public this(World world, EntityPosition position, uint health, uint max) {
		super(world, position);
		this.m_health = Health(health, max);
	}

	public override void tick() {
		super.tick();
		//void
		if(this.position.y < -4 && this.last_void_damage + 10 < this.ticks) {
			this.last_void_damage = this.ticks;
			if(this.last_puncher is null) {
				this.attack(new EntityDamageByVoidEvent(this));
			} else {
				this.attack(new EntityPushedIntoVoidEvent(this, this.last_puncher));
			}
		}
		//update the effects
		foreach(effect ; this.effects) {
			effect.tick();
			if(effect.finished) {
				this.removeEffect(effect);
			}
		}
		if(this.dead && this.despawn_after > 0 && --this.despawn_after == 0) {
			this.despawn();
		}
		if(this.moved) {
			this.updateGroundStatus();
		}
	}

	public pure nothrow @property @safe @nogc float bodyYaw() {
		return this.m_body_yaw;
	}
	
	public pure nothrow @property @safe float bodyYaw(float bodyYaw) {
		return this.m_body_yaw = bodyYaw;
	}

	public final @property @safe ubyte angleBodyYaw() {
		return safe!ubyte(this.bodyYaw / 360 * 256);
	}

	public final pure nothrow @property @safe @nogc float speed() {
		return this.n_speed;
	}

	public final nothrow @property @safe uint health() {
		return this.healthNoAbs + this.absorption;
	}

	public final @property @safe uint health(uint health) {
		//TODO call events
		this.m_health.health = health;
		this.healthUpdated();
		return this.healthNoAbs;
	}

	public final @property @safe @nogc uint maxHealth() {
		return this.maxHealthNoAbs + this.maxAbsorption;
	}

	public final @property @safe uint maxHealth(uint max) {
		this.m_health.max = max;
		this.healthUpdated();
		return this.maxHealth;
	}

	public final nothrow @property @safe uint healthNoAbs() {
		return this.m_health.health;
	}

	public final pure nothrow @property @safe @nogc uint maxHealthNoAbs() {
		return this.m_health.max;
	}

	public final nothrow @property @safe uint absorption() {
		return this.m_health.absorption;
	}

	public final pure nothrow @property @safe @nogc uint maxAbsorption() {
		return this.m_health.maxAbsorption;
	}

	protected @trusted void healthUpdated() {}

	protected override bool validateAttack(EntityDamageEvent event) {
		//TODO the attack is applied if the damage is higher than the last one
		return this.alive && (!this.immortal || event.imminent) && (!cast(EntityDamageByEntityEvent)event || this.last_received_attack + 10 <= this.ticks);
	}

	protected override void attackImpl(EntityDamageEvent event) {
		this.last_received_attack = this.ticks;

		//update the health
		uint abb = this.absorption;
		this.m_health.remove(event.damage);
		if(abb > 0 && this.absorption == 0) {
			this.removeEffect(Effects.absorption);
		}
		this.healthUpdated();

		//hurt animation
		this.viewers!Player.call!"sendHurtAnimation"(this);

		//update the viewers if dead
		if(this.dead) {
			auto death = this.callDeathEvent(event);
			if(death.message != "") {
				this.world.broadcast(death.message, death.args);
			}
			this.die();
		} else if(cast(EntityAttackedByEntityEvent)event) {
			auto casted = cast(EntityDamageByEntityEvent)event;
			if(casted.doKnockback) {
				//TODO use knockback method?
				this.motion = casted.knockback;
			}
			this.last_puncher = casted.damager;
		}
	}

	protected EntityDeathEvent callDeathEvent(EntityDamageEvent last) {
		auto event = new EntityDeathEvent(this, last);
		this.world.callEvent(event);
		return event;
	}

	public @trusted void heal(EntityHealEvent event) {
		this.world.callEvent(event);
		if(!event.cancelled) {
			this.m_health.add(event.amount);
			this.healthUpdated();
		}
	}

	public final override @property @safe bool alive() {
		return this.m_health.alive;
	}

	public final override @property @safe bool dead() {
		return this.m_health.dead;
	}

	alias move = super.move;

	public @safe void move(EntityPosition position, float yaw=Rotation.KEEP, float bodyYaw=Rotation.KEEP, float pitch=Rotation.KEEP) {
		if(!bodyYaw.isNaN) this.m_body_yaw = bodyYaw;
		super.move(position, yaw, pitch);
	}

	/**
	 * Die and send the packets to the viewers
	 */
	protected void die() {
		this.viewers!Player.call!"sendDeathAnimation"(this);
		if((this.despawn_after = this.despawnAfter) == 0) {
			this.despawn();
		}
	}

	protected @property @safe @nogc tick_t despawnAfter() {
		return 30;
	}

	/**
	 * Adds an effect to the entity.
	 */
	public bool addEffect(sul.effects.Effect effect, ubyte level=0, tick_t duration=30, Living thrower=null) {
		return this.addEffect(Effect.fromId(effect, this, level, duration, thrower));
	}

	public bool addEffect(Effect effect) {
		if(effect.instant) {
			effect.onStart();
		} else {

			/+if(effect.id == Effects.healing.id || effect.id == Effects.harming.id) {
				//TODO for undead mobs
				if(effect.id == Effects.harming.id) {
					uint amount = to!uint(round(3 * effect.levelFromOne * multiplier));
					//this.attack(effect.thrower is null ? new EntityDamageEvent(this, Damage.MAGIC, amount) : new EntityDamagedByEntityEvent(this, Damage.MAGIC, amount, effect.thrower));
				}
				else this.heal(new EntityHealEvent(this, Healing.MAGIC, to!uint(round(3 * effect.levelFromOne * multiplier))));
				return true;
			}+/

			if(effect.id in this.effects) this.removeEffect(effect); //TODO just edit instead of removing

			this.effects[effect.id] = effect;
			effect.onStart();

			/*if(effect.id == Effects.healthBoost) {
				this.m_health.max = 20 + effect.levelFromOne * 4;
				this.healthUpdated();
			} else if(effect.id == Effects.absorption) {
				this.m_health.maxAbsorption = effect.levelFromOne * 4;
			}*/

			this.recalculateColors();
			this.onEffectAdded(effect, false);
		}
		return true;
	}

	protected void onEffectAdded(Effect effect, bool modified) {}

	/**
	 * Gets a pointer to an effect.
	 */
	public Effect* opBinaryRight(string op : "in")(ubyte id) {
		return id in this.effects;
	}

	/// ditto
	public Effect* opBinaryRight(string op : "in")(sul.effects.Effect effect) {
		return this.opBinaryRight!"in"(effect.minecraft.id);
	}

	/**
	 * Removes an effect from the entity.
	 */
	public bool removeEffect(sul.effects.Effect effect) {
		auto e = effect.minecraft.id in this.effects;
		if(e) {
			this.effects.remove(effect.minecraft.id);
			this.recalculateColors();
			(*e).onStop();
			/*if(effect.id == Effects.healthBoost) {
				this.m_health.max = 20;
				this.healthUpdated();
			} else if(effect.id == Effects.absorption) {
				this.m_health.maxAbsorption = 0;
			}*/
			this.onEffectRemoved(*e);
			return true;
		}
		return false;
	}

	/// ditto
	public bool removeEffect(ubyte effect) {
		return (effect in this.effects) ? this.removeEffect(this.effects[effect]) : false;
	}

	protected void onEffectRemoved(Effect effect) {}

	/**
	 * Removes every effect.
	 */
	public void clearEffects() {
		foreach(Effect effect; this.effects) {
			this.removeEffect(effect);
		}
	}

	protected void recalculateColors() {
		if(this.effects.length > 0) {
			Color[] colors;
			foreach(effect ; this.effects) {
				foreach(uint i ; 0..effect.levelFromOne) {
					colors ~= Color.fromRGB(effect.particles);
				}
			}
			this.potionColor = new Color(colors);
			this.potionAmbient = true;
		} else {
			this.potionColor = null;
			this.potionAmbient = false;
		}
	}

	public void recalculateSpeed() {
		float s = this.n_base_speed;
		auto speed = Effects.speed in this;
		auto slowness = Effects.slowness in this;
		if(speed) {
			s *= 1 + .2 * (*speed).levelFromOne;
		}
		if(slowness) {
			s /= 1 + .15 * (*slowness).levelFromOne;
		}
		if(this.sprinting) {
			s *= 1.3;
		}
		this.n_speed = s < 0 ? 0 : s;
	}

	protected @property @trusted Color potionColor(Color color) {
		if(color is null) {
			this.metadata.set!"potionColor"(0);
		} else {
			auto c = color.rgb & 0xFFFFFF;
			static if(__minecraft) {
				foreach(p ; __minecraftProtocolsTuple) {
					mixin("this.metadata.minecraft" ~ p.to!string ~ ".potionColor = c;");
				}
			}
			static if(__pocket) {
				c |= 0xFF000000;
				foreach(p ; __pocketProtocolsTuple) {
					mixin("this.metadata.pocket" ~ p.to!string ~ ".potionColor = c;");
				}
			}
		}
		return color;
	}

	protected @property @trusted bool potionAmbient(bool flag) {
		this.metadata.set!"potionAmbient"(flag);
		return flag;
	}

}

struct Health {

	public float m_health;
	public uint m_max;

	public float m_absorption;
	public uint m_max_absorption;

	public @safe this(uint health, uint max) {
		this.m_health = 0;
		this.m_absorption = 0;
		this.max = max;
		this.health = health;
		this.maxAbsorption = 0;
	}

	public nothrow @property @safe @nogc uint health() {
		if(this.dead) return 0;
		uint ret = cast(uint)round(this.m_health);
		return ret == 0 ? 1 : ret;
	}

	public @property @safe uint health(float health) {
		this.m_health = health;
		if(this.m_health > this.m_max) this.m_health = this.m_max;
		else if(this.m_health < 0) this.m_health = 0;
		return this.health;
	}

	public pure nothrow @property @safe @nogc uint max() {
		return this.m_max;
	}

	public @property @safe uint max(uint max) {
		this.m_max = max;
		this.health = this.health;
		return this.m_max;
	}

	public nothrow @property @safe uint absorption() {
		return cast(uint)round(this.m_absorption);
	}

	public pure nothrow @property @safe @nogc uint maxAbsorption() {
		return this.m_max_absorption;
	}

	public @property @safe uint maxAbsorption(uint ma) {
		this.m_max_absorption = ma;
		this.m_absorption = ma;
		return this.maxAbsorption;
	}

	public @safe void add(float amount) {
		this.health = this.m_health + amount;
	}

	public @safe void remove(float amount) {
		if(this.m_absorption != 0) {
			if(amount <= this.m_absorption) {
				this.m_absorption -= amount;
				amount = 0;
			} else {
				amount -= this.m_absorption;
				this.m_absorption = 0;
			}
		}
		this.health = this.m_health - amount;
	}

	public pure nothrow @property @safe @nogc bool alive() {
		return this.m_health != 0;
	}

	public pure nothrow @property @safe @nogc bool dead() {
		return this.m_health == 0;
	}

	public @safe void reset() {
		this.m_health = 20;
		this.m_max = 20;
		this.m_absorption = 0;
		this.m_max_absorption = 0;
	}

}

enum Healing : ubyte {

	UNKNOWN = 0,

	MAGIC = 1,
	NATURAL_REGENERATION = 2,
	REGENERATION = 3,

}
