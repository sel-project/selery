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
module selery.node.server;

import core.atomic : atomicOp;
import core.thread : getpid, Thread;

import std.algorithm : canFind, sort, clamp, min;
import std.ascii : newline;
import std.bitmanip : nativeToBigEndian;
static import std.concurrency;
import std.conv : to;
import std.datetime : dur, StopWatch, Duration;
static import std.file;
import std.json;
import std.math : round, ceil;
import std.process : executeShell;
import std.socket : SocketException, Address, InternetAddress, Internet6Address;
import std.string;
import std.typetuple : TypeTuple;
import std.traits : Parameters;
import std.uuid : UUID;
import std.zlib : UnCompress;

import imageformats.png : read_png_from_mem;

import resusage.memory;
import resusage.cpu;

import sel.hncom.about;
import sel.hncom.handler : HncomHandler;

import selery.world.world : World; // do not move this import down

import selery.about;
import selery.command.command : Command, CommandSender, WorldCommandSender;
import selery.config : Config;
import selery.entity.entity : Entity;
import selery.entity.human : Skin;
import selery.event.event : Event, EventListener;
import selery.event.server.server : ServerEvent;
import selery.event.server;
import selery.event.world.world : WorldEvent;
import selery.format : Text, writeln;
import selery.lang : Lang, Translation, Message, Messageable;
import selery.log;
import selery.math.vector : EntityPosition;
import selery.network.hncom;
import selery.network.http : serveResourcePacks;
import selery.node.info : PlayerInfo, WorldInfo;
import selery.player.minecraft : MinecraftPlayer;
import selery.player.player : Player, InputMode;
import selery.player.pocket : PocketPlayer, PocketPlayerImpl;
import selery.plugin : Plugin;
import selery.server : Server;
import selery.util.ip : publicAddresses;
import selery.util.memory : Memory;
import selery.util.node : Node;
import selery.util.resourcepack : createResourcePacks;
import selery.util.tuple : Tuple;
import selery.util.util : milliseconds, microseconds;
import selery.world.rules : Rules;
import selery.world.thread;

import HncomLogin = sel.hncom.login;
import HncomUtil = sel.hncom.util;
import HncomStatus = sel.hncom.status;
import HncomPlayer = sel.hncom.player;

// the signal could be handled on another thread!
private shared bool running = true;
private shared bool stoppedWithSignal = false;

private shared std.concurrency.Tid server_tid;

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
			std.concurrency.send(cast()server_tid, Stop());
			return true; // this will let the process run in background until it kills himself
		}
		return false; // windows will instantly kill the process
	}

} else version(Posix) {

	import core.sys.posix.signal;

	extern (C) void extsig(int sig) {
		std.concurrency.send(cast()server_tid, Stop());
	}

}

private struct Stop {}

/**
 * Singleton for the server instance.
 */
final class NodeServer : EventListener!ServerEvent, Server, HncomHandler!clientbound {

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

	private shared Config _config;

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

