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
static import std.json;
import std.string : toLower, replace;
import std.traits : isIntegral;
import std.typetuple : TypeTuple, staticIndexOf;

import common.sel;

import sel.player : Player;
import sel.block.block : Block, PlacedBlock, Blocks;
import sel.entity.effect : Effects;
import sel.entity.entity : Entity;
import sel.entity.human : Human;
import sel.entity.interfaces : Arthropods, Undead;
import sel.entity.projectile : FallingBlock;
import sel.item.consumeable;
import sel.item.enchanting;
import sel.item.miscellaneous;
import sel.item.placeable;
import sel.item.slot : Slot;
import sel.item.tool;
import sel.math.vector : BlockPosition, face;
import sel.nbt.tags : Compound, DefinedCompound, List, ListOf, Short, String;
import sel.util.color : Color;
import sel.util.lang : GenericTranslatable = Translatable;
import sel.world.world : World;

static import sul.items;
import sul.items : _ = Items;

static import sul.enchantments;

private enum unimplemented;

public final class Items {

	private Item function(ushort damage)[] indexes;
	private Item function(ushort damage)[ushort][] minecraft, pocket;
	private Item function(ushort damage)[string] strings;

	public this() {
		foreach_reverse(a ; __traits(allMembers, Items)) {
			static if(mixin("is(" ~ a ~ " : Item)")) {
				mixin("this.register!" ~ a ~ "();");
			}
		}
	}

	public void register(T:Item)() if(is(typeof(T.sul) == sul.items.Item)) {
		static if(__traits(compiles, new T(ushort.max))) {
			auto f = (ushort damage){ return cast(Item)new T(damage); };
		} else {
			auto f = (ushort damage){ return cast(Item)new T(); };
		}
		if(this.indexes.length <= T.sul.index) this.indexes.length = T.sul.index + 1;
		this.indexes[T.sul.index] = f;
		if(T.sul.minecraft) {
			if(this.minecraft.length < T.sul.minecraft.id) this.minecraft.length = T.sul.minecraft.id + 1;
			this.minecraft[T.sul.minecraft.id][T.sul.minecraft.meta] = f;
		}
		if(T.sul.pocket) {
			if(this.pocket.length < T.sul.pocket.id) this.pocket.length = T.sul.pocket.id + 1;
			this.pocket[T.sul.pocket.id][T.sul.pocket.meta] = f;
		}
		this.strings[T.sul.name] = f;
	}

	public Item function(ushort) getConstructor(size_t index) {
		return this.indexes.length < index ? this.indexes[index] : null;
	}

	public Item get(size_t index, ushort damage=0) {
		return this.indexes.length < index ? this.indexes[index](damage) : null;
	}

	public Item fromMinecraft(ushort id, ushort damage=0) {
		if(this.minecraft.length < id) return null;
		auto data = this.minecraft[id];
		auto dam = damage in data;
		return dam ? (*dam)(damage) : null;
	}

	public Item fromPocket(ushort id, ushort damage=0) {
		if(this.pocket.length < id) return null;
		auto data = this.pocket[id];
		auto dam = damage in data;
		return dam ? (*dam)(damage) : null;
	}

	public Item fromString(string name, ushort damage=0) {
		auto f = name.toLower.replace("_", " ") in this.strings;
		return f ? (*f)(damage) : null;
	}

	public enum air = _.AIR.index;

	public enum stone = _.STONE.index;
	public alias Stone = PlaceableItem!(_.STONE, Blocks.stone);

	public enum granite = _.GRANITE.index;
	public alias Granite = PlaceableItem!(_.GRANITE, Blocks.granite);

	public enum polishedGranite = _.POLISHED_GRANITE.index;
	public alias PolishedGranite = PlaceableItem!(_.POLISHED_GRANITE, Blocks.polishedGranite);

	public enum diorite = _.DIORITE.index;
	public alias Diorite = PlaceableItem!(_.DIORITE, Blocks.diorite);

	public enum polishedDiorite = _.POLISHED_DIORITE.index;
	public alias PolishedDiorite = PlaceableItem!(_.POLISHED_DIORITE, Blocks.polishedDiorite);

	public enum andesite = _.ANDESITE.index;
	public alias Andesite = PlaceableItem!(_.ANDESITE, Blocks.andesite);

	public enum polishedAndesite = _.POLISHED_ANDESITE.index;
	public alias PolishedAndesite = PlaceableItem!(_.POLISHED_ANDESITE, Blocks.polishedAndesite);

	public enum grass = _.GRASS.index;
	public alias Grass = PlaceableItem!(_.GRASS, Blocks.grass);

	public enum dirt = _.DIRT.index;
	public alias Dirt = PlaceableItem!(_.DIRT, Blocks.dirt);

	public enum coarseDirt = _.COARSE_DIRT.index;
	public alias CoarseDirt = PlaceableItem!(_.COARSE_DIRT, Blocks.coarseDirt);

	public enum podzol = _.PODZOL.index;
	public alias Podzol = PlaceableItem!(_.PODZOL, Blocks.podzol);

	public enum cobblestone = _.COBBLESTONE.index;
	public alias Cobblestone = PlaceableItem!(_.COBBLESTONE, Blocks.cobblestone);

	public enum oakWoodPlanks = _.OAK_WOOD_PLANKS.index;
	public alias OakWoodPlanks = PlaceableItem!(_.OAK_WOOD_PLANKS, Blocks.oakWoodPlanks);
	
	public enum spruceWoodPlanks = _.SPRUCE_WOOD_PLANKS.index;
	public alias SpruceWoodPlanks = PlaceableItem!(_.SPRUCE_WOOD_PLANKS, Blocks.spruceWoodPlanks);
	
	public enum birchWoodPlanks = _.BIRCH_WOOD_PLANKS.index;
	public alias BirchWoodPlanks = PlaceableItem!(_.BIRCH_WOOD_PLANKS, Blocks.birchWoodPlanks);
	
	public enum jungleWoodPlanks = _.JUNGLE_WOOD_PLANKS.index;
	public alias JungleWoodPlanks = PlaceableItem!(_.JUNGLE_WOOD_PLANKS, Blocks.jungleWoodPlanks);
	
	public enum acaciaWoodPlanks = _.ACACIA_WOOD_PLANKS.index;
	public alias AcaciaWoodPlanks = PlaceableItem!(_.ACACIA_WOOD_PLANKS, Blocks.acaciaWoodPlanks);
	
	public enum darkOakWoodPlanks = _.DARK_OAK_WOOD_PLANKS.index;
	public alias DarkOakWoodPlanks = PlaceableItem!(_.DARK_OAK_WOOD_PLANKS, Blocks.darkOakWoodPlanks);

	public enum woodPlanks = [oakWoodPlanks, spruceWoodPlanks, birchWoodPlanks, jungleWoodPlanks, acaciaWoodPlanks, darkOakWoodPlanks];
	public alias WoodPlanks = TypeTuple!(OakWoodPlanks, SpruceWoodPlanks, BirchWoodPlanks, JungleWoodPlanks, AcaciaWoodPlanks, DarkOakWoodPlanks);
	
	public enum oakSapling = _.OAK_SAPLING.index;
	public alias OakSapling = PlaceableItem!(_.OAK_SAPLING, Blocks.oakSapling, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);

	public enum spruceSapling = _.SPRUCE_SAPLING.index;
	public alias SpruceSapling = PlaceableItem!(_.SPRUCE_SAPLING, Blocks.spruceSapling, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);
	
	public enum birchSapling = _.BIRCH_SAPLING.index;
	public alias BirchSapling = PlaceableItem!(_.BIRCH_SAPLING, Blocks.birchSapling, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);

	public enum jungleSapling = _.JUNGLE_SAPLING.index;
	public alias JungleSapling = PlaceableItem!(_.JUNGLE_SAPLING, Blocks.jungleSapling, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);
	
	public enum acaciaSapling = _.ACACIA_SAPLING.index;
	public alias AcaciaSapling = PlaceableItem!(_.ACACIA_SAPLING, Blocks.acaciaSapling, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);

	public enum darkOakSapling = _.DARK_OAK_SAPLING.index;
	public alias DarkOakSapling = PlaceableItem!(_.DARK_OAK_SAPLING, Blocks.darkOakSapling, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);

	public enum sapling = [oakSapling, spruceSapling, birchSapling, acaciaSapling, darkOakSapling];
	public alias Sapling = TypeTuple!(OakSapling, SpruceSapling, BirchSapling, JungleSapling, AcaciaSapling, DarkOakSapling);

	public enum bedrock = _.BEDROCK.index;
	public alias Bedrock = PlaceableItem!(_.BEDROCK, Blocks.bedrock);

	public enum sand = _.SAND.index;
	public alias Sand = PlaceableItem!(_.SAND, Blocks.sand);

	public enum redSand = _.RED_SAND.index;
	public alias RedSand = PlaceableItem!(_.RED_SAND, Blocks.redSand);

	public enum gravel = _.GRAVEL.index;
	public alias Gravel = PlaceableItem!(_.GRAVEL, Blocks.gravel);

	public enum goldOre = _.GOLD_ORE.index;
	public alias GoldOre = PlaceableItem!(_.GOLD_ORE, Blocks.goldOre);

	public enum ironOre = _.IRON_ORE.index;
	public alias IronOre = PlaceableItem!(_.IRON_ORE, Blocks.ironOre);

	public enum coalOre = _.COAL_ORE.index;
	public alias CoalOre = PlaceableItem!(_.COAL_ORE, Blocks.coalOre);
	
	public enum oakWood = _.OAK_WOOD.index;
	public alias OakWood = WoodItem!(_.OAK_WOOD, Blocks.oakWood);
	
	public enum spruceWood = _.SPRUCE_WOOD.index;
	public alias SpruceWood = WoodItem!(_.SPRUCE_WOOD, Blocks.spruceWood);
	
	public enum birchWood = _.BIRCH_WOOD.index;
	public alias BirchWood = WoodItem!(_.BIRCH_WOOD, Blocks.birchWood);

	public enum jungleWood = _.JUNGLE_WOOD.index;
	public alias JungleWood = WoodItem!(_.JUNGLE_WOOD, Blocks.jungleWood);

	public enum acaciaWood = _.ACACIA_WOOD.index;
	public alias AcaciaWood = WoodItem!(_.ACACIA_WOOD, Blocks.acaciaWood);
	
	public enum darkOakWood = _.DARK_OAK_WOOD.index;
	public alias DarkOakWood = WoodItem!(_.DARK_OAK_WOOD, Blocks.darkOakWood);
	
	public enum oakLeaves = _.OAK_LEAVES.index;
	public alias OakLeaves = PlaceableItem!(_.OAK_LEAVES, Blocks.oakLeavesNoDecay);

	public enum spruceLeaves = _.SPRUCE_LEAVES.index;
	public alias SpruceLeaves = PlaceableItem!(_.SPRUCE_LEAVES, Blocks.spruceLeavesNoDecay);

	public enum birchLeaves = _.BIRCH_LEAVES.index;
	public alias BirchLeaves = PlaceableItem!(_.BIRCH_LEAVES, Blocks.birchLeavesNoDecay);
	
	public enum jungleLeaves = _.JUNGLE_LEAVES.index;
	public alias JungleLeaves = PlaceableItem!(_.JUNGLE_LEAVES, Blocks.jungleLeavesNoDecay);
	
	public enum acaciaLeaves = _.ACACIA_LEAVES.index;
	public alias AcaciaLeaves = PlaceableItem!(_.ACACIA_LEAVES, Blocks.acaciaLeavesNoDecay);
	
	public enum darkOakLeaves = _.DARK_OAK_LEAVES.index;
	public alias DarkOakLeaves = PlaceableItem!(_.DARK_OAK_LEAVES, Blocks.darkOakLeavesNoDecay);

	public enum sponge = _.SPONGE.index;
	public alias Sponge = PlaceableItem!(_.SPONGE, Blocks.sponge);

	public enum wetSponge = _.WET_SPONGE.index;
	public alias WetSponge = PlaceableItem!(_.WET_SPONGE, Blocks.wetSponge);

	public enum glass = _.GLASS.index;
	public alias Glass = PlaceableItem!(_.GLASS, Blocks.glass);

	public enum lapisLazuliOre = _.LAPIS_LAZULI_ORE.index;
	public alias LapisLazuliOre = PlaceableItem!(_.LAPIS_LAZULI_ORE, Blocks.lapisLazuliOre);

	public enum lapisLazuliBlock = _.LAPIS_LAZULI_BLOCK.index;
	public alias LapisLazuliBlock = PlaceableItem!(_.LAPIS_LAZULI_BLOCK, Blocks.lapisLazuliBlock);

	public @unimplemented enum dispenser = _.DISPENSER.index;
	public alias Dispenser = SimpleItem!(_.DISPENSER);

	public enum sandstone = _.SANDSTONE.index;
	public alias Sandstone = PlaceableItem!(_.SANDSTONE, Blocks.sandstone);

	public enum chiseledSandstone = _.CHISELED_SANDSTONE.index;
	public alias ChiseledSandstone = PlaceableItem!(_.CHISELED_SANDSTONE, Blocks.chiseledSandstone);

	public enum smoothSandstone = _.SMOOTH_SANDSTONE.index;
	public alias SmoothSandstone = PlaceableItem!(_.SMOOTH_SANDSTONE, Blocks.smoothSandstone);

