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
 * <i>"Blocks are the basic units of structure in Minecraft. Together, they build up the in-game environment and can be mined
 * and utilized in various fashions." - from <a href="http://minecraft.gamepedia.com/Block" target="_blank">Minecraft Wiki</a></i>
 * 
 * In SEL every blocks contains informations
 * License: <a href="http://www.gnu.org/licenses/lgpl-3.0.html" target="_blank">GNU General Lesser Public License v3</a>
 */
module sel.block.block;

import std.algorithm : canFind;
import std.conv : to, ConvException;
import std.math : ceil;
import std.string : split;
import std.typecons : Tuple;
import std.typetuple;

import common.sel;

import sel.player : Player;
import sel.block.farming;
import sel.block.flags;
import sel.block.fluid;
import sel.block.miscellaneous;
import sel.block.solid;
import sel.block.tile;
import sel.entity.projectile : FallingBlock;
import sel.event.event : EventListener;
import sel.event.world.world : WorldEvent;
import sel.item.enchanting : Enchantments;
import sel.item.item;
import sel.item.slot : Slot;
import sel.item.tool : Tool;
import sel.math.vector : BlockAxis, BlockPosition, entityPosition;
import sel.util : staticInstanceIndex;
import sel.world.chunk : Chunk;
import sel.world.world : World;

public import sel.math.vector : Faces = Face;

/**
 * Informations about a block or a group.
 * Only the immutable one is used by the software
 * for memory and security reasons.
 * Params:
 * 		id = the SEL's id, in range 0..4096
 * 		ids = the Minecraft and Minecraft: Pocket Edition ids, in range 0..256
 * 		metas = the Minecraft and Minecraft: Pocket Edition metas, in range 0..256
 */
alias MutableBlockData = Tuple!(ushort, "id", bytegroup, "ids", bytegroup, "metas");

/// ditto
alias BlockData = immutable(MutableBlockData);

/// ditto
alias BlockDataArray = immutable(immutable(MutableBlockData)[]);

/** 
 * Identifiers as BlockData and BlockDataArray of every block in 
 * the vanilla game.
 * Example:
 * ---
 * // set a block using a string as identifier. The identifier
 * // can point to different block classes in different worlds
 * world[0, 0, 0] = Blocks.DIRT;
 * 
 * // blocks of the same type can be compared with their whole group
 * auto birch = new Blocks.BirchWoodenPlanks();
 * auto spruce = new Blocks.SpruceWoodenPlanks();
 * assert(birch == Blocks.WOODEN_PLANKS);
 * assert(spruce == Blocks.WOODEN_PLANKS);
 * assert(birch == Blocks.BIRCH_WOODEN_PLANKS);
 * assert(spruce != Blocks.BIRCH_WOODEN_PLANKS);
 * ---
 */
public class Blocks {

	private Block[ushort] singletones;
	private Block*[ushort] pcs, pes;

	public @safe this() {
		foreach(a ; __traits(allMembers, Blocks)) {
			static if(mixin("is(" ~ a ~ " : Block)")) {
				mixin("this.register(new " ~ a ~ "());");
			}
		}
	}

	public @safe Block* register(Block block) {
		singletones[block.id] = block;
		auto ptr = block.id in singletones;
		pes[block.ids.pe | block.metas.pe << 8] = ptr;
		pcs[block.ids.pc | block.metas.pc << 8] = ptr;
		return ptr;
	}

	public @safe Block* opIndex(ushort index) {
		return &singletones[index];
	}

	public @safe Block* opBinaryRight(string op)(ushort index) if(op == "in") {
		return index in singletones;
	}

	public @safe Block* frompe(ubyte id, ubyte meta) {
		return this.pes[id | meta << 8];
	}

	public @safe Block* frompc(ubyte id, ubyte meta) {
		return this.pcs[id | meta << 8];
	}

	public static BlockData AIR = BlockData(0, ID!0, META!0);
	public alias Air = SimpleBlock!(AIR, SHAPELESS);

	public static BlockData STONE = BlockData(1, ID!1, META!0);
	public alias Stone = MineableBlock!(STONE, SOLID!30, HARDNESS!1.5, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.COBBLESTONE, SILK_TOUCH, Items.STONE);

	public static BlockData GRANITE = BlockData(2, ID!1, META!1);
	public alias Granite = MineableBlock!(GRANITE, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.GRANITE);

	public static BlockData POLISHED_GRANITE = BlockData(3, ID!1, META!1);
	public alias PolishedGranite = MineableBlock!(POLISHED_GRANITE, ID!1, META!2, SOLID!30, TOOL!(Tool.PICKAXE,Tool. WOODEN), Items.POLISHED_GRANITE);

	public static BlockData DIORITE = BlockData(4, ID!1, META!3);
	public alias Diorite = MineableBlock!(DIORITE, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.DIORITE);

	public static BlockData POLISHED_DIORITE = BlockData(5, ID!1, META!3);
	public alias PolishedDiorite = MineableBlock!(POLISHED_DIORITE, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.POLISHED_DIORITE);

	public static BlockData ANDESITE = BlockData(6, ID!1, META!5);
	public alias Andesite = MineableBlock!(ANDESITE, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.ANDESITE);

	public static BlockData POLISHED_ANDESITE = BlockData(7, ID!1, META!6);
	public alias PolishedAndesite = MineableBlock!(POLISHED_ANDESITE, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.POLISHED_ANDESITE);

	public static BlockData GRASS = BlockData(8, ID!2, META!0);
	public alias Grass = SimpleSpreadingBlock!(GRASS, [Blocks.DIRT], 1, 1, 2, Blocks.DIRT, SOLID!3, Items.DIRT, SILK_TOUCH, Items.GRASS);

	public static BlockData DIRT = BlockData(9, ID!3, META!0);
	public alias Dirt = MineableBlock!(DIRT, SOLID!3, Items.DIRT);

	public static BlockData COBBLESTONE = BlockData(10, ID!4, META!0);
	public alias Cobblestone = MineableBlock!(COBBLESTONE, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.COBBLESTONE);

	public static BlockData BEDROCK = BlockData(11, ID!7, META!0);
	public alias Bedrock = SimpleBlock!(BEDROCK, SOLID!(double.infinity));

	public static BlockDataArray WOODEN_PLANKS = [OAK_WOODEN_PLANKS, SPRUCE_WOODEN_PLANKS, BIRCH_WOODEN_PLANKS, JUNGLE_WOODEN_PLANKS, ACACIA_WOODEN_PLANKS, DARK_OAK_WOODEN_PLANKS];
	private alias WoodenPlanks(BlockData blockdata, string drop=name) = MineableBlock!(blockdata, SOLID!15, FLAMMABLE, drop);

	public static BlockData OAK_WOODEN_PLANKS = BlockData(12, ID!5, META!0);
	public alias OakWoodenPlanks = WoodenPlanks!(OAK_WOODEN_PLANKS, Items.OAK_WOODEN_PLANKS);

	public static BlockData SPRUCE_WOODEN_PLANKS = BlockData(13, ID!5, META!1);
	public alias SpruceWoodenPlanks = WoodenPlanks!(SPRUCE_WOODEN_PLANKS, Items.SPRUCE_WOODEN_PLANKS);

	public static BlockData BIRCH_WOODEN_PLANKS = BlockData(14, ID!5, META!2);
	public alias BirchWoodenPlanks = WoodenPlanks!(BIRCH_WOODEN_PLANKS, Items.BIRCH_WOODEN_PLANKS);

	public static BlockData JUNGLE_WOODEN_PLANKS = BlockData(15, ID!5, META!3);
	public alias JungleWoodenPlanks = WoodenPlanks!(JUNGLE_WOODEN_PLANKS, Items.JUNGLE_WOODEN_PLANKS);

	public static BlockData ACACIA_WOODEN_PLANKS = BlockData(16, ID!5, META!4);
	public alias AcaciaWooodenPlanks = WoodenPlanks!(ACACIA_WOODEN_PLANKS, Items.ACACIA_WOODEN_PLANKS);

	public static BlockData DARK_OAK_WOODEN_PLANKS = BlockData(17, ID!5, META!5);
	public alias DarkOakWoodenPlanks = WoodenPlanks!(DARK_OAK_WOODEN_PLANKS, Items.DARK_OAK_WOODEN_PLANKS);

	public static BlockDataArray SAPLING = [OAK_SAPLING, SPRUCE_SAPLING, BIRCH_SAPLING, JUNGLE_SAPLING, ACACIA_SAPLING, DARK_OAK_SAPLING];
	private alias Sapling(BlockData blockdata, string drop) = MineableBlock!(blockdata, FLAMMABLE, SHAPELESS, drop);

	public static BlockData OAK_SAPLING = BlockData(18, ID!6, META!0);
	public alias OakSapling = Sapling!(OAK_SAPLING, Items.OAK_SAPLING);

	public static BlockData SPRUCE_SAPLING = BlockData(19, ID!6, META!1);
	public alias SpruceSapling = Sapling!(SPRUCE_SAPLING, Items.SPRUCE_SAPLING);

	public static BlockData BIRCH_SAPLING = BlockData(20, ID!6, META!2);
	public alias BirchSapling = Sapling!(BIRCH_SAPLING, Items.BIRCH_SAPLING);

	public static BlockData JUNGLE_SAPLING = BlockData(21, ID!6, META!3);
	public alias JungleSapling = Sapling!(JUNGLE_SAPLING, Items.JUNGLE_SAPLING);

	public static BlockData ACACIA_SAPLING = BlockData(22, ID!6, META!4);
	public alias AcaciaSapling = Sapling!(ACACIA_SAPLING, Items.ACACIA_SAPLING);

	public static BlockData DARK_OAK_SAPLING = BlockData(23, ID!6, META!5);
	public alias DarkOakSapling = Sapling!(DARK_OAK_SAPLING, Items.DARK_OAK_SAPLING);

	/*public static BlockData WATER = [FLOWING_WATER, STILL_WATER];

	public  static BlockData FLOWING_WATER = BlockData(24, ID!8, META!0);
	public alias FlowingWater = FluidBlock!(FLOWING_WATER, ID!8, 0, 7, 1, 4);
	
	public  static BlockData STILL_WATER = "stillWater";
	public alias StillWater = FluidBlock!(STILL_WATER, ID!9);

	public static static BlockData LAVA = [FLOWING_LAVA, STILL_LAVA];

	public  static BlockData FLOWING_LAVA = "lava";
	public alias FlowingLava = FluidBlock!(FLOWING_LAVA, ID!10, 0, 7, 2, 20);
	
	public  static BlockData STILL_LAVA = "stillLava";
	public alias StilLava = FluidBlock!(STILL_LAVA, ID!11);*/

	//TODO
	public static BlockDataArray FLOWING_WATER = [FLOWING_WATER_0, FLOWING_WATER_1, FLOWING_WATER_2, FLOWING_WATER_3, FLOWING_WATER_4, FLOWING_WATER_5, FLOWING_WATER_6, FLOWING_WATER_7];

	public static BlockData FLOWING_WATER_0 = BlockData(335, ID!8, META!0);
	public alias FlowingWater0 = FluidBlock!(FLOWING_WATER_0, FLOWING_WATER_1, 1, 5);

	public static BlockData FLOWING_WATER_1 = BlockData(336, ID!8, META!1);
	public alias FlowingWater1 = FluidBlock!(FLOWING_WATER_1, FLOWING_WATER_2, 1, 5);

	public static BlockData FLOWING_WATER_2 = BlockData(337, ID!8, META!2);
	public alias FlowingWater2 = FluidBlock!(FLOWING_WATER_2, FLOWING_WATER_3, 1, 5);

	public static BlockData FLOWING_WATER_3 = BlockData(338, ID!8, META!3);
	public alias FlowingWater3 = FluidBlock!(FLOWING_WATER_3, FLOWING_WATER_4, 1, 5);

	public static BlockData FLOWING_WATER_4 = BlockData(339, ID!8, META!4);
	public alias FlowingWater4 = FluidBlock!(FLOWING_WATER_4, FLOWING_WATER_5, 1, 5);

	public static BlockData FLOWING_WATER_5 = BlockData(340, ID!8, META!5);
	public alias FlowingWater5 = FluidBlock!(FLOWING_WATER_5, FLOWING_WATER_6, 1, 5);

	public static BlockData FLOWING_WATER_6 = BlockData(341, ID!8, META!6);
	public alias FlowingWater6 = FluidBlock!(FLOWING_WATER_6, FLOWING_WATER_7, 1, 5);

	public static BlockData FLOWING_WATER_7 = BlockData(342, ID!8, META!7);
	public alias FlowingWater7 = FluidBlock!(FLOWING_WATER_7, AIR, 1, 5);

	public static BlockData FALLING_WATER = BlockData(358, ID!8, META!8);
	public alias FallingWater = SimpleBlock!(FALLING_WATER);

	public static BlockDataArray STILL_WATER = [STILL_WATER_0, STILL_WATER_1, STILL_WATER_2, STILL_WATER_3, STILL_WATER_4, STILL_WATER_5, STILL_WATER_6, STILL_WATER_7];

	public static BlockData STILL_WATER_0 = BlockData(308, ID!9, META!0);
	public alias StillWater0 = SimpleBlock!(STILL_WATER_0);
	
	public static BlockData STILL_WATER_1 = BlockData(352, ID!9, META!1);
	public alias StillWater1 = SimpleBlock!(STILL_WATER_1);
	
	public static BlockData STILL_WATER_2 = BlockData(353, ID!9, META!2);
	public alias StillWater2 = SimpleBlock!(STILL_WATER_2);
	
	public static BlockData STILL_WATER_3 = BlockData(354, ID!9, META!3);
	public alias StillWater3 = SimpleBlock!(STILL_WATER_3);
	
	public static BlockData STILL_WATER_4 = BlockData(355, ID!9, META!4);
	public alias StillWater4 = SimpleBlock!(STILL_WATER_4);
	
	public static BlockData STILL_WATER_5 = BlockData(356, ID!9, META!5);
	public alias StillWater5 = SimpleBlock!(STILL_WATER_5);
	
	public static BlockData STILL_WATER_6 = BlockData(357, ID!9, META!6);
	public alias StillWater6 = SimpleBlock!(STILL_WATER_6);
	
	public static BlockData STILL_WATER_7 = BlockData(358, ID!9, META!7);
	public alias StillWater7 = SimpleBlock!(STILL_WATER_7);
	
	public static BlockData STILL_FALLING_WATER_0 = BlockData(363, ID!9, META!8);
	public alias StillFallingWater0 = SimpleBlock!(STILL_FALLING_WATER_0);
	
	public static BlockData STILL_FALLING_WATER_1 = BlockData(364, ID!9, META!9);
	public alias StillFallingWater1 = SimpleBlock!(STILL_FALLING_WATER_1);

	public static BlockData STILL_LAVA = BlockData(309, ID!11, META!0);
	public alias StillLava = SimpleBlock!(STILL_LAVA);
	
	public static BlockData SAND = BlockData(24, ID!12, META!0);
	public alias Sand = MineableBlock!(SAND, SOLID!2.5, GRAVITY, Items.SAND);
	
