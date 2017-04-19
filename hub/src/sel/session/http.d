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
module sel.session.http;

import core.atomic : atomicOp;

import std.bitmanip : nativeToLittleEndian;
import std.conv : to;
import std.datetime : time_t, dur;
import std.file : exists, read;
import std.json;
import std.regex : ctRegex, replaceAll;
import std.socket;
import std.string;
import std.system : Endian;
import std.uri : decode;
import std.zlib : Compress, HeaderFormat;

import common.path : Paths;
import common.sel;
import common.util : seconds;

import sel.constants;
import sel.server : Server;
import sel.settings;
import sel.network.handler : HandlerThread;
import sel.network.socket;
import sel.util.log;
import sel.util.thread : SafeThread;

class HttpHandler : HandlerThread {
	
	private shared WebResource index;
	private shared WebResource icon;
	private shared string info;
	private shared WebResource status;
	private shared WebResource stylesheet;
	
	private shared string* socialJson;

	private shared string website;

	private immutable ushort pocketPort, minecraftPort;
	
	private shared time_t lastStatusUpdate;

	private shared size_t sessionsCount;
	
	public this(shared Server server, shared string* socialJson, ushort pocketPort, ushort minecraftPort) {
		with(server.settings) super(server, createSockets!TcpSocket("http", webAddresses, WEB_BACKLOG));
		this.socialJson = socialJson;
		this.pocketPort = pocketPort;
		this.minecraftPort = minecraftPort;
		(cast(shared)this).reload();
	}

	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			Socket client = socket.accept();
			client.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(WEB_TIMEOUT));
			this.handleClient(client);
		}
	}

	private void handleClient(Socket socket) {
		new SafeThread({
			char[] buffer = new char[WEB_BUFFER_SIZE];
			auto recv = socket.receive(buffer);
			if(recv > 0) {
				this.receive(recv);
				auto sent = socket.send(this.handleConnection(socket, Request.parse(buffer[0..recv].idup)).toString());
				if(sent > 0) this.send(sent);
			}
			socket.close();
		}).start();
	}

	public override shared void reload() {
		// from reload command
		(cast()this).reloadInfoJson();
		(cast()this).reloadWebResources();
	}
	
	public void reloadInfoJson() {
		auto settings = this.server.settings;
		JSONValue[string] json, software, protocols;
		with(Software) {
			software["name"] = JSONValue(name);
			software["display"] = JSONValue(display);
			software["codename"] = JSONValue(["name": JSONValue(codename), "emoji": JSONValue(codenameEmoji)]);
			software["version"] = JSONValue(["major": JSONValue(major), "minor": JSONValue(minor), "patch": JSONValue(patch), "stable": JSONValue(stable)]);
			if(settings.pocket) protocols["pocket"] = JSONValue(settings.pocket.protocols);
			if(settings.minecraft) protocols["minecraft"] = JSONValue(settings.minecraft.protocols);
			json["software"] = JSONValue(software);
			json["protocols"] = JSONValue(protocols);
			json["online"] = JSONValue(__onlineMode);
		}
		this.info = JSONValue(json).toString();
	}
	
	public void reloadWebResources() {
		
		auto settings = this.server.settings;

		this.website = "";
		try { this.website = (cast()settings.social)["website"].str; } catch(JSONException) {}
		
		// index
		string index = cast(string)read(Paths.res ~ "index.html");
		index = index.replace("{DEFAULT_LANG}", settings.language[0..2]);
		index = index.replace("{DISPLAY_NAME}", settings.displayName);
		index = index.replace("{SOFTWARE}", Software.display);
		index = index.replace("{PC}", settings.minecraft ? ("<p>Minecraft: {IP}:" ~ to!string(this.minecraftPort) ~ "</p>") : "");
		index = index.replace("{PE}", settings.pocket ? ("<p>Minecraft&nbsp;" ~ (__edu ? "Education" : "Pocket") ~ "&nbsp;Edition: {IP}:" ~ to!string(this.pocketPort) ~ "</p>") : "");
		if(settings.serverIp.length) index = index.replace("{IP}", settings.serverIp);
		index = index.replace("{WEBSITE}", this.website);
		this.index.uncompressed = index;
		this.index.compress();
		
		// icon.png
		if(exists(Paths.resources ~ settings.icon)) {
			this.icon.uncompressed = cast(shared string)read(Paths.resources ~ settings.icon);
			this.icon.compress();
		}
		
		// status.json
		this.reloadWebStatus(settings);

		// style.css
		if(exists(Paths.res ~ "http/style.css")) {
			this.stylesheet.uncompressed = (cast(string)read(Paths.res ~ "http/style.css")).replaceAll(ctRegex!`[\r\n\t]*`, "").replaceAll(ctRegex!`[ ]*([\{\:\,])[ ]*`, "$1");
			this.stylesheet.compress();
		}
		
	}
	
	public void reloadWebStatus(shared const Settings settings) {
		ubyte[] status = nativeToLittleEndian(server.onlinePlayers) ~ nativeToLittleEndian(server.maxPlayers);
		static if(JSON_STATUS_SHOW_PLAYERS) {
			foreach(player ; this.server.players) {
				status ~= nativeToLittleEndian(player.id);
				status ~= nativeToLittleEndian(player.displayName.length.to!ushort);
				status ~= cast(ubyte[])player.displayName;
			}
		}
		this.status.uncompressed = cast(string)status;
		if(status.length > JSON_STATUS_COMPRESSION_THRESOLD) {
			this.status.compress();
		} else {
			this.status.compressed = null;
		}
		this.lastStatusUpdate = seconds;
	}
	
	private Response handleConnection(Socket socket, Request request) {
		if(!request.valid || request.path.length == 0 || "host" !in request.headers) return this.returnWebError(400, "Bad Request");
		if(request.method != "GET") return this.returnWebError(405, "Method Not Allowed");
		switch(decode(request.path[1..$])) {
			case "":
				auto response = Response(200, "OK", ["Content-Type": "text/html"]);
				return this.returnWebResource(this.index, request, response);
			case "info.json":
				return Response(200, "OK", ["Content-Type": "application/json; charset=utf-8"], this.info);
			case "social.json":
				return Response(200, "OK", ["Content-Type": "application/json; charset=utf-8"], *this.socialJson);
			case "status":
				auto time = seconds;
				if(time - this.lastStatusUpdate > JSON_STATUS_REFRESH_TIMEOUT) this.reloadWebStatus(server.settings);
				auto response = Response(200, "OK", ["Content-Type": "application/octet-stream"], this.status.uncompressed);
				if(this.status.isCompressed) {
					response = this.returnWebResource(this.status, request, response);
				}
				return response;
			case "icon.png":
				if(this.icon.compressed !is null) {
					auto response = Response(200, "OK", ["Content-Type": "image/png"]);
					return this.returnWebResource(this.icon, request, response);
				} else {
					return Response(301, "Moved Permanently", ["Location": "//i.imgur.com/uxvZbau.png"]);
				}
			case "icon":
				return Response(301, "Moved Permanently", ["Location": "/icon.png"]);
			case Software.codenameEmoji:
				return Response(418, "I'm a " ~ Software.codename.toLower, ["Content-Type": "text/html"], "<head><meta charset='UTF-8'/><style>span{font-size:128px}</style><script>function a(){document.body.innerHTML+='<span>" ~ Software.codenameEmoji ~ "</span>';setTimeout(a,Math.round(Math.random()*2500));}window.onload=a;</script></head>");
			case "software":
				return Response(301, "Moved Permanently", ["Location": "//" ~ Software.website]);
			case "website":
				if(this.website.length) {
					return Response(301, "Moved Permanently", ["Location": "//" ~ this.website]);
				} else {
					return this.returnWebError(404, "Not Found");
				}
			case "style.css":
				return this.returnWebResource(this.stylesheet, request, Response(200, "OK", ["Content-Type": "text/css"]));
			default:
				if(request.path.startsWith("/player/") && request.path.endsWith(".json")) {
					try {
						auto player = this.server.playerFromId(to!uint(request.path[8..$-5]));
						if(player !is null) {
							JSONValue[string] json;
							json["name"] = JSONValue(player.username);
							json["display"] = JSONValue(player.displayName);
							json["version"] = JSONValue(player.game);
							if(player.skin !is null) json["picture"] = JSONValue(player.skin.faceBase64);
							json["world"] = JSONValue(["name": JSONValue(player.world.name), "dimension": JSONValue(player.dimension)]);
							return Response(200, "OK", ["Content-Type": "application/json; charset=utf-8"], JSONValue(json).toString());
						}
					} catch(Exception) {}
					return Response(404, "Not Found", ["Content-Type": "application/json; charset=utf-8"], "{\"error\":\"player not found\"}");
				}
				return this.returnWebError(404, "Not Found");
		}
	}
	
	private Response returnWebResource(ref shared WebResource resource, Request request, Response response) {
		auto ae = "accept-encoding" in request.headers;
		if(ae && ((*ae).indexOf(WEB_COMPRESSION_FORMAT) >= 0 || *ae == "*")) {
			response.headers["Content-Encoding"] = WEB_COMPRESSION_FORMAT;
			response.content = resource.compressed;
		} else {
			response.content = resource.uncompressed;
		}
		return response;
	}
	
	private Response returnWebError(uint error, string description) {
		string ed = to!string(error) ~ " " ~ description;
		return Response(error, description, ["Content-Type": "text/html"], "<head><title>" ~ ed ~ "</title></head><body><center><h1>" ~ ed ~ "</h1></center><hr><center>" ~ Software.display ~ "</center></body>");
	}

}

