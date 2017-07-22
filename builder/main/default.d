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

import selery.config : Config;
import selery.crash : logCrash;
import selery.hub.plugin : HubPlugin, HubPluginOf = PluginOf;
import selery.hub.server : HubServer;
import selery.network.hncom : TidAddress;
import selery.node.plugin : NodePlugin, NodePluginOf = PluginOf;
import selery.node.server : NodeServer;
import selery.session.hncom : LiteNode;
import selery.util.util : UnloggedException;

import pluginloader;
import starter;

void main(string[] args) {

	static if(__traits(compiles, import("portable.zip"))) {

		// should be executed in an empty directory
		//mkdirRecurse(Paths.res);

		import std.zip;

		/*auto zip = new ZipArchive(cast(void[])import("portable.zip"));

		foreach(name, member; zip.directory) {
			if(name.indexOf("/") != -1) mkdirRecurse(Paths.res ~ name[0..name.lastIndexOf("/")]);
			if(!exists(Paths.res ~ name)) {
				zip.expand(member);
				write(Paths.res ~ name, member.expandedData);
			}
		}*/

		enum type = "portable";

	} else {

		enum type = "default";
		
	}

	start(ConfigType.server, type, args, (Config config){
	
		static if(type == "portable") {
		
			//TODO override assets reader
			
			auto portable = new ZipArchive(cast(void[])import("portable.zip"));
			
			config.files = new class Files {
			
				public this() {
					super("", config.files.temp);
				}
				
				public override inout bool hasAsset(string file) {
					return convert(file) in portable.directory;
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
		
		}

		new Thread({ new shared HubServer(true, config, loadPlugins!(HubPluginOf, HubPlugin)(), args); }).start();

		while(!LiteNode.ready) Thread.sleep(dur!"msecs"(10)); //TODO add a limit in case of failure
		
		try {
			
			new shared NodeServer(new TidAddress(cast()LiteNode.tid), "", "", true, config, loadPlugins!(NodePluginOf, NodePlugin)(), args);
			
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

