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
module selery.command.util;

import std.algorithm : sort;
import std.conv : to, ConvException;
import std.random : uniform;
import std.string : split, join, toLower, startsWith, replace;
import std.traits : isIntegral, isFloatingPoint;
import std.typecons : Tuple;

import selery.command.command : Command;
import selery.entity.entity : Entity;
import selery.lang : Messageable;
import selery.math.vector : EntityPosition, isVector, distance;
import selery.node.server : NodeServer;
import selery.player.player : Player, Gamemode;
import selery.world.world : World;

/**
 * Interface for command senders.
 */
interface CommandSender : Messageable {

	/**
	 * Gets the command sender's current server.
	 */
	public pure nothrow @property @safe @nogc shared(NodeServer) server();

	/**
	 * Gets the commands that can be called by the command sender
	 * in its current status.
	 * Aliases are included in the list and the Command object is
	 * the same as the non-aliased command.
	 * Example:
	 * ---
	 * assert(sender.availableCommands["help"] is sender.availableCommands["?"]);
	 * ---
	 */
	public @property Command[string] availableCommands();
	
}

/**
 * Interface for a command sender that is spawned in a world.
 */
interface WorldCommandSender : CommandSender {
	
	/**
	 * Gets the command sender's world.
	 */
	public pure nothrow @property @safe @nogc World world();
	
	/**
	 * Gets the command sender's current position.
	 */
	public @property EntityPosition position();
	
	/**
	 * Gets the list of the entities visible by the
	 * command sender.
	 */
	public @property Entity[] visibleEntities();
	
	/**
	 * Gets the list of the players visible by the
	 * command sender.
	 */
	public @property Player[] visiblePlayers();
	
}

enum PocketType {
	
	target,
	blockpos,
	stringenum,
	string,
	rawtext,
	integer,
	floating,
	boolean,
	
}

/**
 * Created an enum with a single value that can be used in
 * commands with a single argument.
 * Example:
 * ---
 * // test add @a
 * @command("test") test0(SingleEnum!"add", Target target) {}
 * 
 * // test remove @a
 * @command("test") test1(SingleEnum!"remove", Target target) {}
 * ---
 */
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

struct Ranged(T, string _type, T _min, T _max) if((isIntegral!T || isFloatingPoint!T) && _min < _max && (_type == "[]" || _type == "(]" || _type == "[)" || _type == "()")) {

	enum __is_range;

	alias Type = T;

	enum type = _type;

	enum min = _min;
	enum max = _max;

	T value;

	alias value this;

}

alias Ranged(T, T min, T max) = Ranged!(T, "[]", min, max);

enum isRanged(T) = __traits(hasMember, T, "__is_range");

template minImpl(T) {
	static if(isIntegral!T) enum minImpl = T.min;
	else enum minImpl = T.min_normal;
}

/**
 * Indicates a position with absolutes and/or relatives coordinates.
 * Example:
 * ---
 * auto pos = Position(Position.Point.fromString("~"), Position.Point.fromString("1"), Position.Point.fromString("~10"));
 * auto res = pos.from(BlockPosition(1, 10, 100));
 * assert(res == BlockPosition(1, 1, 110));
 * ---
 */
struct PositionImpl(V) if(isVector!V) {

	alias T = V.Type;
	
	static struct Point {
		
		private bool absolute;
		private T _value;
		private T function(T, T) _apply;
		
		public this(bool absolute, immutable T v) {
			this.absolute = absolute;
			this._value = v;
			if(absolute) {
				this._apply = &applyAbsolute;
			} else {
				this._apply = &applyRelative;
			}
		}
		
		private static T applyAbsolute(T a, T b) {
			return a;
		}
		
		private static T applyRelative(T a, T b) {
			return b + a;
		}
		
		public T apply(T value) {
			return this._apply(this._value, value);
		}
		
		public string toString() {
			if(this.absolute) {
				return to!string(this._value);
			} else if(this._value == 0) {
				return "~";
			} else {
				return "~" ~ to!string(this._value);		
			}
		}
		
