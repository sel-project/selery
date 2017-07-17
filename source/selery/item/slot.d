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
module selery.item.slot;

import std.conv : to;

import selery.about;
import selery.item.item : Item;
import selery.item.items : Items;

/**
 * Container for an item stack that has always a value.
 * If the slot is not empty, an Item instance and the count
 * can be stored.
 * 
 * Conventionally an empty slot is always constructed using Slot(null)
 */
struct Slot {

	private Item n_item;
	public ubyte count;

	/**
	 * Creates a slot with an item and its highest value as count.
	 * Example:
	 * ---
	 * assert(Slot(new Items.DiamondSword()).count == 1);
	 * assert(Slot(new Items.Snowball()).count == 16);
	 * assert(Slot(null).count == 0);
	 * ---
	 */
	public @safe @nogc this(Item item) {
		if(item !is null) {
			this.n_item = item;
			this.count = this.item.max;
		}
	}

	/**
	 * Creates a slot giving an item and a count in range 0..255 (unsigned byte).
	 * Setting an higher value it's impossible due to protocol's limitations.
	 * Example:
	 * ---
	 * assert(Slot(new Items.DiamondSword(), 22).count == 22);
	 * assert(Slot(new Items.Snowball(), 2).count == 2);
	 * assert(Slot(null, 100).count == 0);
	 * ---
	 */
	public @safe @nogc this(Item item, ubyte count) {
		this(item);
		if(this.item !is null) this.count = count;
	}

	/**
	 * Gets the slot's item.
	 */
	public pure nothrow @property @safe @nogc Item item() {
		return this.n_item;
	}

	/**
	 * Checks whether or not the slot is empty.
	 * A slot is considered empty when its count is equal to 0 or
	 * when its item is null.
	 * Example:
	 * ---
	 * Slot slot = Slot(null);
	 * assert(slot.empty);
	 * 
	 * slot = Slot(new Items.Snowball(), 1);
	 * assert(!slot.empty);
	 * 
	 * slot.count--;
	 * assert(slot.empty);
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool empty() {
		return this.count == 0 || this.item is null;
	}

	/**
	 * Checks whether or not the slot is full.
	 * The slot is considered full when its count is equals or
	 * higher than the item's max stackable size.
	 * Example:
	 * ---
	 * assert(Slot(new Items.DiamondSword(), 1).full);
	 * assert(!Slot(new Items.Snowball(), 15).full);
	 * ---
	 * 
	 * This property should be called only if the slot isn't empty due
	 * to its call on the item's property, that can be null.
	 * ---
	 * if(!slot.empty && slot.full) { ... }
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool full() {
		return this.count >= this.item.max;
	}

	/**
	 * Fills the slot setting the count as the max stacking value
	 * of the item.
	 * Example:
	 * ---
	 * Slot slot = Slot(new Item.Snowball(), 1);
	 * assert(slot.count == 1);
	 * slot.fill();
	 * assert(slot.count == 16);
	 * ---
	 * 
	 * Like full, this function requires item to not be null due to
	 * its call on its max property.
	 * ---
	 * if(slot.item !is null) {
	 *    slot.fill();
	 * }
	 * ---
	 */
	public pure nothrow @safe @nogc void fill() {
		this.count = this.item.max;
	}

	public bool opEquals(Slot slot) {
		return this.empty == slot.empty && (this.empty || this.count == slot.count && this.item == slot.item);
	}

	public bool opEquals(Item item) {
		return this.empty == !!(item is null) && (this.empty || this.item == item);
	}

	public bool opEquals(item_t item) {
		return this.empty == (item == Items.air) && (this.empty || this.item == item);
	}

	public string toString() {
		return "Slot(" ~ (this.empty ? "null" : (this.item.toString() ~ " x" ~ this.count.to!string)) ~ ")";
	}

}
