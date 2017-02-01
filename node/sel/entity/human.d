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
module sel.entity.human;

import std.math : isNaN, sin, cos, PI;

import common.sel;

import sel.player : Player;
import sel.entity.effect : Effect, Effects;
import sel.entity.entity : Entities, Rotation;
import sel.entity.interfaces;
import sel.entity.living : Healing, Damage, Living;
import sel.event.world.damage;
import sel.event.world.entity : EntityHealEvent;
import sel.item.inventory : PlayerInventory;
import sel.item.slot : Slot;
import sel.math.vector : BlockPosition, EntityPosition, entityPosition;
import sel.util : call;
import sel.world.world : Difficulty, World;

class Human : Living, Collector, Shooter, PotionThrower {

	public static immutable WIDTH = .6f;
	public static immutable HEIGHT = 1.8f;

	private bool n_spawned;

	protected Hunger m_hunger;

	private float m_experience;
	private uint m_level;

	public EntityPosition m_spawn;

	public Skin skin;

	public PlayerInventory inventory;

	private tick_t last_attack = 0;

	private tick_t regeneration_tick = 0;
	private tick_t starvation_tick = 0;

	public this(World world, EntityPosition position, Skin skin) {
		super(world, position, 20, 20);
		this.m_hunger = Hunger(20, 20);
		//this.m_exp = Experience();
		this.m_experience = 0;
		this.m_level = 0;
		this.skin = skin;
		this.n_eye_height = 1.62;
		this.m_body_yaw = Rotation.FRONT;
		this.inventory = new PlayerInventory(this);
		this.setSize(.6f, 1.8f);
	}

	public final override @property @safe @nogc bytegroup type() {
		return Entities.PLAYER;
	}

	public override void tick() {
		super.tick();
		if(this.starvation_tick != 0 && this.ticks % 80 == this.starvation_tick) {
			if(this.health > (this.world.rules.difficulty == Difficulty.hard ? 0 : (this.world.rules.difficulty == Difficulty.normal ? 1 : 10))) {
				this.attack(new EntityStarveEvent(this));
			}
		} else if(this.regeneration_tick != 0 && this.ticks % (this.hunger == 20 ? 10 : 80) == this.regeneration_tick && this.rules.naturalRegeneration) {
			this.heal(new EntityHealEvent(this, Healing.NATURAL_REGENERATION, 1));
			this.exhaust(Exhaustion.NATURAL_REGENERATION);
		}
	}

	protected override @safe bool tickEffect(Effect effect) {
		if(!super.tickEffect(effect)) {
			switch(effect.id) {
				case Effects.HUNGER:
					this.exhaust(.025 * effect.levelFromOne);
					break;
				case Effects.SATURATION:
					if(this.hunger < 20) {
						this.hunger = this.hunger + effect.levelFromOne;
					}
					break;
				default:
					return false;
			}
		}
		return true;
	}

	public final @property @safe @nogc bool spawned() {
		return this.n_spawned;
	}

	/**
	 * Get the spawn point
	 */
	public @property @safe @nogc EntityPosition spawn() {
		return this.m_spawn;
	}

	/**
	 * Set the spawn point
	 */
	public @property @safe EntityPosition spawn(EntityPosition spawn) {
		return this.m_spawn = spawn;
	}

	/// ditto
	public @property @safe EntityPosition spawn(BlockPosition spawn) {
		return this.spawn = spawn.entityPosition;
	}

	protected override void die() {
		super.die();
		this.removeEffects();
		this.recalculateColors();
		this.ticking = false;
		//drop the content of the inventory
		foreach(Slot slot ; this.inventory.full) {
			if(!slot.empty) {
				float f0 = this.world.random.next!float * .5f;
				float f1 = this.world.random.next!float * PI * 2;
				this.world.drop(slot, this.position + [0, 1.3, 0], EntityPosition(-sin(f1) * f0, .2, cos(f1) * f0));
			}
		}
		this.inventory.empty = true;
		this.inventory.update = PlayerInventory.ALL;
	}

	protected override @property @safe @nogc tick_t despawnAfter() {
		return 0;
	}

	public override @trusted void despawn() {
		//do nothing, wait for the respawn
		this.n_spawned = false;
		// despawn from players
		this.viewers!Player.call!"sendDespawnEntity"(this);
	}

	protected @trusted void respawn() {
		this.ticking = true;
		this.m_health.reset();
		this.m_hunger.reset();
		this.hungerUpdated();
		this.firstspawn();
		this.onFire = false;
		this.sprinting = false;
		this.sneaking = false;
		this.move(this.spawn, 0, 0, 0);
		//show again to viewers
		this.viewers!Player.call!"sendSpawnEntity"(this);
	}

	public @safe void firstspawn() {
		this.n_spawned = true;
		this.sprinting = false;
		this.inventory.init();
	}

	// used for limiting the attacks

	public final @property @safe bool canAttack() {
		return this.last_attack + 10 < this.ticks;
	}

	public override void attackImpl(EntityDamageEvent event) {
		super.attackImpl(event);
		if(!event.cancelled) {
			this.last_attack = this.ticks;
			this.exhaust(Exhaustion.DAMAGED);
			//all the kinds of damages damage the armour in mcpe
			/*foreach(uint index, Slot slot; this.inventory.armor) {
				if(slot !is null && cast(Armor)slot.item) {
					slot.consume(1);
					this.inventory.armor(index, slot.consumed ? null : slot);
					if(!slot.consumed) this.inventory.update_viewers &= PlayerInventory.ARMOR ^ 0xF;
				}
			}*/
		}
	}

