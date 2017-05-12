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
import std.typecons : Tuple, tuple;
import std.typetuple : TypeTuple;
import std.traits : Parameters;
import std.uuid : UUID;
import std.zlib : UnCompress;

import resusage.memory;
import resusage.cpu;

import sel.network.hncom; // do not move this import down

import sel.about;
import sel.config : Config, ConfigType;
import sel.format : Text;
import sel.lang : Lang, translate, Translation;
import sel.memory : Memory;
import sel.path : Paths;
import sel.plugin : Plugin;
import sel.utils : milliseconds, microseconds;
import sel.entity.entity : Entity;
import sel.entity.human : Skin;
import sel.event.event : Event, EventListener;
import sel.event.server;
import sel.event.server.server : ServerEvent;
import sel.event.world.world : WorldEvent;
import sel.math.vector : BlockPosition;
import sel.network.http : serveResourcePacks;
import sel.player.minecraft : MinecraftPlayer, MinecraftPlayerImpl;
import sel.player.player : Player;
import sel.player.pocket : PocketPlayer, PocketPlayerImpl;
import sel.util.command : Command, CommandSender;
import sel.util.ip : publicAddresses;
import sel.util.log;
import sel.util.node : Node;
import sel.util.resourcepack : createResourcePacks;
import sel.util.task;
import sel.world.rules : Rules;
import sel.world.world : World, Dimension;

mixin((){
	string imports;
	foreach(mod ; ["util", "types", "login", "status", "player", "world"]) {
		imports ~= "import Hncom" ~ capitalize(mod) ~ " = sul.protocol.hncom" ~ to!string(Software.hncom) ~ "." ~ mod ~ ";";
	}
	return imports;
}());

// Server's instance
private Server n_server;

/**
 * Gets the server instance (plugins should use this
 * function to get the server's instance).
 */
