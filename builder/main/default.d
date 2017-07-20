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
module loader.default_;

import core.thread : Thread, dur;

import std.concurrency : LinkTerminated;
import std.conv : to;
import std.file : write, exists, mkdirRecurse;
import std.path : dirSeparator;
import std.string : indexOf, lastIndexOf;

import selery.config : ConfigType;
import selery.crash : logCrash;
import selery.hub.plugin : HubPlugin, HubPluginOf = PluginOf;
import selery.hub.server : HubServer;
import selery.network.hncom : TidAddress;
import selery.node.plugin : NodePlugin, NodePluginOf = PluginOf;
import selery.node.server : NodeServer;
import selery.path : Paths;
import selery.session.hncom : LiteNode;
import selery.start : startup;
import selery.util.util : UnloggedException;

import pluginloader;

void main(string[] args) {

	static if(__traits(compiles, import("portable.zip"))) {

		// should be executed in an empty directory
		mkdirRecurse(Paths.res);

		import std.zip;

		auto zip = new ZipArchive(cast(void[])import("portable.zip"));

		foreach(name, member; zip.directory) {
			if(name.indexOf("/") != -1) mkdirRecurse(Paths.res ~ name[0..name.lastIndexOf("/")]);
			if(!exists(Paths.res ~ name)) {
				zip.expand(member);
				write(Paths.res ~ name, member.expandedData);
			}
		}

		immutable type = "portable";

	} else {

		immutable type = "default";
		
	}

	bool edu, realm;

	if(startup(ConfigType.lite, type, args, edu, realm)) {
	
		shared NodeServer node;

		new Thread({ new shared HubServer(true, edu, realm, loadPlugins!(HubPluginOf, HubPlugin)()); }).start();

		while(!LiteNode.ready) Thread.sleep(dur!"msecs"(10)); //TODO add a limit in case of failure
		
		try {
			
			node = new shared NodeServer(new TidAddress(cast()LiteNode.tid), "", "", true, loadPlugins!(NodePluginOf, NodePlugin)(), args);
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("node", node is null ? "en_GB" : node.settings.language, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(1);
			
		}
	}
	
}

