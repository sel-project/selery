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
module sel.item.item;

import std.array : split;
import std.conv : to;
import std.json;
import std.traits : isIntegral;
import std.typetuple : staticIndexOf;

import common.sel;

import sel.player : Player;
import sel.block.block : Block, PlacedBlock, Blocks, BlockData;
import sel.entity.effect : EffectInfo, effectInfo, Effect, Effects, Potions;
import sel.entity.entity : Entity;
import sel.entity.human : Human;
import sel.entity.interfaces : Arthropods, Undead;
import sel.entity.projectile : FallingBlock;
import sel.item.enchanting;
import sel.item.flags;
import sel.item.miscellaneous;
import sel.item.slot : Slot;
import sel.item.tool;
import sel.math.vector : BlockPosition, face;
import sel.nbt.tags : Compound, DefinedCompound, List, ListOf, Short, String;
import sel.util;
import sel.util.color : Color;
import sel.util.lang : GenericTranslatable = Translatable;
import sel.world.world : World;

public final class Items {

	@disable this();

	public static immutable string AIR = "air";

	public static immutable string STONE = "stone";
	public static alias Stone = PlaceableItem!(STONE, ID!1, META!0, Blocks.STONE);

	public static immutable string GRANITE = "granite";
	public static alias Granite = PlaceableItem!(GRANITE, ID!1, META!1, Blocks.GRANITE);

	public static immutable string POLISHED_GRANITE = "polishedGranite";
	public static alias PolishedGranite = PlaceableItem!(POLISHED_GRANITE, ID!1, META!2, Blocks.POLISHED_GRANITE);

	public static immutable string DIORITE = "diorite";
	public static alias Diorite = PlaceableItem!(DIORITE, ID!1, META!3, Blocks.DIORITE);

	public static immutable string POLISHED_DIORITE = "polishedDiorite";
	public static alias PolishedDiorite = PlaceableItem!(POLISHED_DIORITE, ID!1, META!4, Blocks.POLISHED_DIORITE);

	public static immutable string ANDESITE = "andesite";
	public static alias Andesite = PlaceableItem!(ANDESITE, ID!1, META!5, Blocks.ANDESITE);

	public static immutable string POLISHED_ANDESITE = "polishedAndesite";
	public static alias PolishedAndesite = PlaceableItem!(POLISHED_ANDESITE, ID!1, META!6, Blocks.POLISHED_ANDESITE);

	public static immutable string GRASS = "grass";
	public static alias Grass = PlaceableItem!(GRASS, ID!2, META!0, Blocks.GRASS);

	public static immutable string DIRT = "dirt";
	public static alias Dirt = PlaceableItem!(DIRT, ID!3, META!0, Blocks.DIRT);

	public static immutable string COBBLESTONE = "cobblestone";
	public static alias Cobblestone = PlaceableItem!(COBBLESTONE, ID!4, META!0, Blocks.COBBLESTONE);

	public static enum WOODEN_PLANKS = [OAK_WOODEN_PLANKS, SPRUCE_WOODEN_PLANKS, BIRCH_WOODEN_PLANKS, JUNGLE_WOODEN_PLANKS, ACACIA_WOODEN_PLANKS, DARK_OAK_WOODEN_PLANKS];
	public static alias WoodenPlanks(string name, shortgroup metas, BlockData place) = PlaceableItem!(name, ID!5, metas, place);

	public static immutable string OAK_WOODEN_PLANKS = "oakWoodenPlanks";
	public static alias OakWoodenPlanks = WoodenPlanks!(OAK_WOODEN_PLANKS, META!0, Blocks.OAK_WOODEN_PLANKS);

	public static immutable string SPRUCE_WOODEN_PLANKS = "spruceWoodenPlanks";
	public static alias SpruceWoodenPlanks = WoodenPlanks!(SPRUCE_WOODEN_PLANKS, META!1, Blocks.SPRUCE_WOODEN_PLANKS);

	public static immutable string BIRCH_WOODEN_PLANKS = "birchWoodenPlanks";
	public static alias BirchWoodenPlanks = WoodenPlanks!(BIRCH_WOODEN_PLANKS, META!2, Blocks.BIRCH_WOODEN_PLANKS);

	public static immutable string JUNGLE_WOODEN_PLANKS = "jungleWoodenPlanks";
	public static alias JungleWoodenPlanks = WoodenPlanks!(JUNGLE_WOODEN_PLANKS, META!3, Blocks.JUNGLE_WOODEN_PLANKS);

	public static immutable string ACACIA_WOODEN_PLANKS = "acaciaWoodenPlanks";
	public static alias AcaciaWoodenPlanks = WoodenPlanks!(ACACIA_WOODEN_PLANKS, META!4, Blocks.ACACIA_WOODEN_PLANKS);

	public static immutable string DARK_OAK_WOODEN_PLANKS = "darkOakWoodenPlanks";
	public static alias DarkOakWoodenPlanks = WoodenPlanks!(DARK_OAK_WOODEN_PLANKS, META!5, Blocks.DARK_OAK_WOODEN_PLANKS);
	
	public static enum SAPLING = [OAK_SAPLING, SPRUCE_SAPLING, BIRCH_SAPLING, JUNGLE_SAPLING, ACACIA_SAPLING, DARK_OAK_SAPLING];
	
	public static immutable string OAK_SAPLING = "oakSapling";
	
	public static immutable string SPRUCE_SAPLING = "spruceSapling";
	
	public static immutable string BIRCH_SAPLING = "birchSapling";
	
	public static immutable string JUNGLE_SAPLING = "jungleSapling";
	
	public static immutable string ACACIA_SAPLING = "acaciaSapling";
	
	public static immutable string DARK_OAK_SAPLING = "darkOakSapling";

	public static immutable string BEDROCK = "bedrock";
	public static alias Bedrock = PlaceableItem!(BEDROCK, ID!7, META!0, Blocks.BEDROCK);

	/*public static enum WATER = [FLOWING_WATER, STILL_WATER];

	public static immutable string FLOWING_WATER = "water";
	public static alias Water = PlaceableItem!(FLOWING_WATER, ID!8, META!0, Blocks.FLOWING_WATER);

	public static immutable string STILL_WATER = "stillWater";
	public static alias StillWater = PlaceableItem!(STILL_WATER, ID!9, META!0, Blocks.STILL_WATER);

	public static enum LAVA = [FLOWING_LAVA, STILL_LAVA];

	public static immutable string FLOWING_LAVA = "lava";
	public static alias Lava = PlaceableItem!(FLOWING_LAVA, ID!10, META!0, Blocks.FLOWING_WATER);

	public static immutable string STILL_LAVA = "stillLava";
	public static alias StillLava = PlaceableItem!(STILL_LAVA, ID!11, META!0, Blocks.STILL_LAVA);*/

	public static immutable string SAND = "sand";
	public static alias Sand = PlaceableItem!(SAND, ID!12, META!0, Blocks.SAND);

	public static immutable string RED_SAND = "redSand";
	public static alias RedSand = PlaceableItem!(RED_SAND, ID!12, META!1, Blocks.RED_SAND);

	public static immutable string GRAVEL = "gravel";
	public static alias Gravel = PlaceableItem!(GRAVEL, ID!13, META!0, Blocks.GRAVEL);

	public static immutable string GOLD_ORE = "goldOre";
	public static alias GoldOre = PlaceableItem!(GOLD_ORE, ID!14, META!0, Blocks.GOLD_ORE);

	public static immutable string IRON_ORE = "ironOre";
	public static alias IronOre = PlaceableItem!(IRON_ORE, ID!15, META!0, Blocks.IRON_ORE);

	public static immutable string COAL_ORE = "coalOre";
	public static alias CoalOre = PlaceableItem!(COAL_ORE, ID!16, META!0, Blocks.COAL_ORE);

	//TODO placing with the right orientation
	public static enum WOOD = [OAK_WOOD, SPRUCE_WOOD, BIRCH_WOOD, JUNGLE_WOOD, ACACIA_WOOD, DARK_OAK_WOOD];

	public static immutable string OAK_WOOD = "oakWood";
	public static alias OakWood = PlaceableItem!(OAK_WOOD, ID!17, META!0, Blocks.OAK_WOOD_UP_DOWN);

	public static immutable string SPRUCE_WOOD = "spruceWood";
	public static alias SpruceWood = PlaceableItem!(SPRUCE_WOOD, ID!17, META!1, Blocks.SPRUCE_WOOD_UP_DOWN);

	public static immutable string BIRCH_WOOD = "birchWood";
	public static alias BirchWood = PlaceableItem!(BIRCH_WOOD, ID!17, META!2, Blocks.BIRCH_WOOD_UP_DOWN);

	public static immutable string JUNGLE_WOOD = "jungleWood";
	public static alias JungleWood = PlaceableItem!(JUNGLE_WOOD, ID!17, META!3, Blocks.BIRCH_WOOD_UP_DOWN);

	public static immutable string ACACIA_WOOD = "acaciaWood";
	public static alias AcaciaWood = PlaceableItem!(ACACIA_WOOD, ID!162, META!0, Blocks.ACACIA_WOOD_UP_DOWN);

	public static immutable string DARK_OAK_WOOD = "darkOakWood";
	public static alias DarkOakWood = PlaceableItem!(DARK_OAK_WOOD, ID!162, META!1, Blocks.DARK_OAK_WOOD_UP_DOWN);

	public static enum LEAVES = [OAK_LEAVES, SPRUCE_LEAVES, BIRCH_LEAVES, JUNGLE_LEAVES, ACACIA_LEAVES, DARK_OAK_LEAVES];

	public static immutable string OAK_LEAVES = "oakLeaves";
	public static alias OakLeaves = PlaceableItem!(OAK_LEAVES, ID!18, META!0, Blocks.OAK_LEAVES_NO_DECAY);

	public static immutable string SPRUCE_LEAVES = "spruceLeaves";
	public static alias SpruceLeaves = PlaceableItem!(SPRUCE_LEAVES, ID!18, META!1, Blocks.SPRUCE_LEAVES_NO_DECAY);

	public static immutable string BIRCH_LEAVES = "birchLeaves";
	public static alias BirchLeaves = PlaceableItem!(BIRCH_LEAVES, ID!18, META!2, Blocks.BIRCH_LEAVES_NO_DECAY);

	public static immutable string JUNGLE_LEAVES = "jungleLeaves";
	public static alias JungleLeaves = PlaceableItem!(JUNGLE_LEAVES, ID!18, META!3, Blocks.JUNGLE_LEAVES_NO_DECAY);

	public static immutable string ACACIA_LEAVES = "acaciaLeaves";
	public static alias AcaciaLeaves = PlaceableItem!(ACACIA_LEAVES, ID!161, META!0, Blocks.ACACIA_LEAVES_NO_DECAY);

