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
module condition;

import selery.config : Config;

bool cond(string condition, bool is_node)(inout Config config, bool match) {
	static if(condition == "java_enabled") {
		static if(is_node) return config.node.java.enabled == match;
		else return config.hub.java.enabled == match;
	} else static if(condition == "pocket_enabled") {
		static if(is_node) return config.node.pocket.enabled == match;
		else return config.hub.pocket.enabled == match;
	} else {
		return condImpl!condition(config, match);
	}
}

bool condImpl(string condition)(inout Config config, bool match) {
	static if(condition == "java_onlineMode") {
		return config.hub.java.onlineMode == match;
	} else static if(condition == "pocket_onlineMode") {
		return config.hub.pocket.onlineMode == match;
	} else {
		static assert(0, "\"" ~ condition ~ "\" is not a valid condition");
	}
}
