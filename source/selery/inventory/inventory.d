/*
 * Copyright (c) 2017-2019 sel-project
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
/**
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/inventory/inventory.d, selery/inventory/inventory.d)
 */
module selery.inventory.inventory;

import std.conv : to;
import std.exception : enforce;
import std.typecons : Tuple;

import selery.about : item_t;
import selery.entity.human : Human;
import selery.item.item : Item;
import selery.item.slot : Slot;
import selery.item.tool : Armor;

private alias Slice = Tuple!(size_t, "min", size_t, "max");

/**
 * Exception thrown by the inventory when a range error happens,
 * instead of the classic RangeError that gives a bad description
 * of the problem.
 */
class InventoryRangeError : Error {
	
	public pure nothrow @safe this(string message, string file=__FILE__, size_t line=__LINE__) {
		super(message, file, line, null);
	}
	
	public pure nothrow @safe this(size_t index, Inventory inventory, string file=__FILE__, size_t line=__LINE__) {
		this("Index " ~ to!string(index) ~ " exceeds the inventory range of 0.." ~ to!string(inventory.length), file, line);
	}
	
}

/**
 * Basic inventory class with adding/removing/assigning/filling functions.
 * Example:
 * ---
 * auto inventory = new Inventory(10);
 * 
 * // assign
 * inventory[4] = Slot(new Items.Apple(), 12);
 * inventory[5] = new Items.Apple();
 * 
 * // automatically add in the first empty slot
 * inventory.add(new Items.Beetroot());
 * 
 * // fill
 * inventory = new Items.Beetroot();
 * 
 * // an inventory can also be iterated
 * foreach(ref Slot slot ; inventory) {
 *    d(slot);
 * }
 * ---
 */
class Inventory {
	
	private Slot[] n_slots;
	
	/**
	 * Creates an inventory with the given number of slots.
	 * The number of slots must be higher than 0 and shorter than 2^16.
	 * Params:
	 * 		size = the size of the inventory
	 */
	public @safe this(size_t size) {
		this.n_slots.length = size;
	}
	
	/**
	 * Constructs an inventory giving an array of slots.
	 * The length of the inventory will be the same as the given array.
	 * Params:
	 * 		slots = one or more slots
	 * Example:
	 * ---
	 * auto a = new Inventory(Slot(null));
	 * auto b = new Inventory(Slot(null), Slot(null));
	 * auto c = new Inventory([Slot(null), Slot(null)]);
	 * ---
	 */
	public @safe this(Slot[] slots ...) {
		this.n_slots = slots.dup;
	}
	
	/// ditto
	public @safe this(Inventory inventory) {
		this(cast(Slot[])inventory);
	}
	
	/**
	 * Gets every slots of the inventory (0..$).
	 * This property should only be used when the full inventory is needed,
	 * otherwise opIndex should be used for getting a slot in a specific index
	 * or in a specific range.
	 * Returns: an array with every slot in the inventory
	 * Example:
	 * ---
	 * auto inventory = new Inventory(2);
	 * assert(inventory[] == [Slot(null), Slot(null)]);
	 * assert(cast(Slot[])inventory == inventory[]);
	 * ---
	 */
	public @safe Slot[] opIndex() {
		return this.n_slots[0..$];
	}
	
	/// ditto
	public @safe T opCast(T)() if(is(T == Slot[])) {
		return this.opIndex();
	}
	
	/**
	 * Gets the slot at the given index.
	 * Params:
	 * 		index = a number in range 0..$
	 * Returns: the slot at the given index
	 * Throws: RangeError if an invalid index is given
	 * Example:
	 * ---
	 * if(!inventory[1].empty && inventory[1].item == Items.APPLE) { ... }
	 * ---
	 */
	public @safe Slot opIndex(size_t index) {
		//if(index >= this.length) throw new InventoryRangeError(index, this);
		return this.n_slots[index];
	}
	