	public enum noteBlock = _.NOTE_BLOCK.index;
	public alias NoteBlock = PlaceableItem!(_.NOTE_BLOCK, Blocks.noteBlock);
	
	public @unimplemented enum poweredRail = _.POWERED_RAIL.index;
	public alias PoweredRail = SimpleItem!(_.POWERED_RAIL);
	
	public @unimplemented enum detectorRail = _.DETECTOR_RAIL.index;
	public alias DetectorRail = SimpleItem!(_.DETECTOR_RAIL);

	public @unimplemented enum stickyPiston = _.STICKY_PISTON.index;
	public alias StickyPiston = SimpleItem!(_.STICKY_PISTON);

	public enum cobweb = _.COBWEB.index;
	public alias Cobweb = PlaceableItem!(_.COBWEB, Blocks.cobweb);

	public enum tallGrass = _.TALL_GRASS.index;
	public alias TallGrass = PlaceableItem!(_.TALL_GRASS, Blocks.tallGrass, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);

	public enum fern = _.FERN.index;
	public alias Fern = PlaceableItem!(_.FERN, Blocks.fern, [Blocks.dirt, Blocks.grass, Blocks.podzol, Blocks.coarseDirt] ~ Blocks.farmland);

	public enum deadBush = _.DEAD_BUSH.index;
	public alias DeadBush = PlaceableItem!(_.DEAD_BUSH, Blocks.deadBush, [Blocks.sand, Blocks.redSand, Blocks.dirt, Blocks.podzol, Blocks.coarseDirt, Blocks.hardenedClay] ~ Blocks.stainedClay);
	
	public @unimplemented enum piston = _.PISTON.index;
	public alias Piston = SimpleItem!(_.PISTON);

	public enum whiteWool = _.WHITE_WOOL.index;
	public alias WhiteWool = PlaceableItem!(_.WHITE_WOOL, Blocks.whiteWool);

	public enum orangeWool = _.ORANGE_WOOL.index;
	public alias OrangeWool = PlaceableItem!(_.ORANGE_WOOL, Blocks.orangeWool);
	
	public enum magentaWool = _.MAGENTA_WOOL.index;
	public alias MagentaWool = PlaceableItem!(_.MAGENTA_WOOL, Blocks.magentaWool);

	public enum lightBlueWool = _.LIGHT_BLUE_WOOL.index;
	public alias LightBlueWool = PlaceableItem!(_.LIGHT_BLUE_WOOL, Blocks.lightBlueWool);

	public enum yellowWool = _.YELLOW_WOOL.index;
	public alias YellowWool = PlaceableItem!(_.YELLOW_WOOL, Blocks.yellowWool);

	public enum limeWool = _.LIME_WOOL.index;
	public alias LimeWool = PlaceableItem!(_.LIME_WOOL, Blocks.limeWool);

	public enum pinkWool = _.PINK_WOOL.index;
	public alias PinkWool = PlaceableItem!(_.PINK_WOOL, Blocks.pinkWool);
	
	public enum grayWool = _.GRAY_WOOL.index;
	public alias GrayWool = PlaceableItem!(_.GRAY_WOOL, Blocks.grayWool);
	
	public enum lightGrayWool = _.LIGHT_GRAY_WOOL.index;
	public alias LightGrayWool = PlaceableItem!(_.LIGHT_GRAY_WOOL, Blocks.lightGrayWool);
	
	public enum cyanWool = _.CYAN_WOOL.index;
	public alias CyanWool = PlaceableItem!(_.CYAN_WOOL, Blocks.cyanWool);
	
	public enum purpleWool = _.PURPLE_WOOL.index;
	public alias PurpleWool = PlaceableItem!(_.PURPLE_WOOL, Blocks.purpleWool);
	
	public enum blueWool = _.BLUE_WOOL.index;
	public alias BlueWool = PlaceableItem!(_.BLUE_WOOL, Blocks.blueWool);
	
	public enum brownWool = _.BROWN_WOOL.index;
	public alias BrownWool = PlaceableItem!(_.BROWN_WOOL, Blocks.brownWool);
	
	public enum greenWool = _.GREEN_WOOL.index;
	public alias GreenWool = PlaceableItem!(_.GREEN_WOOL, Blocks.greenWool);
	
	public enum redWool = _.RED_WOOL.index;
	public alias RedWool = PlaceableItem!(_.RED_WOOL, Blocks.redWool);
	
	public enum blackWool = _.BLACK_WOOL.index;
	public alias BlackWool = PlaceableItem!(_.BLACK_WOOL, Blocks.blackWool);
	
	public enum wool = [whiteWool, orangeWool, magentaWool, lightBlueWool, yellowWool, limeWool, pinkWool, grayWool, lightGrayWool, cyanWool, purpleWool, blueWool, brownWool, greenWool, redWool, blackWool];

	public enum dandelion = _.DANDELION.index;
	public alias Dandelion = PlaceableItem!(_.DANDELION, Blocks.dandelion);
	
	public enum poppy = _.POPPY.index;
	public alias Poppy = PlaceableItem!(_.POPPY, Blocks.poppy);
	
	public enum blueOrchid = _.BLUE_ORCHID.index;
	public alias BlueOrchid = PlaceableItem!(_.BLUE_ORCHID, Blocks.blueOrchid);
	
	public enum allium = _.ALLIUM.index;
	public alias Allium = PlaceableItem!(_.ALLIUM, Blocks.allium);
	
	public enum azureBluet = _.AZURE_BLUET.index;
	public alias AzureBluet = PlaceableItem!(_.AZURE_BLUET, Blocks.azureBluet);
	
	public enum redTulip = _.RED_TULIP.index;
	public alias RedTulip = PlaceableItem!(_.RED_TULIP, Blocks.redTulip);
	
	public enum orangeTulip = _.ORANGE_TULIP.index;
	public alias OrangeTulip = PlaceableItem!(_.ORANGE_TULIP, Blocks.orangeTulip);
	
	public enum whiteTulip = _.WHITE_TULIP.index;
	public alias WhiteTulip = PlaceableItem!(_.WHITE_TULIP, Blocks.whiteTulip);
	
	public enum pinkTulip = _.PINK_TULIP.index;
	public alias PinkTulip = PlaceableItem!(_.PINK_TULIP, Blocks.pinkTulip);

	public enum oxeyeDaisy = _.OXEYE_DAISY.index;
	public alias OxeyeDaisy = PlaceableItem!(_.OXEYE_DAISY, Blocks.oxeyeDaisy);
	
	public enum brownMushroom = _.BROWN_MUSHROOM.index; //TODO place on low light level
	public alias BrownMushroom = PlaceableItem!(_.BROWN_MUSHROOM, Blocks.brownMushroom, [Blocks.podzol]);

	public enum redMushroom = _.RED_MUSHROOM.index;
	public alias RedMushroom = PlaceableItem!(_.RED_MUSHROOM, Blocks.redMushroom, [Blocks.podzol]);

	public enum goldBlock = _.GOLD_BLOCK.index;
	public alias GoldBlock = PlaceableItem!(_.GOLD_BLOCK, Blocks.goldBlock);

	public enum ironBlock = _.IRON_BLOCK.index;
	public alias IronBlock = PlaceableItem!(_.IRON_BLOCK, Blocks.ironBlock);

	public enum stoneSlab = _.STONE_SLAB.index;
	public alias StoneSlab = SlabItem!(_.STONE_SLAB, Blocks.stoneSlab, Blocks.upperStoneSlab, Blocks.doubleStoneSlab);

	public enum sandstoneSlab = _.SANDSTONE_SLAB.index;
	public alias SandstoneSlab = SlabItem!(_.SANDSTONE_SLAB, Blocks.sandstoneSlab, Blocks.upperSandstoneSlab, Blocks.doubleSandstoneSlab);

	public enum stoneWoodenSlab = _.STONE_WOODEN_SLAB.index;
	public alias StoneWoodenSlab = SlabItem!(_.STONE_WOODEN_SLAB, Blocks.stoneWoodenSlab, Blocks.upperStoneWoodenSlab, Blocks.doubleStoneWoodenSlab);

	public enum cobblestoneSlab = _.COBBLESTONE_SLAB.index;
	public alias CobblestoneSlab = SlabItem!(_.COBBLESTONE_SLAB, Blocks.cobblestoneSlab, Blocks.upperCobblestoneSlab, Blocks.doubleCobblestoneSlab);

	public enum bricksSlab = _.BRICKS_SLAB.index;
	public alias BricksSlab = SlabItem!(_.BRICKS_SLAB, Blocks.bricksSlab, Blocks.upperBricksSlab, Blocks.doubleBricksSlab);

	public enum stoneBrickSlab = _.STONE_BRICK_SLAB.index;
	public alias StoneBrickSlab = SlabItem!(_.STONE_BRICK_SLAB, Blocks.stoneBrickSlab, Blocks.upperStoneBrickSlab, Blocks.doubleStoneBrickSlab);

	public enum netherBrickSlab = _.NETHER_BRICK_SLAB.index;
	public alias NetherBrickSlab = SlabItem!(_.NETHER_BRICK_SLAB, Blocks.netherBrickSlab, Blocks.upperNetherBrickSlab, Blocks.doubleNetherBrickSlab);

	public enum quartzSlab = _.QUARTZ_SLAB.index;
	public alias QuartzSlab = SlabItem!(_.QUARTZ_SLAB, Blocks.quartzSlab, Blocks.upperQuartzSlab, Blocks.doubleQuartzSlab);

	public enum bricks = _.BRICKS.index;
	public alias Bricks = PlaceableItem!(_.BRICKS, Blocks.bricks);

	public enum tnt = _.TNT.index;
	public alias Tnt = PlaceableItem!(_.TNT, Blocks.tnt);

	public enum bookshelf = _.BOOKSHELF.index;
	public alias Bookshelf = PlaceableItem!(_.BOOKSHELF, Blocks.bookshelf);

	public enum mossStone = _.MOSS_STONE.index;
	public alias MossStone = PlaceableItem!(_.MOSS_STONE, Blocks.mossStone);

	public enum obsidian = _.OBSIDIAN.index;
	public alias Obsidian = PlaceableItem!(_.OBSIDIAN, Blocks.obsidian);

	public enum torch = _.TORCH.index;
	public alias Torch = TorchItem!(_.TORCH, Blocks.torch);

	public enum monsterSpawner = _.MONSTER_SPAWNER.index;
	public alias MonsterSpawner = PlaceableItem!(_.MONSTER_SPAWNER, Blocks.monsterSpawner);

	public enum oakWoodStairs = _.OAK_WOOD_STAIRS.index;
	public alias OakWoodStairs = StairsItem!(_.OAK_WOOD_STAIRS, Blocks.oakWoodStairs);

	public enum chest = _.CHEST.index;
	//TODO place tile in right direction

	public enum diamondOre = _.DIAMOND_ORE.index;
	public alias DiamondOre = PlaceableItem!(_.DIAMOND_ORE, Blocks.diamondOre);

	public enum diamondBlock = _.DIAMOND_BLOCK.index;
	public alias DiamondBlock = PlaceableItem!(_.DIAMOND_BLOCK, Blocks.diamondBlock);

	public enum craftingTable = _.CRAFTING_TABLE.index;
	public alias CraftingTable = PlaceableItem!(_.CRAFTING_TABLE, Blocks.craftingTable);

	public enum furnace = _.FURNACE.index;
	//TODO place tile in the right direction

	public enum ladder = _.LADDER.index;
	//TODO place in the right direction

	public enum rail = _.RAIL.index;
	//TODO

	public enum cobblestoneStairs = _.COBBLESTONE_STAIRS.index;
	public alias CobblestoneStairs = StairsItem!(_.COBBLESTONE_STAIRS, Blocks.cobblestoneStairs);

	public enum lever = _.LEVER.index;
	//TODO

	public enum stonePressurePlate = _.STONE_PRESSURE_PLATE.index;

	public enum woodenPressurePlate = _.WOODEN_PRESSURE_PLATE.index;

	public enum redstoneOre = _.REDSTONE_ORE.index;
	public alias RedstoneOre = PlaceableItem!(_.REDSTONE_ORE, Blocks.redstoneOre);

	public enum redstoneTorch = _.REDSTONE_TORCH.index;

	public enum stoneButton = _.STONE_BUTTON.index;

	public enum snowLayer = _.SNOW_LAYER.index;

	public enum ice = _.ICE.index;
	public alias Ice = PlaceableItem!(_.ICE, Blocks.ice);

	public enum snowBlock = _.SNOW_BLOCK.index;
	public alias SnowBlock = PlaceableItem!(_.SNOW_BLOCK, Blocks.snow);

	public enum cactus = _.CACTUS.index;
	public alias Cactus = PlaceableItem!(_.CACTUS, Blocks.cactus0, [Blocks.sand, Blocks.redSand] ~ Blocks.cactus); //TODO do not place near other blocks

	public enum clayBlock = _.CLAY_BLOCK.index;
	public alias ClayBlock = PlaceableItem!(_.CLAY_BLOCK, Blocks.clay);

	public enum jukebox = _.JUKEBOX.index;
	public alias Jukebox = PlaceableItem!(_.JUKEBOX, Blocks.jukebox);

	public enum oakFence = _.OAK_FENCE.index;

	public enum pumpkin = _.PUMPKIN.index;

