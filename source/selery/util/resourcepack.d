/*
 * Copyright (c) 2017-2019 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/resourcepack.d, selery/util/resourcepack.d)
 */
module selery.util.resourcepack;

import std.algorithm : canFind;
import std.concurrency : Tid, send;
import std.conv : to;
import std.file : read, dirEntries, SpanMode, isFile;
import std.json : JSONValue;
import std.random : uniform;
import std.regex : ctRegex, replaceAll;
import std.socket;
import std.string : replace, join, indexOf, startsWith;
import std.uuid : UUID;
import std.zip;

import sel.net.http : StatusCodes, Response;

import selery.about : Software;
import selery.node.server : NodeServer;
import selery.util.tuple : Tuple;

auto createResourcePacks(shared NodeServer server, UUID uuid, string[] textures) {

	auto java2 = new ZipArchive();
	auto java3 = new ZipArchive();
	auto pocket = new ZipArchive();

	void add(ArchiveMember member) {
		java2.addMember(member);
		java3.addMember(member);
	}

	// add sel's modified textures to minecraft and pocket resource packs
	foreach(t ; textures) {
		foreach(string file ; dirEntries(t, SpanMode.breadth)) {
			if(isFile(file)) {
				immutable name = replace(file[t.length..$], "\\", "/");
				auto data = cast(ubyte[])read(file);
				add(create("assets/minecraft/textures/" ~ name, data));
				pocket.addMember(create("textures/" ~ name, data));
			}
		}
	}

	// add icon
	auto icon = cast(ubyte[])server.config.files.readAsset("icon.png");
	add(create("pack.png", icon));
	pocket.addMember(create("pack_icon.png", icon));

	// create minecraft's manifest
	auto description = JSONValue("The default look of Selery");
	java2.addMember(create("pack.mcmeta", cast(ubyte[])JSONValue(["pack": JSONValue(["pack_format": JSONValue(2), "description": description])]).toString()));
	java3.addMember(create("pack.mcmeta", cast(ubyte[])JSONValue(["pack": JSONValue(["pack_format": JSONValue(3), "description": description])]).toString()));

	// create pocket's manifest
	auto vers = JSONValue(cast(ubyte[])Software.versions);
	pocket.addMember(create("manifest.json", cast(ubyte[])JSONValue(["format_version": JSONValue(1), "header": JSONValue(["description": description, "name": JSONValue("SEL"), "uuid": JSONValue(uuid.toString()), "version": vers]), "modules": JSONValue([JSONValue(["description": description, "type": JSONValue("resources"), "uuid": JSONValue(server.nextUUID.toString()), "version": vers])])]).toString()));

	return Tuple!(void[], "java2", void[], "java3", void[], "pocket1")(java2.build(), java3.build(), pocket.build());

}

private ArchiveMember create(string name, ubyte[] data) {
	auto ret = new ArchiveMember();
	ret.name = name;
	ret.expandedData(data);
	ret.compressionMethod = CompressionMethod.deflate;
	return ret;
}

void serveResourcePacks(Tid server, string pack2, string pack3) {
	
	auto port = uniform(ushort(999), ushort.max);
	
	auto socket = new TcpSocket();
	socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
	socket.bind(new InternetAddress("0.0.0.0", port));
	socket.listen(16);
	socket.blocking = true;
	
	send(server, port);
	
	char[] buffer = new char[6];
	
	const(void)[] response2 = Response(StatusCodes.ok, ["Content-Type": "application/zip", "Server": Software.display], pack2).toString();
	const(void)[] response3 = Response(StatusCodes.ok, ["Content-Type": "application/zip", "Server": Software.display], pack3).toString();
	
	while(true) {
		
		//TODO create a non-blocking handler
		
		auto client = socket.accept();
		
		auto r = client.receive(buffer);
		if(r == 6) { // length of the buffer
			if(buffer[0..5] == "GET /") {
				if(buffer[5] == '2') client.send(response2);
				else if(buffer[5] == '3') client.send(response3);
				else client.close();
			}
		}
		
	}
	
}