	/**
	 * Gets the slots in a specific range.
	 * Params:
	 * 		slice = the slice obtained with opSlice, e.g. inventory[0..10]
	 * Returns: an <a href="#InventoryRange">InventoryRange</a> with the slots at the given indexes
	 * Throws: RangeError if an invalid range or index is given
	 * Example:
	 * ---
	 * auto inventory = new Inventory(4);
	 * inventory[2] = Slot(new Items.Apple(), 1);
	 * assert(inventory[2..$] == [Slot(new Items.Apple(), 1), Slot(null)]);
	 * ---
	 */
	public @safe InventoryRange opIndex(Slice slice) {
		//if(slice.max > this.length) throw new InventoryRangeError(slice.max, this);
		return new InventoryRange(this, slice.min, slice.max);
	}
	
	/**
	 * Sets the slot at the given index.
	 * Params:
	 * 		slot = the item to set
	 * 		index = a number in range 0..$
	 * Throws: RangeError if an invalid index is given
	 * Example:
	 * ---
	 * if(inventory[1].empty || inventory[1].item != Items.BEETROOT) {
	 *    inventory[1] = Slot(new Items.Beetroot());
	 * }
	 * ---
	 */
	public @safe void opIndexAssign(Slot slot, size_t index) {
		//if(index >= this.length) throw new InventoryRangeError(index, this);
		// TODO create a duplicate for the item (mantaining the class type)
		this.n_slots[index] = slot.empty ? slot : Slot(slot.item/*.exactDuplicate*/, slot.count);
	}
	
	/**
	 * Sets the slots in the given range.
	 * Params:
	 * 		slot = the slot to be set
	 * 		slice = the range to set
	 * Throws: RangeError is an invalid range or index is given
	 * Example:
	 * ---
	 * inventory[2..4] = Slot(new Items.Apple(), 32);
	 * inventory[4..6] = another[10..12];
	 * ---
	 */
	public @safe void opIndexAssign(Slot slot, Slice slice) {
		foreach(size_t index ; slice.min..slice.max) {
			this[index] = slot;
		}
	}
	
	/// ditto
	public @safe void opIndexAssign(Slot[] slots, Slice slice) {
		foreach(size_t index ; slice) {
			this[index] = slots[index - slice.min];
		}
	}
	
	// returns a slice with the given indexes
	public @safe Slice opSlice(size_t pos)(size_t min, size_t max) {
		return Slice(min, max);
	}
	
	/// Gets the size of the inventory.
	public pure nothrow @property @safe @nogc size_t length() {
		return this.n_slots.length;
	}
	
	/// ditto
	public pure nothrow @safe @nogc size_t opDollar(size_t pos)() {
		return this.length;
	}
	
	/**
	 * Concatenates two inventories (or an inventory and an array of slots)
	 * and returns a new one.
	 * Example:
	 * ---
	 * auto inventory = new Inventory(4);
	 * auto ni = inventory ~ [Slot(null), Slot(null)] ~ inventory;
	 * assert(inventory.length == 4);
	 * assert(ni.length == 10);
	 * ---
	 */
	public @safe Inventory opBinary(string op)(Slot[] slots) if(op == "~") {
		return new Inventory(this[] ~ slots);
	}
	
	/// ditto
	public @safe Inventory opBinary(string op)(Inventory inventory) if(op == "~") {
		return this.opBinary!op(inventory[]);
	}
	
	/// ditto
	public @safe Inventory opBinary(string op)(Slot slot) if(op == "~") {
		return this.opBinary!op([slot]);
	}
	
	/// ditto
	public @safe Inventory opBinaryRight(string op)(Slot[] slots) if(op == "~") {
		return this.opBinary!op(slots);
	}
	
	/// ditto
	public @safe Inventory opBinaryRight(string op)(Slot slot) if(op == "~") {
		return this.opBinaryRight!op([slot]);
	}
	
