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
module selery.item.recipe;

import selery.about : block_t, item_t;

class Recipe {}

/**
 * Example:
 * ---
 * // for oak wood planks
 * new ShapelessRecipe([Items.oakWood: 1], 4);
 * ---
 */
class ShapelessRecipe : Recipe {

	public this(ubyte[item_t] items, ubyte result=1) {}

	public this(item_t items...) {}

}

class ShapedRecipe : Recipe {}

class SmallRecipe : ShapedRecipe {}

class BigRecipe : ShapedRecipe {}

class FurnaceRecipe : Recipe {}

class BrewingRecipe : Recipe {}
