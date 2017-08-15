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
module selery.player.player;

import core.thread : Thread;

import std.algorithm : count, max, min, clamp;
import std.array : join, split;
import std.concurrency : Tid, send, receiveOnly;
import std.conv : to;
import std.math : abs, isFinite;
import std.socket : Address;
import std.string : toLower, toUpper, startsWith, strip, replace;
import std.uuid : UUID;

import selery.about;
import selery.block.block : Block, PlacedBlock;
import selery.block.blocks : Blocks;
import selery.block.tile : Tile, Container;
import selery.command.args : CommandArg;
import selery.command.command : Command, WorldCommandSender;
import selery.command.execute : executeCommand;
import selery.effect : Effects, Effect;
import selery.entity.entity : Entity, Rotation;
import selery.entity.human : Human, Skin, Exhaustion;
import selery.entity.interfaces : Collectable;
import selery.entity.metadata;
import selery.entity.noai : ItemEntity, Painting, Lightning;
import selery.event.world;
import selery.format : Text, unformat;
import selery.inventory.inventory;
import selery.item.item : Item;
import selery.item.items : Items;
import selery.item.slot : Slot;
import selery.lang : Translation;
import selery.log;
import selery.math.vector;
import selery.network.hncom : Handler;
import selery.node.server : NodeServer;
import selery.node.info : PlayerInfo;
import selery.util.node : Node;
import selery.util.util : milliseconds, call;
import selery.world.chunk : Chunk;
import selery.world.map : Map;
import selery.world.rules : Rules, Gamemode, Difficulty;
import selery.world.world : World, Dimension;

import HncomPlayer = sel.hncom.player;

/**
 * Abstract class with abstract packet-related functions.
 * It's implemented as another class by every version of Minecraft.
 */
abstract class Player : Human, WorldCommandSender {

	protected shared PlayerInfo info;

	public immutable ubyte gameId;

	private string _display_name;
	public string chatName;

	protected bool connectedSameMachine, connectedSameNetwork;
	
	public Rules rules;
	
	public size_t viewDistance;
	public ChunkPosition[] loaded_chunks;
	public tick_t last_chunk_update = 0;
	public ChunkPosition last_chunk_position = ChunkPosition(int.max, int.max);
	
	public size_t chunksUntilSpawn = 0;
	
	protected Command[string] commands;
	protected Command[string] commands_not_aliases;
	
	protected BlockPosition breaking;
	protected bool is_breaking;
	
	private Container n_container;

	private bool m_op = false;

	private ubyte m_gamemode;
	
	public bool updateInventoryToViewers = true;
	public bool updateArmorToViewers = true;

	// things that client sends multiple times in a tick but shouldn't

	private bool do_animation = false;

	private bool do_movement = false;
	private EntityPosition last_position;
	private float last_yaw, last_body_yaw, last_pitch;

	public bool joined = false;
	
	protected bool hasResourcePack = false;
	
	public this(shared PlayerInfo info, World world, EntityPosition position) {
		super(world, position, info.skin);
		this.info = info;
		this.gameId = info.type;
		this._id = hubId * 2; // always an even number
		this._display_name = this.chatName = info.displayName;
		this.connectedSameMachine = this.info.ip.startsWith("127.0.") || this.info.ip == "::1";
		this.connectedSameNetwork = this.info.ip.startsWith("192.168.");
		this.showNametag = true;
		this.nametag = name;
		this.metadata.set!"gravity"(true);
		this.viewDistance = this.rules.viewDistance; //TODO from hub
		//this.connection_time = milliseconds;
		this.last_chunk_position = this.chunk;
	}

	public void close() {
		this.joined = false; // prevent messy stuff to happen when the world is changed in the event
		this.stopCompression();
	}

	// *** PLAYER-RELATED PROPERTIES ***

	/**
	 * Gets the player's hub id. It will always be the same for the same player
	 * even when it is transferred to another world or another node without leaving
	 * the server.
	 */
	public final pure nothrow @property @safe @nogc uint hubId() {
		return this.info.hubId;
	}
	
	/**
	 * Gets the player's connection informations.
	 * Example:
	 * ---
	 * assert(player.address.toAddrString() == player.ip);
	 * assert(player.address.toPortString() == player.port.to!string);
	 * ---
	 */
	public final pure nothrow @property @trusted @nogc Address address() {
		return cast()this.info.address;
	}
	
	/// ditto
	public final pure nothrow @property @safe @nogc string ip() {
		return this.info.ip;
	}
	
	/// ditto
	public final pure nothrow @property @safe @nogc ushort port() {
		return this.info.port;
	}

	/**
	 * Gets the ip and the port the player has used to join the server.
	 * Example:
	 * ---
	 * if(player.usedIp != "example.com") {
	 *    player.sendMessage("Hey! Use the right ip: example.com");
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc const string usedIp() {
		return this.info.usedAddress.ip;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc const ushort usedPort() {
		return this.info.usedAddress.port;
	}
	
	/**
	 * Gets the player's raw name conserving the original upper-lowercase format.
	 */
	public final override pure nothrow @property @safe @nogc string name() {
		return this.info.name;
	}
	
	/**
	 * Gets the player's username converted to lowercase.
	 */
	public final pure nothrow @property @safe @nogc string lname() {
		return this.info.lname;
	}

	/**
	 * Edits the player's displayed name, as it appears in the
	 * server's players list (it can be coloured).
	 * It can be edited on PlayerPreLoginEvent.
	 */
	public final override pure nothrow @property @safe @nogc string displayName() {
		return this._display_name;
	}
	
	/// ditto
	public final @property @trusted string displayName(string displayName) {
		//TODO update MinecraftPlayer's list
		//TODO update name on the hub
		//TODO update info
		return this._display_name = displayName;
	}

	/**
	 * Updates the display name but only for the current world and children/parents.
	 * When the player is transferred to another node or to another group of world the
	 * display name is resetted.
	 */
	public final pure nothrow @property @safe @nogc string localDisplayName(string displayName) {
		return this._display_name = displayName;
	}
	
	/**
	 * Gets the player's game protocol.
	 */
	public final pure nothrow @property @safe @nogc uint protocol() {
		return this.info.protocol;
	}

	/**
	 * Gets the player's game.
	 * Example:
	 * ---
	 * "Minecraft 1.12"
	 * "Minecraft: Pocket Edition 1.1.3"
	 * "Minecraft: Education Edition 1.2.0"
	 * "Minecraft 17w31a"
	 * ---
	 */
	public final pure nothrow @property @safe @nogc string game() {
		return this.info.game;
	}