	public static BlockData RED_SAND = BlockData(25, ID!12, META!1);
	public alias RedSand = MineableBlock!(RED_SAND, SOLID!2.5, GRAVITY, Items.RED_SAND);
	
	public static BlockData GRAVEL = BlockData(26, ID!13, META!0);
	public alias Gravel = MineableBlock!(GRAVEL, SOLID!3, GRAVITY, Items.GRAVEL);
	
	public static BlockData GOLD_ORE = BlockData(27, ID!14, META!0);
	public alias GoldOre = MineableBlock!(GOLD_ORE, SOLID!15, TOOL!(Tool.PICKAXE, Tool.IRON), Items.GOLD_ORE);
	
	public static BlockData IRON_ORE = BlockData(28, ID!15, META!0);
	public alias IronOre = MineableBlock!(IRON_ORE, SOLID!15, TOOL!(Tool.PICKAXE, Tool.STONE), Items.IRON_ORE);
	
	public static BlockData COAL_ORE = BlockData(29, ID!16, META!0);
	public alias CoalOre = MineableBlock!(COAL_ORE, SOLID!15, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.COAL, SILK_TOUCH, Items.COAL_ORE, FORTUNE, "level + 1");
	
	public static BlockDataArray WOOD = [OAK_WOOD_UP_DOWN, SPRUCE_WOOD_UP_DOWN, BIRCH_WOOD_UP_DOWN, JUNGLE_WOOD_UP_DOWN, ACACIA_WOOD_UP_DOWN, DARK_OAK_WOOD_UP_DOWN,
											OAK_WOOD_EAST_WEST, SPRUCE_WOOD_EAST_WEST, BIRCH_WOOD_EAST_WEST, JUNGLE_WOOD_EAST_WEST, ACACIA_WOOD_EAST_WEST, DARK_OAK_WOOD_EAST_WEST,
											OAK_WOOD_NORTH_SOUTH, SPRUCE_WOOD_NORTH_SOUTH, BIRCH_WOOD_NORTH_SOUTH, JUNGLE_WOOD_NORTH_SOUTH, ACACIA_WOOD_NORTH_SOUTH, DARK_OAK_WOOD_NORTH_SOUTH,
											OAK_WOOD_BARK, SPRUCE_WOOD_BARK, BIRCH_WOOD_BARK, JUNGLE_WOOD_BARK, ACACIA_WOOD_BARK, DARK_OAK_WOOD_BARK];

	public static BlockDataArray WOOD_UP_DOWN = [OAK_WOOD_UP_DOWN, SPRUCE_WOOD_UP_DOWN, BIRCH_WOOD_UP_DOWN, JUNGLE_WOOD_UP_DOWN, ACACIA_WOOD_UP_DOWN, DARK_OAK_WOOD_UP_DOWN];
	public static BlockDataArray WOOD_EAST_WEST = [OAK_WOOD_EAST_WEST, SPRUCE_WOOD_EAST_WEST, BIRCH_WOOD_EAST_WEST, JUNGLE_WOOD_EAST_WEST, ACACIA_WOOD_EAST_WEST, DARK_OAK_WOOD_EAST_WEST];
	public static BlockDataArray WOOD_NORTH_SOUTH = [OAK_WOOD_NORTH_SOUTH, SPRUCE_WOOD_NORTH_SOUTH, BIRCH_WOOD_NORTH_SOUTH, JUNGLE_WOOD_NORTH_SOUTH, ACACIA_WOOD_NORTH_SOUTH, DARK_OAK_WOOD_NORTH_SOUTH];
	public static BlockDataArray WOOD_BARK = [OAK_WOOD_BARK, SPRUCE_WOOD_BARK, BIRCH_WOOD_BARK, JUNGLE_WOOD_BARK, ACACIA_WOOD_BARK, DARK_OAK_WOOD_BARK];

	public static BlockDataArray OAK_WOOD = [OAK_WOOD_UP_DOWN, OAK_WOOD_EAST_WEST, OAK_WOOD_NORTH_SOUTH, OAK_WOOD_BARK];
	public static BlockDataArray SPRUCE_WOOD = [SPRUCE_WOOD_UP_DOWN, SPRUCE_WOOD_EAST_WEST, SPRUCE_WOOD_NORTH_SOUTH, SPRUCE_WOOD_BARK];
	public static BlockDataArray BIRCH_WOOD = [BIRCH_WOOD_UP_DOWN, BIRCH_WOOD_EAST_WEST, BIRCH_WOOD_NORTH_SOUTH, BIRCH_WOOD_BARK];
	public static BlockDataArray JUNGLE_WOOD = [JUNGLE_WOOD_UP_DOWN, JUNGLE_WOOD_EAST_WEST, JUNGLE_WOOD_NORTH_SOUTH, JUNGLE_WOOD_BARK];
	public static BlockDataArray ACACIA_WOOD = [ACACIA_WOOD_UP_DOWN, ACACIA_WOOD_EAST_WEST, ACACIA_WOOD_NORTH_SOUTH, ACACIA_WOOD_BARK];
	public static BlockDataArray DARK_OAK_WOOD = [DARK_OAK_WOOD_UP_DOWN, DARK_OAK_WOOD_EAST_WEST, DARK_OAK_WOOD_NORTH_SOUTH, DARK_OAK_WOOD_BARK];

	public static BlockData OAK_WOOD_UP_DOWN = BlockData(30, ID!17, META!0b0000);
	public alias OakWoodUpDown = MineableBlock!(OAK_WOOD_UP_DOWN, SOLID!10, FLAMMABLE, Items.OAK_WOOD);

	public static BlockData OAK_WOOD_EAST_WEST = BlockData(31, ID!17, META!0b0100);
	public alias OakWoodEastWest = MineableBlock!(OAK_WOOD_EAST_WEST, SOLID!10, FLAMMABLE, Items.OAK_WOOD);

	public static BlockData OAK_WOOD_NORTH_SOUTH = BlockData(32, ID!17, META!0b1000);
	public alias OakWoodNorthSouth = MineableBlock!(OAK_WOOD_NORTH_SOUTH, SOLID!10, FLAMMABLE, Items.OAK_WOOD);

	public static BlockData OAK_WOOD_BARK = BlockData(33, ID!17, META!0b1100);
	public alias OakWoodBark = MineableBlock!(OAK_WOOD_BARK, SOLID!10, FLAMMABLE, Items.OAK_WOOD);

	public static BlockData SPRUCE_WOOD_UP_DOWN = BlockData(34, ID!17, META!0b0001);
	public alias SpruceWoodUpDown = MineableBlock!(SPRUCE_WOOD_UP_DOWN, SOLID!10, FLAMMABLE, Items.SPRUCE_WOOD);

	public static BlockData SPRUCE_WOOD_EAST_WEST = BlockData(35, ID!17, META!0b0101);
	public alias SpruceWoodEastWest = MineableBlock!(SPRUCE_WOOD_EAST_WEST, SOLID!10, FLAMMABLE, Items.SPRUCE_WOOD);

	public static BlockData SPRUCE_WOOD_NORTH_SOUTH = BlockData(36, ID!17, META!0b1001);
	public alias SpruceWoodNorthSouth = MineableBlock!(SPRUCE_WOOD_NORTH_SOUTH, SOLID!10, FLAMMABLE, Items.SPRUCE_WOOD);

	public static BlockData SPRUCE_WOOD_BARK = BlockData(37, ID!17, META!0b1101);
	public alias SpruceWoodBark = MineableBlock!(SPRUCE_WOOD_BARK, SOLID!10, FLAMMABLE, Items.SPRUCE_WOOD);

	public static BlockData BIRCH_WOOD_UP_DOWN = BlockData(38, ID!17, META!0b0010);
	public alias BirchWoodUpDown = MineableBlock!(BIRCH_WOOD_UP_DOWN, SOLID!10, FLAMMABLE, Items.BIRCH_WOOD);

	public static BlockData BIRCH_WOOD_EAST_WEST = BlockData(39, ID!17, META!0b0110);
	public alias BirchWoodEastWest = MineableBlock!(BIRCH_WOOD_EAST_WEST, SOLID!10, FLAMMABLE, Items.BIRCH_WOOD);

	public static BlockData BIRCH_WOOD_NORTH_SOUTH = BlockData(40, ID!17, META!0b1010);
	public alias BirchWoodNorthSouth = MineableBlock!(BIRCH_WOOD_NORTH_SOUTH, SOLID!10, FLAMMABLE, Items.BIRCH_WOOD);

	public static BlockData BIRCH_WOOD_BARK = BlockData(41, ID!17, META!0b1110);
	public alias BirchWoodBark = MineableBlock!(BIRCH_WOOD_BARK, SOLID!10, FLAMMABLE, Items.BIRCH_WOOD);

	public static BlockData JUNGLE_WOOD_UP_DOWN = BlockData(42, ID!17, META!0b0011);
	public alias JungleWoodUpDown = MineableBlock!(JUNGLE_WOOD_UP_DOWN, SOLID!10, FLAMMABLE, Items.JUNGLE_WOOD);

	public static BlockData JUNGLE_WOOD_EAST_WEST = BlockData(43, ID!17, META!0b0111);
	public alias JungleWoodEastWest = MineableBlock!(JUNGLE_WOOD_EAST_WEST, SOLID!10, FLAMMABLE, Items.JUNGLE_WOOD);

	public static BlockData JUNGLE_WOOD_NORTH_SOUTH = BlockData(44, ID!17, META!0b1011);
	public alias JungleWoodNorthSouth = MineableBlock!(JUNGLE_WOOD_NORTH_SOUTH, SOLID!10, FLAMMABLE, Items.JUNGLE_WOOD);

	public static BlockData JUNGLE_WOOD_BARK = BlockData(45, ID!17, META!0b1111);
	public alias JungleWoodBark = MineableBlock!(JUNGLE_WOOD_BARK, SOLID!10, FLAMMABLE, Items.JUNGLE_WOOD);

	public static BlockData ACACIA_WOOD_UP_DOWN = BlockData(46, ID!162, META!0b0000);
	public alias AcaciaWoodUpDown = MineableBlock!(ACACIA_WOOD_UP_DOWN, SOLID!10, FLAMMABLE, Items.ACACIA_WOOD);

	public static BlockData ACACIA_WOOD_EAST_WEST = BlockData(47, ID!162, META!0b0100);
	public alias AcaciaWoodEastWest = MineableBlock!(ACACIA_WOOD_EAST_WEST, SOLID!10, FLAMMABLE, Items.ACACIA_WOOD);

	public static BlockData ACACIA_WOOD_NORTH_SOUTH = BlockData(48, ID!162, META!0b1000);
	public alias AcaciaWoodNorthSouth = MineableBlock!(ACACIA_WOOD_NORTH_SOUTH, SOLID!10, FLAMMABLE, Items.ACACIA_WOOD);

	public static BlockData ACACIA_WOOD_BARK = BlockData(49, ID!162, META!0b1100);
	public alias AcaciaWoodBark = MineableBlock!(ACACIA_WOOD_BARK, SOLID!10, FLAMMABLE, Items.ACACIA_WOOD);

	public static BlockData DARK_OAK_WOOD_UP_DOWN = BlockData(50, ID!162, META!0b0001);
	public alias DarkOakWoodUpDown = MineableBlock!(DARK_OAK_WOOD_UP_DOWN, SOLID!10, FLAMMABLE, Items.DARK_OAK_WOOD);

	public static BlockData DARK_OAK_WOOD_EAST_WEST = BlockData(51, ID!162, META!0b0101);
	public alias DarkOakWoodEastWest = MineableBlock!(DARK_OAK_WOOD_EAST_WEST, SOLID!10, FLAMMABLE, Items.DARK_OAK_WOOD);

	public static BlockData DARK_OAK_WOOD_NORTH_SOUTH = BlockData(52, ID!162, META!0b1001);
	public alias DarkOakWoodNorthSouth = MineableBlock!(DARK_OAK_WOOD_NORTH_SOUTH, SOLID!10, FLAMMABLE, Items.DARK_OAK_WOOD);

	public static BlockData DARK_OAK_WOOD_BARK = BlockData(53, ID!162, META!0b1101);
	public alias DarkOakWoodBark = MineableBlock!(DARK_OAK_WOOD_BARK, SOLID!10, FLAMMABLE, Items.DARK_OAK_WOOD);

	//TODO leaves drops and decayment

	public static BlockDataArray LEAVES = [OAK_LEAVES_DECAY, SPRUCE_LEAVES_DECAY, BIRCH_LEAVES_DECAY, JUNGLE_LEAVES_DECAY, ACACIA_LEAVES_DECAY, DARK_OAK_LEAVES_DECAY,
											OAK_LEAVES_NO_DECAY, SPRUCE_LEAVES_NO_DECAY, BIRCH_LEAVES_NO_DECAY, JUNGLE_LEAVES_NO_DECAY, ACACIA_LEAVES_NO_DECAY, DARK_OAK_LEAVES_NO_DECAY];

	public static BlockDataArray LEAVES_DECAY = [OAK_LEAVES_DECAY, SPRUCE_LEAVES_DECAY, BIRCH_LEAVES_DECAY, JUNGLE_LEAVES_DECAY, ACACIA_LEAVES_DECAY, DARK_OAK_LEAVES_DECAY];
	public static BlockDataArray LEAVES_NO_DECAY = [OAK_LEAVES_NO_DECAY, SPRUCE_LEAVES_NO_DECAY, BIRCH_LEAVES_NO_DECAY, JUNGLE_LEAVES_NO_DECAY, ACACIA_LEAVES_NO_DECAY, DARK_OAK_LEAVES_NO_DECAY];

	public static BlockDataArray OAK_LEAVES = [OAK_LEAVES_DECAY, OAK_LEAVES_NO_DECAY];
	public static BlockDataArray SPRUCE_LEAVES = [SPRUCE_LEAVES_DECAY, SPRUCE_LEAVES_NO_DECAY];
	public static BlockDataArray BIRCH_LEAVES = [BIRCH_LEAVES_DECAY, BIRCH_LEAVES_NO_DECAY];
	public static BlockDataArray JUNGLE_LEAVES = [JUNGLE_LEAVES_DECAY, JUNGLE_LEAVES_NO_DECAY];
	public static BlockDataArray ACACIA_LEAVES = [ACACIA_LEAVES_DECAY, ACACIA_LEAVES_NO_DECAY];
	public static BlockDataArray DARK_OAK_LEAVES = [DARK_OAK_LEAVES_DECAY, DARK_OAK_LEAVES_NO_DECAY];

