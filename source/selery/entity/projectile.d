/*
 * Copyright (c) 2017-2018 SEL
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
module selery.entity.projectile;

import std.conv : to;
import std.math : abs, sqrt, atan2, PI;

import selery.about;
import selery.block.block : Block, blockInto;
import selery.block.blocks : Blocks;
import selery.effect;
import selery.entity.entity : Entity, Entities;
import selery.entity.living : Living;
import selery.entity.metadata;
import selery.event.world;
import selery.math.vector;
import selery.player.player : Player;
import selery.util.color : Color;
import selery.world.world : World;

static import sul.entities;

abstract class Projectile : Entity {

	private Living n_shooter;
	private bool outfromshooter = false;

	public this(World world, EntityPosition position, EntityPosition motion, Living shooter=null) {
		super(world, position);
		this.m_motion = motion;
		this.n_shooter = shooter;
		if(this.shot) {
			//this.metadata[DATA_SHOOTER] = this.shooter.id.to!ulong;
		}
	}

	public this(World world, Living shooter, float power) {
		this(world, shooter.position + [0, shooter.eyeHeight, 0], shooter.direction * power, shooter);
	}

	public override void tick() {
		super.tick();

		if(this.position.y < 0) {
			this.despawn();
			return;
		}

		EntityPosition lastposition = this.position;

		// TODO move in Entity and add bool doMotion

		if(!this.motionless) {

			// add gravity

			
			// update the motion
			if(this.acceleration != 0) this.motion = this.motion - [0, this.acceleration, 0];
			if(this.motion.y.abs > this.terminal_velocity) this.m_motion = EntityPosition(this.motion.x, this.motion.y > 0 ? this.terminal_velocity : -this.terminal_velocity, this.motion.z);
			
			// move
			this.move(this.position + this.motion, atan2(this.motion.x, this.motion.z) * 180f / PI, atan2(this.motion.y, sqrt(this.motion.x * this.motion.x + this.motion.z * this.motion.z)) * 180f / PI);
			
			// apply the drag force
			if(this.drag != 0) this.motion = this.motion * (1f - this.drag);

			//TODO an entity could travel more that 1 block per tick

			// collisions with entities
			if(!this.outfromshooter && (!this.shot || !this.shooter.box.intersects(this.n_box))) this.outfromshooter = true;
			foreach(ref Entity entity ; this.viewers) {
				if(entity.box.intersects(this.n_box)) {
					if(!this.shot || entity != this.shooter || this.outfromshooter) {
						if(this.onCollide(entity)) break;
					}
				}
			}

			// collision with blocks
			auto min = this.n_box.minimum;
			auto max = this.n_box.maximum;
			foreach(int x ; min.x.blockInto..max.x.blockInto+1) {
				foreach(int y ; min.y.blockInto..max.y.blockInto+1) {
					foreach(int z ; min.z.blockInto..max.z.blockInto+1) {
						BlockPosition position = BlockPosition(x, y, z);
						Block block = this.world[position];
						if(block.hasBoundingBox) {
							block.box.update(position.entityPosition);
							if(block.box.intersects(this.n_box) && this.onCollide(block, position, 0)) goto BreakCycle;
						}
					}
				}
			}
			BreakCycle:

		}

	}

	protected bool onCollide(Entity entity) {
		return false;
	}

	protected bool onCollide(Block block, BlockPosition position, uint face) {
		return false;
	}

	public @property @safe @nogc bool shot() {
		return this.shooter !is null;
	}

	public @property @safe @nogc Living shooter() {
		return this.n_shooter;
	}

}

class Arrow : Projectile {

	public static immutable float WIDTH = .5f;
	public static immutable float HEIGHT = .5f;

	public static immutable float FORCE = 2f;

	public static immutable float ACCELERATION = .05f;
	public static immutable float DRAG = .01f;
	public static immutable float TERMINAL_VELOCITY = 5f;

	private float power;

	public this(World world, Living shooter, float force) {
		super(world, shooter, FORCE * force);
		this.power = force;
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2f;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.arrow;
	}

	public override bool onCollide(Entity entity) {
		if(cast(Living)entity) {
			//entity.to!Living.attack(new EntityDamagedByChildEvent(entity.to!Living, Damage.PROJECTILE, to!uint(this.power * 10f), this.shooter, this));
			this.despawn();
			return true;
		}
		return false;
	}

	public override bool onCollide(Block block, BlockPosition position, uint face) {
		this.motionless = true;
		return true;
	}

}

class Snowball : Projectile {

	public static immutable float WIDTH = .25f;
	public static immutable float HEIGHT = .25f;
	
	public static immutable float FORCE = 1.5f;
	
	public static immutable float ACCELERATION = .03f;
	public static immutable float DRAG = .01f;
	public static immutable float TERMINAL_VELOCITY = 3f;
	
	public this(World world, Living shooter) {
		super(world, shooter, FORCE);
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2f;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.snowball;
	}

	public override void tick() {
		super.tick();
		this.moved = false;
		this.motionmoved = false;
	}

	public override bool onCollide(Entity entity) {
		if(cast(Living)entity) {
			//TODO damage blazes (3 points)
			//entity.to!Living.attack(new EntityDamagedByChildEvent(entity.to!Living, Damage.GENERIC_PROJECTILE, 0, this.shooter, this));
			this.despawn();
			return true;
		}
		return false;
	}
	
}

class Egg : Projectile {

	public static immutable float WIDTH = .25f;
	public static immutable float HEIGHT = .25f;

	public static immutable float FORCE = 1.5f;

	public static immutable float ACCELERATION = .03f;
	public static immutable float DRAG = .01f;
	public static immutable float TERMINAL_VELOCITY = 3f;

	public this(World world, Living shooter) {
		super(world, shooter, FORCE);
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2f;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.egg;
	}

	public override void tick() {
		super.tick();
		this.moved = false;
		this.motionmoved = false;
	}

	public override bool onCollide(Entity entity) {
		if(cast(Living)entity) {
			//entity.to!Living.attack(new EntityDamagedByChildEvent(entity.to!Living, Damage.GENERIC_PROJECTILE, 0, this.shooter, this));
			//TODO 12.5% of possibiity of spawn a baby chicken
			this.despawn();
			return true;
		}
		return false;
	}

}

class Enderpearl : Projectile {

	public static immutable float WIDTH = .25f;
	public static immutable float HEIGHT = .25f;

	public static immutable float FORCE = 1.5f;

	public static immutable float ACCELERATION = .03f;
	public static immutable float DRAG = .01f;
	public static immutable float TERMINAL_VELOCITY = 3f;

	public this(World world, Living shooter) {
		super(world, shooter, FORCE);
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.enderpearl;
	}

	public override bool onCollide(Entity entity) {
		if(cast(Living)entity) {
			//entity.to!Living.attack(new EntityDamagedByChildEvent(entity.to!Living, Damage.GENERIC_PROJECTILE, 0, this.shooter, this));
			this.onCollide();
			return true;
		}
		return false;
	}

	public override bool onCollide(Block block, BlockPosition position, uint face) {
		this.onCollide();
		return true;
	}

	protected void onCollide() {
		if(this.shot) {
			if(cast(Player)this.shooter) {
				this.shooter.to!Player.teleport(this.position);
			} else {
				this.shooter.move(this.position);
			}
			//this.shooter.attack(new EntityDamageEvent(this.shooter, Damage.FALL, 5));
		}
		this.despawn();
	}

}

class Fireball : Projectile {

	public static immutable float WIDTH = 1f;
	public static immutable float HEIGHT = 1f;

	public static immutable float FORCE = 1.5f;

	public static immutable float ACCELERATION = 0f;
	public static immutable float DRAG = 0f;
	public static immutable float TERMINAL_VELOCITY = 1.3f;

	public this(World world, Living shooter) {
		super(world, shooter, FORCE);
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2f;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.ghastFireball;
	}

	public override void tick() {
		super.tick();
		this.moved = false;
		if(this.ticks > 60) this.despawn();
	}

}

class SmallFireball : Projectile {

	public static immutable float WIDTH = .3125f;
	public static immutable float HEIGHT = .3125f;

	public static immutable float FORCE = 1.5f;

	public static immutable float ACCELERATION = 0f;
	public static immutable float DRAG = 0f;
	public static immutable float TERMINAL_VELOCITY = 1.3f;

	public this(World world, Living shooter) {
		super(world, shooter, FORCE);
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.blazeFireball;
	}

	public override void tick() {
		super.tick();
		this.moved = false;
		this.motionmoved = false;
		if(this.ticks > 60) this.despawn();
	}

	public override bool onCollide(Entity entity) {
		if(cast(Living)entity) {
			//entity.to!Living.attack(new EntityDamagedByChildEvent(entity.to!Living, Damage.BLAZE_FIREBALL, 5, this.shooter, this));
			//TODO burn it with fire
			this.despawn();
			return true;
		}
		return false;
	}

}

class ExperienceBottle /*: Projectile*/ {

