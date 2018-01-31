/*
 * Copyright (c) 2017-2018 sel-project
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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/node/node.d, selery/event/node/node.d)
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
