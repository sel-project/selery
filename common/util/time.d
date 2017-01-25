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
module common.util.time;

import std.datetime : Clock, UTC;

 /**
 * Gets the seconds from January 1st, 1970.
 */
public @property @safe uint seconds() {
	return Clock.currTime(UTC()).toUnixTime!int;
}

/**
 * Gets the milliseconds from January 1st, 1970.
 */
public @property @safe ulong milliseconds() {
	auto t = Clock.currTime(UTC());
	return t.toUnixTime!long * 1000 + t.fracSecs.total!"msecs";
}

/**
 * Gets the microseconds from January 1st, 1970.
 */
public @property @safe ulong microseconds() {
	auto t = Clock.currTime(UTC());
	return t.toUnixTime!long * 1000 + t.fracSecs.total!"usecs";
}
