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
module sel.world.world;

import std.algorithm : sort, min, canFind;
import std.bitmanip : read, write;
import std.conv : to;
import std.math : sin, cos, PI, round, pow;
import std.random : unpredictableSeed;
import std.string : replace, toLower, split;
import std.traits : isAbstractClass, hasUDA, getUDAs, Parameters;
import std.typecons : Tuple;

import common.sel;

import sel.player;
import sel.plugin;
import sel.server : server;
import sel.block.block : Block, Blocks, PlacedBlock, Update, Remove, blockInto;
import sel.block.tile : Tile;
import sel.entity.entity : Entity;
import sel.entity.living : Living;
import sel.entity.noai : ItemEntity, Lightning;
import sel.event.event : Event, EventListener;
import sel.event.server : PlayerJoinEvent;
import sel.event.world;
import sel.event.world.entity : EntityEvent;
import sel.event.world.player : PlayerEvent;
import sel.event.world.world : WorldEvent;
import sel.item.item : Item, Items;
import sel.item.slot : Slot;
import sel.math.vector;
import sel.util;
import sel.util.color : Color;
import sel.util.command : Command;
import sel.util.lang : translate, ITranslatable;
import sel.util.log;
import sel.util.random : Random;
import sel.util.task;
import sel.world.chunk;
import sel.world.generator;
import sel.world.map : Map;
import sel.world.particle : Particle;
import sel.world.rules : Rules;

/**
 * Basic world.
 */
class World : EventListener!(WorldEvent, EntityEvent, "entity", PlayerEvent, "player") {
	
	public static void registerAttributes(T:World)(T world) {
		foreach(immutable fname ; __traits(allMembers, T)) {
			static if(is(typeof(__traits(getMember, T, fname)) == function)) {
				mixin("alias func = T." ~ fname ~ ";");
				static if(hasUDA!(func, event)) {
					mixin("auto del = &world." ~ fname ~ ";");
					registerEvent!(hasUDA!(func, cancel), hasUDA!(func, inherit))(world, del);
				}
				static if(hasUDA!(func, command)) {
					mixin("auto del = &world." ~ fname ~ ";");
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
					world.registerCommand!(func)(del, getUDAs!(func, command)[0], d, a, p, hasUDA!(func, op), hasUDA!(func, hidden));
				}
				static if(hasUDA!(func, task)) {
					mixin("auto del = &world." ~ fname ~ ";");
					world.addTask(del, getUDAs!(func, task)[0]);
				}
			}
		}
	}
	
	private static void registerEvent(bool cancelled, bool inher, T)(World world, void delegate(T) event) {
		static if(cancelled) {
			event = (T e){ e.cancel(); };
		}
		world.addEventListener(event);
		static if(inher) {
			world.inheritance.addEventListener(event);
		}
	}

	public static void startWorld(T:World)(T world, World parent) {
		world.setListener(server.globalListener);
		if(parent !is null) {
			world.setListener(parent.inheritance);
			world.inheritance = parent.inheritance;
		}
		registerAttributes(world);
		world.start();
	}

	public static void stopWorld(World world, World transferTo) {
		if(transferTo !is null) {
			void transfer(World from) {
				auto c = from.w_players.length;
				if(c) {
					warning_log(translate("{warning.removingWithPlayers}", server.settings.language, [from.name, to!string(c)]));
					foreach(player ; from.w_players) {
						player.world = transferTo;
					}
				}
				foreach(child ; from.children) {
					transfer(child);
				}
			}
			transfer(world);
		}
		world.stop();
	}

	private static uint wcount = 0;

	public immutable uint id;
	public immutable string n_name;

	protected group!byte n_dimension = Dimension.overworld;
	protected uint n_seed;
	protected string n_type;

	private World n_parent;
	private World[] n_children;
	
	protected Blocks n_blocks;
	protected Items n_items;
	
	private Random n_random;

	public Rules rules;
	
	private tick_t n_ticks = 0;

	protected EventListener!WorldEvent inheritance = new EventListener!WorldEvent();
	protected TaskManager task_manager;

	protected Generator generator;
	
	public BlockPosition spawnPoint;
	
	private Chunk[int][int] n_chunks;
	public ChunkPosition[] defaultChunks;

	private Map[int][int][ubyte] maps;
	private Map[ushort] id_maps;

	public bool updateBlocks = false;

	private PlacedBlock[] updated_blocks;
	private Tile[size_t] updated_tiles;
	
	private Entity[size_t] w_entities;
	private Player[size_t] w_players;
	private Player[] players_list;
	
	private tick_t m_time;

	protected tick_t no_rain;
	protected Weather m_weather;

	private ScheduledUpdate[] scheduled_updates;

	private TaskManager tasks;

	private Command[string] commands;
	
	public this(string name="world", Rules rules=Rules.defaultRules.dup, Generator generator=null, uint seed=unpredictableSeed) {
		this.id = wcount++;
		this.n_name = name;
		this.n_seed = seed;
		if(this.n_blocks is null) this.n_blocks = new Blocks();
		if(this.n_items is null) this.n_items = new Items();
		this.rules = this.parent is null ? rules : this.parent.rules.dup;
		this.n_random = Random(this.seed);
		this.generator = generator is null ? new Flat(this) : generator;
		this.generator.seed = seed;
		this.n_type = this.generator.type;
		this.spawnPoint = this.generator.spawn;
		this.no_rain = this.random.next(0, 180000);
		this.tasks = new TaskManager();
	}