	public static immutable string DARK_OAK_LEAVES = "darkOakLeaves";
	public static alias DarkOakLeaves = PlaceableItem!(DARK_OAK_LEAVES, ID!161, META!1, Blocks.DARK_OAK_LEAVES_NO_DECAY);

	public static immutable string SPONGE = "sponge";
	public static alias Sponge = PlaceableItem!(SPONGE, ID!19, META!0, Blocks.SPONGE);

	public static immutable string GLASS = "glass";
	public static alias Glass = PlaceableItem!(GLASS, ID!20, META!0, Blocks.GLASS);

	public static immutable string LAPIS_LAZULI_ORE = "lapisLazuliOre";
	public static alias LapisLazuliOre = PlaceableItem!(LAPIS_LAZULI_ORE, ID!21, META!0, Blocks.LAPIS_LAZULI_ORE);

	public static immutable string LAPIS_LAZULI_BLOCK = "lapisLazuliBlock";
	public static alias LapisLazuliBlock = PlaceableItem!(LAPIS_LAZULI_BLOCK, ID!22, META!0, Blocks.LAPIS_LAZULI_BLOCK);

	public static immutable string DISPENSER = "dispencer";
	//public static alias Dispencer = PlaceableItem!(DISPENSER, ID!23, META!0, Blocks.DISPENSER);

	public static immutable string SANDSTONE = "sandstone";
	public static alias Sandstone = PlaceableItem!(SANDSTONE, ID!24, META!0, Blocks.SANDSTONE);

	public static immutable string CHISELED_SANDSTONE = "chiseledSandstone";
	public static alias ChiseledSandstone = PlaceableItem!(CHISELED_SANDSTONE, ID!24, META!1, Blocks.CHISELED_SANDSTONE);

	public static immutable string SMOOTH_SANDSTONE = "smoothSandstone";
	public static alias SmoothSandstone = PlaceableItem!(SMOOTH_SANDSTONE, ID!24, META!2, Blocks.SMOOTH_SANDSTONE);

	public static immutable string NOTEBLOCK = "noteblock";
	//public static alias Noteblock = PlaceableItem!(NOTEBLOCK, ID!25, META!0, Blocks.NOTEBLOCK);
	
	public static immutable string TALL_GRASS = "tallGrass";
	public static alias TallGrass = PlaceableItem!(TALL_GRASS, ID!31, META!1, Blocks.TALL_GRASS);
	
	public static immutable string FERN = "fern";
	public static alias Fern = PlaceableItem!(FERN, ID!31, META!2, Blocks.FERN);

	public static immutable string DEAD_BUSH = "deadBush";
	public static alias DeadBush = PlaceableItem!(DEAD_BUSH, ID!32, META!0, Blocks.DEAD_BUSH);

	public static enum WOOL = [WHITE_WOOL, ORANGE_WOOL, MAGENTA_WOOL, LIGHT_BLUE_WOOL, YELLOW_WOOL, LIME_WOOL, PINK_WOOL, GRAY_WOOL, LIGHT_GRAY_WOOL, CYAN_WOOL, PURPLE_WOOL, BLUE_WOOL, BROWN_WOOL, GREEN_WOOL, RED_WOOL, BLACK_WOOL];
	
	public static immutable string WHITE_WOOL = "whiteWool";
	public static alias WhiteWool = PlaceableItem!(WHITE_WOOL, ID!35, META!0, Blocks.WHITE_WOOL);
	
	public static immutable string ORANGE_WOOL = "orangeWool";
	public static alias OrangeWool = PlaceableItem!(ORANGE_WOOL, ID!35, META!1, Blocks.ORANGE_WOOL);
	
	public static immutable string MAGENTA_WOOL = "magentaWool";
	public static alias MagentaWool = PlaceableItem!(MAGENTA_WOOL, ID!35, META!2, Blocks.MAGENTA_WOOL);
	
	public static immutable string LIGHT_BLUE_WOOL = "lightBlueWool";
	public static alias LightBlueWool = PlaceableItem!(LIGHT_BLUE_WOOL, ID!35, META!3, Blocks.LIGHT_BLUE_WOOL);
	
	public static immutable string YELLOW_WOOL = "yellowWool";
	public static alias YellowWool = PlaceableItem!(YELLOW_WOOL, ID!35, META!4, Blocks.YELLOW_WOOL);
	
	public static immutable string LIME_WOOL = "limeWool";
	public static alias LimeWool = PlaceableItem!(LIME_WOOL, ID!35, META!5, Blocks.LIME_WOOL);
	
	public static immutable string PINK_WOOL = "pinkWool";
	public static alias PinkWool = PlaceableItem!(PINK_WOOL, ID!35, META!6, Blocks.PINK_WOOL);
	
	public static immutable string GRAY_WOOL = "grayWool";
	public static alias GrayWool = PlaceableItem!(GRAY_WOOL, ID!35, META!7, Blocks.GRAY_WOOL);
	
	public static immutable string LIGHT_GRAY_WOOL = "lightGrayWool";
	public static alias LightGrayWool = PlaceableItem!(LIGHT_GRAY_WOOL, ID!35, META!8, Blocks.LIGHT_GRAY_WOOL);
	
	public static immutable string CYAN_WOOL = "cyanWool";
	public static alias CyanWool = PlaceableItem!(CYAN_WOOL, ID!35, META!9, Blocks.CYAN_WOOL);
	
	public static immutable string PURPLE_WOOL = "purpleWool";
	public static alias PurpleWool = PlaceableItem!(PURPLE_WOOL, ID!35, META!10, Blocks.PURPLE_WOOL);
	
	public static immutable string BLUE_WOOL = "blueWool";
	public static alias BlueWool = PlaceableItem!(BLUE_WOOL, ID!35, META!11, Blocks.BLUE_WOOL);
	
	public static immutable string BROWN_WOOL = "brownWool";
	public static alias BrownWool = PlaceableItem!(BROWN_WOOL, ID!35, META!12, Blocks.BROWN_WOOL);
	
	public static immutable string GREEN_WOOL = "greenWool";
	public static alias GreenWool = PlaceableItem!(GREEN_WOOL, ID!35, META!13, Blocks.GREEN_WOOL);
	
	public static immutable string RED_WOOL = "redWool";
	public static alias RedWool = PlaceableItem!(RED_WOOL, ID!35, META!14, Blocks.RED_WOOL);
	
	public static immutable string BLACK_WOOL = "blackWool";
	public static alias BlackWool = PlaceableItem!(BLACK_WOOL, ID!35, META!15, Blocks.BLACK_WOOL);

	public static immutable string DANDELION = "dandelion";
	public static alias Dandelion = PlaceableItem!(DANDELION, ID!37, META!0, Blocks.DANDELION);
	
	public static immutable string POPPY = "poppy";
	public static alias Poppy = PlaceableItem!(POPPY, ID!38, META!0, Blocks.POPPY);
	
	public static immutable string BLUE_ORCHID = "blueOrchid";
	public static alias BlueOrchid = PlaceableItem!(BLUE_ORCHID, ID!38, META!1, Blocks.BLUE_ORCHID);
	
	public static immutable string ALLIUM = "allium";
	public static alias Allium = PlaceableItem!(ALLIUM, ID!38, META!2, Blocks.ALLIUM);
	
	public static immutable string AZURE_BLUET = "azureBluet";
	public static alias AzureBluet = PlaceableItem!(AZURE_BLUET, ID!38, META!3, Blocks.AZURE_BLUET);
	
	public static immutable string RED_TULIP = "redTulip";
	public static alias RedTulip = PlaceableItem!(RED_TULIP, ID!38, META!4, Blocks.RED_TULIP);
	
	public static immutable string ORANGE_TULIP = "orangeTulip";
	public static alias OrangeTulip = PlaceableItem!(ORANGE_TULIP, ID!38, META!5, Blocks.ORANGE_TULIP);
	
	public static immutable string WHITE_TULIP = "whiteTulip";
	public static alias WhiteTulip = PlaceableItem!(WHITE_TULIP, ID!38, META!6, Blocks.WHITE_TULIP);
	
	public static immutable string PINK_TULIP = "pinkTulip";
	public static alias PinkTulip = PlaceableItem!(PINK_TULIP, ID!38, META!7, Blocks.PINK_TULIP);

	public static immutable string OXEYE_DAISY = "exeyeDaisy";
	public static alias OxeyeDaisy = PlaceableItem!(OXEYE_DAISY, ID!38, META!8, Blocks.OXEYE_DAISY);
	
	public static immutable string 	BROWN_MUSHROOM = "brownMushroom";
	
	public static immutable string 	RED_MUSHROOM = "redMushroom";

	public static immutable string GOLD_BLOCK = "goldBlock";
	public static alias GoldBlock = PlaceableItem!(GOLD_BLOCK, ID!41, META!0, Blocks.GOLD_BLOCK);

	public static immutable string IRON_BLOCK = "ironBlock";
	public static alias IronBlock = PlaceableItem!(IRON_BLOCK, ID!42, META!0, Blocks.IRON_BLOCK);

	// TODO up and down
	public static immutable string STONE_SLAB = "doubleStoneSlab";
	public static alias DoubleStoneSlab = PlaceableItem!(STONE_SLAB, ID!43, META!0, Blocks.STONE_SLAB);

	public static immutable string TNT = "tnt";
	public static alias Tnt = PlaceableItem!(TNT, ID!46, META!0, Blocks.TNT);

	public static immutable string OBSIDIAN = "obsidian";
	public static alias Obsidian = PlaceableItem!(OBSIDIAN, ID!49, META!0, Blocks.OBSIDIAN);

	public static immutable string FIRE = "fire";
	public static alias Fire = PlaceableItem!(FIRE, ID!51, META!0, Blocks.FIRE);

	public static immutable string DIAMOND_ORE = "diamondOre";
	public static alias DiamondOre = PlaceableItem!(DIAMOND_ORE, ID!56, META!0, Blocks.DIAMOND_ORE);

	public static immutable string DIAMOND_BLOCK = "diamondBlock";
	public static alias DiamondBlock = PlaceableItem!(DIAMOND_BLOCK, ID!57, META!0, Blocks.DIAMOND_BLOCK);

	public static immutable string CRAFTING_TABLE = "craftingTable";
	public static alias CraftingTable = PlaceableItem!(CRAFTING_TABLE, ID!58, META!0, Blocks.CRAFTING_TABLE);

	//TODO facing
	public static immutable string LADDER = "ladder";
	public static alias Ladder = PlaceableItem!(LADDER, ID!65, META!0, Blocks.LADDER_NORTH);

	public static immutable string SNOW_BLOCK = "snowBlock";
	public static alias SnowBlock = PlaceableItem!(SNOW_BLOCK, ID!80, META!0, Blocks.SNOW);

