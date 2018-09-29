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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hub/server.d, selery/hub/server.d)
 */
module selery.hub.server;

import core.atomic : atomicOp;
import core.cpuid;
import core.sys.posix.signal;
import core.thread;

import std.algorithm : sort, canFind;
import std.array : Appender;
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

import libasync : EventLoop;

import myip : privateAddresses, publicAddress4;

import sel.format : Format;
import sel.server.util : Client;
//import sel.server.query : Query;
import sel.server.util : ServerInfo;
import sel.server.server : PlayerHandler = Handler;

import selery.about;
import selery.config : Config;
import selery.event.event : EventListener;
import selery.event.hub : HubServerEvent, LogEvent;
import selery.hncom.login : HubInfo, NodeInfo;
import selery.hncom.status : Log;
import selery.hub.handler : Handler;
import selery.hub.hncom : Node;
import selery.hub.player : PlayerSession;
import selery.hub.plugin.plugin : HubPluginInfo;
import selery.lang : Translation;
import selery.log : Message, Logger;
import selery.plugin : Plugin;
import selery.server : Server;
import selery.util.thread;
import selery.util.util : milliseconds;

import terminal : Terminal;

import xbuffer : Buffer;

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

class HubServer : /*EventListener!HubServerEvent, */PlayerHandler, Server {

	public immutable bool lite;

	public immutable ulong id;
	private shared ulong uuid_count;

	private immutable ulong started;

	private EventLoop _eventLoop;

	public EventListener!HubServerEvent eventListener;

	private Config _config;
	private ServerLogger _logger;
	private const(AddressRange)[] _accepted_nodes;
	private Icon _icon;
	private ServerInfo _info;
	//private shared Query _query;

	private Plugin[] _plugins;

	private uint n_max = 0; //TODO replace with _info.max

	private Handler handler;

	private Node[uint] nodes;
	private Node[] main_nodes;
	private Node[string] nodesNames;
	private size_t[string] n_plugins;
	
	private PlayerSession[uint] _players;

	public this(bool lite, Config config, Plugin[] plugins=[], string[] args=[]) {

		assert(config.files !is null);
		assert(config.lang !is null);
		assert(config.hub !is null);

		debug Thread.getThis().name = "hub_server";

		this.lite = lite;

		_eventLoop = new EventLoop();

		this.eventListener = new EventListener!HubServerEvent();

		this._info = new shared ServerInfo();
		/*if(config.hub.query) {
			this._query = new shared Query(this._info);
			this._query.software = Software.name ~ " " ~ Software.displayVersion;
		}*/

		AddressRange[] acceptedNodes;
		foreach(node ; config.hub.acceptedNodes) {
			acceptedNodes ~= AddressRange.parse(node);
		}
		this._accepted_nodes = acceptedNodes;

		Terminal terminal = new Terminal();

		terminal.title = config.hub.displayName ~ " | " ~ (!lite ? "hub | " : "") ~ Software.simpleDisplay;
		
		Message[][] errors = this.load(config);

		this._logger = new ServerLogger(this, terminal);
		
		this.logger.log(Translation("startup.starting", [Format.green ~ Software.name ~ Format.reset ~ " " ~ Format.white ~ Software.fullVersion ~ Format.reset ~ " " ~ Software.fullCodename]));
		
		static if(!__supported) {
			this.logger.logWarning(Translation("startup.unsupported", [Software.name]));
		}

		// print error message from config loading
		foreach(message ; errors) {
			this.logger.logMessage(message);
		}

		this.id = uniform!"[]"(ulong.min, ulong.max);
		this.uuid_count = uniform!"[]"(ulong.min, ulong.max);

		auto pr = privateAddresses;
		if(pr.length) this.logger.log(Translation("startup.privateAddresses", pr.join(", ")));
		immutable pu4 = publicAddress4;
		if(pu4.length) this.logger.log(Translation("startup.publicAddress", pu4));

		this.handler = new Handler(this, this._info/*, this._query*/);

		this._plugins = plugins;

		// load plugins
		foreach(_plugin ; _plugins) {
			auto plugin = cast(HubPluginInfo)_plugin;
			plugin.load(this);
			if(plugin.main) {
				auto a = [
					Format.green ~ plugin.name ~ Format.reset,
					Format.white ~ (plugin.authors.length ? plugin.authors.join(Format.reset ~ ", " ~ Format.white) : "?") ~ Format.reset,
					Format.white ~ plugin.version_[1..$]
				];
				this.logger.log(Translation("startup.plugin.enabled" ~ (plugin.version_.startsWith("v") ? ".version" : (plugin.authors.length ? ".author" : "")), a));
			}
		}

		//TODO load plugins' language files

		// call @start
		foreach(plugin ; _plugins) {
			foreach(del ; plugin.onstart) del();
		}

		this.started = milliseconds;

		if(!this.lite) this.logger.log(Translation("startup.started"));

		this.eventLoop.run();

		//TODO move this into a timer
		/*int last_online, last_max = this.maxPlayers;
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
			Thread.sleep(dur!"msecs"(1000));
		}*/

	}

