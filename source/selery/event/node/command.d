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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/node/command.d, selery/event/node/command.d)
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

final class CommandNotFoundEvent : CommandEvent {

	private string _command;

	public this(CommandSender sender, string command) {
		super(sender);
		this._command = command;
	}

	public pure nothrow @property @safe @nogc string command() {
		return this._command;
	}

}

final class CommandFailedEvent : CommandEvent {

	private Command _command;

	public this(CommandSender sender, Command command) {
		super(sender);
		this._command = command;
	}

	public pure nothrow @property @safe @nogc Command command() {
		return this._command;
	}

}
