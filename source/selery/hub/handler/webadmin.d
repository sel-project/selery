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
module selery.hub.handler.webadmin;

import sel.net.http : StatusCodes, Request, Response;

import selery.hub.server : HubServer;

class WebAdminHandler {

	private shared HubServer server;

	public shared this(shared HubServer server) {
		this.server = server;
	}

	private shared Response handle(Request request) {
		switch(request.path) {
			case "/":
				//TODO return main page
				return Response(StatusCodes.ok, "Under construction");
			case "/connect":
				// do authentication if password is enabled
				immutable password = this.server.config.hub.webAdminPassword;
				if(password.length && password != request.data) {
					return Response(StatusCodes.forbidden);
				} else {
					return Response(StatusCodes.switchingProtocols);
					//TODO create client
				}
			default:
				return Response.error(StatusCodes.notFound);
		}
	}

}

class WebAdminClient {}
