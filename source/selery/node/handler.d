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
module selery.node.handler;

debug import core.thread : Thread;

static import std.concurrency;
import std.conv : to;
import std.datetime : dur, msecs;
import std.socket;
import std.system : Endian;
import std.variant : Variant;

import sel.net.modifiers : LengthPrefixedStream;
import sel.net.stream : TcpStream;

alias HncomStream = LengthPrefixedStream!(uint, Endian.littleEndian);

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
		debug Thread.getThis().name = "hncom_client";
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

	private HncomStream stream;
	
	private ubyte[] n_next;
	private size_t n_next_length = 0;
	
	public shared this(Address address) {
		super();
		Socket socket = new TcpSocket(address.addressFamily);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		//socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));
		//socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dur!"seconds"(2));
		socket.blocking = true;
		socket.connect(address);
		this.stream = cast(shared)new HncomStream(new TcpStream(socket, 8192));
	}

	public override shared ubyte[] receive() {
		return (cast()this.stream).receive();
	}

	public shared synchronized override ptrdiff_t send(ubyte[] buffer) {
		return (cast()this.stream).send(buffer);
	}

	public shared override void close() {
		(cast()this.stream.stream.socket).close();
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
