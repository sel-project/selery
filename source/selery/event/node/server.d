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
module selery.event.node.server;

import selery.event.event : Event;
import selery.node.server : NodeServer;

abstract class NodeServerEvent : Event {
	
	private shared NodeServer _server;
	
	public pure nothrow @safe @nogc this(shared NodeServer server) {
		this._server = server;
	}
	
	public final pure nothrow @property @safe @nogc shared(NodeServer) server() {
		return this._server;
	}
	
}