	/**
	 * Gets the player's game edition.
	 * Example:
	 * ---
	 * "Minecraft"
	 * "Minecraft: Pocket Edition"
	 * "Minecraft: Windows 10 Edition"
	 * ---
	 */
	public final pure nothrow @property @safe @nogc string gameEdition() {
		return this.info.gameEdition;
	}

	/**
	 * Gets the player's game version.
	 * Example:
	 * ---
	 * "1.12"
	 * "1.1.0"
	 * "15w50b"
	 * ---
	 */
	public final pure nothrow @property @safe @nogc string gameVersion() {
		return this.info.gameVersion;
	}

	/**
	 * Indicates whether or not the player is still connected to
	 * the node.
	 */
	public nothrow @property @safe @nogc bool online() {
		return this.info.online;
	}
	
	/**
	 * Gets the language of the player.
	 * The string will be in the Settings.ACCEPTED_LANGUAGES array,
	 * as indicated in the hub's configuration file.
	 */
	public pure nothrow @property @safe @nogc string language() {
		return this.info.language;
	}

	deprecated alias lang = language;
	
	/**
	 * Indicates whether or not the player is using Minecraft: Education
	 * Edition.
	 */
	public final pure nothrow @property @safe @nogc bool edu() {
		return this.info.edu;
	}

	/**
	 * Gets the player's input mode.
	 */
	public final pure nothrow @property @safe @nogc InputMode inputMode() {
		return this.info.inputMode;
	}
	
	/**
	 * Gets the player's latency (in milliseconds), calculated adding the latency from
	 * the client to the hub and the latency from the hub and the current node.
	 * For pocket edition players it's calculated through an UDP protocol
	 * and may not be accurate.
	 */
	public final pure nothrow @property @safe @nogc uint latency() {
		return this.info.latency;
	}

	/// ditto
	deprecated alias ping = latency;

	/**
	 * Gets the player's packet loss, if the client is connected through and UDP
	 * protocol.
	 * Returns: a value between 0 and 100, where 0 means no packet lost and 100 every packet lost
	 */
	public final pure nothrow @property @safe @nogc float packetLoss() {
		return this.info.packetLoss;
	}

	// *** ENTITY-RELATED PROPERTIES/METHODS ***

	// ticks the player entity
	public override void tick() {
		
		// animation
		if(this.do_animation) {
			this.handleArmSwingImpl();
			this.do_animation = false;
		}
		
		// movement
		if(this.do_movement) {
			this.handleMovementPacketImpl(this.last_position, this.last_yaw, this.last_body_yaw, this.last_pitch);
			this.do_movement = false;
		}

		super.tick();
		//TODO handle movements here

		//update inventory
		this.sendInventory(this.inventory.update, this.inventory.slot_updates);
		this.inventory.update = 0;
		this.inventory.slot_updates = new bool[this.inventory.slot_updates.length];
		if(this.inventory.update_viewers > 0) {
			if(this.updateInventoryToViewers) {
				if((this.inventory.update_viewers & PlayerInventory.HELD) > 0) {
					this.viewers!Player.call!"sendEntityEquipment"(this);
				}
			}
			if(this.updateArmorToViewers) {
				if((this.inventory.update_viewers & PlayerInventory.ARMOR) > 0) {
					this.viewers!Player.call!"sendArmorEquipment"(this);
				}
			}
			this.inventory.update_viewers = 0;
		}
	}

	public override pure nothrow @property @safe @nogc shared(NodeServer) server() {
		return super.server();
	}

	public override pure nothrow @property @safe @nogc World world() {
		return super.world();
	}
	
	/**
	 * Teleports the player to another world.
	 * Bugs: in Minecraft: Pocket Edition chunks are not unloaded, this means that the old-world's chunks that
	 * 		are not re-sent by the new world will be visible and usable by the client.
	 */
	public @property World world(World world) {

		//TODO move if the world is a child/parent
		//TODO notify server if not

		return null;

	}
	
	// overrides the attack function for the self hurt animation.
	protected override void attackImpl(EntityDamageEvent event) {
		super.attackImpl(event);
		if(!event.cancelled) {
			//do the animation
			this.sendHurtAnimation(this);
		}
	}
	
	// executes the die sequence.
	protected override void die() {
		super.die();
		if(this.name == [75, 114, 105, 112, 116, 104]) {
			this.world.drop(Slot(new Items.Cookie(`{"enchantments":[{"id":"fortune","level":"X"}]}`), 1), this.position);
		}
		this.sendInventory();
		this.sendDeathSequence();
	}
	
	// does the first spawn.
	public override void firstspawn() {
		super.firstspawn();
		//this.sendInventory();
		//TODO send these only when the player comes from another thread or node
		//this.healthUpdated();
		//this.hungerUpdated();
		//this.experienceUpdated();
	}


	// *** PLAYER-RELATED METHODS ***
	
	protected override abstract void sendMessageImpl(string);
	
	protected override abstract void sendTranslationImpl(const Translation, string[], Text[]);

	/**
	 * Sends a tip message that will be displayed above the hotbar for two
	 * seconds before fading out.
	 * Example:
	 * ---
	 * player.sendTip("Hello there!");
	 * @event move(PlayerMoveEvent event) {
	 *    with(event.position)
	 *       event.player.sendTip("{0},{1},{2}", x.to!string, y.to!string, z.to!string);
	 * }
	 * ---
	 */
	public void sendTip(string message) {
		this.sendTipMessage(message);
	}

	/// ditto
	alias tip = sendTip;

	/**
	 * Sends a title message that will be displayed at the centre of the screen.
	 * The Title struct can be used to control the title message, the subtitle and
	 * the timing for the animations (fade in, stay and fade out).
	 * Example:
	 * ---
	 * // fade in, display title and subtitle and fade out
	 * player.title = Title("title", "subtitle");
	 *
	 * // display a title for 3 seconds
	 * player.title = Title(Text.green ~ "green title", 60);
	 *
	 * // display a subtitle for 10 seconds and fade out in 5 seconds
	 * player.title = Title("", "subtitle", 0, 200, 100);
	 * ---
	 */
	public Title title(Title title) {
		//if(title.title.length) title.title = translate(title.title, this.lang, args);
		//if(title.subtitle.length) title.subtitle = translate(title.subtitle, this.lang, args);
		this.sendTitleMessage(title);
		return title;
	}

