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
module selery.command.command;

import std.conv : ConvException, to;
static import std.math;
import std.string : toLower;
import std.traits : Parameters, ParameterDefaults, ParameterIdentifierTuple, hasUDA, getUDAs, staticIndexOf, Reverse;

import selery.command.args : StringReader, CommandArg;
import selery.command.util : PocketType, CommandSender, WorldCommandSender, Target, Position;
import selery.entity.entity : Entity;
import selery.lang : Message;
import selery.node.server : ServerCommandSender;
import selery.player.player : Player;
import selery.util.tuple : Tuple;

alias param = Tuple!(string, "param");

class Command {

	enum MISSING_DESCRIPTION = Message("No description given");

	/**
	 * Command's overload.
	 */
	public class Overload {

		public abstract pure nothrow @property @safe @nogc bool callableByServer();

		public abstract pure nothrow @property @safe @nogc bool callableByPlayer();

		//public abstract pure nothrow @property @safe @nogc bool callableByCommandBlock();

		/**
		 * Name of the parameters (name of the variables if not specified
		 * by the user).
		 */
		public string[] params;

		public abstract @property size_t requiredArgs();

		public abstract string typeOf(size_t i);

		public abstract PocketType pocketTypeOf(size_t i);

		public abstract string[] enumMembers(size_t i);
		
		public abstract bool callArgs(CommandSender sender, string args);

		public abstract bool callArgs(CommandSender sender, CommandArg[] args);
		
	}
	
	private class OverloadOf(C:CommandSender, E...) : Overload if(areValidArgs!(E[0..$/2])) {

		private alias Args = E[0..$/2];
		private alias Params = E[$/2..$];

		private enum size_t minArgs = staticIndexOf!(void, Params) != -1 ? (Params.length - staticIndexOf!(void, Reverse!Params)) : 0;

		public void delegate(C, Args) del;
		
		public this(void delegate(C, Args) del, string[] params) {
			this.del = del;
			this.params = params;
		}

		public override pure nothrow @property @safe @nogc bool callableByServer() {
			static if(is(C == ServerCommandSender) || is(C == CommandSender)) {
				return true;
			} else {
				return false;
			}
		}

		public override pure nothrow @property @safe @nogc bool callableByPlayer() {
			static if(is(C == CommandSender) || is(C == WorldCommandSender) || is(C == Player)) {
				return true;
			} else {
				return false;
			}
		}

		public override @property size_t requiredArgs() {
			return minArgs;
		}

		public override string typeOf(size_t i) {
			switch(i) {
				foreach(immutable j, T; Args) {
					case j:
						static if(is(T == Target)) return "target";
						else static if(is(T == Entity[])) return "entities";
						else static if(is(T == Player[])) return "players";
						else static if(is(T == Player)) return "player";
						else static if(is(T == Entity)) return "entity";
						else static if(is(T == Position)) return "position";
						else static if(is(T == bool)) return "bool";
						else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) return "int";
						else static if(is(T == float) || is(T == double)) return "float";
						else return "string";
				}
				default:
					return "unknwon";
			}
		}

