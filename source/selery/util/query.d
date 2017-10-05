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
module selery.util.query;

import core.thread : Thread;

import std.algorithm : min;
import std.bitmanip : nativeToLittleEndian;
import std.conv : to;
import std.datetime : dur;
import std.string : split, join;

import selery.about;
import selery.constants;
import selery.hub.server;
import selery.network.session : session_t;

class Queries : Thread {

	private shared HubServer server;

	private shared string* socialJson;

	public shared string pocketIp = "0.0.0.0";
	public shared string javaIp = "0.0.0.0";

	// every 120 seconds (as it's deprecated and rarely used)
	private shared ubyte[] _java_legacy_status, _java_legacy_status_old;

	// every 30 seconds
	private shared ubyte[] _pocket_short_query, _java_short_query;

	// every 30 seconds
	private shared ubyte[] _pocket_long_query, _java_long_query;

	// reset every 30 seconds
	private shared int[session_t] _query_sessions;

	public this(shared HubServer server, shared string* socialJson) {
		super(&this.run);
		this.server = server;
		this.socialJson = socialJson;
		// set best ip/port
		with(server.config.hub) {
			if(serverIp.length) {
				this.pocketIp = this.javaIp = serverIp;
			} else {
				void parse(string address, ref shared string ip) {
					string[] spl = address.split(":");
					if(spl.length >= 2) {
						try {
							string nip = spl[0..$-1].join(":");
							if(nip.length > 1) ip = nip;
						} catch(Exception) {}
					}
				}
				foreach(string address ; bedrock.addresses) {
					parse(address, this.pocketIp);
				}
				foreach(string address ; java.addresses) {
					parse(address, this.javaIp);
				}
			}
		}
	}

	public void run() {
		while(true) {
			static if(MINECRAFT_ALLOW_LEGACY_PING) this.regenerateJavaLegacyStatus();
			foreach(i ; 0..4) {
				this.regenerateShortQueries();
				this.regenerateLongQueries();
				Thread.sleep(dur!"seconds"(30));
				this.clearQuerySessions();
			}
		}
	}

	public shared nothrow @property @safe @nogc shared(ubyte[])* javaLegacyStatus() {
		return &this._java_legacy_status;
	}

	public shared nothrow @property @safe @nogc shared(ubyte[])* javaLegacyStatusOld() {
		return &this._java_legacy_status_old;
	}

	public shared nothrow @property @safe shared(ubyte[])* pocketShortQuery() {
		return &this._pocket_short_query;
	}

	public shared nothrow @property @safe shared(ubyte[])* javaShortQuery() {
		return &this._java_short_query;
	}

	public shared nothrow @property @safe shared(ubyte[])* pocketLongQuery() {
		return &this._pocket_long_query;
	}

	public shared nothrow @property @safe shared(ubyte[])* javaLongQuery() {
		return &this._java_long_query;
	}

	public shared nothrow @property @safe shared(int[session_t])* querySessions() {
		return &this._query_sessions;
	}

	private void regenerateJavaLegacyStatus() {
		/* new (since 1.4) */ {
			ubyte[] payload = [0, 167, 0, 49, 0, 0];
			with(this.server.config.hub.java) {
				foreach(string status ; [to!string(protocols[$-1]), supportedJavaProtocols[protocols[$-1]][0], motd, to!string(this.server.onlinePlayers), to!string(this.server.maxPlayers)]) {
					foreach(wchar wc ; to!wstring(status)) {
						ushort s = cast(ushort)wc;
						payload ~= [(s >> 8) & 255, s & 255];
					}
					payload ~= [0, 0];
				}
			}
			payload = payload[0..$-2];
			size_t length = payload.length / 2;
			this._java_legacy_status = cast(shared ubyte[])(cast(ubyte[])[255, (length >> 8) & 255, length & 255] ~ payload);
		}
		/* old (from beta 1.8 to 1.3) */ {
			ubyte[] payload;
			with(this.server.config.hub.java) {
				foreach(wchar wc ; to!wstring(motd ~ "§" ~ to!string(this.server.onlinePlayers) ~ "§" ~ to!string(this.server.maxPlayers))) {
					ushort s = cast(ushort)wc;
					payload ~= [(s >> 8) & 255, s & 255];
				}
			}
			size_t length = payload.length / 2;
			this._java_legacy_status_old = cast(shared ubyte[])(cast(ubyte[])[255, (length >> 8) & 255, length & 255] ~ payload);
		}
	}

