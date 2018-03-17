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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/node/server.d, selery/node/server.d)
 */
module selery.node.server;

import core.atomic : atomicOp;
import core.thread : getpid, Thread;

import std.algorithm : canFind, min;
import std.bitmanip : nativeToBigEndian;
static import std.concurrency;
import std.conv : to;
import std.datetime : dur, Duration;
import std.datetime.stopwatch : StopWatch;
static import std.file;
import std.json : JSON_TYPE, JSONValue, parseJSON;
import std.process : executeShell;
import std.socket : SocketException, Address;
import std.string; //TODO selective imports
import std.traits : Parameters;
import std.uuid : UUID;

import imageformats.png : read_png_from_mem;

import resusage.memory;
import resusage.cpu;

import sel.format : Format;
import sel.hncom.about;
import sel.hncom.handler : HncomHandler;
import sel.server.bedrock : bedrockSupportedProtocols;

import selery.world.world : World; // do not move this import down

import selery.about;
import selery.command.command : Command;
import selery.command.execute : executeCommand;
import selery.command.util : CommandSender;
import selery.commands : Commands;
import selery.config : Config, Difficulty, Gamemode;
import selery.entity.human : Skin;
import selery.event.event : Event, EventListener;
import selery.event.node;
import selery.event.world.world : WorldEvent;
import selery.lang : LanguageManager, Translation;
import selery.log : Message, Logger;
import selery.node.handler; //TODO selective imports
import selery.node.node : Node;
import selery.node.plugin.plugin : NodePluginInfo;
import selery.player.bedrock : BedrockPlayer, BedrockPlayerImpl;
import selery.player.java : JavaPlayer;
import selery.player.player : PlayerInfo, PermissionLevel;
import selery.plugin : Plugin, Description;
import selery.server : Server;
import selery.util.resourcepack : createResourcePacks, serveResourcePacks;
import selery.util.tuple : Tuple;
import selery.util.util : milliseconds, microseconds;
import selery.world.group;
import selery.world.world : WorldInfo;

import terminal : Terminal;

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

private struct Stop {}

/**
 * Singleton for the server instance.
 */
final class NodeServer : EventListener!NodeServerEvent, Server, HncomHandler!clientbound {

	public immutable bool lite;

	private shared ulong start_time;

	private Handler handler;
	private Address n_hub_address;

	private const string[] n_args;

	private shared ulong n_id;
	private shared ulong uuid_count;

	private shared uint n_hub_latency;

	public shared std.concurrency.Tid tid; //TODO make private

	private shared Config _config;
	private shared Logger _logger;
	private shared ServerLogger serverlogger;

	private shared size_t n_online;
	private shared size_t n_max;

	private shared Node[uint] nodes_hubid;
	private shared Node[string] nodes_names;

	private shared Tuple!(string, "website", string, "facebook", string, "twitter", string, "youtube", string, "instagram", string, "googlePlus") n_social;

	private shared(uint) _main_group_id = 0; // 0 = no default group
	private shared(GroupInfo)[uint] _groups;
	private shared(GroupInfo)[string] _groups_names;

	private shared(PlayerInfo)[uint] _players;

	private shared Plugin[] n_plugins;

	public shared EventListener!WorldEvent globalListener;

	private shared Command[string] _commands;