	/**
	 * Adds slot(s) to the inventory (if there's enough space).
	 * Note that this function will only mutate the the inventory's
	 * slots' content without mutating its length.
	 * Params:
	 * 		slot = slot(s) that will be added to the inventory
	 * Returns: the slot(s) that couldn't be added to the inventory
	 * Example:
	 * ---
	 * auto inventory = new Inventory(10);
	 * inventory += Slot(new Items.Apple(), 32);
	 * assert(inventory[0].item == Items.APPLE);
	 * ---
	 */
	public @trusted Slot opOpAssign(string op)(Slot slot) if(op == "+") {
		if(slot.empty) return slot;
		// try to add on deep equals items
		// try to add on free space
		size_t[] empties;
		foreach(size_t index, Slot islot; this[]) {
			if(islot.empty) {
				empties ~= index;
			} else if(islot.item == slot.item && !islot.full) {
				uint count = islot.count + slot.count;
				ubyte max = (count < slot.item.max ? count : slot.item.max) & 255;
				this[index] = Slot(slot.item, max);
				if(count > max) {
					slot.count = (count - max) & 255;
				} else {
					return Slot(null);
				}
			}
		}
		foreach(size_t index ; empties) {
			ubyte count = slot.count <= slot.item.max ? slot.count : slot.item.max;
			this[index] = Slot(slot.item, count);
			if(count < slot.count) {
				slot.count = (slot.count - count) & 255;
			} else {
				return Slot(null);
			}
		}
		return slot;
	}
	
	/// ditto
	public @safe Slot[] opOpAssign(string op)(Slot[] slots) if(op == "+") {
		Slot[] ret;
		foreach(Slot slot ; slots) {
			Slot res = this.opOpAssign!op(slot);
			if(!res.empty) {
				ret ~= res;
			}
		}
		return ret;
	}
	
	/**
	 * Removes slot(s) from the inventory.
	 * Parameter types:
	 * 		string = tries to remove items with the same name
	 * 		string[] = tries to remove items with one of the names in the array
	 * 		Item = tries to remove items with the same name and properties
	 * 		Slot = tries to remove items with the same name, properties and count
	 * Returns: the number of slots that has been set to empty
	 * Example:
	 * ---
	 * inventory -= Items.FOOD;          // remove food
	 * inventory -= new Items.Apple();   // remove apples
	 * ---
	 */
	public @trusted uint opOpAssign(string op, T)(T item) if(op == "-" && (is(T == Slot) || is(T : Item) || is(T == string) || is(T == string[]) || is(T == immutable(string)[]))) {
		static if(is(T == Slot)) {
			assert(!item.empty, "Slot can't be empty");
			immutable operation = "slot == item";
		} else {
			assert(item !is null, "Item can't be null");
			immutable operation = "slot.item == item";
		}
		uint removed = 0;
		foreach(size_t index, Slot slot; this[]) {
			if(!slot.empty) {
				if(mixin(operation)) {
					this[index] = Slot(null);
					removed++;
				}
			}
		}
		return removed;
	}
	
	/// ditto
	public @safe uint opOpAssign(string op, T)(T[] items) if(op == "-" && (is(T == Slot) || is(T == Item))) {
		uint removed = 0;
		foreach(T item ;items) {
			removed += this.opOpAssign!op(item);
		}
		return removed;
	}
	
	/**
	 * Matches the first occurence and returns the pointer to the slot.
	 * Paramenter types:
	 * 		string = checks for an item with the same name
	 * 		string[] = checks for an item with one of the names in the array
	 * 		Item = checks for an item with the same name and properties (custom name, enchantments, ...)
	 * 		Slot = checks for the item (see above) and the count of the item
	 * Returns: a pointer to first occurence found, or null if no occurences were found
	 * Standards:
	 * 		Use "Slot(null) in inventory" to check for an empty slot.
	 * Example:
	 * ---
	 * // check for an empty slot
	 * if(Slot(null) in inventory) {
	 *   d("there's space!");
	 * }
	 * ---
	 */
	public @trusted Slot* opBinary(string op, T)(T item) if(op == "in" && (is(T == Slot) || is(T : Item) || is(T == string) || is(T == string[]) || is(T == immutable(string)[]))) {
		static if(is(T == Slot)) {
			immutable operation = "slot == item";
		} else {
			immutable operation = "!slot.empty && slot.item == item";
		}
		foreach(Slot slot ; this[]) {
			if(mixin(operation)) return &slot;
		}
		return null;
	}
	
