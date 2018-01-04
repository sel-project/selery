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
/**
 * RCON allows the execution of commands remotely and it's available
 * in the official Minecraft server since 1.9. It's an implementation
 * of the $(HTTP https://developer.valvesoftware.com/wiki/Source_RCON_Protocol, RCON protocol)
 * by Valve.
 * 
 * The protocol is only implemented in SEL to mantain compatibility with
 * other server softwares and managers that uses it.
 * A better alternative offered by SEL is the external console protocol,
 * which is an advanced version of RCON and also accessible through browser
 * using websockets.
 * 
 */
module selery.hub.handler.rcon;

import core.atomic : atomicOp;
import core.thread : Thread;

import std.bitmanip : write, peek, nativeToLittleEndian;
import std.concurrency : spawn;
import std.conv : to;
import std.datetime : dur;
import std.socket;
import std.system : Endian;

import sel.hncom.status : RemoteCommand;
import sel.server.query : Query;
import sel.server.util;

import selery.about;
import selery.hub.server : HubServer;
import selery.util.thread : SafeThread;

/**
 * The handler thread only accepts connections on a blocking
 * TCP socket and starts new sessions in another thread, if
 * the address of the client is not blocked by the server.
 */
final class RconHandler : GenericServer {

	private shared HubServer server;
	
	public shared this(shared HubServer server) {
		super(server.info);
		this.server = server;
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
		debug Thread.getThis().name = "rcon_server@" ~ (cast()_socket).localAddress.toString();
		Socket socket = cast()_socket;
		while(true) {
			Socket client = socket.accept();
			if(!this.server.isBlocked(client.remoteAddress)) {
				new SafeThread(this.server.lang, {
					shared RconClient session = new shared RconClient(this.server, client);
					delete session;
				}).start();
			} else {
				client.close();
			}
		}
	}

	public override shared pure nothrow @property @safe @nogc ushort defaultPort() {
		return ushort(25575);
	}

}

/**
 * An Rcon session runs in a dedicated thread and only waits
 * for data on a blocking socket after the login.
 * 
 * The first login packet must arrive within 1 second since
 * the creation of the session and it must be a login packet
 * with the password in it.
 * If the packet doesn't arrive, its format is wrong or the 
 * password is wrong the session is closed.
 * 
 * Once successfully connected the socket's receive timeout
 * is set to infinite and the session only waits for remote
 * commands.
 * 
 * The session never times out and it's only closed when the
 * remote socket has been closed or a packet with the wrong
 * format is received.
 */
final class RconClient {

	private static shared uint _id;
	private static shared int commandsCount = 1;

	public immutable uint id;

	private shared HubServer server;

	private shared Socket socket;
	private immutable string remoteAddress;

	private shared int[int] commandTable;
	
	public shared this(shared HubServer server, Socket socket) {
		this.id = atomicOp!"+="(_id, 1);
		this.server = server;
		this.socket = cast(shared)socket;
		this.remoteAddress = socket.remoteAddress.to!string;
		debug Thread.getThis().name = "rcon_client#" ~ to!string(this.id) ~ "@" ~ this.remoteAddress;
		// wait for the login or disconnect
		ubyte[] payload = new ubyte[14 + server.config.hub.rconPassword.length];
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(1));
		auto recv = socket.receive(payload);
		if(recv >= 14) {
			// format is length(int32le), requestId(int32le), packetId(int32le), payload(ubyte[]), padding(x0, x0)
			if(payload[8] == 3 && payload[12..$-2] == server.config.hub.rconPassword) {
				this.send(payload[4..8], 2);
				server.add(this);
				this.loop();
				server.remove(this);
			} else {
				// wrong password or packet
				this.send(payload[4..8], -1);
			}
		}
		socket.close();
	}

	/**
	 * Waits for a command packet and let the server parse
	 * it if it is longer than 0 bytes.
	 */
	protected shared void loop() {
		Socket socket = cast()this.socket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(0)); // it was changed because the first packet couldn't be sent instantly
		// the session doesn't timeout
		// socket.blocking = true;
		ubyte[] buffer = new ubyte[1446];
		while(true) {
			auto recv = socket.receive(buffer);
			if(recv < 14 || buffer[8] != 2) return; // connection closed, invalid packet format or invalid packet id
			if(recv >= 15 && peek!(int, Endian.littleEndian)(buffer, 8) == 2) {
				// only handle commands that are at least 1-character long
				this.commandTable[commandsCount] = peek!(int, Endian.littleEndian)(buffer, 4);
				this.server.handleCommand(cast(string)buffer[12..recv-2], RemoteCommand.RCON, socket.remoteAddress, commandsCount);
				atomicOp!"+="(commandsCount, 1);
			}
		}
	}

	/**
	 * Sends a packet back using the given request id.
	 */
	public shared ptrdiff_t send(ubyte[4] request_id, int id, ubyte[] payload=[]) {
		return this.send(request_id ~ nativeToLittleEndian(id) ~ payload ~ cast(ubyte[])[0, 0]);
	}
	
	public shared ptrdiff_t send(const(void)[] data) {
		data = nativeToLittleEndian(data.length.to!uint) ~ data;
		return (cast()this.socket).send(data);
	}

	public shared void consoleMessage(string message, int id) {
		auto ptr = id in this.commandTable;
		if(ptr) {
			this.send(nativeToLittleEndian(*ptr), 0, cast(ubyte[])message);
			this.commandTable.remove(id);
		}
	}

	/**
	 * Represented as "Rcon(id, address:port)".
	 * Example:
	 * ---
	 * log(rcon);
	 * // Rcon(54, [::1]:54123)
	 * ---
	 */
	public shared inout string toString() {
		return "Rcon(" ~ to!string(this.id) ~ ", " ~ this.remoteAddress ~ ")";
	}
	
}
