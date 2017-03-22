/*
 * Copyright (c) 2016-2017 SEL
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
/**
 * "Blocks are the basic units of structure in Minecraft. Together, they build up the in-game environment and can be mined
 * and utilized in various fashions." - from <a href="http://minecraft.gamepedia.com/Block" target="_blank">Minecraft Wiki</a>
 * 
 * License: <a href="http://www.gnu.org/licenses/lgpl-3.0.html" target="_blank">GNU General Lesser Public License v3</a>
 */
module sel.block.block;

import std.algorithm : canFind;
import std.conv : to;
import std.math : ceil;
import std.string : split, join, capitalize;

import common.sel;

import sel.player : Player;
import sel.entity.entity : Entity;
import sel.event.event : EventListener;
import sel.event.world.world : WorldEvent;
import sel.item.enchanting : Enchantments;
import sel.item.item;
import sel.item.slot : Slot;
import sel.item.tool : Tools;
import sel.math.vector : BlockAxis, BlockPosition, entityPosition;
import sel.world.chunk : Chunk;
import sel.world.world : World;

public import sel.math.vector : Faces = Face;

static import sul.blocks;

enum Update {

	placed,
	nearestChanged,

}

enum Remove {

	broken,
	creativeBroken,
	exploded,
	burnt,
	enderDragon,
	unset,

}

/**
 * Base class for every block.
 */
abstract class Block {

	/**
	 * Gets the block's SEL id.
	 */
	public abstract pure nothrow @property @safe @nogc block_t id();

	public abstract pure nothrow @property @safe @nogc bool minecraft();

	public abstract pure nothrow @property @safe @nogc bool pocket();

	/**
	 * Gets the block's ids for Minecraft and
	 * Minecraft: Pocket Edition.
	 * Example:
	 * ---
	 * if(block.ids.pe == block.ids.pc) {
	 *    d("This block has the same ids");
	 * }
	 * ---
	 */
	public abstract pure nothrow @property @safe @nogc bytegroup ids();

	/**
	 * Gets the block's metas for Minecraft and
	 * Minecraft: Pocket Edition.
	 * Example:
	 * ---
	 * if(block.metas.pe != block.metas.pc) {
	 *    d("This block has different metas");
	 * }
	 * ---
	 */
	public abstract pure nothrow @property @safe @nogc bytegroup metas();

	/**
	 * Indicates whether a block is solid (can sustain another block or
	 * an entity) or not.
	 */
	public pure nothrow @property @safe @nogc bool solid() {
		return true;
	}

	/**
	 * Indicates whether the block is a fluid.
	 */
	public pure nothrow @property @safe @nogc bool fluid() {
		return false;
	}

	/**
	 * Indicates the block's hardness, used to calculate the mining
	 * time of the block's material.
	 */
	public abstract pure nothrow @property @safe @nogc double hardness();

	/**
	 * Indicates whether the block can be mined.
	 */
	public abstract pure nothrow @property @safe @nogc bool indestructible();
	
	/**
	 * Indicates whether the block can be mined or it's destroyed
	 * simply by a left-click.
	 */
	public abstract pure nothrow @property @safe @nogc bool instantBreaking();

	/**
	 * Gets the blast resistance, used for calculate
	 * the resistance at the explosion of solid blocks.
	 */
	public abstract pure nothrow @property @safe @nogc double blastResistance();

	/**
	 * Gets the block's opacity, in a range from 0 to 15, where 0 means
	 * that the light propagates like in the air and 15 means that the
	 * light is totally blocked.
	 */
	public abstract pure nothrow @property @safe @nogc ubyte opacity();

	/**
	 * Indicates the level of light emitted by the block in a range from
	 * 0 to 15.
	 */
	public abstract pure nothrow @property @safe @nogc ubyte luminance();

	/**
	 * Boolean value indicating whether or not the block is replaced
	 * when touched with a placeable item.
	 */
	public abstract pure nothrow @property @safe @nogc bool replaceable();

	/**
	 * Boolean value indicating whether or not the block can be burnt.
	 */
	public abstract pure nothrow @property @safe @nogc bool flammable();

	public abstract pure nothrow @property @safe @nogc ubyte encouragement();

	public abstract pure nothrow @property @safe @nogc ubyte flammability();

	/**
	 * Indicates whether falling on this block causes damage or not.
	 */
	public pure nothrow @property @safe @nogc bool noFallDamage() {
		return this.fluid;
	}

	/**
	 * Indicates whether the block has a bounding box which entities
	 * can collide with, even if the block is not solid.
	 */
	public abstract pure nothrow @property @safe @nogc bool hasBoundingBox();

	/**
	 * If hasBoundingBox is true, returns the bounding box of the block
	 * as an Axis instance.
	 * Values are from 0 to 1
	 */
	public final @property @safe @nogc BlockAxis box() {
		return null;
	}

	public abstract pure nothrow @property @safe @nogc bool fullUpperShape();

