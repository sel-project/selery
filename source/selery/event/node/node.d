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
module selery.event.node.node;

import selery.event.node.server : NodeServerEvent;
import selery.node.server : NodeServer;
import selery.util.node : Node;

abstract class NodeEvent : NodeServerEvent {

	protected Node _node;

	public pure nothrow @safe @nogc this(Node node) {
		super(node.server);
		this._node = node;
	}

	public final pure nothrow @property @safe @nogc const(Node) node() {
		return this._node;
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

	private ubyte[] _payload;

	public pure nothrow @safe @nogc this(Node node, ubyte[] payload) {
		super(node);
		this._payload = payload;
	}

	public final pure nothrow @property @safe @nogc ubyte[] payload() {
		return this._payload;
	}

	alias message = payload;

	public void reply(ubyte[] message) {
		this._node.sendMessage(message);
	}

}