	public shared this(Address hub, string name, string password, bool main, Config config, Plugin[] plugins=[], string[] args=[]) {

		assert(config.node !is null);

		debug Thread.getThis().name = "NodeServer";

		this.lite = cast(TidAddress)hub !is null;

		this.node_name = name;
		this.node_main = main;

		this.n_plugins = cast(shared)plugins;

		this.n_args = cast(shared)args;

		this.tid = server_tid = cast(shared)std.concurrency.thisTid;
		
		this.n_hub_address = cast(shared)hub;

		config.hub = new Config.Hub();

		// load language from the last execution (or default language)
		if(config.files.hasTemp("lang")) {
			config.hub.language = cast(string)config.files.readTemp("lang");
		} else {
			config.hub.language = "en_GB";
		}
		//config.hub.acceptedLanguages = [config.hub.language];
		config.lang.load(config.hub.language, [config.hub.language]);

		this._config = cast(shared)config;

		if(lite) {

			this.handler = new shared MessagePassingHandler(cast(shared TidAddress)hub);
			this.handleInfoImpl(cast()std.concurrency.receiveOnly!(shared HncomLogin.HubInfo)());

		} else {

			log(config.lang.translate("startup.connecting", [to!string(hub), name]));

			try {
				this.handler = new shared SocketHandler(hub);
				this.handler.send(HncomLogin.ConnectionRequest(password, name, main).encode());
			} catch(SocketException e) {
				error_log(config.lang.translate("warning.connectionError", [to!string(hub), e.msg]));
				return;
			}

			// wait for ConnectionResponse
			ubyte[] buffer = this.handler.receive();
			if(buffer.length && buffer[0] == HncomLogin.ConnectionResponse.ID) {
				auto response = HncomLogin.ConnectionResponse.fromBuffer(buffer[1..$]);
				if(response.status == HncomLogin.ConnectionResponse.OK) {
					this.handleInfo();
				} else {
					immutable reason = (){
						switch(response.status) with(HncomLogin.ConnectionResponse) {
							case OUTDATED_HUB: return "outdatedHub";
							case OUTDATED_NODE: return "outdatedNode";
							case PASSWORD_REQUIRED: return "passwordRequired";
							case WRONG_PASSWORD: return "wrongPassword";
							case INVALID_NAME_LENGTH: return "invalidNameLength";
							case INVALID_NAME_CHARACTERS: return "invalidNameCharacters";
							case NAME_ALREADY_USED: return "nameAlreadyUsed";
							case NAME_RESERVED: return "nameReserved";
							default: return "unknown";
						}
					}();
					error_log(config.lang.translate("status." ~ reason));
					if(response.status == HncomLogin.ConnectionResponse.OUTDATED_HUB || response.status == HncomLogin.ConnectionResponse.OUTDATED_NODE) {
						error_log(config.lang.translate("warning.protocolRequired", [to!string(__PROTOCOL__), to!string(response.protocol)]));
					}
				}
			} else {
				error_log(config.lang.translate("warning.refused"));
			}

			this.handler.close();

		}
		
	}

	private shared void handleInfo() {

		ubyte[] buffer = this.handler.receive();
		if(buffer.length && buffer[0] == HncomLogin.HubInfo.ID) {
			this.handleInfoImpl(HncomLogin.HubInfo.fromBuffer(buffer[1..$]));
		} else {
			error_log(this.config.lang.translate("warning.closed"));
		}

	}

	private shared void handleInfoImpl(HncomLogin.HubInfo info) {

		Config config = cast()this._config;

		this.n_id = info.serverId;
		this.uuid_count = info.reservedUUIDs;

		if(info.additionalJSON.type != JSON_TYPE.OBJECT) info.additionalJSON = parseJSON("{}");

		auto minecraft = "minecraft" in info.additionalJSON;
		if(minecraft && minecraft.type == JSON_TYPE.OBJECT) {
			auto edu = "edu" in *minecraft;
			auto realm = "realm" in *minecraft;
			config.hub.edu = edu && edu.type == JSON_TYPE.TRUE;
			config.hub.realm = realm && realm.type == JSON_TYPE.TRUE;
		}

		Rules.reload(config.node);

		config.hub.displayName = info.displayName;
		config.hub.language = info.language;
		config.hub.acceptedLanguages = info.acceptedLanguages;

		//TODO validate languages

		this.n_online = info.online;
		this.n_max = info.max;

		auto social = "social" in info.additionalJSON;
		if(social && social.type == JSON_TYPE.OBJECT) {
			if("website" in *social) this.n_social.website = (*social)["website"].str;
			if("facebook" in *social) this.n_social.facebook = (*social)["facebook"].str;
			if("twitter" in *social) this.n_social.twitter = (*social)["twitter"].str;
			if("youtube" in *social) this.n_social.youtube = (*social)["youtube"].str;
			if("instagram" in *social) this.n_social.instagram = (*social)["instagram"].str;
			if("google-plus" in *social) this.n_social.googlePlus = (*social)["google-plus"].str;
		}

		// save latest language used
		config.files.writeTemp("lang", config.hub.language);

		version(Windows) {
			if(!this.lite) executeShell("title " ~ info.displayName ~ " ^| node ^| " ~ Software.name ~ " " ~ Software.fullVersion);
		}

		// reload languages
		config.lang.load(config.hub.language, config.hub.acceptedLanguages);
		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			if(plugin.languages !is null) config.lang.add(plugin.languages);
		}

