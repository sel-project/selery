/*
 * Copyright (c) 2017-2019 sel-project
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
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/node/commands.d, selery/node/commands.d)
 */
module selery.node.commands;

import std.algorithm : sort, clamp, min, filter;
import std.conv : to;
import std.math : ceil;
import std.random : uniform;
import std.string : join, toLower, startsWith;
import std.traits : hasUDA, getUDAs, Parameters;
import std.typetuple : TypeTuple;

import sel.format : Format, unformat;

import selery.about : Software;
import selery.command.command : Command;
import selery.command.util : CommandSender, WorldCommandSender, PocketType, SingleEnum, SnakeCaseEnum, Ranged, Position, Target;
import selery.config : Config, Gamemode, Difficulty, Dimension;
import selery.effect : Effects;
import selery.enchantment : Enchantments;
import selery.entity.entity : Entity;
import selery.lang : Translation, Translatable;
import selery.node.server : isServerRunning, NodeServer, ServerCommandSender;
import selery.player.bedrock : BedrockPlayer;
import selery.player.java : JavaPlayer;
import selery.player.player : PlayerInfo, Player, PermissionLevel;
import selery.plugin : Description, permission, hidden, unimplemented;
import selery.util.messages : Messages;
import selery.world.group : GroupInfo;
import selery.world.world : WorldInfo, Time;

enum vanilla;
enum op;

struct aliases {

	string[] aliases;

	this(string[] aliases...) {
		this.aliases = aliases;
	}

}

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
				sender.sendMessage("* ", Format.green, plugin.name, Format.reset, " ", (!plugin.version_.startsWith("~") ? "v" : ""), plugin.version_);
			}
		}
	}

	// help
	
	@vanilla help0(ServerCommandSender sender) {
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
	
	@vanilla help1(ServerCommandSender sender, string command) {
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

	// permission

	enum PermissionAction { grant, revoke }

	@unimplemented @op permission0(WorldCommandSender sender, PermissionAction action, Player[] target, string permission) {}

	@unimplemented void permission1(WorldCommandSender sender, SingleEnum!"list" list, Player target) {}

	@unimplemented void permission2(ServerCommandSender sender, PermissionAction action, string target, string permission) {}

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
			import core.stdc.stdlib : exit;
			exit(0);
		}
	}

	// transfer

	@unimplemented @op transfer0(WorldCommandSender sender, Player[] target, string node) {}

	@unimplemented @op transfer1(ServerCommandSender sender, string target, string node) {}

	// world
	
	void world0(CommandSender sender, SingleEnum!"list" list) {
		string[] names;
		foreach(group ; sender.server.worldGroups) names ~= group.name;
		sender.sendMessage(Translation("commands.world.list", names.length, names.join(", ")));
	}

	@op world1(CommandSender sender, SingleEnum!"add" add, string name, bool defaultWorld=false) {
		auto world = sender.server.addWorld(name);
		if(world) {
			sender.sendMessage(Translation("commands.world.add.success"));
			//if(defaultWorld) sender.server.defaultWorld = world;
		} else {
			sender.sendMessage(Format.red, Translation("commands.world.add.failed"));
		}
	}

	void world2(CommandSender sender, SingleEnum!"remove" remove, string name) {
		executeOnWorlds(sender, name, (shared GroupInfo info){
			if(sender.server.removeWorldGroup(info)) sender.sendMessage(Translation("commands.world.remove.success"));
		});
	}

	@unimplemented void world3(CommandSender sender, SingleEnum!"info" info, string name) {}

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

private void executeOnWorlds(CommandSender sender, string name, void delegate(shared GroupInfo) del) {
	auto group = sender.server.getGroupByName(name);
	if(group !is null) {
		del(group);
	} else {
		sender.sendMessage(Format.red, Translation("commands.world.notFound", name));
	}
}

private void executeOnPlayers(CommandSender sender, string name, void delegate(shared PlayerInfo) del) {
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