	public shared this(Address hub, Config config, Plugin[] plugins=[], string[] args=[]) {

		assert(config.node !is null);

		debug Thread.getThis().name = "node";

		this.lite = cast(TidAddress)hub !is null;

		this.n_plugins = cast(shared)plugins;

		this.n_args = cast(shared)args;

		this.tid = server_tid = cast(shared)std.concurrency.thisTid;
		
		this.n_hub_address = cast(shared)hub;

		if(config.hub is null) config.hub = config.new Config.Hub();

		this._config = cast(shared)config;

		Terminal terminal = new Terminal();
		this._logger = cast(shared)new Logger(terminal, config.lang); // only writes in the console

		if(lite) {

			this.handler = new shared MessagePassingHandler(cast(shared TidAddress)hub);
			this.handleInfoImpl(cast()std.concurrency.receiveOnly!(shared HncomLogin.HubInfo)());

		} else {

			this.logger.log(Translation("startup.connecting", [to!string(hub), config.node.name]));

			try {
				this.handler = new shared SocketHandler(hub);
				this.handler.send(HncomLogin.ConnectionRequest(config.node.name, config.node.password, config.node.main).encode());
			} catch(SocketException e) {
				this.logger.logError(Translation("warning.connectionError", [to!string(hub), e.msg]));
				return;
			}

			// remove variables in config that plugins should not read
			config.node.password = "";
			config.node.ip = "";
			config.node.port = ushort(0);

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
					this.logger.logError(Translation("status." ~ reason));
					if(response.status == HncomLogin.ConnectionResponse.OUTDATED_HUB || response.status == HncomLogin.ConnectionResponse.OUTDATED_NODE) {
						this.logger.logError(Translation("warning.protocolRequired", [to!string(__PROTOCOL__), to!string(response.protocol)]));
					}
				}
			} else {
				this.logger.logError(Translation("warning.refused"));
			}

