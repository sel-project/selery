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
module selery.session.java;

import core.atomic : atomicOp;
import core.sync.condition : Condition;
import core.sync.mutex : Mutex;
import core.thread : Thread;

import std.algorithm : canFind;
import std.bitmanip : read;
import std.conv : to;
import std.datetime : dur, StopWatch;
import std.json;
import std.path : dirSeparator;
import std.random : uniform;
import std.regex : matchFirst, ctRegex;
import std.socket;
import std.string : toLower;
import std.uuid;

import sel.hncom.about;
import sel.hncom.player : HncomAdd = Add;

import selery.about;
import selery.constants;
import selery.hub.server : HubServer;
import selery.network.handler : HandlerThread, UnconnectedHandler;
import selery.network.session;
import selery.session.player : PlayerSession, Skin;
import selery.util.queue : Queueable, Queue;
import selery.util.thread : SafeThread;
import selery.util.util : milliseconds;

import sul.utils.var : varuint;

mixin("import Status = sul.protocol.java" ~ newestJavaProtocol.to!string ~ ".status;");
mixin("import Login = sul.protocol.java" ~ newestJavaProtocol.to!string ~ ".login;");
mixin("import Clientbound = sul.protocol.java" ~ newestJavaProtocol.to!string ~ ".clientbound;");
mixin("import Serverbound = sul.protocol.java" ~ newestJavaProtocol.to!string ~ ".serverbound;");

private enum __onlineMode = false;

private struct ClientSettings { string language; uint viewDistance; }

private __gshared pure ubyte[] function(uint)[uint] _create_keep_alive;
private __gshared pure uint function(ubyte[])[uint] _handle_keep_alive;
private __gshared uint[uint] _keep_alive_id;
private __gshared pure ubyte[] function(string)[uint] _create_disconnect;
private __gshared pure ClientSettings function(ubyte[])[uint] _handle_client_settings;
private __gshared uint[uint] _client_settings_id;

shared static this() {

	foreach(protocol ; SupportedJavaProtocols) {
		mixin("import Clientbound = sul.protocol.java" ~ protocol.to!string ~ ".clientbound;");
		mixin("import Serverbound = sul.protocol.java" ~ protocol.to!string ~ ".serverbound;");
		_create_keep_alive[protocol] = (uint id) pure { return new Clientbound.KeepAlive(id).encode(); };
		_handle_keep_alive[protocol] = (ubyte[] buffer) pure { return Serverbound.KeepAlive.fromBuffer(buffer).id; };
		_keep_alive_id[protocol] = Serverbound.KeepAlive.ID;
		_create_disconnect[protocol] = (string json) pure { return new Clientbound.Disconnect(json).encode(); };
		_handle_client_settings[protocol] = (ubyte[] buffer) pure { with(Serverbound.ClientSettings.fromBuffer(buffer)){ return ClientSettings(language, viewDistance); } };
		_client_settings_id[protocol] = Serverbound.ClientSettings.ID;
	}

}

class JavaHandler : HandlerThread {
	
	private shared string* socialJson;
	
	private bool delegate(string ip) acceptIp;
	
	public shared JSONValue[string] status;
	private shared ubyte[]* legacyStatus, legacyStatusOld;
	
	private shared Queue!IJavaSession sessions;
	private shared Socket[] newConnections;
	
	private __gshared Mutex mutex;
	private __gshared Condition condition;
	
	public this(shared HubServer server, shared string* socialJson, bool delegate(string ip) acceptIp, shared ubyte[]* legacyStatus, shared ubyte[]* legacyStatusOld) {
		with(server.config.hub) super(server, createSockets!TcpSocket(server, "java", java.addresses, java.port, MINECRAFT_BACKLOG));
		this.socialJson = socialJson;
		this.acceptIp = acceptIp;
		this.legacyStatus = legacyStatus;
		this.legacyStatusOld = legacyStatusOld;
		this.sessions = new shared Queue!IJavaSession();
		(cast(shared)this).reload();
	}
		
