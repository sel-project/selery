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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/entity/entity.d, selery/entity/entity.d)
 */
module selery.entity.entity;

import core.atomic : atomicOp;

import std.algorithm : clamp;
import std.bitmanip : bigEndianToNative, nativeToBigEndian;
import std.conv : to;
import std.file : exists, read, write;
import std.math;
import std.random : uniform01;
import std.string : split, replace;
import std.traits : isArray, isAbstractClass;
import std.typecons : Tuple;
import std.uuid : UUID;

import selery.about;
import selery.block.block : Block, blockInto;
import selery.command.command : Position;
import selery.entity.metadata : Metadata;
import selery.event.event : EventListener;
import selery.event.world.damage;
import selery.event.world.world : WorldEvent;
import selery.item.slot : Slot;
import selery.math.vector;
import selery.node.server : NodeServer;
import selery.player.player : Player;
import selery.util.util : safe, call;
import selery.world.world : World;

static import sul.entities;
public import sul.entities : Entities;

/**
 * Base abstract class for every entity.
 */
abstract class Entity : EventListener!WorldEvent {

	private static uint count = -1;

	public static @safe @nogc uint reserveLocalId() {
		return count += 2; // always an odd number (starting from 1)
	}

	protected uint _id;
	protected UUID n_uuid;

	protected World n_world;

	private Entity[size_t] n_watchlist;
	private Entity[size_t] n_viewers; //edited by other entities

	public bool ticking = true;
	private tick_t n_ticks = 0;

	protected bool n_alive = true;

	public EntityPosition oldposition;
	protected EntityPosition m_position;
	protected EntityPosition m_last;
	protected EntityPosition m_motion;
	protected float m_yaw = 0;
	protected float m_body_yaw = 0;
	protected float m_pitch = 0;
	public bool moved = false;
	public bool motionmoved = false;

	private bool n_falling= false;
	protected bool n_on_ground;
	private float highestPoint;
	protected Entity last_puncher;

	protected double n_eye_height;

	private Entity m_vehicle;
	private Entity m_passenger;

	protected EntityAxis n_box;

	public Metadata metadata;

	protected uint n_data;

	protected float acceleration = 0;		// blocks/tick
	protected float drag = 0;				// percentage (0-1)
	protected float terminal_velocity = 0;	// blocks/tick

	public this() {
		// unusable entity
		this._id = 0;
	}

	public this(World world, EntityPosition position) {
		//assert(world !is null, "World can't be null");
		this._id = reserveLocalId();
		this.n_world = world;
		this.n_uuid = cast()this.server.nextUUID;
		this.m_position = this.m_last = this.oldposition = position;
		this.m_motion = EntityPosition(0, 0, 0);
		this.highestPoint = this.position.y;
		//TODO entity dimensions in space
		this.n_eye_height = 0;
		this.n_box = new EntityAxis(0, 0, this.position);
		this.metadata = new Metadata(); //TODO custom
	}

	public final pure nothrow @property @safe @nogc uint id() {
		return this._id;
	}