	//TODO facing
	public static immutable string PUMPKIN = "pumpkin";
	public static alias Pumpkin = PlaceableArmor!(PUMPKIN, ID!86, META!0, Blocks.PUMPKIN_SOUTH);

	public static immutable string SOUL_SAND = "soulSand";
	public static alias SoulSand = PlaceableItem!(SOUL_SAND, ID!88, META!0, Blocks.SOUL_SAND);

	public static immutable string BARRIER = "barrier";
	public static immutable string INVISIBLE_BEDROCK = BARRIER;
	public static alias Barrier = PlaceableItem!(BARRIER, IDS!(95, 166), META!0, Blocks.BARRIER);

	public static immutable string MELON_BLOCK = "melonBlock";
	public static alias MelonBlock = PlaceableItem!(MELON_BLOCK, ID!103, META!0, Blocks.MELON);


	public static immutable string MYCELIUM = "mycelium";
	public static alias Mycelium = PlaceableItem!(MYCELIUM, ID!110, META!0, Blocks.MYCELIUM);

	public static immutable string REDSTONE_BLOCK = "redstoneBlock";
	public static alias RedstoneBlock = PlaceableItem!(REDSTONE_BLOCK, ID!152, META!0, Blocks.REDSTONE_BLOCK);

	public static immutable string QUARTZ_BLOCK = "quartzBlock";
	public static alias QuartzBlock = PlaceableItem!(QUARTZ_BLOCK, ID!155, META!0, Blocks.QUARTZ_BLOCK);


	public static enum STAINED_CLAY = [WHITE_STAINED_CLAY, ORANGE_STAINED_CLAY, MAGENTA_STAINED_CLAY, LIGHT_BLUE_STAINED_CLAY, YELLOW_STAINED_CLAY, LIME_STAINED_CLAY, PINK_STAINED_CLAY, GRAY_STAINED_CLAY, LIGHT_GRAY_STAINED_CLAY, CYAN_STAINED_CLAY, PURPLE_STAINED_CLAY, BLUE_STAINED_CLAY, BROWN_STAINED_CLAY, GREEN_STAINED_CLAY, RED_STAINED_CLAY, BLACK_STAINED_CLAY];

	public static immutable string WHITE_STAINED_CLAY = "whiteStainedClay";

	public static immutable string ORANGE_STAINED_CLAY = "orangeStainedClay";

	public static immutable string MAGENTA_STAINED_CLAY = "magentaStainedClay";

	public static immutable string LIGHT_BLUE_STAINED_CLAY = "lightBlueStainedClay";

	public static immutable string YELLOW_STAINED_CLAY = "yellowStainedClay";

	public static immutable string LIME_STAINED_CLAY = "limeStainedClay";

	public static immutable string PINK_STAINED_CLAY = "pinkStainedClay";

	public static immutable string GRAY_STAINED_CLAY = "grayStainedClay";

	public static immutable string LIGHT_GRAY_STAINED_CLAY = "lightGrayStainedClay";

	public static immutable string CYAN_STAINED_CLAY = "cyanStainedClay";

	public static immutable string PURPLE_STAINED_CLAY = "purpleStainedClay";

	public static immutable string BLUE_STAINED_CLAY = "blueStainedClay";

	public static immutable string BROWN_STAINED_CLAY = "brownStainedClay";

	public static immutable string GREEN_STAINED_CLAY = "greenStainedClay";

	public static immutable string RED_STAINED_CLAY = "redStainedClay";

	public static immutable string BLACK_STAINED_CLAY = "blackStainedClay";

	public static immutable string SLIME_BLOCK = "slimeBlock";
	public static alias SlimeBlock = PlaceableItem!(SLIME_BLOCK, ID!165, META!0, Blocks.SLIME_BLOCK);

	public static enum CARPET = [WHITE_CARPET, ORANGE_CARPET, MAGENTA_CARPET, LIGHT_BLUE_CARPET, YELLOW_CARPET, LIME_CARPET, PINK_CARPET, GRAY_CARPET, LIGHT_GRAY_CARPET, CYAN_CARPET, PURPLE_CARPET, BLUE_CARPET, BROWN_CARPET, GREEN_CARPET, RED_CARPET, BLACK_CARPET];
	
	public static immutable string WHITE_CARPET = "whiteCarpet";
	public static alias WhiteCarpet = PlaceableItem!(WHITE_CARPET, ID!171, META!0, Blocks.WHITE_CARPET);
	
	public static immutable string ORANGE_CARPET = "orangeCarpet";
	public static alias OrangeCarpet = PlaceableItem!(ORANGE_CARPET, ID!171, META!1, Blocks.ORANGE_CARPET);
	
	public static immutable string MAGENTA_CARPET = "magentaCarpet";
	public static alias MagentaCarpet = PlaceableItem!(MAGENTA_CARPET, ID!171, META!2, Blocks.MAGENTA_CARPET);
	
	public static immutable string LIGHT_BLUE_CARPET = "lightBlueCarpet";
	public static alias LightBlueCarpet = PlaceableItem!(LIGHT_BLUE_CARPET, ID!171, META!3, Blocks.LIGHT_BLUE_CARPET);
	
	public static immutable string YELLOW_CARPET = "yellowCarpet";
	public static alias YellowCarpet = PlaceableItem!(YELLOW_CARPET, ID!171, META!4, Blocks.YELLOW_CARPET);
	
	public static immutable string LIME_CARPET = "limeCarpet";
	public static alias LimeCarpet = PlaceableItem!(LIME_CARPET, ID!171, META!5, Blocks.LIME_CARPET);
	
	public static immutable string PINK_CARPET = "pinkCarpet";
	public static alias PinkCarpet = PlaceableItem!(PINK_CARPET, ID!171, META!6, Blocks.PINK_CARPET);
	
	public static immutable string GRAY_CARPET = "grayCarpet";
	public static alias GrayCarpet = PlaceableItem!(GRAY_CARPET, ID!171, META!7, Blocks.GRAY_CARPET);
	
	public static immutable string LIGHT_GRAY_CARPET = "lightGrayCarpet";
	public static alias LightGrayCarpet = PlaceableItem!(LIGHT_GRAY_CARPET, ID!171, META!8, Blocks.LIGHT_GRAY_CARPET);
	
	public static immutable string CYAN_CARPET = "cyanCarpet";
	public static alias CyanCarpet = PlaceableItem!(CYAN_CARPET, ID!171, META!9, Blocks.CYAN_CARPET);
	
	public static immutable string PURPLE_CARPET = "purpleCarpet";
	public static alias PurpleCarpet = PlaceableItem!(PURPLE_CARPET, ID!171, META!10, Blocks.PURPLE_CARPET);
	
	public static immutable string BLUE_CARPET = "blueCarpet";
	public static alias BlueCarpet = PlaceableItem!(BLUE_CARPET, ID!171, META!11, Blocks.BLUE_CARPET);
	
	public static immutable string BROWN_CARPET = "brownCarpet";
	public static alias BrownCarpet = PlaceableItem!(BROWN_CARPET, ID!171, META!12, Blocks.BROWN_CARPET);
	
	public static immutable string GREEN_CARPET = "greenCarpet";
	public static alias GreenCarpet = PlaceableItem!(GREEN_CARPET, ID!171, META!13, Blocks.GREEN_CARPET);
	
	public static immutable string RED_CARPET = "redCarpet";
	public static alias RedCarpet = PlaceableItem!(RED_CARPET, ID!171, META!14, Blocks.RED_CARPET);
	
	public static immutable string BLACK_CARPET = "blackCarpet";
	public static alias BlackCarpet = PlaceableItem!(BLACK_CARPET, ID!171, META!15, Blocks.BLACK_CARPET);

	public static immutable string HARDENED_CLAY = "hardenedClay";
	//public static alias HardenedClay = PlaceableItem!(HARDENED_CLAY, ID!172, META!0, Blocks.HARDENED_CLAY);

	public static immutable string COAL_BLOCK = "coalBlock";
	public static alias CoalBlock = PlaceableItem!(COAL_BLOCK, ID!173, META!0, Blocks.COAL_BLOCK);


	public static immutable string IRON_SHOVEL = "ironShovel";
	public static alias IronShovel = ShovelItem!(IRON_SHOVEL, ID!256, Tool.IRON, Durability.IRON, 4);

	public static immutable string IRON_PICKAXE = "ironPickaxe";
	public static alias IronPickaxe = PickaxeItem!(IRON_PICKAXE, ID!257, Tool.IRON, Durability.IRON, 5);

	public static immutable string IRON_AXE = "ironAxe";
	public static alias IronAxe = AxeItem!(IRON_AXE, ID!258, Tool.IRON, Durability.IRON, 6);

	public static immutable string FLINT_AND_STEEL = "flintAndSteel";

	public static immutable string APPLE = "apple";
	public static alias Apple = SimpleFoodItem!(APPLE, ID!260, 4, 2.4);

	public static immutable string BOW = "bow";

	public static immutable string ARROW = "arrow";
	public static alias Arrow = SimpleItem!(ARROW, ID!262, META!0);

	public static immutable string COAL = "coal";
	public static alias Coal = SimpleItem!(COAL, ID!263, META!0);

	public static immutable string CHARCOAL = "charcoal";
	public static alias Charcoal = SimpleItem!(CHARCOAL, ID!263, META!1);

	public static immutable string DIAMOND = "diamond";
	public static alias Diamond = SimpleItem!(DIAMOND, ID!264, META!0);

	public static immutable string IRON_INGOT = "ironIngot";
	public static alias IronIngot = SimpleItem!(IRON_INGOT, ID!265, META!0);

	public static immutable string GOLD_INGOT = "goldIngot";
	public static alias GoldIngot = SimpleItem!(GOLD_INGOT, ID!266, META!0);

	public static immutable string IRON_SWORD = "ironSword";
	public static alias IronSword = SwordItem!(IRON_SWORD, ID!267, Tool.IRON, Durability.IRON, 7);

	public static immutable string WOODEN_SWORD = "woodenSword";
	public static alias WoodenSword = SwordItem!(WOODEN_SWORD, ID!268,Tool. WOODEN, Durability.WOOD, 5);

	public static immutable string WOODEN_SHOVEL = "woodenShovel";
	public static alias WoodenShovel = ShovelItem!(WOODEN_SHOVEL, ID!269, Tool.WOODEN, Durability.WOOD, 2);

	public static immutable string WOODEN_PICKAXE = "woodenPickaxe";
	public static alias WoodenPickaxe = PickaxeItem!(WOODEN_PICKAXE, ID!270, Tool.WOODEN, Durability.WOOD, 3);