			this.handler.close();

		}
		
	}

	private shared void handleInfo() {

		ubyte[] buffer = this.handler.receive();
		if(buffer.length && buffer[0] == HncomLogin.HubInfo.ID) {
			this.handleInfoImpl(HncomLogin.HubInfo.fromBuffer(buffer[1..$]));
		} else {
			this.logger.logError(Translation("warning.closed"));
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
			config.hub.edu = edu && edu.type == JSON_TYPE.TRUE;
		}

		config.hub.displayName = info.displayName;

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

		if(!this.lite) this.logger.terminal.title = info.displayName ~ " | node | " ~ Software.simpleDisplay;

		void handleGameInfo(ubyte type, HncomLogin.HubInfo.GameInfo info) {
			void set(ref Config.Hub.Game game) {
				game.enabled = true;
				game.protocols = info.protocols;
				game.motd = info.motd;
				game.onlineMode = info.onlineMode;
			}
			if(type == __JAVA__) {
				set(config.hub.java);
			} else if(type == __BEDROCK__) {
				set(config.hub.bedrock);
			} else {
				this.logger.logError(Translation("warning.invalidGame", [to!string(type), Software.name]));
			}
		}

		foreach(game, info ; info.gamesInfo) {
			handleGameInfo(game, info);
		}

		// check protocols and print warnings if necessary
		void check(string name, uint[] requested, uint[] supported) {
			foreach(req ; requested) {
				if(!supported.canFind(req)) {
					this.logger.logWarning(Translation("warning.invalidProtocol", [to!string(req), name]));
				}
			}
		}

		check("Minecraft: Java Edition", config.hub.java.protocols, supportedJavaProtocols);
		check("Minecraft (Bedrock Engine)", config.hub.bedrock.protocols, supportedBedrockProtocols);

		this._config = cast(shared)config;

		this.finishConstruction();

	}

	private shared void finishConstruction() {

		if(!this.lite) this.logger.log(Translation("startup.starting", [Format.green ~ Software.name ~ Format.white ~ " " ~ Software.fullVersion ~ Format.reset ~ " " ~ Software.fullCodename]));

		static if(!__supported) {
			this.logger.logWarning(Translation("startup.unsupported", [Software.name]));
		}

		this.globalListener = new EventListener!WorldEvent();

		// default skins for players that connect with invalid skins
		Skin.STEVE = Skin("Standard_Steve", read_png_from_mem(cast(ubyte[])this.config.files.readAsset("skin/steve.png")).pixels);
		Skin.ALEX = Skin("Standard_Alex", read_png_from_mem(cast(ubyte[])this.config.files.readAsset("skin/alex.png")).pixels);

		// load creative inventories
		foreach(protocol ; SupportedBedrockProtocols) {
			string[] failed;
			if(this.config.hub.bedrock.protocols.canFind(protocol)) {
				if(!mixin("BedrockPlayerImpl!" ~ protocol.to!string).loadCreativeInventory(this.config.files)) {
					failed ~= bedrockSupportedProtocols[protocol];
				}
			}
			if(failed.length) {
				this.logger.logWarning(Translation("warning.creativeFailed", [failed.join(", ")]));
			}
		}

		// create resource pack files
		string[] textures = []; // ordered from least prioritised to most prioritised
		foreach_reverse(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			if(plugin.textures !is null) textures ~= plugin.textures;
		}
		if(textures.length) {
			
			this.logger.log(Translation("startup.resourcePacks"));

			auto rp_uuid = this.nextUUID;
			auto rp = createResourcePacks(this, rp_uuid, textures);
			std.concurrency.spawn(&serveResourcePacks, std.concurrency.thisTid, cast(string)rp.java2.idup, cast(string)rp.java3.idup);
			ushort port = std.concurrency.receiveOnly!ushort();

			import myip : publicAddress4;

			auto ip = publicAddress4;
			//TODO also try to use private addresses before using 127.0.0.1

			JavaPlayer.updateResourcePacks(rp.java2, rp.java3, ip.length ? ip : "127.0.0.1", port);
			BedrockPlayer.updateResourcePacks(rp_uuid, rp.pocket1);

		}

		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast(NodePluginInfo)_plugin;
			plugin.load(this);
			if(plugin.main) {
				auto args = [
					Format.green ~ plugin.name ~ Format.reset,
					Format.white ~ (plugin.authors.length ? plugin.authors.join(Format.reset ~ ", " ~ Format.white) : "?") ~ Format.reset,
					Format.white ~ plugin.vers
				];
				this.logger.log(Translation("startup.plugin.enabled" ~ (plugin.authors.length ? ".author" : (!plugin.vers.startsWith("~") ? ".version" : "")), args));
			}
		}
		
		// register commands if enabled in the settings
		Commands.register(this);

		// send node's informations to the hub and switch to a non-blocking connection
		HncomLogin.NodeInfo nodeInfo;
		uint[][ubyte] games;
		if(this.config.node.bedrock) nodeInfo.acceptedGames[__BEDROCK__] = cast(uint[])this.config.node.bedrock.protocols;
		if(this.config.node.java) nodeInfo.acceptedGames[__JAVA__] = cast(uint[])this.config.node.java.protocols;
		nodeInfo.max = this.config.node.maxPlayers; // 0 for unlimited, like in the config file
		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			nodeInfo.plugins ~= HncomLogin.NodeInfo.Plugin(plugin.id, plugin.name, plugin.vers);
		}
		if(this.lite) {
			std.concurrency.send(cast()(cast(shared MessagePassingHandler)this.handler).hub, cast(shared)nodeInfo);
		} else {
			this.handler.send(nodeInfo.encode());
		}
		
		// load plugin's language files
		foreach(_plugin ; this.n_plugins) {
			auto plugin = cast()_plugin;
			foreach(language, messages; this.config.lang.loadPlugin(plugin)) {
				this.updateLanguageFiles(language, messages);
			}
		}

		this.logger.log(Translation("test"));

		if(!this.lite) std.concurrency.spawn(&this.handler.receiveLoop, cast()this.tid);
		
		this.start_time = milliseconds;

		// call @start functions
		foreach(plugin ; this.n_plugins) {
			foreach(del ; plugin.onstart) {
				del();
			}
		}
		
		if(this._main_group_id == 0) {
			//TODO load world in worlds/world
			this.addWorld("world");
		}

		//TODO wait unitl world's spawn area is ready

		this.logger.log(Translation("startup.started"));

		Terminal terminal = (cast()this._logger).terminal;
		if(this.lite) {
			this._logger = this.serverlogger = cast(shared)new LiteServerLogger(terminal, this.lang);
		} else {
			this._logger = this.serverlogger = cast(shared)new NodeServerLogger(terminal, this.lang);
		}

		// start calculation of used resources
		std.concurrency.spawn(&startResourceUsageThread, getpid);

		// start command reader
		std.concurrency.spawn(&startCommandReaderThread, cast()this.tid);
		
		this.start();

	}

	private shared void start() {
		
		//TODO request first latency calculation

		while(running) {

			// receive messages
			std.concurrency.receive(
				&handlePromptCommand,
				&handleCloseResult,
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

		this.logger.log(Translation("startup.stopped"));

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
	 * Gets the arguments the server has been launched with, excluding the ones
     * used to edit the configuration files.
	 * Example:
	 * ---
	 * // from command-line
	 * ./selery --display-name=test -a -b
	 * assert(server.args == ["-a", "-b"]);
	 * ---
     *
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

	public override shared @property Logger logger() {
		return cast()this._logger;
	}

	public shared void logCommand(Message[] messages, int commandId) {
		(cast()this.serverlogger).logWith(messages, commandId);
	}

	public shared void logWorld(Message[] messages, int worldId) {
		(cast()this.serverlogger).logWith(messages, HncomStatus.Log.NO_COMMAND, worldId);
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
	 * Sets the maximum number of players that can connect to the
	 * current node.
	 * 0 can be used for unlimited players.
	 */
	public shared @property size_t max(uint max) {
		this._config.node.maxPlayers = max;
		this.handler.send(HncomStatus.UpdateMaxPlayers(max).encode());
		return max;
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
		return this.config.node.name;
	}

	/**
	 * Gets whether or not this is a main node (players are added
	 * when connected to hub) or not (player are added only when
	 * transferred by other nodes).
	 */
	public shared pure nothrow @property @safe @nogc bool isMainNode() {
		return this.config.node.main;
	}

	/**
	 * Gets the server's social informations like website and social
	 * networks' names.
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
	 *    writeln("the hub is ipv4 localhost!");
	 * } else if(server.hubAddress.toAddrString() == "::1") {
	 *    writeln("The hub is ipv6 localhost!");
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
	 * writeln("The server is online from ", server.uptime.minutes, " minutes");
	 * 
	 * ulong m, s;
	 * server.uptime.split!("minutes", "seconds")(m, s);
	 * writeln("The server is online from ", m, " minutes and ", s, " seconds");
	 * ---
	 */
	public shared @property @safe Duration uptime() {
		return dur!"msecs"(milliseconds - this.start_time);
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
	 * Updates langauge files (in config) and send the UpdateLanguageFiles packet to
	 * the hub if needed.
	 */
	protected shared void updateLanguageFiles(string language, string[string] messages) {
		if(!this.lite) this.config.lang.add(language, messages);
		this.handler.send(HncomStatus.UpdateLanguageFiles(language, messages).encode());
	}

	public shared pure nothrow @property shared(GroupInfo) mainWorldGroup() {
		return this._groups[this._main_group_id];
	}

	/**
	 * Gets the default world of the server's main group of worlds.
	 */
	public shared pure nothrow @property shared(WorldInfo) defaultWorld() {
		return this.mainWorldGroup.defaultWorld;
	}

	/**
	 * Gets a list with every world registered in the server.
	 * The list is a copy of the one kept by the server and its
	 * modification has no effect on the server.
	 */
	public shared pure nothrow @property shared(GroupInfo)[] worldGroups() {
		return this._groups.values;
	}

	/**
	 * Gets a world by its name.
	 * Returns: the WorldInfo of the world with the given name or null if a world with the given name doesn't exists.
	 */
	public shared @property shared(GroupInfo) getGroupByName(string name) {
		auto group = name in this._groups_names;
		return group ? *group : null;
	}

	/**
	 * Creates a new group of worlds with the given name and starts it in a new thread.
     * This method only creates a group, which is a container for worlds, but no actual world.
     * To create a world the addWorld method must be used.
     * Example:
     * ---
     * auto group = server.addWorldGroup("MyGroup");
     * auto world = server.addWorld(group, 0); // where 0 is the seed
     * ---
	 */
	public shared synchronized shared(GroupInfo) addWorldGroup(string name) {
		if(name !in this._groups_names) {
			shared GroupInfo group = new shared GroupInfo(name);
			this._groups[group.id] = group;
			this._groups_names[name] = group;
			bool main = false;
			if(this._main_group_id == 0) {
				this._main_group_id = group.id;
				main = true;
			}
			group.tid = cast(shared)std.concurrency.spawn(&spawnWorldGroup, this, group, main);
			return group;
		} else {
			return null;
		}
	}
	
	/**
	 * Creates and registers a world in the given group, initialising its terrain,
	 * registering events, commands and tasks.
	 * Returns: the WorldInfo of the created world.
     * Example:
     * ---
     * server.addWorld(server.mainWorldGroup);
     * server.addWorld(server.addWorldGroup("test"));
     * ---
	 */
	public shared synchronized shared(WorldInfo) addWorld(T:World=World, E...)(shared GroupInfo group, E args) {
		shared WorldInfo world = new shared WorldInfo();
		// this is also done after the world is created, but the thread can
		// be busy and the world may not be asigned in time, resulting in an
		// error when the list of worlds or the `defaultWorld` variable are requested
		group.worlds[world.id] = world;
		if(group.defaultWorld is null) group.defaultWorld = world;
		// request the new world
		std.concurrency.send(cast()group.tid, AddWorld(cast(shared)new AddWorld.Create!T(world, args))); // the world is then added to the group in the group's thread
		return world;
	}

    /**
     * Creates a group with the given name and adds the given world.
     * Example:
     * ---
     * server.addWorld("test");
     * ---
     */
	public shared synchronized shared(WorldInfo) addWorld(T:World=World, E...)(string name, E args) {
		return this.addWorld!T(this.addWorldGroup(name), args);
	}

	public shared synchronized bool removeWorldGroup(uint groupId) {
		auto group = groupId in this._groups;
		if(group) {
			if(groupId == this._main_group_id) {
				this.logger.logWarning(Translation("warning.removingMainGroup", group.name));
			} else {
				std.concurrency.send(cast()group.tid, Close()); // wait for CloseResult before removing the world
				return true;
			}
		}
		return false;
	}

	/// ditto
	public shared synchronized bool removeWorldGroup(shared GroupInfo group) {
		return this.removeWorldGroup(group.id);
	}

	public shared synchronized void removeWorld(shared WorldInfo world) {
		std.concurrency.send(cast()world.group.tid, RemoveWorld(world.id));
	}

	protected shared void handleCloseResult(CloseResult result) {
		auto group = result.groupId in this._groups;
		if(group) {
			if(result.status == CloseResult.PLAYERS_ONLINE) {
				this.logger.logWarning(Translation("warning.removingWithPlayers", group.name));
			} else {
				this._groups.remove(group.id);
				this._groups_names.remove(group.name);
			}
		}
	}

	/**
	 * Gets a list with all the players in the server.
	 */
	public shared pure nothrow @property shared(PlayerInfo)[] players() {
		return this._players.values;
	}

	/**
	 * Broadcasts a message in every registered group and their worlds`
	 * calling the world's broadcast method.
	 */
	public shared void broadcast(string message) {
		foreach(group ; this._groups) {
			std.concurrency.send(cast()group.tid, Broadcast(message));
		}
	}

	public shared void updateGroupDifficulty(shared GroupInfo group, Difficulty difficulty) {
		std.concurrency.send(cast()group.tid, UpdateDifficulty(difficulty));
	}

	public shared void updatePlayerGamemode(shared PlayerInfo player, Gamemode gamemode) {
		std.concurrency.send(cast()player.world.group.tid, UpdatePlayerGamemode(player.hubId, gamemode));
	}

	public shared void updatePlayerPermissionLevel(shared PlayerInfo player, PermissionLevel permissionLevel) {
		std.concurrency.send(cast()player.world.group.tid, UpdatePlayerPermissionLevel(player.hubId, permissionLevel));
	}

	/**
	 * Registers a command.
	 */
	public void registerCommand(alias func)(void delegate(Parameters!func) del, string command, Description description, string[] aliases, ubyte permissionLevel, string[] permissions, bool hidden, bool implemented=true) {
		if(command !in this._commands) this._commands[command] = cast(shared)new Command(command, description, aliases, permissionLevel, permissions, hidden);
		auto ptr = command in this._commands;
		(cast()*ptr).add!func(del, implemented);
		foreach(alias_ ; aliases) this._commands[alias_] = *ptr;
	}

	public shared @property auto commands() {
		return this._commands;
	}

	// hub-node communication and related methods

	/*
	 * Kicks a player from the server using Player.kick.
	 */
	public shared void kick(uint hubId, string reason) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.kicked)) {
			this.handler.send(HncomPlayer.Kick(hubId, reason, false).encode());
		}
	}

	/// ditto
	public shared void kick(uint hubId, string reason, inout(string)[] args) {
		if(this.removePlayer(hubId, PlayerLeftEvent.Reason.kicked)) {
			this.handler.send(HncomPlayer.Kick(hubId, reason, true, cast(string[])args).encode());
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
				std.concurrency.send(cast()(*player).world.group.tid, RemovePlayer(hubId));
			}
			this._players.remove(hubId);
			(cast()this).callEventIfExists!PlayerLeftEvent(this, cast(const)*player, reason);
			return true;
		} else {
			return false;
		}
	}
	
	public shared void updatePlayerDisplayName(uint hubId) {
		auto player = hubId in this._players;
		if(player) this.handler.send(HncomPlayer.UpdateDisplayName(hubId, (*player).displayName).encode());
	}

	// hncom handlers

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
	
	protected override void handleStatusRemoteCommand(HncomStatus.RemoteCommand packet) {
		with(packet) (cast(shared)this).handleCommand(cast(ubyte)(origin + 1), sender, command, commandId);
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

	protected override void handleStatusUpdateDisplayName(HncomStatus.UpdateDisplayName packet) {
		this._config.hub.displayName = packet.displayName;
	}

	protected override void handleStatusUpdateMOTD(HncomStatus.UpdateMOTD packet) {
		// assuming that is already parsed
		if(packet.type == __BEDROCK__) this._config.hub.bedrock.motd = packet.motd;
		else if(packet.type == __JAVA__) this._config.hub.java.motd = packet.motd;
	}

	protected override void handleStatusUpdateSupportedProtocols(HncomStatus.UpdateSupportedProtocols packet) {
		//TODO
	}

	protected override void handleStatusWebAdminCredentials(HncomStatus.WebAdminCredentials packet) {
		//TODO start http server for panel
	}

	protected override void handlePlayerAdd(HncomPlayer.Add packet) {

		Skin skin = Skin(packet.skin.expand);

		if(!skin.valid) {
			// http://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/UUID.java#l394
			string data = packet.uuid.toString().replace("-", "");
			skin = (data[7] ^ data[15] ^ data[23] ^ data[31]) ? Skin.ALEX : Skin.STEVE;
		}

		shared PlayerInfo player = cast(shared)new PlayerInfo(packet);
		player.skin = skin;

		// add to the lists
		this._players[player.hubId] = player;

		auto event = (cast()this).callEventIfExists!PlayerJoinEvent(cast(shared)this, cast(const)player, packet.reason);

		//TODO allow kicking from event

		// do not spawn if it has been disconnected during the event
		if(player.hubId in this._players) {
			
			shared(WorldInfo) world;
			if(event is null || event.world is null || event.world.group.id !in this._groups) {
				world = (cast(shared)this).defaultWorld;
			}

			// set the world before the group's thread does to avoid null references
			player.world = world;

			std.concurrency.send(cast()world.group.tid, AddPlayer(player, world.id, packet.reason != HncomPlayer.Add.FIRST_JOIN));

		}

	}

	protected override void handlePlayerRemove(HncomPlayer.Remove packet) {
		(cast(shared)this).removePlayer(packet.hubId, packet.reason);
	}

	protected override void handlePlayerUpdateDisplayName(HncomPlayer.UpdateDisplayName packet) {
		//TODO
	}

	protected override void handlePlayerUpdatePermissionLevel(HncomPlayer.UpdatePermissionLevel packet) {
		auto player = packet.hubId in this._players;
		if(player) {
			(cast(shared)this).updatePlayerPermissionLevel(*player, cast(PermissionLevel)packet.permissionLevel);
		}
	}

	protected override void handlePlayerUpdateViewDistance(HncomPlayer.UpdateViewDistance packet) {
		//TODO
	}

	protected override void handlePlayerUpdateLanguage(HncomPlayer.UpdateLanguage packet) {
		//TODO
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
			std.concurrency.send(cast()(*player).world.group.tid, GamePacket(packet.hubId, packet.payload.idup));
		}
	}

	private shared void handlePromptCommand(string command) {
		this.handleCommand(0, null, command);
	}

	// handles a command from various sources.
	private shared void handleCommand(ubyte origin, Address address, string command, int id=-1) {
		auto sender = new ServerCommandSender(this, this._commands, origin, address, id);
		executeCommand(sender, command).trigger(sender);
	}

}

