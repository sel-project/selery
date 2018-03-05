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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/world/group.d, selery/world/group.d)
 */
module selery.world.group;

import core.atomic : atomicOp;
import core.thread : Thread;

import std.concurrency : Tid, send, receiveTimeout;
import std.conv : to;
import std.datetime : dur;
import std.datetime.stopwatch : StopWatch;
import std.random : Random, unpredictableSeed, uniform, dice;
import std.string : toUpper;
import std.traits : isAbstractClass, Parameters;
import std.typetuple : TypeTuple;

import sel.hncom.about : __BEDROCK__, __JAVA__;

import selery.about : SupportedBedrockProtocols, SupportedJavaProtocols;
import selery.config : Difficulty, Gamemode, Config;
import selery.log : Message;
import selery.math.vector : EntityPosition;
import selery.node.server : NodeServer;
import selery.player.bedrock : BedrockPlayerImpl;
import selery.player.java : JavaPlayerImpl;
import selery.player.player : PlayerInfo, Player, PermissionLevel;
import selery.util.util : call;
import selery.world.world : WorldInfo, World;

private shared uint _id;

/**
 * Generic informations about a group of worlds.
 */
final class GroupInfo {
	
	/**
	 * Group's id. It is unique on the node.
	 */
	public immutable uint id;
	
	/**
	 * World's name, which is given by the user who creates the world.
	 * It is unique in the node and every world in the same group has
	 * the same name.
	 */
	public immutable string name;
	
	/**
	 * Thread where the group exists.
	 */
	public Tid tid;

	/**
	 * Worlds in the group.
	 */
	shared(WorldInfo)[uint] worlds;

	/**
	 * Group's default world.
	 */
	shared WorldInfo defaultWorld;
	
	public shared this(string name) {
		this.id = atomicOp!"+="(_id, 1);
		this.name = name;
	}
	
}

void spawnWorldGroup(shared NodeServer server, shared GroupInfo info, bool main) {

	debug Thread.getThis().name = "world_group#" ~ to!string(info.id);

	WorldGroup group = new WorldGroup(server, info, main);
	group.start();
	
	//TODO catch exceptions per-world
	
}

final class WorldGroup {

	private shared NodeServer server;
	private shared GroupInfo info;
	private bool main;
	private Random random;

	private bool _stopped = false;

	private World[uint] _worlds;
	private Player[uint] _players;
	
	Gamemode gamemode;
	Difficulty difficulty;
	
	// rules that the client does not need to know about
	bool pvp;
	bool naturalRegeneration;
	bool depleteHunger;
	uint randomTickSpeed;
	uint viewDistance;
	
	Time time;
	Weather weather;
	
	private this(shared NodeServer server, shared GroupInfo info, bool main) {
		this.server = server;
		this.info = info;
		this.main = main;
		this.random = Random(unpredictableSeed);
		with(server.config.node) {
			this.gamemode = gamemode;
			this.difficulty = difficulty;
			this.depleteHunger = depleteHunger;
			this.naturalRegeneration = naturalRegeneration;
			this.pvp = pvp;
			this.randomTickSpeed = randomTickSpeed;
			this.viewDistance = viewDistance;
			//TODO more rules
			this.time = new Time(doDaylightCycle);
			this.weather = new Weather(doWeatherCycle);
			this.weather.clear();
		}
	}

	public pure nothrow @property World[] worlds() {
		return this._worlds.values;
	}

	public pure nothrow @property Player[] players() {
		return this._players.values;
	}
	
	//TODO constructor from world's save file
	
	// updates
	
	void addPlayer(Player player) {
		this._players.call!"sendAddList"([player]);
		this._players[player.hubId] = player;
		player.sendAddList(this.players);
	}

	void removePlayer(Player player, bool closed) {
		if(this._players.remove(player.hubId)) {
			this._players.call!"sendRemoveList"([player]);
			if(!closed) player.sendRemoveList(this.players);
		}
	}
	
	void updateDifficulty(Difficulty difficulty) {
		this.difficulty = difficulty;
		this._players.call!"sendDifficulty"(difficulty);
	}
	
	void updateGamemode(Gamemode gamemode) {
		this.gamemode = gamemode;
		this.players.call!"sendWorldGamemode"(gamemode);
	}
	
	private class Time {
		
		bool _cycle;
		uint day;
		uint _time;
		
		this(bool cycle) {
			this._cycle = cycle;
		}
		
		@property bool cycle() {
			return _cycle;
		}
		
		@property bool cycle(bool cycle) {
			players.call!"sendDoDaylightCycle"(cycle);
			return _cycle = cycle;
		}
		
