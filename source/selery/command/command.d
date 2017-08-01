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
import std.string : toLower, startsWith;
import std.traits : Parameters, ParameterDefaults, ParameterIdentifierTuple, hasUDA, getUDAs, staticIndexOf, Reverse, isIntegral, isFloatingPoint;

import selery.command.args : StringReader, CommandArg;
import selery.command.util : PocketType, CommandSender, WorldCommandSender, Ranged, isRanged, Target, Position;
import selery.entity.entity : Entity;
import selery.event.node.command : CommandNotFoundEvent, CommandFailedEvent;
import selery.format : Text;
import selery.lang : Message;
import selery.node.server : ServerCommandSender;
import selery.player.player : Player;
import selery.util.messages : Messages;
import selery.util.tuple : Tuple;

struct CommandResult {

	// defaults
	enum SUCCESS = CommandResult(success);
	enum NOT_FOUND = CommandResult(notFound);
	enum INVALID_SYNTAX = CommandResult(invalidSyntax);

	enum : ubyte {

		success,

		notFound,
		invalidSyntax,

		invalidParameter,

		invalidNumber,
		invalidBoolean,	
		playerNotFound,
		targetNotFound,
		invalidRangeDown,
		invalidRangeUp

	}

	ubyte result = success;
	string[] args;

	string query;
	Command command;

	inout pure nothrow @property @safe @nogc bool successful() {
		return result == success;
	}

	/**
	 * Returns: whether the commands was successfully executed
	 */
	inout bool trigger(CommandSender sender) {
		if(this.result != success) {
			if(this.result == notFound) {
				//TODO call event with actual used command
				if(!(cast()sender.server).callCancellableIfExists!CommandNotFoundEvent(sender, this.query)) sender.sendMessage(Text.red, Messages.generic.notFound);
			} else {
				//TODO call event with actual used command
				if(!(cast()sender.server).callCancellableIfExists!CommandFailedEvent(sender, cast()this.command)) {
					const message = (){
						final switch(result) with(Messages) {
							case invalidSyntax: return generic.invalidSyntax;
							case invalidParameter: return generic.invalidParameter;
							case invalidNumber: return generic.numInvalid;
							case invalidBoolean: return generic.invalidBoolean;
							case playerNotFound: return generic.playerNotFound;
							case targetNotFound: return generic.targetNotFound;
							case invalidRangeDown: return generic.numTooSmall;
							case invalidRangeUp: return generic.numTooBig;
						}
					}();
					sender.sendMessage(Text.red, message, this.args);
				}
			}
			return false;
		} else {
			return true;
		}
	}

}

class Command {

	enum MISSING_DESCRIPTION = Message("No description given");

	/**
	 * Command's overload.
	 */
	public class Overload {

		enum : string {

			TARGET = "target",
			ENTITIES = "entities",
			PLAYERS = "players",
			PLAYER = "player",
			ENTITY = "entity",
			POSITION = "x y z",
			BOOL = "bool",
			INT = "int",
			FLOAT = "float",
			STRING = "string",
			UNKNOWN = "unknown"

		}

		/**
		 * Name of the parameters (name of the variables if not specified
		 * by the user).
		 */
		public string[] params;

		public abstract @property size_t requiredArgs();

		public abstract string typeOf(size_t i);

		public abstract PocketType pocketTypeOf(size_t i);

		public abstract string[] enumMembers(size_t i);

		public abstract bool callableBy(CommandSender sender);
		
		public abstract CommandResult callArgs(CommandSender sender, string args);

		public abstract CommandResult callArgs(CommandSender sender, CommandArg[] args);
		
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

		public override @property size_t requiredArgs() {
			return minArgs;
		}

		public override string typeOf(size_t i) {
			switch(i) {
				foreach(immutable j, T; Args) {
					case j:
						static if(is(T == Target)) return TARGET;
						else static if(is(T == Entity[])) return ENTITIES;
						else static if(is(T == Player[])) return PLAYERS;
						else static if(is(T == Player)) return PLAYER;
						else static if(is(T == Entity)) return ENTITY;
						else static if(is(T == Position)) return POSITION;
						else static if(is(T == bool)) return BOOL;
						else static if(is(T == enum)) return T.stringof;
						else static if(isIntegral!T || isRanged!T && isIntegral!(T.Type)) return INT;
						else static if(isFloatingPoint!T || isRanged!T && isFloatingPoint!(T.Type)) return FLOAT;
						else return STRING; // also used for enums and commands
				}
				default:
					return UNKNOWN;
			}
		}