		public static Point fromString(string str) {
			if(str.length) {
				if(str[0] == '~') {
					if(str.length == 1) {
						return Point(false, 0);
					} else {
						return Point(false, to!T(str[1..$]));
					}
				} else {
					return Point(true, to!T(str));
				}
			} else {
				return Point(true, T.init);
			}
		}
		
	}

	public static typeof(this) fromString(string str) {
		auto spl = str.split(" ");
		if(spl.length != 3) throw new ConvException("Wrong format");
		else return typeof(this)(Point.fromString(spl[0]), Point.fromString(spl[1]), Point.fromString(spl[2]));
	}
	
	mixin((){
		string ret;
		foreach(c ; V.coords) {
			ret ~= "public Point " ~ c ~ ";";
		}
		return ret;
	}());
	
	/**
	 * Creates a vector from an initial position (used for
	 * relative values).
	 */
	public @property V from(V position) {
		T[V.coords.length] ret;
		foreach(i, c; V.coords) {
			mixin("ret[i] = this." ~ c ~ ".apply(position." ~ c ~ ");");
		}
		return V(ret);
	}
	
	public string toCoordsString(string glue=", ") {
		string[] ret;
		foreach(c ; V.coords) {
			ret ~= mixin("this." ~ c ~ ".toString()");
		}
		return ret.join(glue);
	}

	public string toString() {
		return "Position(" ~ this.toCoordsString() ~ ")";
	}
	
}

/// ditto
alias Position = PositionImpl!EntityPosition;

/**
 * Indicates a target selected using a username or a target selector.
 * For reference see $(LINK2 https://minecraft.gamepedia.com/Commands#Target_selector_variables, Command on Minecraft Wiki).
 */
struct Target {

	/**
	 * Raw input of the selector used.
	 */
	public string input;
	
	public Entity[] entities;
	public Player[] players;

	/**
	 * Indicates whether the target was a player or an entity.
	 * Example:
	 * ---
	 * "Steve" = true
	 * "@a" = true
	 * "@e" = false
	 * "@e[type=player]" = true
	 * "@r" = true
	 * "@r[type=creeper]" = false
	 */
	public bool player = true;

	public this(string input) {
		this.input = input;
	}
	
	public this(string input, Entity[] entities, bool player=true) {
		this(input);
		this.entities = entities;
		foreach(entity ; entities) {
			if(cast(Player)entity) this.players ~= cast(Player)entity;
		}
		this.player = player;
	}
	
	public this(string input, Player[] players, bool player=true) {
		this(input);
		this.entities = cast(Entity[])players;
		this.players = players;
	}
	
	/**
	 * Creates a target from a username or a selector string.
	 */
	public static Target fromString(WorldCommandSender sender, string str) {
		if(str.length >= 2 && str[0] == '@') {
			string[string] selectors;
			if(str.length >= 4 && str[2] == '[' && str[$-1] == ']') {
				foreach(sel ; str[3..$-1].split(",")) {
					auto spl = sel.split("=");
					if(spl.length == 2) selectors[spl[0]] = spl[1];
				}
			}
			switch(str[1]) {
				case 's':
					if(cast(Entity)sender) {
						return Target(str, [cast(Entity)sender]);
					} else {
						return Target(str);
					}
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
							return Target(str, selected, is(T == Player));
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
					return Target(str, players, true);
				case 'e':
					auto entities = sender.visibleEntities;
					filter(sender, entities, selectors);
					return Target(str, entities, false);
				default:
					return Target(str);
			}
		} else {
			immutable sel = str.toLower;
			Player[] ret;
			foreach(player ; sender.visiblePlayers) {
				if(player.lname == sel) ret ~= player;
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

private void filter(T:Entity)(WorldCommandSender sender, ref T[] entities, string[string] selectors) {
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
				entities = filterDistance!false(sender.position, entities, amount);
			} else if(amount < 0) {
				entities = filterDistance!true(sender.position, entities, -amount);
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

private T[] filterDistance(bool inverted, T:Entity)(EntityPosition position, T[] entities, size_t count) {
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