	public this(string name, Generator generator, uint seed=unpredictableSeed) {
		this(name, Rules.defaultRules.dup, generator, seed);
	}
	
	public this(string name, uint seed) {
		this(name, null, seed);
	}
	
	public this(uint seed) {
		this("world", seed);
	}

	/*
	 * Function called when the the world is created.
	 * Calls init and orders the default chunks.
	 */
	protected void start() {
		this.init();
		this.updated_blocks.length = 0;
		sort!"a.x.abs + a.z.abs < b.x.abs + b.z.abs"(this.defaultChunks);
		this.updateBlocks = true;
	}

	protected void init() {
		
		immutable int radius = 5;
		//load some chunks as a flat world
		foreach(int x ; -radius..radius) {
			foreach(int z ; -radius..radius) {
				if(!(x == -radius && z == -radius) && !(x == radius-1 && z == radius-1) && !(x == -radius && z == radius-1) && !(x == radius-1 && z == -radius)) {
					this.generate(x, z);
					this.defaultChunks ~= ChunkPosition(x, z);
				}
			}
		}

	}

	/*
	 * Function called when the world is closed.
	 * Saves the resources if they need to be saved.
	 */
	protected void stop() {
		foreach(ref chunks ; this.n_chunks) {
			foreach(ref chunk ; chunks) {
				chunk.unload();
			}
		}
		foreach(child ; children) {
			child.stop();
		}
	}

	/**
	 * Gets the world's name used for identification and
	 * loggin purposes.
	 * Example:
	 * ---
	 * if(!server.worldsWithName(world.name).canFind(world)) {
	 *    log(world.name, " is not managed by the server");
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc immutable(string) name() {
		return this.n_name;
	}

	/**
	 * Gets the world's dimension as a group of bytes.
	 * Example:
	 * ---
	 * if(world.dimension == Dimension.nether) {
	 *    log("world is nether!");
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc const(group!byte) dimension() {
		return this.n_dimension;
	}

	/**
	 * Gets the world's seed used for terrain and randomness
	 * generation.
	 */
	public final pure nothrow @property @safe @nogc const(uint) seed() {
		return this.n_seed;
	}

	/**
	 * Gets the world's type as a string.
	 * Valid types are "flat" and "default" for both Minecraft and
	 * Minecraft: Pocket Edition plus "largeBiomes", "amplified" and
	 * "customized" for Minecraft only.
	 */
	public final pure nothrow @property @safe @nogc const(string) type() {
		return this.n_type;
	}
	
	/*
	 * Gets the blocks.
	 */
	public final pure nothrow @property @safe @nogc ref Blocks blocks() {
		return this.n_blocks;
	}
	
	/*
	 * Gets the items
	 */
	public final pure nothrow @property @safe @nogc ref Items items() {
		return this.n_items;
	}
	
	/**
	 * Gets the world's random generator initialised with the
	 * world's seed.
	 */
	public final pure nothrow @property @safe @nogc ref Random random() {
		return this.n_random;
	}

	/**
	 * Gets the world's parent world.
	 * Returns: A world instance if the world has a parent, null otherwise
	 * Example:
	 * ---
	 * if(world.parent !is null) {
	 *    assert(world.parent.canFind(world));
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc World parent() {
		return this.n_parent;
	}

	/**
	 * Gets the world's children.
	 * Returns: An array of worlds, empty if the world has no children
	 * Example:
	 * ---
	 * if(world.children.length) {
	 *    log(world.name, " has ", world.children.length, " child(ren)");
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc World[] children() {
		return this.n_children;
	}

	/**
	 * Checks whether or not the given world is a child of this one.
	 * Example:
	 * ---
	 * if(!overworld.hasChild(nether)) {
	 *    overworld.addChild(nether);
	 * }
	 * ---
	 */
	public final pure nothrow @safe @nogc bool hasChild(World world) {
		foreach(child ; this.n_children) {
			if(world.id == child.id) return true;
		}
		return false;
	}

	/**
	 * Adds a child to the world.
	 * A child world is not managed (and ticked) by the server but
	 * by its parent. This means that this method should be used instead
	 * of server.addWorld.
	 * Returns: a new instance of the given world, constructed with the given parameters
	 * Example:
	 * ---
	 * auto overworld = server.addWorld!Overworld();
	 * auto nether = overworld.addChild!Nether();
	 * ---
	 */
	public final T addChild(T:World=World, E...)(E args) if(__traits(compiles, new T(args))) {
		T world = new T(args);
		World.startWorld(world, this);
		this.n_children ~= world;
		return world;
	}

	/**
	 * Removes a child.
	 * Returns: true if the given world was a child, false otherwise
	 */
	public final bool removeChild(World world) {
		foreach(i, child; this.n_children) {
			if(world.id == child.id) {
				this.n_children = this.n_children[0..i] ~ this.n_children[i+1..$];
				World.stopWorld(world, this);
				return true;
			}
		}
		return false;
	}
	
