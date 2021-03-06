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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/world/block.d, selery/event/world/block.d)
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
