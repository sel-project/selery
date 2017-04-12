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
module sel.entity.noai;

import std.conv : to;

import common.sel;
import common.util : call;

import sel.settings;
import sel.block.block;
import sel.entity.entity;
import sel.entity.interfaces;
import sel.item.slot : Slot;
import sel.math.vector : BlockPosition, EntityPosition, entityPosition;
import sel.player.player : Player;
import sel.world.world : World;

static import sul.entities;

class ItemEntity : Entity, Collectable {

	public static immutable uint LIFETIME = 5 * 60 * 20;

	public static immutable uint PICKUP_DELAY = 1 * 20;

	public static immutable float WIDTH = .25;

	public static immutable float HEIGHT = .25;

	private Slot n_item;
	public bool pickUp = true;
	public uint delay = PICKUP_DELAY;

	public this(World world, EntityPosition position, EntityPosition motion, Slot item, bool noai=false) {
		super(world, position);
		assert(!item.empty, "Can't drop an empty slot!");
		this.n_data = 1;
		this.m_motion = motion;
		this.n_item = item;
		static if(__minecraft) {
			import sel.player.minecraft : MinecraftPlayerImpl;
			foreach(immutable i ; __minecraftProtocolsTuple) {
				mixin("this.metadata.minecraft" ~ to!string(i) ~ ".item = MinecraftPlayerImpl!" ~ to!string(i) ~ ".toSlot(item);");
			}
		}
		if(noai) {
			this.noai = true;
			this.ticking = false;
		}
		this.setSize(WIDTH, HEIGHT);
		this.acceleration = .05;
		this.terminal_velocity = 100;
		this.drag = .99;
	}

	public override pure nothrow @property @safe @nogc sul.entities.Entity data() {
		return Entities.DROPPED_ITEM;
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
		return Entities.LIGHTNING;
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
		return Entities.PAINTING;
	}

	public pure nothrow @property @safe @nogc string title() {
		return this.n_title;
	}

	public pure nothrow @property @safe @nogc uint direction() {
		return this.n_direction;
	}

}