	/*
	 * Ticks the world and its children.
	 * This function should be called by the server (if parent world
	 * is null) or by the parent world (if it is not null).
	 */
	public void tick() {
		this.n_ticks++;

		// tasks
		if(this.tasks.length) this.tasks.tick(this.ticks);

		// update the time
		if(this.rules.daylightCycle) {
			this.m_time++;
			if(this.m_time >= 24000) {
				this.m_time %= 24000;
			}
		}

		// update the weather
		if(this.rules.toggledownfall) {
			bool update = false;
			if(this.m_weather.rain != 0) {
				this.m_weather.tick();
				if(this.m_weather.rain == 0) {
					update = true;
					foreach(ref cx ; this.n_chunks) {
						foreach(ref chunk ; cx) {
							chunk.resetSnow();
						}
					}
					this.no_rain = this.random.next(12000, 180000); // .5 to 7.5 days
				}
			} else if(--this.no_rain == 0) {
				//toggle downfall
				this.m_weather.rain = this.random.next(12000, 24000); // .5 to 1 day
				this.m_weather.thunder = this.random.probability(.25f);
				this.m_weather.intensity = this.random.range!ubyte(1, 3);
				update = true;
				log("started ", this.m_weather);
			}
			if(update) {
				this.w_players.call!"sendWeather"();
			}
		}

		// random chunk ticks
		if(this.rules.chunkTick) {
			foreach(ref c ; this.n_chunks) {
				foreach(ref chunk ; c) {
					int cx = chunk.x << 4;
					int cz = chunk.z << 4;
					if(this.m_weather.rain != 0 && this.m_weather.thunder && this.random.probability(this.rules.thunders)) {
						ubyte random = this.random.range!ubyte;
						ubyte x = (random >> 4) & 0xF;
						ubyte z = random & 0xF;
						auto y = chunk.firstBlock(x, z);
						if(y >= 0) this.strike(EntityPosition(chunk.x << 4 | x, y, chunk.z << 4 | z));
					}
					if(this.m_weather.rain != 0 && this.random.probability(.03125f * this.m_weather.intensity)) {
						auto xz = chunk.nextSnow;
						auto y = chunk.firstBlock(xz.x, xz.z);
						//TODO fill a cauldron or freeze a water block
						if(y > 0) {
							//TODO check biome (cold for snow, non-desert for rain)
							BlockPosition position = BlockPosition(cx | xz.x, y, cz | xz.z);
							Block dest = this[position];
							//TODO check whether the snow can lay on the block
							if(dest.fullUpperShape && dest.opacity == 15) {
								this[position + [0, 1, 0]] = Blocks.snowLayer0;
							}
						}
					}
					foreach(i, section; chunk.sections) {
						if(section.tick) {
							immutable y = i << 4;
							foreach(j ; 0..this.rules.randomTick) {
								auto random = this.random.next(0, 4096);
								auto block = section.blocks[random];
								if(block && (*block).doRandomTick) {
									(*block).onRandomTick(this, BlockPosition(cx | ((random >> 4) & 15), y | ((random >> 8) & 15), cz | (random & 15)));
								}
							}
						}
					}
				}
			}
		}

		// scheduled updates
		/*if(this.scheduled_updates.length > 0) {
			for(uint i=0; i<this.scheduled_updates.length; i++) {
				if(this.scheduled_updates[i].time-- == 0) {
					this.scheduled_updates[i].block.onScheduledUpdate();
					this.scheduled_updates = this.scheduled_updates[0..i] ~ this.scheduled_updates[i+1..$];
				}
			}
		}*/
		
		// tick the entities
		foreach(ref Entity entity ; this.w_entities) {
			if(entity.ticking) entity.tick();
		}
		// and the players
		foreach(ref Player player ; this.w_players) {
			if(player.ticking) player.tick();
		}

		// send the updated movements
		foreach(ref Player player ; this.w_players) {
			player.sendMovements();
		}

		// set the entities as non-moved
		foreach(ref Entity entity ; this.w_entities) {
			if(entity.moved) {
				entity.moved = false;
				entity.oldposition = entity.position;
			}
			if(entity.motionmoved) entity.motionmoved = false;
		}
		foreach(ref Player player ; this.w_players) {
			if(player.moved) {
				player.moved = false;
				player.oldposition = player.position;
			}
			if(player.motionmoved) player.motionmoved = false;
		}

		// send the updated blocks
		if(this.updated_blocks.length > 0) {
			this.w_players.call!"sendBlocks"(this.updated_blocks);
			this.updated_blocks.length = 0;
		}
		// send the updated tiles
		if(this.updated_tiles.length > 0) {
			foreach(Tile tile ; this.updated_tiles) {
				this.w_players.call!"sendTile"(tile, cast(ITranslatable)tile ? true : false);
			}
			//reset
			this.updated_tiles.clear();
		}

		// tick the children
		foreach(world ; this.n_children) {
			world.tick();
		}
	}
	
	/**
	 * Gets the number of this ticks occurred since the
	 * creation of the world.
	 */
	public final pure nothrow @property @safe @nogc tick_t ticks() {
		return this.n_ticks;
	}

	/**
	 * Broadcasts a message to every player in the world.
	 */
	public void broadcast(string message, string[] params=[]) {
		foreach(player ; this.w_players) {
			player.sendMessage(message, params);
		}
		world_log(this, translate(message, server.settings.language, params, server.variables));
	}

