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
module selery.node.plugin.file;

static import std.file;
import std.path : dirSeparator;
import std.string : split, join, replace;

import selery.path : Paths;

private string path(string mod)() {
	return Paths.resources ~ mod.split(".")[0] ~ dirSeparator;
}

public @property bool exists(string mod=__MODULE__)(string file) {
	return std.file.exists(path!mod ~ file);
}

public @property bool isDir(string mod=__MODULE__)(string file) {
	return std.file.isDir(path!mod ~ file);
}

public @property bool isFile(string mod=__MODULE__)(string file) {
	return std.file.isFile(path!mod ~ file);
}

public void[] read(string mod=__MODULE__)(string file) {
	return std.file.read(path!mod ~ file);
}

public void write(string mod=__MODULE__)(string file, const void[] data) {
	version(Windows) {
		file = file.replace(`/`, `\`);
	} else {
		file = file.replace(`\`, `/`);
	}
	immutable dir = path!mod ~ file.split(dirSeparator)[0..$-1].join(dirSeparator);
	if(!std.file.exists(dir)) {
		std.file.mkdirRecurse(dir);
	}
	std.file.write(path!mod ~ file, data);
}

public void remove(string mod=__MODULE__)(string file) {
	std.file.remove(path!mod ~ file);
}
