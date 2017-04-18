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
import std.random : uniform;
import std.string : join, split, replace, toLower;
import std.traits : Parameters, ParameterDefaults, ParameterIdentifierTuple, staticIndexOf, Reverse;
import std.typecons : Tuple;

import sel.server : server;
import sel.entity.effect : Effect;
import sel.entity.entity : Entity;
import sel.event.world : EntityDamageByCommandEvent;
import sel.item : Item, Slot;
import sel.math.vector;
import sel.player.player : Player, Gamemode;
import sel.plugin.plugin : arguments;
import sel.util.lang : translate;
import sel.util.log;
import sel.world.world : World;

/*bool areValidCommandArgs(E...)() {
	static if(E.length == 1 && (is(E[0] == arguments) || is(E[0] == string[]))) return true;
	foreach(T ; E) {
		static if(!is(T == string) && !is(T == long) && !is(T == ulong) && !is(T == bool) && !is(T == Position)) return false;
	}
	return true;
}*/

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
		
		abstract bool callArgs(CommandSender sender, arguments args);
		
	}
	
	private class CmdOf(C:CommandSender, E...) : Cmd {

		private alias Args = E[0..$/2];
		private alias Params = E[$/2..$];

		mixin("private enum size_t minArgs = " ~ to!string(staticIndexOf!(void, Params) != -1 ? (Params.length - staticIndexOf!(void, Reverse!Params)) : 0) ~ ";");

		public void delegate(C, Args) del;
		
		public this(void delegate(C, Args) del, string[] params) {
			this.del = del;
			this.params = params;
		}

		public override @property size_t requiredArgs() {
			return minArgs;
		}

		public override string typeOf(size_t i) {
			foreach(immutable j, T; Args) {
				if(i == j) {
					static if(is(T == Target)) return "target";
					else static if(is(T == Entity[])) return "entities";
					else static if(is(T == Player[])) return "players";
					else static if(is(T == Player)) return "player";
					else static if(is(T == Position)) return "position";
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
					else static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player)) return "target";
					else static if(is(T == string)) return j == Args.length - 1 ? "rawtext" : "string";
					else static if(is(T == bool)) return "bool";
					else static if(is(T == Position)) return "blockpos";
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
					static if(is(T == enum)) return [__traits(allMembers, T)]; //TODO this should be converted into snake case (which minecraft uses)
					else break;
				}
			}
			return new string[0];
		}

		public override bool callArgs(CommandSender sender, arguments args) {
			static if(!is(C == CommandSender)) {
				C senderc = cast(C)sender;
				if(senderc is null) return false;
			} else {
				alias senderc = sender;
			}
			static if(Args.length == 1 && is(Args[0] == arguments))  {
				this.del(senderc, args);
			} else static if(Args.length == 1 && is(Args[0] == string[])) {
				this.del(senderc, args.dup);
			} else {
				Args cargs;
				size_t j = 0;
				foreach(immutable i, T; Args) {
					if(j < args.length) {
						static if(is(T == enum)) {
							bool found = false;
							foreach(immutable member ; __traits(allMembers, T)) {
								//TODO convert member to snake case
								if(!found && member == args[j]) {
									mixin("cargs[i] = T." ~ member ~ ";");
									found = true;
									break;
								}
							}
							if(!found) return false;
						} else static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player)) {
							auto target = Target.fromString(sender, args[j]);
							static if(is(T == Player)) {
								if(target.players.length) cargs[i] = target.players[0];
							} else static if(is(T == Player[])) {
								cargs[i] = target.players;
							} else static if(is(T == Entity[])) {
								cargs[i] = target.entities;
							} else {
								cargs[i] = target;
							}
						} else {
							try {
								static if(is(T == Position)) {
									if(j + 3 > args.length) return false;
									cargs[i] = Position(Position.Point.fromString(args[j++]), Position.Point.fromString(args[j++]), Position.Point.fromString(args[j]));
								} else {
									// bool, int, float, string
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
				this.del(senderc, cargs);
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
	immutable bool hidden;
	
	Cmd[] overloads;
	
	this(string command, string description="", string[] aliases=[], bool op=false, bool hidden=false) {
		this.id = count++;
		this.command = command.toLower;
		this.description = description;
		this.aliases = aliases.idup;
		this.op = op;
		this.hidden = hidden;
	}

	void add(alias func)(void delegate(Parameters!func) del, string[] params) if(Parameters!func.length >= 1 && is(Parameters!func[0] : CommandSender)) {
		while(params.length < Parameters!func.length - 1) params ~= [ParameterIdentifierTuple!func][params.length + 1];
		this.overloads ~= new CmdOf!(Parameters!func[0], Parameters!func[1..$], ParameterDefaults!func[1..$])(del, params);
	}
	
	/**
	 * Returns: true if the command has been executed, false otherwise.
	 */
	bool call(C:CommandSender, E...)(C sender, E args) {
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
	bool callArgs(C:CommandSender)(C sender, arguments args) {
		foreach(cmd ; this.overloads) {
			if(cmd.callArgs(sender, args)) return true;
		}
		return false;
	}

	public Command dup(C:CommandSender=CommandSender)() {
		Command ret = new Command(this.command, this.description, this.aliases, this.op, this.hidden);
		ret.overloads = this.overloads;
		return ret;
	}
	
}

/**
 * Interface for command senders.
 */
interface CommandSender {

	/**
	 * Gets the command sender's current position.
	 */
	public BlockPosition startingPosition();

	/**
	 * Gets the list of the entities visible by the
	 * command sender.
	 */
	public Entity[] visibleEntities();

	/**
	 * Gets the list of the players visible by the
	 * command sender.
	 */
	public Player[] visiblePlayers();

	/**
	 * Sends a translatable message to the command sender.
	 */
	public void sendMessage(string, string[]=[]);

}

/**
 * Indicates a position with abslutes and/or relatives coordinates.
 * Example:
 * ---
 * auto pos = Position(Position.Point.fromString("~"), Position.Point.fromString("1"), Position.Point.fromString("~10"));
 * auto res = pos.from(BlockPosition(1, 10, 100));
 * assert(res == BlockPosition(1, 1, 110));
 * ---
 */
struct PositionImpl(T) if(isVector!T) {

	static struct Point {

		private T.Type _value;
		private T.Type function(T.Type, T.Type) _apply;

		public this(bool absolute, immutable T.Type v) {
			this._value = v;
			if(absolute) {
				this._apply = &applyAbsolute;
			} else {
				this._apply = &applyRelative;
			}
		}

		private static T.Type applyAbsolute(T.Type a, T.Type b) {
			return a;
		}

		private static T.Type applyRelative(T.Type a, T.Type b) {
			return b + a;
		}

		public T.Type apply(T.Type value) {
			return this._apply(this._value, value);
		}

		public static Point fromString(string str) {
			if(str.length) {
				if(str[0] == '~') {
					if(str.length == 1) {
						return Point(false, 0);
					} else {
						return Point(false, to!(T.Type)(str[1..$]));
					}
				} else {
					return Point(true, to!(T.Type)(str));
				}
			} else {
				return Point(true, T.Type.init);
			}
		}

	}

	mixin((){
		string ret;
		foreach(c ; T.coords) {
			ret ~= "public Point " ~ c ~ ";";
		}
		return ret;
	}());

	/**
	 * Creates a vector from an initial position (used for
	 * relative values).
	 */
	public @property T from(T position) {
		T.Type[T.coords.length] ret;
		foreach(i, c; T.coords) {
			mixin("ret[i] = this." ~ c ~ ".apply(position." ~ c ~ ");");
		}
		return T(ret);
	}

}

/// ditto
alias Position = PositionImpl!BlockPosition;

/**
 * Indicates a target selected using a username or a target selector.
 * For reference see $(LINK2 https://minecraft.gamepedia.com/Commands#Target_selector_variables, Command on Minecraft Wiki).
 */
struct Target {

	public string input;

	public Entity[] entities;
	public Player[] players;

	public this(string input) {
		this.input = input;
	}

	public this(string input, Entity[] entities) {
		this(input);
		this.entities = entities;
		foreach(entity ; entities) {
			if(cast(Player)entity) this.players ~= cast(Player)entity;
		}
	}

	public this(string input, Player[] players) {
		this(input);
		this.entities = cast(Entity[])players;
		this.players = players;
	}

	/**
	 * Creates a target from a username or a selector string.
	 */
	public static Target fromString(CommandSender sender, string str) {
		if(str.length >= 2 && str[0] == '@') {
			string[string] selectors;
			if(str.length >= 4 && str[2] == '[' && str[$-1] == ']') {
				foreach(sel ; str[3..$-1].split(",")) {
					auto spl = sel.split("=");
					if(spl.length == 2) selectors[spl[0]] = spl[1];
				}
			}
			switch(str[1]) {
				case 'p':
					auto players = sender.visiblePlayers;
					if(players.length) {
						//TODO
						return Target(str);
					} else {
						return Target(str);
					}
				case 'r': 
					return Target(str, [sender.visiblePlayers[uniform(0, $)]]);
				case 'a':
					return Target(str, sender.visiblePlayers);
				case 'e':
					return Target(str, sender.visibleEntities);
				default:
					return Target(str);
			}
		} else {
			immutable sel = str.toLower.replace("-", " ");
			Player[] ret;
			foreach(player ; sender.visiblePlayers) {
				if(player.iname == sel) ret ~= player;
			}
			return Target(str, ret);
		}
	}

}
