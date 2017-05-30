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
module sel.node.server;

import core.atomic : atomicOp;
import core.thread : getpid, Thread;

import std.algorithm : canFind;
import std.ascii : newline;
import std.bitmanip : nativeToBigEndian;
static import std.concurrency;
import std.conv : to;
import std.datetime : dur, StopWatch, Duration;
static import std.file;
import std.json;
import std.math : round;
import std.process : executeShell;
import std.socket : SocketException, Address, InternetAddress, Internet6Address;
import std.string;
import std.typetuple : TypeTuple;
import std.traits : Parameters;
import std.uuid : UUID;
import std.zlib : UnCompress;

import resusage.memory;
import resusage.cpu;

import sel.world.world; // do not move this import down

import sel.about;
import sel.command.command : Command, CommandSender;
import sel.config : Config, ConfigType;
import sel.format : Text;
import sel.lang : Lang, translate, Translation, Messageable;
import sel.util.memory : Memory;
import sel.path : Paths;
import sel.plugin : Plugin;
import sel.util.util : milliseconds, microseconds;
import sel.entity.entity : Entity;
import sel.entity.human : Skin;
import sel.event.event : Event, EventListener;
import sel.event.server;
import sel.event.server.server : ServerEvent;
import sel.event.world.world : WorldEvent;
import sel.math.vector : EntityPosition;
import sel.network.hncom;
import sel.network.http : serveResourcePacks;
import sel.node.info : PlayerInfo, WorldInfo;
import sel.player.minecraft : MinecraftPlayer;
import sel.player.player : Player;
import sel.player.pocket : PocketPlayer, PocketPlayerImpl;
import sel.tuple : Tuple;
import sel.util.hncom;
import sel.util.ip : publicAddresses;
import sel.log;
import sel.util.node : Node;
import sel.util.resourcepack : createResourcePacks;
import sel.world.rules : Rules;
import sel.world.thread;
import sel.world.world : World, Dimension;

// Server's instance
private shared Server n_server;
private shared std.concurrency.Tid server_tid;

/**
 * Gets the server instance (plugins should use this
 * function to get the server's instance).
 */
public nothrow @property @safe @nogc shared(Server) server() {
	return n_server;
}

// the signal could be handled on another thread!
private shared bool running = true;
private shared bool stoppedWithSignal = false;

public nothrow @property @safe @nogc bool isServerRunning() {
	return running;
}

version(Windows) {

	import core.sys.windows.wincon : CTRL_C_EVENT;
	import core.sys.windows.windef : DWORD, BOOL;

	alias extern (Windows) BOOL function(DWORD) PHANDLER_ROUTINE;
	extern (Windows) BOOL SetConsoleCtrlHandler(PHANDLER_ROUTINE, BOOL);

	extern (Windows) int sigHandler(uint sig) {
		if(sig == CTRL_C_EVENT) {
			stoppedWithSignal = true;
			running = false;
			//TODO send a message to say to stop
			return true; // this will let the process run in background until it kills himself
		}
		return false; // windows will instantly kill the process
	}

} else version(Posix) {

	import core.sys.posix.signal;

	extern (C) void extsig(int sig) {
		stoppedWithSignal = true;
		running = false;
		//server.stop();
	}

}

/**
 * Singleton for the server instance.
 */
final class Server : EventListener!ServerEvent, Messageable {

	public immutable bool lite;

	private shared ulong start_time;

	private Handler handler;
	private Address n_hub_address;
	private immutable string node_name;
	private immutable bool node_main;

	private const string[] n_args;

	private shared ulong n_id;
	private shared ulong uuid_count;

	private shared uint n_hub_latency;

	public shared std.concurrency.Tid tid; //TODO make private

	private shared Config n_settings;
	private shared uint n_node_max;
	private shared size_t n_online;
	private shared size_t n_max;

	private shared Node[uint] nodes_hubid;
	private shared Node[string] nodes_names;

	private shared Tuple!(string, "website", string, "facebook", string, "twitter", string, "youtube", string, "instagram", string, "googlePlus") n_social;

	private shared(uint) _world_count = 0;
	private shared(uint) _default_world_id = 0; // 0 = no default world
	private shared(WorldInfo)[uint] _worlds;
	private shared(PlayerInfo)[uint] _players;

	private shared Plugin[] n_plugins;

	public shared EventListener!WorldEvent globalListener;

	private shared Command[string] commands;

