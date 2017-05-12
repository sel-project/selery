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
module sel.hub.server;

import core.atomic : atomicOp;
import core.cpuid;
import core.sys.posix.signal;
import core.thread;

import std.algorithm : sort;
import std.ascii : newline;
import std.bitmanip : nativeToBigEndian;
import std.conv : to;
import std.file;
import std.json;
import std.math : round;
import std.net.curl;
import std.random : uniform;
import std.socket;
import std.string : join, split, toLower, strip, indexOf;
import std.system : endian;
import std.typecons;
import std.uuid : parseUUID, UUID;
import std.utf : UTFException;

import sel.about;
import sel.format : Text;
import sel.lang : Lang, translate, Translation;
import sel.path : Paths;
import sel.plugin : Plugin;
import sel.utils : milliseconds;
import sel.hub.settings;
import sel.network.handler : Handler;
import sel.session.externalconsole : ExternalConsoleSession;
import sel.session.hncom : Node;
import sel.session.player : PlayerSession;
import sel.session.rcon : RconSession;
import sel.util.analytics : GoogleAnalytics;
import sel.util.block : Blocks;
import sel.util.ip : localAddresses, publicAddresses;
import sel.util.logh : log;
import sel.util.thread;

mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".login : HubInfo, NodeInfo;");
mixin("import sul.protocol.hncom" ~ Software.hncom.to!string ~ ".status : RemoteCommand;");

mixin("import sul.protocol.externalconsole" ~ Software.externalConsole.to!string ~ ".types : NodeStats;");

/+version(Windows) {
	
	import core.sys.windows.wincon : CTRL_C_EVENT;
	import core.sys.windows.windef : DWORD, BOOL;
	
	alias extern (Windows) BOOL function(DWORD) PHANDLER_ROUTINE;
	extern (Windows) BOOL SetConsoleCtrlHandler(PHANDLER_ROUTINE, BOOL);
	
	extern (Windows) int sigHandler(uint sig) {
		if(sig == CTRL_C_EVENT) {
			Server.instance.shutdown();
			return true; // this will let the process run in background until it kills himself
		}
		return false; // windows will instantly kill the process
	}
	
} else version(Posix) {
	
	import core.sys.posix.signal;
	
	extern (C) void extsig(int sig) {
		Server.instance.shutdown();
		//server.stop();
	}
	
}+/

class Server {

	private static shared Server n_instance;

	public static nothrow @safe @nogc shared(Server) instance() {
		return n_instance;
	}

	public immutable ulong id;
	private shared ulong uuid_count;

	private immutable ulong started;

	private shared Settings n_settings;

	private shared uint n_max;
	private shared size_t unlimited_nodes = 0;

	private shared Traffic n_traffic;

	private shared uint n_upload, n_download;

	private shared List n_whitelist;
	private shared List n_blacklist;

	private shared Handler handler;
	private shared Blocks blocks;

	private shared Node[immutable(uint)] nodes;
	private shared Node[] main_nodes;
	private shared Node[string] nodesNames;
	private shared size_t[string] n_plugins;

	private shared ExternalConsoleSession[immutable(uint)] externalConsoles;
	private shared RconSession[immutable(uint)] rcons;
	
	private shared PlayerSession[immutable(uint)] n_players;

	private shared GoogleAnalytics analytics;