	public enum netherrack = _.NETHERRACK.index;
	public alias Netherrack = PlaceableItem!(_.NETHERRACK, Blocks.netherrack);

	public enum soulSand = _.SOUL_SAND.index;
	public alias SoulSand = PlaceableItem!(_.SOUL_SAND, Blocks.soulSand);

	public enum glowstone = _.GLOWSTONE.index;
	public alias Glowstone = PlaceableItem!(_.GLOWSTONE, Blocks.glowstone);

	public enum jackOLantern = _.JACK_O_LANTERN.index;
	
	public enum whiteStainedGlass = _.WHITE_STAINED_GLASS.index;
	public alias WhiteStainedGlass = PlaceableItem!(_.WHITE_STAINED_GLASS, Blocks.whiteStainedGlass);
	
	public enum orangeStainedGlass = _.ORANGE_STAINED_GLASS.index;
	public alias OrangeStainedGlass = PlaceableItem!(_.ORANGE_STAINED_GLASS, Blocks.orangeStainedGlass);
	
	public enum magentaStainedGlass = _.MAGENTA_STAINED_GLASS.index;
	public alias MagentaStainedGlass = PlaceableItem!(_.MAGENTA_STAINED_GLASS, Blocks.magentaStainedGlass);
	
	public enum lightBlueStainedGlass = _.LIGHT_BLUE_STAINED_GLASS.index;
	public alias LightBlueStainedGlass = PlaceableItem!(_.LIGHT_BLUE_STAINED_GLASS, Blocks.lightBlueStainedGlass);
	
	public enum yellowStainedGlass = _.YELLOW_STAINED_GLASS.index;
	public alias YellowStainedGlass = PlaceableItem!(_.YELLOW_STAINED_GLASS, Blocks.yellowStainedGlass);
	
	public enum limeStainedGlass = _.LIME_STAINED_GLASS.index;
	public alias LimeStainedGlass = PlaceableItem!(_.LIME_STAINED_GLASS, Blocks.limeStainedGlass);
	
	public enum pinkStainedGlass = _.PINK_STAINED_GLASS.index;
	public alias PinkStainedGlass = PlaceableItem!(_.PINK_STAINED_GLASS, Blocks.pinkStainedGlass);
	
	public enum grayStainedGlass = _.GRAY_STAINED_GLASS.index;
	public alias GrayStainedGlass = PlaceableItem!(_.GRAY_STAINED_GLASS, Blocks.grayStainedGlass);
	
	public enum lightGrayStainedGlass = _.LIGHT_GRAY_STAINED_GLASS.index;
	public alias LightGrayStainedGlass = PlaceableItem!(_.LIGHT_GRAY_STAINED_GLASS, Blocks.lightGrayStainedGlass);
	
	public enum cyanStainedGlass = _.CYAN_STAINED_GLASS.index;
	public alias CyanStainedGlass = PlaceableItem!(_.CYAN_STAINED_GLASS, Blocks.cyanStainedGlass);
	
	public enum purpleStainedGlass = _.PURPLE_STAINED_GLASS.index;
	public alias PurpleStainedGlass = PlaceableItem!(_.PURPLE_STAINED_GLASS, Blocks.purpleStainedGlass);
	
	public enum blueStainedGlass = _.BLUE_STAINED_GLASS.index;
	public alias BlueStainedGlass = PlaceableItem!(_.BLUE_STAINED_GLASS, Blocks.blueStainedGlass);
	
	public enum brownStainedGlass = _.BROWN_STAINED_GLASS.index;
	public alias BrownStainedGlass = PlaceableItem!(_.BROWN_STAINED_GLASS, Blocks.brownStainedGlass);
	
	public enum greenStainedGlass = _.GREEN_STAINED_GLASS.index;
	public alias GreenStainedGlass = PlaceableItem!(_.GREEN_STAINED_GLASS, Blocks.greenStainedGlass);
	
	public enum redStainedGlass = _.RED_STAINED_GLASS.index;
	public alias RedStainedGlass = PlaceableItem!(_.RED_STAINED_GLASS, Blocks.redStainedGlass);
	
	public enum blackStainedGlass = _.BLACK_STAINED_GLASS.index;
	public alias BlackStainedGlass = PlaceableItem!(_.BLACK_STAINED_GLASS, Blocks.blackStainedGlass);
	
	public enum stainedGlass = [whiteStainedGlass, orangeStainedGlass, magentaStainedGlass, lightBlueStainedGlass, yellowStainedGlass, limeStainedGlass, pinkStainedGlass, grayStainedGlass, lightGrayStainedGlass, cyanStainedGlass, purpleStainedGlass, blueStainedGlass, brownStainedGlass, greenStainedGlass, redStainedGlass, blackStainedGlass];

	public enum woodenTrapdoor = _.WOODEN_TRAPDOOR.index;

	public enum stoneMonsterEgg = _.STONE_MONSTER_EGG.index;
	public alias StoneMonsterEgg = PlaceableItem!(_.STONE_MONSTER_EGG, Blocks.stoneMonsterEgg);

	public enum cobblestoneMonsterEgg = _.COBBLESTONE_MONSTER_EGG.index;
	public alias CobblestoneMonsterEgg = PlaceableItem!(_.COBBLESTONE_MONSTER_EGG, Blocks.cobblestoneMonsterEgg);
	
	public enum stoneBrickMonsterEgg = _.STONE_BRICK_MONSTER_EGG.index;
	public alias StoneBrickMonsterEgg = PlaceableItem!(_.STONE_BRICK_MONSTER_EGG, Blocks.stoneBrickMonsterEgg);
	
	public enum mossyStoneBrickMonsterEgg = _.MOSSY_STONE_BRICK_MONSTER_EGG.index;
	public alias MossyStoneBrickMonsterEgg = PlaceableItem!(_.MOSSY_STONE_BRICK_MONSTER_EGG, Blocks.mossyStoneBrickMonsterEgg);
	
	public enum crackedStoneBrickMonsterEgg = _.CRACKED_STONE_BRICK_MONSTER_EGG.index;
	public alias CrackedStoneBrickMonsterEgg = PlaceableItem!(_.CRACKED_STONE_BRICK_MONSTER_EGG, Blocks.crackedStoneBrickMonsterEgg);
	
	public enum chiseledStoneBrickMonsterEgg = _.CHISELED_STONE_BRICK_MONSTER_EGG.index;
	public alias ChiseledStoneBrickMonsterEgg = PlaceableItem!(_.CHISELED_STONE_BRICK_MONSTER_EGG, Blocks.chiseledStoneBrickMonsterEgg);

	public enum stoneBricks = _.STONE_BRICKS.index;
	public alias StoneBricks = PlaceableItem!(_.STONE_BRICKS, Blocks.stoneBricks);
	
	public enum mossyStoneBricks = _.MOSSY_STONE_BRICKS.index;
	public alias MossyStoneBricks = PlaceableItem!(_.MOSSY_STONE_BRICKS, Blocks.mossyStoneBricks);

	public enum crackedStoneBricks = _.CRACKED_STONE_BRICKS.index;
	public alias CrackedStoneBricks = PlaceableItem!(_.CRACKED_STONE_BRICKS, Blocks.crackedStoneBricks);
	
	public enum chiseledStoneBricks = _.CHISELED_STONE_BRICKS.index;
	public alias ChiseledStoneBricks = PlaceableItem!(_.CHISELED_STONE_BRICKS, Blocks.chiseledStoneBricks);

	public enum brownMushroomBlock = _.BROWN_MUSHROOM_BLOCK.index;
	public alias BrownMushroomBlock = PlaceableItem!(_.BROWN_MUSHROOM_BLOCK, Blocks.brownMushroomCapsEverywhere);

	public enum redMushroomBlock = _.RED_MUSHROOM_BLOCK.index;
	public alias RedMushroomBlock = PlaceableItem!(_.RED_MUSHROOM_BLOCK, Blocks.redMushroomCapsEverywhere);

	public enum ironBars = _.IRON_BARS.index;
	public alias IronBars = PlaceableItem!(_.IRON_BARS, Blocks.ironBars);

	public enum glassPane = _.GLASS_PANE.index;
	public alias GlassPane = PlaceableItem!(_.GLASS_PANE, Blocks.glassPane);

	public enum melonBlock = _.MELON_BLOCK.index;
	public alias MelonBlock = PlaceableItem!(_.MELON_BLOCK, Blocks.melon);

	public enum vines = _.VINES.index;

	public enum oakFenceGate = _.OAK_FENCE_GATE.index;

	public enum brickStairs = _.BRICK_STAIRS.index;

	public enum stoneBrickStairs = _.STONE_BRICK_STAIRS.index;

	public enum mycelium = _.MYCELIUM.index;
	public alias Mycelium = PlaceableItem!(_.MYCELIUM, Blocks.mycelium);

	public enum lilyPad = _.LILY_PAD.index;
	public alias LilyPad = PlaceableItem!(_.LILY_PAD, Blocks.lilyPad, [Blocks.flowingWater0, Blocks.stillWater0, Blocks.ice] ~ Blocks.frostedIce);

	public enum netherBrickBlock = _.NETHER_BRICK_BLOCK.index;
	public alias NetherBrickBlock = PlaceableItem!(_.NETHER_BRICK_BLOCK, Blocks.netherBrick);

	public enum netherBrickFence = _.NETHER_BRICK_FENCE.index;
	public alias NetherBrickFence = PlaceableItem!(_.NETHER_BRICK_FENCE, Blocks.netherBrickFence);

	public enum netherBrickStairs = _.NETHER_BRICK_STAIRS.index;

	public enum enchantmentTable = _.ENCHANTMENT_TABLE.index;
	public alias EnchantmentTable = PlaceableItem!(_.ENCHANTMENT_TABLE, Blocks.enchantmentTable);

	public enum endPortalFrame = _.END_PORTAL_FRAME.index;

	public enum endStone = _.END_STONE.index;
	public alias EndStone = PlaceableItem!(_.END_STONE, Blocks.endStone);

	public enum dragonEgg = _.DRAGON_EGG.index;
	public alias DragonEgg = PlaceableItem!(_.DRAGON_EGG, Blocks.dragonEgg);

	public enum redstoneLamp = _.REDSTONE_LAMP.index;
	public alias RedstoneLamp = PlaceableItem!(_.REDSTONE_LAMP, Blocks.inactiveRedstoneLamp);

	public enum oakWoodSlab = _.OAK_WOOD_SLAB.index;

	public enum spruceWoodSlab = _.SPRUCE_WOOD_SLAB.index;

	public enum birchWoodSlab = _.BIRCH_WOOD_SLAB.index;

	public enum jungleWoodSlab = _.JUNGLE_WOOD_SLAB.index;

	public enum acaciaWoodSlab = _.ACACIA_WOOD_SLAB.index;

	public enum darkOakWoodSlab = _.DARK_OAK_WOOD_SLAB.index;

	public enum sandstoneStairs = _.SANDSTONE_STAIRS.index;

	public enum emeraldOre = _.EMERALD_ORE.index;
	public alias EmeraldOre = PlaceableItem!(_.EMERALD_ORE, Blocks.emeraldOre);

	public enum enderChest = _.ENDER_CHEST.index;

	public enum tripwireHook = _.TRIPWIRE_HOOK.index;

	public enum emeraldBlock = _.EMERALD_BLOCK.index;
	public alias EmeraldBlock = PlaceableItem!(_.EMERALD_BLOCK, Blocks.emeraldBlock);

	public enum spruceWoodStairs = _.SPRUCE_WOOD_STAIRS.index;

	public enum birchWoodStairs = _.BIRCH_WOOD_STAIRS.index;

	public enum jungleWoodStairs = _.JUNGLE_WOOD_STAIRS.index;

	public enum commandBlock = _.COMMAND_BLOCK.index;

	public enum beacon = _.BEACON.index;
	public alias Beacon = PlaceableItem!(_.BEACON, Blocks.beacon);

	public enum cobblestoneWall = _.COBBLESTONE_WALL.index;
	public alias CobblestoneWall = PlaceableItem!(_.COBBLESTONE_WALL, Blocks.cobblestoneWall);

	public enum mossyCobblestoneWall = _.MOSSY_COBBLESTONE_WALL.index;
	public alias MossyCobblestoneWall = PlaceableItem!(_.MOSSY_COBBLESTONE_WALL, Blocks.mossyCobblestoneWall);

	public enum woodenButton = _.WOODEN_BUTTON.index;

	public enum anvil = _.ANVIL.index;

	public enum trappedChest = _.TRAPPED_CHEST.index;

	public enum lightWeightedPressurePlate = _.LIGHT_WEIGHTED_PRESSURE_PLATE.index;

	public enum heavyWeightedPressurePlate = _.HEAVY_WEIGHTED_PRESSURE_PLATE.index;

	public enum daylightSensor = _.DAYLIGHT_SENSOR.index;

	public enum redstoneBlock = _.REDSTONE_BLOCK.index;
	public alias RedstoneBlock = PlaceableItem!(_.REDSTONE_BLOCK, Blocks.redstoneBlock);

	public enum netherQuartzOre = _.NETHER_QUARTZ_ORE.index;
	public alias NetherQuartzOre = PlaceableItem!(_.NETHER_QUARTZ_ORE, Blocks.netherQuartzOre);

	public enum hopper = _.HOPPER.index;