	/**
	 * Gets the world's time.
	 * The returned value is always in range 0..24000, where
	 * 0 is sunrise.
	 * The time doesn't change if the field daylight-cycle in the
	 * world's rules is set to false.
	 * Example:
	 * ---
	 * if(world.time > Time.sunset) {
	 *    world.time = Time.sunrise;
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc tick_t time() {
		return this.m_time;
	}

	/**
	 * Sets the world's time.
	 * If the given value is not in the range 0..24000 the value
	 * will be the modulo of the division for 24000.
	 * Example:
	 * ---
	 * world.time = 30000;
	 * assert(world.time == Time.noon);
	 * ---
	 */
	public final @property tick_t time(tick_t time) {
		this.m_time = time %= 24000;
		this.w_players.call!"sendTimePacket"();
		return this.m_time;
	}

	/**
	 * Whether or not it's raining or snowing.
	 */
	public @property @safe @nogc bool downfall() {
		return this.m_weather.rain != 0;
	}

	/**
	 * Toggles or untoggles downfalls.
	 * Example:
	 * ---
	 * if(world.downfall) {
	 *    world.downfall = false;
	 * }
	 * ---
	 */
	public @property bool downfall(bool downfall) {
		if(downfall != this.downfall) {
			if(!downfall) this.no_rain = this.random.next(0, 180000);
			this.m_weather.rain = downfall ? this.random.next(24000) : 0;
			this.w_players.call!"sendWeather"();
		}
		return downfall;
	}

	/**
	 * Gets the current weather.
	 */
	public final pure nothrow @property @safe @nogc Weather weather() {
		return this.m_weather;
	}

	/**
	 * Gets the entities spawned in the world.
	 */
	public @property T[] entities(T=Entity, string condition="")() {
		import std.algorithm : filter;
		T[] ret;
		void add(E)(E entity) {
			T a = cast(T)entity;
			if(a) {
				static if(condition.length) {
					mixin("if(" ~ condition ~ ") ret ~= a;");
				} else {
					ret ~= a;
				}
			}
		}
		//TODO improve performances for Player and Entity
		foreach(entity ; this.w_entities) add(entity);
		foreach(player ; this.w_players) add(player);
		return ret;
	}

	/// ditto
	public @property Entity[] entities(string condition)() {
		return this.entities!(Entity, condition);
	}

	/**
	 * Gets a list of the players spawned in the world.
	 */
	public @property T[] players(T=Player, string condition="")() if(isPlayer!T) {
		return this.entities!(T, condition);
	}

	/// ditto
	public @property Player[] players(string condition)() {
		return this.players!(Player, condition);
	}

	/*
	 * Adds a player to the world's players list and
	 * broadcasts the packet to the players in the world.
	 */
	public final void addPlayerList(Player player) {
		this.players_list ~= player;
		this.w_players.call!"sendAddList"([player]);
	}

	/*
	 * Removes a player from the world's players list and
	 * broadcasts the packet to the players in the world.
	 */
	public final void removePlayerList(Player player) {
		if(array_remove(player, this.players_list)) {
			this.w_players.call!"sendRemoveList"([player]);
		}
	}

	/*
	 * Gets the player's list (online players without the hidden ones).
	 */
	public final @property @safe @nogc Player[] playersList() {
		return this.players_list;
	}
	
	/*
	 * Spawns a player using an existing instance.
	 */
	public final void spawnPlayer(Player player) {
		//player.rules = this.rules.dup;
		
		player.m_spawn = this.spawnPoint.entityPosition;
		player.sendJoinPacket();
		player.spawn = this.spawnPoint; // sends spawn position
		player.move(this.spawnPoint.entityPosition);
		
		//send chunks
		foreach(ChunkPosition pos ; this.defaultChunks) {
			auto chunk = pos in this;
			if(chunk) {
				player.sendChunk(*chunk);
			} else {
				player.sendChunk(this.generate(pos));
			}
			player.loaded_chunks ~= pos;
		}

		// add world's commands
		foreach(command ; this.commands) {
			player.registerCommand(command);
		}

		player.sendSettingsPacket();
		player.sendRespawnPacket();
		player.sendTimePacket();
		player.sendWeather();
		player.sendInventory();
		player.sendMetadata(player);

		player.setAsReadyToSpawn();
		player.firstspawn();

		this.w_players[player.id] = player;
		PlayerSpawnEvent event = new PlayerSpawnEvent(player);
		this.callEvent(event);
		if(event.announce) {
			this.broadcast(event.message, [player.displayName]);
		}
		//TODO find a better solution for this
		if(player.pc) {
			player.teleport(this.spawnPoint.entityPosition);
		}
		if(event.spawn) {
			//update the players list
			if(this.players_list.length > 0) player.sendAddList(this.players_list);
			this.addPlayerList(player);
			//TODO let the event choose if spawn or not
			foreach(ref Player splayer ; this.w_players) {
				splayer.show(player);
				player.show(splayer);
			}
		}
		foreach(ref Entity entity ; this.w_entities) {
			if(entity.shouldSee(player)) entity.show(player);
			/*if(player.shouldSee(entity))*/ player.show(entity); // the player sees EVERYTHING
		}

		this.callEventIfExists!PlayerAfterSpawnEvent(player);
	}
	