		void handleGameInfo(ubyte type, HncomLogin.HubInfo.GameInfo info) {
			void set(ref Config.Hub.Game game) {
				game.enabled = true;
				game.protocols = info.protocols;
				game.motd = info.motd;
				game.onlineMode = info.onlineMode;
				game.port = info.port;
			}
			if(type == __JAVA__) {
				set(config.hub.minecraft);
			} else if(type == __POCKET__) {
				set(config.hub.pocket);
			} else {
				error_log(config.lang.translate("warning.invalidGame", [to!string(type), Software.name]));
			}
		}

		foreach(game, info ; info.gamesInfo) {
			handleGameInfo(game, info);
		}

		// check protocols and print warnings if necessary
		void check(string name, uint[] requested, uint[] supported) {
			foreach(req ; requested) {
				if(!supported.canFind(req)) {
					warning_log(config.lang.translate("warning.invalidProtocol", [to!string(req), name]));
				}
			}
		}

		check("Minecraft", config.hub.minecraft.protocols, supportedMinecraftProtocols.keys);
		check("Minecraft: Pocket Edition", config.hub.pocket.protocols, supportedPocketProtocols.keys);

		this._config = cast(shared)config;

		this.finishConstruction();

	}

	private shared void finishConstruction() {

		import core.cpuid : coresPerCPU, processor, threadsPerCPU;

		if(!this.lite) log(this.config.lang.translate("startup.starting", [Text.green ~ Software.name ~ Text.white ~ " " ~ Software.fullVersion ~ Text.reset ~ " " ~ Software.fullCodename]));

		static if(!__supported) {
			warning_log(this.config.lang.translate("startup.unsupported", [Software.name]));
		}

		this.globalListener = new EventListener!WorldEvent();

		// default skins for players that connect with invalid skins
		Skin.STEVE = Skin("Standard_Steve", read_png_from_mem(cast(ubyte[])this.config.files.readAsset("skin/steve.png")).pixels);
		Skin.ALEX = Skin("Standard_Alex", read_png_from_mem(cast(ubyte[])this.config.files.readAsset("skin/alex.png")).pixels);

		// load creative inventories
		foreach(immutable protocol ; SupportedPocketProtocols) {
			string[] failed;
			if(this.config.hub.pocket.protocols.canFind(protocol)) {
				if(!mixin("PocketPlayerImpl!" ~ protocol.to!string).loadCreativeInventory(this.config.files)) {
					failed ~= supportedPocketProtocols[protocol];
				}
			}
			if(failed.length) {
				warning_log(this.config.lang.translate("warning.creativeFailed", [failed.join(", ")]));
			}
		}

		// create resource pack files
		string[] textures = []; // ordered from least prioritised to most prioritised
		foreach_reverse(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			if(plugin.textures !is null) textures ~= plugin.textures;
		}
		if(textures.length) {
			
			log(this.config.lang.translate("startup.resourcePacks"));

			auto rp_uuid = this.nextUUID;
			auto rp = createResourcePacks(this, rp_uuid, textures);
			std.concurrency.spawn(&serveResourcePacks, std.concurrency.thisTid, cast(string)rp.minecraft2.idup, cast(string)rp.minecraft3.idup);
			ushort port = std.concurrency.receiveOnly!ushort();

			auto ip = publicAddresses(this.config.files);
			//TODO also try to use local address before using 127.0.0.1

			MinecraftPlayer.updateResourcePacks(rp.minecraft2, rp.minecraft3, ip.v4.length ? ip.v4 : "127.0.0.1", port);
			PocketPlayer.updateResourcePacks(rp_uuid, rp.pocket1);

		}

		this.start_time = milliseconds;

		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			plugin.load(this);
			auto args = [
				Text.green ~ plugin.name ~ (plugin.api ? " + API" : "") ~ Text.reset,
				Text.white ~ (plugin.authors.length ? plugin.authors.join(Text.reset ~ ", " ~ Text.white) : "?") ~ Text.reset,
				Text.white ~ plugin.vers
			];
			log(this.config.lang.translate("startup.plugin.enabled" ~ (!plugin.vers.startsWith("~") ? ".version" : (plugin.authors.length ? ".author" : "")), args));
		}

		// send node's informations to the hub and switch to a non-blocking connection
		HncomLogin.NodeInfo nodeInfo;
		uint[][ubyte] games;
		if(this.config.node.minecraft) nodeInfo.acceptedGames[__JAVA__] = cast(uint[])this.config.node.minecraft.protocols;
		if(this.config.node.pocket) nodeInfo.acceptedGames[__POCKET__] = cast(uint[])this.config.node.pocket.protocols;
		nodeInfo.max = this.config.node.maxPlayers; // 0 for unlimited, like in the config file
		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			nodeInfo.plugins ~= HncomLogin.NodeInfo.Plugin(plugin.name, plugin.vers);
		}
		if(this.lite) {
			std.concurrency.send(cast()(cast(shared MessagePassingHandler)this.handler).hub, cast(shared)nodeInfo);
		} else {
			this.handler.send(nodeInfo.encode());
		}
		if(!this.lite) std.concurrency.spawn(&this.handler.receiveLoop, cast()this.tid);

		// register help command if enabled in the settings
		if(this.config.node.helpCommand) {
			auto command = new Command("help", Message(Translation("commands.help.description")));
			auto _this = cast()this;
			command.add!helpCommand(&_this.helpCommand);				// ServerCommandSender
			command.add!helpCommandByPage(&_this.helpCommandByPage);	// WorldCommandSender
			command.add!helpCommandByName(&_this.helpCommandByName);	// Player
			this.commands["help"] = cast(shared)command;
		}

		// call @start functions
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onstart) {
				del();
			}
		}
		
		if(this._default_world_id == 0) {
			//TODO load world in worlds/world
			this.addWorld("world");
		}
		
		version(Windows) {
			SetConsoleCtrlHandler(&sigHandler, true);
		} else version(linux) {
			sigset(SIGTERM, &extsig);
			sigset(SIGINT, &extsig);
		}

		log(this.config.lang.translate("startup.started"));

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
		
		//TODO request first latency calculation

		while(running) {

			// receive messages
			std.concurrency.receive(
				&handlePromptCommand,
				//TODO kick (wolrd)
				//TODO close result (world)
				(immutable(ubyte)[] payload){
					// from the hub
					if(payload.length) {
						(cast()this).handleHncom(payload.dup);
					} else {
						// close
						running = false;
					}
				},
				(Stop stop){
					running = false;
				},
			);
			
		}
		
		this.handler.close();

		// call @stop plugins
		foreach(plugin ; this.n_plugins) {
			foreach(void delegate() del ; (cast()plugin).onstop) {
				del();
			}
		}

		log(this.config.lang.translate("startup.stopped"));

		/*version(Windows) {
			// perform suicide
			executeShell("taskkill /PID " ~ to!string(getpid) ~ " /F");
		} else {*/
			import std.c.stdlib : exit;
			exit(0);
		//}

	}

	/**
	 * Stops the server setting the running variable to false and kicks every
	 * player from the server.
	 */
	public shared void shutdown() {
		std.concurrency.send(cast()server_tid, Stop());
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

	public shared pure nothrow @property @nogc UUID nextUUID() {
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

	public override shared pure nothrow @property @trusted @nogc const(Config) config() {
		return cast()this._config;
	}

	public override shared pure nothrow @property @trusted @nogc const(Plugin)[] plugins() {
		return cast(const(Plugin)[])this.n_plugins;
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
		return this._config.hub.displayName;
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
		return this._config.node.maxPlayers;
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
		this.handler.send(HncomStatus.SendMessage(addressees, payload).encode());
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
				warning_log(this.config.lang.translate("warning.removingDefaultWorld"));
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
	public void registerCommand(alias func)(void delegate(Parameters!func) del, string command, Message description, string[] aliases, bool op, bool hidden) {
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
		log(join(cast(string[])formats, ""), (cast(shared)this).config.lang.translate(message, args));
	}

	// hub-node communication and related methods

	public shared bool changePlayerLanguage(uint hubId, string language) {
		auto player = hubId in this._players;
		if(player) {
			if(language == (*player).language || !this.config.hub.acceptedLanguages.canFind(language) || (cast()this).callCancellableIfExists!PlayerLanguageUpdatedEvent(cast(const)*player, language)) return false;
			(*player).language = language;
			this.handler.send(HncomPlayer.UpdateLanguage(hubId, language).encode());
			return true;
		} else {
			return false;
		}
	}
	
	public shared void updatePlayerDisplayName(uint hubId) {
		auto player = hubId in this._players;
		if(player) this.handler.send(HncomPlayer.UpdateDisplayName(hubId, (*player).displayName).encode());
	}

	/*
	 * Kicks a player from the server using Player.kick.
	 */
	public shared void kick(uint hubId, string reason) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.kicked)) {
			this.handler.send(HncomPlayer.Kick(hubId, reason, false).encode());
		}
	}

	/// ditto
	public shared void kick(uint hubId, string reason, string[] args) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.kicked)) {
			this.handler.send(HncomPlayer.Kick(hubId, reason, true, args).encode());
		}
	}

	/*
	 * Transfers a player to another node using Player.transfer
	 */
	public shared void transfer(uint hubId, inout Node node) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.transferred)) {
			this.handler.send(HncomPlayer.Transfer(hubId, node.hubId).encode());
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

	/*private shared void handleHncomPacket(ubyte id, ubyte[] data) {
		switch(id) {
			foreach(P ; TypeTuple!(HncomUtil.Packets, HncomStatus.Packets, HncomPlayer.Packets, HncomWorld.Packets)) {
				static if(P.CLIENTBOUND) {
					case P.ID: mixin("return this.handle" ~ P.stringof ~ "Packet(P.fromBuffer!false(data));");
				}
			}
			default: error_log("Unknown packet received from the hub with id ", id, " and ", data.length, " bytes of data");
		}
	}*/

	protected override void handleUtilUncompressed(HncomUtil.Uncompressed packet) {
		assert(packet.id == 0); //TODO
		foreach(p ; packet.packets) {
			if(p.length) this.handleHncom(p.dup);
		}
	}

	protected override void handleUtilCompressed(HncomUtil.Compressed packet) {
		this.handleUtilUncompressed(packet.uncompress());
	}

	protected override void handleStatusLatency(HncomStatus.Latency packet) {
		//TODO send packet back
	}

	protected override void handleStatusReload(HncomStatus.Reload packet) {
		//TODO update settings
		// only reload plugins, not settings
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onreload) del();
		}
	}

	protected override void handleStatusAddNode(HncomStatus.AddNode packet) {
		auto node = new Node(cast(shared)this, packet.hubId, packet.name, packet.main, packet.acceptedGames);
		this.nodes_hubid[node.hubId] = cast(shared)node;
		this.nodes_names[node.name] = cast(shared)node;
		this.callEventIfExists!NodeAddedEvent(node);
	}

	protected override void handleStatusRemoveNode(HncomStatus.RemoveNode packet) {
		auto node = packet.hubId in this.nodes_hubid;
		if(node) {
			this.nodes_hubid.remove((*node).hubId);
			this.nodes_names.remove((*node).name);
			this.callEventIfExists!NodeRemovedEvent(cast()*node);
		}
	}

	protected override void handleStatusReceiveMessage(HncomStatus.ReceiveMessage packet) {
		auto node = (cast(shared)this).nodeWithHubId(packet.sender);
		// only accept message from nodes that didn't disconnect
		if(node !is null) {
			this.callEventIfExists!NodeMessageEvent(cast()node, cast(ubyte[])packet.payload);
		}
	}

	protected override void handleStatusUpdatePlayers(HncomStatus.UpdatePlayers packet) {
		this.n_online = packet.online;
		this.n_max = packet.max;
	}

	protected override void handleStatusRemoteCommand(HncomStatus.RemoteCommand packet) {
		with(packet) (cast(shared)this).handleCommand(cast(ubyte)(origin + 1), sender, command, commandId);
	}

	protected override void handleStatusListInfo(HncomStatus.ListInfo packet) {}

	protected override void handleStatusUpdateList(HncomStatus.UpdateList packet) {}

	protected override void handleStatusPanelCredentials(HncomStatus.PanelCredentials packet) {
		//TODO start http server for panel
	}

	protected override void handlePlayerAdd(HncomPlayer.Add packet) {

		Skin skin = Skin(packet.skin.expand);

		if(!skin.valid) {
			// http://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/UUID.java#l394
			ubyte a = packet.uuid.data[7] ^ packet.uuid.data[15];
			ubyte b = (packet.uuid.data[3] ^ packet.uuid.data[11]) ^ a;
			skin = ((b & 1) == 0) ? Skin.STEVE : Skin.ALEX;
		}

		shared PlayerInfo player = cast(shared)new PlayerInfo(packet.hubId, packet.type, packet.protocol, packet.username, packet.displayName, packet.uuid, packet.clientAddress, packet.serverAddress, packet.language, packet.gameData);
		player.skin = skin;

		//TODO register global commands

		// add to the lists
		this._players[player.hubId] = cast(shared)player;

		auto event = (cast()this).callEventIfExists!PlayerJoinEvent(cast(const)player, packet.reason);

		//TODO allow kicking from event

		shared(WorldInfo) world;
		if(event is null || event.world is null || event.world.id !in this._worlds) {
			world = this._worlds[this._default_world_id];
		} else {
			world = this._worlds[event.world.id];
		}

		// do not spawn if it has been disconnected during the event
		if(player.hubId in this._players) {

			std.concurrency.send(cast()world.tid, AddPlayer(player));

		}

	}

	protected override void handlePlayerRemove(HncomPlayer.Remove packet) {
		(cast(shared)this).removePlayer(packet.hubId, packet.reason);
	}

	protected override void handlePlayerUpdateLatency(HncomPlayer.UpdateLatency packet) {
		//TODO
	}

	protected override void handlePlayerUpdatePacketLoss(HncomPlayer.UpdatePacketLoss packet) {
		//TODO
	}

	protected override void handlePlayerGamePacket(HncomPlayer.GamePacket packet) {
		auto player = packet.hubId in this._players;
		if(player && packet.payload.length) {
			std.concurrency.send(cast()(*player).world.tid, GamePacket(packet.hubId, packet.payload.idup));
		}
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

	private void helpCommand(ServerCommandSender sender) {
		Command[] commands;
		foreach(command ; sender.registeredCommands) {
			if(!command.hidden) {
				foreach(overload ; command.overloads) {
					if(overload.callableByServer) {
						commands ~= command;
						break;
					}
				}
			}
		}
		sort!((a, b) => a.command < b.command)(commands);
		foreach(cmd ; commands) {
			if(cmd.description.isTranslation) {
				sender.sendMessage(Text.yellow, cmd.description.translation);
			} else {
				sender.sendMessage(Text.yellow, cmd.description.message);
			}
			string[] usages;
			foreach(overload ; cmd.overloads) {
				if(overload.callableByServer) {
					usages ~= ("/" ~ cmd.command ~ " " ~ this.formatArg(overload));
				}
			}
			if(usages.length == 1) {
				sender.sendMessage(Translation("commands.generic.usage"), usages[0]);
			} else {
				sender.sendMessage(Translation("commands.generic.usage"), "");
				foreach(usage ; usages) {
					sender.sendMessage("- ", usage);
				}
			}
		}
	}

	private void helpCommandByPage(WorldCommandSender sender, int page) {
		auto player = cast(Player)sender;
		if(player) {
			Command[] commands;
			foreach(command ; player.commandMap) {
				if(!command.hidden) commands ~= command;
			}
			sort!((a, b) => a.command < b.command)(commands);
			immutable pages = cast(size_t)ceil(commands.length.to!float / 7); // commands.length should always be at least 1 (help command)
			page = clamp(--page, 0, pages - 1);
			sender.sendMessage(Text.darkGreen, Translation.all("commands.help.header"), page+1, pages);
			string[] messages;
			foreach(command ; commands[page*7..min($, (page+1)*7)]) {
				messages ~= (command.command ~ " " ~ this.formatArgs(command)[0]);
			}
			sender.sendMessage(messages.join("\n"));
			if(player.inputMode == InputMode.keyboard) {
				sender.sendMessage(Text.green, Translation.all("commands.help.footer"));
			}
		} else {
			sender.sendMessage("Sorry, no help today!");
		}
	}

	private void helpCommandByName(Player sender, string command) { // use Command as arg when available
		auto cmd = sender.commandByName(command);
		if(cmd !is null) {
			sender.sendMessage(Text.yellow ~ cmd.command ~ ":");
			if(cmd.description.isTranslation) {
				sender.sendMessage(Text.yellow, cmd.description.translation);
			} else {
				sender.sendMessage(Text.yellow, cmd.description.message);
			}
			auto params = formatArgs(cmd);
			foreach(ref param ; params) {
				param = "- /" ~ command ~ " " ~ param;
			}
			sender.sendMessage(Translation.all("commands.generic.usage"), "");
			sender.sendMessage(params.join("\n"));
		} else {
			sender.sendMessage(Text.red, Translation.all("commands.generic.notFound"));
		}
	}

	private string[] formatArgs(Command command) {
		string[] ret;
		foreach(overload ; command.overloads) {
			ret ~= this.formatArg(overload);
		}
		return ret;
	}
	
	private string formatArg(Command.Overload overload) {
		string[] p;
		foreach(i, param; overload.params) {
			if(overload.pocketTypeOf(i) == "stringenum" && overload.enumMembers(i).length == 1) {
				p ~= overload.enumMembers(i)[0];
			} else {
				string full = param ~ ": " ~ overload.typeOf(i);
				if(i < overload.requiredArgs) {
					p ~= "<" ~ full ~ ">";
				} else {
					p ~= "[" ~ full ~ "]";
				}
			}
		}
		return p.join(" ");
	}

}