	public shared this(Address hub, string name, string password, bool main, Plugin[] plugins, string[] args) {

		Thread.getThis().name = "Server";

		this.lite = cast(TidAddress)hub !is null;

		this.node_name = name;
		this.node_main = main;

		this.n_plugins = cast(shared)plugins;

		this.n_args = cast(shared)args;

		this.tid = server_tid = cast(shared)std.concurrency.thisTid;
		
		n_server = cast(shared)this;
		
		this.n_hub_address = cast(shared)hub;
		
		{
			// load language from the last execution (or default language)
			static import std.file;
			if(std.file.exists(Paths.hidden ~ "lang")) {
				this.n_settings.language = cast(string)std.file.read(Paths.hidden ~ "lang");
			} else {
				this.n_settings.language = "en_GB";
			}
			this.n_settings.acceptedLanguages = [this.n_settings.language];
			Lang.init(cast(string[])this.n_settings.acceptedLanguages, cast(string[])[Paths.langSystem]);
		}

		if(lite) {

			this.handler = new shared MessagePassingHandler(cast(shared TidAddress)hub);
			this.handleInfoImpl(cast()std.concurrency.receiveOnly!(HncomLogin.HubInfo)());

		} else {

			log(translate(Translation("startup.connecting"), this.n_settings.language, [to!string(hub), name]));

			try {
				this.handler = new shared SocketHandler(hub);
				this.handler.send(new HncomLogin.ConnectionRequest(Software.hncom, password, name, main).encode());
			} catch(SocketException e) {
				error_log(translate(Translation("warning.connectionError"), this.n_settings.language, [to!string(hub), e.msg]));
				return;
			}

			// wait for ConnectionResponse
			ubyte[] buffer = this.handler.receive();
			if(buffer.length && buffer[0] == HncomLogin.ConnectionResponse.ID) {
				auto response = HncomLogin.ConnectionResponse.fromBuffer(buffer);
				if(response.status == HncomLogin.ConnectionResponse.OK) {
					this.handleInfo();
				} else {
					immutable reason = (){
						switch(response.status) {
							case HncomLogin.ConnectionResponse.OUTDATED_HUB: return "outdatedHub";
							case HncomLogin.ConnectionResponse.OUTDATED_NODE: return "outdatedNode";
							case HncomLogin.ConnectionResponse.PASSWORD_REQUIRED: return "passwordRequired";
							case HncomLogin.ConnectionResponse.WRONG_PASSWORD: return "wrongPassword";
							case HncomLogin.ConnectionResponse.INVALID_NAME_LENGTH: return "invalidNameLength";
							case HncomLogin.ConnectionResponse.INVALID_NAME_CHARACTERS: return "invalidNameCharacters";
							case HncomLogin.ConnectionResponse.NAME_ALREADY_USED: return "nameAlreadyUsed";
							case HncomLogin.ConnectionResponse.NAME_RESERVED: return "nameReserved";
							default: return "unknown";
						}
					}();
					error_log(translate(Translation("status." ~ reason), this.n_settings.language));
					if(response.status == HncomLogin.ConnectionResponse.OUTDATED_HUB || response.status == HncomLogin.ConnectionResponse.OUTDATED_NODE) {
						error_log(translate(Translation("warning.protocolRequired"), this.n_settings.language, [to!string(Software.hncom), to!string(response.protocol)]));
					}
				}
			} else {
				error_log(translate(Translation("warning.refused"), this.n_settings.language));
			}

			this.handler.close();

		}
		
	}

	private shared void handleInfo() {

		ubyte[] buffer = this.handler.receive();
		if(buffer.length && buffer[0] == HncomLogin.HubInfo.ID) {
			this.handleInfoImpl(HncomLogin.HubInfo.fromBuffer(buffer));
		} else {
			error_log(translate(Translation("warning.closed"), this.n_settings.language));
		}

	}

	private shared void handleInfoImpl(HncomLogin.HubInfo info) {

		Config settings;

		this.n_hub_latency = cast(uint)round(to!float(microseconds - info.time) / 1000f);

		this.n_id = info.serverId;
		this.uuid_count = info.reservedUuids;

		auto type = this.n_hub_address is null ? ConfigType.lite : ConfigType.node;

		auto additional = parseJSON(info.additionalJson);
		auto minecraft = "minecraft" in additional;
		if(minecraft && minecraft.type == JSON_TYPE.OBJECT) {
			auto edu = "edu" in *minecraft;
			auto realm = "realm" in *minecraft;
			settings = Config(type, edu && edu.type == JSON_TYPE.TRUE, realm && realm.type == JSON_TYPE.TRUE);
		} else {
			settings = Config(type, false, false);
		}
		settings.load();
		Rules.reload(settings);

		settings.displayName = info.displayName;
		settings.language = info.language;
		settings.acceptedLanguages = info.acceptedLanguages;

		this.n_online = info.online;
		this.n_max = info.max;

		auto social = "social" in additional;
		if(social && social.type == JSON_TYPE.OBJECT) {
			if("website" in *social) this.n_social.website = (*social)["website"].str;
			if("facebook" in *social) this.n_social.facebook = (*social)["facebook"].str;
			if("twitter" in *social) this.n_social.twitter = (*social)["twitter"].str;
			if("youtube" in *social) this.n_social.youtube = (*social)["youtube"].str;
			if("instagram" in *social) this.n_social.instagram = (*social)["instagram"].str;
			if("google-plus" in *social) this.n_social.googlePlus = (*social)["google-plus"].str;
		}

		// save latest language used
		std.file.write(Paths.hidden ~ "lang", settings.language);

		version(Windows) {
			//executeShell("title " ~ info.displayName ~ " ^| node ^| " ~ Software.display);
		}

		// reload languages and save cache
		string[] paths;
		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			if(plugin.languages !is null) paths ~= plugin.languages;
		}
		Lang.init(settings.acceptedLanguages, paths ~ Paths.langSystem ~ Paths.langMessages);
		if(!std.file.exists(Paths.hidden)) std.file.mkdirRecurse(Paths.hidden);
		std.file.write(Paths.hidden ~ "lang", settings.language);

		foreach(game ; info.gamesInfo) {
			this.handleGameInfo(game, settings);
		}

		// check protocols and print warnings if necessary
		void check(string name, uint[] requested, uint[] supported) {
			foreach(req ; requested) {
				if(!supported.canFind(req)) {
					warning_log(translate(Translation("warning.invalidProtocol"), settings.language, [to!string(req), name]));
				}
			}
		}