	protected override void run() {
		this.condition = new Condition(this.mutex = new Mutex());
		new SafeThread(this.server.config.lang, &this.timeout).start();
		super.run();
		enum tps = 1000000 / MINECRAFT_HANDLER_TPS;
		StopWatch watch;
		ubyte[] buffer = new ubyte[MINECRAFT_BUFFER_LENGTH];
		ptrdiff_t recv;
		while(true) {
			watch.reset();
			watch.start();
			foreach(shared IJavaSession session ; this.sessions.sessions) {
				Socket socket = cast()session.socket;
				do {
					recv = socket.receive(buffer); //TODO may be null (from crash file)
					if(recv > 0) {
						this.server.traffic.receive(recv);
						session.handle(buffer[0..recv]);
					} else if(recv == 0) {
						session.onSocketClosed();
					}
				} while(recv != Socket.ERROR);
			}
			for(size_t i; i<this.newConnections.length; i++) {
				Socket socket = cast()this.newConnections[i];
				ubyte[] payload;
				while((recv = socket.receive(buffer)) > 0) {
					this.server.traffic.receive(recv);
					payload ~= buffer[0..recv];
				}
				if(payload.length && recv == Socket.ERROR) {
					// stream fully readed and connection not closed
					this.handleNewConnection(socket, payload);
					this.newConnections = this.newConnections[0..i] ~ this.newConnections[i+1..$];
				} else if(recv == 0) {
					// connection closed
					this.newConnections = this.newConnections[0..i] ~ this.newConnections[i+1..$];
				}
			}
			watch.stop();
			if(this.sessions.sessions.length || this.newConnections.length) {
				auto time = watch.peek().usecs;
				if(time < tps) {
					Thread.sleep(dur!"usecs"(tps - time));
				}
			} else {
				synchronized(this.mutex) {
					this.condition.wait();
				}
			}
		}
	}
	
	private void handleNewConnection(Socket client, ubyte[] payload) {
		Address address = client.remoteAddress;
		switch(payload[0]) {
			case 253:
				// social json
				string socialJson = *this.socialJson;
				this.server.traffic.send(socialJson.length);
				client.send(socialJson);
				client.close();
				break;
			case 254:
				// legacy ping (deprecated and used by old versions and some server list)
				static if(MINECRAFT_ALLOW_LEGACY_PING) {
					ubyte[] legacyStatus;
					if(payload.length == 1) {
						// beta 1.8 to 1.3
						legacyStatus = cast(ubyte[])*this.legacyStatusOld;
					} else {
						// from 1.4
						legacyStatus = cast(ubyte[])*this.legacyStatus;
					}
					this.server.traffic.send(legacyStatus.length);
					client.send(legacyStatus);
				}
				client.close();
				break;
			default:
				size_t length = varuint.fromBuffer(payload);
				if(payload.length && length <= payload.length && payload[0] == Status.Handshake.ID) {
					auto handshake = Status.Handshake.fromBuffer(payload);
					if(this.acceptIp(handshake.serverAddress)) {
						shared IJavaSession session;
						if(handshake.next == Status.Handshake.STATUS) {
							session = new shared JavaStatusSession(this.server, cast(shared)client, this, handshake);
						} else if(handshake.next == Status.Handshake.LOGIN) {
							session = new shared JavaSession(this.server, cast(shared)client, this, handshake);
						}
						if(session !is null) {
							this.sessions.push(session);
							if(payload.length > length) {
								session.handle(payload[length..$]);
							}
							synchronized(this.mutex) {
								this.condition.notify();
							}
							break;
						}
					} else {
						client.close();
						break;
					}
				}
				// wrong packet format
				this.server.block(address, 30);
				client.close();
				break;
		}
	}
	
	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			Socket client = socket.accept();
			if(this.server.isBlocked(client.remoteAddress)) {
				client.close();
			} else {
				client.blocking = false;
				this.newConnections ~= cast(shared)client;
				synchronized(this.mutex) {
					this.condition.notify();
				}
			}
		}
	}
	
	private void timeout() {
		Thread.getThis().name = "javaHandler" ~ dirSeparator ~ "timeout";
		while(true) {
			Thread.sleep(dur!"seconds"(1));
			foreach(shared IJavaSession session ; this.sessions.sessions) {
				session.checkTimeout();
			}
		}
	}
	
	public shared void removeSession(shared IJavaSession session) {
		if(this.sessions.remove(session)) {
			delete session;
		}
	}

	public override shared void reload() {
		JSONValue[string] status;
		// version.protocol, version.name, players.online and players.max will be set by the session
		status["description"] = ["text": JSONValue(this.server.config.hub.java.motd)];
		if(this.server.icon.data.length) status["favicon"] = this.server.icon.base64data;
		this.status = cast(shared)status;
	}
	
}

