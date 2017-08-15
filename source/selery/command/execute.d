module selery.command.execute;

import std.string : strip, startsWith;
import std.traits : isAbstractClass;

import selery.command.args : CommandArg;
import selery.command.command : CommandResult, Command;
import selery.command.util : CommandSender;

const(CommandResult) executeCommand(CommandSender sender, Command[] commands, string data) {
	CommandResult ret = CommandResult.NOT_FOUND;
	data = data.strip;
	foreach(command ; commands) {
		foreach(name ; command.command ~ command.aliases) {
			if(data.length == name.length ? data == name : data.startsWith(name ~ " ")) {
				const result = executeCommand(sender, command, data[name.length..$]);
				if(result.successful) return result;
				else bestResult(ret, result);
			}
		}
	}
	return ret;
}

const(CommandResult) executeCommand(CommandSender sender, Command command, string data) {
	CommandResult ret = CommandResult.NOT_FOUND;
	foreach(overload ; command.overloads) {
		if(overload.callableBy(sender)) {
			const result = executeCommand(sender, overload, data);
			if(result.successful) return result;
			else bestResult(ret, result);
		}
	}
	return ret;
}

const(CommandResult) executeCommand(T)(CommandSender sender, Command.Overload overload, T data) if(is(T == string) || is(T == CommandArg[])) {
	return overload.callArgs(sender, data);
}

private void bestResult(ref CommandResult current, const CommandResult cmp) {
	if(current.result == CommandResult.notFound && cmp.result > CommandResult.notFound || current.result == CommandResult.invalidSyntax && cmp.result > CommandResult.invalidSyntax) {
		current.result = cmp.result;
		current.args = cast(string[])cmp.args;
	}
}
