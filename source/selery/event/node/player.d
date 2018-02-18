/*
 * Copyright (c) 2017-2018 sel-project
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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/node/player.d, selery/event/node/player.d)
 */
module selery.event.node.player;

import std.conv : to;

import sel.hncom.player : Add, Remove;

import selery.about : Software;
import selery.event.event : Cancellable;
import selery.event.node.server : NodeServerEvent;
import selery.node.info : PlayerInfo, WorldInfo;
import selery.node.server : NodeServer;
import selery.player.player : Player;
import selery.world.world : World;

class PlayerEvent : NodeServerEvent {

	private const(PlayerInfo) _player;

	public pure nothrow @safe @nogc this(shared NodeServer server, inout PlayerInfo player) {
		super(server);
		this._player = player;
	}

	public final pure nothrow @property @safe @nogc const(PlayerInfo) player() {
		return this._player;
	}

}

/**
 * Event called after the Player class for the now logged in player is created.
 * It's the first event called after the creation of the player, before PlayerPreSpawnEvent.
 * While this event is handled the client will see the "loading world" screen in its device,
 * waiting for the chunks that will be sent after PlayerPreSpawnEvent (that is called by
 * the world and every time a player changes world). That also means that this event
 * will be called only once per player-session.
 */
final class PlayerJoinEvent : PlayerEvent {
	
	enum Reason : ubyte {
		
		firstJoin = Add.FIRST_JOIN,
		transferred = Add.TRANSFERRED,
		forciblyTransferred = Add.FORCIBLY_TRANSFERRED
		
	}

	private immutable ubyte _reason;

	public shared(WorldInfo) world;
	
	public pure nothrow @safe @nogc this(shared NodeServer server, inout PlayerInfo player, ubyte reason) {
		super(server, player);
		this._reason = reason;
	}

	public pure nothrow @property @safe @nogc ubyte reason() {
		return this._reason;
	}
	
}

/**
 * Event called when a player leaves the server, after PlayerDespawnEvent.
 * It's the last event called for the player, after it lefts the server, and
 * is only called once, like PlayerJoinEvent.
 * Example:
 * ---
 * @effect playerleft(PlayerLeftEvent event) {
 *    assert(!event.player.online);
 * }
 * ---
 */
final class PlayerLeftEvent : PlayerEvent {
	
	enum Reason : ubyte {
		
		left = Remove.LEFT,
		timedOut = Remove.TIMED_OUT,
		kicked = Remove.KICKED,
		transferred = Remove.TRANSFERRED
		
	}

	private immutable ubyte _reason;
	
	public pure nothrow @safe @nogc this(shared NodeServer server, inout PlayerInfo player, ubyte reason) {
		super(server, player);
		this._reason = reason;
	}
	
	public pure nothrow @property @safe @nogc ubyte reason() {
		return this._reason;
	}
	
}

/**
 * Event called when the player's language is updated (from the client or from
 * a plugin). The old and the new languages will always be one in the server's accepted
 * ones, as indicated in the hub's configuration file (accepted-languages field).
 * Example:
 * ---
 * @event changeLanguage(PlayerLanguageUpdatedEvent event) {
 *    log(event.player.name, " is changing language from ", event.currentLanguage, " to ", event.newLanguage);
 * }
 * ---
 */
final class PlayerLanguageUpdatedEvent : PlayerEvent, Cancellable {
	
	mixin Cancellable.Implementation;

	public immutable string oldLanguage;
	public immutable string newLanguage;
	
	public pure nothrow @safe @nogc this(shared NodeServer server, inout PlayerInfo player, string lang) {
		super(server, player);
		this.oldLanguage = player.language;
		this.newLanguage = lang;
	}
	
}

/**
 * Event called when the player's latency is updated from the hub.
 * Example:
 * ---
 * @event updateLatency(PlayerLatencyUpdatedEvent event) {
 *    event.player.title = event.latency.to!string ~ " ms";
 * }
 * ---
 */
final class PlayerLatencyUpdatedEvent : PlayerEvent {

	public pure nothrow @safe @nogc this(shared NodeServer server, inout PlayerInfo player) {
		super(server, player);
	}

	/**
	 * Gets the player's latency.
	 * Example:
	 * ---
	 * assert(event.latency == event.player.latency);
	 * ---
	 */
	public pure nothrow @property @safe @nogc uint latency() {
		return this.player.latency;
	}

}

/**
 * Event called when the player's packet loss is updated from the hub.
 * The packet loss is only calculated for players that use a connectionless
 * protocol like UDP (only Minecraft: Pocket Edition).
 * Example:
 * ---
 * @event updatePacketLoss(PlayerPacketLossUpdatedEvent event) {
 *    event.player.title = event.packetLoss.to!string ~ "%";
 *    assert(event.player.pe);
 * }
 * ---
 */
final class PlayerPacketLossUpdatedEvent : PlayerEvent {

	public pure nothrow @safe @nogc this(shared NodeServer server, inout PlayerInfo player) {
		super(server, player);
	}

	/**
	 * Gets the player's packet loss.
	 * Example:
	 * ---
	 * assert(event.packetLoss == event.player.packetLoss);
	 * ---
	 */
	public pure nothrow @property @safe @nogc float packetLoss() {
		return this.player.packetLoss;
	}

}
