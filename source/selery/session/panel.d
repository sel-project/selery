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
module selery.session.panel;

import std.socket : Socket, TcpSocket;

import selery.hub.server : HubServer;
import selery.network.handler : HandlerThread;
import selery.network.session : Session;

class PanelHandler : HandlerThread {

	public this(shared HubServer server) {
		with(server.config.hub) super(server, createSockets!TcpSocket(server, "panel", panelAddresses, panelPort, 8));
	}

	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		/*while(true) {
			auto client = socket.accept();
			//TODO
		}*/
	}

}

//class PanelSession : Session {}
