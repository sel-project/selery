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
module selery.hub.handler.webview;

import core.atomic : atomicOp;
import core.thread : Thread;

import std.bitmanip : nativeToLittleEndian;
import std.concurrency : spawn;
import std.conv : to;
import std.datetime : dur;
import std.json;
import std.socket;
import std.string;
import std.system : Endian;
import std.uri : decode;
import std.zlib : Compress, HeaderFormat;

import sel.net.http : Status, StatusCodes, Request, Response;
import sel.server.query : Query;
import sel.server.util;

import selery.about;
import selery.hub.handler.handler : Reloadable;
import selery.hub.server : HubServer;
import selery.util.diet;
import selery.util.thread : SafeThread;
import selery.util.util : seconds;

class WebViewHandler : GenericServer, Reloadable {

	private shared HubServer server;

	private shared WebResource icon;
	private shared string info;
	private shared WebResource status;

	private shared string iconRedirect = null;
	
	private shared string* socialJson;
	
	private shared string website;

	private shared ulong lastStatusUpdate;
	
	private shared size_t sessionsCount;
	
	public shared this(shared HubServer server, shared string* socialJson) {
		super(server.info);
		this.server = server;
		this.socialJson = socialJson;
		(cast(shared)this).reload();
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
		debug Thread.getThis().name = "web_view_server@" ~ (cast()_socket).localAddress.toString();
		Socket socket = cast()_socket;
		while(true) {
			Socket client = socket.accept();
			client.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(5000));
			this.handleClient(client); //TODO use spawn
		}
	}
	
	private shared void handleClient(Socket socket) {
		new SafeThread(this.server.config.lang, {
			char[] buffer = new char[1024];
			auto recv = socket.receive(buffer);
			if(recv > 0) {
				auto response = this.handleConnection(socket, Request.parse(buffer[0..recv].idup));
				response.headers["Server"] = Software.display;
				auto sent = socket.send(response.toString());
			}
			socket.close();
		}).start();
	}

	public override shared pure nothrow @property @safe @nogc ushort defaultPort() {
		return ushort(80);
	}
	
	public override shared void reload() {
		// from reload command
		this.reloadInfoJson();
		this.reloadWebResources();
	}
	
	public shared void reloadInfoJson() {
		const config = this.server.config.hub;
		JSONValue[string] json, software, protocols;
		with(Software) {
			software["name"] = JSONValue(name);
			software["display"] = JSONValue(display);
			software["codename"] = JSONValue(["name": JSONValue(codename), "emoji": JSONValue(codenameEmoji)]);
			software["version"] = JSONValue(["major": JSONValue(major), "minor": JSONValue(minor), "patch": JSONValue(patch), "stable": JSONValue(stable)]);
			if(config.bedrock) protocols["bedrock"] = JSONValue(config.bedrock.protocols);
			if(config.java) protocols["java"] = JSONValue(config.java.protocols);
			json["software"] = JSONValue(software);
			json["protocols"] = JSONValue(protocols);
		}
		this.info = JSONValue(json).toString();
	}
	
	public shared void reloadWebResources() {
		
		const config = this.server.config;
		
		// icon.png
		this.icon = WebResource.init;
		this.iconRedirect = null;
		with(this.server.icon) {
			if(url.length) {
				this.iconRedirect = url;
			} else if(data.length) {
				// must be valid if not empty
				this.icon.uncompressed = cast(string)data;
				this.icon.compress();
			}
		}
		
		// status.json
		this.reloadWebStatus();
		
	}
	
	public shared void reloadWebStatus() {
		ubyte[] status = nativeToLittleEndian(this.server.onlinePlayers) ~ nativeToLittleEndian(this.server.maxPlayers);
		{
			//TODO add an option to disable showing players
			immutable show_skin = (this.server.onlinePlayers <= 32);
			foreach(player ; this.server.players) {
				immutable skin = (show_skin && player.skin !is null) << 15;
				status ~= nativeToLittleEndian(player.id);
				status ~= nativeToLittleEndian(to!ushort(player.displayName.length | skin));
				status ~= cast(ubyte[])player.displayName;
				if(skin) status ~= player.skin.face;
			}
		}
		this.status.uncompressed = cast(string)status;
		if(status.length > 1024) {
			this.status.compress();
		} else {
			this.status.compressed = null;
		}
		this.lastStatusUpdate = seconds;
	}
	
	private shared Response handleConnection(Socket socket, Request request) {
		if(!request.valid || request.path.length == 0 || "host" !in request.headers) return Response.error(StatusCodes.badRequest);
		if(request.method != "GET") return Response.error(StatusCodes.methodNotAllowed, ["Allow": "GET"]);
		switch(decode(request.path[1..$])) {
			case "":
				const config = this.server.config.hub;
				immutable host = request.headers["host"];
				return Response(StatusCodes.ok, ["Content-Type": "text/html"], compileDietFile!("view.dt", config, host));
			case "info.json":
				return Response(StatusCodes.ok, ["Content-Type": "application/json; charset=utf-8"], this.info);
			case "social.json":
				return Response(StatusCodes.ok, ["Content-Type": "application/json; charset=utf-8"], *this.socialJson);
			case "status":
				auto time = seconds;
				if(time - this.lastStatusUpdate > 10) this.reloadWebStatus();
				auto response = Response(StatusCodes.ok, ["Content-Type": "application/octet-stream"], this.status.uncompressed);
				if(this.status.isCompressed) {
					response = this.returnWebResource(this.status, request, response);
				}
				return response;
			case "icon.png":
				if(this.iconRedirect !is null) {
					return Response.redirect(StatusCodes.temporaryRedirect, this.iconRedirect);
				} else if(this.icon.compressed !is null) {
					auto response = Response(StatusCodes.ok, ["Content-Type": "image/png"]);
					return this.returnWebResource(this.icon, request, response);
				} else {
					return Response.redirect("//i.imgur.com/uxvZbau.png");
				}
			case "icon":
				return Response.redirect("/icon.png");
			case Software.codenameEmoji:
				return Response(Status(418, "I'm a " ~ Software.codename.toLower), ["Content-Type": "text/html"], "<head><meta charset='UTF-8'/><style>span{font-size:128px}</style><script>function a(){document.body.innerHTML+='<span>" ~ Software.codenameEmoji ~ "</span>';setTimeout(a,Math.round(Math.random()*2500));}window.onload=a;</script></head>");
			case "software":
				return Response.redirect(Software.website);
			case "website":
				if(this.website.length) {
					return Response.redirect("//" ~ this.website);
				} else {
					return Response.error(StatusCodes.notFound);
				}
			default:
				if(request.path.startsWith("/player_") && request.path.endsWith(".json")) {
					try {
						auto player = this.server.playerFromId(to!uint(request.path[8..$-5]));
						if(player !is null) {
							JSONValue[string] json;
							json["name"] = player.username;
							json["display"] = player.displayName;
							json["version"] = player.game;
							if(player.skin !is null) json["skin"] = player.skin.faceBase64;
							if(player.world !is null) json["world"] = ["name": JSONValue(player.world.name), "dimension": JSONValue(player.dimension)];
							return Response(StatusCodes.ok, ["Content-Type": "application/json; charset=utf-8"], JSONValue(json).toString());
						}
					} catch(Exception) {}
					return Response(StatusCodes.notFound, ["Content-Type": "application/json; charset=utf-8"], `{"error":"player not found"}`);
				}
				return Response.error(StatusCodes.notFound);
		}
	}
	
	private shared Response returnWebResource(ref shared WebResource resource, Request request, Response response) {
		auto ae = "accept-encoding" in request.headers;
		if(ae && ((*ae).indexOf("gzip") >= 0 || *ae == "*")) {
			response.headers["Content-Encoding"] = "gzip";
			response.content = resource.compressed;
		} else {
			response.content = resource.uncompressed;
		}
		return response;
	}
	
}

private struct WebResource {
	
	public string uncompressed;
	public string compressed = null;
	
	public shared nothrow @property @safe @nogc bool isCompressed() {
		return this.compressed !is null;
	}
	
	public shared void compress() {
		Compress c = new Compress(6, HeaderFormat.gzip);
		auto r = c.compress(this.uncompressed);
		r ~= c.flush();
		this.compressed = cast(string)r;
	}
	
}