	public enum quartzBlock = _.QUARTZ_BLOCK.index;
	public alias QuartzBlock = PlaceableItem!(_.QUARTZ_BLOCK, Blocks.quartzBlock);

	public enum chiseledQuartzBlock = _.CHISELED_QUARTZ_BLOCK.index;
	public alias ChiseledQuartzBlock = PlaceableItem!(_.CHISELED_QUARTZ_BLOCK, Blocks.chiseledQuartzBlock);

	public enum pillarQuartzBlock = _.PILLAR_QUARTZ_BLOCK.index;

	public enum quartzStairs = _.QUARTZ_STAIRS.index;

	public enum activatorRail = _.ACTIVATOR_RAIL.index;

	public enum dropper = _.DROPPER.index;

	public enum whiteStainedClay = _.WHITE_STAINED_CLAY.index;
	public alias WhiteStainedClay = PlaceableItem!(_.WHITE_STAINED_CLAY, Blocks.whiteStainedClay);
	
	public enum orangeStainedClay = _.ORANGE_STAINED_CLAY.index;
	public alias OrangeStainedClay = PlaceableItem!(_.ORANGE_STAINED_CLAY, Blocks.orangeStainedClay);
	
	public enum magentaStainedClay = _.MAGENTA_STAINED_CLAY.index;
	public alias MagentaStainedClay = PlaceableItem!(_.MAGENTA_STAINED_CLAY, Blocks.magentaStainedClay);
	
	public enum lightBlueStainedClay = _.LIGHT_BLUE_STAINED_CLAY.index;
	public alias LightBlueStainedClay = PlaceableItem!(_.LIGHT_BLUE_STAINED_CLAY, Blocks.lightBlueStainedClay);
	
	public enum yellowStainedClay = _.YELLOW_STAINED_CLAY.index;
	public alias YellowStainedClay = PlaceableItem!(_.YELLOW_STAINED_CLAY, Blocks.yellowStainedClay);
	
	public enum limeStainedClay = _.LIME_STAINED_CLAY.index;
	public alias LimeStainedClay = PlaceableItem!(_.LIME_STAINED_CLAY, Blocks.limeStainedClay);
	
	public enum pinkStainedClay = _.PINK_STAINED_CLAY.index;
	public alias PinkStainedClay = PlaceableItem!(_.PINK_STAINED_CLAY, Blocks.pinkStainedClay);
	
	public enum grayStainedClay = _.GRAY_STAINED_CLAY.index;
	public alias GrayStainedClay = PlaceableItem!(_.GRAY_STAINED_CLAY, Blocks.grayStainedClay);
	
	public enum lightGrayStainedClay = _.LIGHT_GRAY_STAINED_CLAY.index;
	public alias LightGrayStainedClay = PlaceableItem!(_.LIGHT_GRAY_STAINED_CLAY, Blocks.lightGrayStainedClay);
	
	public enum cyanStainedClay = _.CYAN_STAINED_CLAY.index;
	public alias CyanStainedClay = PlaceableItem!(_.CYAN_STAINED_CLAY, Blocks.cyanStainedClay);
	
	public enum purpleStainedClay = _.PURPLE_STAINED_CLAY.index;
	public alias PurpleStainedClay = PlaceableItem!(_.PURPLE_STAINED_CLAY, Blocks.purpleStainedClay);
	
	public enum blueStainedClay = _.BLUE_STAINED_CLAY.index;
	public alias BlueStainedClay = PlaceableItem!(_.BLUE_STAINED_CLAY, Blocks.blueStainedClay);
	
	public enum brownStainedClay = _.BROWN_STAINED_CLAY.index;
	public alias BrownStainedClay = PlaceableItem!(_.BROWN_STAINED_CLAY, Blocks.brownStainedClay);
	
	public enum greenStainedClay = _.GREEN_STAINED_CLAY.index;
	public alias GreenStainedClay = PlaceableItem!(_.GREEN_STAINED_CLAY, Blocks.greenStainedClay);
	
	public enum redStainedClay = _.RED_STAINED_CLAY.index;
	public alias RedStainedClay = PlaceableItem!(_.RED_STAINED_CLAY, Blocks.redStainedClay);
	
	public enum blackStainedClay = _.BLACK_STAINED_CLAY.index;
	public alias BlackStainedClay = PlaceableItem!(_.BLACK_STAINED_CLAY, Blocks.blackStainedClay);
	
	public enum stainedClay = [whiteStainedClay, orangeStainedClay, magentaStainedClay, lightBlueStainedClay, yellowStainedClay, limeStainedClay, pinkStainedClay, grayStainedClay, lightGrayStainedClay, cyanStainedClay, purpleStainedClay, blueStainedClay, brownStainedClay, greenStainedClay, redStainedClay, blackStainedClay];

	public enum whiteStainedGlassPane = _.WHITE_STAINED_GLASS_PANE.index;
	public alias WhiteStainedGlassPane = PlaceableItem!(_.WHITE_STAINED_GLASS_PANE, Blocks.whiteStainedGlassPane);
	
	public enum orangeStainedGlassPane = _.ORANGE_STAINED_GLASS_PANE.index;
	public alias OrangeStainedGlassPane = PlaceableItem!(_.ORANGE_STAINED_GLASS_PANE, Blocks.orangeStainedGlassPane);
	
	public enum magentaStainedGlassPane = _.MAGENTA_STAINED_GLASS_PANE.index;
	public alias MagentaStainedGlassPane = PlaceableItem!(_.MAGENTA_STAINED_GLASS_PANE, Blocks.magentaStainedGlassPane);
	
	public enum lightBlueStainedGlassPane = _.LIGHT_BLUE_STAINED_GLASS_PANE.index;
	public alias LightBlueStainedGlassPane = PlaceableItem!(_.LIGHT_BLUE_STAINED_GLASS_PANE, Blocks.lightBlueStainedGlassPane);
	
	public enum yellowStainedGlassPane = _.YELLOW_STAINED_GLASS_PANE.index;
	public alias YellowStainedGlassPane = PlaceableItem!(_.YELLOW_STAINED_GLASS_PANE, Blocks.yellowStainedGlassPane);
	
	public enum limeStainedGlassPane = _.LIME_STAINED_GLASS_PANE.index;
	public alias LimeStainedGlassPane = PlaceableItem!(_.LIME_STAINED_GLASS_PANE, Blocks.limeStainedGlassPane);
	
	public enum pinkStainedGlassPane = _.PINK_STAINED_GLASS_PANE.index;
	public alias PinkStainedGlassPane = PlaceableItem!(_.PINK_STAINED_GLASS_PANE, Blocks.pinkStainedGlassPane);
	
	public enum grayStainedGlassPane = _.GRAY_STAINED_GLASS_PANE.index;
	public alias GrayStainedGlassPane = PlaceableItem!(_.GRAY_STAINED_GLASS_PANE, Blocks.grayStainedGlassPane);
	
	public enum lightGrayStainedGlassPane = _.LIGHT_GRAY_STAINED_GLASS_PANE.index;
	public alias LightGrayStainedGlassPane = PlaceableItem!(_.LIGHT_GRAY_STAINED_GLASS_PANE, Blocks.lightGrayStainedGlassPane);
	
	public enum cyanStainedGlassPane = _.CYAN_STAINED_GLASS_PANE.index;
	public alias CyanStainedGlassPane = PlaceableItem!(_.CYAN_STAINED_GLASS_PANE, Blocks.cyanStainedGlassPane);
	
	public enum purpleStainedGlassPane = _.PURPLE_STAINED_GLASS_PANE.index;
	public alias PurpleStainedGlassPane = PlaceableItem!(_.PURPLE_STAINED_GLASS_PANE, Blocks.purpleStainedGlassPane);
	
	public enum blueStainedGlassPane = _.BLUE_STAINED_GLASS_PANE.index;
	public alias BlueStainedGlassPane = PlaceableItem!(_.BLUE_STAINED_GLASS_PANE, Blocks.blueStainedGlassPane);
	
	public enum brownStainedGlassPane = _.BROWN_STAINED_GLASS_PANE.index;
	public alias BrownStainedGlassPane = PlaceableItem!(_.BROWN_STAINED_GLASS_PANE, Blocks.brownStainedGlassPane);
	
	public enum greenStainedGlassPane = _.GREEN_STAINED_GLASS_PANE.index;
	public alias GreenStainedGlassPane = PlaceableItem!(_.GREEN_STAINED_GLASS_PANE, Blocks.greenStainedGlassPane);
	
	public enum redStainedGlassPane = _.RED_STAINED_GLASS_PANE.index;
	public alias RedStainedGlassPane = PlaceableItem!(_.RED_STAINED_GLASS_PANE, Blocks.redStainedGlassPane);
	
	public enum blackStainedGlassPane = _.BLACK_STAINED_GLASS_PANE.index;
	public alias BlackStainedGlassPane = PlaceableItem!(_.BLACK_STAINED_GLASS_PANE, Blocks.blackStainedGlassPane);
	
	public enum stainedGlassPane = [whiteStainedGlassPane, orangeStainedGlassPane, magentaStainedGlassPane, lightBlueStainedGlassPane, yellowStainedGlassPane, limeStainedGlassPane, pinkStainedGlassPane, grayStainedGlassPane, lightGrayStainedGlassPane, cyanStainedGlassPane, purpleStainedGlassPane, blueStainedGlassPane, brownStainedGlassPane, greenStainedGlassPane, redStainedGlassPane, blackStainedGlassPane];

	public enum acaciaWoodStairs = _.ACACIA_WOOD_STAIRS.index;

	public enum darkOakWoodStairs = _.DARK_OAK_WOOD_STAIRS.index;

	public enum slimeBlock = _.SLIME_BLOCK.index;
	public alias SlimeBlock = PlaceableItem!(_.SLIME_BLOCK, Blocks.slimeBlock);

	public enum barrier = _.BARRIER.index;
	public enum invisibleBedrock = barrier;
	public alias Barrier = PlaceableItem!(_.BARRIER, Blocks.barrier);
	public alias InvisibleBedrock = Barrier;

	public enum ironTrapdoor = _.IRON_TRAPDOOR.index;

	public enum prismarine = _.PRISMARINE.index;
	public alias Prismarine = PlaceableItem!(_.PRISMARINE, Blocks.prismarine);

	public enum prismarineBricks = _.PRISMARINE_BRICKS.index;
	public alias PrismarineBricks = PlaceableItem!(_.PRISMARINE_BRICKS, Blocks.prismarineBricks);

	public enum darkPrismarine = _.DARK_PRISMARINE.index;
	public alias DarkPrismarine = PlaceableItem!(_.DARK_PRISMARINE, Blocks.darkPrismarine);

	public enum seaLantern = _.SEA_LANTERN.index;
	public alias SeaLantern = PlaceableItem!(_.SEA_LANTERN, Blocks.seaLantern);

	public enum hayBale = _.HAY_BALE.index;
	
	public enum whiteCarpet = _.WHITE_CARPET.index;
	public alias WhiteCarpet = PlaceableItem!(_.WHITE_CARPET, Blocks.whiteCarpet);
	
	public enum orangeCarpet = _.ORANGE_CARPET.index;
	public alias OrangeCarpet = PlaceableItem!(_.ORANGE_CARPET, Blocks.orangeCarpet);
	
	public enum magentaCarpet = _.MAGENTA_CARPET.index;
	public alias MagentaCarpet = PlaceableItem!(_.MAGENTA_CARPET, Blocks.magentaCarpet);
	
	public enum lightBlueCarpet = _.LIGHT_BLUE_CARPET.index;
	public alias LightBlueCarpet = PlaceableItem!(_.LIGHT_BLUE_CARPET, Blocks.lightBlueCarpet);
	
	public enum yellowCarpet = _.YELLOW_CARPET.index;
	public alias YellowCarpet = PlaceableItem!(_.YELLOW_CARPET, Blocks.yellowCarpet);
	
	public enum limeCarpet = _.LIME_CARPET.index;
	public alias LimeCarpet = PlaceableItem!(_.LIME_CARPET, Blocks.limeCarpet);
	
	public enum pinkCarpet = _.PINK_CARPET.index;
	public alias PinkCarpet = PlaceableItem!(_.PINK_CARPET, Blocks.pinkCarpet);
	
	public enum grayCarpet = _.GRAY_CARPET.index;
	public alias GrayCarpet = PlaceableItem!(_.GRAY_CARPET, Blocks.grayCarpet);
	
	public enum lightGrayCarpet = _.LIGHT_GRAY_CARPET.index;
	public alias LightGrayCarpet = PlaceableItem!(_.LIGHT_GRAY_CARPET, Blocks.lightGrayCarpet);
	
	public enum cyanCarpet = _.CYAN_CARPET.index;
	public alias CyanCarpet = PlaceableItem!(_.CYAN_CARPET, Blocks.cyanCarpet);
	
	public enum purpleCarpet = _.PURPLE_CARPET.index;
	public alias PurpleCarpet = PlaceableItem!(_.PURPLE_CARPET, Blocks.purpleCarpet);
	
	public enum blueCarpet = _.BLUE_CARPET.index;
	public alias BlueCarpet = PlaceableItem!(_.BLUE_CARPET, Blocks.blueCarpet);
	
	public enum brownCarpet = _.BROWN_CARPET.index;
	public alias BrownCarpet = PlaceableItem!(_.BROWN_CARPET, Blocks.brownCarpet);
	