private struct WebResource {
	
	public string uncompressed;
	public string compressed = null;
	
	public shared nothrow @property @safe @nogc bool isCompressed() {
		return this.compressed !is null;
	}
	
	public shared void compress() {
		Compress c = new Compress(WEB_COMPRESSION_LEVEL, mixin("HeaderFormat." ~ WEB_COMPRESSION_FORMAT));
		auto r = c.compress(this.uncompressed);
		r ~= c.flush();
		this.compressed = cast(string)r;
	}
	
}

public struct Request {
	
	bool valid;
	
	string method;
	string path;
	
	string[string] headers;
	
	public static Request parse(string str) {
		Request request;
		string[] spl = str.split("\r\n");
		if(spl.length > 0) {
			string[] head = spl[0].split(" ");
			if(head.length == 3) {
				request.valid = true;
				request.method = head[0];
				request.path = head[1];
				foreach(string line ; spl[1..$]) {
					string[] sl = line.split(":");
					if(sl.length >= 2) {
						request.headers[sl[0].strip.toLower] = sl[1..$].join(":").strip;
					}
				}
			}
		}
		return request;
	}
	
}

public struct Response {
	
	uint code;
	string codeMessage;
	
	string[string] headers;
	
	string content;
	
	public string toString() {
		return "HTTP/1.1 " ~ to!string(this.code) ~ " " ~ this.codeMessage ~ "\r\n" ~
				"Server: " ~ Software.display ~ "\r\n" ~
				"Connection: close\r\n" ~
				"Content-Length: " ~ to!string(this.content.length) ~ "\r\n" ~
				(){
					string ret = "";
					foreach(string key, string value; headers) {
						ret ~= key ~ ": " ~ value ~ "\r\n";
					}
					return ret;
				}() ~
				"\r\n" ~ this.content;
	}
	
}
