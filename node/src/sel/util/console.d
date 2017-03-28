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
module sel.util.console;

import std.concurrency : send;
import std.stdio : readln;
import std.string : strip;

import sel.util.concurrency : Thread;

class Console : Thread {

	public override void run() {
		while(this.running) {
			string cmd = readln().strip;
			if(cmd.length != 0) {
				send(this.owner, cmd);
			}
		}
	}

}
