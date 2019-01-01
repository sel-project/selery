/*
 * Copyright (c) 2017-2019 sel-project
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
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/entity/noai.d, selery/entity/noai.d)
 */
module selery.entity.noai;

import std.conv : to;

import selery.about;
import selery.block.block;
import selery.entity.entity;
import selery.entity.interfaces;
import selery.item.slot : Slot;
import selery.math.vector : BlockPosition, EntityPosition, entityPosition;
import selery.player.player : Player;
import selery.util.util : call;
import selery.world.world : World;

static import sul.entities;

class ItemEntity : Entity, Collectable {

	public static immutable uint LIFETIME = 5 * 60 * 20;

	public static immutable uint PICKUP_DELAY = 1 * 20;

	public static immutable float WIDTH = .25;

	public static immutable float HEIGHT = .25;

	private Slot n_item;
	public bool pickUp = true;
	public uint delay = PICKUP_DELAY;

	public this(World world, EntityPosition position, EntityPosition motion, Slot item) {
		super(world, position);
		assert(!item.empty, "Can't drop an empty slot!");
		this.n_data = 1;
		this.m_motion = motion;
		this.n_item = item;
		static if(supportedJavaProtocols.length) {
			import selery.player.java : JavaPlayerImpl;
			foreach(immutable i ; SupportedJavaProtocols) {
				mixin("this.metadata.java" ~ to!string(i) ~ ".item = JavaPlayerImpl!" ~ to!string(i) ~ ".toSlot(item);");
			}
		}
		this.setSize(WIDTH, HEIGHT);
		this.acceleration = .05;
		this.terminal_velocity = 100;
		this.drag = .99;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.droppedItem;
	}

	public override void tick() {
		super.tick();
		if(this.ticks > LIFETIME) {
			this.despawn();
		}
		if(this.delay > 0) {
			this.delay--;
		} else {
			// check for pickup
			/+foreach(Entity entity ; this.watchlist) {
				if(cast(Collector)entity && this.box.grow(.25, .25).intersects(entity.box)) {
					if((cast(Collector)entity).onCollect(this)) {
						this.viewers!Player.call!"sendPickupItem"(entity, this);
						this.despawn();
						return;
					}
				}
			}+/
		}

		//TODO check if it's into a block

		//this.doPhysic();

	}

	public pure nothrow @property @safe @nogc Slot item() {
		return this.n_item;
	}

	alias slot = item;

	public override @trusted bool shouldSee(Entity entity) {
		return cast(Collector)entity || (cast(ItemEntity)entity && this.item.item == (cast(ItemEntity)entity).item.item);
	}

}

final class Lightning : Entity {

	public this(World world, EntityPosition position) {
		super(world, position);
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.lightning;
	}

	public override void tick() {
		super.tick();
		if(this.ticks == 4) {
			//TODO fire
			//TODO strike the entities
			super.despawn();
		}
	}

}

final class Painting : Entity {

	public static immutable string KEBAB = "Kebab"; 
	public static immutable string AZTEC = "Aztec"; 
	public static immutable string ALBAN = "Alban"; 
	public static immutable string AZTEC2 = "Aztec2"; 
	public static immutable string BOMB = "Bomb"; 
	public static immutable string PLANT = "Plant"; 
	public static immutable string WASTELAND = "Wasteland";
	public static immutable string POOL = "Pool"; 
	public static immutable string COURBET = "Courbet"; 
	public static immutable string SEA = "Sea"; 
	public static immutable string SUNSET = "Sunset"; 
	public static immutable string CREEBET = "Creebet"; 
	public static immutable string WANDERER = "Wanderer";
	public static immutable string GRAHAM = "Graham"; 
	public static immutable string MATCH = "Match"; 
	public static immutable string BUST = "Bust"; 
	public static immutable string STAGE = "Stage";
	public static immutable string VOID = "Void"; 
	public static immutable string SKULL_AND_ROSES = "SkullAndRoses"; 
	public static immutable string WITHER = "Wither"; 
	public static immutable string FIGHTERS = "Fighters"; 
	public static immutable string POINTER = "Pointer"; 
	public static immutable string PIGSCENE = "PigScene"; 
	public static immutable string BURNINGSKULL = "BurningSkull"; 
	public static immutable string SKELETON = "Skeleton"; 
	public static immutable string DONKEYKONG = "DonkeyKong";

	public bool ticking = false;

	private string n_title;
	private uint n_direction;

	public this(World world, BlockPosition position, string title, uint direction) {
		super(world, position.entityPosition);
		this.n_title = title;
		this.n_direction = direction;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.painting;
	}

	public pure nothrow @property @safe @nogc string title() {
		return this.n_title;
	}

	public pure nothrow @property @safe @nogc uint direction() {
		return this.n_direction;
	}

}
