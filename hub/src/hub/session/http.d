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
module hub.session.http;

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

import com.path : Paths;
import com.sel;
import com.util : seconds;

import hub.constants;
import hub.server : Server;
import hub.settings;
import hub.network.handler : HandlerThread;
import hub.util.log;

import vibe.http.server;
import vibe.web.web;

class HttpHandler {

	private shared Server server;

	private shared WebResource icon;
	private shared string info;
	private shared WebResource status;
	private shared WebResource stylesheet;
	
	private shared string* socialJson;

	private shared string website;

	private immutable ushort pocketPort, minecraftPort;
	
	private shared time_t lastStatusUpdate;

	private shared size_t sessionsCount;
	
	public this(shared Server server, shared string* socialJson) {
		this.server = server;
		this.socialJson = socialJson;
		this.pocketPort = pocketPort;
		this.minecraftPort = minecraftPort;
		this.reload();
	}

	public void reload() {
		// from reload command
		this.reloadInfoJson();
		this.reloadWebResources();
	}
	
	private void reloadInfoJson() {
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
	
	private void reloadWebResources() {
		
		auto settings = cast()this.server.settings;
		
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
	
	private void reloadWebStatus(inout Settings settings) {
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

	public void index(HTTPServerResponse res) {
		auto settings = cast()this.server.settings.config;
		auto website = ""; //TODO
		res.render!("index.dt", settings, Software, website, supportedMinecraftProtocols, supportedPocketProtocols);
	}

	@path("/index.html") getIndex(HTTPServerResponse res) {
		res.redirect("/", 301);
	}

	@path("/info.json") getInfo(HTTPServerResponse res) {
		res.writeBody(this.info, "application/json; charset=utf-8");
	}

	@path("/social.json") getSocial(HTTPServerResponse res) {
		res.writeBody(*this.socialJson, "application/json; charset=utf-8");
	}

	@path("/status") getStatus(HTTPServerResponse res) {
		if(seconds - this.lastStatusUpdate > JSON_STATUS_REFRESH_TIMEOUT) this.reloadWebStatus(cast()server.settings);
		res.writeBody(this.status.uncompressed, "application/octet-stream");
	}

	@path("/icon.png") getIcon(HTTPServerResponse res) {
		if(this.icon.compressed !is null) {
			res.writeBody(this.icon.uncompressed, "image/png");
		} else {
			res.redirect("//i.imgur.com/uxvZbau.png", 301);
		}
	}

	@path("/icon") getIconRedirect(HTTPServerResponse res) {
		res.redirect("/icon.png", 301);
	}

	@path("/" ~ Software.codenameEmoji) getCodenameEmoji(HTTPServerResponse res) {
		res.statusCode = 418;
		res.statusPhrase = "It's a " ~ Software.codenameEmoji;
		res.writeBody("<head><meta charset='UTF-8'/><style>span{font-size:128px}</style><script>function a(){document.body.innerHTML+='<span>" ~ Software.codenameEmoji ~ "</span>';setTimeout(a,Math.round(Math.random()*2500));}window.onload=a;</script></head>", "text/html; charset=utf-8");
	}

	@path("/software") getSoftware(HTTPServerResponse res) {
		res.redirect("//" ~ Software.website, 301);
	}

	@path("/player/:id") getPlayer(HTTPServerResponse res, uint _id) {
		auto player = this.server.playerFromId(_id);
		if(player !is null) {
			JSONValue[string] json;
			json["name"] = JSONValue(player.username);
			json["display"] = JSONValue(player.displayName);
			json["version"] = JSONValue(player.game);
			if(player.skin !is null) json["picture"] = JSONValue(player.skin.faceBase64);
			json["world"] = JSONValue(["name": JSONValue(player.world.name), "dimension": JSONValue(player.dimension)]);
			res.writeBody(JSONValue(json).toString(), "application/json; charset=utf-8");
		} else {
			res.statusCode = 404;
			res.statusPhrase = "Not Found";
			res.writeBody("{\"error\":\"Player not found\"}", "application/json; charset=utf-8");
		}
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
