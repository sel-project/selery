/*
 * Copyright (c) 2017-2018 SEL
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
module selery.hub.server;

import core.atomic : atomicOp;
import core.cpuid;
import core.sys.posix.signal;
import core.thread;

import std.algorithm : sort, canFind;
import std.ascii : newline;
import std.base64 : Base64;
import std.bitmanip : nativeToBigEndian;
import std.conv : to;
import std.file;
import std.json;
import std.math : round;
import std.net.curl : download, CurlException;
import std.random : uniform;
import std.regex : replaceAll, ctRegex;
import std.socket : Address, InternetAddress, Internet6Address, AddressFamily;
import std.string : join, split, toLower, strip, indexOf, replace, startsWith;
import std.system : endian;
import std.typecons;
import std.uuid : parseUUID, UUID;
import std.utf : UTFException;

import imageformats : ImageIOException, read_png_header_from_mem;

import sel.hncom.login : HubInfo, NodeInfo;
import sel.hncom.status : RemoteCommand;
import sel.server.client : Client;
import sel.server.query : Query;
import sel.server.util : ServerInfo, PlayerHandler = Handler;

import selery.about;
import selery.config : Config;
import selery.format : Text;
import selery.hub.handler.handler : Handler;
import selery.hub.handler.hncom : AbstractNode;
import selery.hub.handler.rcon : RconClient;
import selery.hub.handler.webadmin : WebAdminClient;
import selery.hub.player : PlayerSession;
import selery.lang : Translation;
import selery.log : log, warning_log, raw_log;
import selery.plugin : Plugin;
import selery.server : Server;
import selery.util.block : Blocks;
import selery.util.ip : localAddresses, publicAddresses;
import selery.util.portable : startWebAdmin;
import selery.util.thread;
import selery.util.util : milliseconds;

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

struct Icon {

	string url;

	ubyte[] data;
	string base64data;

	static Icon fromData(void[] _data) {
		ubyte[] data = cast(ubyte[])_data;
		return Icon("", data, "data:image/png;base64," ~ Base64.encode(data).idup);
	}

	static Icon fromURL(string url, void[] data) {
		auto ret = fromData(data);
		ret.url = url;
		return ret;
	}

}

class HubServer : PlayerHandler, Server {

	public immutable bool lite;

	public immutable ulong id;
	private shared ulong uuid_count;

	private immutable ulong started;

	private shared Config _config;
	private shared const(AddressRange)[] _accepted_nodes;
	private shared Icon _icon;
	private shared ServerInfo _info;
	private shared Query _query;

	private shared Plugin[] _plugins;

	private shared uint n_max = 0; //TODO replace with _info.max

	private shared uint n_upload, n_download;

	private shared List n_whitelist;
	private shared List n_blacklist;

	private shared Handler handler;
	private shared Blocks blocks;

	private shared AbstractNode[uint] nodes;
	private shared AbstractNode[] main_nodes;
	private shared AbstractNode[string] nodesNames;
	private shared size_t[string] n_plugins;

	private shared WebAdminClient[uint] webAdmins;
	private shared RconClient[uint] rcons;
	
	private shared PlayerSession[uint] _players;

	public shared this(bool lite, Config config, Plugin[] plugins=[], string[] args=[]) {

		assert(config.files !is null);
		assert(config.lang !is null);
		assert(config.hub !is null);

		debug Thread.getThis().name = "hub_server";

		this.lite = lite;

		this._info = new shared ServerInfo();
		if(config.hub.query) {
			this._query = new shared Query(this._info);
			this._query.software = Software.name ~ " " ~ Software.displayVersion;
		}

		this.n_whitelist = List(this, "whitelist");
		this.n_blacklist = List(this, "blacklist");

		AddressRange[] acceptedNodes;
		foreach(node ; config.hub.acceptedNodes) {
			acceptedNodes ~= AddressRange.parse(node);
		}
		this._accepted_nodes = cast(shared const)acceptedNodes;
		
		version(Windows) {
			import std.process : executeShell;
			executeShell("title " ~ config.hub.displayName ~ " ^| " ~ (!lite ? "hub ^| " : "") ~ Software.simpleDisplay);
		}
		
		this.load(config);
		
		log(config.lang.translate("startup.starting", [Text.green ~ Software.name ~ Text.reset ~ " " ~ Text.white ~ Software.fullVersion ~ Text.reset ~ " " ~ Software.fullCodename]));
		
		static if(!__supported) {
			warning_log(config.lang.translate("startup.unsupported", [Software.name]));
		}

		foreach(plugin ; plugins) {
			//TODO does this save?
			if(plugin.languages !is null) config.lang.add(plugin.languages); // absolute path
			//TODO add to query
		}
		//TODO save to _plugins

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
		
		auto pa = publicAddresses(config.files);
		if(pa.v4.length || pa.v6.length) {
			if(pa.v4.length) log("Public ip: ", pa.v4);
			if(pa.v6.length) log("Public ipv6: ", pa.v6);
			log();
		}
		
		this.blocks = new Blocks();

		this.handler = new shared Handler(this, this._info, this._query);

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

		/*version(Windows) {
			SetConsoleCtrlHandler(&sigHandler, true);
		} else version(linux) {
			sigset(SIGTERM, &extsig);
			sigset(SIGINT, &extsig);
		}*/

		/*if(config.googleAnalytics.length) {
			this.analytics = new shared GoogleAnalytics(this, config.googleAnalytics);
		}*/

		//TODO load plugins

		// open web admin GUI
		if(config.hub.webAdminOpen) {
			import std.process : Pid;
			Pid pid = null;
			foreach(address ; config.hub.webAdminAddresses) {
				if(address.ip == "127.0.0.1" || address.ip == "::1") {
					pid = startWebAdmin(address.port);
					break;
				}
			}
			if(pid is null && config.hub.webAdminAddresses.length) {
				pid = startWebAdmin(config.hub.webAdminAddresses[0].port);
			}
		}

		this.started = milliseconds;

		if(!this.lite) log(config.lang.translate("startup.started"));

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
			Thread.sleep(dur!"msecs"(5000));
			this.blocks.remove(5);
		}

	}

	/**
	 * Loads the configuration file.
	 * - validates the motds
	 * - validates protocols
	 * - loads and validate favicon
	 * - validate accepted language(s)
	 * - load languages
	 */
	private shared void load(ref Config config) {
		// MOTDs and protocols
		this._info.motd.raw = config.hub.displayName;
		if(config.hub.bedrock) with(config.hub.bedrock) {
			motd = motd.replaceAll(ctRegex!"&([0-9a-zk-or])", "§$1");
			motd = motd.replace(";", "");
			motd ~= Text.reset;
			this._info.motd.bedrock = motd;
			validateProtocols(protocols, supportedBedrockProtocols, supportedBedrockProtocols);
		}
		if(config.hub.java) with(config.hub.java) {
			motd = motd.replaceAll(ctRegex!"&([0-9a-zk-or])", "§$1");
			motd = motd.replace("\\n", "\n");
			this._info.motd.java = motd;
			validateProtocols(protocols, supportedJavaProtocols, supportedJavaProtocols);
		}
		// languages
		string[] accepted;
		foreach(lang ; config.hub.acceptedLanguages) {
			if(Config.LANGUAGES.canFind(lang)) accepted ~= lang;
		}
		if(!Config.LANGUAGES.canFind(config.hub.language)) config.hub.language = "en_GB";
		if(!accepted.canFind(config.hub.language)) accepted ~= config.hub.language;
		config.hub.acceptedLanguages = accepted;
		config.lang.load(config.hub.language, config.hub.acceptedLanguages);
		// icon
		Icon icon;
		if(exists(config.hub.favicon) && isFile(config.hub.favicon)) {
			icon = Icon.fromData(read(config.hub.favicon));
		} else if(config.hub.favicon.startsWith("http://") || config.hub.favicon.startsWith("https://")) {
			immutable cached = "icon_" ~ Base64.encode(cast(ubyte[])config.hub.favicon).idup;
			if(!config.files.hasTemp(cached)) {
				try {
					static import std.net.curl;
					std.net.curl.download(config.hub.favicon, config.files.temp ~ cached);
				} catch(CurlException e) {
					warning_log(config.lang.translate("warning.iconFailed", [config.hub.favicon, e.msg]));
				}
			}
			if(config.files.hasTemp(cached)) {
				icon = Icon.fromURL(config.hub.favicon, config.files.readTemp(cached));
			}
		}
		if(icon.data.length) {
			bool valid = false;
			try {
				auto header = read_png_header_from_mem(icon.data);
				if(header.width == 64 && header.height == 64) valid = true;
			} catch(ImageIOException) {}
			if(!valid) {
				warning_log(config.lang.translate("warning.invalidIcon", [config.hub.favicon]));
				icon = Icon.init;
			}
		}
		this._icon = cast(shared)icon;
		this._info.favicon = this._icon.base64data;
		// save new config
		this._config = cast(shared)config;
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
	 * Gets the server's configuration.
	 */
	public override shared nothrow @property @trusted @nogc const(Config) config() {
		return cast()this._config;
	}

	public override shared pure nothrow @property @trusted @nogc const(Plugin)[] plugins() {
		return cast(const(Plugin)[])this._plugins;
	}

	public final shared nothrow @property @safe @nogc shared(ServerInfo) info() {
		return this._info;
	}

	public shared nothrow @property @trusted @nogc const(Icon) icon() {
		return cast()this._icon;
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
			return cast(uint)this._players.length;
		} else {
			return this._players.length;
		}
	}

	/**
	 * Gets the number of max players.
	 */
	public shared nothrow @property @safe @nogc const int maxPlayers() {
		return this.n_max;
	}

	public shared @property @safe @nogc void updateMaxPlayers() {
		int max = 0;
		foreach(node ; this.nodes) {
			if(node.max == NodeInfo.UNLIMITED) {
				this.n_max = HubInfo.UNLIMITED;
				return;
			} else {
				max += node.max;
			}
		}
		this.n_max = max;
	}

	/**
	 * Indicates whether the server is full.
	 */
	public shared @property @safe @nogc const(bool) full() {
		if(this.maxPlayers == HubInfo.UNLIMITED) return false;
		foreach(node ; this.nodes) {
			if(!node.full) return false;
		}
		return true;
	}

	/**
	 * Gets the online players.
	 */
	public shared @property shared(PlayerSession[]) players() {
		return this._players.values;
	}

	/**
	 * Gets the plugin used by the connected nodes.
	 */
	/*public shared @property string[] plugins() {
		return this.n_plugins.keys;
	}*/

	public shared void handleCommand(string str, ubyte origin=RemoteCommand.HUB, Address source=null, int commandId=-1) {
		// console, external console, rcon
		string[] spl = str.split(" ");
		if(spl.length) {
			string cmd = spl[0].toLower.idup;
			if(!cmd.length) return;
			string[] args = spl[1..$];
			switch(cmd) {
				case "threads":
					string[] names;
					foreach(thread ; Thread.getAll()) {
						names ~= thread.name;
					}
					sort(names);
					this.command("Threads (" ~ to!string(names.length) ~ "): " ~ names.join(", "), commandId);
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
						//TODO usage for every connected node
					}
					break;
				default:
					shared AbstractNode node;
					if(this.nodes.length == 1) {
						node = this.nodes.values[0];
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
			raw_log("[", node, "][", logger, "] ", message);
		} else {
			raw_log("[", logger, "] ", message);
		}
		if(id != -1) {
			foreach(webAdmin ; this.webAdmins) {
				(cast()webAdmin).sendLog(message, commandId);
			}
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
			log(this.config.lang.translate("warning.blocked", [to!string(address), to!string(seconds)]));
			return true;
		} else {
			return false;
		}
	}

	public shared bool acceptNode(Address address) {
		if(this.config.hub.maxNodes != 0) {
			if(this.nodes.length >= this.config.hub.maxNodes) return false;
		}
		// check if it's an IPv4-mapped in IPv6
		if(cast(Internet6Address)address) {
			auto v6 = cast(Internet6Address)address;
			ubyte[16] bytes = v6.addr;
			if(bytes[10] == 255 && bytes[11] == 255) { // ::ffff:127.0.0.1
				address = new InternetAddress(to!string(bytes[12]) ~ "." ~ to!string(bytes[13]) ~ "." ~ to!string(bytes[14]) ~ "." ~ to!string(bytes[15]), v6.port);
			}
		}
		foreach(ar ; this._accepted_nodes) {
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
	public shared nothrow @property @safe @nogc shared(AbstractNode) mainNode() {
		foreach(node ; this.main_nodes) {
			if(node.main && (node.max == NodeInfo.UNLIMITED || node.online < node.max)) return node;
		}
		return null;
	}

	public shared nothrow @property @safe shared(AbstractNode)[] mainNodes() {
		shared AbstractNode[] nodes;
		foreach(node ; this.main_nodes) {
			if(node.main && (node.max == NodeInfo.UNLIMITED || node.online < node.max)) nodes ~= node;
		}
		return nodes;
	}

	public shared nothrow shared(AbstractNode) nodeByName(string name) {
		auto ptr = name in this.nodesNames;
		return ptr ? *ptr : null;
	}
	
	public shared nothrow shared(AbstractNode) nodeById(uint id) {
		auto ptr = id in this.nodes;
		return ptr ? *ptr : null;
	}

	public shared @property string[] nodeNames() {
		return this.nodesNames.keys;
	}

	public shared @property shared(AbstractNode[]) nodesList() {
		return this.nodes.values;
	}

	public synchronized shared void add(shared AbstractNode node) {
		if(!this.lite) log(Text.green, "+ ", Text.reset, node.toString());
		this.nodes[node.id] = node;
		this.nodesNames[node.name] = node;
		// update players
		this.updateMaxPlayers();
		// add to main, if main
		if(node.main) this.main_nodes ~= node;
		// add plugins
		foreach(plugin ; node.plugins) {
			string str = plugin.name ~ " " ~ plugin.version_;
			if(str in this.n_plugins) {
				atomicOp!"+="(this.n_plugins[str], 1);
			} else {
				this.n_plugins[str] = 1;
				//TODO add to _query.plugins
			}
		}
		// notify other nodes
		foreach(shared AbstractNode on ; this.nodes) {
			on.addNode(node);
		}
	}

	public synchronized shared void remove(shared AbstractNode node) {
		log(Text.red, "- ", Text.reset, node.toString());
		this.nodes.remove(node.id);
		this.nodesNames.remove(node.name);
		// update players
		this.updateMaxPlayers();
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
			string str = plugin.name ~ " " ~ plugin.version_;
			auto ptr = str in this.n_plugins;
			if(ptr) {
				atomicOp!"-="(*ptr, 1);
				if(*ptr == 0) {
					this.n_plugins.remove(str);
					//TODO remove from _query.plugins
				}
			}
		}
		// notify other nodes
		foreach(shared AbstractNode on ; this.nodes) {
			on.removeNode(node);
		}
	}

	public override shared void onClientJoin(shared Client client) {
		auto player = new shared PlayerSession(this, client);
		if(player.firstConnect()) this._players[player.id] = player;
	}

	public override shared void onClientLeft(shared Client client) {
		auto player = client.id in this._players;
		if(player) {
			this._players.remove(client.id);
			//TODO notify the connected node
		}
	}

	public override shared void onClientPacket(shared Client client, ubyte[] packet) {
		auto player = client.id in this._players;
		if(player) {
			(*player).sendToNode(packet);
		}
	}

	public shared void onBedrockClientRequestChunkRadius(shared Client client, uint viewDistance) {
		//TODO select player and update if changed (the node will send the confirmation back)
	}

	public shared void onJavaClientClientSettings(shared Client client, string language, ubyte viewDistance, uint chatMode, bool chatColors, ubyte skinParts, uint mainHand) {
		//TODO select player and update if changed
	}

	public synchronized shared void add(WebAdminClient webAdmin) {
		log(Text.green, "+ ", Text.reset, webAdmin.toString());
		this.webAdmins[webAdmin.id] = cast(shared)webAdmin;
	}

	public synchronized shared void remove(WebAdminClient webAdmin) {
		if(this.webAdmins.remove(webAdmin.id)) {
			log(Text.red, "- ", Text.reset, webAdmin.toString());
		}
	}

	public synchronized shared void add(shared RconClient rcon) {
		log(Text.green, "+ ", Text.reset, rcon.toString());
		this.rcons[rcon.id] = rcon;
	}

	public synchronized shared void remove(shared RconClient rcon) {
		if(this.rcons.remove(rcon.id)) {
			log(Text.red, "- ", Text.reset, rcon.toString());
		}
	}

	public shared nothrow shared(PlayerSession) playerFromId(immutable(uint) id) {
		auto ptr = id in this._players;
		return ptr ? *ptr : null;
	}

	public shared shared(PlayerSession) playerFromIdentifier(ubyte[] idf) {
		foreach(shared PlayerSession player ; this.players) {
			if(player.iusername == idf) return player;
		}
		return null;
	}

	protected override void sendMessageImpl(string message) {
		log(message);
	}
	
	protected override void sendTranslationImpl(const Translation message, string[] args, Text[] formats) {
		log(join(cast(string[])formats, ""), (cast(shared)this).config.lang.translate(message, args));
	}

}

struct List {

	private shared HubServer server;
	
	public immutable string name;

	private shared Player[] players;

	public this(shared HubServer server, string name) {
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
		if(!exists(this.name ~ ".txt")) return;
		foreach(string line ; (cast(string)read(this.name ~ ".txt")).split("\n")) {
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
		write(this.name ~ ".txt", lines.join(newline) ~ newline);
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

/**
 * Stores a range of ip addresses.
 */
struct AddressRange {
	
	/**
	 * Parses an ip string into an AddressRange.
	 * Throws:
	 * 		ConvException if one of the numbers is not an unsigned byte
	 */
	public static AddressRange parse(string address) {
		AddressRange ret;
		string[] spl = address.split(".");
		if(spl.length == 4) {
			// ipv4
			ret.addressFamily = AddressFamily.INET;
			foreach(string s ; spl) {
				if(s == "*") {
					ret.ranges ~= Range(ubyte.min, ubyte.max);
				} else if(s.indexOf("-") > 0) {
					auto range = Range(to!ubyte(s[0..s.indexOf("-")]), to!ubyte(s[s.indexOf("-")+1..$]));
					if(range.min > range.max) {
						auto sw = range.max;
						range.max = range.min;
						range.min = sw;
					}
					ret.ranges ~= range;
				} else {
					ubyte value = to!ubyte(s);
					ret.ranges ~= Range(value, value);
				}
			}
			return ret;
		} else {
			// try ipv6
			ret.addressFamily = AddressFamily.INET6;
			spl = address.split("::");
			if(spl.length) {
				string[] a = spl[0].split(":");
				string[] b = (spl.length > 1 ? spl[1] : "").split(":");
				if(a.length + b.length <= 8) {
					while(a.length + b.length != 8) {
						a ~= "0";
					}
					foreach(s ; a ~ b) {
						if(s == "*") {
							ret.ranges ~= Range(ushort.min, ushort.max);
						} else if(s.indexOf("-") > 0) {
							auto range = Range(s[0..s.indexOf("-")].to!ushort(16), s[s.indexOf("-")+1..$].to!ushort(16));
							if(range.min > range.max) {
								auto sw = range.max;
								range.max = range.min;
								range.min = sw;
							}
						} else {
							ushort num = s.to!ushort(16);
							ret.ranges ~= Range(num, num);
						}
					}
				}
			}
		}
		return ret;
	}
	
	public AddressFamily addressFamily;
	
	private Range[] ranges;
	
	/**
	 * Checks if the given address is in this range.
	 * Params:
	 * 		address = an address of ip version 4 or 6
	 * Returns: true if it's in the range, false otherwise
	 * Example:
	 * ---
	 * auto range = AddressRange.parse("192.168.0-64.*");
	 * assert(range.contains(new InternetAddress("192.168.0.1"), 0));
	 * assert(range.contains(new InternetAddress("192.168.64.255"), 0));
	 * assert(range.contains(new InternetAddress("192.168.255.255"), 0));
	 * ---
	 */
	public bool contains(Address address) {
		size_t[] bytes;
		if(cast(InternetAddress)address) {
			if(this.addressFamily != addressFamily.INET) return false;
			InternetAddress v4 = cast(InternetAddress)address;
			bytes = [(v4.addr >> 24) & 255, (v4.addr >> 16) & 255, (v4.addr >> 8) & 255, v4.addr & 255];
		} else if(cast(Internet6Address)address) {
			if(this.addressFamily != AddressFamily.INET6) return false;
			ubyte last;
			foreach(i, ubyte b; (cast(Internet6Address)address).addr) {
				if(i % 2 == 0) {
					last = b;
				} else {
					bytes ~= last << 8 | b;
				}
			}
		}
		if(bytes.length == this.ranges.length) {
			foreach(size_t i, Range range; this.ranges) {
				if(bytes[i] < range.min || bytes[i] > range.max) return false;
			}
			return true;
		} else {
			return false;
		}
	}
	
	/**
	 * Converts this range into a string.
	 * Returns: the address range formatted into a string
	 * Example:
	 * ---
	 * assert(AddressRange.parse("*.0-255.79-1.4-4").toString() == "*.*.1-79.4");
	 * ---
	 */
	public string toString() {
		string pre, suf;
		string[] ret;
		size_t max = this.addressFamily == AddressFamily.INET ? ubyte.max : ushort.max;
		bool hex = this.addressFamily == AddressFamily.INET6;
		Range[] ranges = this.ranges;
		if(hex) {
			if(ranges[0].is0) {
				pre = "::";
				while(ranges.length && ranges[0].is0) {
					ranges = ranges[1..$];
				}
			} else if(ranges[$-1].is0) {
				suf = "::";
				while(ranges.length && ranges[$-1].is0) {
					ranges = ranges[0..$-1];
				}
			} else {
				//TODO zeroes in the centre
			}
		}
		foreach(Range range ; ranges) {
			ret ~= range.toString(max, hex);
		}
		return pre ~ ret.join(hex ? ":" : ".") ~ suf;
	}
	
	private static struct Range {
		
		size_t min, max;
		
		public pure nothrow @property @safe @nogc bool is0() {
			return this.min == 0 && this.max == 0;
		}
		
		public string toString(size_t max, bool hex) {
			string conv(size_t num) {
				if(hex) return to!string(num, 16).toLower;
				else return to!string(num);
			}
			if(this.min == 0 && this.max >= max) {
				return "*";
			} else if(this.min != this.max) {
				return conv(this.min) ~ "-" ~ conv(this.max);
			} else {
				return conv(this.min);
			}
		}
		
	}
	
}