	/**
	 * Groups an item type into the given slot, if possible.
	 * Params:
	 * 		index = the index of the slot where the items should be grouped
	 * Example:
	 * ---
	 * auto inventory = new Inventory(10);
	 * inventory[0..3] = Slot(new Items.Cookie(), 30);
	 * inventory.group(0);
	 * assert(inventory[0].count == 64);
	 * assert(inventory[1].count == 0);
	 * assert(inventory[2].count == 26);
	 * ---
	 */
	public @trusted void group(size_t index) {
		Slot target = this[index];
		if(!target.empty && !target.full) {
			Item item = target.item;
			uint count = target.count;
			foreach(size_t i, Slot slot; this[]) {
				if(i != index && !slot.empty && slot.item == item) {
					uint c = count + slot.count;
					if(c >= item.max) {
						count = item.max;
						this[i] = Slot(item, (c - item.max) & ubyte.max);
						break;
					} else {
						count = c;
						this[i] = Slot(null);
					}
				}
			}
			if(count != target.count) this[index] = Slot(item, count & ubyte.max);
		}
	}
	
	/**
	 * Performs a basic math operation on every slot's count in
	 * the inventory, if not empty.
	 * Example:
	 * ---
	 * auto inventory = new Inventory(new Items.Apple(), Slot(new Items.Cookie(), 12));
	 * inventory += 40;
	 * assert(inventory == [Slot(new Items.Apple(), 64), Slot(new Items.Cookie(), 52)]);
	 * inventory -= 52;
	 * assert(inventory == [Slot(new Items.Apple(), 12), Slot(null)]);
	 * inventory *= 4;
	 * assert(inventory == [Slot(new Items.Apple(), 48), Slot(null)]);
	 * inventory /= 24;
	 * assert(inventory == [Slot(new Items.Apple(), 2), Slot(null)]);
	 * ---
	 */
	public @safe void opOpAssign(string op, T)(T number) if(is(T : int) && (op == "+" || op == "-" || op == "*" || op == "/")) {
		foreach(size_t index, Slot slot; this[]) {
			if(!slot.empty) {
				mixin("int count = slot.count " ~ op ~ " number;");
				this[index] = Slot(slot.item, count <= 0 ? 0 : (count > slot.item.max ? slot.item.max : (count & ubyte.max)));
			}
		}
	}
	
	/**
	 * Checks whether or not the inventory is empty.
	 * Returns: true if the inventory is empty, false otherwise
	 * Example:
	 * ---
	 * if(inventory.empty) {
	 *    inventory[5] = new Items.Beetroot();
	 *    assert(!inventory.empty);
	 * }
	 * ---
	 */
	public @property @safe bool empty() {
		foreach(Slot slot ; this[]) {
			if(!slot.empty) return false;
		}
		return true;
	}
	
	/**
	 * Removes every item from inventory if empty is true.
	 * Example:
	 * ---
	 * if(!inventory.empty) {
	 *    inventory.empty = true;
	 * }
	 * ---
	 */
	public @property @safe bool empty(bool empty) {
		if(!empty) {
			return false;
		} else {
			this[0..$] = Slot(null);
			return true;
		}
	}
	
	/**
	 * Compares the inventory with an array of slots.
	 * Returns: true if the length and the item at every index is equals to the array's ones
	 * Example:
	 * ---
	 * auto inventory = new Inventory(Slot(null), Slot(new Items.Apple()));
	 * assert(inventory == [Slot(null), Slot(new Items.Apple())]);
	 * assert(inventory != [Slot(null), Slot(new Items.Apple(), 12)]);
	 * assert(inventory != [Slot(null), Slot(new Items.Apple("{\"customName\":\"test\"}"))]);
	 * ---
	 */
	public bool opEquals(Slot[] slots) {
		if(this.length != slots.length) return false;
		foreach(size_t i ; 0..this.length) {
			if(this[i] != slots[i]) return false;
		}
		return true;
	}
	
	/// ditto
	public override bool opEquals(Object object) {
		return cast(Inventory)object ? this.opEquals(cast(Slot[])cast(Inventory)object) : false;
	}
	
	/**
	 * Returns a string with representing the inventory and its
	 * array of slots.
	 */
	public override string toString() {
		return "Inventory(" ~ to!string(this.length) ~ ", " ~ to!string(this[]) ~ ")";
	}
	
}