	public static immutable string WOODEN_AXE = "woodenAxe";
	public static alias WoodenAxe = AxeItem!(WOODEN_AXE, ID!271, Tool.WOODEN, Durability.WOOD, 4);

	public static immutable string STONE_SWORD = "stoneSword";
	public static alias StoneSword = SwordItem!(STONE_SWORD, ID!272, Tool.STONE, Durability.STONE, 6);

	public static immutable string STONE_SHOVEL = "stoneShovel";
	public static alias StoneShovel = ShovelItem!(STONE_SHOVEL, ID!273, Tool.STONE, Durability.STONE, 3);

	public static immutable string STONE_PICKAXE = "stonePickaxe";
	public static alias StonePickaxe = PickaxeItem!(STONE_PICKAXE, ID!274, Tool.STONE, Durability.STONE, 4);

	public static immutable string STONE_AXE = "stoneAxe";
	public static alias StoneAxe = AxeItem!(STONE_AXE, ID!275, Tool.STONE, Durability.STONE, 5);

	public static immutable string DIAMOND_SWORD = "diamondSword";
	public static alias DiamondSword = SwordItem!(DIAMOND_SWORD, ID!276, Tool.DIAMOND, Durability.DIAMOND, 8);

	public static immutable string DIAMOND_SHOVEL = "diamondShovel";
	public static alias DiamondShovel = ShovelItem!(DIAMOND_SHOVEL, ID!277, Tool.DIAMOND, Durability.DIAMOND, 5);

	public static immutable string DIAMOND_PICKAXE = "diamondPickaxe";
	public static alias DiamondPickaxe = PickaxeItem!(DIAMOND_PICKAXE, ID!278, Tool.DIAMOND, Durability.DIAMOND, 6);

	public static immutable string DIAMOND_AXE = "diamondAxe";
	public static alias DiamondAxe = AxeItem!(DIAMOND_AXE, ID!279, Tool.DIAMOND, Durability.DIAMOND, 7);

	public static immutable string STICK = "stick";
	public static alias Stick = SimpleItem!(STICK, ID!280, META!0);

	public static immutable string BOWL = "bowl";
	public static alias Bowl = SimpleItem!(BOWL, ID!281, META!0);

	public static immutable string MUSHROOM_STEW = "mushroomStew";
	public static alias MushroomStew = SoupItem!(MUSHROOM_STEW, ID!282, META!0, 6, 7.2);

	public static immutable string GOLDEN_SWORD = "goldenSword";
	public static alias GoldenSword = SwordItem!(GOLDEN_SWORD, ID!283, Tool.GOLDEN, Durability.GOLD, 5);

	public static immutable string GOLDEN_SHOVEL = "goldenShovel";
	public static alias GoldenShovel = ShovelItem!(GOLDEN_SHOVEL, ID!284, Tool.GOLDEN, Durability.GOLD, 2);

	public static immutable string GOLDEN_PICKAXE = "goldenPickaxe";
	public static alias GoldenPickaxe = PickaxeItem!(GOLDEN_PICKAXE, ID!285, Tool.GOLDEN, Durability.GOLD, 3);

	public static immutable string GOLDEN_AXE = "goldenAxe";
	public static alias GoldenAxe = AxeItem!(GOLDEN_AXE, ID!286, Tool.GOLDEN, Durability.GOLD, 4);

	public static immutable string STRING = "string";
	public static alias String = SimpleItem!(STRING, ID!287, META!0);

	public static immutable string FEATHER = "feather";
	public static alias Feather = SimpleItem!(FEATHER, ID!288, META!0);

	public static immutable string GUNPOWDER = "gunpowder";
	public static alias Gunpowder = SimpleItem!(GUNPOWDER, ID!289, META!0);

	public static immutable string WOODEN_HOE = "woodenHoe";
	public static alias WoodenHoe = HoeItem!(WOODEN_HOE, ID!290, Tool.WOODEN, Durability.WOOD);

	public static immutable string STONE_HOE = "stoneHoe";
	public static alias StoneHoe = HoeItem!(STONE_HOE, ID!291, Tool.STONE, Durability.STONE);

	public static immutable string IRON_HOE = "ironHoe";
	public static alias IronHoe = HoeItem!(IRON_HOE, ID!292, Tool.IRON, Durability.IRON);

	public static immutable string DIAMOND_HOE = "diamondHoe";
	public static alias DiamondHoe = HoeItem!(DIAMOND_HOE, ID!293, Tool.DIAMOND, Durability.DIAMOND);

	public static immutable string GOLDEN_HOE = "goldenHoe";
	public static alias GoldenHoe = HoeItem!(GOLDEN_HOE, ID!294, Tool.GOLDEN, Durability.GOLD);

	public static immutable string SEEDS = "seeds";
	public static alias Seeds = SimpleItem!(SEEDS, ID!295, META!0, 64, "crop", Blocks.SEEDS_BLOCK_0);

	public static immutable string WHEAT = "wheat";
	public static alias Wheat = SimpleItem!(WHEAT, ID!296, META!0);

	public static immutable string BREAD = "bread";
	public static alias Bread = SimpleFoodItem!(BREAD, ID!297, 5, 6);

	public static immutable string LEATHER_CAP = "leatherCap";
	public static alias LeatherCap = ArmorItem!(LEATHER_CAP, ID!298, 56, Armor.CAP, 1, COLORABLE);

	public static immutable string LEATHER_TUNIC = "leatherTunic";
	public static alias LeatherTunic = ArmorItem!(LEATHER_TUNIC, ID!299, 81, Armor.TUNIC, 3, COLORABLE);

	public static immutable string LEATHER_PANTS = "leatherPants";
	public static alias LeatherPants = ArmorItem!(LEATHER_PANTS, ID!300, 76, Armor.PANTS, 2, COLORABLE);

	public static immutable string LEATHER_BOOTS = "leatherBoots";
	public static alias LeatherBoots = ArmorItem!(LEATHER_BOOTS, ID!301, 66, Armor.BOOTS, 1, COLORABLE);

	public static immutable string CHAIN_HELMET = "chainHelmet";
	public static alias ChainHelmet = ArmorItem!(CHAIN_HELMET, ID!302, 166, Armor.HELMET, 2);

	public static immutable string CHAIN_CHESTPLATE = "chainChestplate";
	public static alias ChainChestplate = ArmorItem!(CHAIN_CHESTPLATE, ID!303, 241, Armor.CHESTPLATE, 5);

	public static immutable string CHAIN_LEGGINGS = "chainLeggings";
	public static alias ChainLeggings = ArmorItem!(CHAIN_LEGGINGS, ID!304, 226, Armor.LEGGINGS, 4);

	public static immutable string CHAIN_BOOTS = "chainBoots";
	public static alias ChainBoots = ArmorItem!(CHAIN_BOOTS, ID!305, 196, Armor.BOOTS, 1);

	public static immutable string IRON_HELMET = "ironHelmet";
	public static alias IronHelmet = ArmorItem!(IRON_HELMET, ID!306, 166, Armor.HELMET, 2);

	public static immutable string IRON_CHESTPLATE = "ironChestplate";
	public static alias IronChestplate = ArmorItem!(IRON_CHESTPLATE, ID!307, 241, Armor.CHESTPLATE, 6);

	public static immutable string IRON_LEGGINGS = "ironLeggings";
	public static alias IronLeggings = ArmorItem!(IRON_LEGGINGS, ID!308, 226, Armor.LEGGINGS, 5);

	public static immutable string IRON_BOOTS = "ironBoots";
	public static alias IronBoots = ArmorItem!(IRON_BOOTS, ID!309, 196, Armor.BOOTS, 2);

	public static immutable string DIAMOND_HELMET = "diamondHelmet";
	public static alias DiamondHelmet = ArmorItem!(DIAMOND_HELMET, ID!310, 364, Armor.HELMET, 3);

	public static immutable string DIAMOND_CHESTPLATE = "diamondChestplate";
	public static alias DiamondChestplate = ArmorItem!(DIAMOND_CHESTPLATE, ID!311, 529, Armor.CHESTPLATE, 8);

	public static immutable string DIAMOND_LEGGINGS = "diamondLeggings";
	public static alias DiamondLeggings = ArmorItem!(DIAMOND_LEGGINGS, ID!312, 496, Armor.LEGGINGS, 6);

	public static immutable string DIAMOND_BOOTS = "diamondBoots";
	public static alias DiamondBoots = ArmorItem!(DIAMOND_BOOTS, ID!313, 430, Armor.BOOTS, 3);

	public static immutable string GOLDEN_HELMET = "goldenHelmet";

	public static immutable string GOLDEN_CHESTPLATE = "goldenChestplate";

	public static immutable string GOLDEN_LEGGINGS = "goldenLeggings";

	public static immutable string GOLDEN_BOOTS = "goldenBoots";

	public static immutable string FLINT = "flint";
	public static alias Flint = SimpleItem!(FLINT, ID!318, META!0);

	public static immutable string RAW_PORKCHOP = "rawPorkchop";
	public static alias RawPorkchop = SimpleFoodItem!(RAW_PORKCHOP, ID!319, 3, 1.8);

	public static immutable string COOKED_PORKCHOP = "cookedPorkchop";
	public static alias CookedPorkchop = SimpleFoodItem!(COOKED_PORKCHOP, ID!320, 8, 12.8);

	public static immutable string PAINTING = "painting";

	public static immutable string GOLDEN_APPLE = "goldenApple";
	public static alias GoldenApple = FoodItem!(GOLDEN_APPLE, ID!322, META!0, 64, 4, 9.6, [effectInfo(Effects.REGENERATION, 5, "II"), effectInfo(Effects.ABSORPTION, 120, "I")]);

	public static immutable string SIGN = "sign";

	/*public static immutable string BUCKET = "bucket";
	public static alias Bucket = BucketItem!(BUCKET, ID!325, META!0, 16, [Blocks.FLOWING_WATER: Items.WATER_BUCKET, Blocks.STILL_WATER: Items.WATER_BUCKET, Blocks.FLOWING_LAVA: Items.LAVA_BUCKET, Blocks.STILL_LAVA: Items.LAVA_BUCKET]);

	public static immutable string WATER_BUCKET = "waterBucket";
	public static alias WaterBucket = FilledBucketItem!(WATER_BUCKET, IDS!(325, 326), METAS!(8, 0), 1, Blocks.FLOWING_WATER, Items.BUCKET);

	public static immutable string LAVA_BUCKET = "lavaBucket";
	public static alias LavaBucket = FilledBucketItem!(LAVA_BUCKET, IDS!(325, 327), METAS!(10, 0), 1, Blocks.FLOWING_LAVA, Items.BUCKET);*/

	//TODO throwable
	public static immutable string SNOWBALL = "snowball";
	public static alias Snowball = SimpleItem!(SNOWBALL, ID!332, META!0, 16);