class JavaQueryHandler : UnconnectedHandler {
	
	private shared int[session_t]* querySessions;
	
	private shared ubyte[]* shortQuery, longQuery;
	
	public this(shared HubServer server, shared int[session_t]* querySessions, shared ubyte[]* shortQuery, shared ubyte[]* longQuery) {
		with(server.config.hub.java) super(server, createSockets!UdpSocket(server, "javaQuery", addresses, port, -1), 15);
		this.querySessions = querySessions;
		this.shortQuery = shortQuery;
		this.longQuery = longQuery;
	}
	
	protected override void onReceived(Socket socket, Address address, ubyte[] payload) {
		if(payload.length >= 7 && payload[0] == 254 && payload[1] == 253) {
			payload = payload[2..$];
			session_t code = Session.code(address);
			switch(payload[0]) {
				case 0:
					// query
					ubyte[] header = payload[0..5]; // id, session
					if(payload.length >= 9 && code in (*this.querySessions)) {
						payload = payload[5..$];
						if((*this.querySessions)[code] == read!int(payload)) {
							this.sendTo(socket, header ~ (payload.length == 4 ? (*this.longQuery) : (*this.shortQuery)), address);
						}
					}
					break;
				case 9:
					// login
					int session = uniform(0, 16777216);
					this.sendTo(socket, payload[0..5] ~ cast(ubyte[])to!string(session) ~ cast(ubyte[])[0], address);
					(*this.querySessions)[code] = session;
					break;
				default:
					// block the address!!!
					break;
			}
		}
	}
	
}

interface IJavaSession : Queueable {

	public shared nothrow @property @safe @nogc uint sessionId();

	public shared nothrow @property @safe @nogc ref shared(Socket) socket();

	public shared void checkTimeout();

	public shared void handle(ubyte[] payload);

	public shared void onSocketClosed();

	public shared string toString();

}

final class JavaStatusSession : Session, IJavaSession {

	private shared Socket sharedSocket;

	private shared JavaHandler handler;
	public immutable uint protocol;

	private shared ubyte timeoutIn = 4;

	private shared bool ping;

	public shared this(shared HubServer server, shared Socket socket, JavaHandler handler, Status.Handshake handshake) {
		super(server);
		this.sharedSocket = socket;
		this.handler = cast(shared)handler;
		this.protocol = handshake.protocol;
	}

	public override shared nothrow @property @safe @nogc immutable(uint) sessionId() {
		return this.id;
	}
	
	public final override shared nothrow @property @safe @nogc uint queueId() {
		return this.sessionId;
	}

	public override shared nothrow @property @safe @nogc ref shared(Socket) socket() {
		return this.sharedSocket;
	}

	public override shared void checkTimeout() {
		atomicOp!"-="(this.timeoutIn, 1);
		if(this.timeoutIn == 0) {
			this.onSocketClosed();
		}
	}

	public override shared void handle(ubyte[] payload) {
		if(!this.ping) {
			this.handleStatus(payload);
		} else {
			this.handlePing(payload);
		}
	}
	
	private shared void handleStatus(ubyte[] payload) {
		immutable length = varuint.fromBuffer(payload);
		if(length && varuint.fromBuffer(payload) == Status.Request.ID) {
			auto status = cast(JSONValue[string])this.handler.status;
			uint protocol = this.server.config.hub.java.protocols.canFind(this.protocol) ? this.protocol : this.server.config.hub.java.protocols[$-1];
			status["version"] = JSONValue(["protocol": JSONValue(protocol), "name": JSONValue(supportedJavaProtocols[protocol][0])]);
			status["players"] = JSONValue(["online": JSONValue(this.server.onlinePlayers), "max": JSONValue(this.server.maxPlayers)]);
			this.send(new Status.Response(JSONValue(status).toString()).encode());
			this.ping = true;
			if(payload.length) {
				// also try to ping
				this.handlePing(payload);
			}
		} else {
			this.onSocketClosed();
		}
	}
	
	private shared void handlePing(ubyte[] payload) {
		if(payload.length == 10 && payload[1] == Status.Latency.ID) { // [9, 1, ...]
			// send back the same packet
			this.send(payload[1..$]);
		}
		this.onSocketClosed();
	}