	public shared this(bool lite, bool edu, bool realm, Plugin[] plugins) {

		n_instance = this;

		this.n_whitelist = List(this, "whitelist");
		this.n_blacklist = List(this, "blacklist");

		auto settings = Settings(lite, edu, realm);
		settings.load();
		this.n_settings = cast(shared)settings;

		version(Windows) {
			import std.process : executeShell;
			executeShell("title " ~ this.n_settings.displayName ~ " ^| " ~ (!lite ? "hub ^| " : "") ~ Software.display);
		}

		Lang.init([this.n_settings.language], [Paths.langSystem]); //TODO load plugin's lang files

		log(translate(Translation("startup.starting"), this.n_settings.language, [Text.green ~ Software.name ~ Text.reset ~ " " ~ Software.fullVersion ~ " " ~ Software.fullCodename]));
		log(translate(Translation("startup.started"), this.n_settings.language), "\n");

		static if(!__supported) {
			log(translate(Translation("startup.unsupported"), this.n_settings.language, [Software.name]));
		}

		version(DigitalMars) {
			debug {} else {
				// buggy in DMD's release mode
				//TODO print message
			}
		}

		long id;
		bool snoop_enabled = false;
		/*try {
			JSONValue[string] login;
			with(Software) login["software"] = ["name": JSONValue(name), "version": JSONValue([major, minor, patch]), "stable": JSONValue(stable)];
			login["online"] = __onlineMode;
			if(this.n_settings.minecraft) login["minecraft"] = this.n_settings.minecraft.protocols;
			if(this.n_settings.pocket) login["pocket"] = this.n_settings.pocket.protocols;
			login["edu"] = edu;
			login["realm"] = realm;
			login["lang"] = this.n_settings.language;
			login["bits"] = size_t.sizeof * 8;
			login["endianness"] = cast(int)endian;
			login["processor"] = processor;
			login["cores"] = coresPerCPU;
			//log(JSONValue(login).toString(), "\n");
			id = to!ulong(post("http://snoop." ~ Software.website ~ "/login", JSONValue(login).toString()));
		} catch(Throwable) {*/

		this.id = uniform!"[]"(ulong.min, ulong.max);
		this.uuid_count = uniform!"[]"(ulong.min, ulong.max);

		/*if(this.n_settings.whitelist) {
			this.n_whitelist.load();
			this.n_whitelist.save();
		}

		if(this.n_settings.blacklist) {
			this.n_blacklist.load();
			this.n_blacklist.save();
		}*/
		
		auto pa = publicAddresses;
		if(pa.v4.length || pa.v6.length) {
			if(pa.v4.length) log("Public ip: ", pa.v4);
			if(pa.v6.length) log("Public ipv6: ", pa.v6);
			log();
		}
		
		this.blocks = new Blocks();

		this.handler = new shared Handler(this);

		// listen for commands
		auto reader = new Thread({
			import std.stdio : readln;
			while(true) {
				try {
					handleCommand(readln().strip);
				} catch(UTFException e) {
					log(Text.red, e.msg);
				}
			}
		});
		reader.name = "reader";
		reader.start();

		if(snoop_enabled) {
			auto snoop = new SafeThread({
				while(true) {
					Thread.sleep(dur!"minutes"(1));
					JSONValue[string] status;
					status["online"] = this.onlinePlayers;
					status["max"] = this.maxPlayers;
					status["nodes"] = this.nodes.length;
					post("http://snoop." ~ Software.website ~ "/status", JSONValue(status).toString());
				}
			});
			snoop.name = "snoop";
			snoop.start();
		}

		/*version(Windows) {
			SetConsoleCtrlHandler(&sigHandler, true);
		} else version(linux) {
			sigset(SIGTERM, &extsig);
			sigset(SIGINT, &extsig);
		}*/

		Thread.getThis().name = "main";

		if(this.n_settings.googleAnalytics.length) {
			this.analytics = new shared GoogleAnalytics(this.n_settings.googleAnalytics);
		}

		this.started = milliseconds;

		int last_online, last_max = this.maxPlayers;
		size_t next_analytics = 0;
		while(true) {
			uint online = this.onlinePlayers.to!uint;
			if(online != last_online || this.maxPlayers != last_max) {
				last_online = online;
				last_max = this.maxPlayers;
				foreach(node ; this.nodes) {
					node.updatePlayers(last_online, last_max);
				}
			}
			auto sent = cast(uint)(this.n_traffic.sent.to!float / 5f);
			auto recv = cast(uint)(this.n_traffic.received.to!float / 5f);
			if(this.externalConsoles.length) {
				auto uptime = this.uptime;
				auto nodeStats = this.externalConsoleNodeStats;
				foreach(externalConsole ; this.externalConsoles) {
					externalConsole.updateStats(online, last_max, uptime, sent, recv, nodeStats);
				}
			}
			this.n_upload = sent;
			this.n_download = recv;
			this.n_traffic.reset();
			if(this.analytics !is null) {
				if(++next_analytics == 12) {
					next_analytics = 0;
					this.analytics.updatePlayers(this.players);
				}
				this.analytics.sendRequests();
			}
			Thread.sleep(dur!"msecs"(5000));
			this.blocks.remove(5);
		}

	}

	public shared void shutdown() {
		this.handler.shutdown();
		foreach(node ; this.nodes) node.onClosed(false);
		import core.stdc.stdlib : exit;
		log("Shutting down");
		exit(0);
	}

