/*
 * Copyright (c) 2017 SEL
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
module selery.entity.util;

import std.traits : isFinalClass, isAbstractClass;

import selery.entity.entity : Entity;

/**
 * Example:
 * ---
 * alias ZombieProjection = Projection!(Noai!Zombie, "direction-10,y+5");
 * auto zombie = world.spawn!ZombieProjection;
 * zombie.attach(player);
 * ---
 */
template Projection(T:Entity, string algorithm="") if(!isFinalClass!T && !isAbstractClass!T) {

	//TODO check algorithm

	class Projection : T {

		public this(E...)(E args) {
			super(args);
		}

		public override void tick() {
			super.tick();
			//TODO do programmed moves
		}

		public void attach(Player player) {
			player += &move_event;
		}

		public void move_event(PlayerMoveEvent event) {
			int x = event.position.x;
			int y = event.position.y;
			int z = event.position.z;
			//TODO move using the algorithm directives
			// [x y z direction] [+ - * / pow log] [float auto]
		}

	}

}

/**
 * Example:
 * ---
 * alias ChickenFollower = Follower!(Noai!Chicken);
 * auto chicken = world.spawn!ChickenFollower();
 * chicken.follow(player!"Kripth");
 * ---
 */
template Follower(T:Entity) if(!isFinalClass!T && !isAbstractClass!T) {

	class Follower : T {

		public this(E...)(E args) {
			super(args);
		}

		public void follow(Entity entity) {}

		public void unfollow() {}

	}

}
