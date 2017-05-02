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
module sel.event.world.world;

import com.sel;

import sel.entity.entity : Entity;
import sel.event.event : Event, Cancellable;
import sel.math.vector : EntityPosition;
import sel.world.world : World;

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