	public pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return sul.entities.Entity.init;
	}

	/**
	 * Gets the entity's type in a string format.
	 * Example:
	 * ---
	 * assert(creeper.type == "creeper");
	 * assert(witherSkull.type == "wither_skull");
	 * ---
	 */
	public pure nothrow @property @safe string type() {
		return this.data.name.replace(" ", "_");
	}

	/**
	 * Indicates whether the entity exists in Minecraft.
	 */
	public pure nothrow @property @safe @nogc bool java() {
		return this.data.java.exists;
	}

	public pure nothrow @property @safe @nogc ubyte javaId() {
		return this.data.java.id;
	}

	/**
	 * Indicates whether the entity exists in Minecraft.
	 */
	public pure nothrow @property @safe @nogc bool bedrock() {
		return this.data.bedrock.exists;
	}

	public pure nothrow @property @safe @nogc ubyte bedrockId() {
		return this.data.bedrock.id;
	}

	/**
	 * Gets the item's width.
	 * Returns: a number higher than 0 or double.nan if the entity has no size
	 */
	public pure nothrow @property @safe @nogc double width() {
		return this.data.width;
	}

	/**
	 * Gets the item's height.
	 * Returns: a number higher than 0 or double.nan if the entity has no size
	 */
	public pure nothrow @property @safe @nogc double height() {
		return this.data.height;
	}

	/**
	 * Indicates whether the entity is an object. If not the entity is
	 * a mob (living entity).
	 */
	public pure nothrow @property @safe @nogc bool object() {
		return this.data.object;
	}

	/**
	 * If the entity is an object gets the object's extra data used
	 * in Minecraft's SpawnObject packet.
	 */
	public final pure nothrow @property @safe @nogc int objectData() {
		return this.n_data;
	}

	/**
	 * Gets the unique identifier (UUID).
	 * It's usually randomly generated when the entity is
	 * created and it can only be changed by the child classes.
	 */
	public final pure nothrow @property @safe @nogc UUID uuid() {
		return this.n_uuid;
	}

	/**
	 * Gets the world the entity has been spawned into.
	 * Non-player entities should always have the same world for
	 * their whole life-cycle.
	 */
	public pure nothrow @property @safe @nogc World world() {
		return this.n_world;
	}

	public pure nothrow @property @safe @nogc shared(NodeServer) server() {
		return this.world.server;
	}

	// ticks the entity
	public void tick() {
		this.n_ticks++;
		if(this.vehicle !is null && this.vehicle.dead) this.vehicle = null;
		if(this.passenger !is null && this.passenger.dead) this.passenger = null;
		if(this.metadata.changed) {
			this.metadata.changed = false;
			this.broadcastMetadata();
		}
	}
	
	/**
	 * Gets the amount of ticks for this entity.
	 * The ticks doesn't indicates the life-time of the entity, but
	 * how many times it has been ticked by its world.
	 */
	public final pure nothrow @property @safe @nogc tick_t ticks() {
		return this.n_ticks;
	}

	public @property @trusted bool onFire() {
		return this.metadata.get!("onFire", bool)();
	}

	public @property @trusted bool onFire(bool flag) {
		return this.metadata.set!"onFire"(flag);
	}

	public @property @trusted bool sneaking() {
		return this.metadata.get!("sneaking", bool)();
	}

	public @property @trusted bool sneaking(bool flag) {
		return this.metadata.set!"sneaking"(flag);
	}

	public @property @trusted bool sprinting() {
		return this.metadata.get!("sprinting", bool)();
	}

	public @property @trusted bool sprinting(bool flag) {
		return this.metadata.set!"sprinting"(flag);
	}

	public @property @trusted bool usingItem() {
		return this.metadata.get!("usingItem", bool)();
	}

	public @property @trusted bool actionFlag(bool flag) {
		return this.metadata.set!"usingItem"(flag);
	}

	public @property @trusted bool invisible() {
		return this.metadata.get!("invisible", bool)();
	}

	public @property @trusted bool invisible(bool flag) {
		return this.metadata.set!"invisible"(flag);
	}

	public @property @trusted string nametag() {
		return this.metadata.get!("nametag", string)();
	}

	public @property @trusted string nametag(string nametag) {
		this.metadata.set!"nametag"(nametag);
		this.metadata.set!"customName"(nametag);
		return this.nametag;
	}

	public @property @trusted bool showNametag() {
		return this.metadata.get!("showNametag", bool)();
	}

	public @property @trusted bool showNametag(bool flag) {
		this.metadata.set!"showNametag"(flag);
		this.metadata.set!"alwaysShowNametag"(flag);
		return flag;
	}

	public @property @trusted bool noai() {
		return this.metadata.get!("noAi", bool)();
	}

	public @property @trusted bool noai(bool noai) {
		return this.metadata.set!"noAi"(noai);
	}

	/**
	 * Indicates which entities this one should and should not see.
	 * By default only the entities indicated as true by this function
	 * will be shown through the <a href="#Entity.show">show</a> function
	 * and added to the watchlist.
	 * For example, an arrow can see a painting, so Arrow.shouldSee(painting)
	 * will be true, but a painting shouldn't see an arrow, so Painting.shouldSee(arrow)
	 * will be false.
	 * This increases the performances as there are less controls, casts and operation
	 * on arrays in big worlds or chunks of worlds with an high concetration of entities.
	 */
	public @safe bool shouldSee(Entity entity) {
		return true;
	}

	/**
	 * Adds an entity to the ones this entity can see.
	 * Params:
	 * 		entity = the entity that will be showed to this entity
	 * Returns: true if the entity has been added to the visible entities, false otherwise
	 * Example:
	 * ---
	 * foreach(Player player ; world.players) {
	 *    player.show(entity);
	 *    entity.show(player);
	 * }
	 * ---
	 */
	public @safe bool show(Entity entity) {
		if(entity.id !in this.n_watchlist && entity.id != this.id) {
			this.n_watchlist[entity.id] = entity;
			entity.n_viewers[this.id] = this;
			return true;
		}
		return false;
	}

	/**
	 * Checks wether this entity can see or not another entity.
	 * Example:
	 * ---
	 * if(!player.sees(arrow)) {
	 *    player.show(arrow);
	 * }
	 * ---
	 */
	public @safe @nogc bool sees(Entity entity) {
		return entity.id in this.n_watchlist ? true : false;
	}

	/**
	 * Hides an entity from this entity, if this entity can see it.
	 * Params:
	 * 		entity = the entity to be hidden
	 * Returns: true if the entity has been hidden, false otherwise
	 * Example:
	 * ---
	 * foreach(Living living ; entity.watchlist!Living) {
	 *    entity.hide(living);
	 *    living.hide(entity);
	 * }
	 * ---
	 */
	public @safe bool hide(Entity entity) {
		if(entity.id in this.n_watchlist) {
			this.n_watchlist.remove(entity.id);
			entity.n_viewers.remove(this.id);
			return true;
		}
		return false;
	}

	/**
	 * Gets a list of the entities that this entity can see.
	 * Example:
	 * ---
	 * // every entity
	 * auto entities = entity.watchlist;
	 * 
	 * // every player
	 * auto players = entity.watchlist!Player;
	 * ---
	 */
	public final @property @trusted T[] watchlist(T:Entity=Entity)() {
		static if(is(T == Entity)) {
			return this.n_watchlist.values;
		} else {
			T[] ret;
			foreach(ref Entity entity ; this.n_watchlist) {
				if(cast(T)entity) ret ~= cast(T)entity;
			}
			return ret;
		}
	}

	/**
	 * Gets a list of the entities that can see this entity.
	 * See_Also: watchlist for the examples on the usage
	 */
	public final @property @trusted T[] viewers(T:Entity=Entity)() {
		static if(is(T == Entity)) {
			return this.n_viewers.values;
		} else {
			T[] ret;
			foreach(ref Entity entity ; this.n_viewers) {
				if(cast(T)entity) ret ~= cast(T)entity;
			}
			return ret;
		}
	}

	/**
	 * Despawns this entity, calling the event in the world.
	 */
	protected void despawn() {
		this.world.despawn(this);
	}

	public @safe @nogc void setAsDespawned() {
		this.n_alive = false;
	}

	/**
	 * Checks the dead/alive status of the entity.
	 * Example:
	 * ---
	 * assert(entity.alive ^ entity.dead);
	 * ---
	 */
	public @property @safe bool alive() {
		return this.n_alive;
	}

	/// ditto
	public @property @safe bool dead() {
		return !this.n_alive;
	}

	/**
	 * Gets the 16x16 chunk the entity is in.
	 * A bigger chunk can be obtained by right-shifting the vector
	 * by the required amount.
	 * Example:
	 * ---
	 * auto chunk = entity.chunk;
	 * auto chunk128 = entity.chunk >> 3;
	 * ---
	 */
	public final @property @safe ChunkPosition chunk() {
		return cast(ChunkPosition)this.position >> 4;
	}
	
	/**
	 * Gets the entity's position.
	 */
	public pure nothrow @property @safe @nogc EntityPosition position() {
		return this.m_position;
	}

	/**
	 * Gets the entity's motion.
	 */
	public pure nothrow @property @safe @nogc EntityPosition motion() {
		return this.m_motion;
	}

	/**
	 * Sets the entity's motion.
	 */
	public @property @safe EntityPosition motion(EntityPosition motion) {
		this.motionmoved = true;
		return this.m_motion = motion;
	}

	/**
	 * Checks whether or not an entity has motion.
	 * A motionless entity has every value of the motion's vector
	 * equal to 0.
	 */
	public @property @safe bool motionless() {
		return this.motion == 0;
	}

	/**
	 * Sets the entity as motionless.
	 * This is equivalent to motion = EntityPosition(0).
	 */
	public @property @safe bool motionless(bool motionless) {
		if(motionless) this.motion = EntityPosition(0, 0, 0);
		return this.motionless;
	}
	
	/**
	 * Gets the motion as pc's velocity, ready to be encoded
	 * in a packet.
	 * Due to this encoding limitation, the entity's motion should
	 * never be higher than 4.096 (2^15 / 8000).
	 * If it is, it will be clamped.
	 */
	public @property @safe Vector3!short velocity() {
		auto ret = this.motion * 8000;
		return Vector3!short(clamp(ret.x, short.min, short.max), clamp(ret.y, short.min, short.max), clamp(ret.z, short.min, short.max));
	}

	/**
	 * Gets the entity's looking direction (right-left).
	 * The value should always be in range 0..360.
	 */
	public final pure nothrow @property @safe @nogc float yaw() {
		return this.m_yaw;
	}

	/**
	 * Gets the yaw as an unsigned byte for encoding reasons.
	 * To obtain a valid value the yaw should be in its valid range
	 * from 0 to 360.
	 */
	public final @property @safe ubyte angleYaw() {
		return safe!ubyte(this.yaw / 360 * 256);
	}

	/**
	 * Gets the entity's body facing direction. This variable
	 * may not affect all the entities.
	 */
	public pure nothrow @property @safe @nogc float bodyYaw() {
		return this.m_body_yaw;
	}
	
	public final @property @safe ubyte angleBodyYaw() {
		return safe!ubyte(this.bodyYaw / 360 * 256);
	}

	/**
	 * Gets the entity's looking direction (up-down).
	 * The value should be in range -90..90 (90 included).
	 */
	public final pure nothrow @property @safe @nogc float pitch() {
		return this.m_pitch;
	}

	/**
	 * Gets the pitch as a byte for encoding reasons.
	 * To btain a valid value the pitch should be in its valid range
	 * from -90 to 90.
	 */
	public final @property @safe byte anglePitch() {
		return safe!byte(this.pitch / 90 * 64);
	}

	/**
	 * Boolean value indicating whether or not the player is touching
	 * the ground or is in it.
	 * This value is true even if the player is in a liquid (like water).
	 */
	public final pure nothrow @property @safe @nogc bool onGround() {
		return this.n_on_ground;
	}

	/**
	 * Gets the player's looking direction calculated from yaw and pitch.
	 * The return value is in range 0..1 and it should be multiplied to
	 * obtain the desired value.
	 */
	public final @property @safe EntityPosition direction() {
		float y = -sin(this.pitch * PI / 180f);
		float xz = cos(this.pitch * PI / 180f);
		float x = -xz * sin(this.yaw * PI / 180f);
		float z = xz * cos(this.yaw * PI / 180f);
		return EntityPosition(x, y, z);
	}

	/**
	 * Moves the entity.
	 */
	public @safe void move(EntityPosition position) {
		if(this.position != position) {
			this.n_box.update(position);
		}
		this.m_position = position;
		this.moved = true;
	}

	public void move(EntityPosition position, float yaw, float pitch) {
		this.m_yaw = yaw;
		this.m_pitch = pitch;
		this.move(position);
	}

	public void move(EntityPosition position, float yaw, float bodyYaw, float pitch) {
		this.m_body_yaw = bodyYaw;
		this.move(position, yaw, pitch);
	}

	/**
	 * Teleports the entity.
	 */
	public void teleport(EntityPosition position) {
		this.n_box.update(position);
		this.m_position = position;
		this.moved = true;
	}

	/// ditto
	public void teleport(EntityPosition position, float yaw, float pitch) {
		this.m_yaw = yaw;
		this.m_pitch = pitch;
		this.teleport(position);
	}

	/// ditto
	public void teleport(EntityPosition position, float yaw, float bodyYaw, float pitch) {
		this.m_body_yaw = bodyYaw;
		this.teleport(position, yaw, pitch);
	}

	/// ditto
	public void teleport(World world, EntityPosition position) {
		//TODO
	}

	/// ditto
	public void teleport(World world, EntityPosition position, float yaw, float pitch) {
		this.m_yaw = yaw;
		this.m_pitch = pitch;
		this.teleport(world, position);
	}

	/// ditto
	public void teleport(World world, EntityPosition position, float yaw, float bodyYaw, float pitch) {
		this.m_body_yaw = bodyYaw;
		this.teleport(world, position, yaw, pitch);
	}
	
	/// ditto
	public void teleport(Position position) {
		this.teleport(position.from(this.position));
	}
	
	/// ditto
	public void teleport(Position position, float yaw, float pitch) {
		this.teleport(position.from(this.position), yaw, pitch);
	}
	
	/// ditto
	public void teleport(Position position, float yaw, float bodyYaw, float pitch) {
		this.teleport(position.from(this.position), yaw, bodyYaw, pitch);
	}
	
	/// ditto
	public void teleport(World world, Position position) {
		this.teleport(world, position.from(this.position));
	}
	
	/// ditto
	public void teleport(World world, Position position, float yaw, float pitch) {
		this.teleport(world, position.from(this.position), yaw, pitch);
	}

	/// ditto
	public void teleport(World world, Position position, float yaw, float bodyYaw, float pitch) {
		this.teleport(world, position.from(this.position), yaw, bodyYaw, pitch);
	}

	/**
	 * Gets entity's sizes.
	 */
	public final pure nothrow @property @safe @nogc double eyeHeight() {
		return this.n_eye_height;
	}

	/**
	 * Does the onGround updates.
	 */
	protected void updateGroundStatus() {
		if(this.position.y >= this.m_last.y) {
			// going up
			this.highestPoint = this.position.y;
			this.n_falling = false;
			if(this.position.y != this.m_last.y) this.n_on_ground = false;
		} else {
			// free falling (check collision with the terrain)
			this.n_falling = true;
			this.n_on_ground = false;
			auto min = this.n_box.minimum;
			auto max = this.n_box.maximum;
			foreach(int x ; min.x.blockInto..max.x.blockInto+1) {
				foreach(int z ; min.z.blockInto..max.z.blockInto+1) {
					BlockPosition position = BlockPosition(x, to!int(this.position.y) - (to!int(this.position.y) == this.position.y ? 1 : 0), z);
					auto block = this.world[position];
					if(block.hasBoundingBox) {
						block.box.update(position.entityPosition);
						if(block.box.intersects(this.n_box)) {
							this.n_on_ground = true;
							this.doFallDamage(this.highestPoint - this.position.y, block.fallDamageModifier);
							this.highestPoint = this.position.y;
							this.last_puncher = null;
							goto BreakAll;
						}
					}
				}
			}
		}
		BreakAll:
		this.m_last = this.position;
	}

	protected @trusted void doFallDamage(float distance, float modifier=1) {
		int damage = to!int(round((distance - 3) * modifier));
		if(damage > 0) {
			if(this.last_puncher is null) {
				this.attack(new EntityFallDamageEvent(this, damage));
			} else {
				this.attack(new EntityDoomedToFallEvent(this, this.last_puncher, damage));
			}
		}
	}
	
	/**
	 * Boolean value indicating whether or not the entity
	 * is falling.
	 */
	public final pure nothrow @property @safe @nogc bool falling() {
		return !this.onGround && this.n_falling;
	}

	/**
	 * Does physic movements using the entity's parameters.
	 */
	protected @safe void doPhysic() {

		// update the motion
		if(this.acceleration != 0) this.motion = this.motion - [0, this.acceleration, 0];
		if(this.motion.y.abs > this.terminal_velocity) this.m_motion = EntityPosition(this.m_motion.x, this.motion.y > 0 ? this.terminal_velocity : -this.terminal_velocity, this.m_motion.z);
		
		// move
		this.move(this.position + this.motion/*, atan2(this.motion.x, this.motion.z) * 180f / PI, atan2(this.motion.y, sqrt(this.motion.x * this.motion.x + this.motion.z * this.motion.z)) * 180f / PI*/);
		
		// apply the drag force
		if(this.drag != 0) this.motion = this.motion * (1f - this.drag);

	}

	/**
	 * Checks collisions with the entities in the watchlist
	 * and calls onCollideWithEntity on collision.
	 */
	protected void checkCollisionsWithEntities() {
		foreach(ref Entity entity ; this.viewers) {
			if(entity.box.intersects(this.n_box) && this.onCollideWithEntity(entity)) return;
		}
	}
	
	/**
	 * Function called from checkCollisionWithEntities when
	 * this entity collides with another entity.
	 * Returns: false if the calling function should check for more collisions, true otherwise.
	 */
	protected bool onCollideWithEntity(Entity entity) {
		return false;
	}

	protected void checkCollisionsWithBlocks() {
		auto min = this.n_box.minimum;
		auto max = this.n_box.maximum;
		foreach(int x ; min.x.blockInto..max.x.blockInto+1) {
			foreach(int y ; min.y.blockInto..max.y.blockInto+1) {
				foreach(int z ; min.z.blockInto..max.z.blockInto+1) {
					auto position = BlockPosition(x, y, z);
					auto block = this.world[position];
					if(block.hasBoundingBox) {
						block.box.update(position.entityPosition);
						if(block.box.intersects(this.n_box) && this.onCollideWithBlock(block, position, 0)) return;
					}
				}
			}
		}
	}

	protected bool onCollideWithBlock(Block block, BlockPosition position, uint face) {
		return false;
	}
	
	/**
	 * Updates the size of the entity and its bounding box.
	 */
	public @safe void setSize(float width, float height) {
		this.n_box.update(width, height);
	}
	
	/**
	 * Gets the entity's bounding box.
	 */
	public final @property @safe @nogc EntityAxis box() {
		return this.n_box;
	}
	/++
	/**
	 * Gets the entity's width.
	 */
	public final @property @safe @nogc float width() {
		return this.box.width;
	}

	/**
	 * Gets the entity's height.
	 */
	public final @property @safe @nogc float height() {
		return this.box.height;
	}
	++/
	
	public final pure nothrow @property @safe @nogc float scale() {
		return 1f;
	}
	
	public final @property float scale(float scale) {
		version(Minecraft) {
			// throw exception
		}
		version(Pocket) {
			
		}
		return 1f;
	}
	
	/** Gets the entity's vechicle. */
	public @property @safe @nogc Entity vehicle() {
		return this.m_vehicle;
	}

	/** Sets the entity's vehicle. */
	protected @property @safe Entity vehicle(Entity vehicle) {
		return this.m_vehicle = vehicle;
	}

	/** Gets the entity's passenger. */
	public @property @safe Entity passenger() {
		return this.m_passenger;
	}

	/**
	 * Sets the entity's passenger.
	 * The vehicle of the passenger is set automatically.
	 * Example:
	 * ---
	 * Player player = "steve".player;
	 * Boat boat = world.spawn!Boat;
	 * 
	 * boat.passenger = player;
	 * assert(player.vehicle == boat);
	 * ---
	 */
	public @property Entity passenger(Entity passenger) {
		if(passenger !is null) {
			passenger.vehicle = this;
			this.viewers!Player.call!"sendPassenger"(cast(ubyte)3u, passenger.id, this.id);
		} else if(this.passenger !is null) {
			this.passenger.vehicle = null;
			this.viewers!Player.call!"sendPassenger"(cast(ubyte)0u, this.passenger.id, this.id);
		}
		this.m_passenger = passenger;
		return this.m_passenger;
	}

	/**
	 * Attacks an entity and returns the event used.
	 */
	public T attack(T:EntityDamageEvent)(T event) if(is(T == class) && !isAbstractClass!T) {
		if(this.validateAttack(event)) {
			this.world.callEvent(event);
			if(!event.cancelled) this.attackImpl(event);
		} else {
			event.cancel();
		}
		return event;
	}

	protected bool validateAttack(EntityDamageEvent event) {
		return false;
	}

	protected void attackImpl(EntityDamageEvent event) {

	}

	/**
	 * Send the metadata to the viewers
	 */
	protected void broadcastMetadata() {
		Player[] players = this.viewers!Player;
		if(players.length > 0) {
			foreach(ref Player player ; players) {
				player.sendMetadata(this);
			}
		}
	}

	/**
	 * Drop an item from this entity
	 */
	public void drop(Slot slot) {
		float f0 = uniform01!float(this.world.random) * PI * 2f;
		float f1 = uniform01!float(this.world.random) * .02f;
		this.world.drop(slot, this.position + [0, this.eyeHeight - .3, 0], this.direction * .3f + [cos(f0) * f1, (uniform01!float(this.world.random) - uniform01!float(this.world.random)) * .1f + .1f, sin(f0) * f1]);
	}

	public @property @safe string name() {
		return typeid(this).to!string.split(".")[$-1];
	}

	public @property @safe string displayName() {
		return this.name;
	}

	public override @safe bool opEquals(Object o) {
		return cast(Entity)o && (cast(Entity)o).id == this.id;
	}

	public override @safe string toString() {
		return typeid(this).to!string ~ "(" ~ to!string(this.id) ~ ")";
	}

}