	public shared nothrow @property UUID nextUUID() {
		ubyte[16] data = nativeToBigEndian(this.id) ~ nativeToBigEndian(this.uuid_count);
		atomicOp!"+="(this.uuid_count, 1);
		return UUID(data);
	}

	public shared nothrow @property @trusted @nogc ulong nextPool() {
		ulong pool = this.uuid_count;
		atomicOp!"+="(this.uuid_count, uint.max);
		return pool;
	}

	/**
	 * Gets the server's uptime in milliseconds.
	 */
	public shared @property @safe const uint uptime() {
		return cast(uint)(milliseconds - this.started);
	}

	/**
	 * Gets the server's settings.
	 */
	public shared nothrow @property @safe @nogc ref const(shared(Settings)) settings() {
		return this.n_settings;
	}

	/**
	 * Gets the server's traffic tracker.
	 */
	public shared nothrow @property @safe @nogc ref shared(Traffic) traffic() {
		return this.n_traffic;
	}

	/// ditto
	public shared nothrow @property @safe @nogc const uint upload() {
		return this.n_upload;
	}

	/// ditto
	public shared nothrow @property @safe @nogc const uint download() {
		return this.n_download;
	}

	/**
	 * Gets the server's whitelist.
	 */
	public shared nothrow @property @safe @nogc ref shared(List) whitelist() {
		return this.n_whitelist;
	}

	/**
	 * Gets the server's blacklist.
	 */
	public shared nothrow @property @safe @nogc ref shared(List) blacklist() {
		return this.n_blacklist;
	}

	/**
	 * Gets the number of online players.
	 */
	public shared nothrow @property @safe @nogc const uint onlinePlayers() {
		version(X86_64) {
			return cast(uint)this.n_players.length;
		} else {
			return this.n_players.length;
		}
	}

	/**
	 * Gets the number of max players.
	 */
	public shared nothrow @property @safe @nogc const int maxPlayers() {
		return this.unlimited_nodes ? HubInfo.UNLIMITED : this.n_max;
	}

	/**
	 * Indicates whether the server is full.
	 */
	public shared @property @safe @nogc const(bool) full() {
		if(this.unlimited_nodes) return false;
		foreach(node ; this.nodes) {
			if(!node.full) return false;
		}
		return true;
	}

	/**
	 * Gets the online players.
	 */
	public shared @property shared(PlayerSession[]) players() {
		return this.n_players.values;
	}

	/**
	 * Gets the plugin used by the connected nodes.
	 */
	public shared @property string[] plugins() {
		return this.n_plugins.keys;
	}

	/**
	 * Creates node stats for the external console.
	 */
	public shared @property @safe NodeStats[] externalConsoleNodeStats() {
		NodeStats[] ret;
		foreach(node ; this.nodes) {
			ret ~= NodeStats(node.name, node.tps, node.ram, node.cpu);
		}
		return ret;
	}

