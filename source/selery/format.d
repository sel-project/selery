/*
 * Copyright (c) 2017-2018 SEL
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
module selery.format;

/**
 * Removes valid formatting codes from a message.
 * Note that this function also removes uppercase formatting codes
 * because they're supported by Minecraft (but not by Minecraft Pocket
 * Edition).
 * Example:
 * ---
 * assert(unformat("§agreen") == "green");
 * assert(unformat("res§Ret") == "reset");
 * assert(unformat("§xunsupported") == "§xunsupported");
 * ---
 */
string unformat(string message) {
	// regex should be ctRegex!("§[0-9a-fk-or]", "") but obviously doesn't work on DMD's release mode
	for(size_t i=0; i<message.length-2; i++) {
		if(message[i] == 194 && message[i+1] == 167) {
			char next = message[i+2];
			if(next >= '0' && next <= '9' ||
				next >= 'A' && next <= 'F' || next >= 'K' && next <= 'O' || next == 'R' ||
				next >= 'a' && next <= 'f' || next >= 'k' && next <= 'o' || next == 'r')
			{
				message = message[0..i] ~ message[i+3..$];
				i--;
			}
		}
	}
	return message;
}