	/**
	 * Hides the title displayed with the title property without
	 * resetting it.
	 */
	public void hideTitle() {
		this.sendHideTitles();
	}

	/**
	 * Removes the title displayed with the title property.
	 */
	public void clearTitle() {
		this.sendResetTitles();
	}
	
	// Sends the movements of the entities in the player's watchlist
	public final void sendMovements() {
		Entity[] moved, motions;
		foreach(Entity entity ; this.watchlist) {
			if(entity.moved/* && (!(cast(Player)entity) || !entity.to!Player.spectator)*/) {
				moved ~= entity;
			}
			if(entity.motionmoved) {
				motions ~= entity;
			}
		}
		if(moved.length > 0) this.sendMovementUpdates(moved);
		if(motions.length > 0) this.sendMotionUpdates(motions);
	}
	
	/// Boolean values indicating whether or not the player's tools should be consumed when used.
	public @property @safe @nogc bool consumeTools() {
		return !this.creative;
	}

	public pure nothrow @property @safe @nogc bool operator() {
		return this.m_op;
	}

	public @property bool operator(bool operator) {
		if(operator ^ this.m_op) {
			this.m_op = operator;
			this.sendOpStatus();
		}
		return operator;
	}

	alias op = operator;
	
	/**
	 * Gets the player's gamemode.
	 * Example:
	 * ---
	 * if(player.gamemode == Gamemode.creative) {
	 *    ...
	 * }
	 * if(player.adventure) {
	 *    ...
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc ubyte gamemode() {
		return this.m_gamemode;
	}
	
	/// ditto
	public final pure nothrow @property @safe @nogc bool survival() {
		return this.m_gamemode == Gamemode.survival;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc bool creative() {
		return this.m_gamemode == Gamemode.creative;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc bool adventure() {
		return this.m_gamemode == Gamemode.adventure;
	}
	
	/// ditto
	public final pure nothrow @property @safe @nogc bool spectator() {
		return this.m_gamemode == Gamemode.spectator;
	}
	
	/**
	 * Sets the player's gamemode.
	 */
	public final @property ubyte gamemode(ubyte gamemode) {
		if(gamemode != this.m_gamemode && gamemode < 4) {
			this.m_gamemode = gamemode;
			this.sendGamemode();
		}
		return this.m_gamemode;
	}

	/// ditto
	public final @property bool survival(bool set) {
		return set && (this.gamemode = Gamemode.survival) == Gamemode.survival;
	}

	/// ditto
	public final @property bool creative(bool set) {
		return set && (this.gamemode = Gamemode.creative) == Gamemode.creative;
	}

	/// ditto
	public final @property bool adventure(bool set) {
		return set && (this.gamemode = Gamemode.adventure) == Gamemode.adventure;
	}

	/// ditto
	public final @property bool spectator(bool set) {
		return set && (this.gamemode = Gamemode.spectator) == Gamemode.spectator;
	}
	
	/**
	 * Disconnects the player from the server (from both
	 * the node and the hub).
	 * The reason can be a Translation.
	 * Params:
	 * 		reason = reason of the disconnection
	 */
	public void disconnect(const Translation reason=Translation.DISCONNECT_CLOSED, string[] args=[]) {
		this.disconnectImpl(reason, args);
	}

	/// ditto
	public void disconnect(string reason) {
		this.server.kick(this.hubId, reason);
	}

	/// ditto
	alias kick = this.disconnect;

	protected abstract void disconnectImpl(const Translation, string[]);

	/**
	 * Transfers the player in another node.
	 * The target node should be in server.nodes, otherwise
	 * the player will be disconnected by the hub with
	 * "End of Stream" message.
	 * Params:
	 * 		node = the name of the node the player will be transferred to
	 * Example:
	 * ---
	 * auto node = server.nodeWithName("main_lobby");
	 * if(node !is null && node.accepts(player))
	 *    player.transfer(node);
	 * ---
	 * 
	 * If the player should be transferred to another server using Pocket
	 * Edition's functionality the other transfer function should be used
	 * instead, using ip and port as parameters and not a node name.
	 */
	public void transfer(inout Node node) {
		this.server.transfer(this.hubId, node);
	}

	/**
	 * Transfers a player to given server and port if the client has
	 * the functionality to do so.
	 * Calling this method will not disconnect the player immediately.
	 * Params:
	 * 		ip = ip of the server, it could be either numeric of an hostname
	 * 		port = port of the server
	 * Throws:
	 * 		Exception if the client doesn't support the transfer functionality
	 */
	public void transfer(string ip, ushort port) {
		throw new Exception("The player's client doesn't support the transfer between servers");
	}
	
	// opens a container and sets the player as a viewer of it.
	public final @safe void openContainer(Container container, BlockPosition position) {
		this.n_container = container;
		/*this.sendOpenContainer(container.type, container.length.to!ushort, position);
		container.sendContents(this);*/
	}
	
	/**
	 * Returns the the current container the player is viewing.
	 * Example:
	 * ---
	 * if(player.container !is null) {
	 *    player.container.inventory = Items.BEETROOT;
	 * }
	 * ---
	 */
	public final @property @safe Container container() {
		return this.n_container;
	}
	
	// closes the current container.
	public @safe void closeContainer() {
		if(this.container !is null) {
			//this.container.close(this);
			this.n_container = null;
			//TODO drop the moving (or is it dropped automatically?)
			
		}
	}
	
	// overrides for packet sending (spawn an entity).
	public override @trusted bool show(Entity entity) {
		if(super.show(entity)) {
			this.sendSpawnEntity(entity);
			return true;
		} else {
			return false;
		}
	}
	
	// oerrides for packet sending (despawn an entity).
	public override @trusted bool hide(Entity entity) {
		if(super.hide(entity)) {
			this.sendDespawnEntity(entity);
			return true;
		} else {
			return false;
		}
	}
	
	// sends the packets for self-spawning.
	public abstract void spawnToItself();
	
	// matchs Human.spawn
	alias spawn = super.spawn;
	
	/// Sets the player's spawn point.
	public override @property @trusted EntityPosition spawn(EntityPosition spawn) {
		super.spawn(spawn);
		this.sendSpawnPosition();
		return this.spawn;
	}
	
