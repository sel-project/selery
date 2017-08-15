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
module selery.commands;

import std.algorithm : sort, clamp, min, filter;
import std.conv : to;
import std.math : ceil;
import std.string : join, toLower, startsWith;
import std.traits : hasUDA, getUDAs;
import std.typetuple : TypeTuple;

import selery.about : Software;
import selery.config : Config;
import selery.command.command : Command;
import selery.command.util : CommandSender, WorldCommandSender, PocketType, SingleEnum, SnakeCaseEnum, Ranged, Position, Target;
import selery.format : Text;
import selery.lang : Translation, Message;
import selery.node.server : isServerRunning, NodeServer, ServerCommandSender;
import selery.player.player : Player, InputMode;
import selery.util.messages : Messages;
import selery.world.rules : Difficulty, Gamemode;

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
 * [x] reload
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
			static if(hasUDA!(C, vanilla)) enum description = Translation.fromPocket("commands." ~ command ~ ".description");
			else enum description = Translation("commands." ~ command ~ ".description");
			static if(hasUDA!(C, aliases)) enum aliases = getUDAs!(C, aliases)[0].aliases;
			else enum string[] aliases = [];
			server.registerCommand!C(mixin("&this." ~ command ~ to!string(count)), convertedName!command, Message(description), aliases, hasUDA!(C, op), false);
		} else {
			server.registerCommand!C(mixin("&this." ~ command ~ to!string(count)), convertedName!command, Message.init, [], false, false);
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
		sender.sendMessage(Messages.about.software, Software.name ~ " " ~ Software.fullVersion);
		if(this.server.plugins.length) {
			sender.sendMessage(Messages.about.plugins, this.server.plugins.length);
			foreach(_plugin ; this.server.plugins) {
				auto plugin = cast()_plugin;
				sender.sendMessage("* ", Text.green, plugin.name, Text.reset, " ", (!plugin.vers.startsWith("~") ? "v" : ""), plugin.vers);
			}
		}
	}

	@vanilla @op deop0(WorldCommandSender sender, Player player) {
		if(player.op) {
			player.op = false;
			player.sendMessage(Messages.deop.message);
			sender.sendMessage(Messages.deop.success, player.displayName);
		} else {
			sender.sendMessage(Messages.deop.failed, player.displayName);
		}
	}

	@vanilla deop1(ServerCommandSender sender, string player) {
		//TODO
	}
	
	@vanilla @op difficulty0(WorldCommandSender sender, Difficulty difficulty) {
		//TODO unsupported by selery
		//sender.world.difficulty = difficulty;
		sender.sendMessage(Messages.difficulty.success);
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
			sender.sendMessage(Messages.gamemode.successOther, gamemode.to!string, player.displayName);
		}
	}
	
	@vanilla gamemode2(WorldCommandSender sender, Ranged!(ubyte, 0, 3) gamemode, Player[] target) {
		this.gamemode0(sender, cast(Gamemode)gamemode.value, target);
	}

	@vanilla gamemode1(Player sender, Gamemode gamemode) {
		sender.gamemode = gamemode;
		sender.sendMessage(Messages.gamemode.successSelf, gamemode.to!string);
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

	enum Gamerule { doDayLightCycle, doWeatherCycle, pvp, randomTickSpeed }

	@vanilla @op gamerule0(WorldCommandSender sender) {
		sender.sendMessage(join([__traits(allMembers, Gamerule)], ", "));
	}

	@vanilla gamerule1(WorldCommandSender sender, Gamerule rule) {
		//TODO
		sender.sendMessage(rule, " = ", {
				final switch(rule) with(Gamerule) {
					case doDayLightCycle: return "true";
					case doWeatherCycle: return "true";
					case pvp: return "true";
					case randomTickSpeed: return "3";
				}
			}());
	}

	@vanilla gamerule2(WorldCommandSender sender, Gamerule rule, bool value) {
		//TODO
		switch(rule) with(Gamerule) {
			case doDayLightCycle: break;
			case doWeatherCycle: break;
			case pvp: break;
			default:
				sender.sendMessage(Text.red, Messages.gamerule.invalidType, rule);
				return;
		}
		sender.sendMessage(Messages.gamerule.success, rule, value);
	}

	@vanilla gamerule3(WorldCommandSender sender, Gamerule rule, Ranged!(int, 0, int.max) value) {
		//TODO
		switch(rule) with(Gamerule) {
			case randomTickSpeed: break;
			default:
				sender.sendMessage(Text.red, Messages.gamerule.invalidType, rule);
				return;
		}
		sender.sendMessage(Messages.gamerule.success, rule, value.value);
	}
	
	@vanilla help0(WorldCommandSender sender, int page) {
		auto player = cast(Player)sender;
		if(player) {
			//TODO display overloads instead of commands
			Command[] commands;
			size_t overloads;
			foreach(command ; player.commandMap) {
				if(!command.hidden && (!command.op || player.op)) commands ~= command;
			}
			sort!((a, b) => a.command < b.command)(commands);
			immutable pages = cast(size_t)ceil(commands.length.to!float / 7); // commands.length should always be at least 1 (help command)
			page = clamp(--page, 0, pages - 1);
			sender.sendMessage(Text.darkGreen, Messages.help.header, page+1, pages);
			string[] messages;
			foreach(command ; commands[page*7..min($, (page+1)*7)]) {
				messages ~= (command.command ~ " " ~ formatArgs(command)[0]);
			}
			sender.sendMessage(messages.join("\n"));
			if(player.inputMode == InputMode.keyboard) {
				sender.sendMessage(Text.green, Messages.help.footer);
			}
		} else {
			sender.sendMessage(Messages.help.invalidSender);
		}
	}
	
	@vanilla help1(Player sender, string command) { // use Command as arg when available
		auto cmd = sender.commandByName(command);
		if(cmd !is null) {
			if(cmd.aliases.length) {
				sender.sendMessage(Text.yellow, Messages.help.commandAliases, cmd.command, cmd.aliases.join(", "));
			} else {
				sender.sendMessage(Text.yellow ~ cmd.command ~ ":");
			}
			if(cmd.description.isTranslation) {
				sender.sendMessage(Text.yellow, cmd.description.translation);
			} else {
				sender.sendMessage(Text.yellow, cmd.description.message);
			}
			auto params = formatArgs(cmd);
			foreach(ref param ; params) {
				param = "- /" ~ command ~ " " ~ param;
			}
			sender.sendMessage(Messages.generic.usage, "");
			sender.sendMessage(params.join("\n"));
		} else {
			sender.sendMessage(Text.red, Messages.generic.notFound);
		}
	}
	
	@vanilla help2(ServerCommandSender sender) {
		Command[] commands;
		foreach(command ; sender.registeredCommands) {
			if(!command.hidden) {
				foreach(overload ; command.overloads) {
					if(overload.callableBy(sender)) {
						commands ~= command;
						break;
					}
				}
			}
		}
		sort!((a, b) => a.command < b.command)(commands);
		foreach(cmd ; commands) {
			if(cmd.description.isTranslation) {
				sender.sendMessage(Text.yellow, cmd.description.translation);
			} else {
				sender.sendMessage(Text.yellow, cmd.description.message);
			}
			foreach(overload ; cmd.overloads) {
				if(overload.callableBy(sender)) {
					sender.sendMessage("- ", cmd.command, " ", formatArg(overload));
				}
			}
		}
	}

	@vanilla @op kick0(WorldCommandSender sender, Player[] target, string message) {
		string[] kicked;
		foreach(player ; target) {
			player.kick(message);
			kicked ~= player.displayName;
		}
		sender.sendMessage(Messages.kick.successReason, kicked.join(", "), message);
	}

	@vanilla kick1(WorldCommandSender sender, Player[] target) {
		string[] kicked;
		foreach(player ; target) {
			player.kick();
			kicked ~= player.name;
		}
		sender.sendMessage(Messages.kick.success, kicked.join(", "));
	}

	@vanilla kick2(ServerCommandSender sender, string player, string message) {
		if(executeIfPlayer(sender, player, (uint hubId){ server.kick(hubId, message); })) {
			sender.sendMessage(Messages.kick.successReason, player, message);
		}
	}

	@vanilla kick3(ServerCommandSender sender, string player) {
		if(executeIfPlayer(sender, player, (uint hubId){ server.kick(hubId, "disconnect.closed", []); })) {
			sender.sendMessage(Messages.kick.success, player);
		}
	}

	@vanilla list0(CommandSender sender) {
		// list players on the current node
		sender.sendMessage(Messages.list.players, sender.server.online, sender.server.max);
		if(sender.server.online) {
			string[] names;
			foreach(player ; server.players) {
				names ~= player.displayName;
			}
			sender.sendMessage(names.join(", "));
		}
	}

	@vanilla me0(Player sender, string message) {
		sender.world.broadcast("* " ~ sender.displayName ~ " " ~ message);
	}

	@vanilla @op op0(WorldCommandSender sender, Player player) {
		if(!player.op) {
			player.op = true;
			player.sendMessage(Messages.op.message);
			sender.sendMessage(Messages.op.success, player.displayName);
		} else {
			sender.sendMessage(Text.red, Messages.op.failed, player.displayName);
		}
	}

	@vanilla op1(ServerCommandSender sender, string player) {
		//TODO
	}
	
	@op reload0(CommandSender sender) {
		//TODO reload settings (max-players default world settings and commands)
		foreach(plugin ; this.server.plugins) {
			if(plugin.onreload.length) {
				foreach(reload ; plugin.onreload) reload();
			}
		}
		sender.sendMessage(Messages.reload.success);
	}

	@vanilla @op say0(WorldCommandSender sender, string message) {
		auto player = cast(Player)sender;
		immutable name = player is null ? "@" : player.displayName ~ Text.reset;
		//TODO convert targets into strings
		sender.world.broadcast("[" ~ name ~ "] " ~ message);
	}

	@vanilla say1(ServerCommandSender sender, string message) {
		//TODO
		//sender.server.broadcast("[@] " ~ message);
	}

	@vanilla @op setmaxplayers0(CommandSender sender, uint players) {
		sender.server.max = players;
		sender.sendMessage(Messages.setmaxplayers.success, players);
	}

	@vanilla @op seed0(WorldCommandSender sender) {
		sender.sendMessage(Messages.seed.success, sender.world.seed);
	}
	
	@vanilla @op stop0(CommandSender sender, bool gracefully=true) {
		if(gracefully) {
			if(isServerRunning) {
				sender.sendMessage(Messages.stop.start);
				this.server.shutdown();
			} else {
				sender.sendMessage(Text.red, Messages.stop.failed);
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
				player.sendMessage(Text.italic, Messages.message.incoming, sender.displayName, message);
				sent ~= player.displayName;
			}
		}
		if(sent.length) sender.sendMessage(Text.italic, Messages.message.outcoming, sent.join(", "), message);
		else sender.sendMessage(Text.red, Messages.message.sameTarget);
	}

	@vanilla @op toggledownfall0(WorldCommandSender sender) {
		sender.world.downfall = !sender.world.downfall;
		sender.sendMessage(Messages.toggledownfall.success);
	}

	@op transfer0(WorldCommandSender sender, Player[] target, string node) {
		//TODO
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
			sender.sendMessage(Text.red, Messages.transferserver.invalidPort);
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
			if(success) sender.sendMessage(Messages.transferserver.success);
		} else {
			sender.sendMessage(Text.red, Messages.transferserver.invalidPort);
		}
	}

	enum Weather { clear, rain, thunder }

	@vanilla @op weather0(WorldCommandSender sender, Weather type, int duration=0) {
		if(type == Weather.clear) {
			sender.world.downfall = false;
			sender.sendMessage(Messages.weather.clear);
		} else {
			if(duration <= 0 || duration > 1000000) duration = sender.world.random.range(6000, 18000);
			//TODO support rain/thunder and times
			sender.world.downfall = true;
			sender.sendMessage(type == Weather.rain ? Messages.weather.rain : Messages.weather.thunder);
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

private string[] formatArgs(Command command) {
	string[] ret;
	foreach(overload ; command.overloads) {
		ret ~= formatArg(overload);
	}
	return ret;
}

private string formatArg(Command.Overload overload) {
	string[] p;
	foreach(i, param; overload.params) {
		if(overload.pocketTypeOf(i) == PocketType.stringenum && overload.enumMembers(i).length == 1) {
			p ~= overload.enumMembers(i)[0];
		} else {
			string full = param ~ ": " ~ overload.typeOf(i);
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
		if(!executed) sender.sendMessage(Text.red, Messages.generic.playerNotFound, name);
		return executed;
	}
}
