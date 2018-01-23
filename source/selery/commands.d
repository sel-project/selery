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
import std.random : uniform;
import std.string : join, toLower, startsWith;
import std.traits : hasUDA, getUDAs, Parameters;
import std.typetuple : TypeTuple;

import selery.about : Software;
import selery.command.command : Command;
import selery.command.util : CommandSender, WorldCommandSender, PocketType, SingleEnum, SnakeCaseEnum, Ranged, Position, Target;
import selery.config : Config, Gamemode, Difficulty, Dimension;
import selery.effect : Effects;
import selery.enchantment : Enchantments;
import selery.entity.entity : Entity;
import selery.format : unformat;
import selery.lang : Translation, Translatable;
import selery.log : Format;
import selery.node.info : PlayerInfo, WorldInfo;
import selery.node.server : isServerRunning, NodeServer, ServerCommandSender;
import selery.player.bedrock : BedrockPlayer;
import selery.player.java : JavaPlayer;
import selery.player.player : Player, InputMode, PermissionLevel;
import selery.plugin : Description, permission, hidden, unimplemented;
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
 * Supported vanilla commands:
 * [ ] clear
 * [ ] clone
 * [ ] defaultgamemode
 * [x] deop
 * [ ] difficulty
 * [ ] effect
 * [ ] enchant
 * [ ] execute
 * [ ] fill
 * [x] gamemode
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
 * [x] say
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
 * 
 * Supported multiplayer commands:
 * [ ] ban
 * [ ] ban-ip
 * [ ] banlist
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
			server.registerCommand!C(mixin("&this." ~ command ~ count.to!string), convertedName!command, Description(description), aliases, hasUDA!(C, op), permissions, hasUDA!(C, hidden), !hasUDA!(C, unimplemented));
		} else {
			server.registerCommand!C(mixin("&this." ~ command ~ count.to!string), convertedName!command, Description.init, [], 0, [], false, !hasUDA!(C, unimplemented));
		}
		static if(__traits(hasMember, typeof(this), command ~ to!string(count + 1))) this.registerImpl!(command, count + 1)(server);
	}

	private void sendUnimplementedMessage(CommandSender sender) {
		sender.sendMessage(Format.red, "Not Implemented");
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

	// about

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

	// clear

	@vanilla @op clear0(Player sender) {
		this.clear1(sender, [sender]);
	}

	@unimplemented @vanilla clear1(WorldCommandSender sender, Player[] target) {}

	@unimplemented @vanilla clear2(WorldCommandSender sender, Player[] target, string itemName) {}

	// clone

	enum MaskMode { masked, replace }

	enum CloneMode { force, move, normal }
	
	@unimplemented @vanilla @op clone0(WorldCommandSender sender, Position begin, Position end, Position destination, MaskMode maskMode=MaskMode.replace, CloneMode cloneMode=CloneMode.normal) {}
	
	@unimplemented @vanilla clone0(WorldCommandSender sender, Position begin, Position end, Position destination, SingleEnum!"filtered" maskMode, CloneMode cloneMode, string tileName) {}

	// defaultgamemode

	@unimplemented @vanilla @op defaultgamemode0(WorldCommandSender sender, Gamemode gamemode) {}

	// deop

	@vanilla @op deop0(WorldCommandSender sender, Player player) {
		if(player.permissionLevel <= PermissionLevel.operator) {
			if(player.operator) {
				player.operator = false;
				player.sendMessage(Translation(Messages.deop.message));
			}
			sender.sendMessage(Translation(Messages.deop.success, player.displayName));
		} else {
			sender.sendMessage(Translation(Messages.deop.failed, player.displayName));
		}
	}

	@vanilla deop1(ServerCommandSender sender, string player) {
		executeOnPlayers(sender, player, (shared PlayerInfo info){
			if(info.permissionLevel <= PermissionLevel.operator) {
				if(info.permissionLevel == PermissionLevel.operator) {
					sender.server.updatePlayerPermissionLevel(info, PermissionLevel.user);
					//TODO send message to the player
				}
				sender.sendMessage(Translation(Messages.deop.success, info.displayName));
			} else {
				sender.sendMessage(Format.red, Translation(Messages.deop.failed, info.displayName));
			}
		});
	}

	// difficulty
	
	@vanilla @op difficulty0(WorldCommandSender sender, Difficulty difficulty) {
		sender.world.difficulty = difficulty;
		sender.sendMessage(Translation(Messages.difficulty.success, difficulty));
	}
	
	@vanilla difficulty1(WorldCommandSender sender, Ranged!(ubyte, 0, 3) difficulty) {
		this.difficulty0(sender, cast(Difficulty)difficulty.value);
	}

	@vanilla difficulty2(ServerCommandSender sender, string world, Difficulty difficulty) {
		executeOnWorlds(sender, world, (shared WorldInfo info){
			sender.server.updateWorldDifficulty(info, difficulty);
			sender.sendMessage(Translation(Messages.difficulty.success, difficulty));
		});

	}

	@vanilla difficulty3(ServerCommandSender sender, string world, Ranged!(ubyte, 0, 3) difficulty) {
		this.difficulty2(sender, world, cast(Difficulty)difficulty.value);
	}

	// effect

	@unimplemented @vanilla @op effect0(WorldCommandSender sender, SingleEnum!"clear" clear, Entity[] target) {}

	@unimplemented @vanilla effect1(WorldCommandSender sender, SingleEnum!"clear" clear, Entity[] target, SnakeCaseEnum!Effects effect) {}

	alias Duration = Ranged!(uint, 0, 1_000_000);

	@unimplemented @vanilla effect2(WorldCommandSender sender, SingleEnum!"give" give, Entity[] target, SnakeCaseEnum!Effects effect, Duration duration=Duration(30), ubyte amplifier=0, bool hideParticles=false) {}

	// enchant

	alias Level = Ranged!(ubyte, 1, ubyte.max);

	@unimplemented @vanilla @op enchant0(WorldCommandSender sender, Player[] target, SnakeCaseEnum!Enchantments enchantment, Level level=Level(1)) {}

	@vanilla enchant1(Player sender, SnakeCaseEnum!Enchantments enchantment, Level level=Level(1)) {
		this.enchant0(sender, [sender], enchantment, level);
	}

	// experience

	enum ExperienceAction { add, set }

	enum ExperienceType { points, levels }

	@unimplemented @vanilla @op @aliases("xp") experience0(WorldCommandSender sender, ExperienceAction action, Player[] target, uint amount, ExperienceType type=ExperienceType.levels) {}

	@vanilla experience1(Player sender, ExperienceAction action, uint amount, ExperienceType type=ExperienceType.levels) {
		this.experience0(sender, action, [sender], amount, type);
	}

	@unimplemented @vanilla experience2(WorldCommandSender sender, SingleEnum!"query" query, Player target, ExperienceType type) {}

	@vanilla experience3(Player sender, SingleEnum!"query" query, ExperienceType type) {
		this.experience2(sender, query, sender, type);
	}

	// execute

	//class ExecuteCommand : WorldCommandSender {}

	@unimplemented @vanilla @op execute0(WorldCommandSender sender, Entity[] origin, Position position, string command) {}

	// fill

	enum OldBlockHandling { destroy, hollow, keep, outline, replace }

	@unimplemented @vanilla @op fill0(WorldCommandSender sender, Position from, Position to, string block, OldBlockHandling oldBlockHandling=OldBlockHandling.replace) {}

	// gamemode

	@vanilla @op @aliases("gm") gamemode0(WorldCommandSender sender, Gamemode gamemode, Player[] target) {
		foreach(player ; target) {
			player.gamemode = gamemode;
			sender.sendMessage(Translation(Messages.gamemode.successOther, gamemode, player.displayName));
		}
	}

	@vanilla gamemode1(Player sender, Gamemode gamemode) {
		sender.gamemode = gamemode;
		sender.sendMessage(Translation(Messages.gamemode.successSelf, gamemode));
	}

	@vanilla gamemode2(ServerCommandSender sender, Gamemode gamemode, string target) {
		executeOnPlayers(sender, target, (shared PlayerInfo info){
			sender.server.updatePlayerGamemode(info, gamemode);
			sender.sendMessage(Translation(Messages.gamemode.successOther, gamemode, info.displayName));
		});
	}

	// gamerule

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
	
	// give
	
	@unimplemented @vanilla @op give0(WorldCommandSender sender, Player[] target, string item, ubyte amount=1) {}
	
	@vanilla give1(Player sender, string item, ubyte amount=1) {
		this.give0(sender, [sender], item, amount);
	}

	// help

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
	
	@vanilla @aliases("?") help1(ServerCommandSender sender) {
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
			string[] messages;
			foreach(overload ; cmd.overloads) {
				if(overload.callableBy(sender)) {
					messages ~= ("- " ~ slash ~ cmd.name ~ " " ~ formatArg(overload));
				}
			}
			if(messages.length) {
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
				foreach(message ; messages) {
					sender.sendMessage(message);
				}
				return;
			}
		}
		sender.sendMessage(Format.red, Translation(Messages.generic.invalidParameter, command));
	}

	// kick

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
		executeOnPlayers(sender, player, (shared PlayerInfo info){
			sender.server.kick(info.hubId, message);
			sender.sendMessage(Translation(Messages.kick.successReason, info.displayName, message));
		});
	}

	@vanilla kick3(ServerCommandSender sender, string player) {
		executeOnPlayers(sender, player, (shared PlayerInfo info){
			server.kick(info.hubId, "disconnect.closed", []);
			sender.sendMessage(Translation(Messages.kick.success, info.displayName));
		});
	}

	// kill

	@unimplemented @vanilla @op kill0(WorldCommandSender sender, Entity[] target) {}

	@vanilla kill1(Player sender) {
		this.kill0(sender, [sender]);
	}

	// list

	@vanilla @op list0(CommandSender sender) {
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

	// locate

	enum StructureType { endcity, fortress, mansion, mineshaft, monument, stronghold, temple, village }

	@unimplemented @vanilla @op locate0(WorldCommandSender sender, StructureType structureType) {}

	// me

	@vanilla me0(Player sender, string message) {
		//TODO replace target selectors with names
		sender.world.broadcast("* " ~ sender.displayName ~ Format.reset ~ " " ~ unformat(message));
	}

	// op

	@vanilla @op op0(WorldCommandSender sender, Player player) {
		if(!player.operator) {
			player.operator = true;
			player.sendMessage(Translation(Messages.op.message));
			sender.sendMessage(Translation(Messages.op.success, player.displayName));
		} else {
			sender.sendMessage(Format.red, Translation(Messages.op.failed, player.displayName));
		}
	}

	@vanilla op1(ServerCommandSender sender, string player) {
		executeOnPlayers(sender, player, (shared PlayerInfo info){
			if(info.permissionLevel < PermissionLevel.operator) {
				sender.server.updatePlayerPermissionLevel(info, PermissionLevel.operator);
				//TODO send message to the player
				sender.sendMessage(Translation(Messages.op.success, info.displayName));
			} else {
				sender.sendMessage(Format.red, Translation(Messages.op.failed, info.displayName));
			}
		});
	}

	// permission

	enum PermissionAction { grant, revoke }

	@unimplemented @op permission0(WorldCommandSender sender, PermissionAction action, Player[] target, string permission) {}

	@unimplemented void permission1(ServerCommandSender sender, PermissionAction action, string target, string permission) {}

	// say

	@vanilla @op say0(WorldCommandSender sender, string message) {
		auto player = cast(Player)sender;
		immutable name = player is null ? "@" : player.displayName ~ Format.reset;
		//TODO convert targets into strings
		sender.world.broadcast("[" ~ name ~ "] " ~ message); //TODO unformat
	}

	@vanilla say1(ServerCommandSender sender, string message) {
		sender.server.broadcast("[@] " ~ message);
	}

	// seed

	@vanilla @op seed0(WorldCommandSender sender) {
		sender.sendMessage(Translation(Messages.seed.success, sender.world.seed));
	}
	
	// setmaxplayers
	
	@vanilla @op setmaxplayers0(CommandSender sender, uint players) {
		sender.server.max = players;
		sender.sendMessage(Translation(Messages.setmaxplayers.success, players));
	}

	// setworldspawn

	@unimplemented @vanilla @op setworldspawn0(WorldCommandSender sender, Position position) {}

	@vanilla setworldspawn1(WorldCommandSender sender) {
		this.setworldspawn0(sender, Position(Position.Point(true, sender.position.x), Position.Point(true, sender.position.y), Position.Point(true, sender.position.z)));
	}

	// spawnpoint

	@unimplemented @vanilla @op spawnpoint0(WorldCommandSender sender, Player[] target, Position position) {}

	@vanilla spawnpoint1(WorldCommandSender sender, Player[] target) {
		this.spawnpoint0(sender, target, Position(Position.Point(true, sender.position.x), Position.Point(true, sender.position.y), Position.Point(true, sender.position.z)));
	}

	@vanilla spawnpoint2(Player sender) {
		this.spawnpoint1(sender, [sender]);
	}

	// spreadplayers

	//TODO implement Rotation
	//@unimplemented @vanilla @op spreadplayers0(WorldCommandSender sender, Rotation x, Rotation z, double spreadDistance, double maxRange, Entity[] target) {}

	// stop
	
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

	// summon

	@unimplemented @vanilla @op summon0(WorldCommandSender sender, string entityType, Position position) {}

	@unimplemented @vanilla summon1(WorldCommandSender sender, string entityType) {}

	// tell

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

	// time

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

	// title

	@vanilla @op title0(WorldCommandSender sender, Player[] target, SingleEnum!"clear" clear) {
		foreach(player ; target) player.clearTitle();
		//TODO send message
	}

	@vanilla title1(WorldCommandSender sender, Player[] target, SingleEnum!"reset" reset) {
		foreach(player ; target) player.resetTitle();
		//TODO send message
	}

	@unimplemented @vanilla title2(WorldCommandSender sender, Player[] target, SingleEnum!"title" title, string text) {}

	@unimplemented @vanilla title3(WorldCommandSender sender, Player[] target, SingleEnum!"subtitle" subtitle, string text) {}

	@unimplemented @vanilla title4(WorldCommandSender sender, Player[] target, SingleEnum!"actionbar" actionbar, string text) {
		foreach(player ; target) player.sendTip(text);
		//TODO send message
	}

	@unimplemented @vanilla title5(WorldCommandSender sender, Player[] target, SingleEnum!"times" times, uint fadeIn, uint stay, uint fadeOut) {}

	// toggledownfall

	@vanilla @op toggledownfall0(WorldCommandSender sender) {
		if(sender.world.weather.raining) sender.world.weather.clear();
		else sender.world.weather.start();
		sender.sendMessage(Translation(Messages.toggledownfall.success));
	}

	// tp

	@vanilla @op @permission("minecraft:teleport") @aliases("teleport") tp0(Player sender, Entity destination) {
		this.tp2(sender, [sender], destination);
	}

	@vanilla tp1(Player sender, Position destination) {
		this.tp3(sender, [sender], destination);
	}

	@unimplemented @vanilla tp2(WorldCommandSender sender, Entity[] victim, Entity destination) {}

	@unimplemented @vanilla tp3(WorldCommandSender sender, Entity[] victim, Position destination) {}

	// transfer

	@unimplemented @op transfer0(WorldCommandSender sender, Player[] target, string node) {}

	@unimplemented @op transfer1(ServerCommandSender sender, string target, string node) {}

	// transferserver
	
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

	// weather

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

private void executeOnWorlds(ServerCommandSender sender, string name, void delegate(shared WorldInfo) del) {
	foreach(world ; sender.server.worlds) {
		if(world.name == name) del(world);
	}
}

private void executeOnPlayers(ServerCommandSender sender, string name, void delegate(shared PlayerInfo) del) {
	if(name.startsWith("@")) {
		if(name == "@a" || name == "@r") {
			auto players = sender.server.players;
			if(players.length) {
				final switch(name) {
					case "@a":
						foreach(player ; sender.server.players) {
							del(player);
						}
						break;
					case "@r":
						del(players[uniform(0, $)]);
						break;
				}
			} else {
				sender.sendMessage(Format.red, Translation(Messages.generic.targetNotFound));
			}
		} else {
			sender.sendMessage(Format.red, Translation(Messages.generic.invalidSyntax));
		}
	} else {
		immutable iname = name.toLower();
		bool executed = false;
		foreach(player ; sender.server.players) {
			if(player.lname == iname) {
				executed = true;
				del(player);
			}
		}
		if(!executed) sender.sendMessage(Format.red, Translation(Messages.generic.playerNotFound, name));
	}
}
