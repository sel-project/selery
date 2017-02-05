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
import sel.item.flags;
import sel.item.slot : Slot;
import sel.nbt.tags;
import sel.math.vector : BlockPosition, face, entityPosition;

class BucketItem(string name, shortgroup ids, shortgroup metas, ubyte stack, string[string] pickups) : SimpleItem!(name, ids, metas, stack) {

	public this(F...)(F args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}

	public override bool onPlaced(Player player, BlockPosition position, uint tface) {
		Block target = player.world[position.face(tface)];
		if(target !is null && target.directname in pickups && target.directmetas.pe == 0) {
			Slot slot = Slot(player.world.items.get(pickups[target.directname]), 1);
			target = Blocks.AIR;
			if(player.inventory.held.count == 1) player.inventory.held = slot;
			else if(!player.inventory.add(slot).empty) player.drop(slot);
			return true;
		} else {
			return false;
		}
	}

}

class FilledBucketItem(string name, shortgroup ids, shortgroup metas, ubyte stack, string place_block, string residue) : SimpleItem!(name, ids, metas, stack) {

	public this(F...)(F args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override bool onPlaced(Player player, BlockPosition position, uint tface) {
		Block rep = player.world[position];
		if(rep is null || !rep.replaceable) {
			position = face(position, tface);
			rep = player.world[position];
		}
		if(rep !is null && rep.fluid) return false;
		player.world[position] = place_block;
		player.inventory.held = player.world.items.has(residue) ? Slot(player.world.items.get(residue), 1) : Slot(null);
		return true;
	}

}

class MapItem(string name, shortgroup ids) : SimpleItem!(name, ids, META!0) {

	private ushort m_map_id;

	public this(F...)(F args) {
		static if(F.length > 0 && isIntegral!(F[0])) {
			static if(F.length > 1) super(args[1..$]);
			this.mapId = args[0] & ushort.max;
		} else {
			super(args);
		}
	}

	public final override pure nothrow @property shortgroup metas() {
		return shortgroup(0, this.mapId);
	}

	public pure nothrow @property @safe @nogc ushort mapId() {
		return this.m_map_id;
	}

	public @property @safe ushort mapId(ushort mapId) {
		if(this.m_pe_tag is null) this.m_pe_tag = new Compound("");
		this.m_pe_tag["map_uuid"] = new String(to!string(mapId));
		return this.m_map_id = mapId;
	}

	public override @property @safe Compound petag(Compound tag) {
		super.petag = tag;
		if(tag !is null) {
			if(tag.has!Compound("")) tag = tag.get!Compound("");
			if(tag.has!String("map_uuid")) {
				try {
					this.mapId = to!ushort(tag.get!String("map_uuid").value);
				} catch(ConvException e) {}
			}
		}
		return super.petag;
	}

}
