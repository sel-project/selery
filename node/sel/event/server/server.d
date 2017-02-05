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
 * Events called on the server (and not on the world/entity). The functions marked
 * with @event in the plugin's main class will automatically be registered to the
 * server's event handler.
 */
module sel.event.server.server;

import std.conv : to;
import std.socket : Address;

import common.sel : Software;

import sel.event.event : Event, Cancellable;

mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".status : RemoteCommand;");

interface ServerEvent : Event {}

/**
 * Event dispatched when the server sends a command (through the device's console or
 * the external console, if actived).
 * The input is splitted for every space character, the first element of the array
 * is set as command and the rest as the arguments.<br>
 * command = input.split(" ")[0]<br>
 * arguments = input.split(" ")[1..$]<br>
 * Example:
 * ---
 * @event servercommand(ServerCommandEvent sce) {
 *    if(sce.command == "say") {
 *       d("Server is trying to say \"", args.join(" "), "\"");
 *       sce.doDefault = false;
 *    }
 * }
 * ---
 * 
 * $(VARS
 * 		$(VAR string, command)$(DESC the command, always lowercase)
 * 		$(VAR immutable(string)[], args)$(DESC the arguments for the command, splitted in the space characters)
 * 		$(VAR bool, doDefault)$(DESC indicating whether or not the server should handle this command)
 * )
 */
final class ServerCommandEvent : ServerEvent, Cancellable {

	enum Origin : ubyte {

		prompt = ubyte.max,
		hub = RemoteCommand.HUB,
		externalConsole = RemoteCommand.EXTERNAL_CONSOLE,
		rcon = RemoteCommand.RCON

	}

	mixin Cancellable.Implementation;

	private ubyte n_origin;
	private Address n_address;
	private string n_command;
	private immutable(string)[] n_args;

	public pure nothrow @safe @nogc this(ubyte origin, Address address, string command, immutable(string)[] args) {
		this.n_origin = origin;
		this.n_address = address;
		this.n_command = command;
		this.n_args = args;
	}

	public pure nothrow @property @safe @nogc ubyte origin() {
		return this.n_origin;
	}

	public pure nothrow @property @safe @nogc Address address() {
		return this.n_address;
	}

	public pure nothrow @property @safe @nogc string command() {
		return this.n_command;
	}

	public pure nothrow @property @safe @nogc immutable(string)[] args() {
		return this.n_args;
	}

}