unittest {
	
	import selery.item.items : Items;
	
	// creation
	auto inventory = new Inventory(10);
	assert(inventory.empty && inventory.length == 10);
	
	// assignment
	inventory[2] = Slot(new Items.Apple(), 64);
	assert(!inventory.empty && inventory[2] == Slot(new Items.Apple(), 64));
	
	// range assignment
	inventory[1..4] = Slot(new Items.Cookie(), 60);
	assert(inventory[3] == Slot(new Items.Cookie(), 60));
	
	// concatenation
	assert((inventory ~ inventory).length == 20);
	assert((inventory ~ Slot(null))[$-1] == Slot(null));
	
	// adding an item
	inventory += Slot(new Items.Cookie(), 1);
	assert(inventory[1] == Slot(new Items.Cookie(), 61));
	inventory += Slot(new Items.Cookie("{\"customName\":\"Special Cookie\"}"), 1);
	assert(inventory[1].count == 61 && inventory[0].item.customName == "Special Cookie");
	
	// removing an item
	inventory -= Slot(new Items.Cookie(), 61);
	assert(inventory[1].empty);
	inventory -= new Items.Cookie();
	assert(inventory[2].empty && !inventory[0].empty);
	inventory -= Items.COOKIE;
	assert(inventory.empty);
	
	// math
	inventory += Slot(new Items.Cookie(), 12);
	inventory += 12;	// 24
	inventory -= 8;		// 16
	inventory *= 4;		// 64
	inventory /= 32;	// 2
	assert(inventory[0] == Slot(new Items.Cookie(), 2));
	
	// group
	inventory[2..4] = Slot(new Items.Cookie(), 32);
	inventory[1] = Slot(new Items.Cookie("{\"customName\":\"Ungroupable\"}"), 32);
	inventory.group(2);
	assert(inventory[0].empty && inventory[2].count == 64 && inventory[3].count == 2);
	
}

/**
 * A part of an inventory with all the methods of a normal inventory.
 * It's given by default using by calling the Inventory's method opIndex
 * with a valid range.
 * 
 * This kind of inventory can be used to perform operations only on
 * a part of the full inventory.
 * Example:
 * ---
 * auto inventory = new Inventory(100);
 * auto part = inventory[50..$];
 * part += new Items.Apple();
 * ---
 */
class InventoryRange : Inventory {
	
	private Inventory inventory;
	public immutable size_t start, end;
	
	public @safe this(Inventory inventory, size_t start, size_t end) {
		super(0);
		this.inventory = inventory;
		this.start = start;
		this.end = end;
	}
	
	public override @safe Slot[] opIndex() {
		return this.inventory[][this.start..this.end];
	}
	
	public override @safe Slot opIndex(size_t index) {
		return this.inventory[index + this.start];
	}
	
	public override @safe void opIndexAssign(Slot slot, size_t index) {
		this.inventory[index + this.start] = slot;
	}
	
	public override pure nothrow @property @safe @nogc size_t length() {
		return this.end - this.start;
	}
	
}

unittest {
	
	import selery.item.items : Items;
	
	auto inventory = new Inventory(10);
	auto range = inventory[2..4];
	assert(range.length == 2);
	
	inventory[2] = Slot(new Items.Cookie(), 12);
	assert(inventory[2] == range[0]);
	assert(inventory[2..4] == range);
	
}

/**
 * Group of inventories that acts as one.
 * 
 * This class can be used to change the operation order in a normal
 * inventory.
 * Example:
 * ---
 * auto inv = new Inventory(4);
 * auto ig = new InventoryGroup(inv[2..$], inv[0..2]);
 * ig += new Items.Apple();
 * assert(inv == [Slot(null), Slot(null), Slot(new Items.Apple()), Slot(null)]);
 * ---
 */
class InventoryGroup : Inventory {
	
	private Inventory[] inventories;
	private size_t n_length;
	
	public this(Inventory[] inventories ...) {
		super(0);
		this.inventories = inventories;
		foreach(Inventory inventory ; inventories) {
			this.n_length += inventory.length;
		}
	}
	
	public override @safe Slot[] opIndex() {
		Slot[] ret;
		ret.reserve(this.length);
		foreach(Inventory inventory ; this.inventories) {
			ret ~= inventory[];
		}
		return ret;
	}
	
	public override @safe Slot opIndex(size_t index) {
		size_t i = index;
		foreach(Inventory inventory ; this.inventories) {
			if(i < inventory.length) {
				return inventory[i];
			} else {
				i -= inventory.length;
			}
		}
		throw new InventoryRangeError(index, this);
	}
	
