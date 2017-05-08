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
module sel.network.handler;

import core.thread : Thread;

import std.conv : to;
import std.json : JSONValue;
import std.socket;
import std.string;

import sel.about : Software;
import sel.config : ConfigType;
import sel.constants;
import sel.lang : translate;
import sel.format : Text;
import sel.hub.settings;
import sel.hub.server : Server;
import sel.session.externalconsole : ExternalConsoleHandler;
import sel.session.hncom : HncomHandler, MessagePassingNode;
import sel.session.http : HttpHandler;
import sel.session.minecraft : MinecraftHandler, MinecraftQueryHandler;
import sel.session.panel : PanelHandler;
import sel.session.pocket : PocketHandler;
import sel.session.rcon : RconHandler;
import sel.network.session;
import sel.network.socket;
import sel.util.logh : log;
import sel.util.query : Queries;
import sel.util.thread : SafeThread;

/**
 * Main handler with the purpose of starting children handlers,
 * store constant informations and reload them when needed.
 */
class Handler {

	private shared Server server;

	private shared Queries queries;

	private shared string additionalJson;
	private shared string socialJson;

	private shared HandlerThread[] handlers;

	public shared this(shared Server server) {

		this.server = server;
		
		this.regenerateSocialJson();

		this.queries = this.startThread!Queries(server, &this.socialJson);

		bool delegate(string ip) acceptIp;
		immutable forcedIp = server.settings.serverIp.toLower;
		if(forcedIp.length) {
			acceptIp = (string ip){ return ip.toLower == forcedIp; };
		} else {
			acceptIp = (string ip){ return true; };
		}

		// start handlers

		with(server.settings) {

			if(config.type == ConfigType.hub) {
				this.startThread!HncomHandler(server, &this.additionalJson, &this.socialJson);
			} else {
				new SafeThread({ new shared MessagePassingNode(server, &this.additionalJson, &this.socialJson); }).start();
			}

			if(pocket) {
				this.startThread!PocketHandler(server, &this.socialJson, this.queries.querySessions, this.queries.pocketShortQuery, this.queries.pocketLongQuery);
			}

			if(minecraft) {
				this.startThread!MinecraftHandler(server, &this.socialJson, acceptIp, this.queries.minecraftLegacyStatus, this.queries.minecraftLegacyStatusOld);
				if(query) {
					this.startThread!MinecraftQueryHandler(server, this.queries.querySessions, this.queries.minecraftShortQuery, this.queries.minecraftLongQuery);
				}
			}

			if(externalConsole) {
				this.startThread!ExternalConsoleHandler(server);
			}

			if(rcon) {
				this.startThread!RconHandler(server);
			}

			if(web) {
				this.startThread!HttpHandler(server, &this.socialJson, this.queries.pocketPort, this.queries.minecraftPort);
			}

			if(panel) {
				this.startThread!PanelHandler(server);
			}

		}

		log();

	}

	/**
	 * Starts a new thread and gives it the name of its class.
	 */
	private shared shared(T) startThread(T : Thread, E...)(E args) {
		T thread = new T(args);
		thread.name = toLower(T.stringof[0..1]) ~ T.stringof[1..$];
		static if(is(T : HandlerThread)) {
			this.handlers ~= cast(shared)thread;
		}
		thread.start();
		return cast(shared)thread;
	}

	/**
	 * Reloads the resources that can be reloaded.
	 * Those resources are the social json (always reloaded) and
	 * the web's pages (index, icon and info) when the http handler
	 * is running (when the server has been started with "web-enabled"
	 * equals to true.
	 */
	public shared void reload() {
		this.regenerateSocialJson();
		foreach(handler ; this.handlers) {
			handler.reload();
		}
	}

	/**
	 * Regenerates the social json adding a string field
	 * for each social field that is not empty in the settings.
	 */
	private shared void regenerateSocialJson() {
		auto settings = cast()this.server.settings;
		this.socialJson = settings.social.toString();
		JSONValue[string] additional;
		additional["social"] = this.server.settings.social;
		additional["minecraft"] = ["edu": settings.edu, "realm": settings.realm];
		additional["software"] = ["name": Software.name, "version": Software.displayVersion];
		this.additionalJson = cast(shared)JSONValue(additional).toString();
	}

	/**
	 * Closes the handlers and frees the resources.
	 */
	public shared void shutdown() {
		foreach(shared HandlerThread handler ; this.handlers) {
			handler.shutdown();
		}
	}

}

abstract class HandlerThread : SafeThread {

	public static shared(Socket)[] createSockets(T)(string handler, inout string[] addresses, inout ushort port, int backlog) {
		shared(Socket)[] sockets;
		foreach(string address ; addresses) {
			try {
				sockets ~= cast(shared)socketFromAddress!(BlockingSocket!T)(address, port, backlog);
				log(translate("{handler.listening}", Settings.defaultLanguage, [Text.green ~ handler ~ Text.reset, address]));
			} catch(SocketException e) {
				log(translate("{handler.error.bind}", Settings.defaultLanguage, [Text.red ~ handler ~ Text.reset, address, Text.yellow ~ (e.msg.indexOf(":")!=-1 ? e.msg.split(":")[$-1].strip : e.msg)]));
			} catch(Throwable t) {
				log(translate("{handler.error.address}", Settings.defaultLanguage, [Text.red ~ handler ~ Text.reset, address]));
			}
		}
		return sockets;
	}

	public static shared(Socket)[] createSockets(T)(string handler, shared inout string[] addresses, shared inout ushort port, int backlog) {
		return createSockets!T(handler, cast(string[])addresses, cast()port, backlog);
	}

	protected shared Server server;

	protected shared(Socket)[] sharedSockets;

	public this(shared Server server, shared(Socket)[] sockets) {
		super(&this.run);
		this.server = server;
		this.sharedSockets = sockets;
	}

	protected void run() {
		void start(shared Socket socket) {
			auto thread = new SafeThread({ this.listen(socket); });
			thread.name = Thread.getThis().name ~ "@" ~ (cast()socket).localAddress.to!string;
			thread.start();
		}
		foreach(shared Socket socket ; this.sharedSockets) {
			start(socket);
		}
	}

	protected abstract void listen(shared Socket socket);

	protected final void send(size_t amount) {
		this.server.traffic.send(amount);
	}

	protected final void receive(size_t amount) {
		this.server.traffic.receive(amount);
	}

	public shared void reload() {}

	public shared void shutdown() {}

}

abstract class UnconnectedHandler : HandlerThread {

	protected immutable size_t buffer_size;

	public this(shared Server server, shared(Socket)[] sockets, size_t buffer_size) {
		super(server, sockets);
		this.buffer_size = buffer_size;
	}

	protected override void listen(shared Socket sharedSocket) {
		Socket socket = cast()sharedSocket;
		Address address;
		ubyte[] buffer = new ubyte[this.buffer_size];
		while(true) {
			auto recv = socket.receiveFrom(buffer, address);
			if(recv > 0) {
				this.receive(recv);
				this.onReceived(socket, address, buffer[0..recv]);
			}
		}
	}

	protected abstract void onReceived(Socket socket, Address address, ubyte[] payload);

	public ptrdiff_t sendTo(Socket socket, const(void)[] data, Address address) {
		auto sent = socket.sendTo(data, address);
		if(sent > 0) this.send(sent);
		return sent;
	}
	
	public shared ptrdiff_t sendTo(Socket socket, const(void)[] data, shared Address address) {
		return (cast()this).sendTo(socket, data, cast()address);
	}

}