	public static immutable string MILK = "milk";

	public static immutable string RAW_FISH = "rawFish";
	public static alias RawFish = FoodItem!(RAW_FISH, ID!349, META!0, 64, 2, .4);

	public static immutable string COOKED_FISH = "cookedFish";
	public static alias CookedFish = FoodItem!(COOKED_FISH, ID!350, META!0, 64, 5, 6);

	public static enum DYE = [INK_SAC, ROSE_RED, CACTUS_GREEN, COCOA_BEANS, LAPIS_LAZULI, PURPLE_DYE, CYAN_DYE, LIGHT_GRAY_DYE, GRAY_DYE, PINK_DYE, LIME_DYE, DANDELION_YELLOW, LIGHT_BLUE_DYE, MAGENTA_DYE, ORANGE_DYE, BONE_MEAL];

	public static immutable string INK_SAC = "inkSac";
	public static alias InkSac = SimpleItem!(INK_SAC, ID!351, META!0, 64);

	public static immutable string ROSE_RED = "roseRed";
	public static alias RoseRed = SimpleItem!(ROSE_RED, ID!351, META!1, 64);

	public static immutable string CACTUS_GREEN = "cactusGreen";
	public static alias CactusGreen = SimpleItem!(CACTUS_GREEN, ID!351, META!2, 64);

	public static immutable string COCOA_BEANS = "cocoaBeans";
	public static alias CocoaBeans = SimpleItem!(COCOA_BEANS, ID!351, META!3, 64);

	public static immutable string LAPIS_LAZULI = "lapisLazuli";
	public static alias LapisLazuli = SimpleItem!(LAPIS_LAZULI, ID!351, META!4, 64);

	public static immutable string PURPLE_DYE = "purpleDye";
	public static alias PurpleDye = SimpleItem!(PURPLE_DYE, ID!351, META!5, 64);

	public static immutable string CYAN_DYE = "cyanDye";
	public static alias CyanDye = SimpleItem!(CYAN_DYE, ID!351, META!6, 64);

	public static immutable string LIGHT_GRAY_DYE = "lightGrayDye";
	public static alias LightGrayDye = SimpleItem!(LIGHT_GRAY_DYE, ID!351, META!7, 64);

	public static immutable string GRAY_DYE = "grayDye";
	public static alias GrayDye = SimpleItem!(GRAY_DYE, ID!351, META!8, 64);

	public static immutable string PINK_DYE = "pinkDye";
	public static alias PinkDye = SimpleItem!(PINK_DYE, ID!351, META!9, 64);

	public static immutable string LIME_DYE = "limeDye";
	public static alias LimeDye = SimpleItem!(LIME_DYE, ID!351, META!10, 64);

	public static immutable string DANDELION_YELLOW = "dandelionYellow";
	public static alias DandelionYellow = SimpleItem!(DANDELION_YELLOW, ID!351, META!11, 64);

	public static immutable string LIGHT_BLUE_DYE = "lightBlueDye";
	public static alias LightBlueDye = SimpleItem!(LIGHT_BLUE_DYE, ID!351, META!12, 64);

	public static immutable string MAGENTA_DYE = "magentaDye";
	public static alias MagentaDye = SimpleItem!(MAGENTA_DYE, ID!351, META!13, 64);

	public static immutable string ORANGE_DYE = "orangeDye";
	public static alias OrangeDye = SimpleItem!(ORANGE_DYE, ID!351, META!14, 64);

	//TODO
	public static immutable string BONE_MEAL = "boneMeal";
	public static alias BoneMeal = SimpleItem!(BONE_MEAL, ID!351, META!15, 64);

	public static immutable string COOKIE = "cookie";
	public static alias Cookie = FoodItem!(COOKIE, ID!357, META!0, 64, 2, .4);

	public static immutable string MAP = "map";
	public static alias Map = MapItem!(MAP, ID!358);

	public static immutable string MELON = "melon";
	public static alias Melon = FoodItem!(MELON, ID!360, META!0, 64, 2, 1.2);

	public static immutable string PUMPKIN_SEEDS = "pumpkinSeeds";
	public static alias PumpkinSeeds = SimpleItem!(PUMPKIN_SEEDS, ID!361, META!0, 64, "crop", Blocks.PUMPKIN_STEM_0);

	public static immutable string MELON_SEEDS = "melonSeeds";
	public static alias MelonSeeds = SimpleItem!(MELON_SEEDS, ID!362, META!0, 64, "crop", Blocks.MELON_STEM_0);

	public static immutable string RAW_BEEF = "rawBeef";
	public static alias RawBeef = FoodItem!(RAW_BEEF, ID!363, META!0, 64, 3, 1.8);

	public static immutable string RAW_CHICKEN = "rawChicken";
	public static alias RawChicken = FoodItem!(RAW_CHICKEN, ID!365, META!0, 64, 2, 1.2);

	public static immutable string COOKED_CHICKEN = "cookedChicken";
	public static alias CookedChicked = FoodItem!(COOKED_CHICKEN, ID!366, META!0, 64, 6, 7.2);

	public static immutable string ROTTEN_FLESH = "rottenFlesh";
	public static alias RottenFlesh = FoodItem!(ROTTEN_FLESH, ID!367, META!0, 64, 4, .8, [effectInfo(Effects.HUNGER, 30, "I", .8)]);

	public static immutable string GOLDEN_NUGGET = "goldenNugget";
	public static alias GoldenNugget = SimpleItem!(GOLDEN_NUGGET, ID!371, META!0, 64);

	public static immutable string WATER_BOTTLE = "waterBattle";
	public static alias WaterBottle = PotionItem!(WATER_BOTTLE, META!0, Potions.WATER_BOTTLE);

	public static immutable string MUNDANE_POTION = "mundane";
	public static alias MundanePotion = PotionItem!(MUNDANE_POTION, METAS!(1, 8192), Potions.MUNDANE);

	public static immutable string MUNDANE_POTION_EXTENDED = "mundaneExtended";
	public static alias MundanePotionExtended = PotionItem!(MUNDANE_POTION_EXTENDED, METAS!(2, 64), Potions.MUNDANE_EXTENDED);

	public static immutable string THICK_POTION = "thick";
	public static alias ThickPotion = PotionItem!(THICK_POTION, METAS!(3, 32), Potions.THICK);

	public static immutable string AWKWARD_POTION = "awkward";
	public static alias AwkwardPotion = PotionItem!(AWKWARD_POTION, METAS!(4, 16), Potions.AWKWARD);

	public static immutable string NIGHT_VISION_POTION = "nightVision";
	public static alias NightVision = PotionItem!(NIGHT_VISION_POTION, METAS!(5, 8198), Potions.NIGHT_VISION);

	public static immutable string NIGHT_VISION_EXTENDED_POTION = "nightVisionExtended";
	public static alias NightVisionExtended = PotionItem!(NIGHT_VISION_EXTENDED_POTION, METAS!(6, 8262), Potions.NIGHT_VISION_EXTENDED);

	public static immutable string INVISIBILITY_POTION = "invisibility";
	public static alias InvisibilityPotion = PotionItem!(INVISIBILITY_POTION, METAS!(7, 8206), Potions.INVISIBILITY);

	public static immutable string INVISIBILITY_EXTENDED_POTION = "invisibilityExtended";
	public static alias InvisibilityExtendedPotion = PotionItem!(INVISIBILITY_EXTENDED_POTION, METAS!(8, 8270), Potions.INVISIBILITY_EXTENDED);

	public static immutable string LEAPING_POTION = "leaping";
	public static alias LeapingPotion = PotionItem!(LEAPING_POTION, METAS!(9, 8203), Potions.LEAPING);

	public static immutable string LEAPING_POTION_EXTENDED = "leapingExtended";
	public static alias LeapingExtendedPotion = PotionItem!(LEAPING_POTION_EXTENDED, METAS!(10, 8267), Potions.LEAPING_EXTENDED);

	public static immutable string LEAPING_PLUS_POTION = "leapingPlus";
	public static alias LeapingPlusPotion = PotionItem!(LEAPING_PLUS_POTION, METAS!(11, 8235), Potions.LEAPING_PLUS);

	public static immutable string FIRE_RESISTANCE_POTION = "fireResistance";
	public static alias FireResistancePotion = PotionItem!(FIRE_RESISTANCE_POTION, METAS!(12, 8195), Potions.FIRE_RESISTANCE);

	public static immutable string FIRE_RESISTANCE_POTION_EXTENDED = "fireResistanceExtended";
	public static alias FireResistancePotionExtended = PotionItem!(FIRE_RESISTANCE_POTION_EXTENDED, METAS!(13, 8295), Potions.FIRE_RESISTANCE_EXTENDED);

	public static immutable string SPEED_POTION = "speed";
	public static alias SpeedPotion = PotionItem!(SPEED_POTION, METAS!(14, 8194), Potions.SPEED);

	public static immutable string SPEED_POTION_EXTENDED = "speedExtended";
	public static alias SpeedPotionExtended = PotionItem!(SPEED_POTION_EXTENDED, METAS!(15, 8258), Potions.SPEED_EXTENDED);

	public static immutable string SPEED_PLUS_POTION = "speedPlus";
	public static alias SpeedPlusPotion = PotionItem!(SPEED_PLUS_POTION, METAS!(16, 8226), Potions.SPEED_PLUS);

	public static immutable string SLOWNESS_POTION = "slowness";
	public static alias SlownessPotion = PotionItem!(SLOWNESS_POTION, METAS!(17, 8202), Potions.SLOWNESS);

	public static immutable string SLOWNESS_POTION_EXTENDED = "slownessExtended";
	public static alias SlownessExtendedPotion = PotionItem!(SLOWNESS_POTION_EXTENDED, METAS!(18, 8266), Potions.SLOWNESS_EXTENDED);

	public static immutable string WATER_BREATHING_POTION = "waterBreathing";
	public static alias WaterBreathingPotion = PotionItem!(WATER_BREATHING_POTION, METAS!(19, 8205), Potions.WATER_BREATHING);

	public static immutable string WATER_BREATHING_EXTENDED_POTION = "waterBreathingExtended";
	public static alias WaterBreathingExtended = PotionItem!(WATER_BREATHING_EXTENDED_POTION, METAS!(20, 8269), Potions.WATER_BREATHING_EXTENDED);

	public static immutable string HEALING_POTION = "healing";
	public static alias HealingPotion = PotionItem!(HEALING_POTION, METAS!(21, 8197), Potions.HEALING);

	public static immutable string HEALING_PLUS_POTION = "healingPlus";
	public static alias HealingPlusPotion = PotionItem!(HEALING_PLUS_POTION, METAS!(22, 8229), Potions.HEALING_PLUS);

