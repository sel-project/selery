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
module sel.event.event;

import std.algorithm : sort, canFind;
import std.base64 : Base64Impl;
import std.conv : to;
import std.typecons : Tuple;
import std.typetuple : TypeTuple;
import std.traits : isAbstractClass, BaseClassesTuple, InterfacesTuple;

import sel.util;

alias size_t class_t;

private @safe class_t hash(T)() if(is(T == class) || is(T == interface)) {
	size_t result = 1;
	foreach(ubyte data ; Base64Impl!('.', '_', '=').decode((){ string mangle=T.mangleof;while(mangle.length%4!=0){mangle~="=";}return mangle; }())) {
		result ^= (result >> 8) ^ ~(size_t.max / data);
	}
	return result;
}

/*
 * Storage for event's delegates with the event casted
 * to a generic void pointer.
 */
private alias Delegate = Tuple!(void delegate(void*), "del", size_t, "count");

/*
 * Storage for callable events (already casted to the right
 * type) ready to be ordered and called.
 */
private alias Callable = Tuple!(void delegate(), "call", size_t, "count");

/*
 * Count variable shared between every event listener to
 * maintain a global registration order.
 */
private size_t count = 0;

/**
 * Generic event listener.
 */
class EventListener(O:Event, Children...) if(areValidChildren!(O, Children)) {

	private Delegate[][class_t] delegates;

	public @trusted size_t addEventListener(T)(void delegate(T) listener) if(is(T == class) && is(T : O) || is(T == interface)) {
		this.delegates[hash!T] ~= Delegate(cast(void delegate(void*))listener, count);
		return count++;
	}

	/// ditto
	public @safe opOpAssign(string op : "+", T)(void delegate(T) listener) {
		return this.addEventListener(listener);
	}

	public @safe void setListener(E...)(EventListener!(O, E) listener) {
		foreach(hash, delegates; listener.delegates) {
			foreach(del ; delegates) {
				this.delegates[hash] ~= Delegate(del.del, del.count);
			}
		}
	}

	/**
	 * Removes an event listener using its delegate pointer.
	 */
	public @trusted bool removeEventListener(T)(void delegate(T) listener) {
		bool removed = false;
		auto ptr = hash!T in this.delegates;
		if(ptr) {
			foreach(i, del; *ptr) {
				if(cast(void delegate(T))del.del == listener) {
					*ptr = (*ptr)[0..i] ~ (*ptr)[i+1..$];
					removed = true;
				}
			}
		}
		return removed;
	}

	/// ditto
	public @safe bool opOpAssign(string op : "-", T)(void delegate(T) listener) {
		return this.removeEventListener(listener);
	}

	/**
	 * Removes an event listener using its assigned id.
	 */
	public @safe bool removeEventListener(size_t count) {
		foreach(i, delegates; this.delegates) {
			foreach(j, del; delegates) {
				if(del.count == count) {
					this.delegates[i] = delegates[0..j] ~ delegates[j+1..$];
					return true;
				}
			}
		}
		return false;
	}

	/// ditto
	public @safe bool opOpAssign(string op : "-")(size_t count) {
		return this.removeEventListener(count);
	}
	
	/**
	 * Returns: the instance of the event
	 */
	public void callEvent(T:O)(ref T event) if(is(T == class) && !isAbstractClass!T) {
		Callable[] callables = this.callablesOf(event);
		if(callables.length) {
			sort!"a.count < b.count"(callables);
			foreach(callable ; callables) {
				callable.call();
				static if(is(T : Cancellable)) {
					if(event.cancelled) break;
				}
			}
		}
	}

	public Callable[] callablesOf(T:O)(ref T event) if(is(T == class) && !isAbstractClass!T) {
		import sel.util.log;
		Callable[] callables;
		foreach_reverse(E ; TypeTuple!(T, BaseClassesTuple!T[0..$-1], InterfacesTuple!T)) {
			auto ptr = hash!E in this.delegates;
			if(ptr) {
				foreach(i,del ; *ptr) {
					callables ~= this.createCallable!E(event, del.del, del.count);
				}
			}
		}
		static if(Children.length) {
			foreach(immutable i, C; Children) {
				static if(i % 2 == 0 && is(T : C)) {
					mixin("callables ~= event." ~ Children[i+1] ~ ".callablesOf(event);");
				}
			}
		}
		return callables;
	}
	
	private Callable createCallable(E, T)(ref T event, void delegate(void*) del, size_t count) {
		return Callable((){(cast(void delegate(E))del)(event);}, count);
	}

	public T callEventIfExists(T:O, E...)(E args) if(is(T == class) && !isAbstractClass!T && __traits(compiles, new T(args))) {
		T event = new T(args);
		this.callEvent(event);
		return event;
	}

	/**
	 * Returns: true if the event has been cancelled, false otherwise
	 */
	public bool callCancellableIfExists(T:O, E...)(E args) if(is(T == class) && !isAbstractClass!T && __traits(compiles, new T(args)) && is(T : Cancellable)) {
		T event = this.callEventIfExists!T(args);
		return event !is null && event.cancelled;
	}

}

private bool areValidChildren(T, C...)() {
	static if(C.length % 2 != 0) return false;
	foreach(immutable i, E; C) {
		static if(i % 2 == 0) {
			static if(!is(E : T)) return false;
		} else {
			static if(!__traits(hasMember, C[i-1], E)) return false;
		}
	}
	return true;
}

interface Event {}

interface Cancellable {

	public pure nothrow @safe @nogc void cancel();

	public pure nothrow @property @safe @nogc bool cancelled();

	public static mixin template Implementation() {

		private bool n_cancelled;

		public override pure nothrow @safe @nogc void cancel() {
			this.n_cancelled = true;
		}

		public override pure nothrow @property @safe @nogc bool cancelled() {
			return this.n_cancelled;
		}

	}

	public static mixin template FinalImplementation() {

		public final override pure nothrow @safe @nogc void cancel() {
			super.cancel();
		}

		public final override pure nothrow @property @safe @nogc bool cancelled() {
			return super.cancelled();
		}

	}

}