enum Rotation : float {

	KEEP = float.nan,

	// yaw
	WEST = 0,
	NORTH = 90,
	EAST = 180,
	SOUTH = 270,

	// pitch
	DOWN = 90,
	FRONT = 0,
	UP = -90,

}

/**
 * A template for entities with changes on variables.
 * Example:
 * ---
 * // an entity on fire by default
 * alias OnFire(T) = Changed!(T, "this.onFire = true;");
 * Creeper creeper = world.spawn!(OnFire!Creeper);
 * assert(creeper.onFire);
 * 
 * // multiple changes can be used togheter
 * new OnFire!(Unticked!(Noai!Creeper))();
 * ---
 */
template VariableChanged(T:Entity, string changes) {

	class VariableChanged : T {

		public @safe this(E...)(E args) {
			super(args);
			mixin(changes);
		}

	}

	//alias VariableChanged = X;

}

/**
 * An entity without ticking.
 */
alias Unticked(T:Entity) = VariableChanged!(T, "this.ticking = false;");

/**
 * An Entity without AI.
 */
alias Noai(T:Entity) = VariableChanged!(T, "this.noai = true");

/**
 * An entity without ticking and AI.
 */
alias UntickedNoai(T:Entity) = VariableChanged!(T, "this.ticking = false;this.noai = true;");

/**
 * A template for entities with changing on functions.
 */
template FunctionChanged(T:Entity, string changes) {

	class FunctionChanged : T {

		mixin(changes);

	}

}

/**
 * An entity without physic.
 */
alias NoPhysic(T:Entity) = FunctionChanged!(T, "protected override void doPhysic(){}");

/**
 * An entity that doesn't take fall damage.
 */
alias NoFallDamage(T:Entity) = FunctionChanged!(T, "protected override void doFallDamage(float distance){}");