	public shared void handleCommand(string str, ubyte origin=RemoteCommand.HUB, Address source=null, int commandId=-1) {
		// console, external console, rcon
		string[] spl = str.split(" ");
		if(spl.length) {
			string cmd = spl[0].toLower.idup;
			if(!cmd.length) return;
			string[] args = spl[1..$];
			switch(cmd) {
				case "about":
					//TODO print informations about a player
					break;
				case "disconnect":
					switch(args.length ? args[0].toLower : "") {
						case "node":
							//TODO disconnect a node
							// disconnect node <name>
							break;
						case "ec":
						case "externalconsole":
							//TODO disconnect external console
							// disconnect ec *
							// disconnect ec 192.168.2.5
							// disconnect ec ::1
							break;
						case "rcon":
							//TODO disconnect rcon
							break;
						default:
							log("Usage: 'disconnect <node|externalconsole|rcon> <id>'");
							break;
					}
					break;
				case "help":
					this.command(join([
							"about <player>",
							"disconnect <node|externalconsole|rcon> <id>",
							"kick <player> [reason]",
							"latency",
							"nodes",
							"players",
							"reload",
							"say <message>",
							"stop",
							"threads",
							"transfer <player> <node>",
							"usage [node]",
							"<node> <command> [args]"
						], "\n"), commandId);
					break;
				case "kick":
					//TODO kicks a player
					// Player::onKicked(args.join(" "));
					break;
				case "latency":
					string[] list;
					foreach(node ; this.nodes) {
						list ~= node.name ~ ": " ~ to!string(node.latency) ~ " ms";
					}
					this.command(list.join(", "), commandId);
					break;
				case "nodes":
					string[] nodes;
					foreach(shared Node node ; this.nodes) {
						nodes ~= node.toString();
					}
					this.command("Nodes: " ~ nodes.join(", "), commandId);
					break;
				case "players":
					string[] list;
					foreach(shared PlayerSession player ; this.n_players) {
						list ~= player.username ~ " (" ~ player.game ~ ")";
					}
					this.command("Players (" ~ to!string(list.length) ~ "): " ~ list.join(", "), commandId);
					break;
				case "reload":
					this.n_max = 0;
					this.unlimited_nodes = 0;
					(cast()this.n_settings).load();
					this.handler.reload();
					foreach(node ; this.nodes) node.reload();
					this.command(Text.green ~ "Server's configurations have been reloaded", commandId);
					break;
				case "say":
					string command = "say " ~ args.join(" ");
					foreach(shared Node node ; this.nodes) {
						node.remoteCommand(command, origin, source, commandId);
					}
					break;
				case "stop":
					this.shutdown();
					break;
				case "threads":
					string[] names;
					foreach(thread ; Thread.getAll()) {
						names ~= thread.name;
					}
					sort(names);
					this.command("Threads (" ~ to!string(names.length) ~ "): " ~ names.join(", "), commandId);
					break;
				case "transfer":
					//TODO transfer the player to args[0]
					break;
				case "usage":
					if(args.length) {
						auto node = this.nodeByName(args[0]);
						if(node !is null) {
							this.command(args[0] ~ ": " ~ to!string(node.tps) ~ " TPS", commandId);
						} else {
							this.command("Use 'usage <node>'", commandId);
						}
					} else {
						this.command("Upload: " ~ to!string(this.n_upload.to!float / 1000) ~ " kB/s, Download: " ~ to!string(this.n_download.to!float / 1000) ~ " kb/s", commandId);
					}
					break;
				default:
					shared Node node;
					if(this.nodes.length == 1) {
						node = this.nodes[0];
						if(node.name != cmd) args = cmd ~ args;
					} else {
						node = this.nodeByName(cmd.idup);
					}
					if(node !is null) {
						if(args.length) node.remoteCommand(args.join(" "), origin, source, commandId);
					} else {
						this.command("Node '" ~ cmd ~ "' is not connected", commandId);
					}
					break;
			}
		}
	}

	public shared void message(string node, ulong timestamp, string logger, string message, int commandId) {
		if(node.length) {
			log("[", node, "][", logger, "] ", message);
		} else {
			log("[", logger, "] ", message);
		}
		foreach(externalConsole ; this.externalConsoles) {
			externalConsole.consoleMessage(node, timestamp, logger, message, commandId);
		}
		if(id != -1) {
			foreach(rcon ; this.rcons) {
				rcon.consoleMessage(message, commandId);
			}
		}
	}

	private shared void command(string message, int commandId) {
		this.message("", milliseconds, "command", message, commandId);
	}

	public shared nothrow @safe @nogc bool isBlocked(Address address) {
		return this.blocks.isBlocked(address);
	}

	public shared bool block(Address address, size_t seconds) {
		if(this.blocks.block(address, seconds)) {
			log(translate(Translation("warning.blocked"), this.n_settings.language, [to!string(address), to!string(seconds)]));
			return true;
		} else {
			return false;
		}
	}

	public shared bool acceptNode(Address address) {
		version(Posix) {
			if(cast(UnixAddress)address) return true;
		}
		if(this.n_settings.maxNodes != 0) {
			if(this.nodes.length >= this.n_settings.maxNodes) return false;
		}
		// check if it's an IPv4-mapped in IPv6
		if(cast(Internet6Address)address) {
			auto v6 = cast(Internet6Address)address;
			ubyte[] bytes = v6.addr;
			if(bytes[10] == 255 && bytes[11] == 255) { // ::ffff:127.0.0.1
				address = new InternetAddress(to!string(bytes[12]) ~ "." ~ to!string(bytes[13]) ~ "." ~ to!string(bytes[14]) ~ "." ~ to!string(bytes[15]), v6.port);
			}
		}
		foreach(ar ; this.settings.acceptedNodes) {
			if((cast()ar).contains(address)) return true;
		}
		return false;
	}

