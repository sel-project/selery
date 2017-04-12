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
module sel.util.ip;

import std.algorithm : min;
import std.ascii : newline;
import std.conv : to;
import std.file;
import std.json : parseJSON;
import std.net.curl : get;
import std.path : dirSeparator;
import std.process : executeShell;
import std.string : split, strip, indexOf;
import std.typecons : Tuple;

import common.path : Paths;
import common.util : seconds;

alias Cache = Tuple!(uint, "time", string, "ip");

public @property string publicImpl(string file, uint v)() {
	auto cache = cache(file);
	if(cache.time < seconds - 60 * 60) {
		cache.time = seconds;
		cache.ip = parseJSON(get("http://v" ~ to!string(v) ~ ".ifconfig.co/json")).object["ip"].str;
		save(file, cache);
	}
	if(cache.ip == "") throw new Exception("");
	return cache.ip;
}

alias publicIpv4 = publicImpl!("public4", 4);

alias publicIpv6 = publicImpl!("public6", 6);

public @property string localImpl(string file, string v, string def, string pubf)() {
	string pub;
	try {
		mixin("pub = " ~ pubf ~ ";");
	} catch(Exception) {}
	auto cache = cache(file);
	if(cache.time < seconds - 60 * 10) {
		version(linux) {
			foreach(p ; executeShell("ifconfig").output.split("inet" ~ v ~ " addr:")[1..$]) {
				p = p.strip;
				string addr = p[0..min($, cast(size_t)p.indexOf("/"), cast(size_t)p.indexOf(" "))].strip;
				if(addr != def && addr != pub) {
					cache.ip = addr;
				}
			}
			save(file, cache);
		} else {
			throw new Exception("");
		}
		//save(file, cache);
	}
	if(cache.ip == "") throw new Exception("");
	return cache.ip;
}

alias localIpv4 = localImpl!("local4", "", "127.0.0.1", "publicIpv4");

alias localIpv6 = localImpl!("local6", "6", "::1", "publicIpv6");

private Cache cache(string file) {
	try {
		string[] split = (cast(string)read(tempDir() ~ dirSeparator ~ "sel" ~ dirSeparator ~ file)).split(newline);
		return Cache(to!uint(split[0]), split[1]);
	} catch(Throwable) {
		return Cache.init;
	}
}

private void save(string file, Cache cache) {
	if(!exists(tempDir() ~ dirSeparator ~ "sel")) mkdirRecurse(tempDir() ~ dirSeparator ~ "sel");
	write(tempDir() ~ dirSeparator ~ "sel" ~ dirSeparator ~ file, to!string(cache.time) ~ newline ~ cache.ip);
}