	public override shared ptrdiff_t send(const(void)[] data) {
		data = varuint.encode(data.length.to!uint) ~ data;
		auto sent = (cast()this.sharedSocket).send(data);
		if(sent != Socket.ERROR) this.server.traffic.send(sent);
		return sent;
	}

	public override shared void onSocketClosed() {
		Socket socket = cast()this.sharedSocket;
		socket.shutdown(SocketShutdown.RECEIVE);
		socket.close();
		this.handler.removeSession(this);
	}

	public override shared string toString() {
		return "JavaStatusSession(" ~ to!string(this.id) ~ ", " ~ to!string((cast()this.sharedSocket).remoteAddress) ~ ")";
	}

}

final class JavaSession : PlayerSession, IJavaSession {

	private shared Socket sharedSocket;

	private shared JavaHandler handler;

	private shared ubyte timeoutTicks = MINECRAFT_KEEP_ALIVE_TIMEOUT - 1;
	private shared uint keepAliveCount = 0;
	private shared ulong keepAliveTime = 0;

	private shared uint n_latency = 0;

	private shared ubyte nextUpdate;

	private void delegate(ubyte[]) shared functionHandler;

	private shared Receiver!varuint receiver;

	public shared this(shared HubServer server, shared Socket socket, JavaHandler handler, Status.Handshake handshake) {
		super(server);
		this.sharedSocket = socket;
		this.handler = cast(shared)handler;
		this.n_address = cast(shared)(cast()socket).remoteAddress;
		this.n_server_address = handshake.serverAddress;
		this.n_server_port = handshake.serverPort;
		this.n_protocol = handshake.protocol;
		this.receiver = cast(shared)new Receiver!varuint();
		this.functionHandler = &this.handleLogin;
		auto p = handshake.protocol in supportedJavaProtocols;
		if(p) this.n_version = (*p)[0];
		this.n_game_name = "Minecraft: Java Edition";
	}

	public override shared nothrow @property @safe @nogc immutable(ubyte) type() {
		return __JAVA__;
	}

	public override shared nothrow @property @safe @nogc immutable(uint) latency() {
		return this.n_latency;
	}

	public override shared nothrow @property @safe @nogc immutable(uint) sessionId() {
		return this.id;
	}

	public final shared nothrow @property @safe @nogc uint queueId() {
		return this.sessionId;
	}

	public override shared nothrow @property @safe @nogc ref shared(Socket) socket() {
		return this.sharedSocket;
	}

	public override shared JSONValue hncomAddData() {
		//TODO skin data
		return JSONValue.init;
	}

	public override shared void checkTimeout() {
		atomicOp!"+="(this.timeoutTicks, 1);
		if(this.timeoutTicks == MINECRAFT_KEEP_ALIVE_TIMEOUT) {
			if(this.keepAliveTime == 0) {
				atomicOp!"+="(this.keepAliveCount, 1);
				this.encapsulate(new Clientbound.KeepAlive(this.keepAliveCount).encode());
				this.keepAliveTime = milliseconds;
				this.timeoutTicks = 0;
			} else {
				//TODO only send packet when logged in
				this.encapsulate(new Clientbound.Disconnect(chat(Chat.translate, "disconnect.timeout")).encode());
				this.onTimedOut();
			}
		}
		atomicOp!"+="(this.nextUpdate, 1);
		if(this.nextUpdate == 12) {
			this.nextUpdate = 0;
			this.sendLatency();
		}
	}

	public override shared void handle(ubyte[] payload) {
		auto r = cast()this.receiver;
		r.add(payload);
		while(r.has) {
			if(r.length != 0) this.functionHandler(r.next);
		}
	}

	private shared void handleLogin(ubyte[] payload) {
		this.n_username = this.m_display_name = Login.LoginStart.fromBuffer(payload).username.idup;
		this.send(new Login.SetCompression(1024).encode());
		// disconnect if wrong protocol or name
		auto protocols = this.server.config.hub.java.protocols;
		string message = "";
		if(this.protocol > protocols[$-1]) {
			message = "Could not connect: Outdated server!";
		} else if(!protocols.canFind(this.protocol)) {
			message = "Could not connect: Outdated client!";
		} else if(this.n_username.length < 3 || this.n_username.length > 16 || this.n_username.matchFirst(ctRegex!"[^a-zA-Z0-9_]")) {
			message = "Invalid username!";
		}
		if(message.length) {
			this.encapsulate(new Login.Disconnect(chat(Chat.text, message)).encode());
			this.close();
		} else {
			static if(__onlineMode) {
				//TODO validate from Minecraft's API and start encryption
			} else {
				cast()this.n_uuid = this.server.nextUUID();
				this.onLoginSuccess();
			}
		}
	}

