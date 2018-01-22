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
module selery.commands;

import std.algorithm : sort, clamp, min, filter;
import std.conv : to;
import std.math : ceil;
import std.string : join, toLower, startsWith;
import std.traits : hasUDA, getUDAs;
import std.typetuple : TypeTuple;

import selery.about : Software;
import selery.command.command : Command;
import selery.command.util : CommandSender, WorldCommandSender, PocketType, SingleEnum, SnakeCaseEnum, Ranged, Position, Target;
import selery.config : Config, Gamemode, Difficulty, Dimension;
import selery.entity.entity : Entity;
import selery.lang : Translation, Translatable;
import selery.log : Format;
import selery.node.server : isServerRunning, NodeServer, ServerCommandSender;
import selery.player.java : JavaPlayer;
import selery.player.player : Player, InputMode;
import selery.plugin : Description, permission;
import selery.util.messages : Messages;
import selery.world.world : Time;

enum vanilla;
enum op;

struct aliases {

	string[] aliases;

	this(string[] aliases...) {
		this.aliases = aliases;
	}

}

/**
 * Supported vanilla commands (based on MCPE):
 * [ ] clear
 * [ ] clone
 * [x] deop
 * [ ] difficulty
 * [ ] effect
 * [ ] enchant
 * [ ] execute
 * [ ] fill
 * [ ] gamemode
 * [ ] gamerule
 * [ ] give
 * [x] help
 * [x] kick
 * [ ] kill
 * [x] list
 * [ ] locate
 * [x] me
 * [x] op
 * [ ] playsound
 * [ ] replaceitem
 * [ ] say
 * [ ] setblock
 * [x] setmaxplayers
 * [ ] setworldspawn
 * [ ] spawnpoint
 * [ ] spreadplayers
 * [x] stop
 * [ ] stopsound
 * [ ] summon
 * [x] tell
 * [ ] testfor
 * [ ] testforblock
 * [ ] testforblocks
 * [ ] time
 * [ ] title
 * [x] toggledownfall
 * [ ] tp (teleport)
 * [x] transferserver
 * [x] weather
 * [ ] wsserver
 * [ ] xp
 * 
 * Supported multiplayer commands:
 * [ ] ban
 * [ ] ban-ip
 * [ ] pardon
 * [x] stop
 * [ ] whitelist
 */
final class Commands {

	enum list = mixin({
		string[] commands;
		foreach(member ; __traits(allMembers, typeof(this))) {
			static if(member[$-1] == '0') commands ~= member[0..$-1];
		}
		return "TypeTuple!(" ~ commands.to!string[1..$-1] ~ ")";
	}());

	static Commands register(shared NodeServer server) {
		return new Commands(server).register();
	}

	private shared NodeServer server;

	public this(shared NodeServer server) {
		this.server = server;
	}

	public Commands register() {
		auto server = cast()this.server;
		const config = this.server.config.node;
		foreach(command ; list) {
			if(mixin("config." ~ command ~ "Command")) this.registerImpl!(command, 0)(server);
		}
		return this;
	}
	
	private void registerImpl(string command, size_t count)(NodeServer server) {
		mixin("alias C = " ~ command ~ to!string(count) ~ ";");
		static if(count == 0) {
			static if(hasUDA!(C, vanilla)) enum description = Translatable.fromBedrock("commands." ~ command ~ ".description");
			else enum description = Translatable("commands." ~ command ~ ".description");
			static if(hasUDA!(C, aliases)) enum aliases = getUDAs!(C, aliases)[0].aliases;
			else enum string[] aliases = [];
			static if(hasUDA!(C, permission)) enum permissions = getUDAs!(C, permission)[0].permissions;
			else enum string[] permissions = [];
			server.registerCommand!C(mixin("&this." ~ command ~ to!string(count)), convertedName!command, Description(description), aliases, hasUDA!(C, op), permissions, false);
		} else {
			server.registerCommand!C(mixin("&this." ~ command ~ to!string(count)), convertedName!command, Description.init, [], 0, [], false);
		}
		static if(__traits(hasMember, typeof(this), command ~ to!string(count + 1))) this.registerImpl!(command, count + 1)(server);
	}

	public Commands unregister() {
		//TODO unregister overloads using delegate's pointers
		auto server = cast()this.server;
		foreach(command ; list) {
			this.unregisterImpl!(command, 0)(server);
		}
		return this;
	}
	