	public static immutable string HARMING_POTION = "harming";
	public static alias HarmingPotion = PotionItem!(HARMING_POTION, METAS!(23, 8204), Potions.HARMING);

	public static immutable string HARMING_PLUS_POTION = "harmingPlus";
	public static alias HarmingPlusPotion = PotionItem!(HARMING_PLUS_POTION, METAS!(24, 8236), Potions.HARMING_PLUS);

	public static immutable string POISON_POTION = "poison";
	public static alias PoisonPotion = PotionItem!(POISON_POTION, METAS!(25, 8196), Potions.POISON);

	public static immutable string POISON_POTION_EXTENDED = "poisonExtended";
	public static alias PoisonExtendedPotion = PotionItem!(POISON_POTION_EXTENDED, METAS!(26, 8260), Potions.POISON_EXTENDED);

	public static immutable string POISON_PLUS_POTION = "poisonPlus";
	public static alias PoisonPlusPotion = PotionItem!(POISON_PLUS_POTION, METAS!(27, 8228), Potions.POISON_PLUS);

	public static immutable string REGENERATION_POTION = "regeneration";
	public static alias RegenerationPotion = PotionItem!(REGENERATION_POTION, METAS!(28, 8139), Potions.REGENERATION);

	public static immutable string REGENERATION_POTION_EXTENDED = "regenerationExtended";
	public static alias RegenerationPotionExtended = PotionItem!(REGENERATION_POTION_EXTENDED, METAS!(29, 8257), Potions.REGENERATION_EXTENDED);

	public static immutable string REGENERATION_PLUS_POTION = "regeneraionPlus";
	public static alias RegenerationPlusPotion = PotionItem!(REGENERATION_PLUS_POTION, METAS!(30, 8225), Potions.REGENERATION_PLUS);

	public static immutable string STRENGTH_POTION = "strength";
	public static alias StrengthPotion = PotionItem!(STRENGTH_POTION, METAS!(31, 8201), Potions.STRENGTH);

	public static immutable string STRENGTH_POTION_EXTENDED = "strengthExtended";
	public static alias StrengthPotionExtended = PotionItem!(STRENGTH_POTION_EXTENDED, METAS!(32, 8265), Potions.STRENGTH_EXTENDED);

	public static immutable string STRENGTH_PLUS_POTION = "strengthPlus";
	public static alias StrengthPlusPotion = PotionItem!(STRENGTH_PLUS_POTION, METAS!(33, 8233), Potions.STRENGTH_PLUS);

	public static immutable string WEAKNESS_POTION = "weakness";
	public static alias WeaknessPotion = PotionItem!(WEAKNESS_POTION, METAS!(34, 8200), Potions.WEAKNESS);

	public static immutable string WEAKNESS_POTION_EXTENDED = "weaknessExtended";
	public static alias WeaknessPotionExtended = PotionItem!(WEAKNESS_POTION_EXTENDED, METAS!(35, 8264), Potions.WEAKNESS);

	//TODO fill with water when tapping a source
	public static immutable string GLASS_BOTTLE = "glassBottle";
	public static alias GlassBottle = SimpleItem!(GLASS_BOTTLE, ID!374, META!0);

	public static immutable string SPIDER_EYE = "spiderEye";
	public static alias SpiderEye = FoodItem!(SPIDER_EYE, ID!375, META!0, 64, 2, 3.2, [effectInfo(Effects.POISON, 4, "I")]);

	public static immutable string CARROT = "carrot";
	public static alias Carrot = CropFood!(CARROT, ID!391, 3, 4.8, Blocks.CARROT_BLOCK_0);

	public static immutable string POTATO = "potato";
	public static alias Potato = CropFood!(POTATO, ID!392, 1, .6, Blocks.POTATO_BLOCK_0);

	public static immutable string BAKED_POTATO = "bakedPotato";
	public static alias BakedPotato = FoodItem!(BAKED_POTATO, ID!393, META!0, 64, 5, 7.2);

	public static immutable string POISONOUS_POTATO = "poisonousPotato";
	public static alias PoisonousPotato = FoodItem!(POISONOUS_POTATO, ID!394, META!0, 64, 2, 1.2, [effectInfo(Effects.POISON, 4, "I", .6)]);

	public static immutable string GOLDEN_CARROT = "goldenCarrot";
	public static alias GoldenCarrot = FoodItem!(GOLDEN_CARROT, ID!396, META!0, 64, 6, 14.4);

	public static immutable string PUMPKIN_PIE = "pumpkinPie";
	public static alias PumpkinPie = FoodItem!(PUMPKIN_PIE, ID!400, META!0, 64, 8, 4.8);

	public static immutable string RAW_RABBIT = "rawRabbit";
	public static alias RawRabbit = FoodItem!(RAW_RABBIT, ID!411, META!0, 64, 3, 1.8);

	public static immutable string COOKED_RABBIT = "cookedRabbit";
	public static alias CookedRabbit = FoodItem!(COOKED_RABBIT, ID!412, META!0, 64, 5, 6);

	public static immutable string RABBIT_STEW = "rabbitStew";
	public static alias RabbitStew = SoupItem!(RABBIT_STEW, ID!413, META!0, 10, 12);

	public static immutable string BEETROOT = "beetroot";
	public static alias Beetroot = FoodItem!(BEETROOT, IDS!(457, 434), META!0, 64, 1, 1.2);
	
	public static immutable string BEETROOT_SEEDS = "beetrootSeeds";
	public static alias BeetrootSeeds = SimpleItem!(BEETROOT_SEEDS, IDS!(458, 435), META!0, 64, "crop", Blocks.BEETROOT_BLOCK_0);

	public static immutable string BEETROOT_SOUP = "beetrootSoup";
	public static alias BeetrootSoup = SoupItem!(BEETROOT_SOUP, IDS!(459, 436), META!0, 6, 7.2);

	public static immutable string RAW_SALMON = "rawSalmon";
	public static alias RawSalmon = FoodItem!(RAW_SALMON, IDS!(460, 349), METAS!(0, 1), 64, 2, .4);

	public static immutable string CLOWNFISH = "clownfish";
	public static alias Clownfish = FoodItem!(CLOWNFISH, IDS!(461, 349), METAS!(0, 2), 64, 1, .2);

	public static immutable string PUFFERFISH = "pufferfish";
	public static alias Pufferfish = FoodItem!(PUFFERFISH, IDS!(462, 349), METAS!(0, 3), 64, 1, .2, [effectInfo(Effects.HUNGER, 15, "III"), effectInfo(Effects.NAUSEA, 15, "II"), effectInfo(Effects.POISON, 60, "IV")]);

	public static immutable string COOKED_SALMON = "cookedSalmon";
	public static alias CookedSalmon = FoodItem!(COOKED_SALMON, IDS!(463, 350), METAS!(0, 1), 64, 6, 9.6);

	public static immutable string ENCHANTED_GOLDEN_APPLE = "enchantedGoldenApple";
	public static alias EnchantedGoldenApple = FoodItem!(ENCHANTED_GOLDEN_APPLE, IDS!(466, 322), METAS!(0, 1), 64, 4, 9.6, [effectInfo(Effects.REGENERATION, 30, "V"), effectInfo(Effects.ABSORPTION, 120, "I"), effectInfo(Effects.RESISTANCE, 300, "I"), effectInfo(Effects.FIRE_RESISTANCE, 300, "I")]);

}

/**
 * Base abstract class for an Item.
 */
abstract class Item {
	
	alias ItemCompound = DefinedCompound!(Compound, "display", ListOf!Compound, "ench");

	protected Compound m_pe_tag;
	protected Compound m_pc_tag;

	private string m_name = "";
	private ubyte[ushort] enchantments;

	public @safe @nogc this() {}
	
	/**
	 * Constructs an item with some extra data.
	 * Throws: JSONException if the JSON string is malformed
	 * Example:
	 * ---
	 * new Items.Apple("{\"customName\":\"SPECIAL APPLE\",\"enchantments\":[{\"name\":\"protection\",\"level\":\"IV\"}]}");
	 * ---
	 */
	public @trusted this(string data) {
		this(parseJSON(data));
	}

	/**
	 * Constructs an item adding properties from a JSON.
	 * Throws: RangeError if the enchanting name doesn't exist
	 */
	public @safe this(JSONValue data) {
		this.elaborateJSON(data);
	}

	public @trusted void elaborateJSON(JSONValue data) {

		if("customName" in data && data["customName"].type == JSON_TYPE.STRING) { this.customName = data["customName"].str; }
		else if("name" in data && data["name"].type == JSON_TYPE.STRING) { this.customName = data["name"].str; }
		
		foreach(string e ; ["enchantments", "enchantment", "ench"]) {
			if(e in data && data[e].type == JSON_TYPE.ARRAY) {
				foreach(JSONValue ench ; data[e].array) {
					string se = "";
					foreach(string s ; ["id", "name", "type"]) {
						if(s in ench && ench[s].type == JSON_TYPE.STRING) {
							se = ench[s].str;
							break;
						}
					}
					ubyte level = 1;
					foreach(string s ; ["level", "lvl"]) {
						if(s in ench && (ench[s].type == JSON_TYPE.STRING || ench[s].type == JSON_TYPE.INTEGER)) {
							level = (ench[s].type == JSON_TYPE.INTEGER ? ench[s].integer : roman(ench[s].str)) & 255;
							break;
						}
					}
					this.addEnchantment(Enchantment.fromString(se), level);
				}
				break;
			}
		}

	}

	/**
	 * Gets the ids for the item.
	 * They should never change.
	 * Example:
	 * ---
	 * 
	 * ---
	 */
	public abstract pure nothrow @property @safe @nogc shortgroup ids();

	/**
	 * Gets the metas (or the damage) for the item.
	 */
	public abstract pure nothrow @property @safe @nogc shortgroup metas();

	/**
	 * Gets the name (not the custom name!) of the item.
	 */
	public abstract pure nothrow @property @safe @nogc string name();

	/** 
	 * Highest number of items that can be stacked in the slot.
	 * This number is the default slot's count if not spcified when creating a slot
	 * Returns: usually a number between 1 and 64.
	 * Example:
	 * ---
	 * Slot slot = new Items.Beetroot();
	 * assert(slot.count == 64 && slot.item.max == 64);
	 * 
	 * slot = new Slot(new Items.Beetroot(), 23);
	 * assert(slot.count != 64 && slot.count == 23);
	 * ---
	 */
	public abstract pure nothrow @property @safe @nogc ubyte max();

	/**
	 * Indicates whether or not this item is a tool.
	 * A tool can be used on blocks and entities
	 * and its meta will vary.
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().tool == false);
	 * assert(new Items.DiamondSword().tool == true);
	 * ---
	 */
	public final @property @safe @nogc bool tool() {
		return this.toolType != Tool.NO;
	}

