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