	private void regenerateShortQueries() {
		with(this.server.config.hub) {
			ubyte[] pe, pc;
			void add(string value) {
				ubyte[] buff = cast(ubyte[])value ~ 0;
				if(bedrock) pe ~= buff;
				if(java) pc ~= buff;
			}
			static if(QUERY_SHOW_MOTD) {
				if(pocket) pe ~= cast(ubyte[])pocket.motd ~ ubyte.init;
				if(java) pc ~= cast(ubyte[])java.motd ~ ubyte.init;
			} else {
				add(displayName);
			}
			add(Software.name);
			add("world");
			add(to!string(this.server.onlinePlayers));
			add(to!string(this.server.maxPlayers));
			if(bedrock) {
				pe ~= nativeToLittleEndian(bedrock.port);
				pe ~= cast(ubyte[])this.pocketIp ~ 0;
				this._pocket_short_query = cast(shared)pe;
			}
			if(java) {
				pc ~= nativeToLittleEndian(java.port);
				pc ~= cast(ubyte[])this.javaIp ~ 0;
				this._java_short_query = cast(shared)pc;
			}
		}
	}

	private void regenerateLongQueries() {
		with(this.server.config.hub) {
			ubyte[] pe, pc;
			void add(string key, string value) {
				ubyte[] buff = cast(ubyte[])key ~ 0 ~ cast(ubyte[])value ~ 0;
				if(bedrock) pe ~= buff;
				if(java) pc ~= buff;
			}
			void addTo(ref ubyte[] buffer, string key, string value) {
				buffer ~= cast(ubyte[])key ~ 0 ~ cast(ubyte[])value ~ 0;
			}
			add("splitnum", x"80");
			static if(QUERY_SHOW_MOTD) {
				if(pocket) addTo(pe, "hostname", pocket.motd);
				if(java) addTo(pc, "hostname", java.motd);
			} else {
				add("hostname", displayName);
			}
			add("gametype", Software.name);
			add("whitelist", whitelist ? "on" : "off");
			if(bedrock) {
				addTo(pe, "game_id", "MINECRAFTPE");
				addTo(pe, "version", supportedBedrockProtocols[bedrock.protocols[$-1]][0]);
			}
			if(java) {
				addTo(pc, "game_id", "MINECRAFT");
				addTo(pc, "version", supportedJavaProtocols[java.protocols[$-1]][0]);
			}
			string[] plugins = this.server.plugins;
			add("plugins", Software.name ~ " " ~ Software.displayVersion ~ (plugins.length ? ": " ~ plugins.join("; ") : ""));
			add("map", "world");
			add("numplayers", to!string(this.server.onlinePlayers));
			add("maxplayers", to!string(this.server.maxPlayers));
			if(bedrock) {
				addTo(pe, "hostport", to!string(bedrock.port));
				addTo(pe, "hostip", this.pocketIp);
			}
			if(java) {
				addTo(pc, "hostport", to!string(java.port));
				addTo(pc, "hostip", this.javaIp);
			}
			add("social", *this.socialJson);
			ubyte[] players = cast(ubyte[])(cast(ubyte[])[0, 1] ~ cast(ubyte[])"player_" ~ 0 ~ 0);
			static if(QUERY_SHOW_PLAYERS) {
				foreach(player ; this.server.players[0..min($, QUERY_MAX_PLAYERS)]) {
					players ~= cast(ubyte[])player.username;
					players ~= 0;
				}
			}
			players ~= 0;
			if(bedrock) this._pocket_long_query = cast(shared)(pe ~ players);
			if(java) this._java_long_query = cast(shared)(pc ~ players);
		}
	}

	private nothrow void clearQuerySessions() {
		this._query_sessions.clear();
	}

}
