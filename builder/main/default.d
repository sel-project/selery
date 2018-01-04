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
import selery.hub.plugin : HubPlugin, HubPluginOf = PluginOf;
import selery.hub.server : HubServer;
import selery.network.hncom : TidAddress;
import selery.node.plugin : NodePlugin, NodePluginOf = PluginOf;
import selery.node.server : NodeServer;
import selery.hub.handler.hncom : LiteNode;
import selery.util.util : UnloggedException;

import pluginloader;
import starter;

void main(string[] args) {

	static if(__traits(compiles, import("portable.zip"))) {

		enum type = "portable";

	} else {

		enum type = "default";
		
	}

	start(ConfigType.server, type, args, (Config config){
	
		static if(type == "portable") {
		
			import std.zip;
			
			import selery.files : Files;
			import selery.lang : Lang;
			
			auto portable = new ZipArchive(cast(void[])import("portable.zip"));
			
			//TODO config.files is overwritten on reload
			
			config.files = new class Files {
			
				public this() {
					super("", config.files.temp);
				}
				
				public override inout bool hasAsset(string file) {
					return !!(convert(file) in portable.directory);
				}
				
				public override inout void[] readAsset(string file) {
					auto member = portable.directory[convert(file)];
					if(member.expandedData.length != member.expandedSize) portable.expand(member);
					return cast(void[])member.expandedData;
				}
				
				private static string convert(string file) {
					version(Windows) file = file.replace("\\", "/");
					while(file[$-1] == '/') file = file[0..$-1];
					return file;
				}
			
			};
			
			config.lang = new Lang(config.files);
		
		}

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

