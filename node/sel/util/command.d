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
module sel.util.command;

import std.conv : ConvException, to;
import std.json : parseJSON;
import std.string : join, split, replace, toLower;
import std.traits : Parameters, ParameterDefaults, ParameterIdentifierTuple, staticIndexOf, Reverse;
import std.typecons : Tuple;

import sel.server : server;
import sel.entity.effect : Effect;
import sel.event.world : EntityDamageByCommandEvent;
import sel.item : Item, Slot;
import sel.math.vector;
import sel.player : Player, Gamemode;
import sel.plugin.plugin : arguments;
import sel.util.lang : translate;
import sel.util.log;
import sel.world.world : World;

bool areValidCommandArgs(E...)() {
	static if(E.length == 1 && (is(E[0] == arguments) || is(E[0] == string[]))) return true;
	foreach(T ; E) {
		static if(!is(T == string) && !is(T == long) && !is(T == ulong) && !is(T == bool) && !is(T == BlockPosition) && !is(T == EntityPosition)) return false;
	}
	return true;
}

class Command {
	
	private class Cmd {

		/**
		 * Name of the parameters (name of the variables if not specified
		 * by the user).
		 */
		string[] params;

		abstract @property size_t requiredArgs();

		abstract string typeOf(size_t i);

		abstract string pocketTypeOf(size_t i);

		string[] enumMembers(size_t i) {
			return new string[0];
		}
		
		abstract bool callArgs(Player sender, arguments args);
		
	}
	
	private class CmdOf(E...) : Cmd {

		private alias Args = E[0..$/2];
		private alias Params = E[$/2..$];

		mixin("private enum size_t minArgs = " ~ to!string(staticIndexOf!(void, Params) != -1 ? (Params.length - staticIndexOf!(void, Reverse!Params)) : 0) ~ ";");

		public void delegate(Player, Args) del;
		
		public this(void delegate(Player, Args) del, string[] params) {
			this.del = del;
			this.params = params;
		}

		public override @property size_t requiredArgs() {
			return minArgs;
		}

		public override string typeOf(size_t i) {
			foreach(immutable j, T; Args) {
				if(i == j) {
					static if(is(T == Player)) return "player";
					else static if(is(T == BlockPosition) || is(T == EntityPosition)) return "position";
					else static if(is(T == arguments) || is(T == string[])) return "args";
					else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) return "int";
					else static if(is(T == float) || is(T == double) || is(T == real)) return "float";
					else return T.stringof.toLower;
				}
			}
			return "unknown";
		}

		public override string pocketTypeOf(size_t i) {
			foreach(immutable j, T; Args) {
				if(i == j) {
					static if(is(T == enum)) return "stringenum";
					else static if(is(T == Player)) return "target";
					else static if(is(T == string)) return j == Args.length - 1 ? "rawtext" : "string";
					else static if(is(T == bool)) return "bool";
					else static if(is(T == BlockPosition) || is(T == EntityPosition)) return "blockpos";
					else static if(is(T == float) || is(T == double) || is(T == real)) return "float";
					else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) return "int";
					else return "rawtext";
				}
			}
			return "rawtext";
		}

		public override string[] enumMembers(size_t i) {
			foreach(immutable j, T; E) {
				if(i == j) {
					static if(is(T == enum)) return [__traits(allMembers, T)];
					else break;
				}
			}
			return new string[0];
		}
		
		public override bool callArgs(Player sender, arguments args) {
			static if(Args.length == 1 && is(Args[0] == arguments))  {
				this.del(sender, args);
			} else static if(Args.length == 1 && is(Args[0] == string[])) {
				this.del(sender, args.dup);
			} else {
				Args cargs;
				size_t j = 0;
				foreach(immutable i, T; Args) {
					if(j < args.length) {
						static if(is(T == enum)) {
							bool found = false;
							foreach(immutable member ; __traits(allMembers, T)) {
								if(!found && member == args[j]) {
									mixin("cargs[i] = T." ~ member ~ ";");
									found = true;
									break;
								}
							}
							if(!found) return false;
						} else static if(is(T == Player)) {
							// first player with the given name
							auto list = server.playersWithName(args[j]);
							if(list.length) cargs[i] = list[0];
						} else {
							try {
								static if(is(T == BlockPosition) || is(T == EntityPosition)) {
									if(j + 3 > args.length) return false;
									cargs[i] = T(to!(T.Type)(args[j++]), to!(T.Type)(args[j++]), to!(T.Type)(args[j]));
								} else {
									cargs[i] = to!T(args[j]);
								}
							} catch(ConvException) {
								return false;
							}
						}
					} else {
						static if(!is(Params[i] == void)) cargs[i] = Params[i];
						else return false;
					}
					j++;
				}
				this.del(sender, cargs);
			}
			return true;
		}
		
	}

	private static size_t count = 0;

	immutable size_t id;
	
	immutable string command;
	immutable string description;
	immutable string[] aliases;

	immutable bool op;
	
	Cmd[] overloads;
	
	this(string command, string description="", string[] aliases=[], bool op=false) {
		this.id = count++;
		this.command = command.toLower;
		this.description = description;
		this.aliases = aliases.idup;
		this.op = op;
	}

	void add(alias func)(void delegate(Parameters!func) del, string[] params) if(Parameters!func.length >= 1 && is(Parameters!func[0] == Player)) {
		while(params.length < Parameters!func.length - 1) params ~= [ParameterIdentifierTuple!func][params.length + 1];
		this.overloads ~= new CmdOf!(Parameters!func[1..$], ParameterDefaults!func[1..$])(del, params);
	}
	
	/**
	 * Returns: true if the command has been executed, false otherwise
	 */
	bool call(E...)(Player sender, E args) {
		foreach(cmd ; this.overloads) {
			auto c = cast(CmdOf!E)cmd;
			if(c) {
				c.del(sender, args);
				return true;
			}
		}
		return false;
	}
	
	/// ditto
	bool callArgs(Player sender, arguments args) {
		foreach(cmd ; this.overloads) {
			if(cmd.callArgs(sender, args)) return true;
		}
		return false;
	}
	
}