	/*
	 * Despawns a player (i.e. on disconnection, on world change, ...).
	 */
	public final void despawnPlayer(Player player) {
		//TODO some packet shouldn't be sent when the player is disconnecting or changing dimension
		if(player.id in this.w_players) {
			this.w_players.remove(player.id);
			PlayerDespawnEvent event = new PlayerDespawnEvent(player);
			this.callEvent(event);
			if(event.announce) {
				this.broadcast(event.message, [player.displayName]);
			}
			foreach(ref Entity viewer ; player.viewers) {
				viewer.hide(player);
			}
			foreach(ref Entity watch ; player.watchlist) {
				player.hide(watch/*, false*/); //updating the viewer's watchlist
			}
			this.removePlayerList(player);
			player.sendRemoveList(this.players_list);
			PlayerAfterDespawnEvent ad = new PlayerAfterDespawnEvent(player);
			this.callEvent(ad);

			// remove world's commands
			foreach(command ; this.commands) player.unregisterCommand(command);
		}
	}

	/**
     * Spawns an entity.
	 */
	public final T spawn(T:Entity, E...)(E args) if(!isPlayer!T) {
		T spawned = new T(this, args);
		this.w_entities[spawned.id] = spawned;
		//TODO call the event
		foreach(ref Entity entity ; this.w_entities) {
			if(entity.shouldSee(spawned)) entity.show(spawned);
			if(spawned.shouldSee(entity)) spawned.show(entity);
		}
		foreach(ref Player player ; this.w_players) {
			player.show(spawned); // player sees everything!
			if(spawned.shouldSee(player)) spawned.show(player);
		}
		return spawned;
	}

	/**
	 * Despawns an entity.
	 */
	public final void despawn(T:Entity)(T entity) if(!isPlayer!T) {
		if(entity.id in this.w_entities) {
			entity.setAsDespawned();
			this.w_entities.remove(entity.id);
			//TODO call the event
			foreach(ref Entity e ; entity.viewers) {
				e.hide(entity);
			}
			foreach(ref Entity e ; entity.watchlist) {
				entity.hide(e);
			}
		}
	}

	/**
	 * Drops an item.
	 */
	public final ItemEntity drop(Slot item, EntityPosition position, EntityPosition motion) {
		return this.spawn!ItemEntity(position, motion, item);
	}

	/// ditto
	public final ItemEntity drop(Slot item, EntityPosition position) {
		float f0 = this.random.next!float * .1f;
		float f1 = this.random.next!float * PI * 2f;
		return this.drop(item, position, EntityPosition(-sin(f1) * f0, .2f, cos(f1) * f0));
	}

	/// ditto
	public final void drop(Block from, BlockPosition position) {
		foreach(slot ; from.drops(this, null, null)) {
			this.drop(slot, position.entityPosition + .5);
		}
	}

	/**
	 * Stikes a lightning.
	 */
	public final void strike(bool visual=false)(EntityPosition position) {
		this.w_players.call!"sendLightning"(new Lightning(this, position));
		static if(!visual) {
			//TODO do the damages
			//TODO create the fire
		}
	}

	/// ditto
	public final void strike(Entity entity) {
		this.strike(entity.position);
	}

	public void explode(bool breakBlocks=true)(EntityPosition position, float power, Living damager=null) {

		enum float rays = 16;
		enum float half_rays = (rays - 1) / 2;

		enum float length = .3;
		enum float attenuation = length * .75;
		
		Tuple!(BlockPosition, Block**)[] explodedBlocks;

		void explodeImpl(EntityPosition ray) {

			auto pointer = position.dup;
		
			for(double blastForce=this.random.range(.7, 1.3)*power; blastForce>0; blastForce-=attenuation) {
				auto pos = cast(BlockPosition)pointer + [pointer.x < 0 ? 0 : 1, pointer.y < 0 ? 0 : 1, pointer.z < 0 ? 0 : 1];
				//if(pos.y < 0 || pos.y >= 256) break; //TODO use a constant
				auto block = pos in this;
				if(block && *block && **block != Blocks.AIR) {
					blastForce -= ((**block).blastResistance / 5 + length) * length;
					if(blastForce <= 0) break;
					static if(breakBlocks) {
						import std.typecons : tuple;
						explodedBlocks ~= tuple(pos, block);
					}
				}
				pointer += ray;
			}

		}

		template Range(float max, E...) {
			static if(E.length >= max) {
				alias Range = E;
			} else {
				alias Range = Range!(max, E, E[$-1] + 1);
			}
		}

		foreach(x ; Range!(rays, 0)) {
			foreach(y ; Range!(rays, 0)) {
				foreach(z ; Range!(rays, 0)) {
					static if(x == 0 || x == rays - 1 || y == 0 || y == rays - 1 || z == 0 || z == rays - 1) {

						enum ray = (){
							auto ret = EntityPosition(x, y, z) / half_rays - 1;
							ret.length = length;
							return ret;
						}();
						explodeImpl(ray);

					}
				}
			}
		}

		// send packets
		this.players.call!"sendExplosion"(position, power, new Vector3!byte[0]);

		foreach(exploded ; explodedBlocks) {
			auto block = this[exploded[0]];
			if(block != Blocks.AIR) {
				this.opIndexAssign!true(Blocks.AIR, exploded[0]); //TODO use packet's fields
				if(this.random.range(0f, power) <= 1) {
					this.drop(block, exploded[0]);
					//TODO drop experience
				}
			}
		}

	}

