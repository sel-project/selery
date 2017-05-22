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
module lite;

import core.thread : Thread, dur;

import std.concurrency : LinkTerminated;
import std.conv : to;
import std.file : write, exists, mkdirRecurse;
import std.path : dirSeparator;
import std.string : indexOf, lastIndexOf;

import sel.config : ConfigType;
import sel.crash : logCrash;
import sel.path : Paths;
import sel.start : startup;
import sel.utils : UnloggedException;
import sel.network.hncom : TidAddress;
import sel.session.hncom : MessagePassingNode;

static import sel.hub.server;
static import sel.node.server;

static import pluginloader.hub;
static import pluginloader.node;

void main(string[] args) {

	static if(__traits(compiles, import("portable.zip"))) {

		// should be executed in an empty directory
		Paths.load("." ~ dirSeparator);
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

		immutable type = "lite";
		
	}

	bool edu, realm;

	if(startup(ConfigType.lite, type, args, edu, realm)) {

		new Thread({ new shared sel.hub.server.Server(true, edu, realm, pluginloader.hub.loadPlugins()); }).start();

		while(!MessagePassingNode.ready) Thread.sleep(dur!"msecs"(10)); //TODO add a limit in case of failure
		
		try {
			
			new sel.node.server.Server(new TidAddress(cast()MessagePassingNode.tid), "", "", true, pluginloader.node.loadPlugins(), args);
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("node", sel.node.server.server is null ? "en_GB" : sel.node.server.server.settings.language, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(1);
			
		}
	}
	
}