		check("Minecraft", settings.minecraft.protocols, supportedMinecraftProtocols.keys);
		check("Minecraft: Pocket Edition", settings.pocket.protocols, supportedPocketProtocols.keys);

		this.n_settings = cast(shared)settings;

		this.finishConstruction();

	}

	private shared void handleGameInfo(HncomTypes.GameInfo info, ref Config settings) {
		void set(ref Config.Game game) {
			game.enabled = true;
			game.protocols = info.game.protocols;
			game.motd = info.motd;
			game.onlineMode = info.onlineMode;
			game.port = info.port;
		}
		if(info.game.type == HncomTypes.Game.POCKET) {
			set(settings.pocket);
		} else if(info.game.type == HncomTypes.Game.MINECRAFT) {
			set(settings.minecraft);
		} else {
			error_log(translate(Translation("warning.invalidGame"), settings.language, [to!string(info.game.type), Software.name]));
		}
	}

	private shared void finishConstruction() {

		import core.cpuid : coresPerCPU, processor, threadsPerCPU;

		log(translate(Translation("startup.starting"), this.n_settings.language, [Text.green ~ Software.name ~ Text.white ~ " " ~ Software.fullVersion ~ Text.reset ~ " (" ~ Text.white ~ Software.codename ~ " " ~ Text.reset ~ Software.codenameEmoji ~ ")"]));

		static if(!__supported) {
			warning_log(translate(Translation("startup.unsupported"), this.n_settings.language, [Software.name]));
		}

		this.globalListener = new EventListener!WorldEvent();

		// default skins for players that connect with invalid skins
		Skin.STEVE = Skin("Standard_Steve", cast(ubyte[])std.file.read(Paths.skin ~ "Standard_Steve.bin"));
		Skin.ALEX = Skin("Standard_Alex", cast(ubyte[])std.file.read(Paths.skin ~ "Standard_Alex.bin"));

		// load creative inventories
		foreach(immutable protocol ; SupportedPocketProtocols) {
			string[] failed;
			if(this.settings.pocket.protocols.canFind(protocol)) {
				if(!mixin("PocketPlayerImpl!" ~ protocol.to!string ~ ".loadCreativeInventory()")) {
					failed ~= supportedPocketProtocols[protocol];
				}
			}
			if(failed.length) {
				warning_log(translate(Translation("warning.creativeFailed"), this.n_settings.language, [failed.join(", ")]));
			}
		}

		// create resource pack files
		string[] textures = [Paths.textures]; // ordered from least prioritised to most prioritised
		foreach_reverse(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			if(plugin.textures !is null) textures ~= plugin.textures;
		}
		if(textures.length > 1) {
			
			log(translate(Translation("startup.resourcePacks"), this.n_settings.language));

			auto rp_uuid = this.nextUUID;
			auto rp = createResourcePacks(this, rp_uuid, textures);
			std.concurrency.spawn(&serveResourcePacks, std.concurrency.thisTid, cast(string)rp.minecraft2.idup, cast(string)rp.minecraft3.idup);
			ushort port = std.concurrency.receiveOnly!ushort();

			auto ip = publicAddresses();
			//TODO also try to use local address before using 127.0.0.1

			MinecraftPlayer.updateResourcePacks(rp.minecraft2, rp.minecraft3, ip.v4.length ? ip.v4 : "127.0.0.1", port);
			PocketPlayer.updateResourcePacks(rp_uuid, rp.pocket1);

		}

		this.n_node_max = this.n_settings.maxPlayers;

		this.start_time = milliseconds;

		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			plugin.load();
			auto args = [
				Text.green ~ plugin.name ~ (plugin.api ? " + API" : "") ~ Text.reset,
				Text.white ~ (plugin.authors.length ? plugin.authors.join(Text.reset ~ ", " ~ Text.white) : "?") ~ Text.reset,
				Text.white ~ plugin.vers
			];
			log(translate(Translation("startup.plugin.enabled" ~ (!plugin.vers.startsWith("~") ? ".version" : (plugin.authors.length ? ".author" : ""))), this.n_settings.language, args));
		}

		// send node's informations to the hub and switch to a non-blocking connection
		HncomTypes.Game[] games;
		static if(supportedPocketProtocols.length) games ~= HncomTypes.Game(HncomTypes.Game.POCKET, supportedPocketProtocols.keys);
		static if(supportedMinecraftProtocols.length) games ~= HncomTypes.Game(HncomTypes.Game.MINECRAFT, supportedMinecraftProtocols.keys);
		HncomTypes.Plugin[] plugins;
		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			plugins ~= HncomTypes.Plugin(plugin.name, plugin.vers);
		}
		this.handler.send(new HncomLogin.NodeInfo(microseconds, this.n_node_max, games, plugins).encode());
		if(!this.lite) std.concurrency.spawn(&this.handler.receiveLoop, cast()this.tid);

		// call @start functions
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onstart) {
				del();
			}
		}
		
		if(this._default_world_id == 0) {
			this.addWorld("world");
		}
		
		version(Windows) {
			SetConsoleCtrlHandler(&sigHandler, true);
		} else version(linux) {
			sigset(SIGTERM, &extsig);
			sigset(SIGINT, &extsig);
		}

		log(translate(Translation("startup.started"), this.n_settings.language));

		if(this.lite) {
			// only send the message to the hub that will also send it to the connected
			// external consoles and rcon clients
			setLogger((string logger, string message, int worldId, int outputId){
				Handler.sharedInstance.send(new HncomStatus.Log(milliseconds, worldId, logger, message, outputId).encode());
			});
		} else {
			setLogger((string logger, string message, int worldId, int outputId){
				Handler.sharedInstance.send(new HncomStatus.Log(milliseconds, worldId, logger, message, outputId).encode());
				synchronized writeln("[" ~ logger ~ "] " ~ message);
			});
		}

		// start calculation of used resources
		std.concurrency.spawn(&startResourceUsageThread, getpid);

		// start command reader
		if(!this.lite) std.concurrency.spawn(&startCommandReaderThread, cast()this.tid);
		
		this.start();

	}

	private shared void start() {

		void delegate() receive;
		if(!this.lite) {
			receive = (){
				std.concurrency.receive(
					&handlePromptCommand,
					//TODO kick
					//TODO close result
					(immutable(ubyte)[] payload){
						// from the hub
						if(payload.length) {
							this.handleHncomPacket(payload[0], payload[1..$].dup);
						} else {
							//TODO close
							warning_log("received empty message from the hub");
						}
					},
				);
			};
		} else {
			receive = (){
				std.concurrency.receive(
					&handlePromptCommand,
					//TODO kick
					//TODO close result
					&handleUncompressedPacket,
					&handleCompressedPacket,
					&handleAddNodePacket,
					&handleRemoveNodePacket,
					&handleMessageClientboundPacket,
					&handlePlayersPacket,
					&handleRemoteCommandPacket,
					&handleReloadPacket,
					&handleAddPacket,
					&handleRemovePacket,
					&handleUpdateGamemodePacket,
					&handleUpdateInputModePacket,
					&handleUpdateLatencyPacket,
					&handleUpdatePacketLossPacket,
					&handleGamePacketPacket,
				);
			};
		}

		while(running) {

			// receive messages
			std.concurrency.receive(
				&this.handlePromptCommand,
				(immutable(ubyte)[] payload){
					// from the hub
					if(payload.length) {
						this.handleHncomPacket(payload[0], payload[1..$].dup);
					} else {
						//TODO close
						warning_log("received empty message from the hub");
					}
				},
				(const KickPlayer packet){

				},
				(const CloseResult packet){

				}
			);

			//TODO send logs to the hub

		}

		this.handler.close();

		// call @stop plugins
		foreach(plugin ; this.n_plugins) {
			foreach(void delegate() del ; (cast()plugin).onstop) {
				del();
			}
		}

		log(translate(Translation("startup.stopped"), this.n_settings.language, []));

		version(Windows) {
			// perform suicide
			executeShell("taskkill /PID " ~ to!string(getpid) ~ " /F");
		} else {
			import std.c.stdlib : exit;
			exit(0);
		}

	}

	/**
	 * Stops the server setting the running variable to false and kicks every
	 * player from the server.
	 */
	public shared void shutdown() {
		//foreach(player ; this.players_hubid) player.kick(message);
		running = false;
	}

	/**
	 * Gets the server's id, which is equal in the hub and all
	 * connected nodes.
	 * It is generated by SEL's snooping system or randomly if
	 * the service cannot be reached.
	 */
	public shared pure nothrow @property @safe @nogc immutable(long) id() {
		return this.n_id;
	}

	public shared pure nothrow @property @safe @nogc UUID nextUUID() {
		ubyte[16] data;
		data[0..8] = nativeToBigEndian(this.id);
		data[8..16] = nativeToBigEndian(this.uuid_count);
		atomicOp!"+="(this.uuid_count, 1);
		return UUID(data);
	}

	/**
	 * Gets the arguments the server has been launched with, excluding
	 * the ones used by sel or the manager.
	 * Example:
	 * ---
	 * // from command-line
	 * ./node --name=test -a -b -p=test
	 * assert(server.args == ["-a", "-b"]);
	 * 
	 * // from sel manager
	 * sel start test --name=test -a --loop -b
	 * assert(server.args == ["-a", "-b"]);
	 * ---
	 * Custom arguments can be used by plugins to load optional settings.
	 * Example:
	 * ---
	 * @start load() {
	 *    if(!server.args.canFind("--disable-example")) {
	 *       this.loadImpl();
	 *    }
	 * }
	 * ---
	 */
	public shared pure nothrow @property @safe @nogc const args() {
		return this.n_args;
	}

	/**
	 * Gets the server's settings.
	 * Example:
	 * ---
	 * // server name
	 * log("Welcome to ", server.settings.name);
	 * 
	 * // game version
	 * static if(__pocket) assert(server.settings.pocket);
	 * static if(__minecraft) log("Port for Minecraft: ", server.settings.minecraft.port); 
	 * ---
	 */
	public shared pure nothrow @property @trusted @nogc const(Config) settings() {
		return cast(const)this.n_settings;
	}

	/**
	 * Gets the server's name, as indicated in the hub's
	 * settings.txt file.
	 * The name should just the name of the server without
	 * any formatting code nor description.
	 * Example:
	 * ---
	 * "Potato Empire" // do
	 * "potato empire" // don't
	 * "Potato Empire: NEW MINIGAMES!" // don't
	 * "§aPotato §5Empire" // don't
	 * ---
	 */
	public shared pure nothrow @property @safe @nogc string name() {
		return this.n_settings.displayName;
	}
	
	/**
	 * Gets the number of online players in the current
	 * node (not in the whole server).
	 */
	public shared pure nothrow @property @safe @nogc size_t online() {
		return this._players.length;
	}

	/**
	 * Gets the maximum number of players that can connect on the
	 * current node (not in the whole server).
	 * If the value is 0 there's no limit.
	 */
	public shared pure nothrow @property @safe @nogc size_t max() {
		return this.n_node_max;
	}
	
	/**
	 * Gets the number of online players in the whole server
	 * (not just in the current node).
	 */
	public shared pure nothrow @property @safe @nogc size_t hubOnline() {
		return this.n_online;
	}
	
	/**
	 * Gets the number of maximum players that can connect to
	 * the hub.
	 * If the value is 0 it means that no limit has been set and
	 * players will never be kicked because the server is full.
	 */
	public shared pure nothrow @property @safe @nogc size_t hubMax() {
		return this.n_max;
	}

	/**
	 * Gets the current's node name.
	 */
	public shared pure nothrow @property @safe @nogc string nodeName() {
		return this.node_name;
	}

	/**
	 * Gets whether or not this is a main node (players are added
	 * when connected to hub) or not (player are added only when
	 * transferred by other nodes).
	 */
	public shared pure nothrow @property @safe @nogc bool isMainNode() {
		return this.node_main;
	}

	/**
	 * Gets the server's social informations like website and social
	 * networks names.
	 * Example:
	 * ---
	 * if(server.social.facebook.length) {
	 *    world.broadcast("Follow us on facebook! facebook.com/" ~ server.social.facebook);
	 * }
	 * ---
	 */
	public shared pure nothrow @property @safe @nogc const social() {
		return this.n_social;
	}

	/**
	 * Gets the server's website.
	 * Example:
	 * ---
	 * assert(server.website == server.social.website);
	 * ---
	 */
	public shared pure nothrow @property @safe @nogc string website() {
		return this.social.website;
	}

	/**
	 * Gets the address of the hub this node is connected to.
	 * Returns: the address of the hub connected to, or null if not connected yet
	 * Example:
	 * ---
	 * if(server.hubAddress.toAddrString() == "127.0.0.1") {
	 *    log("the hub is ipv4 localhost!");
	 * } else if(server.hubAddress.toAddrString() == "::1") {
	 *    log("The hub is ipv6 localhost!");
	 * }
	 * ---
	 */
	public shared pure nothrow @property @trusted @nogc Address hubAddress() {
		return cast()this.n_hub_address;
	}

	/**
	 * Gets the latency between the node and the hub.
	 */
	public shared pure nothrow @property @safe @nogc uint hubLatency() {
		return this.n_hub_latency;
	}

	/**
	 * Gets the server's uptime as a Duration instance with milliseconds precision.
	 * The count starts when the node is duccessfully connected with the hub.
	 * Example:
	 * ---
	 * d("The server is online from ", server.uptime.minutes, " minutes");
	 * 
	 * ulong m, s;
	 * server.uptime.split!("minutes", "seconds")(m, s);
	 * d("The server is online from ", m, " minutes and ", s, " seconds");
	 * ---
	 */
	public shared @property @safe Duration uptime() {
		return dur!"msecs"(milliseconds - this.start_time);
	}

	/+
	/**
	 * Gets the current memory (RAM and SWAP) usage.
	 * Example:
	 * ---
	 * if(server.ram.gigabytes >= mem!"GB"(1)) {
	 *    d("The server is using more than 1 GB of RAM!");
	 * }
	 * ---
	 */
	public @property @safe @nogc Memory ram() {
		return Memory(this.last_ram);
	}

	/**
	 * Gets the current CPU usage.
	 * Example:
	 * ---
	 * d("The server is using ", server.cpu, "% on ", totalCPUs, " CPUs");
	 * ---
	 */
	public pure nothrow @property @safe @nogc float cpu() {
		return this.last_cpu;
	}
	+/

	/**
	 * Gets a list with the nodes connected to the hub, this excluded.
	 * Example:
	 * ---
	 * foreach(node ; server.nodes) {
	 *    assert(node.name != server.nodeName);
	 * }
	 * ---
	 */
	public shared pure nothrow @property @trusted const(Node)[] nodes() {
		return cast(const(Node)[])this.nodes_hubid.values;
	}

	/**
	 * Gets a node by its name. It can be used to transfer players
	 * to it.
	 * Example:
	 * ---
	 * auto lobby = server.nodeWithName("lobby");
	 * if(lobby !is null) lobby.transfer(player);
	 * ---
	 */
	public shared inout pure nothrow @trusted const(Node) nodeWithName(string name) {
		auto ret = name in this.nodes_names;
		return ret ? cast(const)*ret : null;
	}

	/**
	 * Gets a node by its hub id, which is given by the hub and
	 * unique for every session.
	 */
	public shared inout pure nothrow @trusted const(Node) nodeWithHubId(uint hubId) {
		auto ret = hubId in this.nodes_hubid;
		return ret ? cast(const)*ret : null;
	}

	/**
	 * Sends a message to a node.
	 */
	public shared void sendMessage(Node[] nodes, ubyte[] payload) {
		uint[] addressees;
		foreach(node ; nodes) {
			if(node !is null) addressees ~= node.hubId;
		}
		this.handler.send(new HncomStatus.MessageServerbound(addressees, payload).encode());
	}

	/// ditto
	public shared void sendMessage(Node node, ubyte[] payload) {
		this.sendMessage([node], payload);
	}

	/**
	 * Broadcasts a message to every node connected to the hub.
	 */
	public shared void broadcast(ubyte[] payload) {
		this.sendMessage([], payload);
	}

	/**
	 * Gets the plugins actived on the server.
	 * Example:
	 * ---
	 * log("There are ", server.plugins.filter!(a => a.author == "sel-plugins").length, " by sel-plugins");
	 * log("There are ", server.plugins.filter!(a => a.api).length, " plugins with APIs");
	 * ---
	 */
	public shared pure nothrow @property @trusted @nogc const(Plugin)[] plugins() {
		return cast(const(Plugin)[])this.n_plugins;
	}

	/**
	 * Gets the server's default world.
	 */
	public shared pure nothrow @property const(WorldInfo) world() {
		return cast(const)this._worlds[this._default_world_id];
	}

	/**
	 * Sets the server's default world if the given world has been
	 * created and registered using the addWorld template method.
	 * Returns: The server's default world (the given world if it has been set as default)
	 * Example:
	 * ---
	 * auto test = server.addWorld!Test("test-world");
	 * server.world = test;
	 * assert(server.world == test);
	 * ---
	 */
	public shared pure nothrow @property const(WorldInfo) world(uint id) {
		assert(id != 0);
		if(id in this._worlds) {
			this._default_world_id = id;
		}
		return this.world;
	}

	/// ditto
	public shared pure nothrow @property const(WorldInfo) world(inout WorldInfo world) {
		return this.world = world.id;
	}

	/**
	 * Gets a list with every world registered in the server.
	 * The list is a copy of the one kept by the server and its
	 * modification has no effect on the server.
	 */
	public shared pure nothrow @property const(WorldInfo)[] worlds() {
		return cast(const(WorldInfo)[])this._worlds.values;
	}

	/**
	 * Creates and registers a world, initialising its terrain,
	 * registering events, commands and tasks.
	 * Example:
	 * ---
	 * server.addWorld("world42"); // normal world
	 * server.addWorld!CustomWorld(42); // custom world where 42 is passed to the constructor
	 * ---
	 */
	public shared synchronized shared(WorldInfo) addWorld(T:World=World, E...)(E args) /*if(__traits(compiles, new T(args)))*/ {
		shared WorldInfo world = cast(shared)new WorldInfo(atomicOp!"+="(this._world_count, 1));
		this._worlds[world.id] = world;
		if(this._default_world_id == 0) this._default_world_id = world.id;
		world.tid = cast(shared)std.concurrency.spawn(&spawnWorld!(T, E), cast(shared)this, world, args);
		return world;
	}

	/**
	 * Removes a world and unloads it.
	 * When trying to remove the default world a message error will be
	 * displayed and the world will not be unloaded.
	 */
	public shared synchronized bool removeWorld(uint id) {
		auto world = id in this._worlds;
		if(world) {
			if((*world).id == this._default_world_id) {
				warning_log(translate(Translation("warning.removingDefaultWorld"), this.n_settings.language));
			} else {
				std.concurrency.send(cast()world.tid, Close());
				return true;
			}
		}
		return false;
	}

	/// ditto
	public shared bool removeWorld(WorldInfo world) {
		return this.removeWorld(world.id);
	}

	/**
	 * Gets a list with all the players in the server.
	 */
	public shared pure nothrow @property const(PlayerInfo)[] players() {
		return cast(const(PlayerInfo)[])this._players.values;
	}

	/**
	 * Broadcasts a message in every registered world and their children
	 * calling the world's broadcast method.
	 */
	public shared void broadcast(E...)(E args) {
		foreach(world ; this._worlds) {
			std.concurrency.send(world.tid, Broadcast(args.to!string, true));
		}
	}

	/**
	 * Registers a command.
	 */
	public void registerCommand(alias func)(void delegate(Parameters!func) del, string command, string description, string[] aliases, bool op, bool hidden) {
		command = command.toLower;
		if(command !in this.commands) this.commands[command] = cast(shared)new Command(command, description, aliases, op, hidden);
		auto ptr = command in this.commands;
		(cast()*ptr).add!func(del);
	}

	public shared @property Command[] registeredCommands() {
		return cast(Command[])this.commands.values;
	}
	
	protected override void sendMessageImpl(string message) {
		log(message);
	}
	
	protected override void sendTranslationImpl(const Translation message, string[] args, Text[] formats) {
		log(join(cast(string[])formats, ""), translate(message, this.n_settings.language, args));
	}

	// hub-node communication and related methods

	public shared bool changePlayerLanguage(uint hubId, string language) {
		auto player = hubId in this._players;
		if(player) {
			if(language == (*player).language || !this.n_settings.acceptedLanguages.canFind(language) || (cast()this).callCancellableIfExists!PlayerLanguageUpdatedEvent(cast(const)*player, language)) return false;
			(*player).language = language;
			this.handler.send(new HncomPlayer.UpdateLanguage(hubId, language).encode());
			return true;
		} else {
			return false;
		}
	}
	
	public shared void updatePlayerDisplayName(uint hubId) {
		auto player = hubId in this._players;
		if(player) this.handler.send(new HncomPlayer.UpdateDisplayName(hubId, (*player).displayName).encode());
	}

	/*
	 * Kicks a player from the server using Player.kick.
	 */
	public shared void kick(uint hubId, string reason) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.kicked)) {
			this.handler.send(new HncomPlayer.Kick(hubId, reason, false).encode());
		}
	}

	/// ditto
	public shared void kick(uint hubId, string reason, string[] args) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.kicked)) {
			this.handler.send(new HncomPlayer.Kick(hubId, reason, true, args).encode());
		}
	}

	/*
	 * Transfers a player to another node using Player.transfer
	 */
	public shared void transfer(uint hubId, inout Node node) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.transferred)) {
			this.handler.send(new HncomPlayer.Transfer(hubId, node.hubId).encode());
		}
	}

	// removes with a reason a player spawned in the server
	private shared synchronized bool removePlayer(uint hubId, ubyte reason) {
		auto player = hubId in this._players;
		if(player) {
			if((*player).world !is null) {
				std.concurrency.send(cast()(*player).world.tid, RemovePlayer(hubId));
			}
			this._players.remove(hubId);
			(cast()this).callEventIfExists!PlayerLeftEvent(cast(const)*player, reason);
			return true;
		} else {
			return false;
		}
	}

	private shared void handleHncomPacket(ubyte id, ubyte[] data) {
		switch(id) {
			foreach(P ; TypeTuple!(HncomUtil.Packets, HncomStatus.Packets, HncomPlayer.Packets, HncomWorld.Packets)) {
				static if(P.CLIENTBOUND) {
					case P.ID: mixin("return this.handle" ~ P.stringof ~ "Packet(P.fromBuffer!false(data));");
				}
			}
			default: error_log("Unknown packet received from the hub with id ", id, " and ", data.length, " bytes of data");
		}
	}

	private shared void handleUncompressedPacket(inout HncomUtil.Uncompressed packet) {
		foreach(p ; packet.packets) {
			if(p.length) this.handleHncomPacket(p[0], p[1..$].dup);
		}
	}

	private shared void handleCompressedPacket(inout HncomUtil.Compressed packet) {
		auto uc = new UnCompress(packet.size);
		ubyte[] data = cast(ubyte[])uc.uncompress(packet.payload);
		data ~= cast(ubyte[])uc.flush();
		this.handleUncompressedPacket(HncomUtil.Uncompressed.fromBuffer!false(data));
	}

	/*
	 * Adds (or update) a node.
	 */
	private shared void handleAddNodePacket(inout HncomStatus.AddNode packet) {
		auto node = new Node(this, packet.hubId, packet.name, packet.main);
		foreach(accepted ; packet.acceptedGames) node.acceptedGames[accepted.type] = cast(uint[])accepted.protocols;
		this.nodes_hubid[node.hubId] = cast(shared)node;
		this.nodes_names[node.name] = cast(shared)node;
		(cast()this).callEventIfExists!NodeAddedEvent(node);
	}

	/**
	 * Removes a node.
	 */
	private shared void handleRemoveNodePacket(inout HncomStatus.RemoveNode packet) {
		auto node = packet.hubId in this.nodes_hubid;
		if(node) {
			this.nodes_hubid.remove((*node).hubId);
			this.nodes_names.remove((*node).name);
			(cast()this).callEventIfExists!NodeRemovedEvent(cast()*node);
		}
	}

	/*
	 * Handles a message sent or broadcasted from another node.
	 */
	private shared void handleMessageClientboundPacket(inout HncomStatus.MessageClientbound packet) {
		auto node = this.nodeWithHubId(packet.sender);
		// only accept message from nodes that didn't disconnect
		if(node !is null) {
			(cast()this).callEventIfExists!NodeMessageEvent(cast()node, cast(ubyte[])packet.payload);
		}
	}
	
	/*
	 * Updates the number of online and max players in the whole
	 * server (not the current node).
	 */
	private shared void handlePlayersPacket(inout HncomStatus.Players packet) {
		this.n_online = packet.online;
		this.n_max = packet.max;
	}

	/*
	 * Handles a command sent by the hub or an external application.
	 */
	private shared void handleRemoteCommandPacket(inout HncomStatus.RemoteCommand packet) {
		with(packet) this.handleCommand(cast(ubyte)(origin + 1), convertAddress(cast()sender), command, commandId);
	}

	/**
	 * Reloads the configurations.
	 */
	private shared void handleReloadPacket(inout HncomStatus.Reload packet) {
		// only reload plugins, not settings
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onreload) del();
		}
	}

	/*
	 * Adds a player to the node.
	 */
	private shared void handleAddPacket(inout HncomPlayer.Add packet) {

		Address address = convertAddress(cast()packet.clientAddress);
		Skin skin = Skin(packet.skin.name, cast(ubyte[])packet.skin.data);

		if(!skin.valid) {
			// http://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/UUID.java#l394
			ubyte a = packet.uuid.data[7] ^ packet.uuid.data[15];
			ubyte b = (packet.uuid.data[3] ^ packet.uuid.data[11]) ^ a;
			skin = ((b & 1) == 0) ? Skin.STEVE : Skin.ALEX;
		}

		shared PlayerInfo player = cast(shared)new PlayerInfo(packet.hubId, packet.type, packet.protocol, packet.vers, packet.username, packet.displayName, packet.uuid, address, packet.serverAddress, packet.serverPort, packet.language);
		player.skin = skin;

		(){
			final switch(packet.type) {
				foreach(Variant ; HncomPlayer.Add.Variants) {
					case Variant.TYPE:
						mixin("player.additional." ~ toLower(Variant.stringof)) = cast(shared)packet.new inout Variant();
						return;
				}
			}
		}();

		//TODO register global commands

		// add to the lists
		this._players[player.hubId] = cast(shared)player;

		auto event = (cast()this).callEventIfExists!PlayerJoinEvent(cast(const)player, packet.reason);

		//TODO allow kicking from event

		shared(WorldInfo)* world;
		if(event is null || event.world is null) {
			world = this._default_world_id in this._worlds;
		} else {
			assert((*event.world).id in this._worlds);
			world = event.world;
		}

		// do not spawn if it has been disconnected during the event
		if(player.hubId in this._players) {

			std.concurrency.send(cast()(*world).tid, AddPlayer(player));

		}

	}

	/*
	 * Removes a player from a node.
	 * This packet is not sent when a player is moved away from this
	 * node with a Transfer or a Kick packet.
	 */
	private shared void handleRemovePacket(inout HncomPlayer.Remove packet) {
		this.removePlayer(packet.hubId, packet.reason);
	}
	
	private shared void handleUpdateGamemodePacket(inout HncomPlayer.UpdateGamemode packet) {
		//TODO
	}
	
	/*
	 * Updates a player's input mode.
	 */
	private shared void handleUpdateInputModePacket(inout HncomPlayer.UpdateInputMode packet) {
		//TODO
	}

	/*
	 * Updates a player's latency.
	 * The value given in the packet represents the latency between the hub
	 * and player, so an additional latency is added (the one between the node
	 * and the hub) is added to obtain a more precise value.
	 */
	private shared void handleUpdateLatencyPacket(inout HncomPlayer.UpdateLatency packet) {
		//TODO
	}

	/*
	 * Updates a player's packet loss thanks to hub's calculations.
	 */
	private shared void handleUpdatePacketLossPacket(inout HncomPlayer.UpdatePacketLoss packet) {
		//TODO
	}
	
	/*
	 * Elaborates raw game data sent by a client.
	 */
	private shared void handleGamePacketPacket(inout HncomPlayer.GamePacket packet) {
		auto player = packet.hubId in this._players;
		if(player && packet.packet.length) {
			std.concurrency.send(cast()(*player).world.tid, GamePacket(packet.hubId, packet.packet.idup));
		}
	}

	private shared void handleUpdateDifficultyPacket(inout HncomWorld.UpdateDifficulty packet) {
		//TODO
	}

	private shared void handleUpdateGamemodePacket(inout HncomWorld.UpdateGamemode packet) {
		//TODO
	}

	private shared void handleRequestCreationPacket(inout HncomWorld.RequestCreation packet) {
		//TODO
	}

	private shared void handlePromptCommand(string command) {
		this.handleCommand(0, null, command);
	}

	// handles a command from various sources.
	private shared void handleCommand(ubyte origin, Address address, string command, int id=-1) {
		auto sender = new ServerCommandSender(this, origin, address, id);
		string found;
		foreach(_c ; this.commands) {
			auto c = cast()_c;
			foreach(cname ; c.command ~ c.aliases) {
				if(command.startsWith(cname)) {
					if(c.call(sender, command[cname.length..$])) return;
					else found = cname;
				}
			}
		}
		if(found) {
			(cast()this).callEventIfExists!InvalidParametersEvent(sender, found);
		} else {
			(cast()this).callEventIfExists!UnknownCommandEvent(sender);
		}
	}

}