		@property uint time() {
			return _time;
		}
		
		@property uint time(uint time) {
			time %= 24000;
			players.call!"sendTime"(time);
			return _time = time;
		}
		
		alias time this;
		
	}
	
	private class Weather {
		
		public bool cycle;
		private bool _raining, _thunderous;
		private uint _time;
		private uint _intensity;
		
		this(bool cycle) {
			this.cycle = cycle;
		}
		
		@property bool raining() {
			return _raining;
		}
		
		@property bool thunderous() {
			return _thunderous;
		}
		
		@property uint intensity() {
			return _intensity;
		}
		
		void clear(uint duration) {
			_raining = _thunderous = false;
			_time = duration;
			_intensity = 0;
			update();
		}
		
		void clear() {
			clear(uniform!"[]"(12000u, 180000u, random));
		}
		
		void start(uint time, uint intensity, bool thunderous) {
			assert(intensity > 0);
			_raining = true;
			_thunderous = thunderous;
			_time = time;
			_intensity = intensity;
			update();
		}
		
		void start(uint time, bool thunderous) {
			start(time, uniform!"[]"(1, 4, random), thunderous);
		}
		
		void start() {
			start(uniform!"[]"(12000u, 24000u, random), !dice(random, .5, .5));
		}
		
		private void update() {
			players.call!"sendWeather"(_raining, _thunderous, _time, _intensity);
		}
		
	}

	/**
	 * Starts the group.
	 */
	public void start() {

		StopWatch timer;
		ulong duration;
		
		while(!this._stopped) {
			
			timer.start();
			
			// handle server's message (new worlds, new players, new packets, ...)
			this.handleServerPackets();
			
			// tick the group
			this.tick();
			
			// tick the worlds
			foreach(world ; this._worlds) world.tick();
			
			// flush player's packets
			foreach(player ; this._players) player.flush();
			
			// sleep until next tick
			timer.stop();
			timer.peek.split!"usecs"(duration);
			if(duration < 50_000) {
				Thread.sleep(dur!"usecs"(50_000 - duration));
			} else {
				//TODO server is less than 20 tps!
			}
			timer.reset();
			
		}
		
		//TODO make sure no players are online

		foreach(world ; this._worlds) {
			world.stop();
		}
		
		//TODO send RemoveWorld to the hub (children will be removed automatically)
		
		send(cast()this.server.tid, CloseResult(this.info.id, CloseResult.REMOVED));

	}
	
	private void handleServerPackets() {
		while(receiveTimeout(dur!"msecs"(0),
			&this.handleAddWorld,
			&this.handleRemoveWorld,
			&this.handleAddPlayer,
			&this.handleRemovePlayer,
			&this.handleGamePacket,
			&this.handleBroadcast,
			&this.handleUpdateDifficulty,
			&this.handleUpdatePlayerGamemode,
			&this.handleUpdatePlayerPermissionLevel,
			&this.handleClose,
		)) {}
	}

	private void handleAddWorld(AddWorld packet) {
		(cast()packet.create).create(this);
	}

	private void handleRemoveWorld(RemoveWorld packet) {
		this.removeWorld(packet.worldId);
	}
	
	private void handleAddPlayer(AddPlayer packet) {
		//TODO allow spawning in a child
		this.spawnPlayer(packet.player, packet.transferred);
	}
	
	private void handleRemovePlayer(RemovePlayer packet) {
		auto player = packet.playerId in this._players;
		if(player) {
			this.removePlayer(*player, false); //TODO whether the player has left the server
			(*player).world.despawnPlayer(*player);
			(*player).close();
		}
	}
	
	private void handleGamePacket(GamePacket packet) {
		auto player = packet.playerId in this._players;
		if(player) {
			(*player).handle(packet.payload[0], packet.payload[1..$].dup);
		}
	}
	
	private void handleBroadcast(Broadcast packet) {
		this.broadcast(packet.message);
	}
	
	private void handleUpdateDifficulty(UpdateDifficulty packet) {
		this.difficulty = packet.difficulty;
	}
	
	private void handleUpdatePlayerGamemode(UpdatePlayerGamemode packet) {
		auto player = packet.playerId in this._players;
		if(player) {
			(*player).gamemode = packet.gamemode;
		}
	}
	
	private void handleUpdatePlayerPermissionLevel(UpdatePlayerPermissionLevel packet) {
		auto player = packet.playerId in this._players;
		if(player) {
			(*player).permissionLevel = packet.permissionLevel;
		}
	}
	
