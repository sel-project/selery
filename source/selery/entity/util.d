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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/entity/util.d, selery/entity/util.d)
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