		public override PocketType pocketTypeOf(size_t i) {
			switch(i) {
				foreach(immutable j, T; Args) {
					case j:
						static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player) || is(T == Entity)) return PocketType.target;
						else static if(is(T == Position)) return PocketType.blockpos;
						else static if(is(T == bool)) return PocketType.boolean;
						else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) return PocketType.integer;
						else static if(is(T == float) || is(T == double) || is(T == real)) return PocketType.floating;
						else static if(is(T == enum)) return PocketType.stringenum;
						else static if(is(T == string)) return j == Args.length - 1 ? PocketType.rawtext : PocketType.string;
						else goto default;
				}
				default:
					return PocketType.rawtext;
			}
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
		
		public override bool callArgs(CommandSender sender, string args) {
			static if(!is(C == CommandSender)) {
				C senderc = cast(C)sender;
				if(senderc is null) return false;
			} else {
				alias senderc = sender;
			}
			try {
				StringReader reader = StringReader(args);
				Args cargs;
				foreach(immutable i, T; Args) {
					if(!reader.eof()) {
						static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player) || is(T == Entity)) {
							auto target = Target.fromString(sender, reader.readQuotedString());
							static if(is(T == Player)) {
								if(target.players.length) cargs[i] = target.players[0];
							} else static if(is(T == Entity)) {
								if(target.entities.length) cargs[i] = target.entities[0];
							} else static if(is(T == Player[])) {
								cargs[i] = target.players;
							} else static if(is(T == Entity[])) {
								cargs[i] = target.entities;
							} else {
								cargs[i] = target;
							}
						} else static if(is(T == Position)) {
							cargs[i] = Position(Position.Point.fromString(reader.readString()), Position.Point.fromString(reader.readString()), Position.Point.fromString(reader.readString()));
						} else static if(is(T == bool)) {
							cargs[i] = to!bool(reader.readString());
						} else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
							cargs[i] = to!T(reader.readString());
						} else static if(is(T == float) || is(T == double)) {
							auto res = to!T(reader.readString());
							if(std.math.isNaN(res) || std.math.isInfinity(res)) return false;
							cargs[i] = res;
						} else static if(is(T == enum)) {
							switch(reader.readString()) {
								mixin((){
									string ret;
									foreach(immutable member ; __traits(allMembers, T)) {
										ret ~= "case \"" ~ member ~ "\": cargs[i]=T." ~ member ~ "; break;";
									}
									return ret;
								}());
								default:
									return false;
							}
						} else static if(i == Args.length - 1) {
							cargs[i] = reader.readText();
						} else {
							cargs[i] = reader.readQuotedString();
						}
					} else {
						static if(!is(Params[i] == void)) cargs[i] = Params[i];
						else return false;
					}
				}
				reader.skip();
				if(reader.eof) {
					this.del(senderc, cargs);
					return true;
				}
			} catch(ConvException) {}
			return false;
		}
		
		public override bool callArgs(CommandSender sender, CommandArg[] args) {
			if(args.length > Args.length) return false;
			static if(!is(C == CommandSender)) {
				C senderc = cast(C)sender;
				if(senderc is null) return false;
			} else {
				alias senderc = sender;
			}
			Args cargs;
			foreach(immutable i, T; Args) {
				if(i < args.length) {
					CommandArg arg = args[i];
					static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player) || is(T == Entity)) {
						if(arg.type != CommandArg.Type.target) return false;
						static if(is(T == Player)) {
							if(arg.store.target.players.length) cargs[i] = arg.store.target.players[0];
						} else static if(is(T == Entity)) {
							if(arg.store.target.entities.length) cargs[i] = arg.store.target.entities[0];
						} else static if(is(T == Player[])) {
							cargs[i] = arg.store.target.players;
						} else static if(is(T == Entity[])) {
							cargs[i] = arg.store.target.entities;
						} else {
							cargs[i] = arg.store.target;
						}
					} else static if(is(T == Position)) {
						if(arg.type != CommandArg.Type.position) return false;
						cargs[i] = arg.store.position;
					} else static if(is(T == bool)) {
						if(arg.type != CommandArg.Type.boolean) return false;
						cargs[i] = arg.store.boolean;
					} else static if(is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong)) {
						if(arg.type != CommandArg.Type.integer) return false;
						cargs[i] = cast(T)arg.store.integer;
					} else static if(is(T == float) || is(T == double)) {
						if(arg.type != CommandArg.Type.floating) return false;
						cargs[i] = cast(T)arg.store.floating;
					} else {
						if(arg.type != CommandArg.Type.string) return false;
						static if(is(T == enum)) {
							switch(arg.store.str) {
								mixin((){
									string ret;
									foreach(immutable member ; __traits(allMembers, T)) {
										ret ~= "case \"" ~ member ~ "\": cargs[i]=T." ~ member ~ "; break;";
									}
									return ret;
								}());
								default:
									return false;
							}
						} else {
							cargs[i] = arg.store.str;
						}
					}
				} else {
					static if(!is(Params[i] == void)) cargs[i] = Params[i];
					else return false;
				}
			}
			this.del(senderc, cargs);
			return true;
		}
		
	}

	private static size_t count = 0;

	immutable size_t id;
	
	immutable string command;
	immutable Message description;
	immutable string[] aliases;

	immutable bool op;
	immutable bool hidden;
	
	Overload[] overloads;
	
	this(string command, Message description=MISSING_DESCRIPTION, string[] aliases=[], bool op=false, bool hidden=false) {
		this.id = count++;
		this.command = command.toLower;
		this.description = description;
		this.aliases = aliases.idup;
		this.op = op;
		this.hidden = hidden;
	}

	void add(alias func)(void delegate(Parameters!func) del) if(Parameters!func.length >= 1 && is(Parameters!func[0] : CommandSender)) {
		string[] params = [ParameterIdentifierTuple!func][1..$];
		/*foreach(i, P; Parameters!func) {
			static if(hasUDA!(P, param) && i != 0) {
				params[i-1] = getUDAs!(P, param)[0];
			}
		}*/
		this.overloads ~= new OverloadOf!(Parameters!func[0], Parameters!func[1..$], ParameterDefaults!func[1..$])(del, params);
	}
	
	/**
	 * Returns: true if the command has been executed, false otherwise.
	 */
	bool call(C:CommandSender, T)(C sender, T args) if(is(T == string) || is(T == CommandArg[])) {
		foreach(cmd ; this.overloads) {
			if(cmd.callArgs(sender, args)) return true;
		}
		return false;
	}
	
}

public bool areValidArgs(E...)() {
	static if(E.length == 0) {
		return true;
	} else {
		alias T = E[0];
		return (
			is(T == Target) || is(T == Player) || is(T == Entity) || is(T == Player[]) || is(T == Entity[]) ||
			is(T == Position) ||
			is(T == bool) ||
			is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint) || is(T == long) || is(T == ulong) ||
			is(T == float) || is(T == float) ||
			is(T == string) || is(T == enum)
		)
		&& areValidArgs!(E[1..$]);
	}
}
