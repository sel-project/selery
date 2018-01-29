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
