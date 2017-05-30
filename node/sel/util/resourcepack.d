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
module sel.util.resourcepack;

import std.algorithm : canFind;
import std.conv : to;
import std.file : read, dirEntries, SpanMode, isFile;
import std.json : JSONValue;
import std.regex : ctRegex, replaceAll;
import std.string : replace, join;
import std.uuid : UUID;
import std.zip;

import sel.about : Software;
import sel.lang : Lang;
import sel.path : Paths;
import sel.node.server : Server;
import sel.tuple : Tuple;

auto createResourcePacks(shared Server server, UUID uuid, string[] textures) {

	auto minecraft2 = new ZipArchive();
	auto minecraft3 = new ZipArchive();
	auto pocket = new ZipArchive();

	void add(ArchiveMember member) {
		minecraft2.addMember(member);
		minecraft3.addMember(member);
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
	auto icon = cast(ubyte[])read(Paths.res ~ "icon.png");
	add(create("pack.png", icon));
	pocket.addMember(create("pack_icon.png", icon));

	// create minecraft's manifest
	auto description = JSONValue("The default look of SEL");
	minecraft2.addMember(create("pack.mcmeta", cast(ubyte[])JSONValue(["pack": JSONValue(["pack_format": JSONValue(2), "description": description])]).toString()));
	minecraft3.addMember(create("pack.mcmeta", cast(ubyte[])JSONValue(["pack": JSONValue(["pack_format": JSONValue(3), "description": description])]).toString()));

	// create pocket's manifest
	auto vers = JSONValue(cast(ubyte[])Software.versions);
	pocket.addMember(create("manifest.json", cast(ubyte[])JSONValue(["format_version": JSONValue(1), "header": JSONValue(["description": description, "name": JSONValue("SEL"), "uuid": JSONValue(uuid.toString()), "version": vers]), "modules": JSONValue([JSONValue(["description": description, "type": JSONValue("resources"), "uuid": JSONValue(server.nextUUID.toString()), "version": vers])])]).toString()));

	return Tuple!(void[], "minecraft2", void[], "minecraft3", void[], "pocket1")(minecraft2.build(), minecraft3.build(), pocket.build());

}

private ArchiveMember create(string name, ubyte[] data) {
	auto ret = new ArchiveMember();
	ret.name = name;
	ret.expandedData(data);
	ret.compressionMethod = CompressionMethod.deflate;
	return ret;
}