/**
 * Collection of useful and vanilla-like commands that can
 * be used by the console and the players.
 */
final class Commands {
	
	alias Message = Tuple!(string, "message", string[], "args");

	/**
	 * Sends a command as the console.
	 * Example:
	 * ---
	 * // this will print "Hello from the console!" in every world
	 * Commands.console(&Commands.say, ["Hello", "from", "the", "console!"].idup);
	 * 
	 * // this will kick every player from the server
	 * Commands.console(&Commands.kickall);
	 * ---
	 */
	public static void console(Message function(arguments args) command, arguments args=[]) {
		Message mx = command(args);
		if(mx.message != "") {
			log(mx.message.translate(server.settings.language, mx.args));
		}
	}

	/**
	 * Sends a commands as a player (passed as the first argument).
	 * Example:
	 * ---
	 * // this will send a message to the player with the info about world's entities
	 * if(server.playersWithName("steve").length) {
	 *    Commands.player(server.playersWithName("steve")[0], &Commands.entities);
	 * }
	 * ---
	 */
	public static void player(Player player, Message function(arguments args) command, arguments args=[]) {
		Message mx = command(args);
		if(mx.message != "") {
			player.sendMessage(mx.message, mx.args);
		}
	}

	public static Message effect(arguments args) {
		if(args.length < 2) return Message("{red}{commands.effect.usage}", []);
		auto players = server.playersWithName(args[0]);
		if(!players.length) return Message("{red}{commands.notonline}", []);
		ubyte effect = to!ubyte(args[1]); //TODO handle error and convert string (e.g. "speed" to 1)
		uint duration = args.length > 2 ? to!uint(args[2]) : 60;
		ubyte level = args.length > 3 ? to!ubyte(args[3]) : 0;
		foreach(player ; players) player.addEffect(new Effect(effect, duration, level));
		return Message("{green}{commands.effect.success}", []);
	}

	/**
	 * Bans a player from the server.
	 * Params:
	 * 		player: the name of the player to be banned
	 * Example:
	 * ---
	 * if("steve".online) {
	 *    Commands.ban(["steve"]);
	 *    assert(!"steve".online);
	 * }
	 * ---
	 */
	/*public static @safe Message ban(arguments args) {
		if(args.length != 1) return Message("{red}{commands.ban.usage}", []);
		return Message(server.ban(args[0].replace("-", " ")) ? "{green}{commands.ban.banned}" : "{red}{commands.ban.already_banned}", args.dup);
	}*/

