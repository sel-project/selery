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
module sel.event.server.player;

import std.conv : to;

import common.sel : Software;

import sel.event.event : Cancellable;
import sel.event.server.server : ServerEvent;
import sel.player.player : Player;
import sel.world.world : World;

mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".player : Add, Remove;");

/**
 * Event called after the Player class for the now logged in player is created.
 * It's the first event called after the creation of the player, before PlayerPreSpawnEvent.
 * While this event is handled the client will see the "loading world" screen in its device,
 * waiting for the chunks that will be sent after PlayerPreSpawnEvent (that is called by
 * the world and every time a player changes world). That also means that this event
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
 * Event called when a player leaves the server, after PlayerDespawnEvent.
 * It's the last event called for the player, after it lefts the server, and
 * is only called once, like PlayerJoinEvent.
 * Example:
 * ---
 * @effect playerleft(PlayerLeftEvent ple) {
 *    assert(!ple.player.online);
 * }
 * ---
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
 * Event called when the player's language is updated (from the client or from
 * a plugin). The old and the new languages will always be one in the server's accepted
 * ones, as indicated in the hub's configuration file (accepted-languages field).
 * Example:
 * ---
 * @event changelanguage(PlayerChangeLanguageEvent pcle) {
 *    d(pcls.player.name, " is changing language from ", pcle.currentLanguage, " to ", pcle.newLanguage);
 * }
 * ---
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
