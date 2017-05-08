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
module sel.node.plugin.plugin;

import std.conv : to;
import std.traits : isAbstractClass, getUDAs, hasUDA;

import sel.about;
public import sel.plugin;

import sel.node.server : server;

class PluginOf(T) : Plugin if(!isAbstractClass!T || is(T == struct)) {

	public this(string namespace, string name, string[] authors, string vers, bool api, string language) {
		this.n_namespace = namespace;
		this.n_name = name;
		this.n_authors = authors;
		this.n_version = vers;
		this.n_api = api;
		this.n_language = language;
		static if(!is(T : Object)) this.hasMain = true;
	}

	public override void load() {
		static if(!is(T == Object)) {
			T main;
			static if(is(T == class)) {
				main = new T();
			}
			foreach(t ; __traits(allMembers, T)) {
				static if(is(typeof(__traits(getMember, T, t)) == function)) {
					mixin("alias func = T." ~ t ~ ";");
					mixin("auto del = &main." ~ t ~ ";");
					// start/stop
					static if(hasUDA!(func, start)) {
						this.onstart ~= del;
					}
					static if(hasUDA!(func, reload)) {
						this.onreload ~= del;
					}
					static if(hasUDA!(func, stop)) {
						this.onstop ~= del;
					}
					// events
					static if(hasUDA!(func, event)) {
						this.registerEvent!(false, hasUDA!(func, cancel))(del);
					}
					static if(hasUDA!(func, global)) {
						this.registerEvent!(true, hasUDA!(func, cancel))(del);
					}
					// commands
					static if(hasUDA!(func, command)) {
						static if(hasUDA!(func, description)) {
							enum d = getUDAs!(func, description)[0];
						} else {
							enum d = "";
						}
						static if(hasUDA!(func, aliases)) {
							enum a = getUDAs!(func, aliases)[0];
						} else {
							enum a = new string[0];
						}
						static if(hasUDA!(func, params)) {
							enum p = getUDAs!(func, params);
						} else {
							enum p = new string[0];
						}
						server.registerCommand!(func)(del, getUDAs!(func, command)[0], d, a, p, hasUDA!(func, op), hasUDA!(func, hidden));
					}
					// tasks
					static if(hasUDA!(func, task)) {
						server.addTask(del, getUDAs!(func, task)[0]);
					}
				}
			}
		}
	}

	private void registerEvent(bool isGlobal, bool isCancelled, T)(void delegate(T) event) {
		static if(isCancelled) {
			event = (T e){ e.cancel(); };
		}
		static if(isGlobal) {
			server.globalListener.addEventListener(event);
		} else {
			server.addEventListener(event);
		}
	}

}

struct command {

	string command;

	alias command this;

}

struct description {

	string description;

	alias description this;

}

struct aliases {

	string[] aliases;

	public this(string[] aliases...) {
		this.aliases = aliases;
	}

	alias aliases this;

}

struct params {

	string[] params;

	public this(string[] params...) {
		this.params = params;
	}

	alias params this;

}

enum op;

enum hidden;

struct task {

	tick_t interval=1;

	alias interval this;

}

/** Generic plugin exception */
class PluginException : Exception {

	public @safe @nogc this(string message, string file=__FILE__, size_t line=__LINE__) {
		super(message, file, line);
	}

}