	private void unregisterImpl(string command, size_t count)(NodeServer server) {
		mixin("alias C = " ~ command ~ to!string(count) ~ ";");
		//server.unregisterCommandByOverload(mixin("&this." ~ command ~ to!string(count)), convertedName!command);
		static if(__traits(hasMember, typeof(this), command ~ to!string(count + 1))) this.unregisterImpl!(command, count + 1)(server);
	}

	void about0(CommandSender sender) {
		sender.sendMessage(Translation(Messages.about.software, Software.name ~ " " ~ Software.fullVersion));
		if(this.server.plugins.length) {
			sender.sendMessage(Translation(Messages.about.plugins, this.server.plugins.length));
			foreach(_plugin ; this.server.plugins) {
				auto plugin = cast()_plugin;
				sender.sendMessage("* ", Format.green, plugin.name, Format.reset, " ", (!plugin.vers.startsWith("~") ? "v" : ""), plugin.vers);
			}
		}
	}

	@vanilla @op deop0(WorldCommandSender sender, Player player) {
		if(player.op) {
			player.op = false;
			player.sendMessage(Translation(Messages.deop.message));
			sender.sendMessage(Translation(Messages.deop.success, player.displayName));
		} else {
			sender.sendMessage(Translation(Messages.deop.failed, player.displayName));
		}
	}

	@vanilla deop1(ServerCommandSender sender, string player) {
		//TODO get player(s) from server.selectPlayers
	}
	
	@vanilla @op difficulty0(WorldCommandSender sender, Difficulty difficulty) {
		//TODO unsupported by selery
		//sender.world.difficulty = difficulty;
		sender.sendMessage(Translation(Messages.difficulty.success, difficulty));
	}
	
	@vanilla difficulty1(WorldCommandSender sender, Ranged!(ubyte, 0, 3) difficulty) {
		this.difficulty0(sender, cast(Difficulty)difficulty.value);
	}

	@vanilla difficulty2(ServerCommandSender sender, string world, Difficulty difficulty) {
		//TODO
	}

	@vanilla difficulty3(ServerCommandSender sender, string world, Ranged!(ubyte, 0, 3) difficulty) {
		this.difficulty2(sender, world, cast(Difficulty)difficulty.value);
	}

	@vanilla @op @aliases("gm") gamemode0(WorldCommandSender sender, Gamemode gamemode, Player[] target) {
		foreach(player ; target) {
			player.gamemode = gamemode;
			sender.sendMessage(Translation(Messages.gamemode.successOther, gamemode, player.displayName));
		}
	}
	
	@vanilla gamemode2(WorldCommandSender sender, Ranged!(ubyte, 0, 3) gamemode, Player[] target) {
		this.gamemode0(sender, cast(Gamemode)gamemode.value, target);
	}

	@vanilla gamemode1(Player sender, Gamemode gamemode) {
		sender.gamemode = gamemode;
		sender.sendMessage(Translation(Messages.gamemode.successSelf, gamemode));
	}

	@vanilla gamemode3(Player sender, Ranged!(ubyte, 0, 3) gamemode) {
		this.gamemode2(sender, gamemode, [sender]);
	}

	@vanilla gamemode4(ServerCommandSender sender, Gamemode gamemode, string target) {
		//TODO
	}

	@vanilla gamemode5(ServerCommandSender sender, Ranged!(ubyte, 0, 3) gamemode, string target) {
		this.gamemode4(sender, cast(Gamemode)gamemode.value, target);
	}

	enum Gamerule { depleteHunger, doDaylightCycle, doWeatherCycle, naturalRegeneration, pvp, randomTickSpeed }

	@vanilla @op gamerule0(WorldCommandSender sender) {
		sender.sendMessage(join([__traits(allMembers, Gamerule)], ", "));
	}

	@vanilla gamerule1(WorldCommandSender sender, Gamerule rule) {
		//TODO
		sender.sendMessage(rule, " = ", {
			final switch(rule) with(Gamerule) {
				case depleteHunger: return sender.world.depleteHunger.to!string;
				case doDaylightCycle: return sender.world.time.cycle.to!string;
				case doWeatherCycle: return sender.world.weather.cycle.to!string;
				case naturalRegeneration: return sender.world.naturalRegeneration.to!string;
				case pvp: return sender.world.pvp.to!string;
				case randomTickSpeed: return sender.world.randomTickSpeed.to!string;
			}
		}());
	}

