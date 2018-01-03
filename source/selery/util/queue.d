/*
 * Copyright (c) 2017-2018 SEL
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
module selery.util.queue;

import selery.network.session : Session;

interface Queueable {

	public shared nothrow @property @safe @nogc uint queueId();

}

synchronized class Queue(T : Queueable) {

	private shared(T)[] n_sessions = [];

	public shared this() {}

	/**
	 * Pushes a new session into the queue.
	 */
	public shared void push(shared T session) {
		// this crashes in release mode (windows)
		this.n_sessions ~= session;
	}

	/**
	 * Removes a session from the queue.
	 * Returns: true if the session has been removed, false otherwise
	 */
	public shared bool remove(shared T session) {
		foreach(i, s; this.n_sessions) {
			if(session.queueId == s.queueId) {
				// array concatenation causes a crash in release mode (windows)
				this.n_sessions = this.n_sessions[0..i] ~ this.n_sessions[i+1..$];
				return true;
			}
		}
		return false;
	}

	/**
	 * Gets the sessions in the queue.
	 */
	public nothrow @property @safe @nogc shared(T)[] sessions() {
		return this.n_sessions;
	}

}
