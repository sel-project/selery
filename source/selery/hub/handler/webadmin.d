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

import core.atomic : atomicOp;
import core.thread : Thread;

import std.concurrency : spawn;
import std.datetime : dur;
import std.json;
import std.random : uniform;
import std.socket : Socket, TcpSocket, Address, SocketOption, SocketOptionLevel;
import std.string : startsWith, split, replace;

import sel.hncom.status : RemoteCommand;
import sel.net.http : StatusCodes, Request, Response;
import sel.net.stream : TcpStream;
import sel.net.websocket : authWebSocketClient, WebSocketServerStream;
import sel.server.query : Query;
import sel.server.util : GenericServer;

import selery.about : Software;
import selery.hub.player : World, PlayerSession;
import selery.hub.server : HubServer;
import selery.log : Message;
import selery.util.diet;

class WebAdminHandler : GenericServer {

	private shared HubServer server;

	private shared string style, bg, lock_locked, lock_unlocked;

	private shared string[string] sessions;

	public shared this(shared HubServer server) {
		super(server.info);
		this.server = server;
		// prepare static resources
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
			spawn(&this.handleClient, cast(shared)client);
		}
	}

	private shared void handleClient(shared Socket _socket) {
		Socket socket = cast()_socket;
		debug Thread.getThis().name = "web_admin_client@" ~ socket.remoteAddress.toString();
		char[] buffer = new char[1024];
		auto recv = socket.receive(buffer);
		if(recv > 0) {
			auto response = this.handle(socket, Request.parse(buffer[0..recv].idup));
			response.headers["Server"] = Software.display;
			socket.send(response.toString());
			if(response.status.code == StatusCodes.switchingProtocols.code) {
				socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(0));
				socket.blocking = true;
				// keep connection alive
				auto client = new WebAdminClient(socket, response.headers["Language"]);
				this.server.add(client);
				// send settings
				client.sendSettings(this.server);
				// send language files (only for the client's language)
				client.sendLanguage(this.server.lang.raw[client.language]);
				// send every world
				foreach(node ; this.server.nodesList) {
					foreach(world ; node.worlds) {
						client.sendAddWorld(world);
					}
				}
				//TODO send players
				auto address = socket.remoteAddress;
				while(true) {
					try {
						JSONValue[string] json = parseJSON(cast(string)client.receive()).object;
						switch(json.get("id", JSONValue.init).str) {
							case "command":
								this.server.handleCommand(json.get("command", JSONValue.init).str, RemoteCommand.WEB_ADMIN, address, cast(uint)json.get("command_id", JSONValue.init).integer);
								break;
							default:
								break;
						}
					} catch(JSONException) {
						break;
					}
				}
				this.server.remove(client);
			}
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

	private shared Response handle(Socket client, Request request) {
		@property string address(){ return client.remoteAddress.toAddrString(); }
		if(request.method == Request.GET) {
			switch(request.path) {
				case "/style.css": return Response(StatusCodes.ok, ["Content-Type": "text/css"], this.style);
				case "/res/bg32.png": return Response(StatusCodes.ok, ["Content-Type": "image/png"], this.bg);
				case "/res/lock_locked.png": return Response(StatusCodes.ok, ["Content-Type": "image/png"], this.lock_locked);
				case "/res/lock_unlocked.png": return Response(StatusCodes.ok, ["Content-Type": "image/png"], this.lock_unlocked);
				case "/":
					bool auth = false;
					auto cookie = "cookie" in request.headers;
					if(cookie && startsWith(*cookie, "key=")) {
						auto ip = (*cookie)[4..$] in this.sessions;
						if(ip && *ip == address) auth = true;
					}
					if("sec-websocket-key" in request.headers) {
						// new websocket connection
						if(auth) {
							auto response = authWebSocketClient(request);
							if(response.valid) {
								response.headers["Language"] = getClientLanguage(request);
								return response;
							} else {
								return Response(StatusCodes.badRequest);
							}
						} else {
							return Response(StatusCodes.forbidden);
						}
					} else {
						// send login page or create a session
						immutable lang = this.getClientLanguage(request);
						string translate(string text, string[] params...) {
							return this.server.config.lang.translate(text, params, lang);
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
							else return Response(StatusCodes.ok, "Limit reached"); //TODO
						}
					}
				default: break;
			}
		} else if(request.method == Request.POST && request.path == "/login") {
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
		return Response.error(StatusCodes.notFound);
	}

	private shared string addClient(string address) {
		immutable key = randomKey();
		this.sessions[key] = address;
		return key;
	}

	public override shared pure nothrow @property @safe @nogc ushort defaultPort() {
		return ushort(19134);
	}

}

class WebAdminClient {

	private static shared uint _id = 0;

	public immutable uint id;

	private WebSocketServerStream stream;

	public string language;

	private immutable string to_string;

	public this(Socket socket, string language) {
		this.id = atomicOp!"+="(_id, 1);
		this.stream = new WebSocketServerStream(new TcpStream(socket));
		this.language = language;
		this.to_string = "WebAdmin@" ~ socket.remoteAddress.toString();
	}

	public void send(string packet, JSONValue[string] data) {
		data["packet"] = packet;
		this.stream.send(JSONValue(data).toString());
	}

	public void sendSettings(shared HubServer server) {
		JSONValue[string] data;
		data["name"] = server.info.motd.raw;
		data["max"] = server.maxPlayers;
		data["favicon"] = server.info.favicon;
		data["languages"] = server.config.hub.acceptedLanguages; //TODO also send language names
		this.send("settings", data);
	}

	public void sendLanguage(inout string[string] messages) {
		JSONValue[string] data;
		foreach(key, value; messages) data[key] = value;
		this.send("lang", ["data": JSONValue(data)]);
	}

	public void sendAddWorld(shared World world) {
		JSONValue[string] data;
		data["id"] = world.id;
		data["name"] = world.name;
		data["dimension"] = world.dimension;
		if(world.parent !is null) data["parent_id"] = world.parent.id;
		this.send("add_world", data);
	}

	public void sendRemoveWorld(shared World world) {
		this.send("remove_world", ["id": JSONValue(world.id)]);
	}

	public void sendAddPlayer(shared PlayerSession player) {}

	public void sendRemovePlayer(shared PlayerSession player) {}

	public void sendLog(Message[] messages, int commandId, int worldId) {
		JSONValue[] log;
		string next;
		void addText() {
			log ~= JSONValue(["text": next]);
			next.length = 0;
		}
		foreach(message ; messages) {
			if(message.type == Message.FORMAT) next ~= message.format;
			else if(message.type == Message.TEXT) next ~= message.text;
			else {
				if(next.length) addText();
				log ~= JSONValue(["translation": JSONValue(message.translation.translatable.default_), "with": JSONValue(message.translation.parameters)]);
			}
		}
		if(next.length) addText();
		this.send("log", ["log": JSONValue(log), "command_id": JSONValue(commandId), "world_id": JSONValue(worldId)]);
	}

	public ubyte[] receive() {
		return this.stream.receive();
	}

	public override string toString() {
		return this.to_string;
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