	@vanilla gamerule2(WorldCommandSender sender, Gamerule rule, bool value) {
		//TODO
		switch(rule) with(Gamerule) {
			case depleteHunger: sender.world.depleteHunger = value; break;
			case doDaylightCycle: sender.world.time.cycle = value; break;
			case doWeatherCycle: sender.world.weather.cycle = value; break;
			case naturalRegeneration: sender.world.naturalRegeneration = value; break;
			case pvp: sender.world.pvp = value; break;
			default:
				sender.sendMessage(Format.red, Translation(Messages.gamerule.invalidType, rule));
				return;
		}
		sender.sendMessage(Translation(Messages.gamerule.success, rule, value));
	}

	@vanilla gamerule3(WorldCommandSender sender, Gamerule rule, Ranged!(int, 0, int.max) value) {
		//TODO
		switch(rule) with(Gamerule) {
			case randomTickSpeed: sender.world.randomTickSpeed = value; break;
			default:
				sender.sendMessage(Format.red, Translation(Messages.gamerule.invalidType, rule));
				return;
		}
		sender.sendMessage(Translation(Messages.gamerule.success, rule, value.value));
	}

	@vanilla help0(JavaPlayer sender, int page=1) {
		// pocket players have the help command client-side
		Command[] commands;
		foreach(name, command; sender.availableCommands) {
			if(command.name == name && !command.hidden) commands ~= command;
		}
		sort!((a, b) => a.name < b.name)(commands);
		immutable pages = cast(size_t)ceil(commands.length.to!float / 7); // commands.length should always be at least 1 (help command)
		page = clamp(--page, 0, pages - 1);
		sender.sendMessage(Format.darkGreen, Messages.help.header, page+1, pages);
		foreach(command ; commands[page*7..min($, (page+1)*7)]) {
			if(command.description.type == Description.EMPTY) sender.sendMessage(command.name);
			else if(command.description.type == Description.TEXT) sender.sendMessage(command.name, " - ", command.description.text);
			else sender.sendMessage(command.name, " - ", Translation(command.description.translatable));
		}
		sender.sendMessage(Format.green, Translation(Messages.help.footer));
	}
	
	@vanilla help1(ServerCommandSender sender) {
		Command[] commands;
		foreach(name, command; sender.availableCommands) {
			if(!command.hidden && name == command.name) {
				foreach(overload ; command.overloads) {
					if(overload.callableBy(sender)) {
						commands ~= command;
						break;
					}
				}
			}
		}
		sort!((a, b) => a.name < b.name)(commands);
		foreach(cmd ; commands) {
			if(cmd.description.type == Description.EMPTY) sender.sendMessage(Format.yellow, cmd.name, ":");
			else if(cmd.description.type == Description.TEXT) sender.sendMessage(Format.yellow, cmd.description.text);
			else sender.sendMessage(Format.yellow, Translation(cmd.description.translatable));
			foreach(overload ; cmd.overloads) {
				if(overload.callableBy(sender)) {
					sender.sendMessage("- ", cmd.name, " ", formatArg(overload));
				}
			}
		}
	}

	@vanilla help2(JavaPlayer sender, string command) {
		this.helpImpl(sender, "/", command);
	}

	@vanilla help3(ServerCommandSender sender, string command) {
		this.helpImpl(sender, "", command);
	}
	
	private void helpImpl(CommandSender sender, string slash, string command) {
		auto cmd = command in sender.availableCommands;
		if(cmd) {
			if(cmd.aliases.length) {
				sender.sendMessage(Format.yellow, Translation(Messages.help.commandAliases, cmd.name, cmd.aliases.join(", ")));
			} else {
				sender.sendMessage(Format.yellow ~ cmd.name ~ ":");
			}
			if(cmd.description.type == Description.TEXT) {
				sender.sendMessage(Format.yellow, cmd.description.text);
			} else if(cmd.description.type == Description.TRANSLATABLE) {
				sender.sendMessage(Format.yellow, Translation(cmd.description.translatable));
			}
			sender.sendMessage(Translation(Messages.generic.usage, ""));
			foreach(overload ; cmd.overloads) {
				if(overload.callableBy(sender)) {
					sender.sendMessage("- ", slash, cmd.name, " ", formatArg(overload));
				}
			}
		} else {
			sender.sendMessage(Format.red, Messages.generic.notFound);
		}
	}

	@vanilla @op kick0(WorldCommandSender sender, Player[] target, string message) {
		string[] kicked;
		foreach(player ; target) {
			player.kick(message);
			kicked ~= player.displayName;
		}
		sender.sendMessage(Translation(Messages.kick.successReason, kicked.join(", "), message));
	}

