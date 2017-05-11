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
module sel.event.world.player;

import sel.format : Text;
import sel.block.block : Block;
import sel.entity.entity : Entity;
import sel.event.event : Cancellable;
import sel.event.world.damage : EntityDamageEvent;
import sel.event.world.entity : EntityDeathEvent;
import sel.event.world.world;
import sel.item : Slot, Item;
import sel.math.vector : BlockPosition, EntityPosition, ChunkPosition;
import sel.player.player : Player;
import sel.world.world : World;

/**
 * General player event
 * It can be listened by world and players
 */
interface PlayerEvent : WorldEvent {

	public pure nothrow @property @safe @nogc Player player();

	public static mixin template Implementation() {

		//mixin WorldEvent.Implementation;

		private Player n_player;

		public final override pure nothrow @property @safe @nogc Player player() {
			return this.n_player;
		}

		public final override pure nothrow @property @safe @nogc World world() {
			// override WorldEvent.Implementation to return World from Player.world
			return this.player.world;
		}

	}

}

/** General announce event */
abstract class PlayerAnnounceEvent : PlayerEvent {

	mixin PlayerEvent.Implementation;
	
	private string def;
	private string m_message;
	
	public @safe @nogc this(Player player, string message) {
		this.n_player = player;
		this.m_message = this.def = message;
	}
	
	public final pure nothrow @property @safe @nogc string message() {
		return this.m_message;
	}
	
	public final pure nothrow @property @safe @nogc string message(string message) {
		return this.m_message = message;
	}
	
	public final @property @safe string message(bool display) {
		if(display) this.m_message = this.def;
		else this.m_message = "";
		return this.m_message;
	}
	
	public final pure nothrow @property @safe @nogc bool announce() {
		return this.m_message.length > 0;
	}

	public final @property @safe bool announce(bool announce) {
		this.message = announce;
		return this.announce;
	}
	
}

/** Called when a player spawns, but it isn't spawned to the other entities/players yet */
final class PlayerSpawnEvent : PlayerAnnounceEvent {
	
	public bool spawn = true;
	
	public @safe this(Player player) {
		super(player, Text.yellow ~ "{connection.join}");
	}
	
}

/** Called when a player leaves the world, but it isn't despawned to the other entities/players yet */
final class PlayerDespawnEvent : PlayerAnnounceEvent {
	
	public @safe this(Player player) {
		super(player, Text.yellow ~ "{connection.left}");
	}
	
}

/** Called when the respawn button is clicked */
final class PlayerRespawnEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	public @safe @nogc this(Player player) {
		this.n_player = player;
	}

}

/**
 * Called when a player sends a chat message
 * Params:
 * 		message = the message sent
 * 		format = the message format
 * Example:
 * ---
 * public @event void chat(PlayerChatEvent event) {
 * 
 *    //<playername> message
 *    event.format = "<{0}> {1}";
 * 
 *    //playername: message
 *    event.format = "{0}: {1}";
 * 
 *    // replace bad words
 *    event.message = event.message.replace("fuck", "f**k");
 *    
 * }
 * ---
 */
final class PlayerChatEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	public static immutable string DEFAULT_FORMAT = "<{0}> {1}";
	
	public string message;
	public string format = DEFAULT_FORMAT;
	
	public @safe @nogc this(Player player, string message) {
		this.n_player = player;
		this.message = message;
	}
	
}

/**
 * Player movement, called when a player sends a movement packet
 * Params:
 * 		position = the new position
 * 		yaw, bodyYaw, pitch = the new rotation
 * 		rotation = true if the player has only moved the head
 */
final class PlayerMoveEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;
	
	private EntityPosition n_position;
	private float n_yaw, n_body_yaw, n_pitch;
	private bool mov_in_space = true;
	
	public @safe this(Player player, EntityPosition position, float yaw, float bodyYaw, float pitch) {
		this.n_player = player;
		this.n_position = position;
		this.n_yaw = yaw % 360;
		this.n_body_yaw = bodyYaw % 360;
		this.n_pitch = pitch < -90 ? -90 : (pitch > 90 ? 90 : pitch);
		if(player.position == position) {
			this.mov_in_space = false;
		}
	}
	
	public @property @safe @nogc EntityPosition position() {
		return this.n_position;
	}
	
	public @property @safe @nogc float yaw() {
		return this.n_yaw;
	}
	
	public @property @safe @nogc float bodyYaw() {
		return this.n_body_yaw;
	}
	
	public @property @safe @nogc float pitch() {
		return this.n_pitch;
	}
	
	public @property @safe @nogc bool rotation() {
		return !this.mov_in_space;
	}
	
	public @property @safe @nogc bool space() {
		return this.mov_in_space;
	}
	
}

/** Called when a player hits the jump button */
final class PlayerJumpEvent : PlayerEvent {

	mixin PlayerEvent.Implementation;
	
