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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/entity/human.d, selery/entity/human.d)
 */
module selery.entity.human;

import std.math : isNaN, sin, cos, PI;
import std.random : uniform01;

import selery.about;
import selery.config : Difficulty;
import selery.effect : Effect, Effects;
import selery.enchantment : Enchantments;
import selery.entity.entity : Entities, Rotation;
import selery.entity.interfaces;
import selery.entity.living : Healing, Living;
import selery.event.world.damage;
import selery.event.world.entity : EntityHealEvent;
import selery.inventory.inventory : PlayerInventory;
import selery.item.slot : Slot;
import selery.math.vector : BlockPosition, EntityPosition, entityPosition;
import selery.player.player : Player;
import selery.util.util : call;
import selery.world.world : World;

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
		this.m_spawn = position;
		this.skin = skin;
		this.n_eye_height = 1.62;
		this.m_body_yaw = Rotation.FRONT;
		this.inventory = new PlayerInventory(this);
		this.setSize(.6f, 1.8f);
	}

	public override pure nothrow @property @safe @nogc string type() {
		return "player";
	}

	public override void tick() {
		super.tick();
		if(this.starvation_tick != 0 && this.ticks % 80 == this.starvation_tick) {
			if(this.health > (this.world.difficulty == Difficulty.hard ? 0 : (this.world.difficulty == Difficulty.normal ? 1 : 10))) {
				this.attack(new EntityStarveEvent(this));
			}
		} else if(this.regeneration_tick != 0 && this.ticks % (this.hunger == 20 ? 10 : 80) == this.regeneration_tick && this.world.naturalRegeneration) {
			this.heal(new EntityHealEvent(this, 1));
			this.exhaust(Exhaustion.NATURAL_REGENERATION);
		}
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
		this.clearEffects();
		this.recalculateColors();
		this.ticking = false;
		//drop the content of the inventory
		foreach(Slot slot ; this.inventory.full) {
			if(!slot.empty && Enchantments.curseOfVanishing !in slot.item) {
				float f0 = uniform01!float(this.world.random) * .5f;
				float f1 = uniform01!float(this.world.random) * PI * 2;
				this.world.drop(slot, this.position + [0, 1.3, 0], EntityPosition(-sin(f1) * f0, .2, cos(f1) * f0));
			}
		}
		this.inventory.empty = true;
		this.inventory.update = PlayerInventory.ALL;
	}

	protected override @property @safe @nogc tick_t despawnAfter() {
		return 0;
	}

	public override void despawn() {
		//do nothing, wait for the respawn
		this.n_spawned = false;
		// despawn from players
		this.viewers!Player.call!"sendDespawnEntity"(this);
	}

	protected void respawn() {
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

	public void firstspawn() {
		this.n_spawned = true;
		this.sprinting = false;
		this.inventory.reset();
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
		if(this.world.depleteHunger && this.world.difficulty != Difficulty.peaceful) {
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
		} else if((this.hunger > 18 || this.world.difficulty == Difficulty.peaceful) && this.regeneration_tick == 0 && this.healthNoAbs < this.maxHealthNoAbs) {
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

	private bool _valid = false;

	private string _name;
	private immutable(ubyte)[] _data;
	private immutable(ubyte)[] _cape;
	private string _geometry_name;
	private immutable(ubyte)[] _geometry_data;

	public @safe this(string name, ubyte[] data, ubyte[] cape=[], string geometryName="", ubyte[] geometryData=[]) {
		this._name = name;
		this._data = data.idup;
		this._cape = cape.idup;
		this._geometry_name = geometryName;
		this._geometry_data = geometryData.idup;
		if(data.length == NORMAL_LENGTH || data.length == COMPLEX_LENGTH) {
			this._valid = true;
		}
	}

	public pure nothrow @property @safe @nogc bool valid() {
		return this._valid;
	}

	public pure nothrow @property @safe @nogc string name() {
		return this._name;
	}

	public pure nothrow @property @safe @nogc immutable(ubyte)[] data() {
		return this._data;
	}

	public pure nothrow @property @safe @nogc immutable(ubyte)[] cape() {
		return this._cape;
	}

	public pure nothrow @property @safe @nogc string geometryName() {
		return this._geometry_name;
	}

	public pure nothrow @property @safe @nogc immutable(ubyte)[] geometryData() {
		return this._geometry_data;
	}

}
