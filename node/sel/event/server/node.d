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
module sel.event.server.node;

import sel.event.server : ServerEvent;
import sel.util.node : Node;

abstract class NodeEvent : ServerEvent {

	private const(Node) n_node;

	public pure nothrow @safe @nogc this(const(Node) node) {
		this.n_node = node;
	}

	public final pure nothrow @property @safe @nogc const(Node) node() {
		return this.n_node;
	}

}

final class NodeAddedEvent : NodeEvent {

	public pure nothrow @safe @nogc this(Node node) {
		super(node);
	}

}

final class NodeRemovedEvent : NodeEvent {

	public pure nothrow @safe @nogc this(Node node) {
		super(node);
	}

}

class NodeMessageEvent : NodeEvent {

	private ubyte[] n_payload;

	public pure nothrow @safe @nogc this(const(Node) node, ubyte[] payload) {
		super(node);
		this.n_payload = payload;
	}

	public final pure nothrow @property @safe @nogc ubyte[] payload() {
		return this.n_payload;
	}

	alias message = payload;

	public void reply(ubyte[] message) {

	}

}