	public override @safe void opIndexAssign(Slot slot, size_t index) {
		size_t i = index;
		foreach(Inventory inventory ; this.inventories) {
			if(i < inventory.length) {
				return inventory[i] = slot;
			} else {
				i -= inventory.length;
			}
		}
		throw new InventoryRangeError(index, this);
	}
	
	public override pure nothrow @property @safe @nogc size_t length() {
		return this.n_length;
	}
	
}

unittest {
	
	import selery.item.items : Items;
	
	auto inventory = new Inventory(10);
	auto igroup = new InventoryGroup(inventory[4..$], inventory[0..4]);
	
	igroup += Slot(new Items.Cookie(), 1);
	assert(inventory[0].empty && inventory[4] == Slot(new Items.Cookie(), 1));
	
}

/**
 * Special inventory that notifies the holder when a slot
 * is updated.
 */
class NotifiedInventory : Inventory {
	
	protected InventoryHolder holder;
	
	public @safe this(InventoryHolder holder, size_t slots) {
		super(slots);
		this.holder = holder;
	}
	
	public override @safe void opIndexAssign(Slot slot, size_t index) {
		super.opIndexAssign(slot, index);
		this.holder.slotUpdated(index);
	}
	
}

/**
 * Inventory held by an entity that also contains slots
 * for armour and item's holding.
 */
class PlayerInventory : Inventory {
	
	public static immutable ubyte HELD = 1u;
	public static immutable ubyte INVENTORY = 2u;
	public static immutable ubyte ARMOR = 4u;
	public static immutable ubyte ALL = HELD | INVENTORY | ARMOR;
	
	public ubyte update = ALL;
	public bool[] slot_updates;
	public ubyte update_viewers = 0;
	
	protected Human holder;
	
	private Hotbar m_hotbar = Hotbar(9);
	private uint m_selected = 0;
	
	public @safe this(Human holder) {
		super(36 + 4);
		this.slot_updates.length = 36;
		this.holder = holder;
		this.reset();
	}
	
	public final @safe @nogc void reset() {
		foreach(uint i ; 0..9) {
			this.m_hotbar[i] = i;
		}
		this.m_selected = 0;
	}
	
	public @property @safe @nogc ref Hotbar hotbar() {
		return this.m_hotbar;
	}
	
	public @property @safe @nogc uint selected() {
		return this.m_selected;
	}
	
	public @property @safe @nogc uint selected(uint selected) {
		this.update_viewers |= HELD;
		return this.m_selected = selected;
	}
	
	/**
	 * Gets the slot the entity has in its hand.
	 * Example:
	 * ---
	 * if(player.inventory.held == Items.SWORD) {
	 *    player.sendMessage("Attack!");
	 * }
	 * ---
	 */
	public @property @safe Slot held() {
		return this.hotbar[this.selected] == 255 ? Slot(null) : this[this.hotbar[this.selected]];
	}
	
	/**
	 * Sets the slot the entity has in its hand.
	 * Example:
	 * ---
	 * if(player.inventory.held.empty) {
	 *    player.inventory.held = new Items.Apple();
	 *    player.sendMessage("Hey, hold this");
	 * }
	 * ---
	 */
	public @property @safe Slot held(Slot item) {
		this[this.hotbar[this.selected] - 9] = item;
		//this.update |= HELD;
		this.update_viewers |= HELD;
		return this.held;
	}
	
	// called when a player is using this item but it didn't send any MobEquipment packet (because it's a shitty buggy game)
	public bool heldFromHotbar(Slot item) {
		if(item == this.held) return true;
		foreach(size_t index ; 0..this.hotbar.length) {
			Slot cmp = super.opIndex(this.hotbar[index] - 9);
			if(!cmp.empty && cmp == item || cmp.empty && item.empty) {
				this.selected = to!uint(index);
				return true;
			}
		}
		return false;
	}
	
	public @safe void resetSlotUpdates() {
		foreach(size_t index ; 0..this.slot_updates.length) {
			this.slot_updates[index] = false;
		}
	}
	
	alias opIndex = super.opIndex;
	
	public override @safe Slot opIndex(size_t index) {
		auto test = this[][index]; // test access violation
		return super.opIndex(index);
	}
	