	/**
	 * Gets an entity from an id.
	 */
	public final @safe Entity entity(uint eid) {
		auto ret = eid in this.w_entities;
		return ret ? *ret : this.player(eid);
	}

	/**
	 * Gets a player from an id.
	 */
	public final @safe Player player(uint eid) {
		auto ret = eid in this.w_players;
		return ret ? *ret : null;
	}

	// CHUNKS

	/**
	 * Gets an associative array with every chunk loaded in
	 * the world.
	 */
	public final pure nothrow @property @safe @nogc Chunk[int][int] chunks() {
		return this.n_chunks;
	}

	/**
	 * Gets the number of loaded chunks in the world and
	 * its children.
	 */
	public final pure @property @safe @nogc size_t loadedChunks() {
		size_t ret = 0;
		foreach(chunks ; this.n_chunks) {
			ret += chunks.length;
		}
		foreach(child ; this.n_children) {
			ret += child.loadedChunks;
		}
		return ret;
	}

	/**
	 * Gets a chunk.
	 * Returns: the chunk at given position or null if the chunk doesn't exist
	 */
	public final @safe Chunk opIndex(int x, int z) {
		return this.opIndex(ChunkPosition(x, z));
	}

	/// ditto
	public final @safe Chunk opIndex(ChunkPosition position) {
		auto ret = position in this;
		return ret ? *ret : null;
	}

	/**
	 * Gets a pointer to the chunk at the given position.
	 * Example:
	 * ---
	 * if(ChunkPosition(100, 100) in world) {
	 *    log("world doesn't have the chunk at 100, 100");
	 * }
	 * ---
	 */
	public final @safe Chunk* opBinaryRight(string op : "in")(ChunkPosition position) {
		auto a = position.x in this.n_chunks;
		return a ? position.z in *a : null;
	}
	
	/**
	 * Sets a chunk.
	 * Example:
	 * ---
	 * auto chunk = new Chunk(world, ChunkPosition(1, 2));
	 * world[] = chunk;
	 * assert(world[1, 2] == chunk);
	 * ---
	 */
	public final @safe Chunk opIndexAssign(Chunk chunk) {
		chunk.saveChangedBlocks = true;
		return this.n_chunks[chunk.x][chunk.z] = chunk;
	}

	/**
	 * Generates and sets a chunk.
	 * Returns: the generated chunk
	 */
	public Chunk generate(ChunkPosition position) {
		return this[] = this.generator.generate(position);
	}

	/// ditto
	public Chunk generate(int x, int z) {
		return this.generate(ChunkPosition(x, z));
	}

	/**
	 * Unloads and removes a chunk.
	 * Returns: true if the chunk was removed, false otherwise
	 */
	public bool unload(ChunkPosition position) {
		if(this.defaultChunks.canFind(position)) return false;
		auto chunk = position in this;
		if(chunk) {
			this.n_chunks[position.x].remove(position.z);
			if(this.n_chunks[position.x].length == 0) this.n_chunks.remove(position.x);
			(*chunk).unload();
			return true;
		}
		return false;
	}

	// Handles the player's chunk request
	public final void playerUpdateRadius(Player player) {
		if(player.viewDistance > this.rules.viewDistance) player.viewDistance = this.rules.viewDistance;
		if(this.rules.chunksAutosending) {
			ChunkPosition pos = player.chunk;
			if(player.last_chunk_position != pos) {
				player.last_chunk_position = pos;

				ChunkPosition[] new_chunks;
				foreach(int x ; pos.x-player.viewDistance.to!int..pos.x+player.viewDistance.to!int) {
					foreach(int z ; pos.z-player.viewDistance.to!int..pos.z+player.viewDistance.to!int) {
						ChunkPosition c = ChunkPosition(x, z);
						if(distance(c, pos) <= player.viewDistance) {
							new_chunks ~= c;
						}
					}
				}

				// sort 'em
				sort!"a.x + a.z < b.x + b.z"(new_chunks);

				// send chunks
				foreach(ChunkPosition cp ; new_chunks) {
					if(!player.loaded_chunks.canFind(cp)) {
						auto chunk = cp in this;
						if(chunk) {
							player.sendChunk(*chunk);
						} else {
							player.sendChunk(this.generate(cp));
						}
					}
				}

				// unload chunks
				foreach(ref ChunkPosition c ; player.loaded_chunks) {
					if(!new_chunks.canFind(c)) {
						//TODO check if it should be deleted from the world's memory
						//this.unload(this[c]);
						player.unloadChunk(c);
					}
				}

				// set the new chunks
				player.loaded_chunks = new_chunks;

			}
		}

	}

	// BLOCKS

	/**
	 * Gets a block.
	 * Returns: an instance of block, which is never null
	 * Example:
	 * ---
	 * if(world[0, 0, 0] != Blocks.BEDROCK) {
	 *    log("0,0,0 is not bedrock!");
	 * }
	 * ---
	 */
	public @safe Block opIndex(BlockPosition position) {
		auto block = position in this;
		return (block && *block) ? **block : *this.blocks[0]; // default block (air)
	}

	/// ditto
	public @safe Block opIndex(int x, uint y, int z) {
		return this.opIndex(BlockPosition(x, y, z));
	}