	public @safe @nogc this(Player player) {
		this.n_player = player;
	}
	
}

abstract class PlayerSprintingEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	public @safe @nogc this(Player player) {
		this.n_player = player;
	}

}

final class PlayerStartSprintingEvent : PlayerSprintingEvent {
	
	public @safe @nogc this(Player player) {
		super(player);
	}
	
}

final class PlayerStopSprintingEvent : PlayerSprintingEvent {
	
	public @safe @nogc this(Player player) {
		super(player);
	}
	
}

abstract class PlayerSneakingEvent : PlayerEvent, Cancellable {
	
	mixin Cancellable.Implementation;
	
	mixin PlayerEvent.Implementation;
	
	public @safe @nogc this(Player player) {
		this.n_player = player;
	}
	
}

final class PlayerStartSneakingEvent : PlayerSneakingEvent {
	
	public @safe @nogc this(Player player) {
		super(player);
	}
	
}

final class PlayerStopSneakingEvent : PlayerSneakingEvent {
	
	public @safe @nogc this(Player player) {
		super(player);
	}
	
}

final class PlayerDeathEvent : EntityDeathEvent, PlayerEvent {

	private Player n_player;

	public @safe @nogc this(Player player, EntityDamageEvent cause) {
		super(player, cause);
		this.message = true;
		this.n_player = player;
	}

	public override pure nothrow @property @safe @nogc Player player() {
		return this.n_player;
	}

}

final class PlayerAnimationEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;
	
	public @safe @nogc this(Player player) {
		this.n_player = player;
	}
	
}

final class PlayerUpdateViewDistanceEvent : PlayerEvent {

	mixin PlayerEvent.Implementation;
	
	private uint n_from;
	public uint to;
	
	public @safe @nogc this(Player player, uint from, uint to) {
		this.n_player = player;
		this.n_from = from;
		this.to = to;
	}
	
	public @property @safe @nogc uint from() {
		return this.n_from;
	}
	
}

final class PlayerNeedChunkEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	private ChunkPosition n_chunk;
	
	public @safe @nogc this(Player player, ChunkPosition chunk) {
		this.n_player = player;
		this.n_chunk = chunk;
	}
	
	public @property @safe @nogc ChunkPosition chunk() {
		return this.n_chunk;
	}
	
}

final class PlayerRequestMapEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	public immutable ushort mapId;

	public @safe @nogc this(Player player, ushort mapId) {
		this.n_player = player;
		this.mapId = mapId;
	}

}

final class PlayerAfterSpawnEvent : PlayerEvent {

	mixin PlayerEvent.Implementation;

	public @safe @nogc this(Player player) {
		this.n_player = player;
	}

}

final class PlayerAfterDespawnEvent : PlayerEvent {

	mixin PlayerEvent.Implementation;

	public @safe @nogc this(Player player) {
		this.n_player = player;
	}

}

final class PlayerBreakBlockEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	private Block n_block;
	private BlockPosition n_position;
	public bool drop = true;
	public bool consumeItem = true;
	public bool removeBlock = true;
	public bool particles = true;

	public @safe @nogc this(Player player, Block block, BlockPosition position) {
		this.n_player = player;
		this.n_block = block;
		this.n_position = position;
	}

	public @property @safe @nogc Block block() {
		return this.n_block;
	}

	public @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

}

final class PlayerPlaceBlockEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	private BlockPosition n_position;
	private Slot n_slot;
	public immutable uint face;

	public @safe @nogc this(Player player, Slot slot, BlockPosition position, uint face) {
		this.n_player = player;
		this.n_slot = slot;
		this.n_position = position;
		this.face = face;
	}

	public @property @safe @nogc Slot slot() {
		return this.n_slot;
	}

	public @property @safe @nogc Item item() {
		return this.n_slot.item;
	}

	public @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

}

/*class PlayerPickupEntityEvent : PlayerCancellableEvent {

	private Entity n_entity;

	public @safe @nogc this(Player player, Entity entity) {
		super(player);
		this.n_entity = entity;
	}

	public final @property @safe @nogc Entity entity() {
		return this.n_entity;
	}

}

final class PlayerPickupItemEvent : PlayerPickupEntityEvent {

	private Slot n_slot;

	public @safe @nogc this(Player player, ItemEntity item) {
		super(player, item);
		this.n_slot = item.slot;
	}

	public @property @safe @nogc Slot slot() {
		return this.n_slot;
	}

	public @property @safe @nogc Item item() {
		return this.n_slot.item;
	}

}*/

final class PlayerDropItemEvent : PlayerEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin PlayerEvent.Implementation;

	private Slot n_slot;

	public @safe @nogc this(Player player, Slot slot) {
		this.n_player = player;
		this.n_slot = slot;
	}

	public @property @safe @nogc Slot slot() {
		return this.n_slot;
	}

}