	@vanilla kick1(WorldCommandSender sender, Player[] target) {
		string[] kicked;
		foreach(player ; target) {
			player.kick();
			kicked ~= player.name;
		}
		sender.sendMessage(Translation(Messages.kick.success, kicked.join(", ")));
	}

	@vanilla kick2(ServerCommandSender sender, string player, string message) {
		if(executeIfPlayer(sender, player, (uint hubId){ server.kick(hubId, message); })) {
			sender.sendMessage(Translation(Messages.kick.successReason, player, message));
		}
	}

	@vanilla kick3(ServerCommandSender sender, string player) {
		if(executeIfPlayer(sender, player, (uint hubId){ server.kick(hubId, "disconnect.closed", []); })) {
			sender.sendMessage(Translation(Messages.kick.success, player));
		}
	}

	@vanilla list0(CommandSender sender) {
		// list players on the current node
		sender.sendMessage(Translation(Messages.list.players, sender.server.online, sender.server.max));
		if(sender.server.online) {
			string[] names;
			foreach(player ; server.players) {
				names ~= player.displayName;
			}
			sender.sendMessage(names.join(", "));
		}
	}

	@vanilla me0(Player sender, string message) {
		//TODO unformat
		sender.world.broadcast("* " ~ sender.displayName ~ " " ~ message);
	}

	@vanilla @op op0(WorldCommandSender sender, Player player) {
		if(!player.op) {
			player.op = true;
			player.sendMessage(Translation(Messages.op.message));
			sender.sendMessage(Translation(Messages.op.success, player.displayName));
		} else {
			sender.sendMessage(Format.red, Translation(Messages.op.failed, player.displayName));
		}
	}

	@vanilla op1(ServerCommandSender sender, string player) {
		//TODO
	}

	@vanilla @op say0(WorldCommandSender sender, string message) {
		auto player = cast(Player)sender;
		immutable name = player is null ? "@" : player.displayName ~ Format.reset;
		//TODO convert targets into strings
		sender.world.broadcast("[" ~ name ~ "] " ~ message); //TODO unformat
	}

	@vanilla say1(ServerCommandSender sender, string message) {
		//TODO
		//sender.server.broadcast("[@] " ~ message);
	}

	@vanilla @op setmaxplayers0(CommandSender sender, uint players) {
		sender.server.max = players;
		sender.sendMessage(Translation(Messages.setmaxplayers.success, players));
	}

	@vanilla @op seed0(WorldCommandSender sender) {
		sender.sendMessage(Translation(Messages.seed.success, sender.world.seed));
	}
	
	@vanilla @op stop0(CommandSender sender, bool gracefully=true) {
		if(gracefully) {
			if(isServerRunning) {
				sender.sendMessage(Translation(Messages.stop.start));
				this.server.shutdown();
			} else {
				sender.sendMessage(Format.red, Translation(Messages.stop.failed));
			}
		} else {
			import std.c.stdlib : exit;
			exit(0);
		}
	}

	@vanilla @aliases("msg", "w") tell0(Player sender, Player[] recipient, string message) {
		string[] sent;
		foreach(player ; recipient) {
			if(player.id != sender.id) {
				player.sendMessage(Format.italic, Translation(Messages.message.incoming, sender.displayName, message));
				sent ~= player.displayName;
			}
		}
		if(sent.length) sender.sendMessage(Format.italic, Translation(Messages.message.outcoming, sent.join(", "), message));
		else sender.sendMessage(Format.red, Translation(Messages.message.sameTarget));
	}

	@vanilla @op time0(WorldCommandSender sender, SingleEnum!"add" add, uint amount) {
		uint time = sender.world.time.time + amount;
		if(time >= 24000) sender.world.time.day += time / 24000;
		sender.world.time.time = time;
		sender.sendMessage(Translation(Messages.time.added, amount));
	}

	enum TimeQuery { day, daytime, gametime }

	@vanilla @op time1(WorldCommandSender sender, SingleEnum!"query" query, TimeQuery time) {
		final switch(time) with(TimeQuery) {
			case day:
				sender.sendMessage(Translation(Messages.time.queryDay, sender.world.time.day));
				break;
			case daytime:
				sender.sendMessage(Translation(Messages.time.queryDaytime, sender.world.time.time));
				break;
			case gametime:
				sender.sendMessage(Translation(Messages.time.queryGametime, sender.world.ticks));
				break;
		}
	}

	@vanilla @op time2(WorldCommandSender sender, SingleEnum!"set" set, uint amount) {
		sender.sendMessage(Translation(Messages.time.set, (sender.world.time.time = amount)));
	}

