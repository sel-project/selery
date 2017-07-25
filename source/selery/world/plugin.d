module selery.world.plugin;

import std.algorithm : canFind;
import std.conv : to;
import std.datetime : Duration;
import std.traits : hasUDA, getUDAs, Parameters;

import selery.about : tick_t;
import selery.event.event : CancellableOf;
import selery.plugin : event, cancel, command, op, hidden;
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
				updateSymbols!(getStates!F)(getStates!F, oldState, newState, { world.registerCommand!F(del, c.command, c.description, c.aliases, hasUDA!(F, op), hasUDA!(F, hidden)); }, { world.unregisterCommand(c.command); });
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
