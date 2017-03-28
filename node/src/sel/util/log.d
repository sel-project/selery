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
module sel.util.log;

import std.conv : to;
import std.path : dirSeparator;
import std.string : replace, startsWith, indexOf;

import common.sel;
import common.util.format : Text, writeln;
import common.util.time : milliseconds;

import sel.world.world : World;

mixin("import sul.protocol.hncom" ~ to!string(Software.hncom) ~ ".status : Log;");

private shared(Log)[] last_logged_messages;

public Log[] getAndClearLoggedMessages() {
	auto ret = cast(Log[])last_logged_messages;
	last_logged_messages.length = 0;
	return ret;
}

public void log_m(bool hub, E...)(int worldId, string logger, int id, E logs) {
	string message = "";
	foreach(immutable l ; logs) {
		static if(is(typeof(l) : string)) {
			message ~= l;
		} else {
			message ~= to!string(l);
		}
	}
	static if(hub) last_logged_messages ~= cast(shared)new Log(milliseconds, worldId, logger, message, id);
	writeln("[" ~ logger ~ "] " ~ message);
}

public void world_log(E...)(World world, E logs) {
	log_m!true(world.id, world.name, -1, logs);
}

public void command_log(E...)(int commandId, E logs) {
	log_m!true(Log.NO_WORLD, "command", commandId, logs);
}

/**
 * Logs a message to the node and the hub's console.
 * This function is the same as writeln, but also sends the message
 * to the hub and the eventual external consoles.
 * The function takes a number of arguments and concatenates them. If the
 * arguments are not strings they are transformed in it through the template
 * to in std.conv.
 * Example:
 * ---
 * log("string");
 * log("value: ", 33);
 * log(tuple(1, '2'), " ", new Object());
 * ---
 */
public void log(bool hub=true, string mod=__MODULE__, E...)(E logs) {
	enum m = mod.replace(".", dirSeparator);
	static if(mod.startsWith("sel.")) {
		enum mm = m[4..$];
	} else {
		static if(mod.indexOf(".") != -1) {
			enum mm = "plugin" ~ dirSeparator ~ m[0..mod.indexOf(".")];
		} else {
			enum mm = "plugin" ~ dirSeparator ~ m;
		}
	}
	log_m!hub(Log.NO_WORLD, mm, -1, logs);
}

public void debug_log(string m=__MODULE__, E...)(E logs) {
	log!(false, m ~ "@debug")(cast(string)Text.blue, logs);
}

public void warning_log(string m=__MODULE__, E...)(E logs) {
	log!(true, m ~ "@warning")(cast(string)Text.yellow, logs);
}

public void error_log(string m=__MODULE__, E...)(E logs) {
	log!(true, m ~ "@error")(cast(string)Text.red, logs);
}

public void success_log(string m=__MODULE__, E...)(E logs) {
	log!(true, m ~ "@success")(cast(string)Text.green, logs);
}