	/**
	 * Get the item's tool type.
	 * Returns: 0 if Item::tool is false, a number higher that 0 indicating
	 * 			the tool type otherwise.
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().toolType == NO_TOOL);
	 * assert(new Items.DiamondSword().toolType == SWORD);
	 * ---
	 */
	public @property @safe @nogc ubyte toolType() {
		return Tool.NO;
	}

	/**
	 * Get the tool's material if Item::tool is true.
	 * Items with ID 0 have unspecified material, 1 is the minimum (wood)
	 * and 5 is the maximum (diamond).
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().toolMaterial == NO_TOOL);
	 * assert(new Items.DiamondSword().toolMaterial == DIAMOND);
	 * ---
	 */
	public @property @safe @nogc ubyte toolMaterial() {
		return Tool.NO;
	}

	/**
	 * If the item is a tool, check if it has been consumed.
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().finished == false); //beetroots aren't tools
	 * assert(new Items.DiamondSword().finished == false);
	 * assert(new Items.DiamondSword(Items.DiamondSword.DURABILITY + 1).finished == true);
	 * ---
	 */
	public @property @safe @nogc bool finished() {
		return false;
	}

	/**
	 * Attack damage caused by the item, as an hit, usually modified
	 * by the tools, like words and axes.
	 */
	public @property @safe @nogc uint attack() {
		return 1;
	}

	/**
	 * Indicates whether or not an item can be eaten/drunk.
	 * If true, Item::onConsumed(Human consumer) will be called
	 * when this item is eaten/drunk.
	 * Example:
	 * ---
	 * if(item.consumeable) {
	 *    Item residue;
	 *    if((residue = item.onConsumed(player)) !is null) {
	 *       player.held = residue;
	 *    }
	 * }
	 * ---
	 */
	public @property @safe @nogc bool consumeable() {
		return false;
	}

	/**
	 * If consumeable is true, this function is called.
	 * when the item is eaten/drunk by its holder, who's passed
	 * as the first arguments.
	 * Return:
	 * 		null: the item count will be reduced by 1
	 * 		item: the item will substitutes the consumed item
	 * Example:
	 * ---
	 * assert(new Items.Beetroot().onConsumed(player) is null);
	 * assert(new Items.BeetrootSoup().onConsumed(player) == Items.BOWL);
	 * ---
	 */
	public Item onConsumed(Player player) {
		return null;
	}
	
	/**
	 * Indicates whether or not the item can be placed.
	 * If this function returns true, Item::place(World world) will be probably
	 * called next for place a block
	 */
	public @property @safe @nogc bool placeable() {
		return false;
	}

	/**
	 * Function called when the item is ready to be placed by
	 * a player (the event for the player has already been called).
	 * Returns: true if a block has been placed, false otherwise
	 */
	public bool onPlaced(Player player, BlockPosition tpos, uint tface) {
		BlockPosition position = tpos.face(tface);
		//TODO calling events on player and on block
		auto placed = this.place(player.world, position);
		if(placed.id != 0) {
			player.world[position] = placed;
			return true;
		} else {
			return false;
		}
	}
	
	/**
	 * If Item::placeable returns true, this function
	 * should return an instance of the block that will
	 * be placed.
	 * Params:
	 * 		world: the world where the block has been placed
	 * 		position: where the item should place the block
	 */
	public BlockData place(World world, BlockPosition position) {
		return Blocks.AIR;
	}

	/** 
	 * Function called when the item is used on a block
	 * clicking the right mouse button or performing a long pressure on the screen.
	 * Returns: true if the item is a tool and it has been cosnumed, false otherwise
	 * Example:
	 * ---
	 * // N.B. that this will not work as the block hasn't been placed
	 * world[0, 64, 0] = Blocks.DIRT;
	 * assert(world[0, 64, 0] == Blocks.DIRT);
	 * 
	 * new Items.WoodenShovel().useOnBlock(player, world[0, 64, 0], Faces.TOP);
	 * 
	 * assert(world[0, 64, 0] == Blocks.GRASS_PATH);
	 * ---
	 */
	public bool useOnBlock(Player player, Block block, BlockPosition position, ubyte face) {
		return false;
	}

	/**
	 * Function called when the item is used to the destroy a block.
	 * Returns: true if the item is a tool and it has been consumed, false otherwise
	 * Example:
	 * ---
	 * auto dirt = new Blocks.Dirt();
	 * auto sword = new Items.DiamondSword(Items.DiamondSword.DURABILITY - 2);
	 * auto shovel = new Items.DiamondShovel(Items.DiamondShovel.DURABILITY - 2);
	 * 
	 * assert(sword.finished == false);
	 * assert(shovel.finished == false);
	 * 
	 * sword.destroyOn(player, dirt);	// 2 uses
	 * shovel.destroyOn(player, dirt);	// 1 use
	 * 
	 * assert(sword.finished == true);
	 * assert(shovel.finished == false);
	 * ---
	 */
	public bool destroyOn(Player player, Block block, BlockPosition position) {
		return false;
	}

	/**
	 * Function called when the item is used on an entity as
	 * right click or long screen pressure.
	 * Returns: true if the items is a tool and it has been consumed, false otherwise
	 */
	public bool useOnEntity(Player player, Entity entity) {
		return false;
	}

	/**
	 * Function called when the item is used against an
	 * entity as a left click or screen tap.
	 * Returns: true if the items is a tool and it has been consumed, false otherwise
	 */
	public bool attackOnEntity(Player player, Entity entity) {
		return false;
	}

	/**
	 * Function called when the item is throwed or aimed.
	 * Returns: true if the item count should be reduced by 1, false otherwise
	 */
	public bool onThrowed(Player player) {
		return false;
	}

	/**
	 * Function called when the item is released, usually after
	 * it has been throwed (which is used as aim-start function).
	 * Returns: true if the item has been consumed, false otherwise
	 */
	public bool onReleased(Player holder) {
		return false;
	}

	protected @trusted void reset() {
		this.m_pe_tag = null;
		this.m_pc_tag = null;
		this.m_name.length = 0;
		this.enchantments.clear();
	}

	public final @property @safe @nogc bool petags() {
		return this.m_pe_tag !is null;
	}

	public final @property @safe @nogc Compound petag() {
		return this.m_pe_tag;
	}

	public @property @safe Compound petag(Compound petag) {
		this.reset();
		if(petag.has!Compound("")) petag = petag.get!Compound("");
		if(petag.has!Compound("display") && petag.get!Compound("display").has!String("Name")) this.customName = petag.get!Compound("display").get!String("Name");
		if(petag.has!(ListOf!Compound)("ench")) {
			foreach(Compound compound ; petag.get!(ListOf!Compound)("ench")) {
				if(compound.has!Short("id") && compound.has!Short("lvl")) {
					try {
						this.addEnchantment(Enchantment.pe(compound.get!Short("id").value & 255), compound.get!Short("lvl").value & 255);
					} catch(Exception e) {}
				}
			}
		}
		return this.petag;
	}

	public final @property @safe @nogc bool pctags() {
		return this.m_pc_tag !is null;
	}

	public final @property @safe @nogc Compound pctag() {
		return this.m_pc_tag;
	}

	public final @property @safe Compound pctag(Compound pctag) {
		return null; //TODO
	}

	/**
	 * Get or set the item's custom name
	 * Returns: the item's custom name
	 * Example:
	 * ---
	 * // add a custom name
	 * item.customName = "Custom item";
	 * 
	 * // reset the custom name
	 * item.customName = null;
	 * ---
	 */
	public @property @safe @nogc string customName() {
		return this.m_name;
	}

	/// ditto
	public @property @safe string customName(string name) {
		if(name is null) name = "";
		if(name == "") {
			if(this.petags && this.m_pe_tag.has!Compound("display") && this.m_pe_tag.get!Compound("display").has("Name")) {
				this.m_pe_tag.get!Compound("display").remove("Name");
				if(this.m_pe_tag.get!Compound("display").empty) {
					this.m_pe_tag.remove("display");
					if(this.m_pe_tag.empty) {
						this.m_pe_tag = null;
					}
				}
			}
			if(this.pctags && this.m_pc_tag.has!Compound("display") && this.m_pc_tag.get!Compound("display").has("Name")) {
				this.m_pc_tag.get!Compound("display").remove("Name");
				if(this.m_pc_tag.get!Compound("display").empty) {
					this.m_pc_tag.remove("display");
					if(this.m_pc_tag.empty) {
						this.m_pc_tag = null;
					}
				}
			}
		} else {
			if(this.m_pe_tag is null) this.m_pe_tag = new Compound("");
			if(!this.m_pe_tag.has!Compound("display")) this.m_pe_tag["display"] = new Compound("");
			this.m_pe_tag.get!Compound("display")["Name"] = new String(name);
			if(this.m_pc_tag is null) this.m_pc_tag = new Compound("");
			if(!this.m_pc_tag.has!Compound("display")) this.m_pc_tag["display"] = new Compound("");
			this.m_pc_tag.get!Compound("display")["Name"] = new String(name);
		}
		return this.m_name = name;
	}

	public @safe void addEnchantment(Enchantment ench) {
		this.addEnchantment(ench.id, ench.level);
	}

	public @safe void addEnchantment(ushort ench, ushort level=1) in { assert(level != 0, "Invalid enchantment level given"); } body {
		if(ench in this.enchantments) {
			this.removeEnchantment(ench);
		}
		this.enchantments[ench] = level.to!ubyte;
		//save to pe
		if(this.m_pe_tag is null) this.m_pe_tag = new Compound("");
		if(!this.m_pe_tag.has!(ListOf!Compound)("ench")) this.m_pe_tag["ench"] = new ListOf!Compound();
		this.m_pe_tag.get!(ListOf!Compound)("ench") ~= new Compound([new Short("id", ench.pe), new Short("lvl", level)]);
		//save to pc
		if(this.m_pc_tag is null) this.m_pc_tag = new Compound("");
		if(!this.m_pc_tag.has!(ListOf!Compound)("ench")) this.m_pc_tag["ench"] = new ListOf!Compound();
		this.m_pc_tag.get!(ListOf!Compound)("ench") ~= new Compound([new Short("id", ench.pc), new Short("lvl", level)]);
	}

	public @safe void addEnchantment(ushort ench, string level) {
		this.addEnchantment(ench, level.roman & 255);
	}

	alias enchant = this.addEnchantment;

	public final @safe bool hasEnchantment(Enchantment ench) {
		return this.hasEnchantment(ench.id);
	}

	public final @safe bool hasEnchantment(ushort ench) {
		return ench in this.enchantments ? true : false;
	}

	public @safe void removeEnchantment(Enchantment ench) {}

