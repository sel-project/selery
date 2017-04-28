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
module hub.session.panel;

import std.socket : Socket, TcpSocket;

import hub.server : Server;
import hub.network.handler : HandlerThread;
import hub.network.session : Session;

class PanelHandler : HandlerThread {

	public this(shared Server server) {
		super(server, createSockets!TcpSocket("panel", server.settings.panelAddresses, 8));
	}

	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			auto client = socket.accept();

		}
	}

}

//class PanelSession : Session {}