class ServerCommandSender : CommandSender {

	enum Origin : ubyte {

		prompt = 0,
		hub = HncomStatus.RemoteCommand.HUB,
		externalConsole = HncomStatus.RemoteCommand.EXTERNAL_CONSOLE,
		rcon = HncomStatus.RemoteCommand.RCON,

	}

	public shared Server server;
	public immutable ubyte origin;
	public const Address address;
	private int id;

	public this(shared Server server, ubyte origin, Address address, int id) {
		this.server = server;
		this.origin = origin;
		this.address = address;
		this.id = id;
	}
	
	public override EntityPosition position() {
		return EntityPosition(0);
	}
	
	public override Entity[] visibleEntities() {
		return [];
	}

	public override Player[] visiblePlayers() {
		return [];
	}

	protected override void sendMessageImpl(string message) {
		logImpl("command", -1, this.id, message);
	}

	protected override void sendTranslationImpl(const Translation translation, string[] args, Text[] formats) {
		logImpl("command", -1, this.id, join(cast(string[])formats, ""), translate(translation, cast()this.server.settings.language, args));
	}

	alias server this;

}

private void startResourceUsageThread(int pid) {

	Thread.getThis().name = "ResourcesUsage";
	
	ProcessMemInfo ram = processMemInfo(pid);
	ProcessCPUWatcher cpu = new ProcessCPUWatcher(pid);
	
	while(true) {
		ram.update();
		log("ram: ", ram.usedRAM);
		log("cpu: ", cpu.current());
		//TODO send packet directly to the socket
		Handler.sharedInstance.send(new HncomStatus.ResourcesUsage(20, ram.usedRAM, cpu.current()).encode());
		Thread.sleep(dur!"seconds"(5));
	}
	
}

private void startCommandReaderThread(std.concurrency.Tid tid) {

	Thread.getThis().name = "CommandReader";

	import std.stdio : readln;
	while(true) {
		std.concurrency.send(tid, readln());
	}

}

private Address convertAddress(HncomTypes.Address address) {
	if(address.bytes.length == 4) {
		ubyte[4] bytes = address.bytes;
		return new InternetAddress(bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3], address.port);
	} else if(address.bytes.length == 16) {
		ubyte[16] bytes = address.bytes;
		return new Internet6Address(bytes, address.port);
	} else {
		return new InternetAddress(0, 0);
	}
}
