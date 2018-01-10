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

import core.thread : Thread;

import std.concurrency : spawn;
import std.datetime : dur;
import std.json;
import std.random : uniform;
import std.socket : Socket, TcpSocket, Address, SocketOption, SocketOptionLevel;
import std.string : startsWith;

import sel.net.http : StatusCodes, Request, Response;
import sel.server.query : Query;
import sel.server.util : GenericServer;

import selery.about : Software;
import selery.hub.server : HubServer;

class WebAdminHandler : GenericServer {

	private shared HubServer server;

	private shared string login, admin;

	private shared string[string] sessions;

	public shared this(shared HubServer server) {
		super(server.info);
		this.server = server;
		with(server.config.files) {
			this.login = cast(string)readAsset("webadmin/login.html");
			this.admin = cast(string)readAsset("webadmin/admin.html");
		}
	}

	protected override shared void startImpl(Address address, shared Query query) {
		Socket socket = new TcpSocket(address.addressFamily);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		socket.blocking = true;
		socket.bind(address);
		socket.listen(8);
		spawn(&this.acceptClients, cast(shared)socket);
	}
	
	private shared void acceptClients(shared Socket _socket) {
		debug Thread.getThis().name = "web_admin_server@" ~ (cast()_socket).localAddress.toString();
		Socket socket = cast()_socket;
		while(true) {
			Socket client = socket.accept();
			client.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(5000));
			this.handleClient(client); //TODO use spawn
		}
	}

	private shared void handleClient(Socket socket) {
		char[] buffer = new char[1024];
		auto recv = socket.receive(buffer);
		if(recv > 0) {
			Response response = this.handle(socket.remoteAddress, Request.parse(buffer[0..recv].idup));
			response.headers["Server"] = Software.display;
			socket.send(response.toString());
		}
		socket.close();
	}

	private shared Response handle(Address address, Request request) {
		if(request.path == "/") {
			bool auth = false;
			auto cookie = "cookie" in request.headers;
			if(cookie && startsWith(*cookie, "key=")) {
				auto ip = (*cookie)[4..$] in this.sessions;
				if(ip && *ip == address.toAddrString()) auth = true;
			}
			if(!auth) {
				// send login page or create a session
				if(this.server.config.hub.webAdminPassword.length) {
					// password is required, send login form
					return Response(StatusCodes.ok, this.login);
				} else {
					immutable key = this.addClient(address);
					if(key.length) return Response(StatusCodes.ok, ["Set-Cookie": "key=" ~ key], this.admin);
					else return Response(StatusCodes.ok, "Limit reached");
				}
			} else {
				if(request.method == Request.POST) {
					// authenticated client trying to do stuff
					try {
						JSONValue[string] response;
						void parseResponse(JSONValue json) {
							auto action = "action" in json.object;
							if(action) {
								switch((*action).str) {
									case "multi":
										// {"action": "multi", "data": [ ... ]}
										auto data = "data" in json.object;
										if(data) {
											JSONValue[string] ret;
											foreach(element ; (*data).array) {
												parseResponse(element);
											}
										}
										break;
									case "get_info":
										with(this.server.info) {
											response["motd"] = motd.raw;
											response["online"] = online;
											response["max"] = max;
											response["favicon"] = favicon;
										}
										break;
									case "get_players":
										JSONValue[] players;
										foreach(player ; this.server.players) {
											JSONValue[string] ret;
											ret["id"] = player.id;
											ret["type"] = player.type;
											ret["name"] = player.username;
											ret["display_name"] = player.displayName;
											ret["game"] = player.game;
											players ~= JSONValue(ret);
										}
										response["players"] = players;
										break;
									case "get_player_permissions":

										break;
									case "get_nodes":
										// also send worlds
										break;
									case "set_max":
										// of one node
										break;
									case "player_kick":

										break;
									default:
										break;
								}
							}
						}
						parseResponse(parseJSON(request.data));
						if(response.length) return Response(StatusCodes.ok, ["Content-Type": "application/json"], JSONValue(response).toString());
					} catch(JSONException) {}
					return Response(StatusCodes.badRequest);
				} else {
					// check credentials and send homepage
					return Response(StatusCodes.ok, this.admin);
				}
			}
		} else if(request.path == "/login" && request.method == Request.POST) {
			// authentication attemp
			immutable password = this.server.config.hub.webAdminPassword;
			if(request.data == this.server.config.hub.webAdminPassword) {
				immutable key = this.addClient(address);
				if(key.length) return Response(StatusCodes.ok, key);
				else return Response(StatusCodes.ok, "limit reached");
			} else {
				return Response(StatusCodes.ok, "Wrong password");
			}
		} else if(request.path == "/style.css") {
			//TODO send stylesheet
		}
		return Response.error(StatusCodes.notFound);
	}

	private shared string addClient(Address address) {
		immutable ip = address.toAddrString();
		immutable key = randomKey();
		this.sessions[key] = ip;
		return key;
	}

	public override shared pure nothrow @property @safe @nogc ushort defaultPort() {
		return ushort(19134);
	}

}

private enum keys = "abcdefghijklmonpqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-+$!";

private @property string randomKey() {
	char[] key = new char[24];
	foreach(ref char c ; key) {
		c = keys[uniform!"[)"(0, keys.length)];
	}
	return key.idup;
}
