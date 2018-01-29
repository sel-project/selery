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