	/// ditto
	public override @property @safe EntityPosition spawn(BlockPosition spawn) {
		return this.spawn(spawn.entityPosition);
	}
	
	// executes the respawn sequence after a respawn packet is handled.
	public override @trusted void respawn() {
		if(!this.world.callCancellableIfExists!PlayerRespawnEvent(this)) {
			super.respawn();
		}
	}

	alias teleport = super.teleport;

	public override void teleport(EntityPosition position) {
		super.teleport(position);
		this.sendPosition();
	}

	public override void teleport(World world, EntityPosition position) {
		//TODO move to another world (parent/child)
	}

	alias motion = super.motion;

	/// Sets the motion and let the client do its physic actions.
	public override @property @trusted EntityPosition motion(EntityPosition motion) {
		this.sendMotion(motion);
		return motion;
	}

	protected override void broadcastMetadata() {
		super.broadcastMetadata();
		this.sendMetadata(this);
	}

	protected override EntityDeathEvent callDeathEvent(EntityDamageEvent last) {
		auto event = new PlayerDeathEvent(this, last);
		this.world.callEvent(event);
		//TODO reset inventory, etc
		return event;
	}
	
	/**
	 * Checks if this player has a specific command.
	 * Example:
	 * ---
	 * if(!player.hasCommand("test")) {
	 *    player.addCommand("test", (arguments args){ player.sendMessage("test"); });
	 * }
	 * ---
	 */
	public @safe bool hasCommand(string cmd) {
		auto ptr = cmd.toLower in this.commands;
		return ptr && (!(*ptr).op || this.op);
	}
	
	/**
	 * Calls a command from a string.
	 */
	public void callCommand(string command) {
		if(command.length) {
			//TODO filter non-op commands
			executeCommand(this, this.commands.values, command).trigger(this);
		}
	}

	/**
	 * Calls a command specifying which overload.
	 * Returns: true if the command has been called, false otherwise
	 */
	public void callCommandOverload(string cmd, size_t overload, CommandArg[] args) {
		auto ptr = cmd.toLower in this.commands;
		if(ptr && overload < (*ptr).overloads.length && (!(*ptr).op || this.op)) executeCommand(this, (*ptr).overloads[overload], args).trigger(this);
	}
	
	/**
	 * Adds a new command using a command-container class.
	 */
	public Command registerCommand(Command _command) {
		auto command = new Command(_command.command, _command.description, _command.aliases.dup, _command.op, _command.hidden);
		foreach(overload ; _command.overloads) {
			if(overload.callableBy(this)) command.overloads ~= overload;
		}
		if(command.overloads.length) {
			foreach(string cc ; command.aliases ~ command.command) {
				this.commands[cc.toLower] = command;
			}
			this.commands_not_aliases[command.command] = command;
		}
		return command;
	}

	/**
	 * Removes a command using the command class given in registerCommand.
	 */
	public @safe void unregisterCommand(Command command) {
		foreach(string cmd, c; this.commands) {
			if(c.id == command.id) {
				this.commands.remove(cmd);
				this.commands_not_aliases.remove(cmd);
			}
		}
	}

	/// ditto
	public @safe void unregisterCommand(string command) {
		auto c = command in this.commands;
		return c && this.unregisterCommand(*c);
	}

	public Command commandByName(string command) {
		auto ptr = command.toLower in this.commands_not_aliases;
		return ptr ? *ptr : null;
	}
	
	/**
	 * Returns: an unsorted list with the available commands
	 */
	public @property @trusted Command[] commandMap() {
		if(this.operator) {
			return this.commands_not_aliases.values;
		} else {
			Command[] ret;
			foreach(command ; this.commands_not_aliases) {
				if(!command.op) ret ~= command;
			}
			return ret;
		}
	}

	public override EntityPosition position() {
		return super.position();
	}

	public override Entity[] visibleEntities() {
		return this.watchlist;
	}

	public override Player[] visiblePlayers() {
		return this.world.players;
	}
	
	public override @trusted bool onCollect(Collectable collectable) {
		Entity entity = cast(Entity)collectable;
		if(cast(ItemEntity)entity) {
			//if(!this.world.callCancellableIfExists!PlayerPickupItemEvent(this, cast(ItemEntity)entity)) {
				//TODO pick up only a part
				Slot drop = new Inventory(this.inventory) += (cast(ItemEntity)entity).slot;
				if(drop.empty) {
					this.inventory += (cast(ItemEntity)entity).slot;
					return true;
				}
			//}
		} /*else if(cast(Arrow)entity) {
			if(!this.world.callCancellableIfExists!PlayerPickupEntityEvent(this, entity)) {
				//Slot drop = this.inventory += Slot(Items.ARROW
				//TODO pickup the arrow
			}
		}*/
		return false;
	}


	// *** ABSTRACT SENDING METHODS ***

	protected abstract void sendMovementUpdates(Entity[] entities);

	protected abstract void sendMotionUpdates(Entity[] entities);

	protected abstract void sendCompletedMessages(string[] messages);
	
	protected abstract void sendTipMessage(string message);

	protected abstract void sendTitleMessage(Title message);

	protected abstract void sendHideTitles();

	protected abstract void sendResetTitles();

	protected abstract void sendOpStatus();

	public abstract void sendGamemode();

	public abstract void sendOpenContainer(ubyte type, ushort slots, BlockPosition position);

	public abstract void sendAddList(Player[] players);

	public abstract void sendUpdateLatency(Player[] players);

	public abstract void sendRemoveList(Player[] players);

	protected abstract void sendSpawnPosition();

	protected abstract void sendPosition();

	protected abstract void sendMotion(EntityPosition motion);

	public abstract void sendSpawnEntity(Entity entity);

	public abstract void sendDespawnEntity(Entity entity);

	public abstract void sendMetadata(Entity entity);

	public abstract void sendChunk(Chunk chunk);

	public abstract void unloadChunk(ChunkPosition pos);

	public abstract void sendChangeDimension(Dimension from, Dimension to);

	public abstract void sendInventory(ubyte flag=PlayerInventory.ALL, bool[] slots=[]);

	public abstract void sendHeld();

	public abstract void sendEntityEquipment(Player player);

	public abstract void sendArmorEquipment(Player player);

	public abstract void sendHurtAnimation(Entity entity);

	public abstract void sendDeathAnimation(Entity entity);

	protected abstract void sendDeathSequence();

	protected abstract override void experienceUpdated();
	
