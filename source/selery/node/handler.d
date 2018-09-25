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
import std.socket : Socket, TcpSocket, Address, SocketOptionLevel, SocketOption;
import std.system : Endian;

import selery.hncom.io : HncomPacket;

import xbuffer : Buffer, BufferOverflowException;

class HncomStream {

	public Socket socket;

	private size_t length;
	private Buffer buffer;

	public this(Socket socket) {
		this.socket = socket;
		this.buffer = new Buffer(1024);
	}

	public ptrdiff_t send(Buffer buffer) {
		buffer.write!(Endian.littleEndian, uint)(buffer.data.length.to!uint, 0);
		return this.sendImpl(buffer);
	}

	private ptrdiff_t sendImpl(Buffer buffer) {
		size_t sent = 0;
		while(sent < buffer.data.length) {
			ptrdiff_t s = this.socket.send(buffer.data[sent..$]);
			if(s <= 0) break;
			else sent += s;
		}
		return sent;
	}

	public Buffer receive() {
		void[] recv = this.receiveImpl();
		if(recv is null) return null;
		Buffer buffer = new Buffer(this.buffer.data ~ recv);
		if(this.length == 0) return this.parseLength(buffer);
		else return this.parseBody(buffer);
	}

	private ubyte[] receiveImpl() {
		static ubyte[] buffer = new ubyte[4096];
		ptrdiff_t recv = this.socket.receive(buffer);
		if(recv > 0) return buffer[0..recv];
		else return null;
	}

	private Buffer parseLength(Buffer buffer) {
		try {
			if((this.length = buffer.read!(Endian.littleEndian, uint)()) != 0) return this.parseBody(buffer);
			else return null;
		} catch(BufferOverflowException) {
			this.buffer.data = buffer.data;
			return this.receive();
		}
	}

	private Buffer parseBody(Buffer buffer) {
		if(buffer.canRead(this.length)) {
			void[] ret = buffer.readData(this.length);
			this.length = 0;
			this.buffer.data = buffer.data;
			return new Buffer(ret);
		} else {
			this.buffer.data = buffer.data;
			return this.receive();
		}
	}

}

class Handler {
	
	private static shared(Handler) _sharedInstance;
	
	public static nothrow @property @safe @nogc shared(Handler) sharedInstance() {
		return _sharedInstance;
	}

	private HncomStream stream;
	
	public shared this(Address address) {
		_sharedInstance = this;
		Socket socket = new TcpSocket(address.addressFamily);
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		//socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));
		//socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dur!"seconds"(2));
		socket.blocking = true;
		socket.connect(address);
		this.stream = cast(shared)new HncomStream(socket);
	}

	/**
	 * Returns: the amount of bytes sent
	 */
	public deprecated shared synchronized ptrdiff_t send(ubyte[] buffer) {
		return (cast()this.stream).send(new Buffer(buffer));
	}

	public shared synchronized ptrdiff_t send(HncomPacket packet) {
		Buffer buffer = new Buffer(1024);
		packet.encode(buffer);
		return (cast()this.stream).send(buffer);
	}
	
	/**
	 * Receives the next packet when there's one available.
	 * This action is blocking.
	 */
	public shared Buffer receive() {
		return (cast()this.stream).receive();
	}

	/**
	 * Closes the connection with the hub.
	 */
	public shared void close() {
		(cast()this.stream.socket).close();
	}

	/**
	 * Starts a new thread and send a new message to the server
	 * when a new packet arrives.
	 */
	public shared void receiveLoop(std.concurrency.Tid server) {
		debug Thread.getThis().name = "node.hncom.client";
		while(true) {
			std.concurrency.send(server, cast(shared)this.receive);
		}
	}
	
}