	/**
	 * Changes the gamemode of a player.
	 * Params:
	 * 		player: the name of the player to change the gamemode
	 * 		gamemode: the new gamemode for the player
	 */
	public static Message gamemode(arguments args) {
		if(args.length != 2) return Message("{red}{commands.gamemode.usage}", []);
		auto players = server.playersWithName(args[0]);
		if(!players.length) return Message("{red}{commands.notonline}", []);
		string gm = args[1].toLower;
		ubyte gamemode;
		switch(args[1].toLower) {
			case "survival":
			case "0":
				gamemode = Gamemode.survival;
				break;
			case "creative":
			case "1":
				gamemode = Gamemode.creative;
				break;
			case "adventure":
			case "2":
				gamemode = Gamemode.adventure;
				break;
			case "spectator":
			case "3":
				gamemode = Gamemode.spectator;
				break;
			default:
				return Message("{red}{commands.gamemode.usage}", []);
		}
		foreach(player ; players) player.gamemode = gamemode;
		return Message("{green}{commands.gamemode.success}", []);
	}

	/**
	 * Gives an item to a player.
	 * Params:
	 * 		player: the name of the player, must be online
	 * 		item: the name of the item to be given to the player in the format "name" or "name:damage"
	 * 		count: count of the item
	 * 		data: extra data as json
	 * Example:
	 * ---
	 * // gives 64x beetroots
	 * Commands.give(["steve", "beetroot"].idup);
	 * 
	 * // gives 12x apples
	 * Commands.give(["steve", "apple", "12"].idup);
	 * 
	 * // gives a stack of random coloured wool
	 * Commands.give(["steve", "wool:" ~ to!string(uniform(0, 16) & 15)].idup);
	 * 
	 * // gives a consumed sword
	 * Commands.give(["steve", "diamondSword:1500"].idup);
	 * ---
	 */
	public static Message give(arguments args) {
		if(args.length < 2) return Message("{red}{commands.give.usage}", []);
		auto players = server.playersWithName(args[0]);
		if(!players.length) return Message("{red}{commands.notonline}", []);
		string itemstr;
		ushort itemmeta;
		ubyte count = 0;
		if(args[1].split(":").length == 1) {
			itemstr = args[1];
			itemmeta = 0;
		} else {
			itemstr = args[1].split(":")[0];
			try {
				itemmeta = args[1].split(":")[1].to!ushort;
			} catch(ConvException e) {
				return Message("{red}{commands.give.metaerr}", [args[1].split(":")[1]]);
			}
		}
		if(args.length > 2) {
			try {
				count = args[2].to!ubyte;
			} catch(ConvException e) {
				return Message("{red}{commands.give.counterr}", [args[2]]);
			}
		}
		Slot given;
		foreach(player ; players) {
			Item item = player.world.items.get(itemstr, itemmeta);
			if(item is null) return Message("{red}{commands.give.noitem}", [itemstr]);
			if(args.length > 3) {
				try {
					item.elaborateJSON(parseJSON(args[3..$].join(" ")));
				} catch(Throwable t) {}
			}
			given = count == 0 ? Slot(item) : Slot(item, count);
			player.inventory += given;
		}
		return Message("{green}{commands.give.given}", [given.toString()]);
	}

	/**
	 * Kicks a player from the server.
	 * Params:
	 * 		player = name of the player to be kicked
	 * 		reason = reason of the disconnection
	 */
	public static Message kick(arguments args) {
		if(args.length < 1) return Message("{red}{commands.kick.usage}", []);
		auto players = server.playersWithName(args[0]);
		if(!players.length) return Message("{red}{commands.notonline}", []);
		if(args.length == 1) {
			foreach(player ; players) player.kick();
		} else {
			foreach(player ; players) player.kick(args[1..$].join(" "));
		}
		return Message("{green}{commands.kick.success}", []);
	}

	/**
	 * Kills a player with reason Damage.UNKNOWN.
	 * The damage can be cancelled by EntityDamageEvent.
	 * Params:
	 * 		player: the name of the player, must be online
	 * Example:
	 * ---
	 * @event damage(EntityDamageEvent event) {
	 *    if(event.cause == Damage.UNKNOWN) {
	 *       // probably a kill command
	 *       event.cancel();
	 *    }
	 * }
	 * ---
	 */
	public static Message kill(arguments args) {
		if(args.length < 1) return Message("{red}{commands.kill.usage}", []);
		auto players = server.playersWithName(args[0]);
		if(!players.length) return Message("{red}{commands.notonline}", []);
		foreach(player ; players) player.attack(new EntityDamageByCommandEvent(player));
		return Message("{green}{commands.kill.killed}", []);
	}

