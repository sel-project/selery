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

import sel.settings;
import sel.player : Player;
import sel.entity.effect : Effect, Effects;
import sel.entity.entity : Entity, Rotation;
import sel.entity.metadata;
import sel.event.world;
import sel.math.vector;
import sel.util;
import sel.util.color : Color;
import sel.world.world : World;

abstract class Living : Entity {

	protected Health m_health;
	private Effect[ubyte] effects;

	public bool immortal = false;

	private tick_t last_received_attack = 0;
	private tick_t last_void_damage = 0;

	protected float m_body_yaw = Rotation.WEST;

	private float n_speed = .1;

	private tick_t despawn_after = 0;

	public this(World world, EntityPosition position, uint health, uint max) {
		super(world, position);
		this.m_health = Health(health, max);
		//this.metadata[DATA_AIR] = to!ushort(300);
	}

	public override void tick() {
		super.tick();
		//void
		if(this.y < 0 && this.last_void_damage + 10 > this.ticks) {
			this.last_void_damage = this.ticks;
			if(this.last_puncher is null) {
				this.attack(new EntityDamageByVoidEvent(this));
			} else {
				this.attack(new EntityPushedIntoVoidEvent(this, this.last_puncher));
			}
		}
		//update the effects
		foreach(Effect effect ; this.effects) {
			if(effect.repeat && effect.repeat(this.ticks)) {
				this.tickEffect(effect);
			}
			if(effect.durate <= 0) {
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

	protected @trusted bool tickEffect(Effect effect) {
		switch(effect.id) {
			case Effects.REGENERATION:
				this.heal(new EntityHealEvent(this, Healing.REGENERATION, 1));
				break;
			case Effects.POISON:
				if(this.healthNoAbs > 1) this.attack(new EntityDamageByPoisonEvent(this));
				break;
			case Effects.WITHER:
				this.attack(new EntityDamageByWitherEffectEvent(this));
				break;
			default:
				return false;
		}
		return true;
	}

	public @property @safe @nogc float bodyYaw() {
		return this.m_body_yaw;
	}
	
	public @property @safe float bodyYaw(float bodyYaw) {
		return this.m_body_yaw = bodyYaw;
	}

	public final @property @safe ubyte angleBodyYaw() {
		return safe!ubyte(this.bodyYaw / 360 * 256);
	}

	public final @property @safe @nogc float speed() {
		return this.n_speed;
	}

	public final @property @safe uint health() {
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

	public final @property @safe uint healthNoAbs() {
		return this.m_health.health;
	}

	public final @property @safe @nogc uint maxHealthNoAbs() {
		return this.m_health.max;
	}

	public final @property @safe uint absorption() {
		return this.m_health.absorption;
	}

	public final @property @safe @nogc uint maxAbsorption() {
		return this.m_health.maxAbsorption;
	}

	protected @trusted void healthUpdated() {}

	protected override bool validateAttack(EntityDamageEvent event) {
		return this.alive && (!this.immortal || event.imminent) && (!cast(EntityDamageByEntityEvent)event || this.last_received_attack + 10 <= this.ticks);
	}

	protected override void attackImpl(EntityDamageEvent event) {
		this.last_received_attack = this.ticks;

		//update the health
		uint abb = this.absorption;
		this.m_health.remove(event.damage);
		if(abb > 0 && this.absorption == 0) {
			this.removeEffect(Effects.ABSORPTION);
		}
		this.healthUpdated();

		//hurt animation
		this.viewers!Player.call!"sendHurtAnimation"(this);

		//update the viewers if dead
		if(this.dead) {
			//TODO add the rules to the event (keep inventory, drop inventory, kep xp, etc)
			EntityDeathEvent death = new EntityDeathEvent(this, event);
			this.world.callEvent(death);
			if(death.message != "") {
				this.world.broadcast(event.message, event.args);
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
		/*EntityEvent packet = new EntityEvent(this, EntityEvent.DEATH_ANIMATION);
		foreach(Player player ; this.viewers!Player) {
			player.sendPacket(packet);
		}*/
		this.viewers!Player.call!"sendDeathAnimation"(this);
		if((this.despawn_after = this.despawnAfter) == 0) {
			this.despawn();
		}
	}

	protected @property @safe @nogc tick_t despawnAfter() {
		return 30;
	}

	/**
	 * Add an effect to the entity
	 */
	public @trusted bool addEffect(Effect effect, double multiplier=1) {

		if(effect.id == Effects.HEALING || effect.id == Effects.HARMING) {
			//TODO for undead mobs
			if(effect.id == Effects.HARMING) {
				uint amount = to!uint(round(3 * effect.levelFromOne * multiplier));
				//this.attack(effect.thrower is null ? new EntityDamageEvent(this, Damage.MAGIC, amount) : new EntityDamagedByEntityEvent(this, Damage.MAGIC, amount, effect.thrower));
			}
			else this.heal(new EntityHealEvent(this, Healing.MAGIC, to!uint(round(3 * effect.levelFromOne * multiplier))));
			return true;
		}

		if(effect.id in this.effects) this.removeEffect(effect.id);


		effect.setStartTick(this.ticks);
		this.effects[effect.id] = effect;

		if(effect.id == Effects.SPEED || effect.id == Effects.SLOWNESS) {
			this.recalculateSpeed();
		} else if(effect.id == Effects.INVISIBILITY) {
			this.invisible = true;
			this.showNametag = false;
		} else if(effect.id == Effects.HEALTH_BOOST) {
			this.m_health.max = 20 + effect.levelFromOne * 4;
			this.healthUpdated();
		} else if(effect.id == Effects.ABSORPTION) {
			this.m_health.maxAbsorption = effect.levelFromOne * 4;
		}

		this.recalculateColors();
		return true;
	}

	/**
	 * Remove an effect from the entity
	 */
	public @trusted bool removeEffect(Effect effect) {
		if(effect.id in this.effects) {
			this.effects.remove(effect.id);
			this.recalculateColors();
			if(effect.id == Effects.SPEED || effect.id == Effects.SLOWNESS) {
				this.recalculateSpeed();
			} else if(effect.id == Effects.INVISIBILITY) {
				this.invisible = false;
				this.showNametag = true;
			} else if(effect.id == Effects.HEALTH_BOOST) {
				this.m_health.max = 20;
				this.healthUpdated();
			} else if(effect.id == Effects.ABSORPTION) {
				this.m_health.maxAbsorption = 0;
			}
			return true;
		}
		return false;
	}

	/// ditto
	public @trusted bool removeEffect(ubyte effect) {
		return (effect in this.effects) ? this.removeEffect(this.effects[effect]) : false;
	}

	/**
	 * Remove all the effects
	 */
	public @safe void removeEffects() {
		foreach(Effect effect; this.effects) {
			this.removeEffect(effect);
		}
	}

	/**
	 * Check if the entity has an effect
	 */
	public @safe @nogc bool hasEffect(ubyte id) {
		return (id in this.effects) ? true : false;
	}

	/**
	 * Get an effect
	 */
	public @safe Effect getEffect(ubyte id) {
		return this.effects[id];
	}

	/**
	 * Recalculate the potion colours
	 */
	protected @safe void recalculateColors() {
		if(this.effects.length > 0) {
			Color[] colors;
			foreach(Effect effect ; this.effects) {
				foreach(uint i ; 0..effect.levelFromOne()) {
					colors ~= Effect.effectColor(effect.id);
				}
			}
			this.potionColor = new Color(colors);
			this.potionAmbient = true;
		} else {
			this.potionColor = null;
			this.potionAmbient = false;
		}
	}

	/** speed need to be recalculated */
	public @safe void recalculateSpeed() {
		float speed = .1;
		if(Effects.SPEED in this.effects) {
			speed *= 1 + .2 * this.effects[Effects.SPEED].levelFromOne;
		}
		if(Effects.SLOWNESS in this.effects) {
			speed /= 1 + .15 * this.effects[Effects.SLOWNESS].levelFromOne;
		}
		if(this.sprinting) {
			speed *= 1.3;
		}
		this.n_speed = speed < 0 ? 0 : speed;
	}

	protected @property @trusted Color potionColor(Color color) {
		if(color is null) {
			this.metadata.set!"potionColor"(0);
		} else {
			auto c = color.rgb & 0xFFFFFF;
			foreach(p ; __minecraftProtocolsTuple) {
				mixin("this.metadata.minecraft" ~ p.to!string ~ ".potionColor = c;");
			}
			c |= 0xFF000000;
			foreach(p ; __pocketProtocolsTuple) {
				mixin("this.metadata.pocket" ~ p.to!string ~ ".potionColor = c;");
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

	public @property @safe uint health() {
		if(this.dead) return 0;
		uint ret = to!uint(round(this.m_health));
		return ret == 0 ? 1 : ret;
	}

	public @property @safe uint health(float health) {
		this.m_health = health;
		if(this.m_health > this.m_max) this.m_health = this.m_max;
		else if(this.m_health < 0) this.m_health = 0;
		return this.health;
	}

	public @property @safe @nogc uint max() {
		return this.m_max;
	}

	public @property @safe uint max(uint max) {
		this.m_max = max;
		this.health = this.health;
		return this.m_max;
	}

	public @property @safe uint absorption() {
		return to!uint(round(this.m_absorption));
	}

	public @property @safe @nogc uint maxAbsorption() {
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

	public @property @safe bool alive() {
		return this.m_health != 0;
	}

	public @property @safe bool dead() {
		return this.m_health == 0;
	}

	public @safe void reset() {
		this.m_health = 20;
		this.m_max = 20;
		this.m_absorption = 0;
		this.m_max_absorption = 0;
	}

}

enum Damage : ubyte {

	UNKNOWN = 0,
	VOID = 1,

	ATTACK = 2,
	PROJECTILE = 3,

	SUFFOCATION = 4,
	FALL = 5,
	BURNING = 6,
	FIRE = 7,
	LAVA = 8,
	DROWNING = 9,
	BLOCK_EXPLOSION = 10,
	ENTITY_EXPLOSION = 11,
	MAGIC = 12,
	LIGHTNING = 13,
	THORNS = 14,
	STARVATION = 15,
	CACTUS = 16,
	BLAZE_FIREBALL = 17,
	GHAST_FIREBALL = 18,
	ANVIL = 19,
	POISON = 20,
	WITHER = 21,
	GENERIC_PROJECTILE = 22,

}

enum Healing : ubyte {

	UNKNOWN = 0,

	MAGIC = 1,
	NATURAL_REGENERATION = 2,
	REGENERATION = 3,

}
