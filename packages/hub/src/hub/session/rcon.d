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
 * License: $(HTTP www.gnu.org/licenses/lgpl-3.0.html, GNU General Lesser Public License v3).
 * 
 * Source: $(HTTP www.github.com/sel-project/sel-server/blob/master/hub/sel/network/rcon.d, sel/network/rcon.d)
 */
module hub.session.rcon;

import core.atomic : atomicOp;
import core.thread : Thread;

import std.bitmanip : write, peek, nativeToLittleEndian;
import std.conv : to;
import std.datetime : dur;
import std.socket;
import std.system : Endian;

import com.sel;

import hub.constants;
import hub.server : Server;
import hub.network.handler : HandlerThread;
import hub.network.session : Session;
import hub.util.log : log;
import hub.util.thread : SafeThread;

mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".status : RemoteCommand;");

/**
 * The handler thread only accepts connections on a blocking
 * TCP socket and starts new sessions in another thread, if
 * the address of the client is not blocked by the server.
 */
final class RconHandler : HandlerThread {
	
	public this(shared Server server) {
		with(server.settings) super(server, createSockets!TcpSocket("rcon", rconAddresses, RCON_BACKLOG));
	}
	
	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		while(true) {
			Socket client = socket.accept();
			if(!this.server.isBlocked(client.remoteAddress)) {
				new SafeThread({
					shared RconSession session = new shared RconSession(this.server, client);
					delete session;
				}).start();
			} else {
				client.close();
			}
		}
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
final class RconSession : Session {

	private static shared int commandsCount = 1;
	
	private shared Socket socket;
	private immutable string remoteAddress;

	private shared int[int] commandTable;
	
	public shared this(shared Server server, Socket socket) {
		super(server);
		this.socket = cast(shared)socket;
		this.remoteAddress = socket.remoteAddress.to!string;
		if(Thread.getThis().name == "") Thread.getThis().name = "rconSession#" ~ to!string(this.id);
		// wait for the login or disconnect
		ubyte[] payload = new ubyte[14 + server.settings.rconPassword.length];
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(1));
		auto recv = socket.receive(payload);
		if(recv >= 14) {
			// format is length(int32le), requestId(int32le), packetId(int32le), payload(ubyte[]), padding(x0, x0)
			if(payload[8] == 3 && payload[12..$-2] == server.settings.rconPassword) {
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
	 * Waits for a command packet and let the server parses
	 * it if it is longer than 0 bytes.
	 */
	protected shared void loop() {
		Socket socket = cast()this.socket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(0)); // it was changed because the first packet couldn't be sent instantly
		// the session doesn't timeout
		// socket.blocking = true;
		ubyte[] buffer = new ubyte[RCON_CONNECTED_BUFFER_LENGTH];
		while(true) {
			auto recv = socket.receive(buffer);
			if(recv < 14 || buffer[8] != 2) return; // connection closed, invalid packet format or invalid packet id
			this.server.traffic.receive(recv);
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
	
	public override shared ptrdiff_t send(const(void)[] data) {
		data = nativeToLittleEndian(data.length.to!uint) ~ data;
		this.server.traffic.send(data.length);
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