public nothrow @property @safe @nogc Server server() {
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
final class Server : EventListener!ServerEvent, CommandSender {

	private ulong start_time;

	private Handler handler;
	private Address n_hub_address;
	private immutable string node_name;
	private immutable bool node_main;

	private ulong n_id;
	private ulong uuid_count;

	private uint n_hub_latency;

	private Tuple!(immutable(uint), ubyte[])[] send_queue;
	
	private size_t next_received_length = 0;
	private ubyte[] next_received;

	private Config n_settings;
	private uint n_node_max;
	private size_t n_online;
	private size_t n_max;

	private Node[uint] nodes_hubid;
	private Node[string] nodes_names;

	private Tuple!(string, "website", string, "facebook", string, "twitter", string, "youtube", string, "instagram", string, "googlePlus") n_social;

	private float avg_tps = 20;
	private double[] last_tps;
	private size_t tps_pointer = 0;
	private ubyte warn = 0;
	private size_t last_warn = 0;

	private ProcessMemInfo resuage_ram;
	private ProcessCPUWatcher resuage_cpu;

	private ulong last_ram;
	private float last_cpu;

	private tick_t n_ticks = 0;

	private World[] m_worlds;

	private Player[uint] players_hubid;

	private TaskManager tasks;

	private Plugin[] n_plugins;

	public EventListener!WorldEvent globalListener;

	private Command[string] commands;

	public this(Address hub, string name, string password, bool main, Plugin[] plugins) {

		immutable bool lite = cast(TidAddress)hub !is null;

		this.node_name = name;
		this.node_main = main;

		this.n_plugins = plugins;
		
		n_server = this;
		
		this.n_hub_address = hub;
		
		this.last_tps.length = 20;
		this.last_tps[] = 20;
		
		{
			// load language from the last execution (or default language)
			static import std.file;
			if(std.file.exists(Paths.hidden ~ "lang")) {
				this.n_settings.language = cast(string)std.file.read(Paths.hidden ~ "lang");
			} else {
				this.n_settings.language = "en_GB";
			}
			this.n_settings.acceptedLanguages = [this.n_settings.language];
			Lang.init(this.n_settings.acceptedLanguages, [Paths.langSystem]);
		}

		if(lite) {

			this.handler = new MessagePassingHandler(cast(TidAddress)hub);
			this.handleInfo();

		} else {

			log(translate(Translation("startup.connecting"), this.n_settings.language, [to!string(hub), name]));

			try {
				this.handler = new SocketHandler(hub);
				this.sendPacket(new HncomLogin.ConnectionRequest(Software.hncom, password, name, main).encode());
			} catch(SocketException e) {
				error_log(translate(Translation("warning.connectionError"), this.n_settings.language, [to!string(hub), e.msg]));
				return;
			}

			// wait for ConnectionResponse
			bool error;
			ubyte[] buffer = this.handler.next(error);
			if(!error && buffer.length && buffer[0] == HncomLogin.ConnectionResponse.ID) {
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

	private void handleInfo() {

		bool error;
		ubyte[] buffer = this.handler.next(error);
		if(!error && buffer.length && buffer[0] == HncomLogin.HubInfo.ID) {

			auto info = HncomLogin.HubInfo.fromBuffer(buffer);

			this.n_hub_latency = cast(uint)round(to!float(microseconds - info.time) / 1000f);

			this.n_id = info.serverId;
			this.uuid_count = info.reservedUuids;

			auto type = this.n_hub_address is null ? ConfigType.lite : ConfigType.node;

			auto additional = parseJSON(info.additionalJson);
			auto minecraft = "minecraft" in additional;
			if(minecraft && minecraft.type == JSON_TYPE.OBJECT) {
				auto edu = "edu" in *minecraft;
				auto realm = "realm" in *minecraft;
				this.n_settings = Config(type, edu && edu.type == JSON_TYPE.TRUE, realm && realm.type == JSON_TYPE.TRUE);
			} else {
				this.n_settings = Config(type, false, false);
			}
			this.n_settings.load();
			Rules.reload(this.n_settings);

			this.n_settings.displayName = info.displayName;
			this.n_settings.language = info.language;
			this.n_settings.acceptedLanguages = info.acceptedLanguages;

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
			std.file.write(Paths.hidden ~ "lang", this.n_settings.language);

			version(Windows) {
				//executeShell("title " ~ info.displayName ~ " ^| node ^| " ~ Software.display);
			}

			// reload languages and save cache
			string[] paths;
			foreach(plugin ; this.n_plugins) {
				if(plugin.languages !is null) paths ~= plugin.languages;
			}
			Lang.init(this.n_settings.acceptedLanguages, paths ~ Paths.langSystem ~ Paths.langMessages);
			if(!std.file.exists(Paths.hidden)) std.file.mkdirRecurse(Paths.hidden);
			std.file.write(Paths.hidden ~ "lang", this.n_settings.language);

			foreach(game ; info.gamesInfo) {
				this.handleGameInfo(game);
			}

			// check protocols and print warnings if necessary
			void check(ubyte type, string name, uint[] requested, uint[] supported) {
				foreach(req ; requested) {
					if(!supported.canFind(req)) {
						warning_log(translate(Translation("warning.invalidProtocol"), this.n_settings.language, [to!string(req), name]));
					}
				}
			}

			check(PE, "Minecraft: Pocket Edition", this.n_settings.pocket.protocols, supportedPocketProtocols.keys);
			check(PC, "Minecraft", this.n_settings.minecraft.protocols, supportedMinecraftProtocols.keys);

			this.finishConstruction();

		} else {
			error_log(translate(Translation("warning.closed"), this.n_settings.language));
		}

	}

	private void handleGameInfo(HncomTypes.GameInfo info) {
		void set(ref Config.Game game) {
			game.enabled = true;
			game.protocols = info.game.protocols;
			game.motd = info.motd;
			game.onlineMode = info.onlineMode;
			game.port = info.port;
		}
		if(info.game.type == HncomTypes.Game.POCKET) {
			set(this.n_settings.pocket);
		} else if(info.game.type == HncomTypes.Game.MINECRAFT) {
			set(this.n_settings.minecraft);
		} else {
			error_log(translate(Translation("warning.invalidGame"), this.n_settings.language, [to!string(info.game.type), Software.name]));
		}
	}

	private void finishConstruction() {

		this.resuage_ram = processMemInfo(getpid);
		this.resuage_cpu = new ProcessCPUWatcher(getpid);

		import core.cpuid : coresPerCPU, processor, threadsPerCPU;

		log(translate(Translation("startup.starting"), this.n_settings.language, [Text.green ~ Software.name ~ Text.white ~ " " ~ Software.fullVersion ~ Text.reset ~ " (" ~ Text.white ~ Software.codename ~ " " ~ Text.reset ~ Software.codenameEmoji ~ ")"]));

		static if(!__supported) {
			warning_log(translate(Translation("startup.unsupported"), this.n_settings.language, [Software.name]));
		}

		this.globalListener = new EventListener!WorldEvent();

		// default skins for players that connect with invalid skins
		Skin.STEVE = Skin("Standard_Steve", cast(ubyte[])std.file.read(Paths.skin ~ "Standard_Steve.bin"));
		Skin.ALEX = Skin("Standard_Alex", cast(ubyte[])std.file.read(Paths.skin ~ "Standard_Alex.bin"));
		
		this.tasks = new TaskManager();

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

		log(translate(Translation("startup.resourcePacks"), this.n_settings.language));

		// create resource pack files
		string[] textures = [Paths.textures]; // ordered from least prioritised to most prioritised
		foreach_reverse(plugin ; this.n_plugins) {
			if(plugin.textures !is null) textures ~= plugin.textures;
		}
		if(textures.length > 1) {

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

		// remove plugins from list if deactivated
		if(std.file.exists(Paths.home ~ "plugins.json")) {
			Plugin[] plugins;
			auto json = parseJSON(cast(string)std.file.read(Paths.home ~ "plugins.json"));
			foreach(plugin ; this.n_plugins) {
				auto p = plugin.namespace in json;
				if(!p || p.type != JSON_TYPE.FALSE) plugins ~= plugin;
			}
			this.n_plugins = plugins;
		}
		// rewite plugins.json
		{
			string[] plugins;
			foreach(plugin ; this.n_plugins) {
				plugins ~= "\t\"" ~ plugin.namespace ~ "\": true";
			}
			//std.file.write(Paths.home ~ "plugins.json", "{" ~ newline ~ plugins.join("," ~ newline) ~ newline ~ "}" ~ newline);
		}

		this.start_time = milliseconds;

		foreach(plugin ; this.n_plugins) {
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
		foreach(plugin ; this.n_plugins) {
			plugins ~= HncomTypes.Plugin(plugin.name, plugin.vers);
		}
		this.sendPacket(new HncomLogin.NodeInfo(microseconds, this.n_node_max, games, plugins).encode());
		this.handler.unblock();

		// call @start functions
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onstart) {
				del();
			}
		}
		
		if(!this.m_worlds.length) {
			//this.addWorld!Overworld();
			this.addWorld!World();
		}
		
		version(Windows) {
			SetConsoleCtrlHandler(&sigHandler, true);
		} else version(linux) {
			sigset(SIGTERM, &extsig);
			sigset(SIGINT, &extsig);
		}

		log(translate(Translation("startup.started"), this.n_settings.language));

		getAndClearLoggedMessages();
		
		this.start();

	}

	private void start() {

		StopWatch watch = StopWatch();

		while(running) {

			watch.start();

			this.tick();

			watch.stop();

			double diff = watch.peek.usecs;
			if(diff < 50000) {
				Thread.sleep(dur!"usecs"(to!ulong(50000 - diff)));
				this.last_tps[this.tps_pointer] = 20;
				this.warn = 0;
			} else {
				this.last_tps[this.tps_pointer] = 20 - diff / 50000;
				if(++this.warn == 3 && this.ticks - this.last_warn > 100) {
					warning_log(translate(Translation("warning.overload"), this.n_settings.language, []));
					this.last_warn = this.ticks;
					this.warn = 0;
				}
			}
			double sum = 0;
			foreach(double b ; this.last_tps) {
				sum += b;
			}
			this.avg_tps = sum / this.last_tps.length;
			++this.tps_pointer %= this.last_tps.length;


			if(this.ticks % 100 == 1) {
				this.resuage_ram.update();
				this.sendPacket(new HncomStatus.ResourcesUsage(this.tps, this.resuage_ram.usedRAM, this.resuage_cpu.current()).encode());
			}

			watch.reset();

		}

		this.handler.close();

		// call @stop plugins
		foreach(Plugin plugin ; this.n_plugins) {
			foreach(void delegate() del ; plugin.onstop) {
				del();
			}
		}

		// unload (an save) all worlds
		foreach(World world ; this.m_worlds) {
			//TODO save the world if there's a provider
			this.removeWorld(world);
		}

		import std.file : exists, remove;
		if(exists(Paths.hidden ~ "status")) remove(Paths.hidden ~ "status");

		log(translate(Translation("startup.stopped"), this.n_settings.language, []));

		/*version(Windows) {
			// forcefully kill this process to make sure also children
			// processes are terminated
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
	public void shutdown() {
		//foreach(player ; this.players_hubid) player.kick(message);
		running = false;
	}

	private void tick() {
		this.n_ticks++;
		
		// try to receive packets
		if(!this.handleHncomPackets()) {
			error_log(translate(Translation("warning.closed"), this.n_settings.language, []));
			running = false;
			return;
		}

		// try to receive one command from the console
		//receiveTimeout(dur!"seconds"(0), (string cmd){ this.handleCommand(ServerCommandEvent.Origin.prompt, null, cmd); });
		
		// execute the tasks
		if(this.tasks.length) this.tasks.tick(this.ticks);

		// tick the worlds
		/*foreach(World world ; this.worlds) {
			world.tick(); // <-- this can cause memory leaks when the netowrk is busy!
		}*/
		/*foreach(string s ; this.worldsNames) {
			this.worlds[s].tick();
		}*/
		foreach(world ; this.m_worlds) {
			world.tick();
		}

		// flush packets
		foreach(player ; this.players_hubid) {
			player.flush();
		}

		// sends the logs to the hub
		foreach(log ; getAndClearLoggedMessages()) {
			this.sendPacket(log.encode());
		}
	}

	/**
	 * Gets the server's id, which is equal in the hub and all
	 * connected nodes.
	 * It is generated by SEL's snooping system or randomly if
	 * the service cannot be reached.
	 */
	public pure nothrow @property @safe @nogc immutable(long) id() {
		return this.n_id;
	}

	public pure nothrow @property @safe @nogc UUID nextUUID() {
		ubyte[16] data;
		data[0..8] = nativeToBigEndian(this.id);
		data[8..16] = nativeToBigEndian(this.uuid_count++);
		return UUID(data);
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
	public pure nothrow @property @safe @nogc const(Config) settings() {
		return this.n_settings;
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
	public pure nothrow @property @safe @nogc string name() {
		return this.n_settings.displayName;
	}
	
	/**
	 * Gets the number of online players in the current
	 * node (not in the whole server).
	 */
	public pure nothrow @property @safe @nogc size_t online() {
		return this.players_hubid.length;
	}

	/**
	 * Gets the maximum number of players that can connect on the
	 * current node (not in the whole server).
	 * If the value is 0 there's no limit.
	 */
	public pure nothrow @property @safe @nogc size_t max() {
		return this.n_node_max;
	}
	
	/**
	 * Gets the number of online players in the whole server
	 * (not just in the current node).
	 */
	public pure nothrow @property @safe @nogc size_t hubOnline() {
		return this.n_online;
	}
	
	/**
	 * Gets the number of maximum players that can connect to
	 * the hub.
	 * If the value is 0 it means that no limit has been set and
	 * players will never be kicked because the server is full.
	 */
	public pure nothrow @property @safe @nogc size_t hubMax() {
		return this.n_max;
	}

	/**
	 * Gets the current's node name.
	 */
	public pure nothrow @property @safe @nogc string nodeName() {
		return this.node_name;
	}

	/**
	 * Gets whether or not this is a main node (players are added
	 * when connected to hub) or not (player are added only when
	 * transferred by other nodes).
	 */
	public pure nothrow @property @safe @nogc bool isMainNode() {
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
	public pure nothrow @property @safe @nogc const social() {
		return this.n_social;
	}

	/**
	 * Gets the server's website.
	 * Example:
	 * ---
	 * assert(server.website == server.social.website);
	 * ---
	 */
	public pure nothrow @property @safe @nogc string website() {
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
	public pure nothrow @property @safe @nogc Address hubAddress() {
		return this.n_hub_address;
	}

	/**
	 * Gets the latency between the node and the hub.
	 */
	public pure nothrow @property @safe @nogc uint hubLatency() {
		return this.n_hub_latency;
	}

	/** 
	 * Gets the number of ticks since the server has connected with hub.
	 * The number of ticks do not indicate the uptime of the server, because
	 * there's the probability that the server's resources can't handle 20
	 * ticks per second.
	 * Example:
	 * ---
	 * if(server.ticks / 20 != server.uptime.seconds) {
	 *    d("The server was lagging!");
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc tick_t ticks() {
		return this.n_ticks;
	}

	/**
	 * Gets the average TPS (ticks per second).
	 * Returns: A floating point number between in range 0..20, where 20 is the best
	 * Example:
	 * ---
	 * if(server.tps != 20) {
	 *    d("Server's is going at less than 20 TPS!");
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc float tps() {
		return this.avg_tps;
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
	public @property @safe Duration uptime() {
		return dur!"msecs"(milliseconds - this.start_time);
	}

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

	/**
	 * Gets a list with the nodes connected to the hub, this excluded.
	 * Example:
	 * ---
	 * foreach(node ; server.nodes) {
	 *    assert(node.name != server.nodeName);
	 * }
	 * ---
	 */
	public pure nothrow @property @trusted const(Node)[] nodes() {
		return this.nodes_hubid.values;
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
	public inout pure nothrow @safe const(Node) nodeWithName(string name) {
		auto ret = name in this.nodes_names;
		return ret ? *ret : null;
	}

	/**
	 * Gets a node by its hub id, which is given by the hub and
	 * unique for every session.
	 */
	public inout pure nothrow @safe const(Node) nodeWithHubId(uint hubId) {
		auto ret = hubId in this.nodes_hubid;
		return ret ? *ret : null;
	}

	/**
	 * Sends a message to a node.
	 */
	public void sendMessage(Node[] nodes, ubyte[] payload) {
		uint[] addressees;
		foreach(node ; nodes) {
			if(node !is null) addressees ~= node.hubId;
		}
		this.sendPacket(new HncomStatus.MessageServerbound(addressees, payload).encode());
	}

	/// ditto
	public void sendMessage(Node node, ubyte[] payload) {
		this.sendMessage([node], payload);
	}

	/**
	 * Broadcasts a message to every node connected to the hub.
	 */
	public void broadcast(ubyte[] payload) {
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
	public pure nothrow @property @safe @nogc const(Plugin)[] plugins() {
		return this.n_plugins;
	}

	/**
	 * Gets the server's default world.
	 */
	public pure nothrow @property @safe @nogc World world() {
		return this.m_worlds[0];
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
	public pure nothrow @property @safe @nogc World world(World world) {
		foreach(i, w; m_worlds[1..$]) {
			if(w.id == world.id) {
				auto def = this.m_worlds[0];
				this.m_worlds[0] = w;
				this.m_worlds[i] = def;
				break;
			}
		}
		return this.m_worlds[0];
	}

	/**
	 * Gets a list with every world registered in the server.
	 * The list is a copy of the one kept by the server and its
	 * modification has no effect on the server.
	 */
	public pure nothrow @property @safe World[] worlds() {
		return this.m_worlds.dup;
	}

	/**
	 * Gets a list of worlds with the same name (case sensitive).
	 * This method should only be used by commands as saving the
	 * world instance is faster and safer.
	 * Example:
	 * ---
	 * log("There are ", server.worldsWithName("overworld").length, " named overworld");
	 * ---
	 */
	public pure nothrow @safe World[] worldsWithName(string name) {
		World[] ret;
		foreach(world ; this.m_worlds) {
			if(world.name == name) ret ~= world;
		}
		return ret;
	}

	/**
	 * Gets a list of worlds with the same name (case insnsitive).
	 * Example:
	 * ---
	 * server.addWorld("Uppercase");
	 * assert(server.worldsWithName("uppercase").length + 1 == server.worldsWithNameIns("uppercase"));
	 * ---
	 */
	public World[] worldsWithNameIns(string name) {
		name = name.toLower;
		World[] ret;
		foreach(world ; this.m_worlds) {
			if(world.name.toLower == name) ret ~= world;
		}
		return ret;
	}

	/**
	 * Gets a world by its id.
	 * Returns: The World instance or null if the world is not registered.
	 */
	public pure nothrow @safe @nogc World worldWithId(uint id) {
		foreach(world ; this.m_worlds) {
			if(world.id == id) return world;
		}
		return null;
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
	public T addWorld(T:World=World, E...)(E args) /*if(__traits(compiles, new T(args)))*/ {
		T world = new T(args);
		World.startWorld(this, world, null);
		this.m_worlds ~= cast(World)world; // default if there are no worlds
		this.sendPacket(new HncomWorld.Add(
			world.id, world.name, world.dimension,
			world.type=="flat" ? HncomWorld.Add.FLAT : HncomWorld.Add.DEFAULT,
			world.rules.difficulty, world.rules.gamemode, //TODO use world.difficulty and world.gamemode
			typeof(HncomWorld.Add.spawnPoint)(world.spawnPoint.x, world.spawnPoint.z),
			cast(short)(world.rules.daylightCycle ? world.time : -world.time),
			world.seed,
			world.parent is null ? -1 : world.parent.id
		).encode());
		return world;
	}

	/**
	 * Removes a world and unloads it.
	 * When trying to remove the default world a message error will be
	 * displayed and the world will not be unloaded.
	 */
	public bool removeWorld(World world) {
		if(this.m_worlds.length) {
			if(world != this.m_worlds[0] || !running) {
				for(size_t i=1; i<this.m_worlds.length; i++) {
					if(world == this.m_worlds[i]) {
						this.m_worlds = this.m_worlds[0..i] ~ this.m_worlds[i+1..$];
						World.stopWorld(world, running ? this.m_worlds[0] : null);
						this.sendPacket(new HncomWorld.Remove(world.id).encode());
						return true;
					}
				}
			} else {
				warning_log(translate(Translation("warning.removingDefaultWorld"), this.n_settings.language, [world.name]));
			}
		}
		return false;
	}

	/**
	 * Gets a list with all the players in the server.
	 */
	public pure nothrow @property @trusted Player[] players() {
		return this.players_hubid.values;
	}

	/**
	 * Gets a player by name.
	 * The search is done case-insensitive and the minus sign (-) is
	 * replaced with the space character (so commands can use it to
	 * indicate a player which name has spaces).
	 * Returns: An array of online players with the given name.
	 */
	public pure @trusted Player[] playersWithName(string name) {
		name = name.toLower.replace("-", " ");
		Player[] ret;
		foreach(player ; this.players_hubid) {
			if(player.lname == name) ret ~= player;
		}
		return ret;
	}

	/**
	 * Gets a player by its hub id.
	 * Returns: The player instance or null if there is not player with the given hub id
	 */
	public pure nothrow @safe @nogc Player playerWithHubId(uint hubId) {
		auto player = hubId in this.players_hubid;
		return player ? *player : null;
	}

	/**
	 * Broadcasts a message in every registered world and their children
	 * calling the world's broadcast method.
	 */
	public void broadcast(E...)(E args) {
		void broadcastImpl(World world) {
			world.broadcast(args);
			foreach(child ; world.children) {
				broadcastImpl(child);
			}
		}
		foreach(world ; this.m_worlds) {
			broadcastImpl(world);
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

	public override BlockPosition startingPosition() {
		return BlockPosition(0);
	}

	public override Entity[] visibleEntities() {
		Entity[] ret;
		foreach(world ; this.worlds) {
			ret ~= world.entities;
		}
		return ret;
	}

	public override Player[] visiblePlayers() {
		return this.players;
	}
	
	protected override void sendMessageImpl(string message) {
		log(message);
	}
	
	protected override void sendTranslationImpl(Translation message, string[] args) {
		log(translate(message, this.settings.language, args));
	}
	
	protected override void sendColoredTranslationImpl(Text color, Translation message, string[] args) {
		log(color, translate(message, this.settings.language, args));
	}

	// hub-node communication and related methods

	private void sendPacket(ubyte[] packet) {
		if(Handler.sharedInstance.send(packet) != packet.length + 4 && running) {
			// something Socket.receive doesn't return 0 when the connection is closed
			error_log(translate(Translation("warning.closed"), this.n_settings.language));
			running = false;
		}
	}

	public bool changePlayerLanguage(Player player, string language) {
		if(language == player.lang || !this.n_settings.acceptedLanguages.canFind(language) || this.callCancellableIfExists!PlayerLanguageUpdatedEvent(player, language)) return false;
		this.sendPacket(new HncomPlayer.UpdateLanguage(player.hubId, language).encode());
		return true;
	}
	
	public void updatePlayerDisplayName(Player player) {
		this.sendPacket(new HncomPlayer.UpdateDisplayName(player.hubId, player.displayName).encode());
	}

	/**
	 * Disconnects a player from the server.
	 * Params:
	 * 		player = the player to disconnect
	 * 		reason = disconnection reason
	 * 		translation = indicates whether or not reason is a client-side translation
	 * Example:
	 * ---
	 * @event jump(PlayerJumpEvent e) {
	 *   server.disconnect(e.player, "You can't jump on this server");
	 * }
	 * ---
	 */
	public void disconnect(Player player, string reason, bool translation=false) {
		if(this.removePlayer(player, PlayerLeftEvent.Reason.kicked)) {
			this.sendPacket(new HncomPlayer.Kick(player.hubId, reason, translation).encode());
		}
	}

	/**
	 * Transfers a player to another node.
	 * Params:
	 * 		player = the player to transfer
	 * 		node = name of the node where the player will be transferred
	 * Example:
	 * ---
	 * if(server.nodes.length) {
	 *    server.transfer(player, server.nodes[0]);
	 * }
	 * ---
	 */
	public void transfer(Player player, inout Node node) {
		if(node.hubId in this.nodes_hubid && this.removePlayer(player, PlayerLeftEvent.Reason.transferred)) {
			this.sendPacket(new HncomPlayer.Transfer(player.hubId, node.hubId).encode());
		}
	}

	// removes with a reason a player spawned in the server
	private bool removePlayer(Player player, ubyte reason) {
		if(player.hubId in this.players_hubid) {
			if(player.world !is null) player.world.despawnPlayer(player);
			this.players_hubid.remove(player.hubId);
			player.close();
			this.callEventIfExists!PlayerLeftEvent(player, reason);
			return true;
		} else {
			return false;
		}
	}

	/*
	 * Returns: true if the connection is alive, false otherwise
	 */
	private bool handleHncomPackets() {
		ubyte[] buffer;
		bool closed = false;
		while((buffer = this.handler.next(closed)).length) {
			this.handleHncomPacket(buffer[0], buffer[1..$]);
		}
		return !closed;
	}

	private void handleHncomPacket(ubyte id, ubyte[] data) {
		switch(id) {
			foreach(P ; TypeTuple!(HncomUtil.Packets, HncomStatus.Packets, HncomPlayer.Packets, HncomWorld.Packets)) {
				static if(P.CLIENTBOUND) {
					case P.ID: mixin("return this.handle" ~ P.stringof ~ "Packet(P.fromBuffer!false(data));");
				}
			}
			default: error_log("Unknown packet received from the hub with id ", id, " and ", data.length, " bytes of data");
		}
	}

	private void handleUncompressedPacket(HncomUtil.Uncompressed packet) {
		foreach(p ; packet.packets) {
			if(p.length) this.handleHncomPacket(p[0], p[1..$]);
		}
	}

	private void handleCompressedPacket(HncomUtil.Compressed packet) {
		// not supported
		auto uc = new UnCompress(packet.size);
		ubyte[] data = cast(ubyte[])uc.uncompress(packet.payload);
		data ~= cast(ubyte[])uc.flush();
		this.handleUncompressedPacket(HncomUtil.Uncompressed.fromBuffer!false(data));
	}

	/*
	 * Adds (or update) a node.
	 */
	private void handleAddNodePacket(HncomStatus.AddNode packet) {
		auto node = new Node(this, packet.hubId, packet.name, packet.main);
		foreach(accepted ; packet.acceptedGames) node.acceptedGames[accepted.type] = accepted.protocols;
		this.nodes_hubid[node.hubId] = node;
		this.nodes_names[node.name] = node;
		this.callEventIfExists!NodeAddedEvent(node);
	}

	/**
	 * Removes a node.
	 */
	private void handleRemoveNodePacket(HncomStatus.RemoveNode packet) {
		auto node = packet.hubId in this.nodes_hubid;
		if(node) {
			this.nodes_hubid.remove((*node).hubId);
			this.nodes_names.remove((*node).name);
			this.callEventIfExists!NodeRemovedEvent(*node);
		}
	}

	/*
	 * Handles a message sent or broadcasted from another node.
	 */
	private void handleMessageClientboundPacket(HncomStatus.MessageClientbound packet) {
		auto node = this.nodeWithHubId(packet.sender);
		// only accept message from nodes that didn't disconnect
		if(node !is null) {
			this.callEventIfExists!NodeMessageEvent(node, packet.payload);
		}
	}
	
	/*
	 * Updates the number of online and max players in the whole
	 * server (not the current node).
	 */
	private void handlePlayersPacket(HncomStatus.Players packet) {
		this.n_online = packet.online;
		this.n_max = packet.max;
	}

	/*
	 * Handles a command sent by the hub or an external application.
	 */
	private void handleRemoteCommandPacket(HncomStatus.RemoteCommand packet) {
		with(packet) this.handleCommand(origin, this.convertAddress(sender), command, commandId);
	}

	/**
	 * Reloads the configurations.
	 */
	private void handleReloadPacket(HncomStatus.Reload packet) {
		// only reload plugins, not settings
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onreload) del();
		}
	}

	/*
	 * Adds a player to the node.
	 */
	private void handleAddPacket(HncomPlayer.Add packet) {

		Address address = this.convertAddress(packet.clientAddress);
		Skin skin = Skin(packet.skin.name, packet.skin.data);

		if(!skin.valid) {
			// http://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/UUID.java#l394
			ubyte a = packet.uuid.data[7] ^ packet.uuid.data[15];
			ubyte b = (packet.uuid.data[3] ^ packet.uuid.data[11]) ^ a;
			skin = ((b & 1) == 0) ? Skin.STEVE : Skin.ALEX;
		}

		Player player = (){
			switch(packet.type) {
				case HncomPlayer.Add.Pocket.TYPE:
					auto pocket = packet.new Pocket();
					pocket.decode();
					final switch(packet.protocol) {
						foreach(immutable p ; SupportedPocketProtocols) {
							case p:
								return cast(Player)new PocketPlayerImpl!p(packet.hubId, packet.vers, address, packet.serverAddress, packet.serverPort, packet.username, packet.displayName, skin, packet.uuid, packet.language, packet.inputMode, packet.latency, pocket.packetLoss, pocket.xuid, pocket.edu, pocket.deviceOs, pocket.deviceModel);
						}
					}
				case HncomPlayer.Add.Minecraft.TYPE:
					auto minecraft = packet.new Minecraft();
					minecraft.decode();
					final switch(packet.protocol) {
						foreach(immutable p ; SupportedMinecraftProtocols) {
							case p:
								return cast(Player)new MinecraftPlayerImpl!p(packet.hubId, packet.vers, address, packet.serverAddress, packet.serverPort, packet.username, packet.displayName, skin, packet.uuid, packet.language, packet.inputMode, packet.latency);
						}
					}
				default: assert(0, "Trying to add a player with an unknown type " ~ to!string(packet.type));
			}
		}();

		// register the server's commands
		foreach(Command command ; this.commands) {
			player.registerCommand(command);
		}

		// add to the lists
		this.players_hubid[player.hubId] = player;

		server.callEventIfExists!PlayerJoinEvent(player, packet.reason);

		// do not spawn if it has been disconnected during the event
		if(player.hubId in this.players_hubid) {

			// use the default world if plugins didn't set one
			if(player.world is null) player.world = this.world;
			World world = player.world;
			if(packet.reason != HncomPlayer.Add.FIRST_JOIN) {
				player.sendChangeDimension(cast(Dimension)packet.dimension, world.dimension);
			}
			player.world = null;
			player.joined = true;
			player.world = world;

		}

		// do not spawn if it has been disconnected during the event
		/*if(player.hubId in this.players_hubid) {
			if(packet.reason != HncomPlayer.Add.FIRST_JOIN) {
				player.sendChangeDimension(group!byte(packet.dimension, packet.dimension), world.dimension);
			}
			player.world.spawnPlayer(player);
		}*/

	}

	/*
	 * Removes a player from a node.
	 * This packet is not sent when a player is moved away from this
	 * node with a Transfer or a Kick packet.
	 */
	private void handleRemovePacket(HncomPlayer.Remove packet) {
		if(auto p = (packet.hubId in this.players_hubid)) {
			this.removePlayer(*p, packet.reason);
		}
	}
	
	private void handleUpdateGamemodePacket(HncomPlayer.UpdateGamemode packet) {
		auto player = packet.hubId in this.players_hubid;
		if(player) {
			(*player).gamemode = packet.gamemode;
		}
	}
	
	/*
	 * Updates a player's input mode.
	 */
	private void handleUpdateInputModePacket(HncomPlayer.UpdateInputMode packet) {
		auto player = packet.hubId in this.players_hubid;
		if(player) {
			//TODO call event
		}
	}

	/*
	 * Updates a player's latency.
	 * The value given in the packet represents the latency between the hub
	 * and player, so an additional latency is added (the one between the node
	 * and the hub) is added to obtain a more precise value.
	 */
	private void handleUpdateLatencyPacket(HncomPlayer.UpdateLatency packet) {
		auto player = packet.hubId in this.players_hubid;
		if(player) {
			(*player).handleUpdateLatency(packet);
		}
	}

	/*
	 * Updates a player's packet loss thanks to hub's calculations.
	 */
	private void handleUpdatePacketLossPacket(HncomPlayer.UpdatePacketLoss packet) {
		auto player = packet.hubId in this.players_hubid;
		if(player) {
			(*player).handleUpdatePacketLoss(packet);
		}
	}
	
	/*
	 * Elaborates raw game data sent by a client.
	 */
	private void handleGamePacketPacket(HncomPlayer.GamePacket packet) {
		auto player = packet.hubId in this.players_hubid;
		if(player && packet.packet.length) {
			(*player).handle(packet.packet[0], packet.packet[1..$]);
		}
	}

	private void handleUpdateDifficultyPacket(HncomWorld.UpdateDifficulty packet) {
		auto world = this.worldWithId(packet.worldId);
		if(world !is null) {
			//TODO update difficulty and send packets
		}
	}

	private void handleUpdateGamemodePacket(HncomWorld.UpdateGamemode packet) {
		auto world = this.worldWithId(packet.worldId);
		if(world !is null) {
			//TODO update default gamemode and send packets
		}
	}

	private void handleRequestCreationPacket(HncomWorld.RequestCreation packet) {
		//TODO do construction with rules
		if(packet.parent < 0) {
			this.addWorld(packet.name);
		} else {
			bool search(World[] worlds) {
				foreach(world ; worlds) {
					if(world.id == packet.parent) {
						world.addChild(packet.name);
						return true;
					} else if(search(world.children)) {
						return true;
					}
				}
				return false;
			}
			search(this.worlds);
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

	// handles a command from various sources.
	private void handleCommand(ubyte origin, Address address, string command, int id=-1) {
		auto spl = command.strip.split(" ");
		if(spl.length) {
			auto c = spl[0] in this.commands; //TODO aliases
			if(c) {
				(*c).callArgs(this, spl[1..$].idup);
			}
		}
	}

	/**
	 * Registers a task.
	 * Params:
	 *		task = a function or a delegate that will be called every interval
	 *		interval = number of ticks indicating the repeating interval
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
	 * Example:
	 * ---
	 * immutable expected = server.ticks + 100;
	 * server.delay({
	 *    assert(server.ticks = expected);
	 * }, 100);
	 * ---
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

}
