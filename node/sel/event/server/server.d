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
/**
 * Events called on the server (and not on the world/entity). The functions marked
 * with @event in the plugin's main class will automatically be registered to the
 * server's event handler.
 * 
 * $(SERVER_EVENTS)
 * 
 * License: <a href="http://www.gnu.org/licenses/lgpl-3.0.html" target="_blank">GNU General Lesser Public License v3</a>
 * 
 * Macros:
 * 		SERVER_EVENTS = <b>Server events:</b> $(LINK2 #PlayerPreLoginEvent, PlayerPreLogin), $(LINK2 #PlayerJoinEvent, PlayerJoin), $(LINK2 #PlayerLeftEvent, PlayerLeft), $(LINK2 #PlayerChangeLanguageEvent, PlayerChangeLanguage), $(LINK2 #ServerCommandEvent, ServerCommand)
 *		VARS = <b>Variables:</b><table>$0</table>
 *		METHODS = <b>Methods:</b><table>$0</table>
 *		VAR = <tr><td>$1</td><td>$2</td>
 *		DESC = <td>$0</td></tr>
 */
module sel.event.server.server;

import std.conv : to;
import std.socket : Address;

import common.sel : Software;

import sel.player : Player, PlayerSoul;
import sel.event.event : Event, Cancellable;
import sel.world.world : World;

mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".player : Add, Remove;");
mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".generic : RemoteCommand;");

interface ServerEvent : Event {}

/**
 * $(SERVER_EVENTS)
 * 
 * Event dispatched when the player successfully logs in passing the
 * controls in the network layer.
 * This packet is commonly used to load data saved on files or in
 * the database by the plugins, only if the player will not be 
 * disconnected after this packet:
 * Example:
 * ---
 * @event prelogin(PlayerPreLoginEvent pple) {
 *    if(!pple.disconnect) {
 *       loadSomething(pple.iname);
 *    }
 * }
 * ---
 * 
 * $(VARS
 * 		$(VAR $(LINK2 sel.player.html#PlayerSoul, PlayerSoul), playerSoul)$(DESC player's information (like name, ip, ...))
 * 		$(VAR $(LINK2 sel.world.world.html#World, World), world)$(DESC world where the player will spawn)
 * 		$(VAR string|bool, disconnect)$(DESC disconnection message (true if not empty))
 * )
 */
final class PlayerPreLoginEvent : ServerEvent {

	enum Reason : ubyte {
		
		firstJoin = Add.FIRST_JOIN,
		transferred = Add.TRANSFERRED,
		forciblyTransferred = Add.FORCIBLY_TRANSFERRED
		
	}

	private PlayerSoul n_player;
	private ubyte n_reason;
	private World m_world;

	private bool m_disconnect;
	private string m_disconnect_reason;

	public @safe @nogc this(PlayerSoul player, ubyte reason) {
		this.n_player = player;
		this.n_reason = reason;
	}

	public pure nothrow @property @safe @nogc ref PlayerSoul player() {
		return this.n_player;
	}

	public pure nothrow @property @safe @nogc ubyte reason() {
		return this.n_reason;
	}

	public pure nothrow @property @safe @nogc World world() {
		return this.m_world;
	}

	public pure nothrow @property @safe @nogc World world(World world) {
		return this.m_world = world;
	}

	public pure nothrow @property @safe @nogc bool disconnect() {
		return this.m_disconnect;
	}

	public pure nothrow @property @safe @nogc bool disconnect(string reason) {
		this.m_disconnect_reason = reason;
		return this.m_disconnect = true;
	}

	public pure nothrow @property @safe bool disconnect(bool disconnect) {
		this.m_disconnect = disconnect;
		if(disconnect) {
			this.m_disconnect_reason = "disconnectionScreen.noReason";
		}
		return this.m_disconnect;
	}

	public pure nothrow @property @safe @nogc string disconnectReason() {
		return this.m_disconnect_reason;
	}

}

/**
 * $(SERVER_EVENTS)
 * 
 * Event dispatched after the Player class for the now logged in player is created.
 * It's the first event called after the creation of the player, before PlayerPreSpawnEvent.
 * While this event is handled the client will see the "loading world" screen in its device,
 * waiting for the chunks that will be sent after PlayerPreSpawnEvent (that is called by
 * the world and every time a player switches the world). That also means that this event
 * will be called only once per player-session.
 * Example:
 * ---
 * @event joinevent(PlayerJoinEvent pje) {
 *    assert(!pje.player.spawned);
 *    assert(pje.player.world !is null);
 *    assert(pje.player.online);
 *    assert(!in_array(pje.player, pje.player.world));
 * }
 * ---
 * 
 * $(VARS
 * 		$(VAR $(LINK2 sel.player.html#Player, Player), player)$(DESC the just-created player instance)
 * )
 */
final class PlayerJoinEvent : ServerEvent {

	enum Reason : ubyte {
		
		firstJoin = Add.FIRST_JOIN,
		transferred = Add.TRANSFERRED,
		forciblyTransferred = Add.FORCIBLY_TRANSFERRED
		
	}