	//TODO documentation
	public Block** opBinaryRight(string op : "in")(BlockPosition position) {
		auto chunk = ChunkPosition(position.x >> 4, position.z >> 4) in this;
		return chunk ? (*chunk)[position.x & 15, position.y, position.z & 15] : null;
	}

	/**
	 * Gets a tile.
	 */
	public @safe T tileAt(T=Tile)(int x, uint y, int z) if(is(T == class) || is(T == interface)) {
		auto chunk = ChunkPosition(x >> 4, z >> 4) in this;
		return chunk ? (*chunk).tileAt!T(BlockPosition(x & 15, y, z & 15)) : null;
	}

	/// ditto
	public @safe T tileAt(T=Tile)(BlockPosition position) {
		return this.tileAt!T(position.x, position.y, position.z);
	}

	/**
	 * Sets a block.
	 * Example:
	 * ---
	 * world[0, 55, 12] = Blocks.grass;
	 * world[12, 55, 789] = Blocks.chest; // not a tile!
	 * ---
	 */
	public Block** opIndexAssign(bool sendUpdates=true, T)(T block, BlockPosition position) if(is(T == block_t) || is(T == block_t[]) || is(T == Block*)) {
		auto chunk = ChunkPosition(position.x >> 4, position.z >> 4) in this;
		if(chunk) {

			Block** ptr = (*chunk)[position.x & 15, position.y, position.z & 15];
			if(ptr && *ptr) {
				(**ptr).onRemoved(this, position, Remove.unset);
			}

			static if(is(T == ushort[])) {
				block_t b = block[0];
			} else {
				alias b = block;
			}

			Block** nb = ((*chunk)[position.x & 15, position.y, position.z & 15] = b);

			// set as to update
			//TODO move this in the chunk
			static if(sendUpdates) this.updated_blocks ~= PlacedBlock(position, nb && *nb ? **nb : null);

			// call the update function
			if(this.updateBlocks) {
				if(nb && *nb) (**nb).onUpdated(this, position, Update.placed);
				this.updateBlock(position + [0, 1, 0]);
				this.updateBlock(position + [1, 0, 0]);
				this.updateBlock(position + [0, 0, 1]);
				this.updateBlock(position - [0, 1, 0]);
				this.updateBlock(position - [1, 0, 0]);
				this.updateBlock(position - [0, 0, 1]);
			}

			return nb;

		}
		return null;
	}

	/// ditto
	public void opIndexAssign(T)(T block, int x, uint y, int z) if(is(T == block_t) || is(T == Block*)) {
		this.opIndexAssign(block, BlockPosition(x, y, z));
	}

	/**
	 * Sets a tile.
	 */
	public void opIndexAssign(T)(T tile, BlockPosition position) if(is(T : Tile) && is(T : Block)) {
		assert(!tile.placed, "This tile has already been placed: " ~ to!string(tile) ~ " at " ~ to!string(position));
		// place the block
		this[position] = tile.data;
		auto chunk = ChunkPosition(position.x >> 4, position.z >> 4) in this;
		if(chunk) {
			// then set it as placed here
			tile.place(this, position);
			// and register the tile in the chunk
			(*chunk).registerTile(tile);
		}
	}

	/// ditto
	public void opIndexAssign(T)(T tile, int x, int y, int z) if(is(T : Tile) && is(T : Block)) {
		this.opIndexAssign(tile, BlockPosition(x, y, z));
	}

	/**
	 * Sets the same block in a rectangualar area.
	 * This method is optimised for building as it uses a cached pointer
	 * instead of getting it every time and it doesn't call any block
	 * update.
	 * Example:
	 * ---
	 * // sets a chunk to stone
	 * world[0..16, 0..$, 0..16] = Blocks.STONE;
	 * 
	 * // sets an area to air
	 * world[0..16, 64..128, 0..16] = Blocks.AIR;
	 * 
	 * // sets a 1-block-high layer only
	 * world[0..16, 64, 0..16] = Blocks.BEETROOT_BLOCK;
	 * ---
	 */
	public final void opIndexAssign(block_t b, Slice x, Slice y, Slice z) {
		auto block = b in this.blocks;
		this.updateBlocks = false;
		foreach(px ; x.min..x.max) {
			foreach(py ; y.min..y.max) {
				foreach(pz ; z.min..z.max) {
					this[px, py, pz] = block;
				}
			}
		}
		this.updateBlocks = true;
	}

	/// ditto
	public final void opIndexAssign(block_t b, int x, Slice y, Slice z) {
		this[x..x+1, y, z] = b;
	}

	/// ditto
	public final void opIndexAssign(block_t b, Slice x, uint y, Slice z) {
		this[x, y..y+1, z] = b;
	}

	/// ditto
	public final void opIndexAssign(block_t b, Slice x, Slice y, int z) {
		this[x, y, z..z+1] = b;
	}

	/// ditto
	public final void opIndexAssign(block_t b, int x, uint y, Slice z) {
		this[x..x+1, y..y+1, z] = b;
	}

	/// ditto
	public final void opIndexAssign(block_t b, int x, Slice y, int z) {
		this[x..x+1, y, z..z+1] = b;
	}

	/// ditto
	public final void opIndexAssign(block_t b, Slice x, uint y, int z) {
		this[x, y..y+1, z..z+1] = b;
	}

