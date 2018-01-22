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