	public enum greenCarpet = _.GREEN_CARPET.index;
	public alias GreenCarpet = PlaceableItem!(_.GREEN_CARPET, Blocks.greenCarpet);
	
	public enum redCarpet = _.RED_CARPET.index;
	public alias RedCarpet = PlaceableItem!(_.RED_CARPET, Blocks.redCarpet);
	
	public enum blackCarpet = _.BLACK_CARPET.index;
	public alias BlackCarpet = PlaceableItem!(_.BLACK_CARPET, Blocks.blackCarpet);
	
	public enum carpet = [whiteCarpet, orangeCarpet, magentaCarpet, lightBlueCarpet, yellowCarpet, limeCarpet, pinkCarpet, grayCarpet, lightGrayCarpet, cyanCarpet, purpleCarpet, blueCarpet, brownCarpet, greenCarpet, redCarpet, blackCarpet];

	public enum hardenedClay = _.HARDENED_CLAY.index;
	public alias HardenedClay = PlaceableItem!(_.HARDENED_CLAY, Blocks.hardenedClay);

	public enum coalBlock = _.COAL_BLOCK.index;
	public alias CoalBlock = PlaceableItem!(_.COAL_BLOCK, Blocks.coalBlock);

	public enum packedIce = _.PACKED_ICE.index;
	public alias PackedIce = PlaceableItem!(_.PACKED_ICE, Blocks.packedIce);

	public enum sunflower = _.SUNFLOWER.index;

	public enum liliac = _.LILIAC.index;

	public enum doubleTallgrass = _.DOUBLE_TALLGRASS.index;

	public enum largeFern = _.LARGE_FERN.index;

	public enum roseBush = _.ROSE_BUSH.index;

	public enum peony = _.PEONY.index;

	public enum redSandstone = _.RED_SANDSTONE.index;
	public alias RedSandstone = PlaceableItem!(_.RED_SANDSTONE, Blocks.redSandstone);

	public enum chiseledRedSandstone = _.CHISELED_RED_SANDSTONE.index;
	public alias ChiseledRedSandstone = PlaceableItem!(_.CHISELED_RED_SANDSTONE, Blocks.chiseledRedSandstone);

	public enum smoothRedSandstone = _.SMOOTH_RED_SANDSTONE.index;
	public alias SmoothRedSandstone = PlaceableItem!(_.SMOOTH_RED_SANDSTONE, Blocks.smoothRedSandstone);

	public enum redSandstoneStairs = _.RED_SANDSTONE_STAIRS.index;

	public enum redSandstoneSlab = _.RED_SANDSTONE_SLAB.index;

	public enum spruceFenceGate = _.SPRUCE_FENCE_GATE.index;

	public enum birchFenceGate = _.BIRCH_FENCE_GATE.index;

	public enum jungleFenceGate = _.JUNGLE_FENCE_GATE.index;

	public enum acaciaFenceGate = _.ACACIA_FENCE_GATE.index;

	public enum darkOakFenceGate = _.DARK_OAK_FENCE_GATE.index;

	public enum endRod = _.END_ROD.index;

	public enum chorusPlant = _.CHORUS_PLANT.index;

	public enum chorusFlower = _.CHORUS_FLOWER.index;

	public enum purpurBlock = _.PURPUR_BLOCK.index;
	public alias PurpurBlock = PlaceableItem!(_.PURPUR_BLOCK, Blocks.purpurBlock);

	public enum purpurPillar = _.PURPUR_PILLAR.index;

	public enum purpurStairs = _.PURPUR_STAIRS.index;

	public enum purpurSlab = _.PURPUR_SLAB.index;

	public enum endStoneBricks = _.END_STONE_BRICKS.index;
	public alias EndStoneBricks = PlaceableItem!(_.END_STONE_BRICKS, Blocks.endStoneBricks);

	public enum grassPath = _.GRASS_PATH.index;
	public alias GrassPath = PlaceableItem!(_.GRASS_PATH, Blocks.grassPath);

	public enum repeatingCommandBlock = _.REPEATING_COMMAND_BLOCK.index;

	public enum chainCommandBlock = _.CHAIN_COMMAND_BLOCK.index;

	public enum frostedIce = _.FROSTED_ICE.index;
	public alias FrostedIce = PlaceableItem!(_.FROSTED_ICE, Blocks.frostedIce0);

	public enum magmaBlock = _.MAGMA_BLOCK.index;
	public alias MagmaBlock = PlaceableItem!(_.MAGMA_BLOCK, Blocks.magmaBlock);

	public enum netherWartBlock = _.NETHER_WART_BLOCK.index;
	public alias NetherWartBlock = PlaceableItem!(_.NETHER_WART_BLOCK, Blocks.netherWartBlock);

	public enum redNetherBrick = _.RED_NETHER_BRICK.index;
	public alias RedNetherBrick = PlaceableItem!(_.RED_NETHER_BRICK, Blocks.redNetherBrick);

	public enum boneBlock = _.BONE_BLOCK.index;

	public enum structureVoid = _.STRUCTURE_VOID.index;
	public alias StructureVoid = PlaceableItem!(_.STRUCTURE_VOID, Blocks.structureVoid);

	public enum observer = _.OBSERVER.index;

	public enum whiteShulkerBox = _.WHITE_SHULKER_BOX.index;
	public alias WhiteShulkerBox = PlaceableItem!(_.WHITE_SHULKER_BOX, Blocks.whiteShulkerBox);
	
	public enum orangeShulkerBox = _.ORANGE_SHULKER_BOX.index;
	public alias OrangeShulkerBox = PlaceableItem!(_.ORANGE_SHULKER_BOX, Blocks.orangeShulkerBox);
	
	public enum magentaShulkerBox = _.MAGENTA_SHULKER_BOX.index;
	public alias MagentaShulkerBox = PlaceableItem!(_.MAGENTA_SHULKER_BOX, Blocks.magentaShulkerBox);
	
	public enum lightBlueShulkerBox = _.LIGHT_BLUE_SHULKER_BOX.index;
	public alias LightBlueShulkerBox = PlaceableItem!(_.LIGHT_BLUE_SHULKER_BOX, Blocks.lightBlueShulkerBox);
	
	public enum yellowShulkerBox = _.YELLOW_SHULKER_BOX.index;
	public alias YellowShulkerBox = PlaceableItem!(_.YELLOW_SHULKER_BOX, Blocks.yellowShulkerBox);
	
	public enum limeShulkerBox = _.LIME_SHULKER_BOX.index;
	public alias LimeShulkerBox = PlaceableItem!(_.LIME_SHULKER_BOX, Blocks.limeShulkerBox);
	
	public enum pinkShulkerBox = _.PINK_SHULKER_BOX.index;
	public alias PinkShulkerBox = PlaceableItem!(_.PINK_SHULKER_BOX, Blocks.pinkShulkerBox);
	
	public enum grayShulkerBox = _.GRAY_SHULKER_BOX.index;
	public alias GrayShulkerBox = PlaceableItem!(_.GRAY_SHULKER_BOX, Blocks.grayShulkerBox);
	
	public enum lightGrayShulkerBox = _.LIGHT_GRAY_SHULKER_BOX.index;
	public alias LightGrayShulkerBox = PlaceableItem!(_.LIGHT_GRAY_SHULKER_BOX, Blocks.lightGrayShulkerBox);
	
	public enum cyanShulkerBox = _.CYAN_SHULKER_BOX.index;
	public alias CyanShulkerBox = PlaceableItem!(_.CYAN_SHULKER_BOX, Blocks.cyanShulkerBox);
	
	public enum purpleShulkerBox = _.PURPLE_SHULKER_BOX.index;
	public alias PurpleShulkerBox = PlaceableItem!(_.PURPLE_SHULKER_BOX, Blocks.purpleShulkerBox);
	
	public enum blueShulkerBox = _.BLUE_SHULKER_BOX.index;
	public alias BlueShulkerBox = PlaceableItem!(_.BLUE_SHULKER_BOX, Blocks.blueShulkerBox);
	
	public enum brownShulkerBox = _.BROWN_SHULKER_BOX.index;
	public alias BrownShulkerBox = PlaceableItem!(_.BROWN_SHULKER_BOX, Blocks.brownShulkerBox);
	
	public enum greenShulkerBox = _.GREEN_SHULKER_BOX.index;
	public alias GreenShulkerBox = PlaceableItem!(_.GREEN_SHULKER_BOX, Blocks.greenShulkerBox);
	
	public enum redShulkerBox = _.RED_SHULKER_BOX.index;
	public alias RedShulkerBox = PlaceableItem!(_.RED_SHULKER_BOX, Blocks.redShulkerBox);
	
	public enum blackShulkerBox = _.BLACK_SHULKER_BOX.index;
	public alias BlackShulkerBox = PlaceableItem!(_.BLACK_SHULKER_BOX, Blocks.blackShulkerBox);
	
	public enum shulkerBox = [whiteShulkerBox, orangeShulkerBox, magentaShulkerBox, lightBlueShulkerBox, yellowShulkerBox, limeShulkerBox, pinkShulkerBox, grayShulkerBox, lightGrayShulkerBox, cyanShulkerBox, purpleShulkerBox, blueShulkerBox, brownShulkerBox, greenShulkerBox, redShulkerBox, blackShulkerBox];

	public enum stonecutter = _.STONECUTTER.index;
	public alias Stonecutter = PlaceableItem!(_.STONECUTTER, Blocks.stonecutter);

	public enum glowingObsidian = _.GLOWING_OBSIDIAN.index;
	public alias GlowingObsidian = PlaceableItem!(_.GLOWING_OBSIDIAN, Blocks.glowingObsidian);

	public enum netherReactorCore = _.NETHER_REACTOR_CORE.index;
	public alias NetherReactorCore = PlaceableItem!(_.NETHER_REACTOR_CORE, Blocks.netherReactorCore);

	public enum updateBlock = _.UPDATE_BLOCK.index;
	public alias UpdateBlock = PlaceableItem!(_.UPDATE_BLOCK, Blocks.updateBlock);

	public enum ateupdBlock = _.ATEUPD_BLOCK.index;
	public alias AteupdBlock = PlaceableItem!(_.ATEUPD_BLOCK, Blocks.ateupdBlock);

	public enum structureSave = _.STRUCTURE_SAVE.index;
	public alias StructureSave = PlaceableItem!(_.STRUCTURE_SAVE, Blocks.structureBlockSave);

	public enum structureLoad = _.STRUCTURE_LOAD.index;
	public alias StructureLoad = PlaceableItem!(_.STRUCTURE_LOAD, Blocks.structureBlockLoad);

	public enum structureCorner = _.STRUCTURE_CORNER.index;
	public alias StructureCorner = PlaceableItem!(_.STRUCTURE_CORNER, Blocks.structureBlockCorner);

	public enum structureData = _.STRUCTURE_DATA.index;
	public alias StructureData = PlaceableItem!(_.STRUCTURE_DATA, Blocks.structureBlockData);


	public enum ironShovel = _.IRON_SHOVEL.index;
	public alias IronShovel = ShovelItem!(_.IRON_SHOVEL, Tools.iron, Durability.iron, 4);

	public enum ironPickaxe = _.IRON_PICKAXE.index;
	public alias IronPickaxe = PickaxeItem!(_.IRON_PICKAXE, Tools.iron, Durability.iron, 5);

	public enum ironAxe = _.IRON_AXE.index;
	public alias IronAxe = AxeItem!(_.IRON_AXE, Tools.iron, Durability.iron, 6);

	public enum flintAndSteel = _.FLINT_AND_STEEL.index;

	public enum apple = _.APPLE.index;
	public alias Apple = FoodItem!(_.APPLE, 4, 2.4);

	public enum bow = _.BOW.index;

	public enum arrow = _.ARROW.index;
	public alias Arrow = SimpleItem!(_.ARROW);

	public enum coal = _.COAL.index;
	public alias Coal = SimpleItem!(_.COAL);

	public enum charcoal = _.CHARCOAL.index;
	public alias Charcoal = SimpleItem!(_.CHARCOAL);

	public enum diamond = _.DIAMOND.index;
	public alias Diamond = SimpleItem!(_.DIAMOND);

	public enum ironIngot = _.IRON_INGOT.index;
	public alias IronIngot = SimpleItem!(_.IRON_INGOT);

	public enum goldIngot = _.GOLD_INGOT.index;
	public alias GoldIngot = SimpleItem!(_.GOLD_INGOT);

	public enum ironSword = _.IRON_SWORD.index;
	public alias IronSword = SwordItem!(_.IRON_SWORD, Tools.iron, Durability.iron, 7);

	public enum woodenSword = _.WOODEN_SWORD.index;
	public alias WoodenSword = SwordItem!(_.WOODEN_SWORD, Tools.wood, Durability.wood, 5);

	public enum woodenShovel = _.WOODEN_SHOVEL.index;
	public alias WoodenShovel = ShovelItem!(_.WOODEN_SHOVEL, Tools.wood, Durability.wood, 2);

	public enum woodenPickaxe = _.WOODEN_PICKAXE.index;
	public alias WoodenPickaxe = PickaxeItem!(_.WOODEN_PICKAXE, Tools.wood, Durability.wood, 3);

	public enum woodenAxe = _.WOODEN_AXE.index;
	public alias WoodenAxe = AxeItem!(_.WOODEN_AXE, Tools.wood, Durability.wood, 4);

