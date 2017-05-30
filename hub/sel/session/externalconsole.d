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
module sel.session.externalconsole;

import core.thread : Thread;

import std.ascii : newline;
import std.base64 : Base64;
import std.bitmanip : nativeToLittleEndian, nativeToBigEndian, bigEndianToNative;
import std.conv : to;
import std.datetime : Clock, dur;
import std.digest.md;
import std.digest.sha;
import std.file : exists, mkdirRecurse, append;
import std.json;
import std.random : uniform;
import std.socket;
import std.system : Endian, endian;

import sel.about;
import sel.path : Paths;
import sel.constants;
import sel.hub.server : Server;
import sel.network.handler : HandlerThread;
import sel.network.session : Session;
import sel.network.socket : BlockingSocket;
import sel.session.http : Request, Response;
import sel.util.thread : SafeThread;

mixin("import Types = sul.protocol.externalconsole" ~ Software.externalConsole.to!string ~ ".types;");
mixin("import Login = sul.protocol.externalconsole" ~ Software.externalConsole.to!string ~ ".login;");
mixin("import Status = sul.protocol.externalconsole" ~ Software.externalConsole.to!string ~ ".status;");
mixin("import Connected = sul.protocol.externalconsole" ~ Software.externalConsole.to!string ~ ".connected;");

mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".status : RemoteCommand;");

static assert(Types.Game.POCKET == PE);
static assert(Types.Game.MINECRAFT == PC);

class ExternalConsoleHandler : HandlerThread {

	private bool delegate(ubyte[], ubyte[]) auth;
	