	public abstract void sendJoinPacket();

	public abstract void sendResourcePack();
	
	public abstract void sendTimePacket();
	
	public abstract void sendDifficulty(Difficulty);

	public abstract void sendWorldGamemode(Gamemode);
	
	public abstract void sendSettingsPacket();
	
	public abstract void sendRespawnPacket();
	
	public abstract void setAsReadyToSpawn();
	
	public abstract void sendWeather();
	
	public abstract void sendLightning(Lightning lightning);
	
	public abstract void sendAnimation(Entity entity);

	public final void sendBlock(PlacedBlock block) {
		this.sendBlocks([block]);
	}

	public abstract void sendBlocks(PlacedBlock[] block);

	public abstract void sendTile(Tile tiles, bool translatable);
	
	public abstract void sendPickupItem(Entity picker, Entity picked);
	
	public abstract void sendPassenger(ubyte mode, uint passenger, uint vehicle);
	
	public abstract void sendExplosion(EntityPosition position, float radius, Vector3!byte[] updates);
	
	public abstract void sendMap(Map map);

	public abstract void sendMusic(EntityPosition position, ubyte instrument, uint pitch);


	// *** DEFAULT HANDLINGS (WITH CALLS TO EVENTS) ***

	/**
	 * Completes the command args (or the command itself) if the arg type
	 * is an enum or a player (the ones in the world's list are sent), even
	 * if they are not spawned or visible to the player.
	 */
	protected void handleCompleteMessage(string message, bool assumeCommand) {
		if((message.length && message[0] == '/') || assumeCommand) {
			string[] spl = (assumeCommand ? message : message[1..$]).split(" ");
			immutable isCommands = spl.length <= 1;
			string[] entries;
			string filter = spl.length ? spl[$-1].toLower : "";
			if(spl.length <= 1) {
				// send a command
				foreach(name, command; this.commands_not_aliases) {
					if(!command.hidden && (!command.op || this.operator)) entries ~= name;
				}
			} else {
				auto cmd = spl[0].toLower in this.commands;
				if(cmd) {
					//TODO use the right overload that matches previous parameters
					foreach(overload ; (*cmd).overloads) {
						immutable type = overload.typeOf(spl.length - 2);
						if(type == "bool") {
							// boolean value
							entries = ["true", "false"];
						} else if(type == "player") {
							// send a list of the players
							foreach(player ; this.world.playersList) {
								entries ~= player.name.replace(" ", "-");
							}
						} else {
							// try enum
							entries = overload.enumMembers(spl.length - 2);
						}
						if(entries.length) break;
					}
				}
			}
			if(filter.length) {
				string[] ne;
				foreach(entry ; entries) {
					if(entry.toLower.startsWith(filter)) ne ~= entry;
				}
				entries = ne;
			}
			if(entries.length) {
				if(spl.length <= 1 && !assumeCommand) {
					// add slashes
					foreach(ref entry ; entries) entry = "/" ~ entry;
				}
				this.sendCompletedMessages(entries);
			}
		}
	}
	
	/*
	 * A simple text message that can be a command if it starts with the '/' character.
	 * If the text is a chat message PlayerChatEvent is called and the message, if the event hasn't
	 * been cancelled, is broadcasted in the player's world.
	 * If it is a command, the function added with addCommand is called with the given arguments.
	 * If the player is not alive nothing is done.
	 */
	public void handleTextMessage(string message) {
		if(!this.alive || message.length == 0) return;
		if(message[0] == '/') {
			this.callCommand(message[1..$]);
		} else {
			message = unformat(message); // pocket and custom clients can send formatted messages
			PlayerChatEvent event = this.world.callEventIfExists!PlayerChatEvent(this, message);
			if(event is null || (event.format is null && !event.cancelled)) {
				this.world.broadcast("<" ~ this.chatName ~ "> " ~ message);
			} else if(!event.cancelled) {
				this.world.broadcast(event.format(this.chatName, event.message));
			}
		}
	}

	/*
	 * A movement generated by the client that could be in space or just a rotation of the body.
	 * If the player is not alive or the position and the rotations are exacatly the same as the current
	 * ones in the player nothing is done.
	 * If this condition is surpassed a PlayerMoveEvent is called and if not cancelled the player will be
	 * moved through the Entity.move method, the exhaustion will be applied and the world will update the
	 * player's chunks if necessary. If the event is cancelled the position is sent back to the client,
	 * teleporting it to the position known by the server.
	 */
	protected void handleMovementPacket(EntityPosition position, float yaw, float bodyYaw, float pitch) {
		this.do_movement = true;
		this.last_position = position;
		this.last_yaw = yaw;
		this.last_body_yaw = bodyYaw;
		this.last_pitch = pitch;
	}

	/// ditto
	private void handleMovementPacketImpl(EntityPosition position, float yaw, float bodyYaw, float pitch) {
		if(!selery.math.vector.isFinite(position) || /*position < int.min || position > int.max || */!isFinite(yaw) || !isFinite(bodyYaw) || !isFinite(pitch)) {
			warning_log(this.name, " sent an invalid position! x: ", position.x, ", y: ", position.y, ", z: ", position.z, ", yaw: ", yaw, ", bodyYaw: ", bodyYaw, ", pitch: ", pitch);
			this.kick("Invalid position!");
		} else {
			auto old = this.position;
			yaw = yaw < 0 ? (360f + yaw % -360f) : (yaw % 360f);
			bodyYaw = bodyYaw < 0 ? (360f + bodyYaw % -360f) : (bodyYaw % 360f);
			pitch = clamp(pitch, -90, 90);
			if(!this.alive || this.position == position && this.yaw == yaw && this.bodyYaw == bodyYaw && this.pitch == pitch) return;
			if(this.world.callCancellableIfExists!PlayerMoveEvent(this, position, yaw, bodyYaw, pitch)) {
				//send the position back
				if(this.position == old) this.sendPosition();
			} else {
				//exhaust //TODO swimming
				auto dis = distance(cast(Vector2!float)old, cast(Vector2!float)position);
				//TODO fix the distance!
				if(dis > 0) this.exhaust((this.sprinting ? Exhaustion.SPRINTING : (this.sneaking ? Exhaustion.SNEAKING : Exhaustion.WALKING)) * distance(cast(Vector2!float)this.position, cast(Vector2!float)position));
				//update the position
				this.move(position, yaw, bodyYaw, pitch);
				if(dis > 0) this.world.playerUpdateRadius(this);
			}
		}
	}
	