	private Player n_player;
	private ubyte n_reason;

	public @safe @nogc this(Player player, ubyte reason) {
		this.n_player = player;
		this.n_reason = reason;
	}

	public pure nothrow @property @safe @nogc Player player() {
		return this.n_player;
	}

	public pure nothrow @property @safe @nogc ubyte reason() {
		return this.n_reason;
	}

}

/**
 * $(SERVER_EVENTS)
 * 
 * Event dispatched when a player leaves the server, after PlayerDespawnEvent.
 * It's the last event called for the player before disconnection, and is only called
 * once, like $(LINK2, #PlayerJoinEvent, PlayerJoin).
 * Example:
 * ---
 * @effect playerleft(PlayerLeftEvent ple) {
 *    assert(!ple.player.online);
 * }
 * ---
 * 
 * $(VARS
 * 		$(VAR $(LINK2 sel.player.html#Player, Player), player)$(DESC the player's instance)
 * )
 */
final class PlayerLeftEvent : ServerEvent {

	enum Reason : ubyte {

		left = Remove.LEFT,
		timedOut = Remove.TIMED_OUT,
		kicked = Remove.KICKED,
		transferred = Remove.TRANSFERRED

	}

	private Player n_player;
	private ubyte n_reason;

	public @safe @nogc this(Player player, ubyte reason) {
		this.n_player = player;
		this.n_reason = reason;
	}

	public pure nothrow @property @safe @nogc Player player() {
		return this.n_player;
	}

	public pure nothrow @property @safe @nogc ubyte reason() {
		return this.n_reason;
	}

}

/**
 * $(SERVER_EVENTS)
 * 
 * Event dispatched when the player's language is updated (from the client or from
 * a plugin). The old and the new languages will always be one in the server's accepted
 * ones, as indicated in the configuration file (available-languages field).
 * Example:
 * ---
 * @event changelanguage(PlayerChangeLanguageEvent pcle) {
 *    d(pcls.player.name, " is changing language from ", pcle.currentLanguage, " to ", pcle.newLanguage);
 * }
 * ---
 * 
 * $(VARS
 * 		$(VAR $(LINK2 sel.player.html#Player, Player), player)$(DESC the player who changed the language)
 * 		$(VAR immutable(string), currentLanguage)$(DESC the player's current language)
 * 		$(VAR immutable(string), newLanguage)$(DESC the new language choosen by player or assigned to it)
 * 		$(VAR bool, cancelled)$(DESC if true, the language will not be changed)
 * )
 * 
 * $(METHODS
 * 		$(VAR void, cancel)$(DESC cancel the event and prevent the changes)
 * )
 */
final class PlayerChangeLanguageEvent : ServerEvent, Cancellable {

	mixin Cancellable.Implementation;

	private Player n_player;
	public immutable string currentLanguage;
	public immutable string newLanguage;

	public @safe @nogc this(Player player, string lang) {
		this.n_player = player;
		this.currentLanguage = player.lang;
		this.newLanguage = lang;
	}

	public @property @safe @nogc Player player() {
		return this.n_player;
	}

}

/**
 * $(SERVER_EVENTS)
 * 
 * Event dispatched when the server sends a command (through the device's console or
 * the external console, if actived).
 * The input is splitted for every space character, the first element of the array
 * is set as command and the rest as the arguments.<br>
 * command = input.split(" ")[0]<br>
 * arguments = input.split(" ")[1..$]<br>
 * Example:
 * ---
 * @event servercommand(ServerCommandEvent sce) {
 *    if(sce.command == "say") {
 *       d("Server is trying to say \"", args.join(" "), "\"");
 *       sce.doDefault = false;
 *    }
 * }
 * ---
 * 
 * $(VARS
 * 		$(VAR string, command)$(DESC the command, always lowercase)
 * 		$(VAR immutable(string)[], args)$(DESC the arguments for the command, splitted in the space characters)
 * 		$(VAR bool, doDefault)$(DESC indicating whether or not the server should handle this command)
 * )
 */
final class ServerCommandEvent : ServerEvent, Cancellable {

	enum Origin : ubyte {

		prompt = 0,
		hub = RemoteCommand.HUB + 1,
		externalConsole = RemoteCommand.EXTERNAL_CONSOLE + 1,
		rcon = RemoteCommand.RCON + 1

	}

	mixin Cancellable.Implementation;

	private ubyte n_origin;
	private Address n_address;
	private string n_command;
	private immutable(string)[] n_args;

	public @safe @nogc this(ubyte origin, Address address, string command, immutable(string)[] args) {
		this.n_origin = origin;
		this.n_address = address;
		this.n_command = command;
		this.n_args = args;
	}

	public pure nothrow @property @safe @nogc ubyte origin() {
		return this.n_origin;
	}

	public pure nothrow @property @safe @nogc Address address() {
		return this.n_address;
	}

	public pure nothrow @property @safe @nogc string command() {
		return this.n_command;
	}

	public pure nothrow @property @safe @nogc immutable(string)[] args() {
		return this.n_args;
	}

}
