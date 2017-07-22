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
module selery.plugin;

import selery.about;
import selery.util.tuple : Tuple;
import selery.server : Server;

/**
 * Informations about a plugin and registration-related
 * utilities.
 */
class Plugin {
	
	protected string n_namespace;
	protected string n_name;
	protected string[] n_authors;
	protected string n_version;
	protected bool n_api;
	public bool hasMain;

	protected string n_languages, n_textures;
	
	public void delegate()[] onstart, onreload, onstop;
	
	/**
	 * Gets the plugin's namespace that corresponds to the plugin's
	 * source code in plugins/<namespace> and the plugin's resources
	 * in resources/<namespace>.
	 */
	public pure nothrow @property @safe @nogc string namespace() {
		return this.n_namespace;
	}
	
	/**
	 * Gets the plugin's name as indicated in the plugin's
	 * package.json file.
	 */
	public pure nothrow @property @safe @nogc string name() {
		return this.n_name;
	}
	
	/**
	 * Gets the plugin's authors as indicated in the plugin's
	 * package.json file.
	 */
	public pure nothrow @property @safe @nogc string[] authors() {
		return this.n_authors;
	}
	
	/**
	 * Gets the plugin's version as indicated in the plugin's
	 * package.json file.
	 * This should be in major.minor[.revision] [alpha|beta] format.
	 */
	public pure nothrow @property @safe @nogc string vers() {
		return this.n_version;
	}
	
	/**
	 * Indicates whether or not the plugin has APIs.
	 * The plugin's APIs are always in the api.d file in
	 * the plugin's directory.
	 * Example:
	 * ---
	 * static if(__traits(compile, { import example.api; })) {
	 *    assert(server.plugins.filter!(a => a.namespace == "example")[0].api);
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool api() {
		return this.n_api;
	}

	/**
	 * Gets the absolute location of the plugin's language files.
	 * Returns: null if the plugin has no language files, a path otherwise
	 */
	public pure nothrow @property @safe @nogc string languages() {
		return this.n_languages;
	}

	/**
	 * Gets the absolute location of the plugin's textures.
	 * Returns: null if the plugin has no textures, a path otherwise
	 */
	public pure nothrow @property @safe @nogc string textures() {
		return this.n_textures;
	}
	
	public abstract void load(shared Server server);
	
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

// attributes for commands
alias command = Tuple!(string, "command");
alias aliases = Tuple!(string[], "aliases");
alias description = Tuple!(string, "description");
enum op;
enum hidden;

// attributes for tasks
struct task { tick_t interval; }

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
				static if(hasUDA!(F, description)) {
					enum d = getUDAs!(F, description)[0].description;
				} else {
					enum d = "";
				}
				string[] a;
				foreach(alias_ ; getUDAs!(F, aliases)) {
					a ~= alias_.aliases;
				}
				storage.registerCommand!F(mixin(del), getUDAs!(F, command)[0].command, d, a, hasUDA!(F, op), hasUDA!(F, hidden));
			}
			// tasks
			static if(tasks && hasUDA!(F, task) && (Parameters!F.length == 0 || Parameters!F.length == 1 && is(Parameters!F[0] : tick_t))) {
				storage.addTask(mixin(del), getUDAs!(F, task)[0].interval);
			}
		}
	}

}
