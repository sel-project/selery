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
module loader.hub;

import selery.config : Config;
import selery.hub.plugin : HubPlugin, PluginOf;
import selery.hub.server : HubServer;

import pluginloader;
import starter;

void main(string[] args) {

	start(ConfigType.hub, "hub", args, (Config config){

		new shared HubServer(false, config, loadPlugins!(PluginOf, HubPlugin, false)(config), args);

	});

}
