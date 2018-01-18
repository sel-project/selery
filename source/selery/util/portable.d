/*
 * Copyright (c) 2018 SEL
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
module selery.util.portable;

import std.conv : to;
import std.file : exists;
import std.process : Pid, spawnShell;

enum CHROME_WINDOWS = [
	`C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`,	// windows 10 64
	`C:\Program Files\Google\Chrome\Application\chrome.exe`,		// windows 10 32
	`C:\Program Files (x86)\Google\Application\chrome.exe`,			// windows 7 64
	`C:\Program Files\Google\Application\chrome.exe`,				// windows 7 32
];

Pid startWebAdmin(ushort port) {

	immutable address = "http://127.0.0.1:" ~ port.to!string;

	version(Windows) {
		foreach(location ; CHROME_WINDOWS) {
			if(exists(location)) return spawnShell("\"" ~ location ~ "\" --app=\"" ~ address ~ "/#app\"");
		}
		return spawnShell("start " ~ address); // default browser
	} else {

		//TODO linux
		//TODO osx

		return null;

	}

}