	public void onCollide(World world, Entity entity) {}

	/**
	 * Get the dropped items as a slot array.
	 * Params:
	 * 		player = the player who broke the block, can be null (e.g. explosion, fire...)
	 * 		item = item used to break the block, is null if player is null or the player broke the block with his hand
	 * Returns: a slot array with the dropped items
	 */
	public Slot[] drops(World world, Player player, Item item) {
		return [];
	}

	/**
	 * Get the amount of dropped xp when the block is broken
	 * Params:
	 * 		player = the player who broke the block, can be null (e.g. explosion, fire...)
	 * 		item = item used to break the block, is null if player is null or the player broke the block with his hand
	 * Returns: an integer, indicating the amount of xp that will be spawned
	 */
	public uint xp(World world, Player player, Item item) {
		return 0;
	}

	public tick_t miningTime(Player player, Item item) {
		return 0;
	}

	/**
	 * Function called when a player right-click the block.
	 * Blocks like tile should use this function for handle
	 * the interaction.
	 * N.B. That this function will no be called if the player shifts
	 *	 while performing the right-click/screen-tap.
	 * Params:
	 * 		player = the player who tapped the block
	 * 		item = the item used, is the same as player.inventory.held
	 * 		face = the face tapped
	 * Returns: false is a block should be placed, true otherwise
	 */
	public bool onInteract(Player player, Item item, BlockPosition position, ubyte face) {
		return false;
	}

	/**
	 * Called when an entity is inside the block (or part of it).
	 */
	public void onEntityInside(Entity entity, BlockPosition position, bool headInside) {}

	/**
	 * Called when an entity falls on walks on the block.
	 */
	public void onEntityStep(Entity entity, BlockPosition position, float fallDistance) {}

	/**
	 * Called when an entity collides with the block's side (except top).
	 */
	public void onEntityCollide(Entity entity, BlockPosition position) {}

	/**
	 * Boolean value indicating whether or not the block can receive a
	 * random tick. This property is only requested when the block is placed.
	 */
	public pure nothrow @property @safe @nogc bool doRandomTick() {
		return false;
	}

	/**
	 * If the property doRandomTick is true, this function could be called
	 * undefined times duraing the chunk's random ticks.
	 */
	public void onRandomTick(World world, BlockPosition position) {}

	/** 
	 * Function called when the block is receives an update.
	 * Redstone mechanism should be handled from this function.
	 */
	public void onUpdated(World world, BlockPosition position, Update type) {}

	public void onRemoved(World world, BlockPosition position, Remove type) {}

	/**
	 * Function called by the world after a requets made
	 * by the block using World.scheduleBlockUpdate if
	 * the rule in the world is activated.
	 */
	public void onScheduledUpdate(World world, BlockPosition position) {}

	/**
	 * Boolean value indicating whether or not the upper
	 * block is air or isn't solid.
	 * Params:
	 * 		checkFluid = boolean value indicating whether or not the fluid should be considered as a solid block
	 * Example:
	 * ---
	 * // farmlands become when dirt when they can't breathe
	 * world[0, 0, 0] = Blocks.FARMLAND;
	 * 
	 * world[0, 1, 0] = Blocks.BEETROOT_BLOCK;
	 * assert(world[0, 0, 0] == Blocks.FARMLAND);
	 * 
	 * world[0, 1, 0] = Blocks.DIRT;
	 * assert(world[0, 0, 0] != Blocks.FARMLAND);
	 * ---
	 */
	public final bool breathe(World world, BlockPosition position, bool checkFluid=true) {
		Block up = world[position + [0, 1, 0]];
		return up.blastResistance == 0 && (!checkFluid || !up.fluid);
	}

	/**
	 * Compare the block names.
	 * Example:
	 * ---
	 * // one block
	 * assert(new Blocks.Dirt() == Blocks.dirt);
	 * 
	 * // a group of blocks
	 * assert(new Blocks.Grass() == [Blocks.dirt, Blocks.grass, Blocks.grassPath]);
	 * ---
	 */
	public bool opEquals(block_t block) {
		return this.id == block;
	}

	/// ditto
	public bool opEquals(block_t[] blocks) {
		return blocks.canFind(this.id);
	}

	/// ditto
	public bool opEquals(Block[] blocks) {
		foreach(block ; blocks) {
			if(this.opEquals(block)) return true;
		}
		return false;
	}

	/// ditto
	public bool opEquals(Block* block) {
		if(block) return this.opEquals(*block);
		else return this.id == 0;
	}

	public override bool opEquals(Object o) {
		return cast(Block)o && this.opEquals((cast(Block)o).id);
	}

	public override abstract string toString();

}

class SimpleBlock(sul.blocks.Block sb) : Block {

	mixin Instance;

	private enum __ids = bytegroup(sb.pocket ? sb.pocket.id : 248 + (sb.minecraft.id & 1), sb.minecraft ? sb.minecraft.id : 0);

