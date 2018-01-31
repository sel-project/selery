/*
 * Copyright (c) 2017-2018 sel-project
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
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/util/ip.d, selery/util/ip.d)
 */
module selery.util.ip;

import std.conv : to;
import std.file : exists, write, read, mkdirRecurse;
import std.net.curl : CurlException;
import std.path : dirSeparator;
import std.string : split;

import selery.config : Files;
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
			try {
				auto http = std.net.curl.HTTP();
				http.handle.set(CurlOption.timeout, 3);
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
