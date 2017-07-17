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
module selery.event.world.block;

import selery.block.block : Block;
import selery.event.event : Cancellable;
import selery.event.world.world : WorldEvent;
import selery.math.vector : BlockPosition;

interface BlockEvent : WorldEvent {

	public pure nothrow @property @safe @nogc Block block();

	public pure nothrow @property @safe @nogc BlockPosition position();

	public static mixin template Implementation() {

		private Block n_block;
		private BlockPosition n_position;

		public final override pure nothrow @property @safe @nogc Block block() {
			return this.n_block;
		}

		public final override pure nothrow @property @safe @nogc BlockPosition position() {
			return this.n_position;
		}

	}

}

interface BlockPlaceEvent : BlockEvent, Cancellable {}

interface BlockBreakEvent : BlockEvent, Cancellable {}
