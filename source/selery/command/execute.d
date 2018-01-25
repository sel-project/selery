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
module selery.command.execute;

import std.string : strip, indexOf;
import std.traits : isAbstractClass;

import selery.command.args : CommandArg;
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
