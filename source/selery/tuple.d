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
module selery.tuple;

import std.conv : to;
import std.traits : isDynamicArray;

struct Tuple(E...) if(E.length % 2 == 0) {

	mixin((){
		string ret;
		foreach(i, T; E) {
			static if(i % 2 == 0) {
				ret ~= "E[" ~ to!string(i) ~ "] ";
			} else {
				ret ~= T ~ ";";
			}
		}
		return ret;
	}());

	static if(E.length == 2) {

		static if(isDynamicArray!(E[0]) && is(E[0] == string)) {
			mixin("public this(E[0] _...){ this." ~ E[1] ~ "=_; }");
		}

		mixin("alias " ~ E[1] ~ " this;");

	}

}
