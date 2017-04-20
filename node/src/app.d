module app;

import std.algorithm : max, min;
import std.concurrency : LinkTerminated;
import std.conv : to;
import std.socket;
import std.string : split, replace, join;

import common.crash : logCrash;
import common.path : Paths;
import common.sel : Software;
import common.util : UnloggedException;

import sel.plugin; // it seems that not importing this causes compiler errors
import sel.server : Server, server;

import data : __minecraftProtocols, __pocketProtocols, __loadPlugins;

void main(string[] args) {
	
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
				address = getAddress("localhost", port)[0];
			}
			
			new Server(address, password, name, main, __loadPlugins());
			
		} catch(LinkTerminated) {
			
		} catch(UnloggedException) {
			
		} catch(Throwable e) {

			logCrash("node", server is null ? "en_GB" : server.settings.language, e);
			
		} finally {
			
			import std.c.stdlib : exit;
			exit(12014);
			
		}
	}
	
}
