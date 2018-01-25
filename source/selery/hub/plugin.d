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
module selery.hub.plugin;

public import selery.plugin;
import selery.server : Server;

interface HubPlugin {}

class PluginOf(T) : Plugin if(is(T == Object) || is(T : HubPlugin)) {
	
	public this(string name, string[] authors, string vers, bool api, string languages, string textures) {
		this.n_name = name;
		this.n_authors = authors;
		this.n_version = vers;
		this.n_api = api;
		this.n_languages = languages;
		this.n_textures = textures;
		static if(!is(T : Object)) this.hasMain = true;
	}
	
	public override void load(shared Server server) {
		//TODO register events
	}
	
}