	public enum stoneSword = _.STONE_SWORD.index;
	public alias StoneSword = SwordItem!(_.STONE_SWORD, Tools.stone, Durability.stone, 6);

	public enum stoneShovel = _.STONE_SHOVEL.index;
	public alias StoneShovel = ShovelItem!(_.STONE_SHOVEL, Tools.stone, Durability.stone, 3);

	public enum stonePickaxe = _.STONE_PICKAXE.index;
	public alias StonePickaxe = PickaxeItem!(_.STONE_PICKAXE, Tools.stone, Durability.stone, 4);

	public enum stoneAxe = _.STONE_AXE.index;
	public alias StoneAxe = AxeItem!(_.STONE_AXE, Tools.stone, Durability.stone, 5);

	public enum diamondSword = _.DIAMOND_SWORD.index;
	public alias DiamondSword = SwordItem!(_.DIAMOND_SWORD, Tools.diamond, Durability.diamond, 8);

	public enum diamondShovel = _.DIAMOND_SHOVEL.index;
	public alias DiamondShovel = ShovelItem!(_.DIAMOND_SHOVEL, Tools.diamond, Durability.diamond, 5);

	public enum diamondPickaxe = _.DIAMOND_PICKAXE.index;
	public alias DiamondPickaxe = PickaxeItem!(_.DIAMOND_PICKAXE, Tools.diamond, Durability.diamond, 6);

	public enum diamondAxe = _.DIAMOND_AXE.index;
	public alias DiamondAxe = AxeItem!(_.DIAMOND_AXE, Tools.diamond, Durability.diamond, 7);

	public enum stick = _.STICK.index;
	public alias Stick = SimpleItem!(_.STICK);

	public enum bowl = _.BOWL.index;
	public alias Bowl = SimpleItem!(_.BOWL);

	public enum mushroomStew = _.MUSHROOM_STEW.index;
	public alias MushroomStew = SoupItem!(_.MUSHROOM_STEW, 6, 7.2);

	public enum goldenSword = _.GOLDEN_SWORD.index;
	public alias GoldenSword = SwordItem!(_.GOLDEN_SWORD, Tools.gold, Durability.gold, 5);

	public enum goldenShovel = _.GOLDEN_SHOVEL.index;
	public alias GoldenShovel = ShovelItem!(_.GOLDEN_SHOVEL, Tools.gold, Durability.gold, 2);

	public enum goldenPickaxe = _.GOLDEN_PICKAXE.index;
	public alias GoldenPickaxe = PickaxeItem!(_.GOLDEN_PICKAXE, Tools.gold, Durability.gold, 3);

	public enum goldenAxe = _.GOLDEN_AXE.index;
	public alias GoldenAxe = AxeItem!(_.GOLDEN_AXE, Tools.gold, Durability.gold, 4);

	public enum stringItem = _.STRING.index;

	public enum feather = _.FEATHER.index;
	public alias Feather = SimpleItem!(_.FEATHER);

	public enum gunpowder = _.GUNPOWDER.index;
	public alias Gunpowder = SimpleItem!(_.GUNPOWDER);

	public enum woodenHoe = _.WOODEN_HOE.index;
	public alias WoodenHoe = HoeItem!(_.WOODEN_HOE, Tools.wood, Durability.wood);

	public enum stoneHoe = _.STONE_HOE.index;
	public alias StoneHoe = HoeItem!(_.STONE_HOE, Tools.stone, Durability.stone);

	public enum ironHoe = _.IRON_HOE.index;
	public alias IronHoe = HoeItem!(_.IRON_HOE, Tools.iron, Durability.iron);

	public enum diamondHoe = _.DIAMOND_HOE.index;
	public alias DiamondHoe = HoeItem!(_.DIAMOND_HOE, Tools.diamond, Durability.diamond);

	public enum goldenHoe = _.GOLDEN_HOE.index;
	public alias GoldenHoe = HoeItem!(_.GOLDEN_HOE, Tools.gold, Durability.gold);

	public enum seeds = _.SEEDS.index;
	public alias Seeds = PlaceableItem!(_.SEEDS, Blocks.seeds0, Blocks.farmland);

	public enum wheat = _.WHEAT.index;
	public alias Wheat = SimpleItem!(_.WHEAT);

	public enum bread = _.BREAD.index;
	public alias Bread = FoodItem!(_.BREAD, 5, 6);

	public enum leatherCap = _.LEATHER_CAP.index;
	public alias LeatherCap = ColorableArmorItem!(_.LEATHER_CAP, 56, Armor.cap, 1);

	public enum leatherTunic = _.LEATHER_TUNIC.index;
	public alias LeatherTunic = ColorableArmorItem!(_.LEATHER_TUNIC, 81, Armor.tunic, 3);

	public enum leatherPants = _.LEATHER_PANTS.index;
	public alias LeatherPants = ColorableArmorItem!(_.LEATHER_PANTS, 76, Armor.pants, 2);

	public enum leatherBoots = _.LEATHER_BOOTS.index;
	public alias LeatherBoots = ColorableArmorItem!(_.LEATHER_BOOTS, 66, Armor.boots, 1);

	public enum chainHelmet = _.CHAIN_HELMET.index;
	public alias ChainHelmet = ArmorItem!(_.CHAIN_HELMET, 166, Armor.helmet, 2);

	public enum chainChestplate = _.CHAIN_CHESTPLATE.index;
	public alias ChainChestplate = ArmorItem!(_.CHAIN_CHESTPLATE, 241, Armor.chestplate, 5);

	public enum chainLeggings = _.CHAIN_LEGGINGS.index;
	public alias ChainLeggings = ArmorItem!(_.CHAIN_LEGGINGS, 226, Armor.leggings, 4);

	public enum chainBoots = _.CHAIN_BOOTS.index;
	public alias ChainBoots = ArmorItem!(_.CHAIN_BOOTS, 196, Armor.boots, 1);

	public enum ironHelmet = _.IRON_HELMET.index;
	public alias IronHelmet = ArmorItem!(_.IRON_HELMET, 166, Armor.helmet, 2);

	public enum ironChestplate = _.IRON_CHESTPLATE.index;
	public alias IronChestplate = ArmorItem!(_.IRON_CHESTPLATE, 241, Armor.chestplate, 6);

	public enum ironLeggings = _.IRON_LEGGINGS.index;
	public alias IronLeggings = ArmorItem!(_.IRON_LEGGINGS, 226, Armor.leggings, 5);

	public enum ironBoots = _.IRON_BOOTS.index;
	public alias IronBoots = ArmorItem!(_.IRON_BOOTS, 196, Armor.boots, 2);

	public enum diamondHelmet = _.DIAMOND_HELMET.index;
	public alias DiamondHelmet = ArmorItem!(_.DIAMOND_HELMET, 364, Armor.helmet, 3);

	public enum diamondChestplate = _.DIAMOND_CHESTPLATE.index;
	public alias DiamondChestplate = ArmorItem!(_.DIAMOND_CHESTPLATE, 529, Armor.chestplate, 8);

	public enum diamondLeggings = _.DIAMOND_LEGGINGS.index;
	public alias DiamondLeggings = ArmorItem!(_.DIAMOND_LEGGINGS, 496, Armor.leggings, 6);

	public enum diamondBoots = _.DIAMOND_BOOTS.index;
	public alias DiamondBoots = ArmorItem!(_.DIAMOND_BOOTS, 430, Armor.boots, 3);

	public enum goldenHelmet = _.GOLDEN_HELMET.index;
	public alias GoldenHelmet = ArmorItem!(_.GOLDEN_HELMET, 78, Armor.helmet, 2);

	public enum goldenChestplate = _.GOLDEN_CHESTPLATE.index;
	public alias GoldenChestplate = ArmorItem!(_.GOLDEN_CHESTPLATE, 113, Armor.chestplate, 5);

	public enum goldenLeggings = _.GOLDEN_LEGGINGS.index;
	public alias GoldenLeggings = ArmorItem!(_.GOLDEN_LEGGINGS, 106, Armor.leggings, 3);

	public enum goldenBoots = _.GOLDEN_BOOTS.index;
	public alias GoldenBoots = ArmorItem!(_.GOLDEN_BOOTS, 92, Armor.boots, 1);

	public enum flint = _.FLINT.index;
	public alias Flint = SimpleItem!(_.FLINT);

	public enum rawPorkchop = _.RAW_PORKCHOP.index;
	public alias RawPorkchop = FoodItem!(_.RAW_PORKCHOP, 3, 1.8);

	public enum cookedPorkchop = _.COOKED_PORKCHOP.index;
	public alias CookedPorkchop = FoodItem!(_.COOKED_PORKCHOP, 8, 12.8);

	public enum painting = _.PAINTING.index;

	public enum goldenApple = _.GOLDEN_APPLE.index;
	public alias GoldenApple = FoodItem!(_.GOLDEN_APPLE, 4, 9.6, [effectInfo(Effects.regeneration, 5, "II"), effectInfo(Effects.absorption, 120, "I")]);

	public enum enchantedGoldenApple = _.ENCHANTED_GOLDEN_APPLE.index;
	public alias EnchantedGoldenApple = FoodItem!(_.ENCHANTED_GOLDEN_APPLE, 4, 9.6, [effectInfo(Effects.regeneration, 20, "II"), effectInfo(Effects.absorption, 120, "IV"), effectInfo(Effects.resistance, 300, "I"), effectInfo(Effects.fireResistance, 300, "I")]);

	public enum sign = _.SIGN.index;

	public enum oakDoor = _.OAK_DOOR.index;

	public enum bucket = _.BUCKET.index;

	public enum waterBucket = _.WATER_BUCKET.index;

	public enum lavaBucket = _.LAVA_BUCKET.index;

	public enum minecart = _.MINECART.index;

	public enum saddle = _.SADDLE.index;

	public enum ironDoor = _.IRON_DOOR.index;

	public enum redstoneDust = _.REDSTONE_DUST.index;

	public enum snowball = _.SNOWBALL.index;

	public enum oakBoat = _.OAK_BOAT.index;

	public enum leather = _.LEATHER.index;
	public alias Leather = SimpleItem!(_.LEATHER);

	public enum milkBucket = _.MILK_BUCKET.index;
	public alias MilkBucket = ClearEffectsItem!(_.MILK_BUCKET, bucket);

	public enum brick = _.BRICK.index;
	public alias Brick = SimpleItem!(_.BRICK);

	public enum clay = _.CLAY.index;
	public alias Clay = SimpleItem!(_.CLAY);

	public enum sugarCanes = _.SUGAR_CANES.index;

	public enum paper = _.PAPER.index;
	public alias Paper = SimpleItem!(_.PAPER);

	public enum book = _.BOOK.index;
	public alias Book = SimpleItem!(_.BOOK);

	public enum slimeball = _.SLIMEBALL.index;
	public alias Slimeball = SimpleItem!(_.SLIMEBALL);

	public enum minecartWithChest = _.MINECART_WITH_CHEST.index;

	public enum minecartWithFurnace = _.MINECART_WITH_FURNACE.index;

	public enum egg = _.EGG.index;

	public enum compass = _.COMPASS.index;
	public alias Compass = SimpleItem!(_.COMPASS);

	public enum fishingRod = _.FISHING_ROD.index;

	public enum clock = _.CLOCK.index;
	public alias Clock = SimpleItem!(_.CLOCK);

	public enum glowstoneDust = _.GLOWSTONE_DUST.index;
	public alias GlowstoneDust = SimpleItem!(_.GLOWSTONE_DUST);

	public enum rawFish = _.RAW_FISH.index;
	public alias RawFish = FoodItem!(_.RAW_FISH, 2, .4);

	public enum rawSalmon = _.RAW_SALMON.index;
	public alias RawSalmon = FoodItem!(_.RAW_SALMON, 2, .4);

	public enum clownfish = _.CLOWNFISH.index;
	public alias Clowfish = FoodItem!(_.CLOWNFISH, 1, .2);

	public enum pufferfish = _.PUFFERFISH.index;
	public alias Pufferfish = FoodItem!(_.PUFFERFISH, 1, .2, [effectInfo(Effects.hunger, 15, "III"), effectInfo(Effects.poison, 60, "IV"), effectInfo(Effects.nausea, 15, "II")]);
	
	public enum cookedFish = _.COOKED_FISH.index;
	public alias CookedFish = FoodItem!(_.COOKED_FISH, 5, 6);

	public enum cookedSalmon = _.COOKED_SALMON.index;
	public alias CookedSalmon = FoodItem!(_.COOKED_SALMON, 6, 9.6);

	public enum inkSac = _.INK_SAC.index;
	public alias InkSac = SimpleItem!(_.INK_SAC);

	public enum roseRed = _.ROSE_RED.index;
	public alias RoseRed = SimpleItem!(_.ROSE_RED);

	public enum cactusGreen = _.CACTUS_GREEN.index;
	public alias CactusGreen = SimpleItem!(_.CACTUS_GREEN);

	public enum cocoaBeans = _.COCOA_BEANS.index;
	public alias CocoaBeans = BeansItem!(_.COCOA_BEANS, Blocks.cocoa0);

	public enum lapisLazuli = _.LAPIS_LAZULI.index;
	public alias LapisLazuli = SimpleItem!(_.LAPIS_LAZULI);