	// hunger functions

	public @property @safe @nogc uint hunger() {
		return this.m_hunger.hunger;
	}

	public @property @safe uint hunger(uint hunger) {
		this.m_hunger.hunger = hunger;
		this.hungerUpdated();
		return hunger;
	}

	public @safe void exhaust(float amount) {
		if(this.rules.depleteHunger && this.world.rules.difficulty != Difficulty.peaceful) {
			uint old = this.hunger;
			this.m_hunger.exhaust(amount);
			if(old != this.hunger) this.hunger = this.hunger;
		}
	}

	public @safe void saturate(float amount) {
		this.m_hunger.saturate(amount);
	}

	public final @property @safe @nogc float saturation() {
		return this.m_hunger.saturation;
	}

	public final @property @safe @nogc float experience() {
		return this.m_experience;
	}

	public final @property @safe float experience(float experience) {
		this.m_experience = experience;
		this.experienceUpdated();
		return this.m_experience;
	}

	public final @property @safe @nogc uint level() {
		return this.m_level;
	}

	public final @property @safe uint level(uint level) {
		this.m_level = level;
		this.experienceUpdated();
		return this.m_level;
	}

	protected @trusted void hungerUpdated() {
		if(this.hunger == 0 && this.starvation_tick == 0) {
			//start starvation
			this.starvation_tick = (this.ticks - 1) % 80;
		} else if((this.hunger > 18 || this.world.rules.difficulty == Difficulty.peaceful) && this.regeneration_tick == 0 && this.healthNoAbs < this.maxHealthNoAbs) {
			//start natural regeneration
			this.regeneration_tick = (this.ticks - 1) % 80;
		} else if(this.hunger > 0 && this.starvation_tick != 0) {
			//stop starvation
			this.starvation_tick = 0;
		} else if(this.hunger <= 18 && this.regeneration_tick != 0) {
			//stop regeneration
			this.regeneration_tick = 0;
		}
	}

	protected override @trusted void healthUpdated() {
		super.healthUpdated();
		if(this.healthNoAbs == this.maxHealthNoAbs && this.regeneration_tick != 0) {
			this.regeneration_tick = 0;
		} else if(this.healthNoAbs < this.maxHealthNoAbs && this.regeneration_tick == 0 && this.hunger > 18) {
			this.regeneration_tick = (this.ticks - 1) % 80;
		}
	}

	protected @trusted void experienceUpdated() {}

	public override @trusted bool onCollect(Collectable collectable) {
		return false;
	}

}

struct Hunger {

	public float exhaustion = 0;
	public float saturation = 5;

	public uint m_hunger;
	public immutable uint max;

	public @safe @nogc this(uint hunger, uint max) {
		this.m_hunger = hunger;
		//this.saturation = hunger;
		this.max = max;
	}

	public @safe @nogc void reset() {
		this.exhaustion = 0;
		this.saturation = 5;
		this.m_hunger = this.max;
	}

	public @safe void exhaust(float amount) {
		this.exhaustion += amount;
		if(this.exhaustion >= 4) {
			this.desaturate(1);
			this.exhaustion %= 4;
		}
	}

	public @safe @nogc void saturate(float amount) {
		this.saturation += amount;
		if(this.saturation > this.hunger) this.saturation = this.hunger;
	}

	public @safe @nogc void desaturate(float amount) {
		this.saturation -= amount;
		if(this.saturation < 0) {
			if(this.hunger > 0) this.m_hunger--;
			this.saturation = 0;
		}
	}

	public @property @safe @nogc uint hunger() {
		return this.m_hunger;
	}

	public @property @safe @nogc uint hunger(uint hunger) {
		if(hunger > this.max) hunger = this.max;
		return this.m_hunger = hunger;
	}

}

enum Exhaustion : float {

	WALKING = .01,
	SNEAKING = .005,
	SWIMMING = .015,
	BREAKING_BLOCK = .025,
	SPRINTING = .1,
	JUMPING = .2,
	ATTACKING = .3,
	DAMAGED = .3,
	SPRINTED_JUMP = .8,
	NATURAL_REGENERATION = 3

}

struct Skin {

	public static Skin STEVE;
	public static Skin ALEX;

	public static immutable ushort NORMAL_LENGTH = 32 * 64 * 4;
	public static immutable ushort COMPLEX_LENGTH = 64 * 64 * 4;

	private bool n_valid = false;

	private string n_name;
	private ushort n_length;
	private immutable(ubyte)[] n_data;

	public string[2] textures;

	public @safe this(string name, ushort length, ubyte[] data, string[2] textures=["", ""]) {
		this.n_name = name;
		this.n_length = length;
		if((length == NORMAL_LENGTH || length == COMPLEX_LENGTH) && length == data.length) {
			this.n_valid = true;
			this.n_data = data.idup;
		}
		this.textures = textures;
	}

	public @safe this(string name, ubyte[] data, string[2] textures=["", ""]) {
		this(name, data.length & ushort.max, data, textures);
	}

	public @property @safe @nogc bool valid() {
		return this.n_valid;
	}

	public @property @safe @nogc string name() {
		return this.n_name;
	}

	public @property @safe @nogc ushort length() {
		return this.n_length;
	}

	public @property @safe @nogc immutable(ubyte)[] data() {
		return this.n_data;
	} 

}
