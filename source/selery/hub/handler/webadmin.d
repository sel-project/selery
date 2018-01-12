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
import std.string : startsWith, split, replace;

import sel.net.http : StatusCodes, Request, Response;
import sel.server.query : Query;
import sel.server.util : GenericServer;

import selery.about : Software;
import selery.hub.server : HubServer;
import selery.util.diet;

class WebAdminHandler : GenericServer {

	private shared HubServer server;

	private shared string style, bg, lock_locked, lock_unlocked;

	private shared string[string] sessions;

	public shared this(shared HubServer server) {
		super(server.info);
		this.server = server;
		with(server.config.files) {
			this.style = cast(string)readAsset("web/styles/main.css");
			this.bg = cast(string)readAsset("web/res/bg32.png");
			this.lock_locked = cast(string)readAsset("web/res/lock_locked.png");
			this.lock_unlocked = cast(string)readAsset("web/res/lock_unlocked.png");
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

	private shared string getClientLanguage(Request request) {
		auto lang = "accept-language" in request.headers;
		if(lang) {
			foreach(l1 ; split(*lang, ";")) {
				foreach(l2 ; split(l1, ",")) {
					if(l2.length == 5) {
						immutable language = l2.replace("-", "_");
						foreach(supported ; this.server.config.hub.acceptedLanguages) {
							if(supported == language) return language;
						}
					}
				}
			}
		}
		return this.server.config.hub.language;
	}

	private shared Response handle(Address address, Request request) {
		if(request.path == "/") {
			bool auth = false;
			auto cookie = "cookie" in request.headers;
			if(cookie && startsWith(*cookie, "key=")) {
				auto ip = (*cookie)[4..$] in this.sessions;
				if(ip && *ip == address.toAddrString()) auth = true;
			}
			if(auth && request.method == Request.POST) {
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
				// send login page or create a session
				immutable lang = this.getClientLanguage(request);
				string translate(string text, string[] params...) {
					return this.server.config.lang.translate(text, lang, params);
				}
				if(auth) {
					// just logged in, needs the admin panel
					return Response(StatusCodes.ok, compileDietFile!("admin.dt", translate));
				} else if(this.server.config.hub.webAdminPassword.length) {
					// password is required, send login form
					return Response(StatusCodes.ok, compileDietFile!("login.dt", translate));
				} else {
					// not logged in, but password is not required
					immutable key = this.addClient(address);
					if(key.length) return Response(StatusCodes.ok, ["Set-Cookie": "key=" ~ key], compileDietFile!("admin.dt", translate));
					else return Response(StatusCodes.ok, "Limit reached");
				}
			}
		} else if(request.path == "/login" && request.method == Request.POST) {
			// authentication attemp
			string password;
			try password = parseJSON(request.data).object.get("password", JSONValue.init).str;
			catch(JSONException) {}
			JSONValue[string] result;
			if(password == this.server.config.hub.webAdminPassword) { //TODO fix sel-net's parser
				immutable key = this.addClient(address);
				if(key.length) result["key"] = key;
				else result["error"] = "limit";
			} else {
				result["error"] = "wrong_password";
			}
			result["success"] = !!("key" in result);
			return Response(StatusCodes.ok, ["Content-Type": "application/json"], JSONValue(result).toString());
		}
		switch(request.path) {
			case "/style.css": return Response(StatusCodes.ok, ["Content-Type": "text/css"], this.style);
			case "/res/bg32.png": return Response(StatusCodes.ok, ["Content-Type": "image/png"], this.bg);
			case "/res/lock_locked.png": return Response(StatusCodes.ok, ["Content-Type": "image/png"], this.lock_locked);
			case "/res/lock_unlocked.png": return Response(StatusCodes.ok, ["Content-Type": "image/png"], this.lock_unlocked);
			default: break;
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