	public enum purpleDye = _.PURPLE_DYE.index;
	public alias PurpleDye = SimpleItem!(_.PURPLE_DYE);

	public enum cyanDye = _.CYAN_DYE.index;
	public alias CyanDye = SimpleItem!(_.CYAN_DYE);

	public enum lightGrayDye = _.LIGHT_GRAY_DYE.index;
	public alias LightGrayDye = SimpleItem!(_.LIGHT_GRAY_DYE);

	public enum grayDye = _.GRAY_DYE.index;
	public alias GrayDye = SimpleItem!(_.GRAY_DYE);

	public enum pinkDye = _.PINK_DYE.index;
	public alias PinkDye = SimpleItem!(_.PINK_DYE);

	public enum limeDye = _.LIME_DYE.index;
	public alias LimeDye = SimpleItem!(_.LIME_DYE);

	public enum dandelionYellow = _.DANDELION_YELLOW.index;
	public alias DandelionYellow = SimpleItem!(_.DANDELION_YELLOW);

	public enum lightBlueDye = _.LIGHT_BLUE_DYE.index;
	public alias LightBlueDye = SimpleItem!(_.LIGHT_BLUE_DYE);

	public enum magentaDye = _.MAGENTA_DYE.index;
	public alias MagentaDye = SimpleItem!(_.MAGENTA_DYE);

	public enum orangeDye = _.ORANGE_DYE.index;
	public alias OrangeDye = SimpleItem!(_.ORANGE_DYE);

	public enum boneMeal = _.BONE_MEAL.index;

	public enum bone = _.BONE.index;
	public alias Bone = SimpleItem!(_.BONE);

	public enum sugar = _.SUGAR.index;
	public alias Sugar = SimpleItem!(_.SUGAR);

	public enum cake = _.CAKE.index;
	public alias Cake = PlaceableItem!(_.CAKE, Blocks.cake0);

	public enum bed = _.BED.index;

	public enum redstoneRepeater = _.REDSTONE_REPEATER.index;

	public enum cookie = _.COOKIE.index;
	public alias Cookie = FoodItem!(_.COOKIE, 2, .4);

	public enum map = _.MAP.index;
	public alias Map = MapItem!(_.MAP);

	public enum shears = _.SHEARS.index;

	public enum melon = _.MELON.index;
	public alias Melon = FoodItem!(_.MELON, 2, 1.2);

	public enum pumpkinSeeds = _.PUMPKIN_SEEDS.index;
	public alias PumpkinSeeds = PlaceableItem!(_.PUMPKIN_SEEDS, Blocks.pumpkinStem0, Blocks.farmland);

	public enum melonSeeds = _.MELON_SEEDS.index;
	public alias MelonSeeds = PlaceableItem!(_.MELON_SEEDS, Blocks.melonStem0, Blocks.farmland);

	public enum rawBeef = _.RAW_BEEF.index;
	public alias RawBeef = FoodItem!(_.RAW_BEEF, 3, 1.8);

	public enum steak = _.STEAK.index;
	public alias Steak = FoodItem!(_.STEAK, 8, 12.8);

	public enum rawChicken = _.RAW_CHICKEN.index;
	public alias RawChicken = FoodItem!(_.RAW_CHICKEN, 2, 1.2);

	public enum cookedChicken = _.COOKED_CHICKEN.index;
	public alias CookedChicked = FoodItem!(_.COOKED_CHICKEN, 6, 7.2);

	public enum rottenFlesh = _.ROTTEN_FLESH.index;
	public alias RottenFlesh = FoodItem!(_.ROTTEN_FLESH, 4, .8, [effectInfo(Effects.hunger, 30, "I", .8)]);

	public enum enderPearl = _.ENDER_PEARL.index;

	public enum blazeRod = _.BLAZE_ROD.index;
	public alias BlazeRod = SimpleItem!(_.BLAZE_ROD);

	public enum ghastTear = _.GHAST_TEAR.index;
	public alias GhastTear = SimpleItem!(_.GHAST_TEAR);

	public enum goldNugget = _.GOLD_NUGGET.index;
	public alias GoldNugget = SimpleItem!(_.GOLD_NUGGET);

	public enum netherWart = _.NETHER_WART.index;
	public alias NetherWart = PlaceableItem!(_.NETHER_WART, Blocks.netherWart0, [Blocks.soulSand]);

	public enum potion = _.POTION.index;

	public enum glassBottle = _.GLASS_BOTTLE.index;

	public enum spiderEye = _.SPIDER_EYE.index;
	public alias SpiderEye = SimpleItem!(_.SPIDER_EYE);

	public enum fermentedSpiderEye = _.FERMENTED_SPIDER_EYE.index;
	public alias FermentedSpiderEye = SimpleItem!(_.FERMENTED_SPIDER_EYE);

	public enum blazePowder = _.BLAZE_POWDER.index;
	public alias BlazePowder = SimpleItem!(_.BLAZE_POWDER);

	public enum magmaCream = _.MAGMA_CREAM.index;
	public alias MagmaCream = SimpleItem!(_.MAGMA_CREAM);

	public enum brewingStand = _.BREWING_STAND.index;
	public alias BrewingStand = PlaceableItem!(_.BREWING_STAND, Blocks.brewingStandEmpty);

	public enum cauldron = _.CAULDRON.index;
	public alias Cauldron = PlaceableItem!(_.CAULDRON, Blocks.cauldronEmpty);

	public enum eyeOfEnder = _.EYE_OF_ENDER.index;

	public enum glisteringMelon = _.GLISTERING_MELON.index;
	public alias GlisteringMelon = SimpleItem!(_.GLISTERING_MELON);

	//TODO spawn eggs

	public enum bottleOEnchanting = _.BOTTLE_O_ENCHANTING.index;

	public enum fireCharge = _.FIRE_CHARGE.index;

	public enum bookAndQuill = _.BOOK_AND_QUILL.index;

	public enum writtenBook = _.WRITTEN_BOOK.index;

	public enum emerald = _.EMERALD.index;
	public alias Emerald = SimpleItem!(_.EMERALD);

	public enum itemFrame = _.ITEM_FRAME.index;

	public enum flowerPot = _.FLOWER_POT.index;
	public alias FlowerPot = PlaceableOnSolidItem!(_.FLOWER_POT, Blocks.flowerPot);

	public enum carrot = _.CARROT.index;
	public alias Carrot = CropFoodItem!(_.CARROT, 3, 4.8, Blocks.carrot0);

	public enum potato = _.POTATO.index;
	public alias Potato = CropFoodItem!(_.POTATO, 1, .6, Blocks.potato0);

	public enum bakedPotato = _.BAKED_POTATO.index;
	public alias BakedPotato = FoodItem!(_.BAKED_POTATO, 5, 7.2);

	public enum poisonousPotato = _.POISONOUS_POTATO.index;
	public alias PoisonousPotato = FoodItem!(_.POISONOUS_POTATO, 2, 1.2, [effectInfo(Effects.poison, 4, "I", .6)]);

	public enum emptyMap = _.EMPTY_MAP.index;

	public enum goldenCarrot = _.GOLDEN_CARROT.index;
	public alias GoldenCarrot = FoodItem!(_.GOLDEN_CARROT, 6, 14.4);

	public enum skeletonSkull = _.SKELETON_SKULL.index;

	public enum witherSkeletonSkull = _.WITHER_SKELETON_SKULL.index;

	public enum zombieHead = _.ZOMBIE_HEAD.index;

	public enum humanHead = _.HUMAN_HEAD.index;

	public enum creeperHead = _.CREEPER_HEAD.index;

	public enum dragonHead = _.DRAGON_HEAD.index;

	public enum carrotOnAStick = _.CARROT_ON_A_STICK.index;

	public enum netherStar = _.NETHER_STAR.index;
	public alias NetherStar = SimpleItem!(_.NETHER_STAR);

	public enum pumpkinPie = _.PUMPKIN_PIE.index;
	public alias PumpkinPie = FoodItem!(_.PUMPKIN_PIE, 8, 4.8);

	public enum fireworkRocket = _.FIREWORK_ROCKET.index;

	public enum fireworkStar = _.FIREWORK_STAR.index;

	public enum enchantedBook = _.ENCHANTED_BOOK.index;

	public enum redstoneComparator = _.REDSTONE_COMPARATOR.index;

	public enum netherBrick = _.NETHER_BRICK.index;
	public alias NetherBrick = SimpleItem!(_.NETHER_BRICK);

	public enum netherQuartz = _.NETHER_QUARTZ.index;
	public alias NetherQuartz = SimpleItem!(_.NETHER_QUARTZ);

	public enum minecartWithTnt = _.MINECART_WITH_TNT.index;

	public enum minecartWithHopper = _.MINECART_WITH_HOPPER.index;

	public enum prismarineShard = _.PRISMARINE_SHARD.index;
	public alias PrismarineShard = SimpleItem!(_.PRISMARINE_SHARD);

	public enum prismarineCrystals = _.PRISMARINE_CRYSTALS.index;
	public alias PrismarineCrystals = SimpleItem!(_.PRISMARINE_CRYSTALS);

	public enum rawRabbit = _.RAW_RABBIT.index;
	public alias RawRabbit = FoodItem!(_.RAW_RABBIT, 3, 1.8);

	public enum cookedRabbit = _.COOKED_RABBIT.index;
	public alias CookedRabbit = FoodItem!(_.COOKED_RABBIT, 5, 6);

	public enum rabbitStew = _.RABBIT_STEW.index;
	public alias RabbitStew = SoupItem!(_.RABBIT_STEW, 10, 12);

	public enum rabbitFoot = _.RABBIT_FOOT.index;
	public alias RabbitFoot = SimpleItem!(_.RABBIT_FOOT);

	public enum rabbitHide = _.RABBIT_HIDE.index;
	public alias RabbitHide = SimpleItem!(_.RABBIT_HIDE);

	public enum armorStand = _.ARMOR_STAND.index;

	public enum leatherHorseArmor = _.LEATHER_HORSE_ARMOR.index;

	public enum ironHorseArmor = _.IRON_HORSE_ARMOR.index;

	public enum goldenHorseArmor = _.GOLDEN_HORSE_ARMOR.index;

	public enum diamondHorseArmor = _.DIAMOND_HORSE_ARMOR.index;

	public enum lead = _.LEAD.index;

	public enum nameTag = _.NAME_TAG.index;

	public enum minecartWithCommandBlock = _.MINECART_WITH_COMMAND_BLOCK.index;

	public enum rawMutton = _.RAW_MUTTON.index;
	public alias RawMutton = FoodItem!(_.RAW_MUTTON, 2, 1.2);

	public enum cookedMutton = _.COOKED_MUTTON.index;
	public alias CookedMutton = FoodItem!(_.COOKED_MUTTON, 6, 9.6);

	public enum banner = _.BANNER.index;

	public enum endCrystal = _.END_CRYSTAL.index;

	public enum spruceDoor = _.SPRUCE_DOOR.index;

	public enum birchDoor = _.BIRCH_DOOR.index;

	public enum jungleDoor = _.JUNGLE_DOOR.index;

	public enum acaciaDoor = _.ACACIA_DOOR.index;

	public enum darkOakDoor = _.DARK_OAK_DOOR.index;

	public enum chorusFruit = _.CHORUS_FRUIT.index;
	public alias ChorusFruit = TeleportationItem!(_.CHORUS_FRUIT, 4, 2.4);

	public enum poppedChorusFruit = _.POPPED_CHORUS_FRUIT.index;
	public alias PoppedChorusFruit = SimpleItem!(_.POPPED_CHORUS_FRUIT);

	public enum beetroot = _.BEETROOT.index;
	public alias Beetroot = FoodItem!(_.BEETROOT, 1, 1.2);

	public enum beetrootSeeds = _.BEETROOT_SEEDS.index;
	public alias BeetrootSeeds = PlaceableItem!(_.BEETROOT_SEEDS, Blocks.beetroot0, Blocks.farmland);

	public enum beetrootSoup = _.BEETROOT_SOUP.index;
	public alias BeetrootSoup = SoupItem!(_.BEETROOT_SOUP, 6, 7.2);

	public enum dragonsBreath = _.DRAGONS_BREATH.index;

	public enum splashPotion = _.SPLASH_POTION.index;

	public enum spectralArrow = _.SPECTRAL_ARROW.index;

	public enum tippedArrow = _.TIPPED_ARROW.index;

	public enum lingeringPotion = _.LINGERING_POTION.index;

	public enum shield = _.SHIELD.index;

	public enum elytra = _.ELYTRA.index;

	public enum spruceBoat = _.SPRUCE_BOAT.index;

	public enum birchBoat = _.BIRCH_BOAT.index;

	public enum jungleBoat = _.JUNGLE_BOAT.index;

	public enum acaciaBoat = _.ACACIA_BOAT.index;

	public enum darkOakBoat = _.DARK_OAK_BOAT.index;

	public enum undyingTotem = _.UNDYING_TOTEM.index;

	public enum shulkerShell = _.SHULKER_SHELL.index;
	public alias ShulkerShell = SimpleItem!(_.SHULKER_SHELL);

	public enum ironNugget = _.IRON_NUGGET.index;
	public alias IronNugget = SimpleItem!(_.IRON_NUGGET);

	//TODO discs

}

/**
 * Base abstract class for an Item.
 */
abstract class Item {