final class ServerCommandSender : CommandSender {

	enum Origin : ubyte {

		prompt = 0,
		hub = HncomStatus.RemoteCommand.HUB + 1,
		webAdmin = HncomStatus.RemoteCommand.WEB_ADMIN + 1,
		rcon = HncomStatus.RemoteCommand.RCON + 1,

	}

	private shared NodeServer _server;
	private shared Command[string] _commands;
	public immutable ubyte origin;
	public const Address address;
	private int id;

	public this(shared NodeServer server, shared Command[string] commands, ubyte origin, Address address, int id) {
		this._server = server;
		this._commands = commands;
		this.origin = origin;
		this.address = address;
		this.id = id;
	}

	public override pure nothrow @property @safe @nogc shared(NodeServer) server() {
		return this._server;
	}

	public override @property Command[string] availableCommands() {
		return cast(Command[string])this._commands;
	}

	protected override void sendMessageImpl(Message[] messages) {
		this._server.logCommand(messages, this.id);
	}

	alias server this;

}

private abstract class ServerLogger : Logger {

	public this(Terminal terminal, inout LanguageManager lang) {
		super(terminal, lang);
	}

	public override void logMessage(Message[] messages) {
		this.logWith(messages);
	}

	/**
	 * Creates a log with commandId and worldId.
	 */
	public void logWith(Message[] messages, int commandId=HncomStatus.Log.NO_COMMAND, int worldId=HncomStatus.Log.NO_WORLD) {
		this.logWithImpl(messages, commandId, worldId);
	}

