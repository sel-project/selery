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

import sel.entity.entity : Entity;
import sel.event.event : Event, Cancellable;
import sel.math.vector : EntityPosition;
import sel.world.world : World;

/** Base world event */
interface WorldEvent : Event {

	public pure nothrow @property @safe @nogc World world();

	public static mixin template Implementation() {

		private World n_world;

		public final override pure nothrow @property @safe @nogc World world() {
			return this.n_world;
		}

	}

}

/** Generic weather event that can be cancelled with event.cancel() */
abstract class WeatherEvent : WorldEvent, Cancellable {
	
	mixin Cancellable.Implementation;
	
	mixin WorldEvent.Implementation;

	public @safe @nogc this(World world) {
		this.n_world = world;
	}

}

/** 
 * Generic atmospheric event
 * Params:
 * 		active: true if the atmospheric event is starting, false otherwise
 * 		time: if the event is starting, the duration in ticks of the atmospheric event
 */
abstract class AtmosphericEvent : WeatherEvent {
	
	public immutable bool active;
	public uint time;
	
	public @safe @nogc this(World world, bool active, uint time) {
		super(world);
		this.active = active;
		this.time = time;
	}
	
}

/** Generic precipitation event (rain and snow) */
abstract class PrecipitationEvent : AtmosphericEvent {

	public @safe @nogc this(World world, bool active, uint time) {
		super(world, active, time);
	}

	alias raining = this.active;
	alias snowing = this.active;

}

/** Called when precipitations start */
final class PrecipitationStartEvent : PrecipitationEvent {

	public @safe @nogc this(World world, uint time) {
		super(world, true, time);
	}

}

/** Called when precipitations end */
final class PrecipitationEndEvent : PrecipitationEvent {

	public @safe @nogc this(World world) {
		super(world, false, 0);
	}

}

/** Generic storm event (if raining/snowing lighting can randmly strike) */
abstract class StormEvent : AtmosphericEvent {

	public @safe @nogc this(World world, bool active, uint time) {
		super(world, active, time);
	}

}

/** Called when a strom starts */
final class StormStartEvent : StormEvent {

	public @safe @nogc this(World world, uint time) {
		super(world, true, time);
	}

}

/** Called when a strom ends */
final class StormEndEvent : StormEvent {

	public @safe @nogc this(World world) {
		super(world, false, 0);
	}

}

/**
 * Called when a lighting strike in the world
 * if the lightning strikes an entity, target will contains it
 */
final class LightningStrikeEvent : WeatherEvent {

	private EntityPosition n_position;
	private Entity n_target;

	public @safe @nogc this(World world, EntityPosition position) {
		super(world);
		this.n_position = position;
	}

	public @safe @nogc this(World world, Entity target) {
		this(world, target.position);
		this.n_target = target;
	}

	public @property @safe @nogc EntityPosition position() {
		return this.n_position;
	}

	public @property @safe @nogc Entity target() {
		return this.n_target;
	}

}