	public override @safe void opIndexAssign(Slot item, size_t index) {
		//this.update |= INVENTORY;
		if(index < this.slot_updates.length) this.slot_updates[index] = true;
		if(index == this.selected) this.update_viewers |= HELD;
		auto test = this[][index]; // test access violation
		super.opIndexAssign(item, index);
	}
	
	/**
	 * Sets a slot using a string, creating the Item object from
	 * the holder's world's items.
	 * 
	 * See the superclass's opIndexAssign documentation for more
	 * informations about this function.
	 * Example:
	 * ---
	 * player.inventory[1] = Items.APPLE;
	 * assert(player.inventory[1] == Slot(new Items.Apple());
	 * ---
	 */
	public void opIndexAssign(item_t item, size_t index) {
		this[index] = this.holder.world.items.get(item);
	}
	
	public override @property @safe @nogc size_t length() {
		return super.length - 4;
	}
	
	/*public override @property @safe size_t length(size_t length) {
		this.slot_updates.length = length;
		return super.length(length + 4);
	}*/
	
	public @property @safe Slot helmet() {
		return super[super.length-4];
	}
	
	public @property @safe Slot helmet(Slot helmet) {
		super.opIndexAssign(helmet, super.length-4);
		this.update |= ARMOR;
		this.update_viewers |= ARMOR;
		return this.helmet;
	}
	
	public @property @safe Slot chestplate() {
		return super[super.length-3];
	}
	
	public @property @safe Slot chestplate(Slot chestplate) {
		super.opIndexAssign(chestplate, super.length-3);
		this.update |= ARMOR;
		this.update_viewers |= ARMOR;
		return this.chestplate;
	}
	
	public @property @safe Slot leggings() {
		return super[super.length-2];
	}
	
	public @property @safe Slot leggings(Slot leggings) {
		super.opIndexAssign(leggings, super.length-2);
		this.update |= ARMOR;
		this.update_viewers |= ARMOR;
		return this.leggings;
	}
	
	public @property @safe Slot boots() {
		return super[super.length-1];
	}
	
	public @property @safe Slot boots(Slot boots) {
		super.opIndexAssign(boots, super.length-1);
		this.update |= ARMOR;
		this.update_viewers |= ARMOR;
		return this.boots;
	}
	
	alias cap = this.helmet;
	alias tunic = this.chestplate;
	alias pants = this.leggings;
	
	public @property @safe Inventory armor() {
		return super.opIndex(Slice(super.length-4, super.length));
	}
	
	public @property @safe Slot armor(uint type) {
		return super.opIndex(this.length + type);
	}
	
	public @property @safe Slot[] armor(uint type, Slot armor) {
		super.opIndexAssign(armor, this.length + type);
		this.update |= ARMOR;
		this.update_viewers |= ARMOR;
		return cast(Slot[])this.armor;
	}
	
	public @property @safe bool hasArmor() {
		return !this.helmet.empty || !this.chestplate.empty || !this.leggings.empty || !this.boots.empty;
	}
	
	public @property @trusted uint protection() {
		uint ret = 0;
		foreach(Slot slot ; this.armor) {
			if(!slot.empty && cast(Armor)(cast(Object)slot.item)) ret += (cast(Armor)(cast(Object)slot.item)).protection;
		}
		return ret;
	}
	
	public @property @safe Slot[] full() {
		return super[];
	}
	
	private struct Hotbar {
		
		private uint[] m_hotbar;
		
		public @safe this(size_t length) {
			this.m_hotbar.length = length;
		}
		
		public @property @safe @nogc size_t length() {
			return this.m_hotbar.length;
		}
		
		public @property @safe @nogc size_t opDollar() {
			return this.length;
		}
		
		public @safe @nogc uint opIndex(size_t index) {
			return this.m_hotbar[index];
		}
		
		public @safe @nogc void opIndexAssign(uint value, size_t index) {
			this.m_hotbar[index] = value;
		}
		
		public @property @safe @nogc uint[] hotbar() {
			return this.m_hotbar;
		}
		
		alias hotbar this;
		
	}
	
}

interface InventoryHolder {
	
	public @trusted void slotUpdated(size_t slot);
	
}
