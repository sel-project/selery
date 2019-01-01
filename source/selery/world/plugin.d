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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/world/plugin.d, selery/world/plugin.d)
 */
module selery.world.plugin;

import std.algorithm : canFind;
import std.conv : to;
import std.datetime : Duration;
import std.traits : hasUDA, getUDAs, Parameters;

import selery.about : tick_t;
import selery.event.event : CancellableOf;
import selery.plugin : event, cancel, command, op, hidden, permissionLevel, permission, unimplemented;
import selery.world.world : World;

void loadWorld(T:World)(T world, int oldState, uint newState) {

	// oldState is -1 and newState is 0 when the world is loaded for the first time

	foreach_reverse(member ; __traits(allMembers, T)) {
		static if(is(typeof(__traits(getMember, T, member)) == function)) {
			mixin("alias F = T." ~ member ~ ";");
			static if(hasUDA!(F, task)) {
				static assert(getUDAs!(F, task).length == 1);
				auto del = mixin("&world." ~ member);
				updateSymbols!(getStates!F)(getStates!F, oldState, newState, { world.addTask(del, getUDAs!(F, task)[0].ticks); }, { world.removeTask(del); });
			}
			static if(hasUDA!(F, command)) {
				static assert(getUDAs!(F, command).length == 1);
				auto del = mixin("&world." ~ member);
				enum c = getUDAs!(F, command)[0];
				static if(hasUDA!(F, permissionLevel)) enum pl = getUDAs!(F, permissionLevel)[0].permissionLevel;
				else enum ubyte pl = 0;
				static if(hasUDA!(F, permission)) enum p = getUDAs!(F, permission)[0].permissions;
				else enum string[] p = [];
				updateSymbols!(getStates!F)(getStates!F, oldState, newState, { world.registerCommand!F(del, c.command, c.description, c.aliases, pl, p, hasUDA!(F, hidden), !hasUDA!(F, unimplemented)); }, { world.unregisterCommand(c.command); });
			}
			static if(hasUDA!(F, event)) {
				static assert(Parameters!F.length == 1);
				static if(hasUDA!(F, cancel)) {
					auto del = &CancellableOf.instance.createCancellable!(Parameters!F[0]);
				} else {
					auto del = mixin("&world." ~ member);
				}
				updateSymbols!(getStates!F)(getStates!F, oldState, newState, { world.addEventListener(del); }, { world.removeEventListener(del); });
			}
		}
	}

}

template updateSymbols(uint[] states) {
	static if(states.length) alias updateSymbols = updateSymbolsWithStates;
	else alias updateSymbols = updateSymbolsWithoutStates;
}

void updateSymbolsWithStates(uint[] states, int oldState, uint newState, lazy void delegate() add, lazy void delegate() remove) {
	immutable bool registered = states.canFind(oldState);
	immutable bool needed = states.canFind(newState);
	if(registered && !needed) remove()();
	else if(needed && !registered) add()();
}

void updateSymbolsWithoutStates(uint[] states, int oldState, uint newState, lazy void delegate() add, lazy void delegate() remove) {
	if(oldState == -1) add()();
}

uint[] getStates(alias fun)() {
	uint[] states;
	foreach(s ; getUDAs!(fun, state)) {
		states ~= s.states;
	}
	return states;
}

struct task {

	tick_t ticks;

	public this(tick_t ticks) {
		assert(ticks != 0);
		this.ticks = ticks;
	}

	public this(Duration duration) {
		assert(duration.total!"msecs"() % 50 == 0);
		this(to!tick_t(duration.total!"msecs"() / 50));
	}

}

struct state {

	private uint[] states;

	public this(uint[] states...) {
		this.states = states;
	}

}
