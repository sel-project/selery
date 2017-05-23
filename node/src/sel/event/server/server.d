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

import sel.command.util : CommandSender;
import sel.event.event : Event;

interface ServerEvent : Event {}

interface CommandEvent : ServerEvent {}

class InvalidParametersEvent : CommandEvent {

	private CommandSender n_sender;
	private string n_command;

	public this(CommandSender sender, string command) {
		this.n_sender = sender;
		this.n_command = command;
	}

	public pure nothrow @property @safe @nogc CommandSender sender() {
		return this.n_sender;
	}

	public pure nothrow @property @safe @nogc string command() {
		return this.n_command;
	}

}

class UnknownCommandEvent : CommandEvent {

	private CommandSender n_sender;
	
	public this(CommandSender sender) {
		this.n_sender = sender;
	}
	
	public pure nothrow @property @safe @nogc CommandSender sender() {
		return this.n_sender;
	}

}