	public this(shared Server server) {
		immutable password = cast(immutable(ubyte)[])server.settings.externalConsolePassword;
		switch(server.settings.externalConsoleHashAlgorithm) {
			case "":
				this.auth = (ubyte[] hash, ubyte[] payload){ return hash == password; };
				break;
			case "sha1":
				this.auth = (ubyte[] hash, ubyte[] payload){ return sha1Of(password ~ payload) == hash; };
				break;
			case "sha224":
				this.auth = (ubyte[] hash, ubyte[] payload){ return sha224Of(password ~ payload) == hash; };
				break;
			case "sha256":
				this.auth = (ubyte[] hash, ubyte[] payload){ return sha256Of(password ~ payload) == hash; };
				break;
			case "sha384":
				this.auth = (ubyte[] hash, ubyte[] payload){ return sha384Of(password ~ payload) == hash; };
				break;
			case "sha512":
				this.auth = (ubyte[] hash, ubyte[] payload){ return sha512Of(password ~ payload) == hash; };
				break;
			case "md5":
				this.auth = (ubyte[] hash, ubyte[] payload){ return md5Of(password ~ payload) == hash; };
				break;
			default:
				throw new Exception("Unsopported hash: " ~ server.settings.externalConsoleHashAlgorithm);
		}
		with(server.settings) super(server, createSockets!TcpSocket("externalConsole", externalConsoleAddresses, externalConsolePort, EXTERNAL_CONSOLE_BACKLOG));
	}
	
	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			auto client = socket.accept();
			client.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(1));
			new SafeThread({
					char[] buffer = new char[EXTERNAL_CONSOLE_GENERIC_BUFFER_LENGTH];
					auto recv = client.receive(buffer);
					if(recv > 0) {
						if(recv == 7 && buffer[0..7] == "classic") {
							this.handleTcpConnection(cast(shared)client);
						} else {
							if(this.server.settings.externalConsoleAcceptWebsockets) {
								this.handleWebConnection(client, Request.parse(buffer[0..recv].idup));
							} else {
								client.send(Response(404, "Not Found").toString());
								client.close();
							}
						}
					} else {
						//TODO block it?
						client.close();
					}
				}).start();
		}
	}
	
	private void handleTcpConnection(shared Socket socket) {
		shared ClassicExternalConsoleSession session = new shared ClassicExternalConsoleSession(this.server, socket, this.auth);
		delete session;
	}
	
	private void handleWebConnection(Socket socket, Request request) {
		if("sec-websocket-key" in request.headers) {
			string accept = Base64.encode(sha1Of(request.headers["sec-websocket-key"] ~ "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).idup;
			auto response = Response(101, "Switching Protocols", ["Sec-WebSocket-Accept": accept, "Connection": "upgrade", "Upgrade": "websocket"]);
			socket.send(response.toString());
			auto s = cast(shared)socket;
			shared WebExternalConsoleSession session = new shared WebExternalConsoleSession(this.server, s, this.auth);
			delete session;
		} else {
			socket.send(Response(401, "Malformed Request").toString());
			socket.close();
		}
	}
	
}

abstract class ExternalConsoleSession : Session {
	
	protected immutable bool commands;
	
	protected shared Socket socket;
	protected shared Address address;
	
	public shared this(shared Server server, shared Socket socket) {
		super(server);
		this.commands = server.settings.externalConsoleRemoteCommands;
		this.socket = socket;
		this.address = cast(shared)(cast()socket).remoteAddress;
		if(Thread.getThis().name == "") Thread.getThis().name = "externalConsoleSession#" ~ to!string(this.id);
	}

	protected shared @property ubyte[] generatePayload() {
		version(LittleEndian) {
			alias nativeToAuto = nativeToLittleEndian;
		} else {
			alias nativeToAuto = nativeToBigEndian;
		}
		return nativeToAuto(uniform!ulong) ~ nativeToAuto(uniform!ulong);
	}
	
	public abstract shared void consoleMessage(string node, ulong timestamp, string logger, string message, int commandId);
	
	public abstract shared void updateNodes(bool add, string name);

	public shared void autoUpdateStats() {
		this.updateStats(this.server.onlinePlayers, this.server.maxPlayers, this.server.uptime, this.server.upload, this.server.download, this.server.externalConsoleNodeStats);
	}
	
	public abstract shared void updateStats(uint online, int max, uint uptime, uint upload, uint download, Types.NodeStats[] nodeStats);
	
	public override shared ptrdiff_t send(const(void)[] data) {
		this.server.traffic.send(data.length);
		return (cast()this.socket).send(data);
	}
	
	protected shared void logAttemp() {
		static if(EXTERNAL_CONSOLE_LOG_FAILED_ATTEMPTS) {
			if(!exists(Paths.logs)) mkdirRecurse(Paths.logs);
			append(Paths.logs ~ "external_console_attemps.txt", (cast()address).to!string ~ " - " ~ Clock.currTime().toString() ~ newline);
		}
	}
	
	public shared inout string toString() {
		return "ExternalConsole(" ~ to!string(this.id) ~ ", " ~ to!string(cast()this.address) ~ ")";
	}
	
}

class ClassicExternalConsoleSession : ExternalConsoleSession {
	
	public shared this(shared Server server, shared Socket sharedSocket, bool delegate(ubyte[], ubyte[]) auth) {
		super(server, sharedSocket);
		Socket socket = cast()sharedSocket;
		ubyte[16] payload = this.generatePayload();
		with(server.settings) this.send(new Login.AuthCredentials(Software.externalConsole, externalConsoleHashAlgorithm != "", externalConsoleHashAlgorithm, payload).encode());
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(EXTERNAL_CONSOLE_AUTH_TIMEOUT));
		auto receiver = new Receiver!(ushort, Endian.littleEndian)();
		ubyte[] buffer = new ubyte[512];
		auto recv = socket.receive(buffer);
		if(recv > 2) {
			this.server.traffic.receive(recv);
			receiver.add(buffer[0..recv]);
			if(receiver.has) {
				auto pk = Login.Auth.fromBuffer(receiver.next);
				if(auth(pk.hash, payload)) {
					Types.Game[] games;
					with(server.settings) {
						if(pocket) games ~= Types.Game(Types.Game.POCKET, cast(uint[])pocket.protocols);
						if(minecraft) games ~= Types.Game(Types.Game.MINECRAFT, cast(uint[])minecraft.protocols);
						with(Software) this.send(new Login.Welcome().new Accepted(this.commands, name, versions, displayName, games, server.nodeNames).encode());
					}
					server.add(this);
					this.loop(receiver);
					server.remove(this);
				} else {
					this.send(new Login.Welcome().new WrongHash().encode());
					this.logAttemp();
					//TODO block after some attempts
				}
			}
		} else if(recv == Socket.ERROR) {
			// timed out
			this.send(new Login.Welcome().new TimedOut().encode());
		}
		socket.close();
	}
	
	private shared void loop(Receiver!(ushort, Endian.littleEndian) receiver) {
		Socket socket = cast()this.socket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(EXTERNAL_CONSOLE_TIMEOUT));
		ubyte[] buffer = new ubyte[EXTERNAL_CONSOLE_CONNECTED_BUFFER_LENGTH];
		while(true) {
			auto recv = socket.receive(buffer);
			if(recv <= 0) return; // connection closed or timed out
			this.server.traffic.receive(recv);
			receiver.add(buffer[0..recv]);
			if(receiver.has) {
				ubyte[] payload = receiver.next;
				switch(payload[0]) {
					case Status.KeepAlive.ID:
						this.send(new Status.KeepAlive(Status.KeepAlive.fromBuffer(payload).count).encode());
						break;
					case Status.RequestStats.ID:
						this.autoUpdateStats();
						break;
					case Connected.Command.ID:
						if(this.commands) {
							auto pk = Connected.Command.fromBuffer(payload);
							if(pk.command.length) {
								this.server.handleCommand(pk.command, RemoteCommand.EXTERNAL_CONSOLE, socket.remoteAddress, pk.commandId);
							}
						} else {
							this.send(new Connected.PermissionDenied().encode());
						}
						break;
					default:
						// unknown packet, disconnect
						return;
				}
			}
		}
	}
	
	public override shared void consoleMessage(string node, ulong timestamp, string logger, string message, int commandId) {
		this.send(new Connected.ConsoleMessage(node, timestamp, logger, message, commandId).encode());
	}
	
	public override shared void updateNodes(bool add, string name) {
		this.send(new Status.UpdateNodes(add ? Status.UpdateNodes.ADD : Status.UpdateNodes.REMOVE, name).encode());
	}
	
	public override shared void updateStats(uint online, int max, uint uptime, uint sent, uint received, Types.NodeStats[] nodeStats) {
		this.send(new Status.UpdateStats(online, max, uptime, sent, received, nodeStats).encode());
	}

	public override shared ptrdiff_t send(const(void)[] data) {
		data = nativeToLittleEndian(cast(ushort)data.length) ~ data;
		return super.send(data);
	}
	
	public override shared inout string toString() {
		return "Classic" ~ super.toString();
	}
	
}