	public shared nothrow @property @safe @nogc bool hasNodes() {
		return this.nodes.length != 0;
	}

	/**
	 * Returns: the first main node which is not full
	 */
	public shared nothrow @property @safe @nogc shared(Node) mainNode() {
		foreach(node ; this.main_nodes) {
			if(node.main && (node.max == NodeInfo.UNLIMITED || node.online < node.max)) return node;
		}
		return null;
	}

	public shared nothrow @property @safe shared(Node)[] mainNodes() {
		shared Node[] nodes;
		foreach(node ; this.main_nodes) {
			if(node.main && (node.max == NodeInfo.UNLIMITED || node.online < node.max)) nodes ~= node;
		}
		return nodes;
	}
	
	public shared nothrow shared(Node) nodeByName(string name) {
		auto ptr = name in this.nodesNames;
		return ptr ? *ptr : null;
	}
	
	public shared nothrow shared(Node) nodeById(uint id) {
		auto ptr = id in this.nodes;
		return ptr ? *ptr : null;
	}

	public shared @property string[] nodeNames() {
		return this.nodesNames.keys;
	}

	public shared @property shared(Node[]) nodesList() {
		return this.nodes.values;
	}

	public synchronized shared void add(shared Node node) {
		log(Text.green, "+ ", Text.white, node.toString());
		this.nodes[node.id] = node;
		this.nodesNames[node.name] = node;
		// update players
		if(node.max == NodeInfo.UNLIMITED) atomicOp!"+="(this.unlimited_nodes, 1);
		else atomicOp!"+="(this.n_max, node.max);
		// add to main, if main
		if(node.main) this.main_nodes ~= node;
		// add plugins
		foreach(plugin ; node.plugins) {
			string str = plugin.name ~ " " ~ plugin.vers;
			if(str in this.n_plugins) {
				atomicOp!"+="(this.n_plugins[str], 1);
			} else {
				this.n_plugins[str] = 1;
			}
		}
		// notify other nodes
		foreach(shared Node on ; this.nodes) {
			on.addNode(node);
		}
		// notify external consoles
		foreach(externalConsole ; externalConsoles) {
			externalConsole.updateNodes(true, node.name);
		}
	}

	public synchronized shared void remove(shared Node node) {
		log(Text.red, "- ", Text.white, node.toString());
		this.nodes.remove(node.id);
		this.nodesNames.remove(node.name);
		// update players
		if(node.max == NodeInfo.UNLIMITED) atomicOp!"-="(this.unlimited_nodes, 1);
		else atomicOp!"-="(this.n_max, node.max);
		// remove from main, if main
		if(node.main) {
			foreach(i, n; this.main_nodes) {
				if(n.id == node.id) {
					this.main_nodes = this.main_nodes[0..i] ~ this.main_nodes[i+1..$];
					break;
				}
			}
		}
		// remove plugins
		foreach(plugin ; node.plugins) {
			string str = plugin.name ~ " " ~ plugin.vers;
			auto ptr = str in this.n_plugins;
			if(ptr) {
				atomicOp!"-="(*ptr, 1);
				if(*ptr == 0) {
					this.n_plugins.remove(str);
				}
			}
		}
		// notify other nodes
		foreach(shared Node on ; this.nodes) {
			on.removeNode(node);
		}
		// notify external consoles
		foreach(externalConsole ; externalConsoles) {
			externalConsole.updateNodes(false, node.name);
		}
	}

	public shared nothrow @property @safe @nogc bool hasExternalConsoles() {
		return this.externalConsoles.length != 0;
	}

	public synchronized shared void add(shared ExternalConsoleSession externalConsole) {
		log(Text.green, "+ ", Text.white, externalConsole.toString());
		this.externalConsoles[externalConsole.id] = externalConsole;
	}

	public synchronized shared void remove(shared ExternalConsoleSession externalConsole) {
		log(Text.red, "- ", Text.white, externalConsole.toString());
		this.externalConsoles.remove(externalConsole.id);
	}

	public synchronized shared void add(shared RconSession rcon) {
		log(Text.green, "+ ", Text.white, rcon.toString());
		this.rcons[rcon.id] = rcon;
	}

	public synchronized shared void remove(shared RconSession rcon) {
		log(Text.red, "- ", Text.white, rcon.toString());
		this.rcons.remove(rcon.id);
	}