	protected abstract void logWithImpl(Message[], int, int);

}

private class NodeServerLogger : ServerLogger {

	public this(Terminal terminal, inout LanguageManager lang) {
		super(terminal, lang);
	}

	// prints to the console and send to the hub
	protected override void logWithImpl(Message[] messages, int commandId, int worldId) {
		this.logImpl(messages);
		Handler.sharedInstance.send(HncomStatus.Log(encodeHncomMessage(messages), milliseconds, commandId, worldId).encode());
	}

}

private class LiteServerLogger : ServerLogger {

	public this(Terminal terminal, inout LanguageManager lang) {
		super(terminal, lang);
	}

	// only send to the hub
	protected override void logWithImpl(Message[] messages, int commandId, int worldId) {
		Handler.sharedInstance.send(HncomStatus.Log(encodeHncomMessage(messages), milliseconds, commandId, worldId).encode());
	}

}

private HncomStatus.Log.Message[] encodeHncomMessage(Message[] messages) {
	HncomStatus.Log.Message[] ret;
	string next;
	void addText() {
		ret ~= HncomStatus.Log.Message(false, next, []);
		next.length = 0;
	}
	foreach(message ; messages) {
		final switch(message.type) {
			case Message.FORMAT:
				next ~= message.format;
				break;
			case Message.TEXT:
				next ~= message.text;
				break;
			case Message.TRANSLATION:
				if(next.length) addText();
				ret ~= HncomStatus.Log.Message(true, message.translation.translatable.default_, message.translation.parameters);
				break;
		}
	}
	if(next.length) addText();
	return ret;
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

//TODO use Terminal
private void startCommandReaderThread(std.concurrency.Tid tid) {

	debug Thread.getThis().name = "CommandReader";

	import std.stdio : readln;
	while(true) {
		std.concurrency.send(tid, readln());
	}

}