	private enum __metas = bytegroup(sb.pocket ? sb.pocket.meta : 0, sb.minecraft ? sb.minecraft.meta : 0);

	private enum __to_string = (string[] data){ foreach(ref d;data){d=capitalize(d);} return data.join(""); }(sb.name.split(" ")) ~ "(id: " ~ to!string(sb.id) ~ ", " ~ (sb.minecraft ? "minecraft(" ~ to!string(sb.minecraft.id) ~ (sb.minecraft.meta ? ":" ~ to!string(sb.minecraft.meta) : "") ~ ")" ~ (sb.pocket ? ", " : "") : "") ~ (sb.pocket ? "pocket(" ~ to!string(sb.pocket.id) ~ (sb.pocket.meta ? ":" ~ to!string(sb.pocket.meta) : "") ~ ")" : "") ~ ")";

	public final override pure nothrow @property @safe @nogc ushort id() {
		return sb.id;
	}

	public final override pure nothrow @property @safe @nogc bool minecraft() {
		return sb.minecraft.exists;
	}

	public final override pure nothrow @property @safe @nogc bool pocket() {
		return sb.pocket.exists;
	}

	public final override pure nothrow @property @safe @nogc bytegroup ids() {
		return __ids;
	}

	public final override pure nothrow @property @safe @nogc bytegroup metas() {
		return __metas;
	}

	public final override pure nothrow @property @safe @nogc bool solid() {
		static if(sb.solid && sb.boundingBox) {
			return true;
		} else {
			return false;
		}
	}

	public final override pure nothrow @property @safe @nogc double hardness() {
		return sb.hardness;
	}

	public final override pure nothrow @property @safe @nogc bool indestructible() {
		static if(sb.hardness < 0) {
			return true;
		} else {
			return false;
		}
	}

	public final override pure nothrow @property @safe @nogc bool instantBreaking() {
		static if(sb.hardness == 0) {
			return true;
		} else {
			return false;
		}
	}

	public final override pure nothrow @property @safe @nogc double blastResistance() {
		return sb.blastResistance;
	}

	public final override pure nothrow @property @safe @nogc ubyte opacity() {
		return sb.opacity;
	}

	public final override pure nothrow @property @safe @nogc ubyte luminance() {
		return sb.luminance;
	}

	public final override pure nothrow @property @safe @nogc bool replaceable() {
		return sb.replaceable;
	}

	public final override pure nothrow @property @safe @nogc bool flammable() {
		static if(sb.encouragement > 0) {
			return true;
		} else {
			return false;
		}
	}

	public final override pure nothrow @property @safe @nogc ubyte encouragement() {
		return sb.encouragement;
	}

	public final override pure nothrow @property @safe @nogc ubyte flammability() {
		return sb.flammability;
	}

	public final override pure nothrow @property @safe @nogc bool hasBoundingBox() {
		static if(sb.boundingBox.exists) {
			return true;
		} else {
			return false;
		}
	}

	static if(sb.boundingBox.exists) {

		private BoundingBox n_box = new BlockBoundingBox();

		public override pure nothrow @property @safe @nogc BoundingBox box() {
			return this.n_box;
		}

	}

	public final override pure nothrow @property @safe @nogc bool fullUpperShape() {
		static if(sb.boundingBox && sb.boundingBox.min.x == 0 && sb.boundingBox.min.z == 0 && sb.boundingBox.max.x == 16 && sb.boundingBox.max.y == 16 && sb.boundingBox.max.z == 16) {
			return true;
		} else {
			return false;
		}
	}

	public override string toString() {
		return __to_string;
	}

}

mixin template Instance() {

	private static Block n_instance;

	private static Block* function() instanceImpl = {
		n_instance = new typeof(this)();
		instanceImpl = {
			return &n_instance;
		};
		return instanceImpl();
	};

	public static @property Block* instance() {
		return instanceImpl();
	}

}

public bool compareBlock(block_t[] blocks)(Block block) {
	return compareBlock!blocks(block.id);
}

public bool compareBlock(block_t[] blocks)(block_t block) {
	//TODO better compile time cmp
	return blocks.canFind(block);
}

private bool compareBlockImpl(block_t[] blocks)(block_t block) {
	static if(blocks.length == 1) return block == blocks[0];
	else static if(blocks.length == 2) return block == blocks[0] || block == blocks[1];
	else return block >= blocks[0] && block <= blocks[$-1];
}

/**
 * Placed block in a world, used when a position is needed
 * but the block can be null.
 */
struct PlacedBlock {

	private BlockPosition n_position;
	private Block n_block;

	public @safe @nogc this(BlockPosition position, Block block) {
		this.n_position = position;
		this.n_block = block;
	}

	public pure nothrow @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

	public pure nothrow @property @safe @nogc Block block() {
		return this.n_block;
	}

	alias block this;

}

public @property @safe int blockInto(float value) {
	if(value < 0) return (-value).ceil.to!int * -1;
	else return value.to!int;
}
