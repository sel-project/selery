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

import core.thread : Thread;
import std.bitmanip : read, nativeToLittleEndian;
import std.conv : to;
import std.datetime : dur, msecs;
import std.socket;
import std.system : Endian;
import std.variant : Variant;

import sel.util.log;

abstract class Handler {
	
	private static shared(Handler) n_shared_instance;
	
	public static nothrow @property @safe @nogc shared(Handler) sharedInstance() {
		return n_shared_instance;
	}

	private ubyte[] buffer;
	
	private ubyte[] n_next;
	private size_t n_next_length = 0;
	
	public this() {
		n_shared_instance = cast(shared)this;
		this.buffer = new ubyte[8192];
	}
	
	public abstract void unblock();

	public ubyte[] next(ref bool closed) {
		if(this.n_next_length == 0) {
			if(!this.addNext(4, closed)) return new ubyte[0];
			this.n_next_length = read!(uint, Endian.littleEndian)(this.n_next);
		}
		if(this.n_next_length == 0 || !this.addNext(this.n_next_length, closed)) return new ubyte[0];
		ubyte[] ret = this.n_next[0..this.n_next_length];
		this.n_next = this.n_next[this.n_next_length..$];
		this.n_next_length = 0;
		return ret;
	}
	
	private bool addNext(size_t amount, ref bool closed) {
		while(this.n_next.length < amount) {
			ptrdiff_t recv = this.receiveBuffer(this.buffer);
			if(recv > 0) {
				this.n_next ~= this.buffer[0..recv];
			} else {
				if(recv == 0) closed = true;
				return false;
			}
		}
		return true;
	}

	protected abstract ptrdiff_t receiveBuffer(ref ubyte[] buffer);

	/**
	 * Returns: the amount of bytes sent
	 */
	public shared synchronized ptrdiff_t send(ubyte[] buffer) {
		return (cast()this).sendImpl(buffer);
	}

	public size_t sendImpl(ubyte[] buffer) {
		return this.sendBuffer(nativeToLittleEndian(buffer.length.to!uint) ~ buffer);
	}

	protected abstract size_t sendBuffer(ubyte[] buffer);
	
	public shared @property string lastError() {
		return lastSocketError();
	}
	
	public abstract void close();
	
}

class SocketHandler : Handler {

	private Socket socket;
	
	public this(Address address) {
		super();
		version(Posix) {
			this.socket = new Socket(address.addressFamily, SocketType.STREAM, cast(UnixAddress)address ? cast(ProtocolType)0 : ProtocolType.TCP);
		} else {
			this.socket = new TcpSocket(address.addressFamily);
		}
		this.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		this.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(5));
		this.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dur!"seconds"(5));
		this.socket.blocking = true;
		this.socket.connect(address);
	}

	public override void unblock() {
		this.socket.blocking = false;
	}

	protected override ptrdiff_t receiveBuffer(ref ubyte[] buffer) {
		return this.socket.receive(buffer);
	}

	protected override size_t sendBuffer(ubyte[] buffer) {
		size_t length = 0;
		ptrdiff_t sent;
		do {
			if((sent = this.socket.send(buffer[length..$])) <= 0) break; // connection closed or another error
		} while((length += sent) < buffer.length);
		return length;
	}

	public override void close() {
		this.socket.close();
	}

}

static import std.concurrency;

class TidAddress : Address {

	public std.concurrency.Tid tid;

	public this(std.concurrency.Tid tid) {
		this.tid = tid;
	}

	public override sockaddr* name() {
		return null;
	}

	public const override const(sockaddr)* name() {
		return null;
	}

	public override const int nameLen() {
		return 0;
	}

	alias tid this;

}

class MessagePassingHandler : Handler {

	private std.concurrency.Tid hub;

	private ptrdiff_t delegate(ref ubyte[]) rec;

	public this(std.concurrency.Tid hub) {
		super();
		this.hub = hub;
		std.concurrency.send(hub, std.concurrency.thisTid);
		this.rec = &this.receiveBlocking;
	}

	public override void unblock() {
		this.rec = &this.receiveNonBlocking;
	}

	private ptrdiff_t receiveBlocking(ref ubyte[] buffer) {
		auto recv = std.concurrency.receiveOnly!(immutable(ubyte)[])();
		buffer ~= recv.dup;
		return recv.length; // 0 for close connection
	}

	private ptrdiff_t receiveNonBlocking(ref ubyte[] buffer) {
		ptrdiff_t ret = -1; // -1 means nothing was received
		std.concurrency.receiveTimeout(msecs(0),
			(immutable(ubyte)[] b) {
				buffer ~= b.dup;
				ret = buffer.length; // 0 for close connection
			},
			(Variant v) {} // close
		);
		return ret;
	}

	public override ptrdiff_t receiveBuffer(ref ubyte[] buffer) {
		return this.rec(buffer);
	}

	public override size_t sendBuffer(ubyte[] buffer) {
		std.concurrency.send(this.hub, buffer.idup);
		return buffer.length;
	}

	public override void close() {}

}
