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
module sel.item.miscellaneous;

import std.conv : to, ConvException;
import std.traits : isIntegral;

import common.sel;

import sel.player : Player;
import sel.block.block : Blocks, Block;
import sel.item.item : SimpleItem;
import sel.item.slot : Slot;
import sel.nbt.tags;
import sel.math.vector : BlockPosition, face, entityPosition;

static import sul.items;

class BucketItem(sul.items.Item si, item_t[item_t] pickups) : SimpleItem!(si) {

	alias sul = si;

	public this(F...)(F args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}

	public override bool onPlaced(Player player, BlockPosition position, uint tface) {
		auto pos = position.face(tface);
		auto pick = player.world[pos].id in pickups;
		if(pick) {
			player.world[pos] = Blocks.air;
			Slot slot = Slot(player.world.items.get(*pick), 1);
			if(player.inventory.held.count == 1) player.inventory.held = slot;
			else if(!player.inventory.add(slot).empty) player.drop(slot);
			return true;
		} else {
			return false;
		}
	}

	alias slot this;

}

class FilledBucketItem(sul.items.Item si, block_t place, item_t residue) : SimpleItem!(si) {

	alias sul = si;

	public this(F...)(F args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override bool onPlaced(Player player, BlockPosition position, uint tface) {
		Block rep = player.world[position];
		if(!rep.replaceable) {
			position = face(position, tface);
			rep = player.world[position];
			if(rep != Blocks.air) return false;
		}
		player.world[position] = place;
		player.inventory.held = Slot(player.world.items.get(residue), 1);
		return true;
	}

	alias slot this;

}

class MapItem(sul.items.Item si) : SimpleItem!(si) {

	alias sul = si;

	private ushort m_map_id;

	public this(E...)(E args) {
		static if(E.length > 0 && isIntegral!(E[0])) {
			static if(E.length > 1) super(args[1..$]);
			this.mapId = args[0] & ushort.max;
		} else {
			super(args);
		}
	}

	public final override pure nothrow @property @safe @nogc shortgroup metas() {
		return shortgroup(0, this.mapId);
	}

	public pure nothrow @property @safe @nogc ushort mapId() {
		return this.m_map_id;
	}

	public @property @safe ushort mapId(ushort mapId) {
		if(this.m_pe_tag is null) this.m_pe_tag = new Compound("");
		this.m_pe_tag["map_uuid"] = to!string(mapId);
		return this.m_map_id = mapId;
	}

	public override void parsePocketCompound(Compound compound) {
		super.parsePocketCompound(compound);
		if(compound.has!Compound("")) compound = compound.get!Compound("");
		if(compound.has!String("map_uuid")) {
			try {
				this.mapId = to!ushort(compound.get!String("map_uuid").value);
			} catch(ConvException e) {}
		}
	}

	alias slot this;

}