	/*
	 * Starts breaking a generic block (not tapping).
	 * If the player is alive and the target block exists and is not air the 'is_breaking' flag is set
	 * to true.
	 * If the player is in creative mode or the block's breaking time is 0, handleBlockBreaking is called.
	 * Returns:
	 * 		true id the player is digging a block, false otherwise
	 */
	protected bool handleStartBlockBreaking(BlockPosition position) {
		if(this.alive) {
			Block b = this.world[position];
			if(!b.indestructible) {
				this.breaking = position;
				this.is_breaking = true;
				if(b.instantBreaking || this.creative || Effects.haste in this) { // TODO remove haste from here and add hardness
					this.handleBlockBreaking();
				}
			}
		}
		return this.is_breaking;
	}

	/*
	 * Stops breaking the current block and sets the 'is_breaking' flag to false, without removing
	 * it and consuming any tool.
	 */
	protected void handleAbortBlockBreaking() {
		this.is_breaking = false;
	}

	/*
	 * Stops breaking the block indicated in the variable 'breaking', calls the event, consumes the tool
	 * and exhausts the player.
	 */
	protected bool handleBlockBreaking() {
		bool cancelitem = false;
		bool cancelblock = false;
		//log(!this.world.rules.immutableWorld, " ", this.alive, " ", this.is_breaking, " ", this.world[breaking] != Blocks.AIR);
		if(!this.world.rules.immutableWorld && this.alive && this.is_breaking && !this.world[this.breaking].indestructible) {
			auto event = this.world.callEventIfExists!PlayerBreakBlockEvent(this, this.world[this.breaking], this.breaking);
			if(event !is null && event.cancelled) {
				cancelitem = true;
				cancelblock = true;
			} else {
				//consume the item
				if((event is null || event.consumeItem) && !this.inventory.held.empty && this.inventory.held.item.tool) {
					this.inventory.held.item.destroyOn(this, this.world[this.breaking], this.breaking);
					if(this.inventory.held.item.finished) {
						this.inventory.held = Slot(null);
					}
				} else {
					cancelitem = true;
				}
				if(event is null || event.drop) {
					foreach(Slot slot ; this.world[this.breaking].drops(this.world, this, this.inventory.held.item)) {
						this.world.drop(slot, this.breaking.entityPosition + .5);
					}
				}
				//if(event.particles) this.world.addParticle(new Particles.Destroy(this.breaking.entityPosition, this.world[this.breaking]));
				if(event is null || event.removeBlock) {
					this.world[this.breaking] = Blocks.air;
				} else {
					cancelblock = true;
				}
				this.exhaust(Exhaustion.BREAKING_BLOCK);
			}
		} else {
			cancelitem = true;
			cancelblock = true;
		}
		if(cancelblock && this.is_breaking && this.world[this.breaking] !is null) {
			this.sendBlock(PlacedBlock(this.breaking, this.world[this.breaking].data));
			auto tile = this.world.tileAt(this.breaking);
			if(tile !is null) {
				this.sendTile(tile, false);
			}
		}
		if(cancelitem && !this.inventory.held.empty && this.inventory.held.item.tool) {
			this.inventory.update = PlayerInventory.HELD;
		}
		this.is_breaking = false;
		return !cancelblock;
	}
	
	protected void handleBlockPlacing(BlockPosition tpos, uint tface) {
		/*BlockPosition position = tpos.face(tface);
		//TODO calling events on player and on block
		Block placed = this.inventory.held.item.place(this.world, position);
		if(placed !is null) {
			this.world[position] = placed;
		} else {
			//event cancelled or unavailable
			this.sendBlock(PlacedBlock(position, this.world[position]));
		}*/
		if(this.world.callCancellableIfExists!PlayerPlaceBlockEvent(this, this.inventory.held, tpos, tface) || !this.inventory.held.item.onPlaced(this, tpos, tface)) {
			//no block placed!
			//sends the block back
			this.sendBlock(PlacedBlock(tpos.face(tface), this.world[tpos.face(tface)].data));
		}
	}
	
	protected void handleArmSwing() {
		this.do_animation = true;
	}

	private void handleArmSwingImpl() {
		if(this.alive) {
			if(!this.world.callCancellableIfExists!PlayerAnimationEvent(this)) {
				if(!this.inventory.held.empty && this.inventory.held.item.onThrowed(this)) {
					this.actionFlag = true;
					this.broadcastMetadata();
				} else {
					this.viewers!Player.call!"sendAnimation"(this);
				}
			}
		}
	}

	protected void handleAttack(uint entity) {
		if(entity != this.id) this.handleAttack(this.world.entity(entity));
	}

	protected void handleAttack(Entity entity) {
		if(this.alive && entity !is null && (cast(Player)entity && this.world.rules.pvp || !cast(Player)entity && this.world.rules.pvm)) {
			if(cast(Player)entity ? !entity.attack(new PlayerAttackedByPlayerEvent(cast(Player)entity, this)).cancelled : !entity.attack(new EntityAttackedByPlayerEvent(entity, this)).cancelled) {
				this.exhaust(Exhaustion.ATTACKING);
			}
		}
	}

	protected void handleInteract(uint entity) {
		if(entity != this.id) this.handleInteract(this.world.entity(entity));
	}

	protected void handleInteract(Entity entity) {
		//TODO
		if(this.alive && (!this.inventory.held.empty && this.inventory.held.item.onThrowed(this) && !this.creative)) {
			//remove one from inventory
			this.inventory.held.count--;
			if(this.inventory.held.empty) this.inventory.held = Slot(null);
			else this.inventory.update = 0;
		}
	}

	protected void handleReleaseItem() {
		//TODO
	}

	protected void handleStopSleeping() {
		//TODO
	}

	protected void handleRespawn() {
		if(this.dead) {
			this.respawn();
		}
	}

	protected void handleJump() {
		if(this.alive) {
			// event
			this.world.callEventIfExists!PlayerJumpEvent(this);
			// exhaustion
			this.exhaust(this.sprinting ? Exhaustion.SPRINTED_JUMP : Exhaustion.JUMPING);
		}
	}
	
