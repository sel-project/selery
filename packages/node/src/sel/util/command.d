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

import std.algorithm : sort;
import std.conv : ConvException, to;
static import std.math;
import std.random : uniform;
import std.string : split, replace, toLower, startsWith;
import std.traits : Parameters, ParameterDefaults, ParameterIdentifierTuple, staticIndexOf, Reverse;
import std.typecons : Tuple;

import sel.entity.entity : Entity;
import sel.math.vector;
import sel.player.player : Player, Gamemode;
import sel.plugin.plugin : arguments;
import sel.world.world : World;

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
					else return "string";
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
 * Interface for a command sender that is spawned in a world.
 */
interface WorldCommandSender : CommandSender {

	/**
	 * Gets the command sender's world.
	 */
	public pure nothrow @property @safe @nogc World world();

}

template SingleEnum(string value) {

	mixin("enum SingleEnum { " ~ value ~ " }");

}

/**
 * Example:
 * ---
 * enum Example : int {
 *    plain = 12,
 *    camelCase = 44,
 *    PascalCase = 100,
 *    ALL_UPPERCASE = 200
 * }
 * alias Snake = SnakeCaseEnum!Example;
 * assert(Example.plain == Snake.plain);
 * assert(Example.camelCase == Snake.camel_case);
 * assert(Example.PascalCase == Snake.pascal_case);
 * assert(Example.ALL_UPPERCASE == Snake.all_uppercase);
 * ---
 */
template SnakeCaseEnum(T) if(is(T == enum)) {

	mixin("enum SnakeCaseEnum {" ~ (){
		string ret;
		foreach(immutable member ; __traits(allMembers, T)) {
			ret ~= toSnakeCase(member) ~ "=T." ~ member ~ ",";
		}
		return ret;
	}() ~ "}");

}

private string toSnakeCase(string str) {
	string ret;
	bool noUpper = true;
	foreach(c ; str) {
		if(c >= 'A' && c <= 'Z') {
			if(noUpper) ret ~= c + 32;
			else ret ~= "_" ~ cast(char)(c + 32);
			noUpper = true;
		} else {
			ret ~= c;
			noUpper = false;
		}
	}
	return ret;
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
						if("c" !in selectors) {
							selectors["c"] = "1";
						}
						filter(sender, players, selectors);
						//TODO sort per distance
						return Target(str);
					} else {
						return Target(str);
					}
				case 'r':
					size_t amount = 1;
					auto c = "c" in selectors;
					if(c) {
						try {
							amount = to!size_t(*c);
						} catch(ConvException) {}
						selectors.remove("c");
					}
					Target rImpl(T:Entity)(T[] data) {
						filter(sender, data, selectors);
						if(amount >= data.length) {
							return Target(str, data);
						} else {
							T[] selected;
							while(--amount) {
								size_t index = uniform(0, data.length);
								selected ~= data[index];
								data = data[0..index] ~ data[index+1..$];
							}
							return Target(str, selected);
						}
					}
					auto type = "type" in selectors;
					if(type && *type != "player") {
						return rImpl(sender.visibleEntities);
					} else {
						return rImpl(sender.visiblePlayers);
					}
				case 'a':
					auto players = sender.visiblePlayers;
					filter(sender, players, selectors);
					return Target(str, players);
				case 'e':
					auto entities = sender.visibleEntities;
					filter(sender, entities, selectors);
					return Target(str, entities);
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

private struct Res {

	bool exists;
	bool inverted;
	string value;

	alias exists this;

}

private void filter(T:Entity)(CommandSender sender, ref T[] entities, string[string] selectors) {
	Res data(string key) {
		auto p = key in selectors;
		if(p) {
			if((*p).startsWith("!")) return Res(true, true, (*p)[1..$]);
			else return Res(true, false, *p);
		} else {
			return Res(false);
		}
	}
	auto type = data("type");
	if(type) {
		// filter type
		if(!type.inverted) filterImpl!("entity.type == a")(entities, type.value);
		else filterImpl!("entity.type != a")(entities, type.value);
	}
	auto name = data("name");
	if(name) {
		// filter by nametag
		if(!name.inverted) filterImpl!("entity.nametag == a")(entities, name.value);
		else filterImpl!("entity.nametag != a")(entities, name.value);
	}
	auto rx = data("rx");
	if(rx) {
		// filter by max pitch
		try { filterImpl!("entity.pitch <= a")(entities, to!float(name.value)); } catch(ConvException) {}
	}
	auto rxm = data("rxm");
	if(rxm) {
		// filter by min pitch
		try { filterImpl!("entity.pitch >= a")(entities, to!float(name.value)); } catch(ConvException) {}
	}
	auto ry = data("ry");
	if(ry) {
		// filter by max yaw
		try { filterImpl!("entity.yaw <= a")(entities, to!float(name.value)); } catch(ConvException) {}
	}
	auto rym = data("rym");
	if(rym) {
		// filter by min yaw
		try { filterImpl!("entity.yaw >= a")(entities, to!float(name.value)); } catch(ConvException) {}
	}
	auto m = data("m");
	auto l = data("l");
	auto lm = data("lm");
	if(m || l || lm) {
		static if(is(T : Player)) {
			alias players = entities;
		} else {
			// filter out non-players
			Player[] players;
			foreach(entity ; entities) {
				auto player = cast(Player)entity;
				if(player !is null) players ~= player;
			}
		}
		if(m) {
			// filter gamemode
			int gamemode = (){
				switch(m.value) {
					case "0": case "s": case "survival": return 0;
					case "1": case "c": case "creative": return 1;
					case "2": case "a": case "adventure": return 2;
					case "3": case "sp": case "spectator": return 3;
					default: return -1;
				}
			}();
			if(gamemode >= 0) {
				if(!m.inverted) filterImpl!("entity.gamemode == a")(players, gamemode);
				else filterImpl!("entity.gamemode != a")(players, gamemode);
			}
		}
		if(l) {
			// filter xp (min)
			try {
				filterImpl!("entity.level <= a")(players, to!uint(l.value));
			} catch(ConvException) {}
		}
		if(lm) {
			// filter xp (max)
			try {
				filterImpl!("entity.level >= a")(players, to!uint(l.value));
			} catch(ConvException) {}
		}
		static if(!is(T : Player)) {
			entities = cast(Entity[])players;
		}
	}
	auto c = data("c");
	if(c) {
		try {
			auto amount = to!ptrdiff_t(c.value);
			if(amount > 0) {
				entities = filterDistance!false(sender.startingPosition, entities, amount);
			} else if(amount < 0) {
				entities = filterDistance!true(sender.startingPosition, entities, -amount);
			} else {
				entities.length = 0;
			}
		} catch(ConvException) {}
	}
}

private void filterImpl(string query, T:Entity, A)(ref T[] entities, A a) {
	T[] ret;
	foreach(entity ; entities) {
		if(mixin(query)) ret ~= entity;
	}
	if(ret.length != entities.length) entities = ret;
}

private T[] filterDistance(bool inverted, T:Entity)(BlockPosition position, T[] entities, size_t count) {
	if(count >= entities.length) return entities;
	Tuple!(T, double)[] distances;
	foreach(entity ; entities) {
		distances ~= Tuple!(T, double)(entity, distance(position, entity.position));
	}
	sort!((a, b) => a[1] == b[1] ? a[0].id < b[0].id : a[1] < b[1])(distances);
	T[] ret;
	foreach(i ; 0..count) {
		static if(inverted) ret ~= distances[$-i-1][0];
		else ret ~= distances[i][0];
	}
	return ret;
}
