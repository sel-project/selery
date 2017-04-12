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
module sel.util.concurrency;

import core.thread : dur, Duration, thread_attachThis;
import std.concurrency : OwnerTerminated, receiveOnly, receiveTimeout, spawnLinked, Tid;
import std.conv : to;
import std.exception : enforce;

import common.crash : logCrash;
import common.util : UnloggedException;

import sel.server : isServerRunning, server;

Tid thread(T:Thread)() {
	return spawnLinked(&_thread!T);
}

void _thread(T:Thread)() {
	Thread th = new T();
	th.start();
}

class Thread {

	private bool n_running;
	protected Tid owner;

	public this() {}

	public final void start() {
		this.n_running = true;
		//thread_attachThis();
		this.owner = receiveOnly!Tid();
		try {
			this.run();
		} catch(OwnerTerminated) {

		} catch(UnloggedException e) {
			throw e;
		} catch(Throwable e) {
			if(isServerRunning) {
				// only log exceptions thrown when the server is running
				logCrash("node", server is null ? "en_GB" : server.settings.language, e);
				throw e;
			}
		}
	}

	public abstract void run();

	public bool receive(T...)(T ops) {
		return receiveTimeout(dur!"msecs"(0), (OwnerTerminated o) { this.stop(); }, ops);
	}

	public bool receiveT(T...)(uint timeout, T ops) {
		return receiveTimeout(dur!"msecs"(timeout), (OwnerTerminated o) { this.stop(); }, ops);
	}

	public @safe @nogc void stop() {
		this.n_running = false;
	}

	public final pure nothrow @property @safe @nogc bool running() {
		return this.n_running;
	}

}
