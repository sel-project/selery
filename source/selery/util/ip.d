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
module selery.util.ip;

import std.conv : to;
import std.file : exists, write, read, mkdirRecurse;
import std.net.curl : CurlException;
import std.path : dirSeparator;
import std.string : split;

import selery.files : Files;
import selery.util.tuple : Tuple;
import selery.util.util : seconds;

alias Addresses = Tuple!(uint, "cached", string, "v4", string, "v6");

private bool load(inout Files files, string file, ref Addresses addresses) {
	if(files.hasTemp("ip_" ~ file)) {
		auto parts = split(cast(string)files.readTemp("ip_" ~ file), "\n");
		if(parts.length == 3) {
			addresses.cached = to!uint(parts[0]);
			addresses.v4 = parts[1];
			addresses.v6 = parts[2];
			return true;
		}
	}
	return false;
}

private void save(inout Files files, string file, ref Addresses addresses) {
	files.writeTemp("ip_" ~ file, addresses.cached.to!string ~ "\n" ~ addresses.v4 ~ "\n" ~ addresses.v6);
}

public Addresses localAddresses(inout Files files) {
	//TODO
	return Addresses.init;
}

public Addresses publicAddresses(inout Files files) {
	Addresses ret;
	if(!load(files, "public", ret) || ret.cached < seconds - 60 * 60 * 3) { // cache for 3 hours
		string get(string url) {
			static import std.net.curl;
			import etc.c.curl : CurlOption;
			auto http = std.net.curl.HTTP();
			http.handle.set(CurlOption.timeout, 3);
			try {
				auto res = std.net.curl.get(url).idup;
				if(res.split(".").length == 4) return res;
			} catch(CurlException) {}
			return "";
		}
		ret.cached = seconds;
		ret.v4 = get("http://ipecho.net/plain");
		//TODO v6
		save(files, "public", ret);
	}
	return ret;
}
