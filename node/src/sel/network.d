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
module sel.network;

import core.thread : Thread, dur;
import std.bitmanip : read, nativeToLittleEndian;
import std.conv : to;
import std.socket;
import std.system : Endian;

import sel.util.log;

final class Handler {
	
	private static shared(Handler) n_shared_instance;
	
	public static nothrow @property @safe @nogc shared(Handler) sharedInstance() {
		return n_shared_instance;
	}
	
	private Socket socket;
	private ubyte[] buffer = new ubyte[2 ^^ 14];
	
	public this() {
		n_shared_instance = cast(shared)this;
	}
	
	public void connect(Address address) {
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
	
	public void unblock() {
		this.socket.blocking = false;
	}
	
	public ubyte[] receive(size_t amount) {
		ubyte[] buffer = new ubyte[amount];
		this.socket.receive(buffer);
		return buffer;
	}
	
	private ubyte[] n_next;
	private size_t n_next_length = 0;

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
			ptrdiff_t recv = this.socket.receive(this.buffer);
			if(recv > 0) {
				this.n_next ~= this.buffer[0..recv];
			} else {
				if(recv == 0) closed = true;
				return false;
			}
		}
		return true;
	}

	/**
	 * Returns: the amount of bytes sent
	 */
	public size_t send(ubyte[] buffer) {
		buffer = nativeToLittleEndian(buffer.length.to!uint) ~ buffer;
		size_t length = 0;
		ptrdiff_t sent;
		do {
			if((sent = this.socket.send(buffer[length..$])) <= 0) break; // connection closed or another error
		} while((length += sent) < buffer.length);
		return length;
	}
	
	public shared synchronized ptrdiff_t send(ubyte[] buffer) {
		return (cast()this).send(buffer);
	}
	
	public shared @property string lastError() {
		return lastSocketError();
	}
	
	public void close() {
		this.socket.close();
	}
	
}