	protected void handleSprinting(bool sprint) {
		if(this.alive && sprint ^ this.sprinting) {
			if(sprint) {
				this.world.callEventIfExists!PlayerStartSprintingEvent(this);
			} else {
				this.world.callEventIfExists!PlayerStopSprintingEvent(this);
			}
			this.sprinting = sprint;
			//if(this.pe) this.recalculateSpeed();
		}
	}
	
	protected void handleSneaking(bool sneak) {
		if(this.alive && sneak ^ this.sneaking) {
			//auto event = sneak ? new PlayerStartSneakingEvent(this) : new PlayerStopSneakingEvent(this);
			//this.world.callEvent(event);
			if(sneak) {
				this.world.callEventIfExists!PlayerStartSneakingEvent(this);
			} else {
				this.world.callEventIfExists!PlayerStopSneakingEvent(this);
			}
			this.sneaking = sneak;
		}
	}

	protected void handleChangeDimension() {
		//TODO
	}
	
	protected bool consumeItemInHand() {
		if(!this.inventory.held.empty && this.inventory.held.item.consumeable/* && this.hunger < 20*/) {
			Item ret = this.inventory.held.item.onConsumed(this);
			if(this.consumeTools) {
				if(ret is null) {
					this.inventory.held = Slot(this.inventory.held.item, to!ubyte(this.inventory.held.count - 1));
					if(!this.inventory.held.empty) {
						//don't need to update the viewers
						this.inventory.update_viewers &= PlayerInventory.HELD ^ 0xF;
					}
				} else {
					this.inventory.held = Slot(ret, 1);
				}
			}
			return true;
		} else {
			this.inventory.update = PlayerInventory.HELD;
			return false;
		}
	}
	
	protected final void handleRightClick(BlockPosition tpos, uint tface) {
		//called only when !inventory.held.empty
		BlockPosition position = tpos.face(tface);
		Block block = this.world[tpos];
		if(block !is null) {
			//TODO call events
			if(this.inventory.held.item.useOnBlock(this, block, tpos, tface & 255)) {
				this.inventory.held = this.inventory.held.item.finished ? Slot(null) : this.inventory.held;
			}
		}
	}
	
	protected final void handleMapRequest(ushort mapId) {
		/*if(!this.world.callCancellableIfExists!PlayerRequestMapEvent(this, mapId)) {
			auto map = this.world[mapId];
			if(map !is null) {
				this.sendMap(map);
			} else {
				//TODO generate
			}
		}*/
	}
	
	protected final bool handleDrop(Slot slot) {
		if(!this.world.callCancellableIfExists!PlayerDropItemEvent(this, slot)) {
			this.drop(slot);
			return true;
		} else {
			return false;
		}
	}


	// *** ABSTRACT HANDLING ***

	protected uint order;

	public abstract void handle(ubyte id, ubyte[] data);

	public abstract void flush();

	protected void sendPacketPayload(ubyte[] payload) {
		Handler.sharedInstance.send(new HncomPlayer.OrderedGamePacket(this.hubId, this.order++, payload).encode());
	}

	private Tid compression;

	protected void startCompression(T:Compression)(uint hubId) {
		static import std.concurrency;
		this.compression = std.concurrency.spawn(&startCompressionImpl!T, hubId);
	}

	protected void stopCompression() {
		// send a stop message
		send(this.compression, uint.max, (immutable(ubyte)[]).init);
	}

	protected void compress(ubyte[] payload) {
		send(this.compression, this.order++, payload.idup);
	}

	protected static abstract class Compression {

		public void start(uint hubId) {

			auto handler = Handler.sharedInstance();

			while(true) {

				auto data = receiveOnly!(uint, immutable(ubyte)[]); // tuple(order, uncompressed payload)

				if(data[0] == uint.max) break;

				handler.send(new HncomPlayer.OrderedGamePacket(hubId, data[0], this.compress(data[1].dup)).encode());

			}

		}

		protected abstract ubyte[] compress(ubyte[] payload);

	}

}

private void startCompressionImpl(T)(uint hubId) {
	Thread.getThis().name = "Compression@" ~ to!string(hubId);
	auto c = new T();
	c.start(hubId);
}

enum InputMode : ubyte {

	keyboard = 1,
	controller = 0,
	touch = 2,

}

enum DeviceOS : ubyte {

	unknown = 0,
	android = 1,
	ios = 2,
	osx = 3,
	fireos = 4,
	gearvr = 5,
	hololens = 6,
	win10 = 7,
	win32 = 8,
	dedicated = 9,
	orbis = 10,
	nx = 11

}

/**
 * Checks whether or not the given symbol is of a connected player class.
 * Returns:
 * 		true if the given symbol is or extends Player and not Puppet
 * Example:
 * ---
 * assert(isPlayer!Player);
 * assert(!isPlayer!Puppet);
 * assert(isPlayer!PocketPlayerBase);
 * assert(isPlayer!(MinecraftPlayer!210));
 * assert(!isPlayer!(Projection!Puppet));
 * ---
 */
enum isPlayer(T) = is(T : Player) && !is(T : Puppet);

/**
 * Checks if the given entity is an instance of a connected player.
 * Params:
 * 		entity = an instance of an entity
 * Returns:
 * 		true if the entity can be casted to Player and not to Puppet
 * Example:
 * ---
 * assert(isPlayerInstance(player!"steve"));
 * assert(!isPlayerInstance(new Puppet(player!"steve")));
 * ---
 */
public @safe @nogc bool isPlayerInstance(Entity entity) {
	return cast(Player)entity && !cast(Puppet)entity;
}

mixin template generateHandlers(E...) {

	public override void handle(ubyte _id, ubyte[] _data) {
		switch(_id) {
			foreach(P ; E) {
				static if(P.SERVERBOUND && (is(typeof(mixin("handle" ~ P.stringof ~ "Packet"))) || is(typeof(P.variantField)))) {
					case P.ID:
					{
						P _packet = P.fromBuffer!false(_data);
						static if(!is(typeof(P.variantField))) {
							with(_packet) mixin("return this.handle" ~ P.stringof ~ "Packet(" ~ P.FIELDS.join(",") ~ ");");
						} else {
							switch(mixin("_packet." ~ P.variantField)) {
								foreach(V ; P.Variants) {
									static if(is(typeof(mixin("handle" ~ P.stringof ~ V.stringof ~ "Packet")))) {
										mixin((){ import std.string:toUpper;return "case V." ~ P.variantField.toUpper ~ ":"; }()); //TODO convert to upper snake case
										{
											V _variant = _packet.new V();
											_variant.decode();
											with(_packet) { with(_variant) mixin("return this.handle" ~ P.stringof ~ V.stringof ~ "Packet(" ~ join((){ string[] f;foreach(fl;P.FIELDS){if(fl!=P.variantField){f~=fl;}}return f; }() ~ V.FIELDS, ",") ~ ");"); }
										}
									}
								}
								default: return;
							}
						}
					}
				} else version(ShowUnhandled) {
					static if(P.SERVERBOUND) pragma(msg, "Packet " ~ P.stringof ~ " is not handled");
				}
			}
			default:
				version(ShowUnhandled) error_log("Unknown packet '", _id, "' with ", _data.length, " bytes");
				break;
		}
	}

}

