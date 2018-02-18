/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/node/handler.d, selery/node/handler.d)
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