	protected Compound m_pc_tag;
	protected Compound m_pe_tag;

	private string m_name = "";
	private Enchantment[ubyte] enchantments;

	public @safe @nogc this() {}
	
	/**
	 * Constructs an item with some extra data.
	 * Throws: JSONException if the JSON string is malformed
	 * Example:
	 * ---
	 * auto item = new Items.Apple(`{"customName":"SPECIAL APPLE","enchantments":[{"name":"protection","level":"IV"}]}`);
	 * assert(item.customName == "SPECIAL_APPLE");
	 * assert(Enchantments.protection in item);
	 * ---
	 */
	public @trusted this(string data) {
		this(std.json.parseJSON(data));
	}

	/**
	 * Constructs an item adding properties from a JSON.
	 * Throws: RangeError if the enchanting name doesn't exist
	 */
	public @safe this(std.json.JSONValue data) {
		this.parseJSON(data);
	}

	public @trusted void parseJSON(std.json.JSONValue data) {
		if(data.type == std.json.JSON_TYPE.OBJECT) {

			auto name = "customName" in data;
			if(name && name.type == std.json.JSON_TYPE.STRING) this.customName = name.str;

			void parseEnchantment(std.json.JSONValue ench) @trusted {
				if(ench.type == std.json.JSON_TYPE.ARRAY) {
					foreach(e ; ench.array) {
						if(e.type == std.json.JSON_TYPE.OBJECT) {
							ubyte l = 1;
							auto level = "level" in e;
							auto lvl = "lvl" in e;
							if(level && level.type == std.json.JSON_TYPE.INTEGER) {
								l = cast(ubyte)level.integer;
							} else if(lvl && lvl.type == std.json.JSON_TYPE.INTEGER) {
								l = cast(ubyte)lvl.integer;
							}
							auto name = "name" in e;
							auto minecraft = "minecraft" in e;
							auto pocket = "pocket" in e;
							try {
								if(name && name.type == std.json.JSON_TYPE.STRING) {
									this.addEnchantment(Enchantment.fromString(name.str, l));
								} else if(minecraft && minecraft.type == std.json.JSON_TYPE.INTEGER) {
									this.addEnchantment(Enchantment.fromMinecraft(cast(ubyte)minecraft.integer, l));
								} else if(pocket && pocket.type == std.json.JSON_TYPE.INTEGER) {
									this.addEnchantment(Enchantment.fromPocket(cast(ubyte)pocket.integer, l));
								}
							} catch(EnchantmentException) {}
						}
					}
				}
			}
			if("ench" in data) parseEnchantment(data["ench"]);
			else if("enchantments" in data) parseEnchantment(data["enchantments"]);

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

	protected abstract pure nothrow @property @safe @nogc size_t index();

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
	public pure nothrow @property @safe @nogc bool tool() {
		return false;
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
	public pure nothrow @property @safe @nogc ubyte toolType() {
		return Tools.none;
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
	public pure nothrow @property @safe @nogc ubyte toolMaterial() {
		return Tools.none;
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
	public pure nothrow @property @safe @nogc bool finished() {
		return false;
	}

	/**
	 * Attack damage caused by the item, as an hit, usually modified
	 * by the tools, like words and axes.
	 */
	public pure nothrow @property @safe @nogc uint attack() {
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
	public pure nothrow @property @safe @nogc bool consumeable() {
		return false;
	}

	/**
	 * Indicates whether the item can be consumed when the holder's
	 * hunger is full.
	 */
	public pure nothrow @property @safe @nogc bool alwaysConsumeable() {
		return true;
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
	public pure nothrow @property @safe @nogc bool placeable() {
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
		auto placed = this.place(player.world, position, tface);
		if(placed != 0) {
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
	public ushort place(World world, BlockPosition position, uint face) {
		return Blocks.air;
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

	/**
	 * Gets the item's compound tag with the custom data of the item.
	 * It may be null if the item has no custom behaviours.
	 * Example:
	 * ---
	 * if(item.minecraftCompound is null) {
	 *    assert(item.customName == "");
	 * }
	 * item.customName = "not empty";
	 * assert(item.pocketCompound !is null);
	 * ---
	 */
	public final pure nothrow @property @safe @nogc Compound minecraftCompound() {
		return this.m_pc_tag;
	}

	/// ditto
	public final pure nothrow @property @safe @nogc Compound pocketCompound() {
		return this.m_pe_tag;
	}

	/**
	 * Parses a compound, usually received from the client or
	 * saved in a world.
	 * The tag should never be null as the method doesn't check it.
	 * Example:
	 * ---
	 * item.parseMinecraftCompound(new Compound(new Compound("display", new String("Name", "custom"))));
	 * assert(item.customName == "custom");
	 * ---
	 */
	public @safe void parseMinecraftCompound(Compound compound) {
		this.clear();
		this.parseCompound(compound, &Enchantment.fromMinecraft);
	}

	/// ditto
	public @safe void parsePocketCompound(Compound compound) {
		this.clear();
		this.parseCompound(compound, &Enchantment.fromPocket);
	}

	private @safe void parseCompound(Compound compound, Enchantment function(ubyte id, ubyte level) @safe get) {
		if(compound.has!Compound("")) compound = compound.get!Compound("");
		if(compound.has!Compound("display")) {
			auto display = compound.get!Compound("display");
			if(display.has!String("Name")) {
				auto name = display.get!String("Name").value;
				if(name.length) this.customName = name;
			}
		}
		if(compound.has!(ListOf!Compound)("ench")) {
			foreach(e ; compound.get!(ListOf!Compound)("ench")) {
				if(e.has!Short("id") && e.has!Short("lvl")) {
					auto ench = get(cast(ubyte)e.get!Short("id").value, cast(ubyte)e.get!Short("lvl").value);
					if(ench !is null) this.addEnchantment(ench);
				}
			}
		}
	}

	/**
	 * Removes the custom behaviours of the item, like custom name
	 * and enchantments.
	 * Example:
	 * ---
	 * item.customName = "name";
	 * assert(item.customName == "name");
	 * item.clear();
	 * assert(item.customName == "");
	 * ---
	 */
	public @trusted void clear() {
		this.m_pc_tag = null;
		this.m_pe_tag = null;
		this.m_name = "";
		this.enchantments.clear();
	}

	/**
	 * Gets the item's custom name.
	 */
	public pure nothrow @property @safe @nogc string customName() {
		return this.m_name;
	}

	/**
	 * Sets the item's custom name.
	 * Example:
	 * ---
	 * item.customName = "§aColoured!";
	 * item.customName = ""; // remove
	 * ---
	 */
	public @property @safe string customName(string name) {
		if(name.length) {
			void set(ref Compound compound) {
				auto n = new String("Name", name);
				if(compound is null) compound = new Compound(new Compound("display", n));
				else if(!compound.has!Compound("display")) compound["display"] = new Compound(n);
				else compound.get!Compound("display")[] = n;
			}
			set(this.m_pc_tag);
			set(this.m_pe_tag);
		} else {
			void reset(ref Compound compound) {
				auto display = compound.get!Compound("display");
				display.remove("Name");
				if(display.empty) {
					compound.remove("display");
					if(compound.empty) compound = null;
				}
			}
			reset(this.m_pc_tag);
			reset(this.m_pe_tag);
		}
		return this.m_name = name;
	}

	/**
	 * Adds an enchantment to the item.
	 * Throws: EnchantmentException if the enchantment doesn't exist
	 * Example:
	 * ---
	 * item.addEnchantment(new Enchantment(Enchantments.sharpness, 1));
	 * item.addEnchantment(Enchantments.power, 5);
	 * item.addEnchantment(Enchantments.fortune, "X");
	 * item += new Enchantment(Enchantments.smite, 2);
	 * ---
	 */
	public @safe void addEnchantment(Enchantment ench) {
		if(ench is null) throw new EnchantmentException("Invalid enchantment given");
		auto e = ench.id in this.enchantments;
		if(e) {
			// modify
			*e = ench;
			void modify(ref Compound compound, ubyte id) @safe {
				foreach(ref tag ; compound.get!(ListOf!Compound)("ench")) {
					if(tag.get!Short("id").value == id) {
						tag.get!Short("lvl").value = ench.level;
						break;
					}
				}
			}
			if(ench.minecraft) modify(this.m_pc_tag, ench.minecraft.id);
			if(ench.pocket) modify(this.m_pe_tag, ench.pocket.id);
		} else {
			// add
			this.enchantments[ench.id] = ench;
			void add(ref Compound compound, ubyte id) @safe {
				auto ec = new Compound([new Short("id", id), new Short("lvl", ench.level)]);
				if(compound is null) compound = new Compound([new ListOf!Compound("ench", [ec])]);
				else if(!compound.has!(ListOf!Compound)("ench")) compound["ench"] = new ListOf!Compound(ec);
				else compound.get!(ListOf!Compound)("ench") ~= ec;
			}
			if(ench.minecraft) add(this.m_pc_tag, ench.minecraft.id);
			if(ench.pocket) add(this.m_pe_tag, ench.pocket.id);
		}
	}

	/// ditto
	public @safe void addEnchantment(sul.enchantments.Enchantment ench, ubyte level) {
		this.addEnchantment(new Enchantment(ench, level));
	}

	/// ditto
	public @safe void addEnchantment(sul.enchantments.Enchantment ench, string level) {
		this.addEnchantment(new Enchantment(ench, level));
	}

	/// ditto
	public @safe void opBinaryRight(string op : "+")(Enchantment ench) {
		this.addEnchantment(ench);
	}

	/// ditto
	alias enchant = this.addEnchantment;

	/**
	 * Gets a pointer to the enchantment.
	 * This method can be used to check if the item has an
	 * enchantment and its level.
	 * Example:
	 * ---
	 * auto e = Enchantments.protection in item;
	 * if(!e || e.level != 5) {
	 *    item.enchant(Enchantment.protection, 5);
	 * }
	 * assert(Enchantments.protection in item);
	 * ---
	 */
	public @safe Enchantment* opBinaryRight(string op : "in")(sul.enchantments.Enchantment ench) {
		return ench.minecraft.id in this.enchantments;
	}

	/**
	 * Removes an enchantment from the item.
	 * Example:
	 * ---
	 * item.removeEnchantment(Enchantments.sharpness);
	 * item -= Enchantments.fortune;
	 * ---
	 */
	public @safe void removeEnchantment(sul.enchantments.Enchantment ench) {
		if(ench.minecraft.id in this.enchantments) {
			this.enchantments.remove(ench.minecraft.id);
			void remove(ref Compound compound, ubyte id) @safe {
				auto list = compound.get!(ListOf!Compound)("ench");
				if(list.length == 1) {
					compound.remove("ench");
					if(compound.empty) compound = null;
				} else {
					foreach(i, e; list) {
						if(e.get!Short("id").value == id) {
							list.remove(i);
							break;
						}
					}
				}
			}
			if(ench.minecraft) remove(this.m_pc_tag, ench.minecraft.id);
			if(ench.pocket) remove(this.m_pe_tag, ench.pocket.id);
		}
	}

	/// ditto
	public @safe void opBinaryRight(string op : "-")(sul.enchantments.Enchantment ench) {
		this.removeEnchantment(ench);
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
	 * a.enchant(Enchantments.protection, "IV");
	 * b.enchant(Enchantments.protection, "IV");
	 * assert(a == b);
	 * ---
	 */
	public override bool opEquals(Object o) {
		if(cast(Item)o) {
			Item i = cast(Item)o;
			//TODO compare enchantments and custom name directly instead of nbts
			return this.ids == i.ids && this.metas == i.metas && this.customName == i.customName && this.enchantments == i.enchantments;
		}
		return false;
	}

	/**
	 * Compare an item with its type as a string or a group of strings.
	 * Example:
	 * ---
	 * Item item = new Items.Beetroot();
	 * assert(item == Items.beetroot);
	 * assert(item == [Items.beetrootSoup, Items.beetroot]);
	 * ---
	 */
	public @safe @nogc bool opEquals(item_t item) {
		return item == this.index;
	}

	/// ditto
	public @safe @nogc bool opEquals(item_t[] items) {
		foreach(item ; items) {
			if(this.opEquals(item)) return true;
		}
		return false;
	}

	/**
	 * Returns the item as string in format "name" or
	 * "name:damage" for tools.
	 */
	public override string toString() {
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

//TODO the translatable should affect the compound tag
/*template Translatable(T:Item) {
	alias Translatable = GenericTranslatable!("this.customName", T);
}*/

class SimpleItem(sul.items.Item si) : Item {

	alias sul = si;

	private enum __ids = shortgroup(si.pocket ? si.pocket.id : 0, si.minecraft ? si.minecraft.id : 0);

	private enum __metas = shortgroup(si.pocket ? si.pocket.meta : 0, si.minecraft ? si.minecraft.meta : 0);

	public @safe this(E...)(E args) {
		super(args);
	}

	public final override pure nothrow @property @safe @nogc item_t index() {
		return si.index;
	}

	public final override pure nothrow @property @safe @nogc shortgroup ids() {
		return __ids;
	}

	public override pure nothrow @property @safe @nogc shortgroup metas() {
		return __metas;
	}

	public final override pure nothrow @property @safe @nogc string name() {
		return si.name;
	}

	public override pure nothrow @property @safe @nogc ubyte max() {
		return si.stack;
	}
	
	alias slot this;

}
