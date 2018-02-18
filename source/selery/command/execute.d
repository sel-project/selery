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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/command/execute.d, selery/command/execute.d)
 */
module selery.command.execute;

import std.string : strip, indexOf;
import std.traits : isAbstractClass;

import selery.command.command : CommandResult, Command;
import selery.command.util : CommandSender;

const(CommandResult) executeCommand(CommandSender sender, string args) {
	args = args.strip;
	CommandResult ret = CommandResult.NOT_FOUND;
	immutable space = args.indexOf(" ");
	immutable name = space == -1 ? args : args[0..space];
	auto command = name in sender.availableCommands;
	if(command) ret = cast()executeCommand(sender, *command, space == -1 ? "" : args[space+1..$]);
	ret.command = name;
	return ret;
}

const(CommandResult) executeCommand(CommandSender sender, Command command, string args) {
	CommandResult ret = CommandResult.NOT_FOUND;
	foreach(overload ; command.overloads) {
		if(overload.callableBy(sender)) {
			const result = executeCommand(sender, overload, args);
			if(result.successful) return result;
			else bestResult(ret, result);
		}
	}
	return ret;
}

const(CommandResult) executeCommand(CommandSender sender, Command.Overload overload, string args) {
	return overload.callArgs(sender, args);
}

private void bestResult(ref CommandResult current, const CommandResult cmp) {
	if(current.result == CommandResult.notFound && cmp.result > CommandResult.notFound || current.result == CommandResult.invalidSyntax && cmp.result > CommandResult.invalidSyntax) {
		current.result = cmp.result;
		current.args = cast(string[])cmp.args;
	}
}