	public static immutable float WIDTH = .25f;
	public static immutable float HEIGHT = .25f;

	public static immutable float FORCE = 1f;

	public static immutable ACCELERATION = .05f;
	public static immutable DRAG = .01f;
	public static immutable TERMINAL_VELOCITY = 3f;

}

class Orb : Projectile {

	public static immutable float WIDTH = .3f;
	public static immutable float HEIGHT = .3f;

	public static immutable float FORCE = 2f;

	public static immutable float ACCELERATION = .04f;
	public static immutable float DRAG = .02f;
	public static immutable float TERMINAL_VELOCITY = 1.96f;

	public this(ref World world, Living shooter) {
		super(world, shooter, FORCE);
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2f;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.experienceOrb;
	}

}

class Potion : Projectile {

	public static immutable float WIDTH = .25f;
	public static immutable float HEIGHT = .25f;

	public static immutable float FORCE = 1f;

	public static immutable float ACCELERATION = .05f;
	public static immutable float DRAG = .01f;
	public static immutable float TERMINAL_VELOCITY = 3f;

	private ushort potion;

	public this(World world, Living shooter, ushort potion) {
		super(world, shooter, FORCE);
		this.potion = potion;
		//this.metadata[DATA_POTION_META] = potion;
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.splashPotion;
	}