		public override PocketType pocketTypeOf(size_t i) {
			switch(i) {
				foreach(immutable j, T; Args) {
					case j:
						static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player) || is(T == Entity)) return PocketType.target;
						else static if(is(T == Position)) return PocketType.blockpos;
						else static if(is(T == bool)) return PocketType.boolean;
						else static if(is(T == enum) || is(T == Command)) return PocketType.stringenum;
						else static if(is(T == string)) return j == Args.length - 1 ? PocketType.rawtext : PocketType.string;
						else static if(isIntegral!T || isRanged!T && isIntegral!(T.Type)) return PocketType.integer;
						else static if(isFloatingPoint!T || isRanged!T && isFloatingPoint!(T.Type)) return PocketType.floating;
						else goto default;
				}
				default:
					return PocketType.rawtext;
			}
		}

		public override string[] enumMembers(size_t i) {
			switch(i) {
				foreach(immutable j, T; E) {
					static if(is(T == enum)) {
						case j: return [__traits(allMembers, T)];
					} else static if(is(T == Command)) {
						//TODO
					}
				}
				default: return [];
			}
		}

		public override bool callableBy(CommandSender sender) {
			static if(is(C == CommandSender)) return true;
			else return cast(C)sender !is null;
		}
		
		public override CommandResult callArgs(CommandSender sender, string args) {
			static if(!is(C == CommandSender)) {
				C senderc = cast(C)sender;
				if(senderc is null) return CommandResult.NOT_FOUND;
			} else {
				alias senderc = sender;
			}
			StringReader reader = StringReader(args);
			Args cargs;
			foreach(immutable i, T; Args) {
				if(!reader.eof()) {
					static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player) || is(T == Entity)) {
						immutable selector = reader.readQuotedString();
						auto target = Target.fromString(sender, selector);
						if(target.entities.length == 0) return CommandResult(selector.startsWith("@") ? CommandResult.targetNotFound : CommandResult.playerNotFound);
						static if(is(T == Player)) {
							cargs[i] = target.players[0];
						} else static if(is(T == Entity)) {
							cargs[i] = target.entities[0];
						} else static if(is(T == Player[])) {
							cargs[i] = target.players;
						} else static if(is(T == Entity[])) {
							cargs[i] = target.entities;
						} else {
							cargs[i] = target;
						}
					} else static if(is(T == Position)) {
						try {
							cargs[i] = Position(Position.Point.fromString(reader.readString()), Position.Point.fromString(reader.readString()), Position.Point.fromString(reader.readString()));
						} catch(Exception) {
							return CommandResult.INVALID_SYNTAX;
						}
					} else static if(is(T == bool)) {
						immutable value = reader.readString();
						if(value == "true") cargs[i] = true;
						else if(value == "false") cargs[i] = false;
						else return CommandResult(CommandResult.invalidBoolean, [value]);
					}  else static if(is(T == enum)) {
						immutable value = reader.readString();
						switch(value) {
							mixin((){
									string ret;
									foreach(immutable member ; __traits(allMembers, T)) {
										ret ~= "case \"" ~ member ~ "\": cargs[i]=T." ~ member ~ "; break;";
									}
									return ret;
								}());
							default:
								return CommandResult(CommandResult.invalidParameter, [value]);
						}
					} else static if(isIntegral!T || isFloatingPoint!T || isRanged!T) {
						static if(isFloatingPoint!T) enum _min = T.min_normal; // float, double and real. not ranged
						else enum _min = T.min;
						immutable value = reader.readString();
						try {
							static if(isFloatingPoint!T || isRanged!T && isFloatingPoint!(T.Type)) {
								// numbers cannot be infinite or nan
								immutable num = to!double(value);
								if(std.math.isNaN(num) || std.math.isInfinity(num)) return CommandResult(CommandResult.invalidNumber, [value]);
							} else {
								immutable num = to!int(value);
							}
							// control bounds
							static if(!isRanged!T || T.type[0] == '[') { if(num < _min) return CommandResult(CommandResult.invalidRangeDown, [value, to!string(_min)]); }
							else { if(num <= _min) return CommandResult(CommandResult.invalidRangeDown, [value, to!string(_min)]); }
							static if(!isRanged!T || T.type[1] == ']') { if(num > T.max) return CommandResult(CommandResult.invalidRangeUp, [value, to!string(T.max)]); }
							else { if(num >= T.max) return CommandResult(CommandResult.invalidRangeUp, [value, to!string(T.max)]); }
							// assign
							static if(isRanged!T) cargs[i] = T(cast(T.Type)num);
							else cargs[i] = cast(T)num;
						} catch(ConvException) {
							return CommandResult(CommandResult.invalidNumber, [value]);
						}
					} else static if(i == Args.length - 1) {
						immutable value = reader.readText();
						if(value.length > 2 && value[0] == '"' && value[$-1] == '"') {
							cargs[i] = value[1..$-1];
						} else {
							cargs[i] = value;
						}
					} else {
						cargs[i] = reader.readQuotedString();
					}
				} else {
					static if(!is(Params[i] == void)) cargs[i] = Params[i];
					else return CommandResult.INVALID_SYNTAX;
				}
			}
			reader.skip();
			if(reader.eof) {
				this.del(senderc, cargs);
				return CommandResult.SUCCESS;
			} else {
				return CommandResult.INVALID_SYNTAX;
			}
		}
		
		public override CommandResult callArgs(CommandSender sender, CommandArg[] args) {
			if(args.length > Args.length) return CommandResult.INVALID_SYNTAX;
			static if(!is(C == CommandSender)) {
				C senderc = cast(C)sender;
				if(senderc is null) return CommandResult.NOT_FOUND;
			} else {
				alias senderc = sender;
			}
			Args cargs;
			foreach(immutable i, T; Args) {
				if(i < args.length) {
					CommandArg arg = args[i];
					static if(is(T == Target) || is(T == Entity[]) || is(T == Player[]) || is(T == Player) || is(T == Entity)) {
						if(arg.type != CommandArg.Type.target) return CommandResult.INVALID_SYNTAX;
						else if(arg.target.entities.length == 0) return CommandResult(CommandResult.targetNotFound);
						static if(is(T == Player)) {
							cargs[i] = arg.target.players[0];
						} else static if(is(T == Entity)) {
							cargs[i] = arg.target.entities[0];
						} else static if(is(T == Player[])) {
							cargs[i] = arg.target.players;
						} else static if(is(T == Entity[])) {
							cargs[i] = arg.target.entities;
						} else {
							cargs[i] = arg.target;
						}
					} else static if(is(T == Position)) {
						if(arg.type != CommandArg.Type.position) return CommandResult.INVALID_SYNTAX;
						cargs[i] = arg.position;
					} else static if(is(T == bool)) {
						if(arg.type != CommandArg.Type.boolean) return CommandResult.INVALID_SYNTAX;
						cargs[i] = arg.boolean;
					} else static if(isIntegral!T) {
						if(arg.type != CommandArg.Type.integer) return CommandResult.INVALID_SYNTAX;
						cargs[i] = cast(T)arg.integer;
					} else static if(isFloatingPoint!T) {
						if(arg.type != CommandArg.Type.floating) return CommandResult.INVALID_SYNTAX;
						cargs[i] = cast(T)arg.floating;
					} else static if(isRanged!T) {
						//TODO
					} else {
						if(arg.type != CommandArg.Type.string) return CommandResult.INVALID_SYNTAX;
						//TODO move before numbers! isIntegral and isFloatingPoint may recognise an enum as number
						static if(is(T == enum)) {
							switch(arg.str) {
								mixin((){
									string ret;
									foreach(immutable member ; __traits(allMembers, T)) {
										ret ~= "case \"" ~ member ~ "\": cargs[i]=T." ~ member ~ "; break;";
									}
									return ret;
								}());
								default:
									return CommandResult(CommandResult.invalidParameter, [arg.str]);
							}
						} else {
							cargs[i] = arg.str;
						}
					}
				} else {
					static if(!is(Params[i] == void)) cargs[i] = Params[i];
					else return CommandResult.INVALID_SYNTAX;
				}
			}
			this.del(senderc, cargs);
			return CommandResult.SUCCESS;
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
		//TODO nameable params
		this.overloads ~= new OverloadOf!(Parameters!func[0], Parameters!func[1..$], ParameterDefaults!func[1..$])(del, params);
	}
	
	/**
	 * Returns: true if the command has been executed, false otherwise.
	 */
	deprecated bool call(C:CommandSender, T)(C sender, T args) if(is(T == string) || is(T == CommandArg[])) {
		foreach(cmd ; this.overloads) {
			if(cmd.callArgs(sender, args).successful) return true;
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
			isIntegral!T ||
			isFloatingPoint!T ||
			isRanged!T ||
			is(T == Command) ||
			is(T == string) || is(T == enum)
		)
		&& areValidArgs!(E[1..$]);
	}
}