class ServerCommandSender : CommandSender {

	enum Origin : ubyte {

		prompt = 0,
		hub = HncomStatus.RemoteCommand.HUB,
		externalConsole = HncomStatus.RemoteCommand.EXTERNAL_CONSOLE,
		remotePanel = HncomStatus.RemoteCommand.REMOTE_PANEL,
		rcon = HncomStatus.RemoteCommand.RCON,

	}

	public shared NodeServer server;
	public immutable ubyte origin;
	public const Address address;
	private int id;

	public this(shared NodeServer server, ubyte origin, Address address, int id) {
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
		logImpl("command", -1, this.id, join(cast(string[])formats, ""), this.server.config.lang.translate(translation, args));
	}

	alias server this;

}

private void startResourceUsageThread(int pid) {

	debug Thread.getThis().name = "ResourcesUsage";
	
	ProcessMemInfo ram = processMemInfo(pid);
	ProcessCPUWatcher cpu = new ProcessCPUWatcher(pid);
	
	while(true) {
		ram.update();
		//TODO send packet directly to the socket
		Handler.sharedInstance.send(HncomStatus.UpdateUsage(cast(uint)(ram.usedRAM / 1024u), cpu.current()).encode());
		Thread.sleep(dur!"seconds"(5));
	}
	
}

private void startCommandReaderThread(std.concurrency.Tid tid) {

	debug Thread.getThis().name = "CommandReader";

	import std.stdio : readln;
	while(true) {
		std.concurrency.send(tid, readln());
	}

}