	/**
	 * Broadcasts a message to every world.
	 * N.B. that the worlds can override the broadcast function and block this message
	 * Params:
	 * 		message: the string to be broadcasted
	 * Example:
	 * ---
	 * // print "Hello from console!"
	 * Commands.say(["Hello", "from", "console!"].idup);
	 * 
	 * // send translations for {commands.help}
	 * Commands.say(["{commands.help}"].idup);
	 * 
	 * class Example : World {
	 * 
	 *    public override void broadcast(string message, string[] params) {
	 *       // block every world's message
	 * 	  }
	 * 
	 * }
	 * ---
	 */
	public static Message say(arguments args) {
		if(args.length > 0) {
			server.broadcast("{lightpurple}server: " ~ args.join(" "));
		}
		return Message.init;
	}

	/**
	 * Summons an entity in a world.
	 * Params:
	 * 		entity = the name of the entity to be summoned
	 * 		world = the name of the world where the entity will be spawned
	 * 		position = position of the entity
	 * 		motion = motion on the entity
	 * Example:
	 * ---
	 * // spawn a cow at the spawn point
	 * Commands.summon("cow world");
	 * 
	 * // spawn an arrow at 0 64 0 going up
	 * Commands.summon("arrow world 0 64 0 0 10 0");
	 * ---
	 */
	/*public static Message summon(arguments args) {
		if(args.length != 2 && args.length != 5 && args.length != 8) return Message("{red}{commands.summon.usage}", []);
		if(!server.has(args[1])) return Message("{red}{commands.noworld}", []);
		try {
			World world = server[args[1]];
			EntityPosition position = args.length == 5 ? new EntityPosition(to!float(args[2]), to!float(args[3]), to!float(args[4])) : world.spawnPoint;
			Entity entity = world.entities.get(args[0], world, position);
			if(args.length == 8) {
				entity.motion = new EntityPosition(to!float(args[5]), to!float(args[6]), to!float(args[7]));
			}
			world.spawn(entity);
			return Message("{green}{commands.summon.success}");
		} catch(ConvException e) {
			return Message("{red}{commands.summon.usage}");
		}
	}*/

	/**
	 * Toggles downfall.
	 */
	public static Message toggledownfall(arguments args) {
		if(args.length < 1) return Message("{red}{commands.toggledownfall.usage}", []);
		auto worlds = server.worldsWithNameIns(args[0]);
		if(!worlds.length) return Message("{red}{commands.noworld}", []);
		foreach(world ; worlds) world.downfall = !world.downfall;
		return Message("{green}{commands.toggledownfall.success}", []);
	}

	/**
	 * Completion for commands, used when a PC player uses the tab button
	 * whilst writing a command.
	 * Params:
	 * 		sender = Player instance of the player who's requesting the completions
	 * 		args = Previous arguments (e.g. in /give: ["Steve", "diamondSword"])
	 */
	//TODO this class causes a segmentation error using LDC on Linux
	/++public final class Complete {

		@disable this();

		/** Gets the list of players as a string in the whole server. */
		public static string[] serverPlayers() {
			string[] ret;
			foreach(string name ; server.playersNames) {
				ret ~= name.replace(" ", "-");
			}
			return ret;
		}

		/** Gets the list of players as a string in a player's world. */
		public static string[] worldPlayers(Player sender) {
			string[] ret;
			foreach(Player player ; sender.world.online!Player) {
				ret ~= player.name.replace(" ", "-");
			}
			return ret;
		}

		/**
		 * Arguments for the ban command.
		 * Returns: the list of the online player (in the whole server)
		 */
		public static const(string[] delegate(Player, string[])[]) ban = [
			(Player sender, string[] commands) {
				return serverPlayers();
			}
		];

		/**
		 * Arguments for the gamemode command.
		 * Returns: a a list of world's players and a list of available gamemodes
		 */
		public static const(string[] delegate(Player, string[])[]) gamemode = [
			(Player sender, string[] commands) {
				return serverPlayers();
			},
			(Player sender, string[] commands) {
				return ["survival", "creative", "adventure", "spectator"];
			}
		];

		/**
		 * Arguments for the kill command.
		 * Returns: a list of the player in the sender'w world.
		 */
		public static const(string[] delegate(Player, string[])[]) kill = [
			(Player sender, string[] commands) {
				return worldPlayers(sender);
			}
		];

	}++/

}