	private shared void onLoginSuccess() {

		string disconnect = (){

			// check whitelist and blacklist
			if(this.server.config.hub.whitelist) {
				with(this.server.whitelist) {
					bool valid = contains(this.username);
					static if(__onlineMode) valid = valid || contains(PC, this.uuid);
					if(!valid) return "You're not invited to play on this server.";
				}
			}
			if(this.server.config.hub.blacklist) {
				with(this.server.blacklist) {
					bool valid = !contains(this.username);
					static if(__onlineMode) valid = valid && contains(PC, this.uuid);
					if(!valid) return "You're not allowed to play on this server.";
				}
			}
				
			// check if there's some available space
			if(this.server.full) {
				return "Server is full!";
			}

			// check if it's already online
			static if(__onlineMode) {
				ubyte[] idf = this.suuid;
			} else {
				ubyte[] idf = cast(ubyte[])this.iusername;
			}
			if(this.server.playerFromIdentifier(idf) !is null) {
				return "Logged in from other location";
			}

			return "";

		}();

		if(disconnect.length) {

			this.encapsulate(new Login.Disconnect(chat(Chat.text, disconnect)).encode());
			this.close();

		} else {

			this.encapsulate(new Login.LoginSuccess(this.uuid.toString(), this.username).encode());
			this.functionHandler = &this.handlePlay;
			this.firstConnect();

		}

	}

	private shared void handlePlay(ubyte[] payload) {
		static if(__onlineMode) {
			//TODO decrypt
		}
		if(payload[0] == 0) {
			// accept only uncompressed packets
			payload = payload[1..$];
			switch(payload[0]) {
				case Serverbound.KeepAlive.ID:
					this.n_latency = cast(uint)(milliseconds - this.keepAliveTime);
					this.keepAliveTime = 0;
					break;
				default:
					if(this.n_node !is null) {
						this.n_node.sendTo(this, payload);
					}
					break;
			}
		}
	}

	public override shared ptrdiff_t send(const(void)[] data) {
		data = this.encrypt(varuint.encode(data.length.to!uint) ~ data);
		auto sent = (cast()this.sharedSocket).send(data);
		if(sent != Socket.ERROR) this.server.traffic.send(sent);
		return sent;
	}

	public shared ptrdiff_t encapsulate(const(void)[] data, uint length=0) {
		return this.send(varuint.encode(length) ~ data); 
	}

	private shared const(void)[] encrypt(const(void)[] data) {
		static if(__onlineMode) {

		} else {
			return data;
		}
	}

	public override shared void sendFromNode(ubyte[] payload) {
		this.send(payload);
	}

	protected override shared void endOfStream() {
		this.encapsulate(new Clientbound.Disconnect(chat(Chat.translate, "disconnect.endOfStream")).encode());
		this.close();
	}

	public override shared void kick(string reason, bool translation, string[] params) {
		this.encapsulate(new Clientbound.Disconnect(chat(translation ? Chat.translate : Chat.text, reason, params)).encode());
		this.close();
	}

	public override shared void onSocketClosed() {
		this.onClosedByClient();
	}

	public override shared void close() {
		super.close();
		Socket socket = cast()this.sharedSocket;
		socket.shutdown(SocketShutdown.RECEIVE);
		socket.close();
		this.handler.removeSession(this);
	}

	public override shared string toString() {
		return "JavaSession(" ~ to!string(this.id) ~ ", " ~ to!string((cast()this.sharedSocket).remoteAddress) ~ ")";
	}

}

enum Chat : string {

	text = "text",
	translate = "translate"

}

string chat(string key, string value, string[] params...) {
	JSONValue[string] json;
	json[key] = value;
	if(params.length) {
		JSONValue[] p;
		foreach(string param ; params) {
			p ~= JSONValue(param);
		}
		json["with"] = p;
	}
	return JSONValue(json).toString();
}
