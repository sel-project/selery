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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/world/world.d, selery/event/world/world.d)
 */
module selery.event.world.world;

import selery.about : tick_t;
import selery.entity.entity : Entity;
import selery.event.event : Event, Cancellable;
import selery.math.vector : EntityPosition;
import selery.world.world : World;

/**
 * Generic event related to the world.
 */
interface WorldEvent : Event {

	/**
	 * Gets the world where the event has happened.
	 */
	public pure nothrow @property @safe @nogc World world();

	public static mixin template Implementation() {

		private World n_world;

		public final override pure nothrow @property @safe @nogc World world() {
			return this.n_world;
		}

	}

}

/**
 * Called it starts to rain or snow in the world.
 */
final class StartRainEvent : WorldEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin WorldEvent.Implementation;

	private tick_t m_duration;

	public pure nothrow @safe @nogc this(World world, tick_t duration) {
		this.n_world = world;
		this.m_duration = duration;
	}

	/**
	 * Gets the duration of the precipitations is ticks.
	 */
	public pure nothrow @property @safe @nogc tick_t duration() {
		return this.m_duration;
	}

	/**
	 * Sets the duration of the precipitation in ticks.
	 * Example:
	 * ---
	 * event.duration = 1;
	 * ---
	 */
	public pure nothrow @property @safe @nogc tick_t duration(tick_t duration) {
		return this.m_duration = duration;
	}

}

/// ditto
alias StartSnowEvent = StartRainEvent;

/**
 * Event called when it stops to rain or snow in the world.
 */
final class StopRainEvent : WorldEvent {

	mixin WorldEvent.Implementation;

	public pure nothrow @safe @nogc this(World world) {
		this.n_world = world;
	}

}

/// ditto
alias StopSnowEvent = StopRainEvent;

/**
 * Event called when a lighting strikes in the world.
 */
final class LightningStrikeEvent : WorldEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin WorldEvent.Implementation;

	private EntityPosition n_position;
	private Entity n_target;

	public pure nothrow @safe @nogc this(World world, EntityPosition position) {
		this.n_world = world;
		this.n_position = position;
	}

	public pure nothrow @safe @nogc this(World world, Entity target) {
		this(world, target.position);
		this.n_target = target;
	}

	/**
	 * Gets the position where the lightning has struck.
	 */
	public pure nothrow @property @safe @nogc EntityPosition position() {
		return this.n_position;
	}

	/**
	 * Gets the target of the lightning, it may be null if the lightning
	 * struck randomly.
	 */
	public pure nothrow @property @safe @nogc Entity target() {
		return this.n_target;
	}

}

interface ExplosionEvent : WorldEvent, Cancellable {

	public pure nothrow @property @safe @nogc float power();

	public pure nothrow @property @safe @nogc float power(float power);

	mixin template Implementation() {

		mixin Cancellable.Implementation;

		private float m_power;

		public override pure nothrow @property @safe @nogc float power() {
			return this.m_power;
		}

		public override pure nothrow @property @safe @nogc float power(float power) {
			return this.m_power = power;
		}

	}

}