	public size_t replace(block_t from, block_t to) {
		return this.replace(from in this.blocks, to in this.blocks);
	}

	public size_t replace(Block* from, Block* to) {
		size_t ret = 0;
		foreach(cc ; this.n_chunks) {
			foreach(c ; cc) {
				ret += this.replaceImpl(c, from, to);
			}
		}
		return ret;
	}

	public size_t replace(block_t from, block_t to, BlockPosition fromp, BlockPosition top) {
		if(fromp.x < top.x && fromp.y < top.y && fromp.z < top.z) {
			//TODO
			return 0;
		} else {
			return 0;
		}
	}

	private size_t replaceImpl(ref Chunk chunk, Block* from, Block* to) {
		//TODO
		return 0;
	}

	/// function called by a tile when its data is updated
	public final void updateTile(Tile tile, BlockPosition position) {
		this.updated_tiles[tile.tid] = tile;
	}

	protected final void updateBlock(BlockPosition position) {
		auto block = position in this;
		if(block && *block) (**block).onUpdated(this, position, Update.nearestChanged);
	}

	public @safe Slice opSlice(size_t pos)(int min, int max) {
		return Slice(min, max);
	}

	/// schedules a block update
	public @safe void scheduleBlockUpdate(Block block, uint time) {
		if(this.rules.scheduledTicks) {
			this.scheduled_updates ~= ScheduledUpdate(block, time);
		}
	}

	/**
	 * Registers a command.
	 */
	public void registerCommand(alias func)(void delegate(Parameters!func) del, string command, string description, string[] aliases, string[] params, bool op, bool hidden) {
		command = command.toLower;
		if(command !in this.commands) this.commands[command] = new Command(command, description, aliases, op, hidden);
		auto ptr = command in this.commands;
		(*ptr).add!func(del, params);
	}

	/**
	 * Unregisters a command.
	 */
	public void unregisterCommand(string command) {
		this.commands.remove(command);
	}

	/**
	 * Registers a task.
	 * Params:
	 *		task = a delegate of a function that will be called every interval
	 *		interval = number of ticks indicating between the calls
	 *		repeat = number of times to repeat the task
	 * Returns:
	 * 		the new task id that can be used to remove the task
	 */
	public @safe size_t addTask(E...)(void delegate(E) task, size_t interval, size_t repeat=size_t.max) if(areValidTaskArgs!E) {
		return this.tasks.add(task, interval, repeat, this.ticks);
	}
	
	/// ditto
	alias addTask schedule;
	
	/**
	 * Executes a task one time after the given ticks.
	 */
	public @safe size_t delay(E...)(void delegate(E) task, size_t timeout) if(areValidTaskArgs!E) {
		return this.addTask(task, timeout, 1);
	}
	
	/**
	 * Removes a task using the task's delegate or the id returned
	 * by the addTask function.
	 */
	public @safe void removeTask(E...)(void delegate(E) task) if(areValidTaskArgs!E) {
		this.tasks.remove(task);
	}
	
	/// ditto
	public @safe void removeTask(size_t tid) {
		this.tasks.remove(tid);
	}

	public override @safe bool opEquals(Object o) {
		if(cast(World)o) return this.id == (cast(World)o).id;
		else return false;
	}

	/** Grows a tree in the given world. */
	public static void growTree(World world, BlockPosition position, ushort[] trunk=Blocks.oakWood, ushort leaves=Blocks.oakLeavesDecay) {
		uint height = world.random.next(3, 6);
		foreach(uint i ; 0..height) {
			world[position + [0, i, 0]] = trunk[0];
		}

		foreach(uint i ; 0..2) {
			foreach(int x ; -2..3) {
				foreach(int z ; -2..3) {
					world[position + [x, height + i, z]] = leaves;
				}
			}
		}
		foreach(int x ; -1..2) {
			foreach(int z ; -1..2) {
				world[position + [x, height + 2, z]] = leaves;
			}
		}
		world[position + [0, height + 3, 0]] = leaves;
		world[position + [-1, height + 3, 0]] = leaves;
		world[position + [1, height + 3, 0]] = leaves;
		world[position + [0, height + 3, -1]] = leaves;
		world[position + [0, height + 3, 1]] = leaves;
	}

	public override string toString() {
		return typeid(this).to!string ~ "(" ~ to!string(this.id) ~ ", " ~ this.name ~ ", " ~ to!string(this.n_children) ~ ")";
	}

}

private alias Slice = Tuple!(int, "min", int, "max");

private struct ScheduledUpdate {

	public Block block;
	public uint time;

	public @safe @nogc this(ref Block block, uint time) {
		this.block = block;
		this.time = time;
	}

}

struct Weather {

	public tick_t rain = 0;
	public bool thunder = false;

	public ubyte intensity = 1; // 1, 2 or 3

	public @safe @nogc void tick() {
		this.rain--;
	}

}

enum Difficulty : ubyte {

	peaceful = 0,
	easy = 1,
	normal = 2,
	hard = 3

}

enum Time : tick_t {

	sunrise = 0,
	noon = 6000,
	sunset = 12000,
	midnight = 18000

}

enum Dimension : group!byte {

	overworld = group!byte(0, 0),
	nether = group!byte(1, -1),
	end = group!byte(2, 1)

}
