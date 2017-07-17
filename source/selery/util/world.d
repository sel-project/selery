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
module selery.util.world;

import selery.about;

class World {

	public immutable uint id;
	public immutable string name;
	public immutable ubyte dimension;

	public World parent;

	public shared this(uint id, string name, ubyte dimension) {
		this.id = id;
		this.name = name;
		this.dimension = dimension;
	}

}
