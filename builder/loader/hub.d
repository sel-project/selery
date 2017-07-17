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

import selery.config : ConfigType;
import selery.hub.plugin : HubPlugin, PluginOf;
import selery.hub.server : HubServer;
import selery.start : startup;

import pluginloader;

void load(string[] args) {

	bool edu, realm;

	if(startup(ConfigType.hub, "hub", args, edu, realm)) {

		new shared HubServer(false, edu, realm, loadPlugins!(PluginOf, HubPlugin)());

	}

}
