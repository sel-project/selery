/*
 * Copyright (c) 2017 SEL
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
module selery.event.node.command;

import selery.command.command : Command;
import selery.command.util : CommandSender;
import selery.event.event : Cancellable;
import selery.event.node.server : NodeServerEvent;
import selery.node.server : NodeServer;

abstract class CommandEvent : NodeServerEvent, Cancellable {

	mixin Cancellable.Implementation;

	public this(CommandSender sender) {
		super(sender.server);
	}

}

class CommandNotFoundEvent : CommandEvent {

	private string _command;

	public this(CommandSender sender, string command) {
		super(sender);
		this._command = command;
	}

}

class CommandFailedEvent : CommandEvent {

	private Command _command;

	public this(CommandSender sender, Command command) {
		super(sender);
		this._command = command;
	}

}
