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
module main;

import std.algorithm : max, min;
import std.concurrency : LinkTerminated;
import std.conv : to;
import std.socket;
import std.string : split, replace, join;

import common.path : Paths;
import common.sel;
import common.util : UnloggedException;

import sel.settings;
import sel.server;
import sel.util.crash;
import sel.util.log;

// prevents linking errors when building with RDMD
mixin((){
	string[] imports;
	foreach(game, protocols; ["pocket": __pocketProtocols, "minecraft": __minecraftProtocols]) {
		foreach(protocol ; protocols) {
			imports ~= "import sul.attributes." ~ game ~ protocol.to!string ~ ";";
			imports ~= "import sul.protocol." ~ game ~ protocol.to!string ~ ";";
			imports ~= "import sul.metadata." ~ game ~ protocol.to!string ~ ";";
		}
	}
	return imports.join("");
}());

void main(string[] args) {
	
	static assert(__VERSION__ >= 2071, "A version equals or higher than 2017 is required, " ~ __VERSION__.to!string ~ " found.");
	
	args = args[1..$];
	
	if(args.length && args[0] == "about") {

		import std.json : JSONValue;
		import std.stdio : writeln;

		auto json = JSONValue([
			"type": JSONValue("node"),
			"software": JSONValue([
				"name": JSONValue(Software.name),
				"version": JSONValue(Software.displayVersion),
				"stable": JSONValue(Software.stable)
			]),
			"minecraft": JSONValue(__minecraftProtocols),
			"pocket": JSONValue(__pocketProtocols)
		]);

		writeln(json.toString());

	} else {

		import std.file : exists, remove;
		if(exists(Paths.hidden ~ "crash")) remove(Paths.hidden ~ "crash");

		Server server;
		
		try {

			string name = args.length > 0 ? args[0] : "node";
			Address address;
			ushort port = args.length > 2 ? to!ushort(args[2]) : 28232;
			bool main = args.length > 3 ? to!bool(args[3]) : true;
			string password = args.length > 4 ? args[4..$].join(" ") : "";
			
			if(args.length > 1) {
				string ip = args[1];
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
			} else {
				address = new InternetAddress("127.0.0.1", port);
			}
			
			server = new Server(address, password, name, main);

		} catch(LinkTerminated) {

		} catch(UnloggedException) {
			
		} catch(Throwable e) {
			
			crash(e);

		} finally {
			
			import std.c.stdlib : exit;
			exit(12014);
			
		}
	}
	
}