	private void handleClose(Close packet) {
		if(this.players.length) {
			// cannot close if there are players online in the world or in the children
			// the world is not stopped
			send(cast()this.server.tid, CloseResult(this.info.id, CloseResult.PLAYERS_ONLINE));
		} else {
			// the world will be stopped at the end of the next tick
			this._stopped = true;
		}
	}
	
	private void tick() {
		
		if(this.time.cycle) {
			if(++this.time._time == 24000) {
				this.time._time = 0;
				this.time.day++;
			}
		}
		
		if(this.weather.cycle) {
			if(--this.weather._time == 0) {
				if(this.weather._raining) this.weather.clear();
				else this.weather.start();
			}
		}
		
	}

	/**
	 * Broadcasts a message to every world in the group.
	 */
	public final void broadcast(E...)(E args) {
		static if(E.length == 1 && is(E[0] == Message[])) this.broadcastImpl(args[0]);
		else this.broadcastImpl(Message.convert(args));
	}
	
	protected void broadcastImpl(Message[] message) {
		foreach(world ; this._worlds) world.broadcast(message);
	}

	/**
	 * Adds a world.
	 */
	public void addWorld(T:World=World, E...)(shared WorldInfo info, E args) {
		this.addWorldImpl(info, new T(args));
	}

	private void addWorldImpl(shared WorldInfo info, World world) {
		if(info is null) info = new shared WorldInfo();
		world.info = info;
		world.info.group = this.info;
		this.info.worlds[world.id] = world.info;
		if(this.info.defaultWorld is null) this.info.defaultWorld = world.info;
		this.worlds[world.id] = world;
		//TODO register stuff
		//TODO send packet to the hub
	}

	/**
	 * Removes a world.
	 */
	public void removeWorld(uint worldId) {
		//TODO check whether it can be stopped
		//TODO save and delete
		//TODO send packet to the hub
	}
	
	/*
	 * Creates and spawn a player when it comes from another world group,
	 * node or from a new connection.
	 */
	private Player spawnPlayer(shared PlayerInfo info, bool transferred) {

		World world = this._worlds[this.info.defaultWorld.id]; //TODO allow spawning in custom world
		
		//TODO load saved info from file
		
		Player player = (){
			final switch(info.type) {
				foreach(type ; TypeTuple!("Bedrock", "Java")) {
					case mixin("__" ~ toUpper(type) ~ "__"): {
						final switch(info.protocol) {
							foreach(protocol ; mixin("Supported" ~ type ~ "Protocols")) {
								case protocol: {
									mixin("alias ReturnPlayer = " ~ type ~ "PlayerImpl;");
									return cast(Player)new ReturnPlayer!protocol(info, world, cast(EntityPosition)world.spawnPoint);
								}
							}
						}
					}
				}
			}
		}();
		
		//TODO if the player is transferred from another world or from the hub, send the change dimension packet or unload every chunk
		
		// send generic informations that will not change when changing dimension
		player.sendJoinPacket();
		
		// add and send to the list
		this.addPlayer(player);
		
		// register server's commands
		foreach(name, command; this.server.commands) {
			player.registerCommand(cast()command);
		}
		
		// prepare for spawning (send chunks and rules)
		world.preSpawnPlayer(player);
		
		// announce and spawn to entities
		world.afterSpawnPlayer(player, true);
		
		return player;
		
	}
	
}

struct AddWorld {

	shared CreateImpl create;

	static class CreateImpl {

		abstract void create(WorldGroup group);

	}

	static class Create(T:World, E...) : CreateImpl {
	
		shared WorldInfo info;
		E args;

		this(shared WorldInfo info, E args) {
			this.info = info;
			this.args = args;
		}

		override void create(WorldGroup group) {
			group.addWorld!T(info, args);
		}

	}

}

struct RemoveWorld {

	uint worldId;

}

// server to world
struct AddPlayer {

	shared PlayerInfo player;
	uint worldId;
	bool transferred;

}

// server to world
struct RemovePlayer {

	uint playerId;

}

// server to world
struct GamePacket {

	uint playerId;
	immutable(ubyte)[] payload;

}

// server to world
struct Broadcast {

	string message;

}

// server to world
struct UpdateDifficulty {

	Difficulty difficulty;

}

// server to world
struct UpdatePlayerGamemode {

	uint playerId;
	Gamemode gamemode;

}

// server to world
struct UpdatePlayerPermissionLevel {

	uint playerId;
	PermissionLevel permissionLevel;

}

// server to world
struct Close {}

// world to server
struct CloseResult {

	enum ubyte REMOVED = 0;
	enum ubyte PLAYERS_ONLINE = 1;

	uint groupId;
	ubyte status;

}