	public override bool onCollide(Entity entity) {
		if(cast(Living)entity) {
			this.onCollide(entity.to!Living);
			return true;
		}
		return false;
	}

	public override bool onCollide(Block block, BlockPosition position, uint face) {
		this.onCollide();
		return true;
	}

	protected void onCollide(Living collider=null) {
		/*Effect effect = this.potion.to!ubyte.effect;
		Color color = effect !is null ? Effect.effectColor(effect.id) : new Color(0, 0, 0);
		ushort particle = effect !is null && (effect.id == Effects.HEALING || effect.id == Effects.HARMING) ? Particles.MOB_SPELL_INSTANTANEOUS : Particles.MOB_SPELL_AMBIENT;
		foreach(uint i ; 0..24) {
			this.world.addParticle(particle, this.position.round.add(this.world.random.next!float / 2f - .5f, 0f, this.world.random.next!float / 2f - .5f), color);
		}
		if(effect !is null) {
			auto radius = this.n_box.grow(4f, 2f);
			foreach(Living entity ; this.viewers!Living) {
				if(entity.box.intersects(radius)) {
					double d = entity.position.distance(this.position);
					if(d < 16) {
						double amount = 1 - (collider !is null && entity == collider ? 0 : sqrt(d) / 4);
						entity.addEffect(new Effect(effect.id, to!uint(amount * (effect.duration / 20) + .5f), effect.level, this.shooter), amount);
					}
				}
			}
		}
		this.despawn();*/
	}

}

class FallingBlock : Projectile {

	public static immutable float WIDTH = .98f;
	public static immutable float HEIGHT = .98f;

	public static immutable float ACCELERATION = .04f;
	public static immutable float DRAG = .02f;
	public static immutable float TERMINAL_VELOCITY = /*1.96f*/10f;

	private Block block;

	public this(World world, Block block, BlockPosition position) {
		super(world, position.entityPosition + [.5, .0001, .5], EntityPosition(0, 0, 0));
		this.setSize(WIDTH, HEIGHT);
		this.n_eye_height = HEIGHT / 2f;
		this.acceleration = ACCELERATION;
		this.drag = DRAG;
		this.terminal_velocity = TERMINAL_VELOCITY;
		this.setSize(.98, .98);
		this.block = block;
		this.metadata.set!"variant"(block.bedrockId | block.bedrockMeta << 8);
		this.n_data = block.javaId | block.javaMeta << 12;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.fallingBlock;
	}

	public override @property @safe bool motionless() {
		return false;
	}

	public override bool onCollide(Block block, BlockPosition position, uint face) {
		//TODO check the face
		BlockPosition pos = position + [0, 1, 0];
		if(this.world[pos] == Blocks.air) {
			this.world[pos] = &this.block;
			this.despawn();
			return true;
		}
		return false;
	}

}
