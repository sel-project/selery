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
module loader.default_;

import core.thread : Thread, dur;

import std.concurrency : LinkTerminated;
import std.conv : to;
import std.file : write, exists, mkdirRecurse;
import std.path : dirSeparator;
import std.string : indexOf, lastIndexOf, replace;

import selery.config : Config;
import selery.crash : logCrash;
import selery.hub.handler.hncom : LiteNode;
import selery.hub.plugin : HubPlugin, HubPluginOf = PluginOf;
import selery.hub.server : HubServer;
import selery.node.handler : TidAddress;
import selery.node.plugin : NodePlugin, NodePluginOf = PluginOf;
import selery.node.server : NodeServer;
import selery.util.util : UnloggedException;

import config : ConfigType;
import pluginloader;
import starter;

void main(string[] args) {

	start(ConfigType.default_, args, (Config config){

		new Thread({ new shared HubServer(true, config, loadPlugins!(HubPluginOf, HubPlugin, false)(config), args); }).start();

		while(!LiteNode.ready) Thread.sleep(dur!"msecs"(10)); //TODO add a limit in case of failure
		
		try {
			
			new shared NodeServer(new TidAddress(cast()LiteNode.tid), "", "", true, config, loadPlugins!(NodePluginOf, NodePlugin, true)(config), args);
			
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