	/**
	 * Loads the configuration file.
	 * - validates the motds
	 * - validates protocols
	 * - loads and validate favicon
	 * - validate accepted language(s)
	 * - load languages
	 */
	private Message[][] load(ref Config config) {
		Message[][] errors;
		// MOTDs and protocols
		this._info.motd.raw = config.hub.displayName;
		if(config.hub.bedrock) with(config.hub.bedrock) {
			motd = motd.replaceAll(ctRegex!"&([0-9a-zk-or])", "§$1");
			motd = motd.replace(";", "");
			motd ~= Format.reset;
			this._info.motd.bedrock = motd;
			validateProtocols(protocols, supportedBedrockProtocols, supportedBedrockProtocols);
		}
		if(config.hub.java) with(config.hub.java) {
			motd = motd.replaceAll(ctRegex!"&([0-9a-zk-or])", "§$1");
			motd = motd.replace("\\n", "\n");
			this._info.motd.java = motd;
			validateProtocols(protocols, supportedJavaProtocols, supportedJavaProtocols);
		}
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
					errors ~= Message.convert(Format.yellow, Translation("warning.iconFailed", config.hub.favicon, e.msg));
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
				errors ~= Message.convert(Format.yellow, Translation("warning.invalidIcon", config.hub.favicon));
				icon = Icon.init;
			}
		}
		this._icon = icon;
		this._info.favicon = this._icon.base64data;
		// save new config
		this._config = config;
		return errors;
	}

	public void shutdown() {
		this.handler.shutdown();
		foreach(node ; this.nodes) node.onClosed(false);
		import core.stdc.stdlib : exit;
		this.logger.log("Shutting down");
		exit(0);
	}

	public nothrow @property UUID nextUUID() {
		ubyte[16] data = nativeToBigEndian(this.id) ~ nativeToBigEndian(this.uuid_count);
		atomicOp!"+="(this.uuid_count, 1);
		return UUID(data);
	}

	public nothrow @property @trusted @nogc ulong nextPool() {
		ulong pool = this.uuid_count;
		atomicOp!"+="(this.uuid_count, uint.max);
		return pool;
	}

	/**
	 * Gets the server's uptime in milliseconds.
	 */
	public @property @safe const uint uptime() {
		return cast(uint)(milliseconds - this.started);
	}

	/**
	 * Gets the server's event loop.
	 */
	public @property EventLoop eventLoop() pure nothrow @safe @nogc {
		return _eventLoop;
	}

	/**
	 * Gets the server's configuration.
	 */
	public override nothrow @property @trusted @nogc const(Config) config() {
		return _config;
	}

	public override @property Logger logger() {
		return _logger;
	}

	public override pure nothrow @property @trusted @nogc const(Plugin)[] plugins() {
		return cast(const(Plugin)[])_plugins;
	}

	public final nothrow @property @safe @nogc ServerInfo info() {
		return _info;
	}

	public nothrow @property @trusted @nogc const(Icon) icon() {
		return _icon;
	}

	/**
	 * Gets the number of online players.
	 */
	public nothrow @property @safe @nogc const uint onlinePlayers() {
		version(X86_64) {
			return cast(uint)this._players.length;
		} else {
			return this._players.length;
		}
	}

	/**
	 * Gets the number of max players.
	 */
	public nothrow @property @safe @nogc const int maxPlayers() {
		return this.n_max;
	}

	public @property @safe @nogc void updateMaxPlayers() {
		int max = 0;
		foreach(node ; this.nodes) {
			if(node.max == NodeInfo.UNLIMITED) {
				_info.max = this.n_max = HubInfo.UNLIMITED;
				return;
			} else {
				max += node.max;
			}
		}
		_info.max = this.n_max = max;
	}

	/**
	 * Indicates whether the server is full.
	 */
	public @property @safe @nogc const(bool) full() {
		if(this.maxPlayers == HubInfo.UNLIMITED) return false;
		foreach(node ; this.nodes) {
			if(!node.full) return false;
		}
		return true;
	}

	/**
	 * Gets the online players.
	 */
	public @property PlayerSession[] players() {
		return this._players.values;
	}

	/**
	 * Handles a command.
	 */
	public void handleCommand(string command, ubyte origin, Address sender, int commandId) {
		Node recv;
		if(this.lite) {
			recv = this.nodes.values[0];
		} else {
			string name = "";
			immutable space = command.indexOf(" ");
			if(space != -1) {
				name = command[0..space];
				command = command[space..$].strip;
				if(command.length == 0) return;
			}
			recv = this.nodeByName(name);
			if(recv is null) return; //TODO print error message
		}
		recv.remoteCommand(command, origin, sender, commandId);
	}

	/**
	 * Handles a log.
	 */
	public void handleLog(string node, Log.Message[] messages, ulong timestamp, int commandId, int worldId, string worldName) {
		Message[] log;
		if(node.length) log ~= Message("[node/" ~ node ~ "]");
		if(worldName.length) log ~= Message("[world/" ~ worldName ~ "]");
		if(log.length) log ~= Message(" ");
		// convert from Log.Message[] to Message[]
		foreach(message ; messages) {
			if(message.translation) log ~= Message(Translation(message.message, message.params));
			else log ~= Message(message.message);
		}
		(cast()this._logger).logWith(log, commandId, worldId);
	}

	public bool acceptNode(Address address) {
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

	public nothrow @property @safe @nogc bool hasNodes() {
		return this.nodes.length != 0;
	}

	/**
	 * Returns: the first main node which is not full
	 */
	public nothrow @property @safe @nogc Node mainNode() {
		foreach(node ; this.main_nodes) {
			if(node.main && (node.max == NodeInfo.UNLIMITED || node.online < node.max)) return node;
		}
		return null;
	}

	public nothrow @property @safe Node[] mainNodes() {
		Node[] nodes;
		foreach(node ; this.main_nodes) {
			if(node.main && (node.max == NodeInfo.UNLIMITED || node.online < node.max)) nodes ~= node;
		}
		return nodes;
	}

	public nothrow Node nodeByName(string name) {
		auto ptr = name in this.nodesNames;
		return ptr ? *ptr : null;
	}
	
	public nothrow Node nodeById(uint id) {
		auto ptr = id in this.nodes;
		return ptr ? *ptr : null;
	}

	public @property string[] nodeNames() {
		return this.nodesNames.keys;
	}

	public @property Node[] nodesList() {
		return this.nodes.values;
	}

	public void add(Node node) {
		if(!this.lite) this.logger.log(Format.green, "+ ", Format.reset, node.toString());
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
				this.n_plugins[str]++;
			} else {
				this.n_plugins[str] = 1;
				//TODO add to _query.plugins
			}
		}
		// notify other nodes
		foreach(on ; this.nodes) {
			on.addNode(node);
		}
	}

	public void remove(Node node) {
		if(node.id in this.nodes) {
			this.logger.log(Format.red, "- ", Format.reset, node.toString());
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
					*ptr += 1;
					if(*ptr == 0) {
						this.n_plugins.remove(str);
						//TODO remove from _query.plugins
					}
				}
			}
			// notify other nodes
			foreach(on ; this.nodes) {
				on.removeNode(node);
			}
		}
	}

	public override void onJoin(Client client) {
		auto player = new PlayerSession(this, client);
		if(player.firstConnect()) this._players[player.id] = player;
	}

	public override void onLeft(Client client) {
		auto player = client.id in this._players;
		if(player) {
			this._players.remove(client.id);
			(*player).onClosed(); // remove from the node
		}
	}

	public override void onPacket(Client client, Buffer buffer) {
		auto player = client.id in this._players;
		if(player) {
			(*player).sendToNode(buffer.data!ubyte);
		}
	}

	public override void onLatencyUpdate(Client client) {
		//TODO
	}

	public override void onPacketLossUpdate(Client client) {
		//TODO
	}

	public nothrow PlayerSession playerFromId(immutable(uint) id) {
		auto ptr = id in this._players;
		return ptr ? *ptr : null;
	}

	public PlayerSession playerFromIdentifier(ubyte[] idf) {
		foreach(PlayerSession player ; this.players) {
			if(player.iusername == idf) return player;
		}
		return null;
	}

}

private class ServerLogger : Logger {

	private HubServer server;
	
	public this(HubServer server, Terminal terminal) {
		super(terminal, server.lang);
		this.server = server;
	}
	
	protected override void logImpl(Message[] messages) {
		this.logWith(messages, Log.NO_COMMAND, Log.NO_WORLD);
	}

	public void logWith(Message[] messages, int commandId, int worldId) {
		this.server.eventListener.callEventIfExists!LogEvent(this.server, messages, commandId, worldId);
		super.logImpl(messages);
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
