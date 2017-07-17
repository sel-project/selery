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
module sel.network.hncom;

debug import core.thread : Thread;

import std.bitmanip : read, nativeToLittleEndian;
static import std.concurrency;
import std.conv : to;
import std.datetime : dur, msecs;
import std.socket;
import std.system : Endian;
import std.variant : Variant;

abstract class Handler {
	
	private static shared(Handler) n_shared_instance;
	
	public static nothrow @property @safe @nogc shared(Handler) sharedInstance() {
		return n_shared_instance;
	}
	
	public shared this() {
		n_shared_instance = this;
	}

	/**
	 * Receives the next packet when there's one available.
	 * This action is blocking.
	 */
	public shared abstract ubyte[] receive();

	/**
	 * Starts a new thread and send a new message to the server
	 * when a new packet arrives.
	 */
	public shared void receiveLoop(std.concurrency.Tid server) {
		debug Thread.getThis().name = "Network";
		while(true) {
			std.concurrency.send(server, this.receive.idup);
		}
	}

	/**
	 * Returns: the amount of bytes sent
	 */
	public shared synchronized abstract ptrdiff_t send(ubyte[] buffer);

	/**
	 * Closes the connection with the hub.
	 */
	public shared abstract void close();
	
}

class SocketHandler : Handler {

	private Socket socket;
	
	private ubyte[] n_next;
	private size_t n_next_length = 0;
	
	public shared this(Address address) {
		super();
		version(Posix) {
			Socket socket = new Socket(address.addressFamily, SocketType.STREAM, cast(UnixAddress)address ? cast(ProtocolType)0 : ProtocolType.TCP);
		} else {
			Socket socket = new TcpSocket(address.addressFamily);
		}
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		//socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dur!"seconds"(2));
		socket.blocking = true;
		socket.connect(address);
		this.socket = cast(shared)socket;
	}

	public override shared ubyte[] receive() {
		return this.next();
	}

	private shared ubyte[] next() {
		ubyte[] buffer = cast(ubyte[])this.n_next;
		if(this.n_next_length == 0) {
			if(!this.addNext(4, buffer)) return new ubyte[0]; // closed
			this.n_next_length = read!(uint, Endian.littleEndian)(buffer);
		}
		if(this.n_next_length == 0 || !this.addNext(this.n_next_length, buffer)) return new ubyte[0]; // closed
		ubyte[] ret = buffer[0..this.n_next_length];
		this.n_next = cast(shared)buffer[this.n_next_length..$];
		this.n_next_length = 0;
		return ret;
	}
	
	private shared bool addNext(size_t amount, ref ubyte[] next) {
		ubyte[] buffer = new ubyte[4096];
		while(next.length < amount) {
			ptrdiff_t recv = (cast()this.socket).receive(buffer);
			if(recv > 0) {
				next ~= buffer[0..recv];
			} else {
				return false;
			}
		}
		return true;
	}

	public shared synchronized override ptrdiff_t send(ubyte[] buffer) {
		return this.sendBuffer(nativeToLittleEndian(buffer.length.to!uint) ~ buffer);
	}

	private shared size_t sendBuffer(ubyte[] buffer) {
		size_t length = 0;
		ptrdiff_t sent;
		do {
			if((sent = (cast()this.socket).send(buffer[length..$])) <= 0) break; // connection closed or another error
		} while((length += sent) < buffer.length);
		return length;
	}

	public shared override void close() {
		(cast()this.socket).close();
	}

}

class TidAddress : UnknownAddress {

	public std.concurrency.Tid tid;

	public this(std.concurrency.Tid tid) {
		this.tid = tid;
	}

	alias tid this;

}

class MessagePassingHandler : Handler {

	public std.concurrency.Tid hub;

	public shared this(shared std.concurrency.Tid hub) {
		super();
		this.hub = hub;
		std.concurrency.send(cast()hub, std.concurrency.thisTid);
	}

	public shared override ubyte[] receive() {
		return std.concurrency.receiveOnly!(immutable(ubyte)[])().dup;
	}

	public shared synchronized override ptrdiff_t send(ubyte[] buffer) {
		std.concurrency.send(cast()this.hub, buffer.idup);
		return buffer.length;
	}

	public shared override void close() {}

}