	public @trusted void removeEnchantment(ushort ench) {
		if(ench in this.enchantments) {
			this.enchantments.remove(ench);
			foreach(size_t index, Compound compound; this.m_pe_tag.get!(ListOf!Compound)("ench")[]) {
				if(compound.has!Short("id") && compound.get!Short("id") == ench.pe) {
					this.m_pe_tag.get!(ListOf!Compound)("ench").remove(index);
					break;
				}
			}
			if(this.enchantments.length == 0) {
				this.m_pe_tag.remove("ench");
				if(this.m_pe_tag.empty) {
					this.m_pe_tag = null;
				}
			}
		}
	}

	public @safe uint getEnchantmentLevel(ushort ench) {
		return this.enchantments[ench];
	}

	/**
	 * Deep comparation of 2 instantiated items.
	 * Compare ids, metas, custom names and enchantments.
	 * Example:
	 * ---
	 * Item a = new Items.Beetroot();
	 * Item b = a.dup;
	 * assert(a == b);
	 * 
	 * a.customName = "beetroot";
	 * assert(a != b);
	 * 
	 * b.customName = "beetroot";
	 * a.enchant(Enchantments.PROTECTION, "IV");
	 * b.enchant(Enchantments.PROTECTION, "IV");
	 * assert(a == b);
	 * ---
	 */
	public override @safe @nogc bool opEquals(Object o) {
		if(cast(Item)o) {
			Item i = cast(Item)o;
			return this.ids == i.ids && this.metas == i.metas && this.petags == i.petags && this.pctags == i.pctags;
		}
		return false;
	}

	/**
	 * Compare an item with its type as a string or a group of strings.
	 * Example:
	 * ---
	 * Item item = new Items.Beetroot();
	 * assert(item == Items.BEETROOT);
	 * assert(item == [Items.BEETROOT_SOUP, Items.BEETROOT]);
	 * ---
	 */
	public @safe @nogc bool opEquals(string item) {
		return item == this.name;
	}

	/// ditto
	public @safe @nogc bool opEquals(string[] items) {
		foreach(string item ; items) {
			if(this.opEquals(item)) return true;
		}
		return false;
	}

	/**
	 * Returns the item as string in format "name" or
	 * "name:damage" for tools.
	 */
	public override @safe string toString() {
		return this.name ~ (this.tool ? (":" ~ this.metas.pe.to!string) : "") ~ (this.customName != "" ? (" (\"" ~ this.customName ~ "\")") : "");
	}

	/**
	 * Create a slot with the Item::max as count
	 * Example:
	 * ---
	 * Slot a = new Slot(new Items.Beetroot(), 12);
	 * Slot b = new Items.Beetroot(); // same as new Items.Beetroot().slot;
	 * 
	 * assert(a.count == 12);
	 * assert(b.count == 64);
	 * ---
	 */
	public final @property @safe Slot slot() {
		return Slot(this);
	}

	/// ditto
	alias slot this;

}

/*template Translatable(T:Item) {
	alias Translatable = GenericTranslatable!("this.customName", T);
}*/

class SimpleItem(string ct_name, shortgroup ct_ids, shortgroup ct_metas, ubyte maxstack=64, E...) : Item
	if(staticIndexOf!("crop", E) < 0 || (staticIndexOf!("crop", E) + 1 < E.length && is(typeof(E[staticIndexOf!("crop", E) + 1]) == BlockData))) {

	public @safe this(F...)(F args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc shortgroup ids() {
		return ct_ids;
	}

	public override pure nothrow @property @safe @nogc shortgroup metas() {
		return ct_metas;
	}

	public final override pure nothrow @property @safe @nogc string name() {
		return ct_name;
	}

	public override pure nothrow @property @safe @nogc ubyte max() {
		return maxstack;
	}

	public override @property @safe @nogc bool placeable() {
		static if(staticIndexOf!("crop", E) >= 0) return true;
		else return false;
	}

	public override @safe BlockData place(World world, BlockPosition position) {
		static if(staticIndexOf!("crop", E) >= 0) {
			Block block = world[position - [0, 1, 0]];
			if(block == Blocks.FARMLAND) return E[staticIndexOf!("crop", E) + 1];
		}
		return Blocks.AIR;
	}

	alias petag = super.petag;

	alias pctag = super.pctag;
	
	alias slot this;

}

class PlaceableItem(string name, shortgroup ids, shortgroup metas, BlockData blockdata, ubyte maxstack=64) : SimpleItem!(name, ids, metas, maxstack) {

	public @safe this(F...)(F args) {
		super(args);
	}

	public override @property @safe @nogc bool placeable() {
		return true;
	}

	public override @property @safe BlockData place(World world, BlockPosition position) {
		return blockdata;
	}
	
	alias slot this;

}

class ToolItem(string name, shortgroup ids, shortgroup ct_metas, ubyte type, ubyte material, ushort durability, uint attackstrength=1, E...) : SimpleItem!(name, ids, ct_metas, 1, E) {

	protected ushort damage;

	public @safe this(F...)(F args) {
		static if(F.length > 0 && is(typeof(F[0]) : int)) {
			super(args[1..$]);
			this.damage = args[0] & ushort.max;
		} else {
			super(args);
		}
	}

	public override pure nothrow @property @safe @nogc shortgroup metas() {
		return shortgroup(this.damage, this.damage);
	}

	public final override pure nothrow @property @safe @nogc ubyte toolType() {
		return type;
	}

	public final override pure nothrow @property @safe @nogc ubyte toolMaterial() {
		return material;
	}

	public final override pure nothrow @property @safe @nogc bool finished() {
		return this.damage >= durability;
	}

	public final override pure nothrow @property @safe @nogc uint attack() {
		return attackstrength;
	}
	
	alias slot this;

}

class ConsumeableItem(string name, shortgroup ids, shortgroup metas, ubyte maxstack, EffectInfo[] effects, string residue="substract", E...) : SimpleItem!(name, ids, metas, maxstack, E) if(residue == "substract" || residue == "bowl" || residue == "bottle") {

	public @safe this(F...)(F args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc bool consumeable() {
		return true;
	}

	public override Item onConsumed(Player player) {
		static if(effects.length > 0) {
			foreach(EffectInfo effect ; effects) {
				if(effect.probability >= 1 || player.world.random.probability(effect.probability)) {
					player.addEffect(new Effect(effect.id, effect.duration, effect.level));
				}
			}
		}
		static if(residue == "substract") return null;
		else static if(residue == "bottle") return player.world.items.get(Items.GLASS_BOTTLE);
		else return player.world.items.get(Items.BOWL);
	}
	
	alias slot this;

}

class FoodItem(string name, shortgroup ids, shortgroup metas, ubyte maxstack, uint ghunger, float gsaturation, EffectInfo[] effects=[], string residue="substract", E...) : ConsumeableItem!(name, ids, metas, maxstack, effects, residue, E) {

	public @safe this(F...)(F args) {
		super(args);
	}

	public static pure nothrow @property @safe @nogc uint hunger() { return ghunger; }
	
	public static pure nothrow @property @safe @nogc float saturation() { return gsaturation; }

	public override Item onConsumed(Player player) {
		player.hunger = player.hunger + ghunger;
		player.saturate(gsaturation);
		return super.onConsumed(player);
	}
	
	alias slot this;

}

alias SimpleFoodItem(string name, shortgroup ids, uint ghunger, float gsaturation) = FoodItem!(name, ids, META!0, 64, ghunger, gsaturation);

alias SoupItem(string name, shortgroup ids, shortgroup metas, uint ghunger, float gsaturation) = FoodItem!(name, ids, metas, 1, ghunger, gsaturation, [], "bowl");

alias CropFood(string name, shortgroup ids, uint ghunger, float gsaturation, BlockData block) = FoodItem!(name, ids, META!0, 64, ghunger, gsaturation, [], "substract", "crop", block);

class PotionItem(string name, shortgroup metas, EffectInfo eff) : ConsumeableItem!(name, ID!373, metas, 1, eff.id == 0 ? [] : [eff], "bottle") {

	public @safe this(F...)(F args) {
		super(args);
	}

	public static pure nothrow @property @safe @nogc EffectInfo effect() {
		return eff;
	}
	
	alias slot this;

}


abstract class IStorage {
	
	public @safe Item get(ushort damage);
	
}

class Storage(O:Item, bool cwd) : IStorage {

	public override @safe O get(ushort damage) {
		static if(cwd) return new O(damage);
		else return new O();
	}
	
}

final class ItemsStorage {
	
	protected IStorage[uint] pe_objects;
	protected IStorage[uint] pc_objects;
	protected IStorage[string] objects;
	
	public @safe ItemsStorage registerAll(C)() {
		foreach(a ; __traits(allMembers, C)) {
			static if(mixin("is(C." ~ a ~ " : Item)")) {
				mixin("this.register!(C." ~ a ~ ")();");
			}
		}
		return this;
	}
	
	public @safe void register(O:Item)() if(__traits(compiles, new O())) {
		O ins = new O();
		this.register!O(ins.name, ins.ids, ins.metas);
	}
	
	public @safe void register(O:Item)(string name, shortgroup ids, shortgroup metas) {
		IStorage storage;
		static if(__traits(compiles, new O(ushort.max))) {
			storage = new Storage!(O, true)();
		} else {
			storage = new Storage!(O, false)();
		}
		this.pe_objects[(ids.pe << 16) | metas.pe] = storage;
		this.pc_objects[(ids.pc << 16) | metas.pc] = storage;
		this.objects[name] = storage;
	}
	
	public @property @safe Item get(string name, ushort damage=0) {
		return name in this.objects ? this.objects[name].get(damage) : null;
	}
	
	public @property @safe Item peget(ushort id, ushort damage=0) {
		return ((id << 16) | damage) in this.pe_objects ? this.pe_objects[(id << 16) | damage].get(damage) : ((id << 16) in this.pe_objects ? this.pe_objects[id << 16].get(damage) : null);
	}
	
	public @property @safe Item pcget(ushort id, ushort damage=0) {
		return ((id << 16) | damage) in this.pc_objects ? this.pc_objects[(id << 16) | damage].get(damage) : ((id << 16) in this.pc_objects ? this.pc_objects[id << 16].get(damage) : null);
	}

	public @safe bool has(string name) {
		return name in this.objects ? true : false;
	}
	
	public @property @safe string[] indexes() {
		string[] ret;
		foreach(string i, IStorage s; this.objects) {
			ret ~= i;
		}
		return ret;
	}
	
	public @property @safe ItemsStorage dup() {
		ItemsStorage ret = new ItemsStorage();
		ret.pe_objects = this.pe_objects;
		ret.pc_objects = this.pc_objects;
		ret.objects = this.objects;
		return ret;
	}
	
}

public interface ItemsStorageHolder {
	
	public @property @safe @nogc ItemsStorage items();
	
}