	public synchronized shared void add(shared PlayerSession player) {
		this.n_players[player.id] = player;
		if(this.analytics !is null) this.analytics.addPlayer(player);
	}

	public synchronized shared void remove(shared PlayerSession player) {
		this.n_players.remove(player.id);
		if(this.analytics !is null) this.analytics.removePlayer(player);
	}

	public shared nothrow shared(PlayerSession) playerFromId(immutable(uint) id) {
		auto ptr = id in this.n_players;
		return ptr ? *ptr : null;
	}

	public shared shared(PlayerSession) playerFromIdentifier(ubyte[] idf) {
		foreach(shared PlayerSession player ; this.players) {
			if(player.iusername == idf) return player;
		}
		return null;
	}

}

struct Traffic {

	size_t sent, received;

	pure nothrow @safe @nogc void send(size_t amount) {
		this.sent += amount;
	}

	pure nothrow @safe @nogc void receive(size_t amount) {
		this.received += amount;
	}

	shared nothrow @nogc void send(size_t amount) {
		atomicOp!"+="(this.sent, amount);
	}

	shared nothrow @nogc void receive(size_t amount) {
		atomicOp!"+="(this.received, amount);
	}

	shared nothrow @safe @nogc void reset() {
		this.sent = 0;
		this.received = 0;
	}

}

struct List {

	private shared Server server;
	
	public immutable string name;

	private shared Player[] players;

	public this(shared Server server, string name) {
		this.server = server;
		this.name = name;
	}

	public shared bool contains(ubyte type, UUID uuid) {
		foreach(player ; this.players) {
			if(cast(UniquePlayer)player) {
				auto u = cast(UniquePlayer)player;
				if(u.game == type && u.uuid == uuid) return true;
			}
		}
		return false;
	}

	public shared bool contains(string name) {
		name = name.toLower;
		foreach(player ; this.players) {
			if(cast(NamedPlayer)player && (cast(NamedPlayer)player).username == name) return true;
		}
		return false;
	}

	public shared void add(Player player) {
		this.players ~= cast(shared)player;
		this.save();
	}

	public shared void remove(Player player) {
		foreach(i, p; this.players) {
			if(cast()p == player) {
				this.players = this.players[0..i] ~ this.players[i+1..$];
				break;
			}
		}
	}

	public shared void load() {
		if(!exists(Paths.resources ~ this.name ~ ".txt")) return;
		foreach(string line ; (cast(string)read(Paths.resources ~ this.name ~ ".txt")).split("\n")) {
			line = line.strip;
			if(line.length) {
				Player player;
				if(line.indexOf("@") > 0) {
					player = new UniquePlayer();
				} else {
					player = new NamedPlayer();
				}
				player.fromString(line);
				this.players ~= cast(shared)player;
			}
		}
	}

	public shared void save() {
		string[] lines;
		foreach(player ; this.players) {
			lines ~= (cast()player).toString();
		}
		write(Paths.resources ~ this.name ~ ".txt", lines.join(newline) ~ newline);
	}

	static class Player {

		public abstract void fromString(string str);

		public abstract override string toString();

		public abstract override bool opEquals(Object o);

	}

	static class UniquePlayer : Player {

		private ubyte game;
		private UUID uuid;

		public this() {}

		public this(ubyte game, UUID uuid) {
			this.game = game;
			this.uuid = uuid;
		}

		public override void fromString(string str) {
			string[] s = str.split("@");
			this.game = to!ubyte(s[1].strip);
			this.uuid = parseUUID(s[0].strip);
		}

		public override string toString() {
			return this.uuid.toString() ~ "@" ~ to!string(this.game);
		}

		public override bool opEquals(Object o) {
			if(cast(UniquePlayer)o) {
				auto u = cast(UniquePlayer)o;
				return this.game == u.game && this.uuid == u.uuid;
			} else {
				return false;
			}
		}

	}

	static class NamedPlayer : Player {

		private string username;

		public this() {}

		public this(string username) {
			this.username = username.toLower;
		}

		public override void fromString(string str) {
			this.username = str.toLower;
		}

		public override string toString() {
			return this.username.toLower;
		}

		public override bool opEquals(Object o) {
			if(cast(NamedPlayer)o) {
				return this.username == (cast(NamedPlayer)o).username;
			} else {
				return false;
			}
		}

	}

}