class WebExternalConsoleSession : ExternalConsoleSession {
	
	public shared this(shared Server server, shared Socket sharedSocket, bool delegate(ubyte[], ubyte[]) auth) {
		super(server, sharedSocket);
		Socket socket = cast()sharedSocket;
		string payload = Base64.encode(this.generatePayload());
		// send AuthCredentials
		this.send(Login.AuthCredentials.ID, [
			"protocol": JSONValue(Software.externalConsole),
			"hash": JSONValue(server.settings.externalConsoleHashAlgorithm != ""),
			"hash_algorithm": JSONValue(server.settings.externalConsoleHashAlgorithm),
			"payload": JSONValue(payload)
		]);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(EXTERNAL_CONSOLE_AUTH_TIMEOUT));
		ubyte[] buffer = new ubyte[256];
		auto recv = socket.receive(buffer);
		if(recv != Socket.ERROR) {
			this.server.traffic.receive(recv);
			auto json = this.parse(buffer[0..recv]);
			if(json.type == JSON_TYPE.OBJECT) {
				auto hash = "hash" in json;
				if(hash && (*hash).type == JSON_TYPE.STRING && commands) {
					if(auth(Base64.decode((*hash).str), cast(ubyte[])payload)) {
						// accepted!
						with(server.settings) {
						JSONValue[] games;
							if(pocket) games ~= JSONValue(["type": JSONValue(Types.Game.POCKET), "protocols": JSONValue(pocket.protocols)]);
							if(minecraft) games ~= JSONValue(["type": JSONValue(Types.Game.MINECRAFT), "protocols": JSONValue(minecraft.protocols)]);
							this.send(Login.Welcome.ID, [
								"status": JSONValue(Login.Welcome.Accepted.STATUS),
								"remote_commands": JSONValue(this.commands),
								"software": JSONValue(Software.name),
								"versions": JSONValue(cast(ubyte[])Software.versions),
								"display_name": JSONValue(server.settings.displayName),
								"games": JSONValue(games),
								"nodes": JSONValue(server.nodeNames)
							]);
						}
						server.add(this);
						this.loop();
						server.remove(this);
					} else {
						this.logAttemp();
						this.send(Login.Welcome.ID, ["status": JSONValue(Login.Welcome.WrongHash.STATUS)]);
						//TODO block after some attemps
					}
				} else {
					this.send(Login.Welcome.ID, ["status": JSONValue(Login.Welcome.TimedOut.STATUS)]);
				}
			}
		}
		socket.close();
	}
	
	private shared void loop() {
		Socket socket = cast()this.socket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(EXTERNAL_CONSOLE_TIMEOUT)); // times out
		ubyte[] buffer = new ubyte[EXTERNAL_CONSOLE_CONNECTED_BUFFER_LENGTH];
		while(true) {
			auto recv = socket.receive(buffer);
			if(recv == Socket.ERROR) return; // connection closed
			this.server.traffic.receive(recv);
			auto json = this.parse(buffer[0..recv]);
			if(json.type == JSON_TYPE.OBJECT) {
				auto id = "id" in json;
				if(id && (*id).type == JSON_TYPE.INTEGER) {
					switch((*id).integer) {
						case Status.KeepAlive.ID:
							auto count = "count" in json;
							this.send(Status.KeepAlive.ID, ["count": count ? *count : JSONValue(null)]);
							break;
						case Status.RequestStats.ID:
							this.autoUpdateStats();
							break;
						case Connected.Command.ID:
							if(this.commands) {
								auto command = "command" in json;
								auto commandId = "command_id" in json;
								if(command && (*command).type == JSON_TYPE.STRING && (commandId is null || (*commandId).type == JSON_TYPE.INTEGER)) {
									this.server.handleCommand((*command).str, RemoteCommand.EXTERNAL_CONSOLE, socket.remoteAddress, commandId ? cast(uint)(*commandId).integer : -1);
								}
							} else {
								this.send(Connected.PermissionDenied.ID, (JSONValue[string]).init);
							}
							break;
						default:
							// unknown packet, close the connection
							return;
					}
				}
			} else {
				// not-json packet, close
				return;
			}
		}
	}
	
	public override shared void consoleMessage(string node, ulong timestamp, string logger, string message, int commandId) {
		this.send(Connected.ConsoleMessage.ID, [
			"node": JSONValue(node),
			"timestamp": JSONValue(timestamp),
			"logger": JSONValue(logger),
			"message": JSONValue(message),
			"command_id": JSONValue(commandId)
		]);
	}
	
	public override shared void updateNodes(bool add, string name) {
		this.send(Status.UpdateNodes.ID, [
			"action": JSONValue(add ? Status.UpdateNodes.ADD : Status.UpdateNodes.REMOVE),
			"node": JSONValue(name)
		]);
	}
	
	public override shared void updateStats(uint online, int max, uint uptime, uint sent, uint received, Types.NodeStats[] nodeStats) {
		JSONValue[] nodes;
		foreach(node ; nodeStats) {
			nodes ~= JSONValue(["name": JSONValue(node.name), "tps": JSONValue(node.tps), "ram": JSONValue(node.ram), "cpu": JSONValue(node.cpu)]);
		}
		this.send(Status.UpdateStats.ID, [
			"online_players": JSONValue(online),
			"max_players": JSONValue(max),
			"uptime": JSONValue(uptime),
			"upload": JSONValue(sent),
			"download": JSONValue(received),
			"nodes": JSONValue(nodes)
		]);
	}
	
	protected shared void send(ubyte id, JSONValue[string] data) {
		data["id"] = id;
		this.send(JSONValue(data).toString());
	}
	
	public override shared ptrdiff_t send(const(void)[] data) {
		ubyte[] header = [0b10000001];
		if(data.length < 0b01111110) {
			header ~= data.length & 255;
		} else if(data.length < ushort.max) {
			header ~= 0b01111110;
			header ~= nativeToBigEndian(cast(ushort)data.length);
		} else {
			header ~= 0b01111111;
			header ~= nativeToBigEndian(cast(ulong)data.length);
		}
		return super.send(header ~ data);
	}
	
	private shared JSONValue parse(ubyte[] payload) {
		if(payload.length > 2 && (payload[0] & 0b1111) == 1) {
			bool masked = (payload[1] & 0b10000000) != 0;
			size_t length = payload[1] & 0b01111111;
			size_t index = 2;
			if(length == 0b01111110) {
				if(payload.length >= index + 2) {
					ubyte[2] bytes = payload[index..index+2];
					length = bigEndianToNative!ushort(bytes);
					index += 2;
				}
			} else if(length == 0b01111111) {
				if(payload.length >= index + 8) {
					ubyte[8] bytes = payload[index..index+8];
					length = bigEndianToNative!ulong(bytes).to!size_t;
					length += 8;
				}
			}
			if(masked && payload.length >= index + 4) {
				ubyte[4] mask = payload[index..index+4];
				payload = payload[4..$];
				foreach(i, ref ubyte p; payload) {
					p ^= mask[i % 4];
				}
				index += 4;
			}
			if(length <= payload.length - index) return parseJSON(cast(string)payload[index..index+length]);
		}
		return JSONValue.init;
	}
	
	public override shared inout string toString() {
		return "Web" ~ super.toString();
	}
	
}