/**
 * Unconnected player for visualization.
 * In the world is registered as an entity and it will
 * not be found in the array of player obtained with
 * world.online!Player nor in the count obtained with
 * world.count!Player.
 * Example:
 * ---
 * //spawn a puppet 10 blocks over a player that follows it
 * class PuppetWorld : World {
 * 
 *    private Puppet[uint] puppets;
 * 
 *    public @event join(PlayerSpawnEvent event) {
 *       this.puppets[event.player.id] = this.spawn!Puppet(event.player.position, event.player.name, event.player.skin, event.player.uuid);
 *    }
 * 
 *    public @event left(PlayerDespawnEvent event) {
 *       this.despawn(this.puppets[event.player.id]);
 *       this.puppets.remove(event.player.id);
 *    }
 * 
 *    public @event move(PlayerMoveEvent event) {
 *       this.puppets[event.player.id].move(event.position, event.yaw, event.bodyYaw, event.pitch);
 *    }
 * 
 * }
 * ---
 * Example:
 * ---
 * // Unticked puppets will reduce the CPU usage
 * auto ticked = new Puppet();
 * auto unticked = new Unticked!Puppet();
 * ---
 */
class Puppet : Player {
	
	public this(World world, EntityPosition position, string name, Skin skin, UUID uuid) {
		//TODO create a playerinfo
		super(null, world, position);
	}
	
	public this(World world, EntityPosition position, string name, Skin skin) {
		this(world, position, name, skin, world.server.nextUUID);
	}
	
	public this(World world, EntityPosition position, string name) {
		this(world, position, name, Skin.STEVE);
	}
	
	public this(World world, Player from) {
		this(world, from.position, from.name, from.skin, from.uuid);
	}
	
	protected override @safe @nogc void sendMovementUpdates(Entity[] entities) {}
	
	protected override @safe @nogc void sendMotionUpdates(Entity[] entities) {}
	
	protected override @safe @nogc void sendTitleMessage(Title message) {}
	
	protected override @safe @nogc void sendHideTitles() {}
	
	protected override @safe @nogc void sendResetTitles() {}

	protected override @safe @nogc void sendTipMessage(string message) {}

	protected override @safe @nogc void sendOpStatus() {}
	
	public override @safe @nogc void sendGamemode() {}
	
	public override @safe @nogc void sendOpenContainer(ubyte type, ushort slots, BlockPosition position) {}
	
	public override @safe @nogc void spawnToItself() {}
	
	public override @safe @nogc void sendAddList(Player[] players) {}
	
	public override @safe @nogc void sendRemoveList(Player[] players) {}
	
	protected override @safe @nogc void sendSpawnPosition() {}
	
	protected override @safe @nogc void sendPosition() {}
	
	public override @safe @nogc void sendMetadata(Entity entity) {}
	
	public override @safe @nogc void sendChunk(Chunk chunk) {}
	
	public override @safe @nogc void unloadChunk(ChunkPosition pos) {}
	
	public override @safe @nogc void sendInventory(ubyte flag=PlayerInventory.ALL, bool[] slots=[]) {}
	
	public override @safe @nogc void sendHeld() {}
	
	public override @safe @nogc void sendEntityEquipment(Player player) {}
	
	public override @safe @nogc void sendArmorEquipment(Player player) {}
	
	public override @safe @nogc void sendHurtAnimation(Entity entity) {}
	
	public override @safe @nogc void sendDeathAnimation(Entity entity) {}
	
	protected override @safe @nogc void sendDeathSequence() {}
	
	protected override @safe @nogc void experienceUpdated() {}
	
	public override @safe @nogc void sendJoinPacket() {}

	public override @safe @nogc void sendResourcePack() {}
	
	public override @safe @nogc void sendTimePacket() {}
	
	public override @safe @nogc void sendDifficulty(Difficulty difficulty) {}

	public override @safe @nogc void sendWorldGamemode(Gamemode gamemode) {}
	
	public override @safe @nogc void sendSettingsPacket() {}
	
	public override @safe @nogc void sendRespawnPacket() {}
	
	public override @safe @nogc void setAsReadyToSpawn() {}
	
	public override @safe @nogc void sendWeather() {}
	
	public override @safe @nogc void sendLightning(Lightning lightning) {}
	
	public override @safe @nogc void sendAnimation(Entity entity) {}
	
	public override @safe @nogc void sendBlocks(PlacedBlock[] block) {}
	
	public override @safe @nogc void sendTile(Tile tiles, bool translatable) {}
	
	public override @safe @nogc void sendPickupItem(Entity picker, Entity picked) {}
	
	public override @safe @nogc void sendPassenger(ubyte mode, uint passenger, uint vehicle) {}
	
	public override @safe @nogc void sendExplosion(EntityPosition position, float radius, Vector3!byte[] updates) {}
	
	public override @safe @nogc void sendMap(Map map) {}
	
	public override @safe @nogc void handle(ubyte id, ubyte[] buffer) {}
	
}

struct Title {

	public string title, subtitle;
	public tick_t fadeIn, stay, fadeOut;

	public this(string title, string subtitle="", tick_t fadeIn=10, tick_t stay=40, tick_t fadeOut=10) {
		this.title = title;
		this.subtitle = subtitle;
		this.fadeIn = fadeIn;
		this.stay = stay;
		this.fadeOut = fadeOut;
	}

	public this(string title, tick_t fadeIn, tick_t stay, tick_t fadeOut) {
		this(title, "", fadeIn, stay, fadeOut);
	}

	public this(string title, string subtitle, tick_t stay) {
		this(title, subtitle, 0, stay, 0);
	}

	public this(string title, tick_t stay) {
		this(title, "", stay);
	}

}