	//TODO decayable leaves and drops
	public static BlockData OAK_LEAVES_DECAY = BlockData(54, ID!18, META!0);
	public alias OakLeavesDecay = SimpleBlock!(OAK_LEAVES_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData SPRUCE_LEAVES_DECAY = BlockData(55, ID!18, META!1);
	public alias SpruceLeavesDecay = SimpleBlock!(SPRUCE_LEAVES_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData BIRCH_LEAVES_DECAY = BlockData(56, ID!18, META!2);
	public alias BirchLeavesDecay = SimpleBlock!(BIRCH_LEAVES_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData JUNGLE_LEAVES_DECAY = BlockData(57, ID!18, META!3);
	public alias JungleLeavesDecay = SimpleBlock!(JUNGLE_LEAVES_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData ACACIA_LEAVES_DECAY = BlockData(58, ID!161, META!0);
	public alias AcaciaLeavesDecay = SimpleBlock!(ACACIA_LEAVES_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData DARK_OAK_LEAVES_DECAY = BlockData(59, ID!161, META!1);
	public alias DarkOakLeavesDecay = SimpleBlock!(DARK_OAK_LEAVES_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData OAK_LEAVES_NO_DECAY = BlockData(60, ID!18, META!4);
	public alias OakLeavesNoDecay = MineableBlock!(OAK_LEAVES_NO_DECAY, SOLID!1, FLAMMABLE, [Items.OAK_SAPLING: "-18..1", Items.APPLE: "-198..1"]/*, TOOL!(Tool.SHEARS)*/, SILK_TOUCH, Items.OAK_LEAVES);

	public static BlockData SPRUCE_LEAVES_NO_DECAY = BlockData(61, ID!18, META!5);
	public alias SpruceLeavesNoDecay = MineableBlock!(SPRUCE_LEAVES_NO_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData BIRCH_LEAVES_NO_DECAY = BlockData(62, ID!18, META!6);
	public alias BirchLeavesNoDecay = MineableBlock!(BIRCH_LEAVES_NO_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData JUNGLE_LEAVES_NO_DECAY = BlockData(63, ID!18, META!7);
	public alias JungleLeavesNoDecay = MineableBlock!(JUNGLE_LEAVES_NO_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData ACACIA_LEAVES_NO_DECAY = BlockData(64, ID!161, META!4);
	public alias AcaciaLeavesNoDecay = MineableBlock!(ACACIA_LEAVES_NO_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData DARK_OAK_LEAVES_NO_DECAY = BlockData(65, ID!161, META!5);
	public alias DarkOakLeavesNoDecay = MineableBlock!(DARK_OAK_LEAVES_NO_DECAY, SOLID!1, FLAMMABLE);

	public static BlockData OAK_LEAVES_CHECK_DECAY = BlockData(365, ID!18, META!8);
	public alias OakLeavesCheckDecay = MineableBlock!(OAK_LEAVES_CHECK_DECAY);

	public static BlockData SPRUCE_LEAVES_CHECK_DECAY = BlockData(366, ID!18, META!9);
	public alias SpruceLeavesCheckDecay = MineableBlock!(SPRUCE_LEAVES_CHECK_DECAY);

	public static BlockData BIRCH_LEAVES_CHECK_DECAY = BlockData(367, ID!18, META!10);
	public alias BirchLeavesCheckDecay = MineableBlock!(BIRCH_LEAVES_CHECK_DECAY);

	public static BlockData JUNGLE_LEAVES_CHECK_DECAY = BlockData(368, ID!18, META!11);
	public alias JungleLeavesCheckDecay = MineableBlock!(JUNGLE_LEAVES_CHECK_DECAY);

	public static BlockData ACACIA_LEAVES_CHECK_DECAY = BlockData(369, ID!161, META!8);
	public alias AcaciaLeavesCheckDecay = MineableBlock!(ACACIA_LEAVES_CHECK_DECAY);

	public static BlockData DARK_OAK_LEAVES_CHECK_DECAY = BlockData(370, ID!161, META!9);
	public alias DarkOakLeavesCheckDecay = MineableBlock!(DARK_OAK_LEAVES_CHECK_DECAY);

	public static BlockData OAK_LEAVES_NO_DECAY_CHECK_DECAY = BlockData(371, ID!18, META!12);
	public alias OakLeavesNoDecayCheckDecay = SimpleBlock!(OAK_LEAVES_NO_DECAY_CHECK_DECAY);

	public static BlockData SPRUCE_LEAVES_NO_DECAY_CHECK_DECAY = BlockData(372, ID!18, META!13);
	public alias SpruceLeavesNoDecayCheckDecay = SimpleBlock!(SPRUCE_LEAVES_NO_DECAY_CHECK_DECAY);

	public static BlockData BIRCH_LEAVES_NO_DECAY_CHECK_DECAY = BlockData(373, ID!18, META!14);
	public alias BirchLeavesNoDecayCheckDecay = SimpleBlock!(BIRCH_LEAVES_NO_DECAY_CHECK_DECAY);

	public static BlockData JUNGLE_LEAVES_NO_DECAY_CHECK_DECAY = BlockData(374, ID!18, META!15);
	public alias JungleLeavesNoDecayCheckDecay = SimpleBlock!(JUNGLE_LEAVES_NO_DECAY_CHECK_DECAY);

	public static BlockData ACACIA_LEAVES_NO_DECAY_CHECK_DECAY = BlockData(375, ID!161, META!12);
	public alias AcaciaLeavesNoDecayCheckDecay = SimpleBlock!(ACACIA_LEAVES_NO_DECAY_CHECK_DECAY);

	public static BlockData DARK_OAK_LEAVES_NO_DECAY_CHECK_DECAY = BlockData(376, ID!161, META!13);
	public alias DarkOakLeavesNoDecayCheckDecay = SimpleBlock!(DARK_OAK_LEAVES_NO_DECAY_CHECK_DECAY);
	
	public static BlockData SPONGE = BlockData(66, ID!19, META!0);
	public alias Sponge = MineableBlock!(SPONGE, SOLID!3, Items.SPONGE);
	
	public static BlockData GLASS = BlockData(67, ID!20, META!0);
	public alias Glass = SimpleBlock!(GLASS, SOLID!1.5, Items.GLASS);

	//TODO fortune and silk touch
	public static BlockData LAPIS_LAZULI_ORE = BlockData(68, ID!21, META!0);
	public alias LapisLazuliOre = MineableBlock!(LAPIS_LAZULI_ORE, SOLID!15, TOOL!(Tool.PICKAXE, Tool.STONE), Items.LAPIS_LAZULI);
	
	public static BlockData LAPIS_LAZULI_BLOCK = BlockData(69, ID!22, META!0);
	public alias LapisLazuliBlock = MineableBlock!(LAPIS_LAZULI_BLOCK, SOLID!15, TOOL!(Tool.PICKAXE, Tool.STONE), Items.LAPIS_LAZULI_BLOCK);
	
	public static BlockDataArray DISPENSER = [DISPENSER_DOWN, DISPENSER_UP, DISPENSER_NORTH, DISPENSER_SOUTH, DISPENSER_WEST, DISPENSER_EAST];

	public static BlockData DISPENSER_DOWN = BlockData(191, ID!23, META!0);

	public static BlockData DISPENSER_UP = BlockData(192, ID!23, META!1);

	public static BlockData DISPENSER_NORTH = BlockData(193, ID!23, META!2);

	public static BlockData DISPENSER_SOUTH = BlockData(194, ID!23, META!3);

	public static BlockData DISPENSER_WEST = BlockData(195, ID!23, META!4);

	public static BlockData DISPENSER_EAST = BlockData(196, ID!23, META!5);
	
	public static BlockData SANDSTONE = BlockData(197, ID!24, META!0);
	public alias Sandstone = MineableBlock!(SANDSTONE, SOLID!4, Items.SANDSTONE);
	
	public static BlockData CHISELED_SANDSTONE = BlockData(198, ID!24, META!1);
	public alias ChiseledSandstone = MineableBlock!(CHISELED_SANDSTONE, SOLID!4, Items.CHISELED_SANDSTONE);
	
	public static BlockData SMOOTH_SANDSTONE = BlockData(199, ID!24, META!2);
	public alias SmoothSandstone = MineableBlock!(SMOOTH_SANDSTONE, SOLID!4, Items.SMOOTH_SANDSTONE);
	
	public static BlockData NOTEBLOCK = BlockData(200, ID!25, META!0);

	public static BlockDataArray BED_BLOCK = [BED_BLOCK_FOOT_SOUTH, BED_BLOCK_FOOT_WEST, BED_BLOCK_FOOT_NORTH, BED_BLOCK_FOOT_EAST,
												BED_BLOCK_HEAD_SOUTH, BED_BLOCK_HEAD_WEST, BED_BLOCK_HEAD_NORTH, BED_BLOCK_HEAD_EAST];

	public static BlockDataArray BED_BLOCK_FOOT = [BED_BLOCK_FOOT_SOUTH, BED_BLOCK_FOOT_WEST, BED_BLOCK_FOOT_NORTH, BED_BLOCK_FOOT_EAST];
	public static BlockDataArray BED_BLOCK_HEAD = [BED_BLOCK_HEAD_SOUTH, BED_BLOCK_HEAD_WEST, BED_BLOCK_HEAD_NORTH, BED_BLOCK_HEAD_EAST];

	public static BlockData BED_BLOCK_FOOT_SOUTH = BlockData(205, ID!26, META!0);

	public static BlockData BED_BLOCK_FOOT_WEST = BlockData(206, ID!26, META!1);

	public static BlockData BED_BLOCK_FOOT_NORTH = BlockData(207, ID!26, META!2);

	public static BlockData BED_BLOCK_FOOT_EAST = BlockData(208, ID!26, META!3);

	public static BlockData BED_BLOCK_HEAD_SOUTH = BlockData(201, ID!26, META!8);

	public static BlockData BED_BLOCK_HEAD_WEST = BlockData(202, ID!26, META!9);

	public static BlockData BED_BLOCK_HEAD_NORTH = BlockData(203, ID!26, META!10);

	public static BlockData BED_BLOCK_HEAD_EAST = BlockData(204, ID!26, META!11);
	
	public static BlockDataArray POWERED_RAIL = [POWERED_RAIL_OFF_NORTH_SOUTH, POWERED_RAIL_OFF_WEST_EAST, POWERED_RAIL_OFF_ASCENDING_EAST, POWERED_RAIL_OFF_ASCENDING_WEST, POWERED_RAIL_OFF_ASCENDING_NORTH, POWERED_RAIL_OFF_ASCENDING_SOUTH,
													POWERED_RAIL_ON_NORTH_SOUTH, POWERED_RAIL_ON_WEST_EAST, POWERED_RAIL_ON_ASCENDING_EAST, POWERED_RAIL_ON_ASCENDING_WEST, POWERED_RAIL_ON_ASCENDING_NORTH, POWERED_RAIL_ON_ASCENDING_SOUTH];
	
	public static BlockDataArray POWERED_RAIL_OFF = [POWERED_RAIL_OFF_NORTH_SOUTH, POWERED_RAIL_OFF_WEST_EAST, POWERED_RAIL_OFF_ASCENDING_EAST, POWERED_RAIL_OFF_ASCENDING_WEST, POWERED_RAIL_OFF_ASCENDING_NORTH, POWERED_RAIL_OFF_ASCENDING_SOUTH];
	public static BlockDataArray POWERED_RAIL_ON = [POWERED_RAIL_ON_NORTH_SOUTH, POWERED_RAIL_ON_WEST_EAST, POWERED_RAIL_ON_ASCENDING_EAST, POWERED_RAIL_ON_ASCENDING_WEST, POWERED_RAIL_ON_ASCENDING_NORTH, POWERED_RAIL_ON_ASCENDING_SOUTH];
	
	public static BlockData POWERED_RAIL_OFF_NORTH_SOUTH = BlockData(205, ID!27, META!0);
	
	public static BlockData POWERED_RAIL_OFF_WEST_EAST = BlockData(206, ID!27, META!1);
	
	public static BlockData POWERED_RAIL_OFF_ASCENDING_EAST = BlockData(207, ID!27, META!2);
	
	public static BlockData POWERED_RAIL_OFF_ASCENDING_WEST = BlockData(208, ID!27, META!3);
	
	public static BlockData POWERED_RAIL_OFF_ASCENDING_NORTH = BlockData(209, ID!27, META!4);
	
	public static BlockData POWERED_RAIL_OFF_ASCENDING_SOUTH = BlockData(210, ID!27, META!5);
	
	public static BlockData POWERED_RAIL_ON_NORTH_SOUTH = BlockData(211, ID!27, META!6);
	
	public static BlockData POWERED_RAIL_ON_WEST_EAST = BlockData(212, ID!27, META!7);
	
	public static BlockData POWERED_RAIL_ON_ASCENDING_EAST = BlockData(213, ID!27, META!8);
	
	public static BlockData POWERED_RAIL_ON_ASCENDING_WEST = BlockData(214, ID!27, META!9);
	
	public static BlockData POWERED_RAIL_ON_ASCENDING_NORTH = BlockData(215, ID!27, META!10);
	
	public static BlockData POWERED_RAIL_ON_ASCENDING_SOUTH = BlockData(216, ID!27, META!11);
	
	public static BlockDataArray DETECTOR_RAIL = [DETECTOR_RAIL_OFF_NORTH_SOUTH, DETECTOR_RAIL_OFF_WEST_EAST, DETECTOR_RAIL_OFF_ASCENDING_EAST, DETECTOR_RAIL_OFF_ASCENDING_WEST, DETECTOR_RAIL_OFF_ASCENDING_NORTH, DETECTOR_RAIL_OFF_ASCENDING_SOUTH,
													DETECTOR_RAIL_ON_NORTH_SOUTH, DETECTOR_RAIL_ON_WEST_EAST, DETECTOR_RAIL_ON_ASCENDING_EAST, DETECTOR_RAIL_ON_ASCENDING_WEST, DETECTOR_RAIL_ON_ASCENDING_NORTH, DETECTOR_RAIL_ON_ASCENDING_SOUTH];
	
	public static BlockDataArray DETECTOR_RAIL_OFF = [DETECTOR_RAIL_OFF_NORTH_SOUTH, DETECTOR_RAIL_OFF_WEST_EAST, DETECTOR_RAIL_OFF_ASCENDING_EAST, DETECTOR_RAIL_OFF_ASCENDING_WEST, DETECTOR_RAIL_OFF_ASCENDING_NORTH, DETECTOR_RAIL_OFF_ASCENDING_SOUTH];
	public static BlockDataArray DETECTOR_RAIL_ON = [DETECTOR_RAIL_ON_NORTH_SOUTH, DETECTOR_RAIL_ON_WEST_EAST, DETECTOR_RAIL_ON_ASCENDING_EAST, DETECTOR_RAIL_ON_ASCENDING_WEST, DETECTOR_RAIL_ON_ASCENDING_NORTH, DETECTOR_RAIL_ON_ASCENDING_SOUTH];
	
	public static BlockData DETECTOR_RAIL_OFF_NORTH_SOUTH = BlockData(217, ID!28, META!0);
	
	public static BlockData DETECTOR_RAIL_OFF_WEST_EAST = BlockData(218, ID!28, META!1);
	
	public static BlockData DETECTOR_RAIL_OFF_ASCENDING_EAST = BlockData(219, ID!28, META!2);
	
	public static BlockData DETECTOR_RAIL_OFF_ASCENDING_WEST = BlockData(220, ID!28, META!3);
	
	public static BlockData DETECTOR_RAIL_OFF_ASCENDING_NORTH = BlockData(221, ID!28, META!4);
	
	public static BlockData DETECTOR_RAIL_OFF_ASCENDING_SOUTH = BlockData(222, ID!28, META!5);
	
	public static BlockData DETECTOR_RAIL_ON_NORTH_SOUTH = BlockData(223, ID!28, META!6);
	
	public static BlockData DETECTOR_RAIL_ON_WEST_EAST = BlockData(224, ID!28, META!7);
	
	public static BlockData DETECTOR_RAIL_ON_ASCENDING_EAST = BlockData(225, ID!28, META!8);
	
	public static BlockData DETECTOR_RAIL_ON_ASCENDING_WEST = BlockData(226, ID!28, META!9);
	
	public static BlockData DETECTOR_RAIL_ON_ASCENDING_NORTH = BlockData(227, ID!28, META!10);
	
	public static BlockData DETECTOR_RAIL_ON_ASCENDING_SOUTH = BlockData(228, ID!28, META!11);

	public static BlockDataArray STICKY_PISTON = [];

	public static BlockData COBWEB = BlockData(229, ID!30, META!0);

	public static BlockData TALL_GRASS = BlockData(151, ID!31, METAS!(0, 1));
	public alias TallGrass = MineableBlock!(TALL_GRASS, REPLACEABLE, INSTANT_BREAKING, FLAMMABLE, Items.SEEDS, "0..1");

	public static BlockData FERN = BlockData(152, ID!31, META!2);
	public alias Fern = MineableBlock!(FERN, REPLACEABLE, INSTANT_BREAKING, FLAMMABLE, Items.SEEDS, "0..1");

	public static BlockData DEAD_BUSH = BlockData(153, ID!32, META!0);
	public alias DeadBush = MineableBlock!(DEAD_BUSH, REPLACEABLE, INSTANT_BREAKING, FLAMMABLE, Items.STICK, "0..2");

	public static BlockDataArray PISTON = [];

	public static BlockDataArray PISTON_HEAD = [];

	public static BlockDataArray WOOL = [WHITE_WOOL, ORANGE_WOOL, MAGENTA_WOOL, LIGHT_BLUE_WOOL, YELLOW_WOOL, LIME_WOOL, PINK_WOOL, GRAY_WOOL, LIGHT_GRAY_WOOL, CYAN_WOOL, PURPLE_WOOL, BLUE_WOOL, BROWN_WOOL, GREEN_WOOL, RED_WOOL, BLACK_WOOL];

	public static BlockData WHITE_WOOL = BlockData(154, ID!35, META!0);
	public alias WhiteWool = MineableBlock!(WHITE_WOOL, SOLID!4, FLAMMABLE, Items.WHITE_WOOL);

	public static BlockData ORANGE_WOOL = BlockData(155, ID!35, META!1);
	public alias OrangeWool = MineableBlock!(ORANGE_WOOL, SOLID!4, FLAMMABLE, Items.ORANGE_WOOL);

	public static BlockData MAGENTA_WOOL = BlockData(156, ID!35, META!2);
	public alias MagentaWool = MineableBlock!(MAGENTA_WOOL, SOLID!4, FLAMMABLE, Items.MAGENTA_WOOL);

	public static BlockData LIGHT_BLUE_WOOL = BlockData(157, ID!35, META!3);
	public alias LightBlueWool = MineableBlock!(LIGHT_BLUE_WOOL, SOLID!4, FLAMMABLE, Items.LIGHT_BLUE_WOOL);

	public  static BlockData YELLOW_WOOL = BlockData(158, ID!35, META!4);
	public alias YellowWool = MineableBlock!(YELLOW_WOOL, SOLID!4, FLAMMABLE, Items.YELLOW_WOOL);

	public static BlockData LIME_WOOL = BlockData(159, ID!35, META!5);
	public alias LimeWool = MineableBlock!(LIME_WOOL, SOLID!4, FLAMMABLE, Items.LIME_WOOL);

	public static BlockData PINK_WOOL = BlockData(160, ID!35, META!6);
	public alias PinkWool = MineableBlock!(PINK_WOOL, SOLID!4, FLAMMABLE, Items.PINK_WOOL);

	public static BlockData GRAY_WOOL = BlockData(161, ID!35, META!7);
	public alias GrayWool = MineableBlock!(GRAY_WOOL, SOLID!4, FLAMMABLE, Items.GRAY_WOOL);

	public static BlockData LIGHT_GRAY_WOOL = BlockData(162, ID!35, META!8);
	public alias LightGrayWool = MineableBlock!(LIGHT_GRAY_WOOL, SOLID!4, FLAMMABLE, Items.LIGHT_GRAY_WOOL);

	public static BlockData CYAN_WOOL = BlockData(163, ID!35, META!9);
	public alias CyanWool = MineableBlock!(CYAN_WOOL, SOLID!4, FLAMMABLE, Items.CYAN_WOOL);

	public static BlockData PURPLE_WOOL = BlockData(164, ID!35, META!10);
	public alias PurpleWool = MineableBlock!(PURPLE_WOOL, SOLID!4, FLAMMABLE, Items.PURPLE_WOOL);

	public static BlockData BLUE_WOOL = BlockData(165, ID!35, META!11);
	public alias BlueWool = MineableBlock!(BLUE_WOOL, SOLID!4, FLAMMABLE, Items.BLUE_WOOL);

	public static BlockData BROWN_WOOL = BlockData(166, ID!35, META!12);
	public alias BrownWool = MineableBlock!(BROWN_WOOL, SOLID!4, FLAMMABLE, Items.BROWN_WOOL);

	public static BlockData GREEN_WOOL = BlockData(167, ID!35, META!13);
	public alias GreenWool = MineableBlock!(GREEN_WOOL, SOLID!4, FLAMMABLE, Items.GREEN_WOOL);

	public static BlockData RED_WOOL = BlockData(168, ID!35, META!14);
	public alias RedWool = MineableBlock!(RED_WOOL, SOLID!4, FLAMMABLE, Items.RED_WOOL);

	public static BlockData BLACK_WOOL = BlockData(169, ID!35, META!15);
	public alias BlackWool = MineableBlock!(BLACK_WOOL, SOLID!4, FLAMMABLE, Items.BLACK_WOOL);

	public static BlockData DANDELION = BlockData(170, ID!37, META!0);
	public alias Dandelion = MineableBlock!(DANDELION, INSTANT_BREAKING, Items.DANDELION);

	public static BlockData POPPY = BlockData(171, ID!38, META!0);
	public alias Poppy = MineableBlock!(POPPY, INSTANT_BREAKING, Items.POPPY);

	public static BlockData BLUE_ORCHID = BlockData(172, ID!38, META!1);
	public alias BlueOrchid = MineableBlock!(BLUE_ORCHID, INSTANT_BREAKING, Items.BLUE_ORCHID);

	public static BlockData ALLIUM = BlockData(173, ID!38, META!2);
	public alias Allium = MineableBlock!(ALLIUM, INSTANT_BREAKING, Items.ALLIUM);

	public static BlockData AZURE_BLUET = BlockData(174, ID!38, META!3);
	public alias AzureBluet = MineableBlock!(AZURE_BLUET, INSTANT_BREAKING, Items.AZURE_BLUET);

	public static BlockData RED_TULIP = BlockData(175, ID!38, META!4);
	public alias RedTulip = MineableBlock!(RED_TULIP, INSTANT_BREAKING, Items.RED_TULIP);

	public static BlockData ORANGE_TULIP = BlockData(176, ID!38, META!5);
	public alias OrangeTulip = MineableBlock!(ORANGE_TULIP, INSTANT_BREAKING, Items.ORANGE_TULIP);

	public static BlockData WHITE_TULIP = BlockData(177, ID!38, META!6);
	public alias WhiteTulip = MineableBlock!(WHITE_TULIP, INSTANT_BREAKING, Items.WHITE_TULIP);

	public static BlockData PINK_TULIP = BlockData(178, ID!38, META!7);
	public alias PinkTulip = MineableBlock!(PINK_TULIP, INSTANT_BREAKING, Items.PINK_TULIP);

	public static BlockData OXEYE_DAISY = BlockData(179, ID!38, META!8);
	public alias OxeyeDaisy = MineableBlock!(OXEYE_DAISY, INSTANT_BREAKING, Items.OXEYE_DAISY);

	public static BlockData BROWN_MUSHROOM = BlockData(180, ID!39, META!0);

	public static BlockData RED_MUSHROOM = BlockData(181, ID!40, META!0);

	public static BlockData GOLD_BLOCK = BlockData(182, ID!41, META!0);
	public alias GoldBlock = MineableBlock!(GOLD_BLOCK, SOLID!30, TOOL!(Tool.PICKAXE, Tool.IRON), Items.GOLD_BLOCK);

	public static BlockData IRON_BLOCK = BlockData(183, ID!42, META!0);
	public alias IronBlock = MineableBlock!(IRON_BLOCK, SOLID!30, TOOL!(Tool.PICKAXE, Tool.STONE), Items.IRON_BLOCK);

	public static BlockDataArray DOUBLE_SLAB = [];

	public static BlockData DOUBLE_STONE_SLAB = BlockData(229, ID!43, META!0);
	public alias DoubleStoneSlab = MineableBlock!(DOUBLE_STONE_SLAB, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.STONE_SLAB, 2);

	public static BlockData DOUBLE_SANDSTONE_SLAB = BlockData(230, ID!43, META!1);

	public static BlockData DOUBLE_STONE_WOOD_SLAB = BlockData(230, ID!43, META!2);

	public static BlockData DOUBLE_COBBLESTONE_SLAB = BlockData(231, ID!43, META!3);

	public static BlockData DOUBLE_BRICK_SLAB = BlockData(232, ID!43, META!4);

	public static BlockData DOUBLE_STONE_BRICK_SLAB = BlockData(233, ID!43, META!5);

	public static BlockData DOUBLE_NETHER_BRICK_SLAB = BlockData(234, ID!43, META!6);

	public static BlockData DOUBLE_QUARTZ_SLAB = BlockData(235, ID!43, META!7);

	public static BlockData SMOOTH_DOUBLE_STONE_SLAB = BlockData(236, ID!43, META!8);

	public static BlockData SMOOTH_DOUBLE_SANDSTONE_SLAB = BlockData(237, ID!43, META!9);

	public static BlockDataArray SLAB = [];

	public static BlockData STONE_SLAB = BlockData(238, ID!44, META!0);
	public alias StoneSlab = MineableBlock!(STONE_SLAB, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.STONE_SLAB);

	public static BlockData SANDSTONE_SLAB = BlockData(239, ID!44, META!1);

	public static BlockData STONE_WOOD_SLAB = BlockData(240, ID!44, META!2);

	public static BlockData COBBLESTONE_SLAB = BlockData(241, ID!44, META!3);

	public static BlockData BRICK_SLAB = BlockData(242, ID!44, META!4);

	public static BlockData STONE_BRICK_SLAB = BlockData(243, ID!44, META!5);

	public static BlockData NETHER_BRICK_SLAB = BlockData(243, ID!44, META!6);

	public static BlockData QUARTZ_SLAB = BlockData(244, ID!44, META!7);

	public static BlockData BRICKS = BlockData(245, ID!45, META!0);

	public static BlockData UPPER_STONE_SLAB = BlockData(343, ID!44, META!8);
	public alias UpperStoneSlab = MineableBlock!(UPPER_STONE_SLAB, SOLID!30, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.STONE_SLAB);

	public static BlockData UPPER_SANDSTONE_SLAB = BlockData(344, ID!44, META!9);

	public static BlockData UPPER_STONE_WOOD_SLAB = BlockData(345, ID!44, META!10);

	public static BlockData UPPER_COBBLESTONE_SLAB = BlockData(346, ID!44, META!11);

	public static BlockData UPPER_BRICK_SLAB = BlockData(347, ID!44, META!12);

	public static BlockData UPPER_STONE_BRICK_SLAB = BlockData(348, ID!44, META!13);

	public static BlockData UPPER_NETHER_BRICK_SLAB = BlockData(349, ID!44, META!14);

	public static BlockData UPPER_QUARTZ_SLAB = BlockData(350, ID!44, META!15);

	public static BlockData TNT = BlockData(184, ID!46, META!0);
	public alias Tnt = MineableBlock!(TNT, FLAMMABLE, INSTANT_BREAKING, Items.TNT);

	public static BlockData BOOKSHELF = BlockData(186, ID!47, META!0);

	public static BlockData MOSSY_STONE = BlockData(187, ID!48, META!0);

	public static BlockData OBSIDIAN = BlockData(185, ID!49, META!0);
	public alias Obsidian = MineableBlock!(OBSIDIAN, SOLID!(double.infinity), TOOL!(Tool.PICKAXE, Tool.DIAMOND), Items.OBSIDIAN);

	public static BlockDataArray TORCH = [TORCH_UP, TORCH_EAST, TORCH_WEST, TORCH_SOUTH, TORCH_NORTH];

	public static BlockData TORCH_EAST = BlockData(186, ID!50, META!1);

	public static BlockData TORCH_WEST = BlockData(187, ID!50, META!2);

	public static BlockData TORCH_SOUTH = BlockData(188, ID!50, META!3);

	public static BlockData TORCH_NORTH = BlockData(189, ID!50, META!4);

	public static BlockData TORCH_UP = BlockData(190, ID!50, META!5);

	public static BlockData FIRE = BlockData(142, ID!51, META!0);
	public alias Fire = FireBlock!(FIRE);

	public static BlockData MONSTER_SPAWNER = BlockData(246, ID!52, META!0);

	public static BlockDataArray OAK_STAIRS = [OAK_STAIRS_EAST, OAK_STAIRS_WEST, OAK_STAIRS_SOUTH, OAK_STAIRS_NORTH, OAK_STAIRS_EAST_UPSIDE_DOWN, OAK_STAIRS_WEST_UPSIDE_DOWN, OAK_STAIRS_SOUTH_UPSIDE_DOWN, OAK_STAIRS_NORTH_UPSIDE_DOWN];

	public static BlockData OAK_STAIRS_EAST = BlockData(247, ID!53, META!0);

	public static BlockData OAK_STAIRS_WEST = BlockData(248, ID!53, META!1);

	public static BlockData OAK_STAIRS_SOUTH = BlockData(249, ID!53, META!2);

	public static BlockData OAK_STAIRS_NORTH = BlockData(250, ID!53, META!3);

	public static BlockData OAK_STAIRS_EAST_UPSIDE_DOWN = BlockData(251, ID!53, META!4);

	public static BlockData OAK_STAIRS_WEST_UPSIDE_DOWN = BlockData(252, ID!53, META!5);

	public static BlockData OAK_STAIRS_SOUTH_UPSIDE_DOWN = BlockData(253, ID!53, META!6);

	public static BlockData OAK_STAIRS_NORTH_UPSIDE_DOWN = BlockData(254, ID!53, META!7);

	public static BlockDataArray CHEST = [CHEST_NORTH, CHEST_SOUTH, CHEST_WEST, CHEST_EAST];

	public static BlockData CHEST_NORTH = BlockData(255, ID!54, META!2);

	public static BlockData CHEST_SOUTH = BlockData(256, ID!54, META!3);

	public static BlockData CHEST_WEST = BlockData(257, ID!54, META!4);

	public static BlockData CHEST_EAST = BlockData(258, ID!54, META!5);

	public static BlockDataArray REDSTONE_WIRE = [REDSTONE_WIRE_0, REDSTONE_WIRE_1, REDSTONE_WIRE_2, REDSTONE_WIRE_3, REDSTONE_WIRE_4, REDSTONE_WIRE_5, REDSTONE_WIRE_6, REDSTONE_WIRE_7, REDSTONE_WIRE_8, REDSTONE_WIRE_10, REDSTONE_WIRE_11, REDSTONE_WIRE_12, REDSTONE_WIRE_13, REDSTONE_WIRE_14, REDSTONE_WIRE_15];

	public static BlockData REDSTONE_WIRE_0 = BlockData(259, ID!55, META!0);

	public static BlockData REDSTONE_WIRE_1 = BlockData(260, ID!55, META!1);

	public static BlockData REDSTONE_WIRE_2 = BlockData(261, ID!55, META!2);

	public static BlockData REDSTONE_WIRE_3 = BlockData(262, ID!55, META!3);

	public static BlockData REDSTONE_WIRE_4 = BlockData(263, ID!55, META!4);

	public static BlockData REDSTONE_WIRE_5 = BlockData(264, ID!55, META!5);

	public static BlockData REDSTONE_WIRE_6 = BlockData(265, ID!55, META!6);

	public static BlockData REDSTONE_WIRE_7 = BlockData(266, ID!55, META!7);

	public static BlockData REDSTONE_WIRE_8 = BlockData(267, ID!55, META!8);

	public static BlockData REDSTONE_WIRE_9 = BlockData(268, ID!55, META!9);

	public static BlockData REDSTONE_WIRE_10 = BlockData(269, ID!55, META!10);

	public static BlockData REDSTONE_WIRE_11 = BlockData(270, ID!55, META!11);

	public static BlockData REDSTONE_WIRE_12 = BlockData(271, ID!55, META!12);

	public static BlockData REDSTONE_WIRE_13 = BlockData(272, ID!55, META!13);

	public static BlockData REDSTONE_WIRE_14 = BlockData(273, ID!55, META!14);

	public static BlockData REDSTONE_WIRE_15 = BlockData(274, ID!55, META!15);

	public static BlockData DIAMOND_ORE = BlockData(275, ID!56, META!0);
	public alias DiamondOre = MineableBlock!(DIAMOND_ORE, SOLID!15, TOOL!(Tool.PICKAXE, Tool.IRON), Items.DIAMOND, SILK_TOUCH, Items.DIAMOND_ORE, FORTUNE, "level + 1");

	public static BlockData DIAMOND_BLOCK = BlockData(276, ID!57, META!0);
	public alias DiamondBlock = MineableBlock!(DIAMOND_BLOCK, SOLID!30, TOOL!(Tool.PICKAXE, Tool.IRON), Items.DIAMOND_BLOCK);

	public static BlockData CRAFTING_TABLE = BlockData(277, ID!58, META!0);
	public alias CraftingTable = MineableBlock!(CRAFTING_TABLE, SOLID!12.5, Items.CRAFTING_TABLE);
	
	public static BlockDataArray SEEDS_BLOCK = [SEEDS_BLOCK_0, SEEDS_BLOCK_1, SEEDS_BLOCK_2, SEEDS_BLOCK_3, SEEDS_BLOCK_4, SEEDS_BLOCK_5, SEEDS_BLOCK_6, SEEDS_BLOCK_7];

	public static BlockData SEEDS_BLOCK_0 = BlockData(70, ID!59, META!0);
	public alias SeedsBlock0 = CropBlock!(SEEDS_BLOCK_0, SEEDS_BLOCK_1, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_1 = BlockData(71, ID!59, META!1);
	public alias SeedsBlock1 = CropBlock!(SEEDS_BLOCK_1, SEEDS_BLOCK_2, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_2 = BlockData(72, ID!59, META!2);
	public alias SeedsBlock2 = CropBlock!(SEEDS_BLOCK_2, SEEDS_BLOCK_3, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_3 = BlockData(73, ID!59, META!3);
	public alias SeedsBlock3 = CropBlock!(SEEDS_BLOCK_3, SEEDS_BLOCK_4, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_4 = BlockData(74, ID!59, META!4);
	public alias SeedsBlock4 = CropBlock!(SEEDS_BLOCK_4, SEEDS_BLOCK_5, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_5 = BlockData(75, ID!59, META!5);
	public alias SeedsBlock5 = CropBlock!(SEEDS_BLOCK_5, SEEDS_BLOCK_6, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_6 = BlockData(76, ID!59, META!6);
	public alias SeedsBlock6 = CropBlock!(SEEDS_BLOCK_6, SEEDS_BLOCK_7, [Items.SEEDS: "1"]);

	public static BlockData SEEDS_BLOCK_7 = BlockData(77, ID!59, META!7);
	public alias SeedsBlock7 = CropBlock!(SEEDS_BLOCK_7, AIR, [Items.SEEDS: "0..3", Items.WHEAT: "1"]);

	public static BlockDataArray FARMLAND = [NOT_HYDRATED_FARMLAND, HYDRATED_FARMLAND];

	public static BlockData NOT_HYDRATED_FARMLAND = BlockData(78, ID!60, META!0);
	public alias NotHydratedFarmland = FertileTerrain!(NOT_HYDRATED_FARMLAND, false, SOLID!3, Items.DIRT);
	
	public static BlockData HYDRATED_FARMLAND = BlockData(79, ID!60, META!7);
	public alias HydratedFarmland = FertileTerrain!(HYDRATED_FARMLAND, true, SOLID!3, Items.DIRT);

	public static BlockDataArray FURNACE = [FURNACE_NORTH, FURNACE_SOUTH, FURNACE_WEST, FURNACE_EAST];

	public static BlockData FURNACE_NORTH = BlockData(280, ID!61, META!2);

	public static BlockData FURNACE_SOUTH = BlockData(281, ID!61, META!3);

	public static BlockData FURNACE_WEST = BlockData(282, ID!61, META!4);

	public static BlockData FURNACE_EAST = BlockData(283, ID!61, META!5);

	public static BlockDataArray LIT_FURNACE = [LIT_FURNACE_NORTH, LIT_FURNACE_SOUTH, LIT_FURNACE_WEST, LIT_FURNACE_EAST];

	public static BlockData LIT_FURNACE_NORTH = BlockData(284, ID!62, META!2);

	public static BlockData LIT_FURNACE_SOUTH = BlockData(285, ID!62, META!3);

	public static BlockData LIT_FURNACE_WEST = BlockData(286, ID!62, META!4);

	public static BlockData LIT_FURNACE_EAST = BlockData(287, ID!62, META!5);

	public static BlockDataArray SIGN = [SIGN_SOUTH, SIGN_SOUTH_SOUTHWEST, SIGN_SOUTHWEST, SIGN_WEST_SOUTHWEST, SIGN_WEST, SIGN_WEST_NORTHWEST, SIGN_NORTH_NORTHWEST, SIGN_NORTH, SIGN_NORTH_NORTHEAST, SIGN_NORTHEAST, SIGN_EAST_NORTHEAST, SIGN_EAST, SIGN_EAST_SOUTHEAST, SIGN_SOUTHEAST, SIGN_SOUTH_SOUTHEAST];
	public alias Sign = TypeTuple!(SignSouth, SignSouthSouthwest, SignSouthwest, SignWestSouthwest, SignWest, SignWestNorthwest, SignNorthNorthwest, SignNorth, SignNorthNortheast, SignNortheast, SignEastNortheast, SignEast, SignEastSoutheast, SignSoutheast, SignSouthSoutheast);

	public static BlockData SIGN_SOUTH = BlockData(288, ID!63, META!0);
	public alias SignSouth = SignBlock!(SIGN_SOUTH, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_SOUTH_SOUTHWEST = BlockData(289, ID!63, META!1);
	public alias SignSouthSouthwest = SignBlock!(SIGN_SOUTH_SOUTHWEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_SOUTHWEST = BlockData(290, ID!63, META!2);
	public alias SignSouthwest = SignBlock!(SIGN_SOUTHWEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_WEST_SOUTHWEST = BlockData(291, ID!63, META!3);
	public alias SignWestSouthwest = SignBlock!(SIGN_WEST_SOUTHWEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_WEST = BlockData(292, ID!63, META!4);
	public alias SignWest = SignBlock!(SIGN_WEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_WEST_NORTHWEST = BlockData(293, ID!63, META!5);
	public alias SignWestNorthwest = SignBlock!(SIGN_WEST_NORTHWEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_NORTHWEST = BlockData(294, ID!63, META!6);
	public alias SignNorthwest = SignBlock!(SIGN_NORTHWEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_NORTH_NORTHWEST = BlockData(295, ID!63, META!7);
	public alias SignNorthNorthwest = SignBlock!(SIGN_NORTH_NORTHWEST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_NORTH = BlockData(296, ID!63, META!8);
	public alias SignNorth = SignBlock!(SIGN_NORTH, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_NORTH_NORTHEAST = BlockData(297, ID!63, META!9);
	public alias SignNorthNortheast = SignBlock!(SIGN_NORTH_NORTHEAST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_NORTHEAST = BlockData(298, ID!63, META!10);
	public alias SignNortheast = SignBlock!(SIGN_NORTHEAST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_EAST_NORTHEAST = BlockData(299, ID!63, META!11);
	public alias SignEastNortheast = SignBlock!(SIGN_EAST_NORTHEAST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_EAST = BlockData(300, ID!63, META!12);
	public alias SignEast = SignBlock!(SIGN_EAST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_EAST_SOUTHEAST = BlockData(301, ID!63, META!13);
	public alias SignEastSoutheast = SignBlock!(SIGN_EAST_SOUTHEAST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_SOUTHEAST = BlockData(302, ID!63, META!14);
	public alias SignSoutheast = SignBlock!(SIGN_SOUTHEAST, SOLID!5, FLAMMABLE);

	public static BlockData SIGN_SOUTH_SOUTHEAST = BlockData(303, ID!63, META!15);
	public alias SignSouthSoutheast = SignBlock!(SIGN_SOUTH_SOUTHEAST, SOLID!5, FLAMMABLE);

	public static BlockDataArray OAK_DOOR = [];

	// TODO shapes
	public static BlockDataArray LADDER = [LADDER_NORTH, LADDER_SOUTH, LADDER_WEST, LADDER_EAST];

	public static BlockData LADDER_NORTH = BlockData(359, ID!65, META!2);
	public alias LadderNorth = MineableBlock!(LADDER_NORTH, SOLID!2, Items.LADDER);

	public static BlockData LADDER_SOUTH = BlockData(360, ID!65, META!3);
	public alias LadderSouth = MineableBlock!(LADDER_SOUTH, SOLID!2, Items.LADDER);

	public static BlockData LADDER_WEST = BlockData(361, ID!65, META!4);
	public alias LadderWest = MineableBlock!(LADDER_WEST, SOLID!2, Items.LADDER);

	public static BlockData LADDER_EAST = BlockData(362, ID!65, META!5);
	public alias LadderEast = MineableBlock!(LADDER_EAST, SOLID!2, Items.LADDER);

	public static BlockDataArray RAIL = [];

	public static BlockDataArray COBBLESTONE_STAIRS = [];

	public static BlockDataArray WALL_SIGN = [WALL_SIGN_NORTH, WALL_SIGN_SOUTH, WALL_SIGN_WEST, WALL_SIGN_EAST];

	public static BlockData WALL_SIGN_NORTH = BlockData(304, ID!68, META!2);
	public alias WallSignNorth = WallSignBlock!(WALL_SIGN_NORTH, SOLID!5, FLAMMABLE);

	public static BlockData WALL_SIGN_SOUTH = BlockData(305, ID!68, META!3);
	public alias WallSignSouth = WallSignBlock!(WALL_SIGN_SOUTH, SOLID!5, FLAMMABLE);

	public static BlockData WALL_SIGN_WEST = BlockData(306, ID!68, META!4);
	public alias WallSignWest = WallSignBlock!(WALL_SIGN_WEST, SOLID!5, FLAMMABLE);

	public static BlockData WALL_SIGN_EAST = BlockData(307, ID!68, META!5);
	public alias WallSignEast = WallSignBlock!(WALL_SIGN_EAST, SOLID!5, FLAMMABLE);


	public static BlockDataArray SNOW_LAYER = [SNOW_LAYER_0, SNOW_LAYER_1, SNOW_LAYER_2, SNOW_LAYER_3, SNOW_LAYER_4, SNOW_LAYER_5, SNOW_LAYER_6, SNOW_LAYER_7];

	public static BlockData SNOW_LAYER_0 = BlockData(143, ID!78, META!0);
	public alias SnowLayer0 = MineableBlock!(SNOW_LAYER_0, SOLID!.5, GRAVITY, REPLACEABLE, SHAPE([0f, 0f, 0f, 1f, 1f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 2);

	public static BlockData SNOW_LAYER_1 = BlockData(144, ID!78, META!1);
	public alias SnowLayer1 = MineableBlock!(SNOW_LAYER_1, SOLID!.5, GRAVITY, SHAPE([0f, 0f, 0f, 1f, 2f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 3);

	public static BlockData SNOW_LAYER_2 = BlockData(145, ID!78, META!2);
	public alias SnowLayer2 = MineableBlock!(SNOW_LAYER_2, SOLID!.5, GRAVITY, SHAPE([0f, 0f, 0f, 1f, 3f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 4);

	public static BlockData SNOW_LAYER_3 = BlockData(146, ID!78, META!3);
	public alias SnowLayer3 = MineableBlock!(SNOW_LAYER_3, SOLID!.5, GRAVITY, SHAPE([0f, 0f, 0f, 1f, 4f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 5);

	public static BlockData SNOW_LAYER_4 = BlockData(147, ID!78, META!4);
	public alias SnowLayer4 = MineableBlock!(SNOW_LAYER_4, SOLID!.5, GRAVITY, SHAPE([0f, 0f, 0f, 1f, 5f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 6);

	public static BlockData SNOW_LAYER_5 = BlockData(148, ID!78, META!5);
	public alias SnowLayer5 = MineableBlock!(SNOW_LAYER_5, SOLID!.5, GRAVITY, SHAPE([0f, 0f, 0f, 1f, 6f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 7);

	public static BlockData SNOW_LAYER_6 = BlockData(149, ID!78, META!6);
	public alias SnowLayer6 = MineableBlock!(SNOW_LAYER_6, SOLID!.5, GRAVITY, SHAPE([0f, 0f, 0f, 1f, 7f/8f, 1f]), TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 8);

	public static BlockData SNOW_LAYER_7 = BlockData(150, ID!78, META!7);
	public alias SnowLayer7 = MineableBlock!(SNOW_LAYER_7, SOLID!.5, TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 9);

	//TODO
	public static BlockData ICE = BlockData(278, ID!79, META!0);
	public alias Ice = SimpleBlock!(ICE, SOLID!.5);


	public static BlockData SNOW = BlockData(279, ID!80, META!0);
	public alias Snow = MineableBlock!(SNOW, SOLID!1, TOOL!(Tool.SHOVEL, Tool.WOODEN), Items.SNOWBALL, 4, SILK_TOUCH, Items.SNOW_BLOCK);

	// TODO
	public static BlockData SUGAR_CANES = BlockData(334, ID!83, META!0);
	public alias SugarCanes = SimpleBlock!(SUGAR_CANES, INSTANT_BREAKING, SHAPELESS);

	//TODO
	public static BlockData OAK_FENCE = BlockData(315, ID!85, META!0);
	public alias OakFence = SimpleBlock!(OAK_FENCE, SOLID!15, FLAMMABLE);

	public static BlockDataArray PUMPKIN = [PUMPKIN_SOUTH, PUMPKIN_WEST, PUMPKIN_NORTH, PUMPKIN_EAST];

	public static BlockData PUMPKIN_SOUTH = BlockData(80, ID!86, META!0);
	public alias PumpkinSouth = MineableBlock!(PUMPKIN_SOUTH, SOLID!5, Items.PUMPKIN);

	public static BlockData PUMPKIN_WEST = BlockData(81, ID!86, META!1);
	public alias PumpkinWest = MineableBlock!(PUMPKIN_WEST, SOLID!5, Items.PUMPKIN);

	public static BlockData PUMPKIN_NORTH = BlockData(82, ID!86, META!2);
	public alias PumpkinNorth = MineableBlock!(PUMPKIN_NORTH, SOLID!5, Items.PUMPKIN);

	public static BlockData PUMPKIN_EAST = BlockData(83, ID!86, META!3);
	public alias PumpkinEast = MineableBlock!(PUMPKIN_EAST, SOLID!5, Items.PUMPKIN);

	public static BlockData SOUL_SAND = BlockData(377, ID!88, META!0);
	public alias SoulSand = MineableBlock!(SOUL_SAND, SOLID!2.5, SHAPE([0f, 0f, 0f, 1f, 15f/16f, 1f]), Items.SOUL_SAND);

	public static BlockData BARRIER = BlockData(84, IDS!(95, 166), META!0);
	public alias INVISIBLE_BEDROCK = BARRIER;
	public alias Barrier = SimpleBlock!(BARRIER, SOLID!(double.infinity));

	public static BlockData MELON = BlockData(85, ID!103, META!0);
	public alias Melon = MineableBlock!(MELON, SOLID!5, Items.MELON, "3..7", SILK_TOUCH, Items.MELON_BLOCK);

	public static BlockDataArray PUMPKIN_STEM = [PUMPKIN_STEM_0, PUMPKIN_STEM_1, PUMPKIN_STEM_2, PUMPKIN_STEM_3, PUMPKIN_STEM_4, PUMPKIN_STEM_5, PUMPKIN_STEM_6, PUMPKIN_STEM_7];

	public static BlockData PUMPKIN_STEM_0 = BlockData(86, ID!104, META!0);
	public alias PumpkinStem0 = CropBlock!(PUMPKIN_STEM_0, PUMPKIN_STEM_1, null);

	public static BlockData PUMPKIN_STEM_1 = BlockData(87, ID!104, META!1);
	public alias PumpkinStem1 = CropBlock!(PUMPKIN_STEM_1, PUMPKIN_STEM_2, null);

	public static BlockData PUMPKIN_STEM_2 = BlockData(88, ID!104, META!2);
	public alias PumpkinStem2 = CropBlock!(PUMPKIN_STEM_2, PUMPKIN_STEM_3, null);

	public static BlockData PUMPKIN_STEM_3 = BlockData(89, ID!104, META!3);
	public alias PumpkinStem3 = CropBlock!(PUMPKIN_STEM_3, PUMPKIN_STEM_4, null);

	public static BlockData PUMPKIN_STEM_4 = BlockData(90, ID!104, META!4);
	public alias PumpkinStem4 = CropBlock!(PUMPKIN_STEM_4, PUMPKIN_STEM_5, null);

	public static BlockData PUMPKIN_STEM_5 = BlockData(91, ID!104, META!5);
	public alias PumpkinStem5 = CropBlock!(PUMPKIN_STEM_5, PUMPKIN_STEM_6, null);

	public static BlockData PUMPKIN_STEM_6 = BlockData(92, ID!104, META!6);
	public alias PumpkinStem6 = CropBlock!(PUMPKIN_STEM_6, PUMPKIN_STEM_7, null);

	public static BlockData PUMPKIN_STEM_7 = BlockData(93, ID!104, META!7);
	public alias PumpkinStem7 = CropBlock!(PUMPKIN_STEM_7, AIR, [Items.PUMPKIN_SEEDS: "1..4"], Blocks.PUMPKIN);

	public static BlockDataArray MELON_STEM = [MELON_STEM_0, MELON_STEM_1, MELON_STEM_2, MELON_STEM_3, MELON_STEM_4, MELON_STEM_5, MELON_STEM_6, MELON_STEM_7];

	public static BlockData MELON_STEM_0 = BlockData(94, ID!105, META!0);
	public alias MelonStem0 = CropBlock!(MELON_STEM_0, MELON_STEM_1, null);

	public static BlockData MELON_STEM_1 = BlockData(95, ID!105, META!1);
	public alias MelonStem1 = CropBlock!(MELON_STEM_1, MELON_STEM_2, null);

	public static BlockData MELON_STEM_2 = BlockData(96, ID!105, META!2);
	public alias MelonStem2 = CropBlock!(MELON_STEM_2, MELON_STEM_3, null);

	public static BlockData MELON_STEM_3 = BlockData(97, ID!105, META!3);
	public alias MelonStem3 = CropBlock!(MELON_STEM_3, MELON_STEM_4, null);

	public static BlockData MELON_STEM_4 = BlockData(98, ID!105, META!4);
	public alias MelonStem4 = CropBlock!(MELON_STEM_4, MELON_STEM_5, null);

	public static BlockData MELON_STEM_5 = BlockData(99, ID!105, META!5);
	public alias MelonStem5 = CropBlock!(MELON_STEM_5, MELON_STEM_6, null);

	public static BlockData MELON_STEM_6 = BlockData(100, ID!105, META!6);
	public alias MelonStem6 = CropBlock!(MELON_STEM_6, MELON_STEM_7, null);

	public static BlockData MELON_STEM_7 = BlockData(101, ID!105, META!7);
	public alias MelonStem7 = CropBlock!(MELON_STEM_7, AIR, [Items.MELON_SEEDS: "1..4"], Blocks.MELON);

	//TODO
	public static BlockDataArray VINES = [VINES_DEFAULT, VINES_SOUTH, VINES_WEST, VINES_NORTH, VINES_EAST];

	public static BlockData VINES_DEFAULT = BlockData(310, ID!106, META!0);
	public alias VinesDefault = SimpleBlock!(VINES_DEFAULT, SOLID!.2, SHAPELESS);

	public static BlockData VINES_SOUTH = BlockData(311, ID!106, META!0b0001);
	public alias VinesSouth = SimpleBlock!(VINES_SOUTH, SOLID!.2, SHAPELESS);

	public static BlockData VINES_WEST = BlockData(312, ID!106, META!0b0010);
	public alias VinesWest = SimpleBlock!(VINES_WEST, SOLID!.2, SHAPELESS);

	public static BlockData VINES_NORTH = BlockData(313, ID!106, META!0b0100);
	public alias VinesNorth = SimpleBlock!(VINES_NORTH, SOLID!.2, SHAPELESS);

	public static BlockData VINES_EAST = BlockData(314, ID!106, META!0b1000);
	public alias VinesEast = SimpleBlock!(VINES_EAST, SOLID!.2, SHAPELESS);

	public static BlockData MYCELIUM = BlockData(102, ID!110, META!0);
	public alias Mycelium = SpreadingBlock!(MYCELIUM, [Blocks.DIRT, Blocks.GRASS, Blocks.PODZOL], 1, 1, 3, 1, Blocks.DIRT, SOLID!3, Items.DIRT, SILK_TOUCH, Items.MYCELIUM);

	public static BlockDataArray CARROT_BLOCK = [CARROT_BLOCK_0, CARROT_BLOCK_1, CARROT_BLOCK_2, CARROT_BLOCK_3, CARROT_BLOCK_4, CARROT_BLOCK_5, CARROT_BLOCK_6, CARROT_BLOCK_7];

	public static BlockData CARROT_BLOCK_0 = BlockData(103, ID!141, META!0);
	public alias CarrotBlock0 = CropBlock!(CARROT_BLOCK_0, CARROT_BLOCK_1, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_1 = BlockData(104, ID!141, META!1);
	public alias CarrotBlock1 = CropBlock!(CARROT_BLOCK_1, CARROT_BLOCK_2, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_2 = BlockData(105, ID!141, META!2);
	public alias CarrotBlock2 = CropBlock!(CARROT_BLOCK_2, CARROT_BLOCK_3, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_3 = BlockData(106, ID!141, META!3);
	public alias CarrotBlock3 = CropBlock!(CARROT_BLOCK_3, CARROT_BLOCK_4, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_4 = BlockData(107, ID!141, META!4);
	public alias CarrotBlock4 = CropBlock!(CARROT_BLOCK_4, CARROT_BLOCK_5, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_5 = BlockData(108, ID!141, META!5);
	public alias CarrotBlock5 = CropBlock!(CARROT_BLOCK_5, CARROT_BLOCK_6, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_6 = BlockData(109, ID!142, META!6);
	public alias CarrotBlock6 = CropBlock!(CARROT_BLOCK_6, CARROT_BLOCK_7, [Items.CARROT: "1"]);

	public static BlockData CARROT_BLOCK_7 = BlockData(110, ID!143, META!7);
	public alias CarrotBlock7 = CropBlock!(CARROT_BLOCK_7, AIR, [Items.CARROT: "1..4"]);

	public static BlockDataArray POTATO_BLOCK = [POTATO_BLOCK_0, POTATO_BLOCK_1, POTATO_BLOCK_2, POTATO_BLOCK_3, POTATO_BLOCK_4, POTATO_BLOCK_5, POTATO_BLOCK_6, POTATO_BLOCK_7];

	public static BlockData POTATO_BLOCK_0 = BlockData(111, ID!142, META!0);
	public alias PotatoBlock0 = CropBlock!(POTATO_BLOCK_0, POTATO_BLOCK_1, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_1 = BlockData(112, ID!142, META!1);
	public alias PotatoBlock1 = CropBlock!(POTATO_BLOCK_1, POTATO_BLOCK_2, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_2 = BlockData(113, ID!142, META!2);
	public alias PotatoBlock2 = CropBlock!(POTATO_BLOCK_2, POTATO_BLOCK_3, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_3 = BlockData(114, ID!142, META!3);
	public alias PotatoBlock3 = CropBlock!(POTATO_BLOCK_3, POTATO_BLOCK_4, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_4 = BlockData(115, ID!142, META!4);
	public alias PotatoBlock4 = CropBlock!(POTATO_BLOCK_4, POTATO_BLOCK_5, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_5 = BlockData(116, ID!142, META!5);
	public alias PotatoBlock5 = CropBlock!(POTATO_BLOCK_5, POTATO_BLOCK_6, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_6 = BlockData(117, ID!142, META!6);
	public alias PotatoBlock6 = CropBlock!(POTATO_BLOCK_6, POTATO_BLOCK_7, [Items.POTATO: "1"]);

	public static BlockData POTATO_BLOCK_7 = BlockData(118, ID!142, META!7);
	public alias PotatoBlock7 = CropBlock!(POTATO_BLOCK_7, AIR, [Items.POTATO: "1..4", Items.POISONOUS_POTATO: "-49..1"]);

	public static BlockData REDSTONE_BLOCK = BlockData(378, ID!152, META!0);
	public alias RedstoneBlock = MineableBlock!(REDSTONE_BLOCK, SOLID!30, HARDNESS!5, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.REDSTONE_BLOCK);

	public static BlockData QUARTZ_BLOCK = BlockData(351, ID!155, META!0);
	public alias QuartzBlock = MineableBlock!(QUARTZ_BLOCK, SOLID!4, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.QUARTZ_BLOCK);

	public static BlockDataArray STAINED_CLAY = [WHITE_STAINED_CLAY, ORANGE_STAINED_CLAY, MAGENTA_STAINED_CLAY, LIGHT_BLUE_STAINED_CLAY, YELLOW_STAINED_CLAY, LIME_STAINED_CLAY, PINK_STAINED_CLAY, GRAY_STAINED_CLAY, LIGHT_GRAY_STAINED_CLAY, CYAN_STAINED_CLAY, PURPLE_STAINED_CLAY, BLUE_STAINED_CLAY, BROWN_STAINED_CLAY, GREEN_STAINED_CLAY, RED_STAINED_CLAY, BLACK_STAINED_CLAY];
	
	public static BlockData WHITE_STAINED_CLAY = BlockData(119, ID!159, META!0);
	public alias WhiteStainedClay = MineableBlock!(WHITE_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.WHITE_STAINED_CLAY);
	
	public static BlockData ORANGE_STAINED_CLAY = BlockData(120, ID!159, META!1);
	public alias OrangeStainedClay = MineableBlock!(ORANGE_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.ORANGE_STAINED_CLAY);
	
	public static BlockData MAGENTA_STAINED_CLAY = BlockData(121, ID!159, META!2);
	public alias MagentaStainedClay = MineableBlock!(MAGENTA_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.MAGENTA_STAINED_CLAY);
	
	public static BlockData LIGHT_BLUE_STAINED_CLAY = BlockData(122, ID!159, META!3);
	public alias LightBlueStainedClay = MineableBlock!(LIGHT_BLUE_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.LIGHT_BLUE_STAINED_CLAY);
	
	public static BlockData YELLOW_STAINED_CLAY = BlockData(123, ID!159, META!4);
	public alias YellowStainedClay = MineableBlock!(YELLOW_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.YELLOW_STAINED_CLAY);
	
	public static BlockData LIME_STAINED_CLAY = BlockData(124, ID!159, META!5);
	public alias LimeStainedClay = MineableBlock!(LIME_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.LIME_STAINED_CLAY);
	
	public static BlockData PINK_STAINED_CLAY = BlockData(125, ID!159, META!6);
	public alias PinkStainedClay = MineableBlock!(PINK_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.PINK_STAINED_CLAY);
	
	public static BlockData GRAY_STAINED_CLAY = BlockData(126, ID!159, META!7);
	public alias GrayStainedClay = MineableBlock!(GRAY_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.GRAY_STAINED_CLAY);
	
	public static BlockData LIGHT_GRAY_STAINED_CLAY = BlockData(127, ID!159, META!8);
	public alias LightGrayStainedClay = MineableBlock!(LIGHT_GRAY_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.LIGHT_GRAY_STAINED_CLAY);
	
	public static BlockData CYAN_STAINED_CLAY = BlockData(128, ID!159, META!9);
	public alias CyanStainedClay = MineableBlock!(CYAN_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.CYAN_STAINED_CLAY);
	
	public static BlockData PURPLE_STAINED_CLAY = BlockData(130, ID!159, META!10);
	public alias PurpleStainedClay = MineableBlock!(PURPLE_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.PURPLE_STAINED_CLAY);
	
	public static BlockData BLUE_STAINED_CLAY = BlockData(131, ID!159, META!11);
	public alias BlueStainedClay = MineableBlock!(BLUE_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.BLUE_STAINED_CLAY);
	
	public static BlockData BROWN_STAINED_CLAY = BlockData(132, ID!159, META!12);
	public alias BrownStainedClay = MineableBlock!(BROWN_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.BROWN_STAINED_CLAY);
	
	public static BlockData GREEN_STAINED_CLAY = BlockData(133, ID!159, META!13);
	public alias GreenStainedClay = MineableBlock!(GREEN_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.GREEN_STAINED_CLAY);
	
	public static BlockData RED_STAINED_CLAY = BlockData(134, ID!159, META!14);
	public alias RedStainedClay = MineableBlock!(RED_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.RED_STAINED_CLAY);
	
	public static BlockData BLACK_STAINED_CLAY = BlockData(135, ID!159, META!15);
	public alias BlackStainedClay = MineableBlock!(BLACK_STAINED_CLAY, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.BLACK_STAINED_CLAY);


	public static BlockData SLIME_BLOCK = BlockData(333, ID!165, META!0);
	public alias SlimeBlock = MineableBlock!(SLIME_BLOCK, INSTANT_BREAKING, NO_FALL_DAMAGE, Items.SLIME_BLOCK);


	public static BlockDataArray CARPET = [WHITE_CARPET, ORANGE_CARPET, MAGENTA_CARPET, LIGHT_BLUE_CARPET, YELLOW_CARPET, LIME_CARPET, PINK_CARPET, GRAY_CARPET, LIGHT_GRAY_CARPET, CYAN_CARPET, PURPLE_CARPET, BLUE_CARPET, BROWN_CARPET, GREEN_CARPET, RED_CARPET, BLACK_CARPET];
	
	public static BlockData WHITE_CARPET = BlockData(316, ID!171, META!0);
	public alias WhiteCarpet = MineableBlock!(WHITE_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.WHITE_CARPET);
	
	public static BlockData ORANGE_CARPET = BlockData(317, ID!171, META!1);
	public alias OrangeCarpet = MineableBlock!(ORANGE_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.ORANGE_CARPET);
	
	public static BlockData MAGENTA_CARPET = BlockData(318, ID!171, META!2);
	public alias MagentaCarpet = MineableBlock!(MAGENTA_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.MAGENTA_CARPET);
	
	public static BlockData LIGHT_BLUE_CARPET = BlockData(319, ID!171, META!3);
	public alias LightBlueCarpet = MineableBlock!(LIGHT_BLUE_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.LIGHT_BLUE_CARPET);
	
	public  static BlockData YELLOW_CARPET = BlockData(320, ID!171, META!4);
	public alias YellowCarpet = MineableBlock!(YELLOW_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.YELLOW_CARPET);
	
	public static BlockData LIME_CARPET = BlockData(321, ID!171, META!5);
	public alias LimeCarpet = MineableBlock!(LIME_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.LIME_CARPET);
	
	public static BlockData PINK_CARPET = BlockData(322, ID!171, META!6);
	public alias PinkCarpet = MineableBlock!(PINK_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.PINK_CARPET);
	
	public static BlockData GRAY_CARPET = BlockData(323, ID!171, META!7);
	public alias GrayCarpet = MineableBlock!(GRAY_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.GRAY_CARPET);
	
	public static BlockData LIGHT_GRAY_CARPET = BlockData(324, ID!171, META!8);
	public alias LightGrayCarpet = MineableBlock!(LIGHT_GRAY_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.LIGHT_GRAY_CARPET);
	
	public static BlockData CYAN_CARPET = BlockData(325, ID!171, META!9);
	public alias CyanCarpet = MineableBlock!(CYAN_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.CYAN_CARPET);
	
	public static BlockData PURPLE_CARPET = BlockData(326, ID!171, META!10);
	public alias PurpleCarpet = MineableBlock!(PURPLE_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.PURPLE_CARPET);
	
	public static BlockData BLUE_CARPET = BlockData(327, ID!171, META!11);
	public alias BlueCarpet = MineableBlock!(BLUE_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.BLUE_CARPET);
	
	public static BlockData BROWN_CARPET = BlockData(328, ID!171, META!12);
	public alias BrownCarpet = MineableBlock!(BROWN_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.BROWN_CARPET);
	
	public static BlockData GREEN_CARPET = BlockData(329, ID!171, META!13);
	public alias GreenCarpet = MineableBlock!(GREEN_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.GREEN_CARPET);
	
	public static BlockData RED_CARPET = BlockData(330, ID!171, META!14);
	public alias RedCarpet = MineableBlock!(RED_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.RED_CARPET);

	public static BlockData BLACK_CARPET = BlockData(331, ID!171, META!15);
	public alias BlackCarpet = MineableBlock!(BLACK_CARPET, SOLID!.5, FLAMMABLE, SHAPE([0, 0, 0, 1, .0625, 1]), Items.BLACK_CARPET);



	//TODO
	public static BlockData PACKED_ICE = BlockData(310, ID!174, META!0);
	public alias PackedIce = SimpleBlock!(PACKED_ICE, SOLID!2.5);


	public static BlockData COAL_BLOCK = BlockData(129, ID!173, META!0);
	public alias CoalBlock = MineableBlock!(COAL_BLOCK, TOOL!(Tool.PICKAXE, Tool.WOODEN), Items.COAL_BLOCK);

	public static BlockData GRASS_PATH = BlockData(136, IDS!(198, 208), META!0);
	public alias GrassPath = MineableBlock!(GRASS_PATH, SOLID!3, Items.DIRT, SHAPE([0, 0, 0, 1, 15/16, 1]));


	public static BlockData PODZOL = BlockData(137, IDS!(243, 3), METAS!(0, 2));
	public alias Podzol = MineableBlock!(PODZOL, SOLID!2.5, Items.DIRT);

	public static BlockDataArray BEETROOT_BLOCK = [BEETROOT_BLOCK_0, BEETROOT_BLOCK_1, BEETROOT_BLOCK_2, BEETROOT_BLOCK_3];

	public static BlockData BEETROOT_BLOCK_0 = BlockData(138, IDS!(244, 207), META!0);
	public alias BeetrootBlock0 = CropBlock!(BEETROOT_BLOCK_0, BEETROOT_BLOCK_1, [Items.BEETROOT_SEEDS: "1"]);

	public static BlockData BEETROOT_BLOCK_1 = BlockData(139, IDS!(244, 207), META!1);
	public alias BeetrootBlock1 = CropBlock!(BEETROOT_BLOCK_1, BEETROOT_BLOCK_2, [Items.BEETROOT_SEEDS: "1"]);

	public static BlockData BEETROOT_BLOCK_2 = BlockData(140, IDS!(244, 207), META!2);
	public alias BeetrootBlock2 = CropBlock!(BEETROOT_BLOCK_2, BEETROOT_BLOCK_3, [Items.BEETROOT_SEEDS: "1"]);

	public static BlockData BEETROOT_BLOCK_3 = BlockData(141, IDS!(246, 107), META!3);
	public alias BeetrootBlock3 = CropBlock!(BEETROOT_BLOCK_3, AIR, [Items.BEETROOT_SEEDS: "0..3", Items.BEETROOT: "1"]);



	//public static PORTAL = [];

	public static BlockData PORTAL_REPLACEMENT = BlockData(332, ID!95, META!2);
	public alias PortalReplacement = SimpleBlock!(PORTAL_REPLACEMENT);

	public static BlockData PORTAL = BlockData(332, ID!90, META!1);
	public alias Portal = SimpleBlock!(PORTAL);




	public static BlockDataArray ORE = [COAL_ORE, IRON_ORE, GOLD_ORE, DIAMOND_ORE, LAPIS_LAZULI_ORE/*, REDSTONE_ORE, EMERALD_ORE*/];

	/*AIR = 0,
	STONE = 1,
	GRASS = 2,
	DIRT = 3,
	COBBLESTONE = 4,
	WOODEN_PLANKS = 5,
	SAPLING = 6,
	BEDROCK = 7,
	WATER = 8,
	STILL_WATER = 9,
	LAVA = 10,
	STILL_LAVA = 11,
	SAND = 12,
	GRAVEL = 13,
	GOLD_ORE = 14,
	IRON_ORE = 15,
	COAL_ORE = 16,
	WOOD = 17,
	LEAVES = 18,
	SPONGE = 19,
	GLASS = 20,
	LAPIS_LAZULI_ORE = 21,
	LAPIS_LAZULI_BLOCK = 22,
	DISPENSER = 23,
	SANDSTONE = 24,
	NOTE_BLOCK = 25,
	BED_BLOCK = 26, //
	POWERED_RAIL = 27,
	DETECTOR_RAIL = 28,
	COBWEB = 30,
	TALL_GRASS = 31,
	BUSH = 32,
	DEAD_BUSH = 32,
	WOOL = 35,
	DANDELION = 37,
	ROSE = 38,
	POPPY = 38,
	RED_FLOWER = 38,
	BROWN_MUSHROOM = 39,
	RED_MUSHROOM = 40,
	GOLD_BLOCK = 41,
	IRON_BLOCK = 42,
	DOUBLE_SLAB = 43,
	DOUBLE_SLABS = 43,
	SLAB = 44,
	SLABS = 44,
	BRICKS = 45,
	BRICKS_BLOCK = 45,
	TNT = 46,
	BOOKSHELF = 47,
	MOSS_STONE = 48,
	MOSSY_STONE = 48,
	OBSIDIAN = 49,
	TORCH = 50,
	FIRE = 51,
	MONSTER_SPAWNER = 52,
	WOOD_STAIRS = 53,
	WOODEN_STAIRS = 53,
	OAK_WOOD_STAIRS = 53,
	OAK_WOODEN_STAIRS = 53,
	CHEST = 54,
	REDSTONE_WIRE = 55,
	DIAMOND_ORE = 56,
	DIAMOND_BLOCK = 57,
	CRAFTING_TABLE = 58,
	WORKBENCH = 58,
	WHEAT_BLOCK = 59,
	FARMLAND = 60,
	FURNACE = 61,
	BURNING_FURNACE = 62,
	LIT_FURNACE = 62,
	SIGN_POST = 63,
	DOOR_BLOCK = 64,
	WOODEN_DOOR_BLOCK = 64,
	WOOD_DOOR_BLOCK = 64,
	LADDER = 65,
	COBBLE_STAIRS = 67,
	COBBLESTONE_STAIRS = 67,
	WALL_SIGN = 68,
	IRON_DOOR_BLOCK = 71,
	LEVER = 69,
	STONE_PRESSURE_PLATE = 70,
	WOODEN_PRESSURE_PLATE = 72,
	REDSTONE_ORE = 73,
	GLOWING_REDSTONE_ORE = 74,
	LIT_REDSTONE_ORE = 74,
	UNLIT_REDSTONE_TORCH = 75,
	REDSTONE_TORCH = 76,
	STONE_BUTTON = 77,
	SNOW = 78,
	SNOW_LAYER = 78,
	ICE = 79,
	SNOW_BLOCK = 80,
	CACTUS = 81,
	CLAY_BLOCK = 82,
	REEDS = 83,
	SUGARCANE_BLOCK = 83,
	FENCE = 85,
	PUMPKIN = 86,
	NETHERRACK = 87,
	SOUL_SAND = 88,
	GLOWSTONE = 89,
	GLOWSTONE_BLOCK = 89,
	PORTAL = 90,
	LIT_PUMPKIN = 91,
	JACK_O_LANTERN = 91,
	CAKE_BLOCK = 92,
	INVISIBLE_BEDROCK = 95,
	TRAPDOOR = 96,
	WOODEN_TRAPDOOR = 96,
	WOOD_TRAPDOOR = 96,
	MONSTER_EGG_BLOCK = 97,
	STONE_BRICKS = 98,
	STONE_BRICK = 98,
	BROWN_MUSHROOM_BLOCK = 99,
	RED_MUSHROOM_BLOCK = 100,
	IRON_BAR = 101,
	IRON_BARS = 101,
	GLASS_PANE = 102,
	GLASS_PANEL = 102,
	MELON_BLOCK = 103,
	PUMPKIN_STEM = 104,
	MELON_STEM = 105,
	VINE = 106,
	VINES = 106,
	FENCE_GATE = 107,
	BRICK_STAIRS = 108,
	STONE_BRICK_STAIRS = 109,
	MYCELIUM = 110,
	WATER_LILY = 111,
	LILY_PAD = 111,
	NETHER_BRICKS = 112,
	NETHER_BRICK_BLOCK = 112,
	NETHER_BRICKS_STAIRS = 114,
	ENCHANTING_TABLE = 116,
	ENCHANT_TABLE = 116,
	ENCHANTMENT_TABLE = 116,
	BREWING_STAND = 117,
	CAULDRON = 118,
	END_PORTAL_FRAME = 120,
	END_STONE = 121,
	INACTIVE_REDSTONE_LAMP = 123,
	ACTIVE_REDSTONE_LAMP = 124,
	DROPPER = 125,
	ACTIVATOR_RAIL = 126,
	COCOA_BLOCK = 127,
	SANDSTONE_STAIRS = 128,
	EMERALD_ORE = 129,
	TRIPWIRE_HOOK = 131,
	TRIPWIRE = 132,
	EMERALD_BLOCK = 133,
	SPRUCE_WOOD_STAIRS = 134,
	SPRUCE_WOODEN_STAIRS = 134,
	BIRCH_WOOD_STAIRS = 135,
	BIRCH_WOODEN_STAIRS = 135,
	JUNGLE_WOOD_STAIRS = 136,
	JUNGLE_WOODEN_STAIRS = 136,
	COBBLE_WALL = 139,
	STONE_WALL = 139,
	COBBLESTONE_WALL = 139,
	FLOWER_POT_BLOCK = 140,
	CARROT_BLOCK = 141,
	POTATO_BLOCK = 142,
	WOODEN_BUTTON = 143,
	SKULL_BLOCK = 144,
	ANVIL = 145,
	TRAPPED_CHEST = 146,
	LIGHT_WEIGHTED_PRESSURE_PLATE = 147,
	HEAVY_WEIGHTED_PRESSURE_PLATE = 148,
	DAYLIGHT_SENSOR = 151,
	DAYLIGHT_SENSOR_INVERTED = 178,
	REDSTONE_BLOCK = 152,
	NETHER_QUARTZ_ORE = 153,
	QUARTZ_BLOCK = 155,
	QUARTZ_STAIRS = 156,
	DOUBLE_WOOD_SLAB = 157,
	DOUBLE_WOODEN_SLAB = 157,
	DOUBLE_WOOD_SLABS = 157,
	DOUBLE_WOODEN_SLABS = 157,
	WOOD_SLAB = 158,
	WOODEN_SLAB = 158,
	WOOD_SLABS = 158,
	WOODEN_SLABS = 158,
	STAINED_CLAY = 159,
	STAINED_HARDENED_CLAY = 159,
	LEAVES2 = 161,
	LEAVE2 = 161,
	WOOD2 = 162,
	TRUNK2 = 162,
	LOG2 = 162,
	ACACIA_WOOD_STAIRS = 163,
	ACACIA_WOODEN_STAIRS = 163,
	DARK_OAK_WOOD_STAIRS = 164,
	DARK_OAK_WOODEN_STAIRS = 164,
	IRON_TRAPDOOR = 167,
	HAY_BALE = 170,
	CARPET = 171,
	HARDENED_CLAY = 172,
	COAL_BLOCK = 173,
	PACKED_ICE = 174,
	DOUBLE_PLANT = 175,
	RED_SANDSTONE = 179,
	FENCE_GATE_SPRUCE = 183,
	FENCE_GATE_BIRCH = 184,
	FENCE_GATE_JUNGLE = 185,
	FENCE_GATE_DARK_OAK = 186,
	FENCE_GATE_ACACIA = 187,
	SPRUCE_DOOR_BLOCK = 193,
	BIRCH_DOOR_BLOCK = 194,
	JUNGLE_DOOR_BLOCK = 195,
	ACACIA_DOOR_BLOCK = 196,
	DARK_OAK_DOOR_BLOCK = 197,
	GRASS_PATH = 198,
	ITEM_FRAME = 199,
	PODZOL = 243,
	BEETROOT_BLOCK = 244,
	STONECUTTER = 245,
	GLOWING_OBSIDIAN = 246,
	NETHER_REACTOR = 247,*/

}

/**
 * Enumeration with the types of block updates.
 * PLACED = called only once, when the block is placed in the world
 * REMOVED = called only once, when the block is removed/replaced in the world
 * NEAREST_CHANGED = called when a nearest block has been placed/removed/replaced
 * NEAREST_FLOWEST = called when a nearest block is liquid and has changed its status
 * BURNT = called when a block has burnt out and is going to be removed
 * REDSTONE_SIGNAL = called when a nearest block releases a direct redstone signal (e.g. a button), the power can be obtained through Block::power
 * MISS_REDSTONE_SIGNAL = opposite as REDSTONE_SIGNAL
 */
enum Update {

	PLACED,
	REMOVED,
	NEAREST_CHANGED,
	NEAREST_FLOWED,

	BURNT,

	REDSTONE_SIGNAL,
	MISS_REDSTONE_SIGNAL,

}

/** Base class for every block */
abstract class Block {

	public static const(BlockPosition) UP = BlockPosition(0, 1, 0);
	public static const(BlockPosition) DOWN = BlockPosition(0, -1, 0);
	public static const(BlockPosition) NORTH = BlockPosition(0, 0, -1);
	public static const(BlockPosition) SOUTH = BlockPosition(0, 0, 1);
	public static const(BlockPosition) EAST = BlockPosition(1, 0, 0);
	public static const(BlockPosition) WEST = BlockPosition(-1, 0, 0);

	protected bool n_no_box;
	protected BlockAxis n_box;

	private ubyte n_power = 0;
	private ubyte n_powered_from = 255;

	/**
	 * Gets the block's data, with SEL id, Minecraft
	 * and Minecraft: Pocket Edition's ids and metas.
	 */
	public abstract pure nothrow @property @safe @nogc BlockData data();

	/// Gets the block's SEL id.
	public abstract pure nothrow @property @safe @nogc ushort id();

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
	 * Gets the blast resistance, used for calculate
	 * the resistance at the explosion of solid blocks.
	 */
	public abstract @property @safe @nogc double blastResistance();

	/**
	 * Boolean value indicating whether or not the block is
	 * broken instantly without damaging the tool used to break it.
	 */
	public abstract @property @safe @nogc bool instantBreaking();

	/**
	 * Boolean value indicating whether or not the block is replaced
	 * when touched with a placeable item.
	 */
	public abstract @property @safe @nogc bool replaceable();

	/**
	 * Boolean value indicating whether or not the block can be burnt.
	 */
	public abstract @property @safe @nogc bool flammable();

	/**
	 * Boolean value indicating whether or not the block is a fluid.
	 */
	public @property @safe @nogc bool fluid() {
		return false;
	}

	/**
	 * Boolean value indicating whether or not the block can cause fall damage.
	 */
	public abstract @property @safe @nogc bool noFallDamage();

	/**
	 * Boolean value indicating whether or not the block has
	 * a collision box where entities can collide.
	 */
	public final @property @safe @nogc bool nobox() {
		return this.n_no_box;
	}

	/**
	 * If nobox is false, returns the bounding box of the block
	 * as an Axis instance.
	 * Values are from 0 to 1
	 */
	public final @property @safe @nogc BlockAxis box() {
		return this.n_box;
	}

	/**
	 * Get the dropped items as a slot array.
	 * Params:
	 * 		player = the player who broke the block, can be null (e.g. explosion, fire...)
	 * 		item = item used to break the block, is null if player is null or the player broke the block with his hand
	 * Returns: a slot array with the dropped items
	 */
	public Slot[] drops(Player player, Item item) {
		return [];
	}

	/**
	 * Get the amount of dropped xp when the block is broken
	 * Params:
	 * 		player = the player who broke the block, can be null (e.g. explosion, fire...)
	 * 		item = item used to break the block, is null if player is null or the player broke the block with his hand
	 * Returns: an integer, indicating the amount of xp that will be spawned
	 */
	public uint xp(Player player, Item item) {
		return 0;
	}

	/**
	 * Function called when a player right-click the block.
	 * Blocks like tile should use this function for handle
	 * the interaction.
	 * N.B. That this function will no be called if the player shifts
	 *	 while performing the right-click/scrren-tap.
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
	 * Boolean value indicating whether or not the block can receive a
	 * random tick. This property is only requested when the block is placed.
	 */
	public @property @safe @nogc bool doRandomTick() {
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
	public void onUpdate(World world, BlockPosition position, Update type) {}

	/**
	 * Function called by the world after a requets made
	 * by the block using World::scheduleBlockUpdate if
	 * the rule in the world is activated.
	 */
	public void onScheduledUpdate(World world, BlockPosition position) {}

	/**
	 * Boolean value indicating whether or not this block
	 * can see the sky (has no blocks over it).
	 */
	public final @safe bool seesSky(World world, BlockPosition position) {
		foreach(uint i ; position.y+1..Chunk.HEIGHT) {
			if(world[position.x, i, position.z] != Blocks.AIR) return false;
		}
		return true;
	}

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
	public final @safe bool breathe(World world, BlockPosition position, bool checkFluid=true) {
		Block up = world[position + [0, 1, 0]];
		return up.blastResistance == 0 && (!checkFluid || !up.fluid);
	}

	/**
	 * Boolean value indicating whether or not there's air
	 * under the block.
	 */
	public final @safe bool floating(World world, BlockPosition position) {
		return world[position - [0, 1, 0]] == Blocks.AIR;
	}

	/**
	 * Compare the block names.
	 * Example:
	 * ---
	 * // one block
	 * assert(new Blocks.Dirt() == Blocks.DIRT);
	 * 
	 * // a group of blocks
	 * assert(new Blocks.Grass() == [Blocks.DIRT, Blocks.GRASS, Blocks.GRASS_PATH]);
	 * ---
	 */
	public @safe bool opEquals(ushort block) {
		return this.id == block;
	}

	/// ditto
	public @safe bool opEquals(ushort[] blocks) {
		return blocks.canFind(this.id);
	}

	/// ditto
	public @safe bool opEquals(BlockData block) {
		return this.opEquals(block.id);
	}

	/// ditto
	public @safe bool opEquals(BlockDataArray blocks) {
		foreach(BlockData block ; blocks) {
			if(this.opEquals(block)) return true;
		}
		return false;
	}

	public override @safe string toString() {
		return "Block(" ~ to!string(this.id) ~ ", pe(" ~ to!string(this.ids.pe) ~ ", " ~ to!string(this.metas.pe) ~ "), pc(" ~ to!string(this.ids.pc) ~ ", " ~ to!string(this.metas.pc) ~ "))";
	}

}

class SimpleBlock(BlockData blockdata, E...) : Block {

	private bool box_initializated = false;

	public @safe this() {
		ShapeFlag sf;
		static if(staticInstanceIndex!(ShapeFlag, E) >= 0) {
			sf = E[staticInstanceIndex!(ShapeFlag, E)];
		} else {
			sf = FULLSHAPE;
		}
		if(sf.shape.length == 6) {
			this.n_no_box = false;
			this.n_box = new BlockAxis(sf.shape[0], sf.shape[1], sf.shape[2], sf.shape[3], sf.shape[4], sf.shape[5]);
		} else {
			this.n_no_box = true;
		}
	}

	public final override pure nothrow @property @safe @nogc BlockData data() {
		return blockdata;
	}

	public final override pure nothrow @property @safe @nogc ushort id() {
		return blockdata.id;
	}

	public final override pure nothrow @property @safe @nogc bytegroup ids() {
		return blockdata.ids;
	}

	public final override pure nothrow @property @safe @nogc bytegroup metas() {
		return blockdata.metas;
	}

	public final override pure nothrow @property @safe @nogc double blastResistance() {
		static if(staticInstanceIndex!(SolidFlag, E) >= 0) {
			return E[staticInstanceIndex!(SolidFlag, E)].blastResistance;
		} else {
			return 0;
		}
	}

	public final override pure nothrow @property @safe @nogc bool instantBreaking() {
		static if(staticIndexOf!(INSTANT_BREAKING, E) >= 0) return true;
		else return false;
	}

	public final override pure nothrow @property @safe @nogc bool replaceable() {
		static if(staticIndexOf!(REPLACEABLE, E) >= 0) return true;
		else return false;
	}

	public final override pure nothrow @property @safe @nogc bool flammable() {
		static if(staticIndexOf!(FLAMMABLE, E) >= 0) return true;
		else return false;
	}

	public final override pure nothrow @property @safe @nogc bool noFallDamage() {
		static if(staticIndexOf!(NO_FALL_DAMAGE, E) >= 0) return true;
		else return false;
	}
	
	public override void onUpdate(World world, BlockPosition position, Update update) {
		static if(staticIndexOf!(GRAVITY, E) >= 0) {
			if(update != Update.REMOVED && this.floating(world, position)) {
				world[position] = Blocks.AIR;
				world.spawn!FallingBlock(this.data, position);
			}
		}
	}

	public override pure nothrow @property @safe @nogc bool doRandomTick() {
		static if(staticIndexOf!(RANDOM_TICK, E) >= 0) return true;
		else return false;
	}

}

/**
 * Class for simple blocks that can drop something.
 * Example:
 * ---
 * // block that drops a beetroot
 * alias A = MineableBlock!(DataA, Items.BEETROOT);
 * 
 * // block that drops a random number of beetroots in range 10 and 60
 * alias B = MineableBlock!(DataB, Items.BEETROOT, "10..60");
 * 
 * // block that can only be mined with an iron pickaxe (or better)
 * alias C = MineableBlock!(DataC, TOOL!(Tool.PICKAXE, Tool.IRON), Items.DIAMOND, "3..4");
 * 
 * // block that change drops when mined with a silk touch-enchanted item
 * alias D = MineableBlock!(DataD, Items.COAL, SILK_TOUCH, Items.COAL_ORE);
 * 
 * // block that change drops when mined with a fortune-enchanted pickaxe
 * // "level" is the variable with the item's fortune level (from 1 to 255)
 * alias E = MineableBlock!(DataE, Items.COAL, "2..4", FORTUNE, "random.range(4, 8) * level");
 * 
 * // array that drops more than 1 type of items
 * alias F = MineableBlock!(DataF, [Items.EMERALD: "1", Items.DIAMOND: "1..3"]);
 * ---
 */
class MineableBlock(BlockData blockdata, E...) : SimpleBlock!(blockdata, E) if(isValidMineableBlock!E) {

	public override @safe Slot[] drops(Player player, Item item) {
		// tool
		static if(staticInstanceIndex!(ToolFlag, E) >= 0) {
			// validate the tool
			if(item is null) return [];
			auto tool = E[staticInstanceIndex!(ToolFlag, E)];
			if(item.toolType != tool.type || item.toolMaterial != tool.material) return [];
		}
		// silk touch
		static if(staticIndexOf!(SILK_TOUCH, E) >= 0) {
			if(item !is null && item.hasEnchantment(Enchantments.SILK_TOUCH)) {
				return [Slot(player.world.items.get(E[staticIndexOf!(SILK_TOUCH, E)]), 1)];
			}
		}
		// TODO fortune enchantment
		// TODO array of drops
		// normal drop
		foreach(uint index, F; E) {
			static if((is(typeof(F) == string) || is(typeof(F) == immutable string)) && (index == 0 || staticInstanceIndex!(ToolFlag, E) != index - 1)) {
				if(player.world.items.has(F)) {
					static if(index < E.length - 1 && (is(typeof(E[index + 1]) == int) || is(typeof(E[index + 1]) == uint) || ((is(typeof(E[index + 1]) == string) || is(typeof(E[index + 1]) == immutable string)) && isValidRange!(E[index + 1], int)))) {
						Slot[] ret;
						static if(is(typeof(E[index + 1]) == int) || is(typeof(E[index + 1]) == uint) || E[index + 1].split("..").length == 1) {
							foreach(uint i ; 0..E[index + 1].to!int) {
								ret ~= Slot(player.world.items.get(F), 1);
							}
						} else {
							int amount = player.world.random.next(E[index + 1].split("..")[0].to!int, E[index + 1].split("..")[1].to!int);
							if(amount > 0) {
								foreach(uint i ; 0..amount) {
									ret ~= Slot(player.world.items.get(F), 1);
								}
							}
						}
						return ret;
					} else {
						return [Slot(player.world.items.get(F), 1)];
					}
				}
			}
		}
		return [];
	}

}

//TODO
private bool isValidMineableBlock(E...)() {
	return true;
}

private bool isValidRange(string s, T=uint)() {
	static if(s.split("..").length == 2) {
		return isValidRange!(s.split("..")[0], T) && isValidRange!(s.split("..")[1], T);
	} else {
		try {
			T conv = to!T(s);
			return true;
		} catch(ConvException e) {
			return false;
		}
	}
}

/**
 * Placed block in a world, used when a position is needed
 * but the block can be null.
 */
struct PlacedBlock {

	private BlockPosition n_position;
	private BlockData n_block;

	public @safe @nogc this(BlockPosition position, BlockData block) {
		this.n_position = position;
		this.n_block = block;
	}

	public @property @safe @nogc BlockPosition position() {
		return this.n_position;
	}

	public @property @safe @nogc BlockData block() {
		return this.n_block;
	}

	alias block this;

}

public @property @safe int blockInto(float value) {
	if(value < 0) return (-value).ceil.to!int * -1;
	else return value.to!int;
}

/** Most used blocks' shapes */
enum Shapes : float[] {

	FULL = [0f, 0f, 0f, 1f, 1f, 1f],
	POT = [.3125f, 0f, .3125f, .6825f, .375f, .6825f],
	THREE_FOURTH = [0f, 0f, 0f, 1f, .75f, 1f],
	BREWING_STAND = [.4375f, 0f, .4375f, .5625f, .875f, .5625f],

}
