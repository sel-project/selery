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

import selery.config : Config;
import selery.crash : logCrash;
import selery.node.plugin : NodePlugin, PluginOf;
import selery.node.server : NodeServer;
import selery.util.util : UnloggedException;

import pluginloader;
import starter;

void main(string[] args) {

	start(ConfigType.node, "node", args, (Config config){

		T find(T)(T def, string opt0, string opt1=null) {
			foreach(i, arg; args) {
				if(arg.startsWith(opt0 ~ "=")) {
					auto ret = to!T(arg[opt0.length+1..$]);
					args = args[0..i] ~ args[i+1..$];
					return ret;
				} else if(opt1 !is null && arg == opt1 && i < args.length - 1) {
					auto ret = to!T(args[i+1]);
					args = args[0..i] ~ args[i+2..$];
					return ret;
				}
			}
			return def;
		}

		auto name = find!string("node", "--name", "-n");
		auto password = find!string("", "--password", "-p");
		auto ip = find!string("localhost", "--ip");
		auto port = find!ushort(ushort(28232), "--port");
		auto main = find!bool(true, "--main");

		Address address = getAddress(ip, port)[0];

		try {
			
			new shared NodeServer(address, name, password, main, config, loadPlugins!(PluginOf, NodePlugin)(), args);
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("node", config.lang, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(1);
			
		}
		
	});
	
}

