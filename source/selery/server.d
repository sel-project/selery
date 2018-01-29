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
module selery.server;

import selery.config : Config, Files;
import selery.lang : LanguageManager;
import selery.log : Logger;
import selery.plugin : Plugin;

/**
 * Generic server with a configuration and plugins.
 */
interface Server {

	/**
	 * Gets the server's configuration.
	 * Example:
	 * ---
	 * // server name
	 * log("Welcome to ", server.config.hub.displayName);
	 * 
	 * // game version
	 * static if(__pocket) assert(server.config.node.pocket);
	 * static if(__minecraft) log("Port for Minecraft: ", server.config.node.minecraft.port); 
	 * ---
	 */
	shared nothrow @property @safe @nogc const(Config) config();

	/**
	 * Gets the server's files (assets and temp files).
	 * Example:
	 * ---
	 * if(!server.files.hasTemp("test")) {
	 *    server.files.writeTemp("test", "Some content");
	 *    assert(server.files.readTemp("test" == "Some content");
	 * }
	 * ---
	 */
	final shared nothrow @property @safe @nogc const(Files) files() {
		return this.config.files;
	}

	/**
	 * Gets the server's language manager.
	 */
	final shared nothrow @property @safe @nogc const(LanguageManager) lang() {
		return this.config.lang;
	}

	/**
	 * Gets the server's logger.
	 * Example:
	 * ---
	 * server.logger.log("Hello");
	 * ---
	 */
	shared @property Logger logger();

	/**
	 * Gets the plugins actived on the server.
	 * Example:
	 * ---
	 * log("There are ", server.plugins.filter!(a => a.author == "sel-plugins").length, " by sel-plugins");
	 * log("There are ", server.plugins.filter!(a => a.api).length, " plugins with APIs");
	 * ---
	 */
	shared nothrow @property @safe @nogc const(Plugin)[] plugins();

}
