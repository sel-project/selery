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
module sel.entity.metadata;

import std.conv : to;
import std.string : join, startsWith;
import std.typetuple : TypeTuple;

import sel.settings;

mixin("alias Games = TypeTuple!(" ~ (){ string[] ret;foreach(g,pr;["pocket":__pocketProtocols,"minecraft":__minecraftProtocols]){foreach(p;pr){ret~="\""~g~p.to!string~"\"";}}return ret.join(","); }() ~ ");");

mixin((){
	string ret;
	foreach(immutable game ; Games) {
		ret ~= "static import sul.metadata." ~ game ~ ";";
	}
	return ret;
}());

class Metadata {

	mixin((){
		string ret;
		foreach(immutable game ; Games) {
			ret ~= "public sul.metadata." ~ game ~ ".Metadata " ~ game ~ ";";
		}
		return ret;
	}());

	public bool changed = false;

	public pure nothrow @safe this() {
		foreach(immutable game ; Games) {
			mixin("this." ~ game ~ " = new sul.metadata." ~ game ~ ".Metadata();");
		}
	}

	T get(string m, T)() {
		foreach(immutable game ; Games) {
			mixin("alias T = sul.metadata." ~ game ~ ".Metadata;");
			static if(__traits(hasMember, T, m)) {
				mixin("return this." ~ game ~ "." ~ m ~ ";");
			}
		}
		return T.init;
	}

	T set(string m, string filter, T)(T value) {
		foreach(immutable game ; Games) {
			static if(!filter.length || game.startsWith(filter)) {
				mixin("alias T = sul.metadata." ~ game ~ ".Metadata;");
				static if(__traits(hasMember, T, m)) {
					this.changed = true;
					mixin("this." ~ game ~ "." ~ m ~ " = value;");
				}
			}
		}
		return value;
	}

	T set(string m, T)(T value) {
		return this.set!(m, "")(value);
	}

}