	@vanilla @op time3(WorldCommandSender sender, SingleEnum!"set" set, Time amount) {
		this.time2(sender, set, cast(uint)amount);
	}

	@vanilla @op toggledownfall0(WorldCommandSender sender) {
		if(sender.world.weather.raining) sender.world.weather.clear();
		else sender.world.weather.start();
		sender.sendMessage(Translation(Messages.toggledownfall.success));
	}

	@vanilla @op @permission("minecraft:teleport") tp0(Player sender, Entity destination) {
		this.tp2(sender, [sender], destination);
	}

	@vanilla tp1(Player sender, Position destination) {
		this.tp3(sender, [sender], destination);
	}

	@vanilla tp2(WorldCommandSender sender, Entity[] victim, Entity destination) {}

	@vanilla tp3(WorldCommandSender sender, Entity[] victim, Position destination) {}

	@op transfer0(WorldCommandSender sender, Player[] target, string node) {
		//TODO transfer to another node
	}

	@op transfer1(ServerCommandSender sender, string target, string node) {
		//TODO
	}
	
	@vanilla @op transferserver0(Player sender, string ip, int port=19132) {
		immutable _port = cast(ushort)port;
		if(_port == port) {
			try {
				sender.transfer(ip, _port);
			} catch(Exception) {}
		} else {
			sender.sendMessage(Format.red, Translation(Messages.transferserver.invalidPort));
		}
	}

	@vanilla @op transferserver1(WorldCommandSender sender, Player[] target, string ip, int port=19132) {
		immutable _port = cast(ushort)port;
		if(_port == port) {
			bool success = false;
			foreach(player ; target) {
				try {
					player.transfer(ip, _port);
					success = true;
				} catch(Exception) {}
			}
			if(success) sender.sendMessage(Translation(Messages.transferserver.success));
		} else {
			sender.sendMessage(Format.red, Translation(Messages.transferserver.invalidPort));
		}
	}

	enum Weather { clear, rain, thunder }

	@vanilla @op weather0(WorldCommandSender sender, Weather type, int duration=0) {
		if(type == Weather.clear) {
			if(duration <= 0) sender.world.weather.clear();
			else sender.world.weather.clear(duration);
			sender.sendMessage(Translation(Messages.weather.clear));
		} else {
			if(duration <= 0 || duration > 1_000_000) duration = sender.world.random.range(6000, 18000);
			if(type == Weather.rain) {
				sender.world.weather.start(duration, false);
				sender.sendMessage(Translation(Messages.weather.rain));
			} else {
				sender.world.weather.start(duration, true);
				sender.sendMessage(Translation(Messages.weather.thunder));
			}
		}
	}

	// UTILS

}

string convertName(string command, string replacement=" ") {
	string ret;
	foreach(c ; command) {
		if(c >= 'A' && c <= 'Z') ret ~= replacement ~ cast(char)(c + 32);
		else ret ~= c;
	}
	return ret;
}

private enum convertedName(string command) = convertName(command);

private string[] formatArgs(Command command, CommandSender sender) {
	string[] ret;
	foreach(overload ; command.overloads) {
		if(overload.callableBy(sender)) ret ~= formatArg(overload);
	}
	return ret;
}

private string formatArg(Command.Overload overload) {
	string[] p;
	foreach(i, param; overload.params) {
		immutable enum_ = overload.pocketTypeOf(i) == PocketType.stringenum;
		if(enum_ && overload.enumMembers(i).length == 1) {
			p ~= overload.enumMembers(i)[0];
		} else {
			string full = enum_ && overload.enumMembers(i).length < 5 ? overload.enumMembers(i).join("|") : (param ~ ": " ~ overload.typeOf(i));
			if(i < overload.requiredArgs) {
				p ~= "<" ~ full ~ ">";
			} else {
				p ~= "[" ~ full ~ "]";
			}
		}
	}
	return p.join(" ");
}

private bool executeIfPlayer(ServerCommandSender sender, string name, lazy void delegate(uint) del) {
	if(name == "@a") {
		foreach(player ; sender.server.players) {
			del()(player.hubId);
		}
		return true;
	} else {
		immutable iname = name.toLower();
		bool executed = false;
		foreach(player ; sender.server.players) {
			if(player.lname == iname) {
				executed = true;
				del()(player.hubId);
			}
		}
		if(!executed) sender.sendMessage(Format.red, Translation(Messages.generic.playerNotFound, name));
		return executed;
	}
}
