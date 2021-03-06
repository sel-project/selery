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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/plugin.d, selery/plugin.d)
 */
module selery.plugin;

import core.atomic : atomicOp;

import selery.about;
import selery.lang : Translatable;

private shared uint _id;

/**
 * Informations about a plugin and registration-related
 * utilities.
 */
class Plugin {

	public immutable uint id;

	/**
	 * Plugin's name as declared in plugin.toml.
	 */
	public immutable string name;

	/**
	 * Plugin's absolute path, used to load plugin'a assets.
	 */
	public immutable string path;

	/**
	 * Plugin's authors as declared in plugin.toml.
	 */
	public immutable string[] authors;

	/**
	 * Plugin's version.
	 */
	public immutable string version_;

	/**
	 * Indicates whether the plugin has a main class.
	 */
	public immutable bool main;
	
	public void delegate()[] onstart, onreload, onstop;

	public this(string name, string path, string[] authors, string version_, bool main) {
		assert(version_.length);
		this.id = atomicOp!"+="(_id, 1);
		this.name = name;
		this.path = path;
		this.authors = authors.idup;
		this.version_ = version_;
		this.main = main;
	}
	
}

// attributes for main classes
enum start;
enum reload;
enum stop;

// attributes for events
enum event;
enum global;
enum inherit;
enum cancel;

struct Description {

	enum : ubyte {

		EMPTY,
		TEXT,
		TRANSLATABLE

	}

	public ubyte type = EMPTY;

	union {

		string text;
		Translatable translatable;

	}

	this(string text) {
		this.type = TEXT;
		this.text = text;
	}

	this(Translatable translatable) {
		this.type = TRANSLATABLE;
		this.translatable = translatable;
	}

}

// attributes for commands
struct command {

	string command;
	string[] aliases;
	Description description;

	public this(string command, string[] aliases=[], Description description=Description.init) {
		this.command = command;
		this.aliases = aliases;
		this.description = description;
	}

	public this(string command, string[] aliases, string description) {
		this(command, aliases, Description(description));
	}

	public this(string command, string[] aliases, Translatable description) {
		this(command, aliases, Description(description));
	}

	public this(string command, string description) {
		this(command, [], description);
	}

	public this(string command, Translatable description) {
		this(command, [], description);
	}

}

struct permissionLevel { ubyte permissionLevel; }
enum op = permissionLevel(1);
struct permission { string[] permissions; this(string[] permissions...){ this.permissions = permissions; } }
alias permissions = permission;
enum hidden;
enum unimplemented;

void loadPluginAttributes(bool main, EventBase, GlobalEventBase, bool inheritance, CommandBase, bool tasks, T, S)(T class_, Plugin plugin, S storage) {

	enum bool events = !is(typeof(EventBase) == bool);
	enum bool globals = !is(typeof(GlobalEventBase) == bool);
	enum bool commands = !is(typeof(CommandBase) == bool);

	import std.traits : getSymbolsByUDA, hasUDA, getUDAs, Parameters;

	foreach(member ; __traits(allMembers, T)) {
		static if(is(typeof(__traits(getMember, T, member)) == function)) { //TODO must be public and not a template
			mixin("alias F = T." ~ member ~ ";");
			enum del = "&class_." ~ member;
			// start/stop
			static if(main) {
				static if(hasUDA!(F, start) && Parameters!F.length == 0) {
					plugin.onstart ~= mixin(del);
				}
				static if(hasUDA!(F, reload) && Parameters!F.length == 0) {
					plugin.onreload ~= mixin(del);
				}
				static if(hasUDA!(F, stop) && Parameters!F.length == 0) {
					plugin.onstop ~= mixin(del);
				}
			}
			// events
			enum isValid(E) = is(Parameters!F[0] == interface) || is(Parameters!F[0] : E);
			static if(events && Parameters!F.length == 1 && ((events && hasUDA!(F, event) && isValid!EventBase) || (globals && hasUDA!(F, global) && isValid!GlobalEventBase))) {
				static if(hasUDA!(F, cancel)) {
					//TODO event must be cancellable
					auto ev = delegate(Parameters!F[0] e){ e.cancel(); };
				} else {
					auto ev = mixin(del);
				}
				static if(events && hasUDA!(F, event)) {
					storage.addEventListener(ev);
				}
				static if(globals && hasUDA!(F, global)) {
					(cast()storage.globalListener).addEventListener(ev);
				}
			}
			// commands
			static if(commands && hasUDA!(F, command) && Parameters!F.length >= 1 && is(Parameters!F[0] : CommandBase)) {
				enum c = getUDAs!(F, command)[0];
				static if(hasUDA!(F, permissionLevel)) enum pl = getUDAs!(F, permissionLevel)[0].permissionLevel;
				else enum ubyte pl = 0;
				static if(hasUDA!(F, permission)) enum p = getUDAs!(F, permission)[0].permissions;
				else enum string[] p = [];
				storage.registerCommand!F(mixin(del), c.command, c.description, c.aliases, pl, p, hasUDA!(F, hidden), !hasUDA!(F, unimplemented));
			}
		}
	}

}
