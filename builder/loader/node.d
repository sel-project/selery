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
module loader.node;

import std.concurrency : LinkTerminated;
import std.conv : to;
import std.socket;
import std.string : startsWith;

import selery.config : ConfigType;
import selery.crash : logCrash;
import selery.node.plugin : NodePlugin, PluginOf;
import selery.node.server : NodeServer;
import selery.start : startup;
import selery.util.util : UnloggedException;

import pluginloader;

void load(string[] args) {

	if(startup(ConfigType.node, "node", args)) {

		T find(T)(T def, string[] dec...) {
			foreach(i, arg; args) {
				foreach(d ; dec) {
					if(arg.startsWith(d ~ "=")) {
						auto ret = to!T(arg[d.length+1..$]);
						args = args[0..i] ~ args[i+1..$];
						return ret;
					}
				}
			}
			return def;
		}

		auto name = find!string("node", "--name", "-n");
		auto password = find!string("", "--password", "-p");
		auto ip = find!string("localhost", "--ip", "--address");
		auto port = find!ushort(cast(ushort)28232, "--port");
		auto main = find!bool(true, "--main", "-m");

		Address address;

		try {
			address = getAddress(ip, port)[0];
		} catch(SocketException e) {
			version(Posix) {
				// assume it's a unix address
				address = new UnixAddress(ip);
			} else {
				throw e;
			}
		}
		
		shared NodeServer server;

		try {
			
			server = new shared NodeServer(address, name, password, main, loadPlugins!(PluginOf, NodePlugin)(), args);
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("node", server is null ? "en_GB" : server.settings.language, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(1);
			
		}
	}
	
}

