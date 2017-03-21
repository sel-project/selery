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
import std.conv : to, ConvException;
import std.math : ceil;
import std.string : split, join, capitalize;
import std.typecons : Tuple;
import std.typetuple;

import common.sel;

import sel.player : Player;
import sel.block.farming;
import sel.block.fluid;
import sel.block.miscellaneous;
import sel.block.redstone;
import sel.block.solid;
import sel.block.tile;
import sel.entity.projectile : FallingBlock;
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
import sul.blocks : _ = Blocks;

private enum unimplemeted;

/** 
 * Identifiers as BlockData and BlockDataArray of every block in 
 * the vanilla game.
 * Example:
 * ---
 * // set a block using a string as identifier. The identifier
 * // can point to different block classes in different worlds
 * world[0, 0, 0] = Blocks.dirt;
 * 
 * // blocks of the same type can be compared with their whole group
 * auto birch = Blocks.BirchWoodPlanks.instance;
 * auto spruce = Blocks.SpruceWoodPlanks.instance;
 * assert(birch == Blocks.woodPlanks);
 * assert(spruce == Blocks.woodPlanks);
 * assert(birch == Blocks.birchWoodPlanks);
 * assert(spruce != Blocks.birchWoodPlanks);
 * ---
 */
public class Blocks {

	private Block*[] sel;
	private Block*[][256] minecraft, pocket;

	public this() {
		foreach(a ; __traits(allMembers, Blocks)) {
			static if(mixin("is(" ~ a ~ " : Block)")) {
				mixin("this.register(" ~ a ~ ".instance);");
			}
		}
	}

	public void register(Block* block) {
		if(block !is null && *block !is null) {
			if(this.sel.length <= block.id) this.sel.length = block.id + 1;
			this.sel[block.id] = block;
			if(block.minecraft) {
				if(this.minecraft[block.ids.pc].length <= block.metas.pc) this.minecraft[block.ids.pc].length = block.metas.pc + 1;
				this.minecraft[block.ids.pc][block.metas.pc] = block;
			}
			if(block.pocket) {
				if(this.minecraft[block.ids.pe].length <= block.metas.pe) this.minecraft[block.ids.pe].length = block.metas.pe + 1;
				this.minecraft[block.ids.pe][block.metas.pe] = block;
			}
		}
	}

	public @safe Block* opIndex(block_t id) {
		return id in this;
	}

	public @safe Block* opBinaryRight(string op : "in")(block_t id) {
		return id < this.sel.length ? this.sel[id] : null;
	}

	public @safe Block* fromMinecraft(ubyte id, ubyte meta=0) {
		auto data = this.minecraft[id];
		if(data.length > meta) return data[meta];
		else return null;
	}

	public @safe Block* fromPocket(ubyte id, ubyte meta=0) {
		auto data = this.pocket[id];
		if(data.length > meta) return data[meta];
		else return null;
	}

	public alias Air = SimpleBlock!(_.AIR);
	public enum air = _.AIR.id;

	public alias Stone = StoneBlock!(_.STONE, Items.cobblestone, Items.stone);
	public enum stone = _.STONE.id;

	public alias Granite = StoneBlock!(_.GRANITE, Items.granite);
	public enum granite = _.GRANITE.id;

	public alias PolishedGranite = StoneBlock!(_.POLISHED_GRANITE, Items.polishedGranite);
	public enum polishedGranite = _.POLISHED_GRANITE.id;

	public alias Diorite = StoneBlock!(_.DIORITE, Items.diorite);
	public enum diorite = _.DIORITE.id;

	public alias PolishedDiorite = StoneBlock!(_.POLISHED_DIORITE, Items.polishedDiorite);
	public enum polishedDiorite = _.POLISHED_DIORITE.id;

	public alias Andesite = StoneBlock!(_.ANDESITE, Items.andesite);
	public enum andesite = _.ANDESITE.id;

	public alias PolishedAndesite = StoneBlock!(_.POLISHED_ANDESITE, Items.polishedAndesite);
	public enum polishedAndesite = _.POLISHED_ANDESITE.id;

	public alias StoneBricks = StoneBlock!(_.STONE_BRICKS, Items.stoneBricks);
	public enum stoneBricks = _.STONE_BRICKS.id;

	public alias MossyStoneBricks = StoneBlock!(_.MOSSY_STONE_BRICKS, Items.mossyStoneBricks);
	public enum mossyStoneBricks = _.MOSSY_STONE_BRICKS.id;

	public alias CrackedStoneBricks = StoneBlock!(_.CRACKED_STONE_BRICKS, Items.crackedStoneBricks);
	public enum crackedStoneBricks = _.CRACKED_STONE_BRICKS.id;

	public alias ChiseledStoneBricks = StoneBlock!(_.CHISELED_STONE_BRICKS, Items.chiseledStoneBricks);
	public enum chiseledStoneBricks = _.CHISELED_STONE_BRICKS.id;

	public alias Cobblestone = StoneBlock!(_.COBBLESTONE, Items.cobblestone);
	public enum cobblestone = _.COBBLESTONE.id;

	public alias MossStone = StoneBlock!(_.MOSS_STONE, Items.mossStone);
	public enum mossStone = _.MOSS_STONE.id;

	public alias CobblestoneWall = StoneBlock!(_.COBBLESTONE_WALL, Items.cobblestoneWall);
	public enum cobblestoneWall = _.COBBLESTONE_WALL.id;

	public alias MossyCobblestoneWall = StoneBlock!(_.MOSSY_COBBLESTONE_WALL, Items.mossyCobblestoneWall);
	public enum mossyCobblestoneWall = _.MOSSY_COBBLESTONE_WALL.id;

	public alias Bricks = StoneBlock!(_.BRICKS, Items.bricks);
	public enum bricks = _.BRICKS.id;

	public alias CoalOre = MineableBlock!(_.COAL_ORE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.coal, 1, 1, Items.coalOre), Experience(0, 2)); //TODO +1 with fortune
	public enum coalOre = _.COAL_ORE.id;

	public alias IronOre = MineableBlock!(_.IRON_ORE, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.ironOre, 1));
	public enum ironOre = _.IRON_ORE.id;

	public alias GoldOre = MineableBlock!(_.GOLD_ORE, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.goldOre, 1));
	public enum goldOre = _.GOLD_ORE.id;

	public alias DiamondOre = MineableBlock!(_.DIAMOND_ORE, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.diamond, 1, 1, Items.diamondOre)); //TODO +1 with fortune
	public enum diamondOre = _.DIAMOND_ORE.id;

	public alias EmeraldOre = MineableBlock!(_.EMERALD_ORE, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.emerald, 1, 1, Items.emeraldOre)); //TODO +1 with fortune
	public enum emeraldOre = _.EMERALD_ORE.id;

	public alias LapisLazuliOre = MineableBlock!(_.LAPIS_LAZULI_ORE, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.lapisLazuli, 4, 8, Items.lapisLazuliOre), Experience(2, 5)); //TODO fortune
	public enum lapisLazuliOre = _.LAPIS_LAZULI_ORE.id;

	public alias RedstoneOre = RedstoneOreBlock!(_.REDSTONE_ORE, false, litRedstoneOre);
	public enum redstoneOre = _.REDSTONE_ORE.id;

	public alias LitRedstoneOre = RedstoneOreBlock!(_.LIT_REDSTONE_ORE, true, redstoneOre);
	public enum litRedstoneOre = _.LIT_REDSTONE_ORE.id;

	public alias NetherQuartzOre = MineableBlock!(_.NETHER_QUARTZ_ORE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherQuartz, 2, 5, Items.netherQuartzOre), Experience(2, 5, 1)); //TODO fortune
	public enum netherQuartzOre = _.NETHER_QUARTZ_ORE.id;

	public enum ore = [coalOre, ironOre, goldOre, diamondOre, emeraldOre, lapisLazuliOre, redstoneOre, litRedstoneOre, netherQuartzOre];

	public alias CoalBlock = MineableBlock!(_.COAL_BLOCK, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.coalBlock, 1));
	public enum coalBlock = _.COAL_BLOCK.id;

	public alias IronBlock = MineableBlock!(_.IRON_BLOCK, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.ironBlock, 1));
	public enum ironBlock = _.IRON_BLOCK.id;

	public alias GoldBlock = MineableBlock!(_.GOLD_BLOCK, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.goldBlock, 1));
	public enum goldBlock = _.GOLD_BLOCK.id;

	public alias DiamondBlock = MineableBlock!(_.DIAMOND_BLOCK, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.diamondBlock, 1));
	public enum diamondBlock = _.DIAMOND_BLOCK.id;

	public alias EmeraldBlock = MineableBlock!(_.EMERALD_BLOCK, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.emeraldBlock, 1));
	public enum emeraldBlock = _.EMERALD_BLOCK.id;

	public alias RedstoneBlock = MineableBlock!(_.REDSTONE_BLOCK, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redstoneBlock, 1));
	public enum redstoneBlock = _.REDSTONE_BLOCK.id;

	public alias LapisLazuliBlock = MineableBlock!(_.LAPIS_LAZULI_ORE, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.lapisLazuliBlock, 1));
	public enum lapisLazuliBlock = _.LAPIS_LAZULI_BLOCK.id;

	public alias NetherReactorCore = MineableBlock!(_.NETHER_REACTOR_CORE, MiningTool(true, Tools.pickaxe, Tools.wood), [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]);
	public enum netherReactorCore = _.NETHER_REACTOR_CORE.id;

	public alias ActiveNetherReactorCore = MineableBlock!(_.ACTIVE_NETHER_REACTOR_CORE, MiningTool(true, Tools.pickaxe, Tools.wood), [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]);
	public enum activeNetherReactorCore = _.ACTIVE_NETHER_REACTOR_CORE.id;

	public alias UsedNetherReactorCore = MineableBlock!(_.USED_NETHER_REACTOR_CORE, MiningTool(true, Tools.pickaxe, Tools.wood), [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]);
	public enum usedNetherReactorCore = _.USED_NETHER_REACTOR_CORE.id;

	public alias Grass = SimpleSpreadingBlock!(_.GRASS, MiningTool(false, Tools.shovel, Tools.wood), [Drop(Items.dirt, 1, 1, Items.grass)], [dirt], 1, 1, 2, dirt);
	public enum grass = _.GRASS.id;

	public alias Dirt = MineableBlock!(_.DIRT, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1));
	public enum dirt = _.DIRT.id;

	public alias CoarseDirt = MineableBlock!(_.COARSE_DIRT, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1));
	public enum coarseDirt = _.COARSE_DIRT.id;

	public alias Podzol = MineableBlock!(_.PODZOL, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1, 1, Items.podzol));
	public enum podzol = _.PODZOL.id;

	public alias Mycelium = SpreadingBlock!(_.MYCELIUM, MiningTool(false, Tools.shovel, Tools.wood), [Drop(Items.dirt, 1, 1, Items.mycelium)], [Blocks.dirt, Blocks.grass, Blocks.podzol], 1, 1, 3, 1, Blocks.dirt);
	public enum mycelium = _.MYCELIUM.id;

	public alias GrassPath = MineableBlock!(_.GRASS_PATH, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.grassPath, 1));
	public enum grassPath = _.GRASS_PATH.id;

	public alias Farmland0 = FertileTerrain!(_.FARMLAND_0, false, farmland7, 0);
	public enum farmland0 = _.FARMLAND_0.id;
	
	public alias Farmland1 = FertileTerrain!(_.FARMLAND_1, false, farmland7, farmland0);
	public enum farmland1 = _.FARMLAND_1.id;
	
	public alias Farmland2 = FertileTerrain!(_.FARMLAND_2, false, farmland7, farmland1);
	public enum farmland2 = _.FARMLAND_2.id;
	
	public alias Farmland3 = FertileTerrain!(_.FARMLAND_3, false, farmland7, farmland2);
	public enum farmland3 = _.FARMLAND_3.id;
	
	public alias Farmland4 = FertileTerrain!(_.FARMLAND_4, false, farmland7, farmland4);
	public enum farmland4 = _.FARMLAND_4.id;
	
	public alias Farmland5 = FertileTerrain!(_.FARMLAND_5, false, farmland7, farmland4);
	public enum farmland5 = _.FARMLAND_5.id;
	
	public alias Farmland6 = FertileTerrain!(_.FARMLAND_6, false, farmland7, farmland5);
	public enum farmland6 = _.FARMLAND_6.id;

	public alias Farmland7 = FertileTerrain!(_.FARMLAND_7, true, 0, farmland6);
	public enum farmland7 = _.FARMLAND_7.id;

	public enum farmland = [farmland0, farmland1, farmland2, farmland3, farmland4, farmland5, farmland6, farmland7];
	
	public alias OakWoodPlanks = MineableBlock!(_.OAK_WOOD_PLANKS, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodPlanks, 1));
	public enum oakWoodPlanks = _.OAK_WOOD_PLANKS.id;

	public alias SpruceWoodPlanks = MineableBlock!(_.SPRUCE_WOOD_PLANKS, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodPlanks, 1));
	public enum spruceWoodPlanks = _.SPRUCE_WOOD_PLANKS.id;
	
	public alias BirchWoodPlanks = MineableBlock!(_.BIRCH_WOOD_PLANKS, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodPlanks, 1));
	public enum birchWoodPlanks = _.BIRCH_WOOD_PLANKS.id;
	
	public alias JungleWoodPlanks = MineableBlock!(_.JUNGLE_WOOD_PLANKS, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodPlanks, 1));
	public enum jungleWoodPlanks = _.JUNGLE_WOOD_PLANKS.id;
	
	public alias AcaciaWoodPlanks = MineableBlock!(_.ACACIA_WOOD_PLANKS, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodPlanks, 1));
	public enum acaciaWoodPlanks = _.ACACIA_WOOD_PLANKS.id;

	public alias DarkOakWoodPlanks = MineableBlock!(_.DARK_OAK_WOOD_PLANKS, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodPlanks, 1));
	public enum darkOakWoodPlanks = _.DARK_OAK_WOOD_PLANKS.id;

	public enum woodPlanks = [oakWoodPlanks, spruceWoodPlanks, birchWoodPlanks, jungleWoodPlanks, acaciaWoodPlanks, darkOakWoodPlanks];

	public alias OakSapling = SaplingBlock!(_.OAK_SAPLING, Items.oakSapling, oakWood, oakLeaves);
	public enum oakSapling = _.OAK_SAPLING.id;

	public alias SpruceSapling = SaplingBlock!(_.SPRUCE_SAPLING, Items.spruceSapling, spruceWood, spruceLeaves);
	public enum spruceSapling = _.SPRUCE_SAPLING.id;

	public alias BirchSapling = SaplingBlock!(_.BIRCH_SAPLING, Items.birchSapling, birchWood, birchLeaves);
	public enum birchSapling = _.BIRCH_SAPLING.id;

	public alias JungleSapling = SaplingBlock!(_.JUNGLE_SAPLING, Items.jungleSapling, jungleWood, jungleLeaves);
	public enum jungleSapling = _.JUNGLE_SAPLING.id;

	public alias AcaciaSapling = SaplingBlock!(_.ACACIA_SAPLING, Items.acaciaSapling, acaciaWood, acaciaLeaves);
	public enum acaciaSapling = _.ACACIA_SAPLING.id;

	public alias DarkOakSapling = SaplingBlock!(_.DARK_OAK_SAPLING, Items.darkOakSapling, darkOakWood, darkOakLeaves);
	public enum darkOakSapling = _.DARK_OAK_SAPLING.id;

	public enum sapling = [oakSapling, spruceSapling, birchSapling, jungleSapling, acaciaSapling, darkOakSapling];

	public alias Bedrock = SimpleBlock!(_.BEDROCK);
	public enum bedrock = _.BEDROCK.id;

	public alias Sand = GravityBlock!(_.SAND, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.sand, 1));
	public enum sand = _.SAND.id;

	public alias RedSand = GravityBlock!(_.RED_SAND, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.redSand, 1));
	public enum redSand = _.RED_SAND.id;

	public alias Gravel = GravelBlock!(_.GRAVEL);
	public enum gravel = _.GRAVEL.id;
	
	public alias OakWoodUpDown = WoodBlock!(_.OAK_WOOD_UP_DOWN, Items.oakWood);
	public enum oakWoodUpDown = _.OAK_WOOD_UP_DOWN.id;
	
	public alias OakWoodEastWest = WoodBlock!(_.OAK_WOOD_EAST_WEST, Items.oakWood);
	public enum oakWoodEastWest = _.OAK_WOOD_EAST_WEST.id;
	
	public alias OakWoodNorthSouth = WoodBlock!(_.OAK_WOOD_NORTH_SOUTH, Items.oakWood);
	public enum oakWoodNorthSouth = _.OAK_WOOD_NORTH_SOUTH.id;
	
	public alias OakWoodBark = WoodBlock!(_.OAK_WOOD_BARK, Items.oakWood);
	public enum oakWoodBark = _.OAK_WOOD_BARK.id;
	
	public enum oakWood = [oakWoodUpDown, oakWoodEastWest, oakWoodNorthSouth, oakWoodBark];
	
	public alias SpruceWoodUpDown = WoodBlock!(_.SPRUCE_WOOD_UP_DOWN, Items.spruceWood);
	public enum spruceWoodUpDown = _.SPRUCE_WOOD_UP_DOWN.id;
	
	public alias SpruceWoodEastWest = WoodBlock!(_.SPRUCE_WOOD_EAST_WEST, Items.spruceWood);
	public enum spruceWoodEastWest = _.SPRUCE_WOOD_EAST_WEST.id;
	
	public alias SpruceWoodNorthSouth = WoodBlock!(_.SPRUCE_WOOD_NORTH_SOUTH, Items.spruceWood);
	public enum spruceWoodNorthSouth = _.SPRUCE_WOOD_NORTH_SOUTH.id;
	
	public alias SpruceWoodBark = WoodBlock!(_.SPRUCE_WOOD_BARK, Items.spruceWood);
	public enum spruceWoodBark = _.SPRUCE_WOOD_BARK.id;
	
	public enum spruceWood = [spruceWoodUpDown, spruceWoodEastWest, spruceWoodNorthSouth, spruceWoodBark];
	
	public alias BirchWoodUpDown = WoodBlock!(_.BIRCH_WOOD_UP_DOWN, Items.birchWood);
	public enum birchWoodUpDown = _.BIRCH_WOOD_UP_DOWN.id;
	
	public alias BirchWoodEastWest = WoodBlock!(_.BIRCH_WOOD_EAST_WEST, Items.birchWood);
	public enum birchWoodEastWest = _.BIRCH_WOOD_EAST_WEST.id;
	
	public alias BirchWoodNorthSouth = WoodBlock!(_.BIRCH_WOOD_NORTH_SOUTH, Items.birchWood);
	public enum birchWoodNorthSouth = _.BIRCH_WOOD_NORTH_SOUTH.id;
	
	public alias BirchWoodBark = WoodBlock!(_.BIRCH_WOOD_BARK, Items.birchWood);
	public enum birchWoodBark = _.BIRCH_WOOD_BARK.id;
	
	public enum birchWood = [birchWoodUpDown, birchWoodEastWest, birchWoodNorthSouth, birchWoodBark];
	
	public alias JungleWoodUpDown = WoodBlock!(_.JUNGLE_WOOD_UP_DOWN, Items.jungleWood);
	public enum jungleWoodUpDown = _.JUNGLE_WOOD_UP_DOWN.id;
	
	public alias JungleWoodEastWest = WoodBlock!(_.JUNGLE_WOOD_EAST_WEST, Items.jungleWood);
	public enum jungleWoodEastWest = _.JUNGLE_WOOD_EAST_WEST.id;
	
	public alias JungleWoodNorthSouth = WoodBlock!(_.JUNGLE_WOOD_NORTH_SOUTH, Items.jungleWood);
	public enum jungleWoodNorthSouth = _.JUNGLE_WOOD_NORTH_SOUTH.id;
	
	public alias JungleWoodBark = WoodBlock!(_.JUNGLE_WOOD_BARK, Items.jungleWood);
	public enum jungleWoodBark = _.JUNGLE_WOOD_BARK.id;
	
	public enum jungleWood = [jungleWoodUpDown, jungleWoodEastWest, jungleWoodNorthSouth, jungleWoodBark];
	
	public alias AcaciaWoodUpDown = WoodBlock!(_.ACACIA_WOOD_UP_DOWN, Items.acaciaWood);
	public enum acaciaWoodUpDown = _.ACACIA_WOOD_UP_DOWN.id;

	public alias AcaciaWoodEastWest = WoodBlock!(_.ACACIA_WOOD_EAST_WEST, Items.acaciaWood);
	public enum acaciaWoodEastWest = _.ACACIA_WOOD_EAST_WEST.id;
	
	public alias AcaciaWoodNorthSouth = WoodBlock!(_.ACACIA_WOOD_NORTH_SOUTH, Items.acaciaWood);
	public enum acaciaWoodNorthSouth = _.ACACIA_WOOD_NORTH_SOUTH.id;
	
	public alias AcaciaWoodBark = WoodBlock!(_.ACACIA_WOOD_BARK, Items.acaciaWood);
	public enum acaciaWoodBark = _.ACACIA_WOOD_BARK.id;
	
	public enum acaciaWood = [acaciaWoodUpDown, acaciaWoodEastWest, acaciaWoodNorthSouth, acaciaWoodBark];

	public alias DarkOakWoodUpDown = WoodBlock!(_.DARK_OAK_WOOD_UP_DOWN, Items.darkOakWood);
	public enum darkOakWoodUpDown = _.DARK_OAK_WOOD_UP_DOWN.id;

	public alias DarkOakWoodEastWest = WoodBlock!(_.DARK_OAK_WOOD_EAST_WEST, Items.darkOakWood);
	public enum darkOakWoodEastWest = _.DARK_OAK_WOOD_EAST_WEST.id;

	public alias DarkOakWoodNorthSouth = WoodBlock!(_.DARK_OAK_WOOD_NORTH_SOUTH, Items.darkOakWood);
	public enum darkOakWoodNorthSouth = _.DARK_OAK_WOOD_NORTH_SOUTH.id;
	
	public alias DarkOakWoodBark = WoodBlock!(_.DARK_OAK_WOOD_BARK, Items.darkOakWood);
	public enum darkOakWoodBark = _.DARK_OAK_WOOD_BARK.id;
	
	public enum darkOakWood = [darkOakWoodUpDown, darkOakWoodEastWest, darkOakWoodNorthSouth, darkOakWoodBark];

	public enum woodUpDown = [oakWoodUpDown, spruceWoodUpDown, birchWoodUpDown, jungleWoodUpDown, acaciaWoodUpDown, darkOakWoodUpDown];

	public enum woodEastWest = [oakWoodEastWest, spruceWoodEastWest, birchWoodEastWest, jungleWoodEastWest, acaciaWoodEastWest, darkOakWoodEastWest];

	public enum woodNorthSouth = [oakWoodNorthSouth, spruceWoodNorthSouth, birchWoodNorthSouth, jungleWoodNorthSouth, acaciaWoodNorthSouth, darkOakWoodNorthSouth];

	public enum woodBark = [oakWoodBark, spruceWoodBark, birchWoodBark, jungleWoodBark, acaciaWoodBark, darkOakWoodBark];

	public enum wood = oakWood ~ spruceWood ~ birchWood ~ jungleWood ~ acaciaWood ~ darkOakWood;
	
	public alias OakLeavesDecay = LeavesBlock!(_.OAK_LEAVES_DECAY, true, Items.oakLeaves, Items.oakSapling, false, true);
	public enum oakLeavesDecay = _.OAK_LEAVES_DECAY.id;
	
	public alias OakLeavesNoDecay = LeavesBlock!(_.OAK_LEAVES_NO_DECAY, false, Items.oakLeaves, Items.oakSapling, false, true);
	public enum oakLeavesNoDecay = _.OAK_LEAVES_NO_DECAY.id;
	
	public alias OakLeavesCheckDecay = LeavesBlock!(_.OAK_LEAVES_CHECK_DECAY, true, Items.oakLeaves, Items.oakSapling, false, true);
	public enum oakLeavesCheckDecay = _.OAK_LEAVES_CHECK_DECAY.id;
	
	public alias OakLeavesNoDecayCheckDecay = LeavesBlock!(_.OAK_LEAVES_NO_DECAY_CHECK_DECAY, false, Items.oakLeaves, Items.oakSapling, false, true);
	public enum oakLeavesNoDecayCheckDecay = _.OAK_LEAVES_NO_DECAY_CHECK_DECAY.id;
	
	public enum oakLeaves = [oakLeavesDecay, oakLeavesNoDecay, oakLeavesCheckDecay, oakLeavesNoDecayCheckDecay];

	public alias SpruceLeavesDecay = LeavesBlock!(_.SPRUCE_LEAVES_DECAY, true, Items.spruceLeaves, Items.spruceSapling, false, false);
	public enum spruceLeavesDecay = _.SPRUCE_LEAVES_DECAY.id;
	
	public alias SpruceLeavesNoDecay = LeavesBlock!(_.SPRUCE_LEAVES_NO_DECAY, false, Items.spruceLeaves, Items.spruceSapling, false, false);
	public enum spruceLeavesNoDecay = _.SPRUCE_LEAVES_NO_DECAY.id;
	
	public alias SpruceLeavesCheckDecay = LeavesBlock!(_.SPRUCE_LEAVES_CHECK_DECAY, true, Items.spruceLeaves, Items.spruceSapling, false, false);
	public enum spruceLeavesCheckDecay = _.SPRUCE_LEAVES_CHECK_DECAY.id;
	
	public alias SpruceLeavesNoDecayCheckDecay = LeavesBlock!(_.SPRUCE_LEAVES_NO_DECAY_CHECK_DECAY, false, Items.spruceLeaves, Items.spruceSapling, false, false);
	public enum spruceLeavesNoDecayCheckDecay = _.SPRUCE_LEAVES_NO_DECAY_CHECK_DECAY.id;
	
	public enum spruceLeaves = [spruceLeavesDecay, spruceLeavesNoDecay, spruceLeavesCheckDecay, spruceLeavesNoDecayCheckDecay];
	
	public alias BirchLeavesDecay = LeavesBlock!(_.BIRCH_LEAVES_DECAY, true, Items.birchLeaves, Items.birchSapling, false, false);
	public enum birchLeavesDecay = _.BIRCH_LEAVES_DECAY.id;
	
	public alias BirchLeavesNoDecay = LeavesBlock!(_.BIRCH_LEAVES_NO_DECAY, false, Items.birchLeaves, Items.birchSapling, false, false);
	public enum birchLeavesNoDecay = _.BIRCH_LEAVES_NO_DECAY.id;
	
	public alias BirchLeavesCheckDecay = LeavesBlock!(_.BIRCH_LEAVES_CHECK_DECAY, true, Items.birchLeaves, Items.birchSapling, false, false);
	public enum birchLeavesCheckDecay = _.BIRCH_LEAVES_CHECK_DECAY.id;
	
	public alias BirchLeavesNoDecayCheckDecay = LeavesBlock!(_.BIRCH_LEAVES_NO_DECAY_CHECK_DECAY, false, Items.birchLeaves, Items.birchSapling, false, false);
	public enum birchLeavesNoDecayCheckDecay = _.BIRCH_LEAVES_NO_DECAY_CHECK_DECAY.id;
	
	public enum birchLeaves = [birchLeavesDecay, birchLeavesNoDecay, birchLeavesCheckDecay, birchLeavesNoDecayCheckDecay];
	
	public alias JungleLeavesDecay = LeavesBlock!(_.JUNGLE_LEAVES_DECAY, true, Items.jungleLeaves, Items.jungleSapling, true, false);
	public enum jungleLeavesDecay = _.JUNGLE_LEAVES_DECAY.id;
	
	public alias JungleLeavesNoDecay = LeavesBlock!(_.JUNGLE_LEAVES_NO_DECAY, false, Items.jungleLeaves, Items.jungleSapling, true, false);
	public enum jungleLeavesNoDecay = _.JUNGLE_LEAVES_NO_DECAY.id;
	
	public alias JungleLeavesCheckDecay = LeavesBlock!(_.JUNGLE_LEAVES_CHECK_DECAY, true, Items.jungleLeaves, Items.jungleSapling, true, false);
	public enum jungleLeavesCheckDecay = _.JUNGLE_LEAVES_CHECK_DECAY.id;
	
	public alias JungleLeavesNoDecayCheckDecay = LeavesBlock!(_.JUNGLE_LEAVES_NO_DECAY_CHECK_DECAY, false, Items.jungleLeaves, Items.jungleSapling, true, false);
	public enum jungleLeavesNoDecayCheckDecay = _.JUNGLE_LEAVES_NO_DECAY_CHECK_DECAY.id;
	
	public enum jungleLeaves = [jungleLeavesDecay, jungleLeavesNoDecay, jungleLeavesCheckDecay, jungleLeavesNoDecayCheckDecay];
	
	public alias AcaciaLeavesDecay = LeavesBlock!(_.ACACIA_LEAVES_DECAY, true, Items.acaciaLeaves, Items.acaciaSapling, false, false);
	public enum acaciaLeavesDecay = _.ACACIA_LEAVES_DECAY.id;
	
	public alias AcaciaLeavesNoDecay = LeavesBlock!(_.ACACIA_LEAVES_NO_DECAY, false, Items.acaciaLeaves, Items.acaciaSapling, false, false);
	public enum acaciaLeavesNoDecay = _.ACACIA_LEAVES_NO_DECAY.id;
	
	public alias AcaciaLeavesCheckDecay = LeavesBlock!(_.ACACIA_LEAVES_CHECK_DECAY, true, Items.acaciaLeaves, Items.acaciaSapling, false, false);
	public enum acaciaLeavesCheckDecay = _.ACACIA_LEAVES_CHECK_DECAY.id;
	
	public alias AcaciaLeavesNoDecayCheckDecay = LeavesBlock!(_.ACACIA_LEAVES_NO_DECAY_CHECK_DECAY, false, Items.acaciaLeaves, Items.acaciaSapling, false, false);
	public enum acaciaLeavesNoDecayCheckDecay = _.ACACIA_LEAVES_NO_DECAY_CHECK_DECAY.id;
	
	public enum acaciaLeaves = [acaciaLeavesDecay, acaciaLeavesNoDecay, acaciaLeavesCheckDecay, acaciaLeavesNoDecayCheckDecay];

	public alias DarkOakLeavesDecay = LeavesBlock!(_.DARK_OAK_LEAVES_DECAY, true, Items.darkOakLeaves, Items.darkOakSapling, false, true);
	public enum darkOakLeavesDecay = _.DARK_OAK_LEAVES_DECAY.id;
	
	public alias DarkOakLeavesNoDecay = LeavesBlock!(_.DARK_OAK_LEAVES_NO_DECAY, false, Items.darkOakLeaves, Items.darkOakSapling, false, true);
	public enum darkOakLeavesNoDecay = _.DARK_OAK_LEAVES_NO_DECAY.id;

	public alias DarkOakLeavesCheckDecay = LeavesBlock!(_.DARK_OAK_LEAVES_CHECK_DECAY, true, Items.darkOakLeaves, Items.darkOakSapling, false, true);
	public enum darkOakLeavesCheckDecay = _.DARK_OAK_LEAVES_CHECK_DECAY.id;
	
	public alias DarkOakLeavesNoDecayCheckDecay = LeavesBlock!(_.DARK_OAK_LEAVES_NO_DECAY_CHECK_DECAY, false, Items.darkOakLeaves, Items.darkOakSapling, false, true);
	public enum darkOakLeavesNoDecayCheckDecay = _.DARK_OAK_LEAVES_NO_DECAY_CHECK_DECAY.id;
	
	public enum darkOakLeaves = [darkOakLeavesDecay, darkOakLeavesNoDecay, darkOakLeavesCheckDecay, darkOakLeavesNoDecayCheckDecay];

	public enum leavesDecay = [oakLeavesDecay, spruceLeavesDecay, birchLeavesDecay, jungleLeavesDecay, acaciaLeavesDecay, darkOakLeavesDecay];

	public enum leavesNoDecay = [oakLeavesNoDecay, spruceLeavesNoDecay, birchLeavesNoDecay, jungleLeavesNoDecay, acaciaLeavesNoDecay, darkOakLeavesNoDecay];

	public enum leavesCheckDecay = [oakLeavesCheckDecay, spruceLeavesCheckDecay, birchLeavesCheckDecay, jungleLeavesCheckDecay, acaciaLeavesCheckDecay, darkOakLeavesCheckDecay];

	public enum leavesNoDecayCheckDecay = [oakLeavesNoDecayCheckDecay, spruceLeavesNoDecayCheckDecay, birchLeavesNoDecayCheckDecay, jungleLeavesNoDecayCheckDecay, acaciaLeavesNoDecayCheckDecay, darkOakLeavesNoDecayCheckDecay];

	public enum leaves = oakLeaves ~ spruceLeaves ~ birchLeaves ~ jungleLeaves ~ acaciaLeaves ~ darkOakLeaves;
	
	public enum flowingWater0 = _.FLOWING_WATER_0.id;
	
	public enum flowingWater1 = _.FLOWING_WATER_1.id;
	
	public enum flowingWater2 = _.FLOWING_WATER_2.id;
	
	public enum flowingWater3 = _.FLOWING_WATER_3.id;
	
	public enum flowingWater4 = _.FLOWING_WATER_4.id;
	
	public enum flowingWater5 = _.FLOWING_WATER_5.id;
	
	public enum flowingWater6 = _.FLOWING_WATER_6.id;
	
	public enum flowingWater7 = _.FLOWING_WATER_7.id;
	
	public enum flowingWaterFalling0 = _.FLOWING_WATER_FALLING_0.id;
	
	public enum flowingWaterFalling1 = _.FLOWING_WATER_FALLING_1.id;
	
	public enum flowingWaterFalling2 = _.FLOWING_WATER_FALLING_2.id;
	
	public enum flowingWaterFalling3 = _.FLOWING_WATER_FALLING_3.id;
	
	public enum flowingWaterFalling4 = _.FLOWING_WATER_FALLING_4.id;
	
	public enum flowingWaterFalling5 = _.FLOWING_WATER_FALLING_5.id;
	
	public enum flowingWaterFalling6 = _.FLOWING_WATER_FALLING_6.id;
	
	public enum flowingWaterFalling7 = _.FLOWING_WATER_FALLING_7.id;
	
	public enum flowingWater = [flowingWater0, flowingWater1, flowingWater2, flowingWater3, flowingWater4, flowingWater5, flowingWater6, flowingWater7, flowingWaterFalling0, flowingWaterFalling1, flowingWaterFalling2, flowingWaterFalling3, flowingWaterFalling4, flowingWaterFalling5, flowingWaterFalling6, flowingWaterFalling7];
	
	public enum stillWater0 = _.STILL_WATER_0.id;
	
	public enum stillWater1 = _.STILL_WATER_1.id;
	
	public enum stillWater2 = _.STILL_WATER_2.id;
	
	public enum stillWater3 = _.STILL_WATER_3.id;
	
	public enum stillWater4 = _.STILL_WATER_4.id;
	
	public enum stillWater5 = _.STILL_WATER_5.id;
	
	public enum stillWater6 = _.STILL_WATER_6.id;
	
	public enum stillWater7 = _.STILL_WATER_7.id;
	
	public enum stillWaterFalling0 = _.STILL_WATER_FALLING_0.id;
	
	public enum stillWaterFalling1 = _.STILL_WATER_FALLING_1.id;
	
	public enum stillWaterFalling2 = _.STILL_WATER_FALLING_2.id;
	
	public enum stillWaterFalling3 = _.STILL_WATER_FALLING_3.id;
	
	public enum stillWaterFalling4 = _.STILL_WATER_FALLING_4.id;
	
	public enum stillWaterFalling5 = _.STILL_WATER_FALLING_5.id;
	
	public enum stillWaterFalling6 = _.STILL_WATER_FALLING_6.id;
	
	public enum stillWaterFalling7 = _.STILL_WATER_FALLING_7.id;
	
	public enum stillWater = [stillWater0, stillWater1, stillWater2, stillWater3, stillWater4, stillWater5, stillWater6, stillWater7, stillWaterFalling0, stillWaterFalling1, stillWaterFalling2, stillWaterFalling3, stillWaterFalling4, stillWaterFalling5, stillWaterFalling6, stillWaterFalling7];
	
	public enum water = flowingWater ~ stillWater;
	
	public enum flowingLava0 = _.FLOWING_LAVA_0.id;
	
	public enum flowingLava1 = _.FLOWING_LAVA_1.id;
	
	public enum flowingLava2 = _.FLOWING_LAVA_2.id;
	
	public enum flowingLava3 = _.FLOWING_LAVA_3.id;
	
	public enum flowingLava4 = _.FLOWING_LAVA_4.id;
	
	public enum flowingLava5 = _.FLOWING_LAVA_5.id;
	
	public enum flowingLava6 = _.FLOWING_LAVA_6.id;
	
	public enum flowingLava7 = _.FLOWING_LAVA_7.id;
	
	public enum flowingLavaFalling0 = _.FLOWING_LAVA_FALLING_0.id;
	
	public enum flowingLavaFalling1 = _.FLOWING_LAVA_FALLING_1.id;
	
	public enum flowingLavaFalling2 = _.FLOWING_LAVA_FALLING_2.id;
	
	public enum flowingLavaFalling3 = _.FLOWING_LAVA_FALLING_3.id;
	
	public enum flowingLavaFalling4 = _.FLOWING_LAVA_FALLING_4.id;
	
	public enum flowingLavaFalling5 = _.FLOWING_LAVA_FALLING_5.id;
	
	public enum flowingLavaFalling6 = _.FLOWING_LAVA_FALLING_6.id;
	
	public enum flowingLavaFalling7 = _.FLOWING_LAVA_FALLING_7.id;
	
	public enum flowingLava = [flowingLava0, flowingLava1, flowingLava2, flowingLava3, flowingLava4, flowingLava5, flowingLava6, flowingLava7, flowingLavaFalling0, flowingLavaFalling1, flowingLavaFalling2, flowingLavaFalling3, flowingLavaFalling4, flowingLavaFalling5, flowingLavaFalling6, flowingLavaFalling7];
	
	public enum stillLava0 = _.STILL_LAVA_0.id;
	
	public enum stillLava1 = _.STILL_LAVA_1.id;
	
	public enum stillLava2 = _.STILL_LAVA_2.id;
	
	public enum stillLava3 = _.STILL_LAVA_3.id;
	
	public enum stillLava4 = _.STILL_LAVA_4.id;
	
	public enum stillLava5 = _.STILL_LAVA_5.id;
	
	public enum stillLava6 = _.STILL_LAVA_6.id;
	
	public enum stillLava7 = _.STILL_LAVA_7.id;
	
	public enum stillLavaFalling0 = _.STILL_LAVA_FALLING_0.id;
	
	public enum stillLavaFalling1 = _.STILL_LAVA_FALLING_1.id;
	
	public enum stillLavaFalling2 = _.STILL_LAVA_FALLING_2.id;
	
	public enum stillLavaFalling3 = _.STILL_LAVA_FALLING_3.id;
	
	public enum stillLavaFalling4 = _.STILL_LAVA_FALLING_4.id;
	
	public enum stillLavaFalling5 = _.STILL_LAVA_FALLING_5.id;
	
	public enum stillLavaFalling6 = _.STILL_LAVA_FALLING_6.id;
	
	public enum stillLavaFalling7 = _.STILL_LAVA_FALLING_7.id;
	
	public enum stillLava = [stillLava0, stillLava1, stillLava2, stillLava3, stillLava4, stillLava5, stillLava6, stillLava7, stillLavaFalling0, stillLavaFalling1, stillLavaFalling2, stillLavaFalling3, stillLavaFalling4, stillLavaFalling5, stillLavaFalling6, stillLavaFalling7];
	
	public enum lava = flowingLava ~ stillLava;

	public alias Sponge = AbsorbingBlock!(_.SPONGE, Items.sponge, wetSponge, 7, 65);
	public enum sponge = _.SPONGE.id;

	public alias WetSponge = MineableBlock!(_.WET_SPONGE, MiningTool.init, Drop(Items.wetSponge, 1));
	public enum wetSponge = _.WET_SPONGE.id;
	
	public alias Glass = MineableBlock!(_.GLASS, MiningTool.init, Drop(0, 0, 0, Items.glass));
	public enum glass = _.GLASS.id;
	
	public alias WhiteStainedGlass = MineableBlock!(_.WHITE_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.whiteStainedGlass));
	public enum whiteStainedGlass = _.WHITE_STAINED_GLASS.id;
	
	public alias OrangeStainedGlass = MineableBlock!(_.ORANGE_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.orangeStainedGlass));
	public enum orangeStainedGlass = _.ORANGE_STAINED_GLASS.id;
	
	public alias MagentaStainedGlass = MineableBlock!(_.MAGENTA_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.magentaStainedGlass));
	public enum magentaStainedGlass = _.MAGENTA_STAINED_GLASS.id;
	
	public alias LightBlueStainedGlass = MineableBlock!(_.LIGHT_BLUE_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.lightBlueStainedGlass));
	public enum lightBlueStainedGlass = _.LIGHT_BLUE_STAINED_GLASS.id;
	
	public alias YellowStainedGlass = MineableBlock!(_.YELLOW_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.yellowStainedGlass));
	public enum yellowStainedGlass = _.YELLOW_STAINED_GLASS.id;
	
	public alias LimeStainedGlass = MineableBlock!(_.LIME_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.limeStainedGlass));
	public enum limeStainedGlass = _.LIME_STAINED_GLASS.id;
	
	public alias PinkStainedGlass = MineableBlock!(_.PINK_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.pinkStainedGlass));
	public enum pinkStainedGlass = _.PINK_STAINED_GLASS.id;
	
	public alias GrayStainedGlass = MineableBlock!(_.GRAY_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.grayStainedGlass));
	public enum grayStainedGlass = _.GRAY_STAINED_GLASS.id;
	
	public alias LightGrayStainedGlass = MineableBlock!(_.LIGHT_GRAY_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.lightGrayStainedGlass));
	public enum lightGrayStainedGlass = _.LIGHT_GRAY_STAINED_GLASS.id;
	
	public alias CyanStainedGlass = MineableBlock!(_.CYAN_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.cyanStainedGlass));
	public enum cyanStainedGlass = _.CYAN_STAINED_GLASS.id;
	
	public alias PurpleStainedGlass = MineableBlock!(_.PURPLE_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.purpleStainedGlass));
	public enum purpleStainedGlass = _.PURPLE_STAINED_GLASS.id;
	
	public alias BlueStainedGlass = MineableBlock!(_.BLUE_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.blueStainedGlass));
	public enum blueStainedGlass = _.BLUE_STAINED_GLASS.id;
	
	public alias BrownStainedGlass = MineableBlock!(_.BROWN_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.brownStainedGlass));
	public enum brownStainedGlass = _.BROWN_STAINED_GLASS.id;
	
	public alias GreenStainedGlass = MineableBlock!(_.GREEN_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.greenStainedGlass));
	public enum greenStainedGlass = _.GREEN_STAINED_GLASS.id;
	
	public alias RedStainedGlass = MineableBlock!(_.RED_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.redStainedGlass));
	public enum redStainedGlass = _.RED_STAINED_GLASS.id;
	
	public alias BlackStainedGlass = MineableBlock!(_.BLACK_STAINED_GLASS, MiningTool.init, Drop(0, 0, 0, Items.blackStainedGlass));
	public enum blackStainedGlass = _.BLACK_STAINED_GLASS.id;
	
	public enum stainedGlass = [whiteStainedGlass, orangeStainedGlass, magentaStainedGlass, lightBlueStainedGlass, yellowStainedGlass, limeStainedGlass, pinkStainedGlass, grayStainedGlass, lightGrayStainedGlass, cyanStainedGlass, purpleStainedGlass, blueStainedGlass, brownStainedGlass, greenStainedGlass, redStainedGlass, blackStainedGlass];

	//TODO glass pane's real shape

	public alias GlassPane = MineableBlock!(_.GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.glassPane));
	public enum glassPane = _.GLASS_PANE.id;
	
	public alias WhiteStainedGlassPane = MineableBlock!(_.WHITE_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.whiteStainedGlassPane));
	public enum whiteStainedGlassPane = _.WHITE_STAINED_GLASS_PANE.id;
	
	public alias OrangeStainedGlassPane = MineableBlock!(_.ORANGE_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.orangeStainedGlassPane));
	public enum orangeStainedGlassPane = _.ORANGE_STAINED_GLASS_PANE.id;
	
	public alias MagentaStainedGlassPane = MineableBlock!(_.MAGENTA_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.magentaStainedGlassPane));
	public enum magentaStainedGlassPane = _.MAGENTA_STAINED_GLASS_PANE.id;
	
	public alias LightBlueStainedGlassPane = MineableBlock!(_.LIGHT_BLUE_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.lightBlueStainedGlassPane));
	public enum lightBlueStainedGlassPane = _.LIGHT_BLUE_STAINED_GLASS_PANE.id;
	
	public alias YellowStainedGlassPane = MineableBlock!(_.YELLOW_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.yellowStainedGlassPane));
	public enum yellowStainedGlassPane = _.YELLOW_STAINED_GLASS_PANE.id;
	
	public alias LimeStainedGlassPane = MineableBlock!(_.LIME_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.limeStainedGlassPane));
	public enum limeStainedGlassPane = _.LIME_STAINED_GLASS_PANE.id;
	
	public alias PinkStainedGlassPane = MineableBlock!(_.PINK_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.pinkStainedGlassPane));
	public enum pinkStainedGlassPane = _.PINK_STAINED_GLASS_PANE.id;
	
	public alias GrayStainedGlassPane = MineableBlock!(_.GRAY_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.grayStainedGlassPane));
	public enum grayStainedGlassPane = _.GRAY_STAINED_GLASS_PANE.id;
	
	public alias LightGrayStainedGlassPane = MineableBlock!(_.LIGHT_GRAY_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.lightGrayStainedGlassPane));
	public enum lightGrayStainedGlassPane = _.LIGHT_GRAY_STAINED_GLASS_PANE.id;
	
	public alias CyanStainedGlassPane = MineableBlock!(_.CYAN_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.cyanStainedGlassPane));
	public enum cyanStainedGlassPane = _.CYAN_STAINED_GLASS_PANE.id;
	
	public alias PurpleStainedGlassPane = MineableBlock!(_.PURPLE_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.purpleStainedGlassPane));
	public enum purpleStainedGlassPane = _.PURPLE_STAINED_GLASS_PANE.id;
	
	public alias BlueStainedGlassPane = MineableBlock!(_.BLUE_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.blueStainedGlassPane));
	public enum blueStainedGlassPane = _.BLUE_STAINED_GLASS_PANE.id;
	
	public alias BrownStainedGlassPane = MineableBlock!(_.BROWN_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.brownStainedGlassPane));
	public enum brownStainedGlassPane = _.BROWN_STAINED_GLASS_PANE.id;
	
	public alias GreenStainedGlassPane = MineableBlock!(_.GREEN_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.greenStainedGlassPane));
	public enum greenStainedGlassPane = _.GREEN_STAINED_GLASS_PANE.id;
	
	public alias RedStainedGlassPane = MineableBlock!(_.RED_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.redStainedGlassPane));
	public enum redStainedGlassPane = _.RED_STAINED_GLASS_PANE.id;
	
	public alias BlackStainedGlassPane = MineableBlock!(_.BLACK_STAINED_GLASS_PANE, MiningTool.init, Drop(0, 0, 0, Items.blackStainedGlassPane));
	public enum blackStainedGlassPane = _.BLACK_STAINED_GLASS_PANE.id;
	
	public enum stainedGlassPane = [whiteStainedGlassPane, orangeStainedGlassPane, magentaStainedGlassPane, lightBlueStainedGlassPane, yellowStainedGlassPane, limeStainedGlassPane, pinkStainedGlassPane, grayStainedGlassPane, lightGrayStainedGlassPane, cyanStainedGlassPane, purpleStainedGlassPane, blueStainedGlassPane, brownStainedGlassPane, greenStainedGlassPane, redStainedGlassPane, blackStainedGlassPane];

	public alias Sandstone = MineableBlock!(_.SANDSTONE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstone, 1));
	public enum sandstone = _.SANDSTONE.id;
	
	public alias ChiseledSandstone = MineableBlock!(_.CHISELED_SANDSTONE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.chiseledSandstone, 1));
	public enum chiseledSandstone = _.CHISELED_SANDSTONE.id;
	
	public alias SmoothSandstone = MineableBlock!(_.SMOOTH_SANDSTONE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.smoothSandstone, 1));
	public enum smoothSandstone = _.SMOOTH_SANDSTONE.id;

	public alias RedSandstone = MineableBlock!(_.RED_SANDSTONE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstone, 1));
	public enum redSandstone = _.RED_SANDSTONE.id;
	
	public alias ChiseledRedSandstone = MineableBlock!(_.CHISELED_RED_SANDSTONE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.chiseledRedSandstone, 1));
	public enum chiseledRedSandstone = _.CHISELED_RED_SANDSTONE.id;
	
	public alias SmoothRedSandstone = MineableBlock!(_.SMOOTH_RED_SANDSTONE, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.smoothRedSandstone, 1));
	public enum smoothRedSandstone = _.SMOOTH_RED_SANDSTONE.id;
	
	public enum dispenserFacingDown = _.DISPENSER_FACING_DOWN.id;
	
	public enum dispenserFacingUp = _.DISPENSER_FACING_UP.id;
	
	public enum dispenserFacingNorth = _.DISPENSER_FACING_NORTH.id;
	
	public enum dispenserFacingSouth = _.DISPENSER_FACING_SOUTH.id;
	
	public enum dispenserFacingWest = _.DISPENSER_FACING_WEST.id;
	
	public enum dispenserFacingEast = _.DISPENSER_FACING_EAST.id;
	
	public enum activeDispenserFacingDown = _.ACTIVE_DISPENSER_FACING_DOWN.id;
	
	public enum activeDispenserFacingUp = _.ACTIVE_DISPENSER_FACING_UP.id;
	
	public enum activeDispenserFacingNorth = _.ACTIVE_DISPENSER_FACING_NORTH.id;
	
	public enum activeDispenserFacingSouth = _.ACTIVE_DISPENSER_FACING_SOUTH.id;
	
	public enum activeDispenserFacingWest = _.ACTIVE_DISPENSER_FACING_WEST.id;
	
	public enum activeDispenserFacingEast = _.ACTIVE_DISPENSER_FACING_EAST.id;
	
	public enum dropperFacingDown = _.DROPPER_FACING_DOWN.id;
	
	public enum dropperFacingUp = _.DROPPER_FACING_UP.id;
	
	public enum dropperFacingNorth = _.DROPPER_FACING_NORTH.id;
	
	public enum dropperFacingSouth = _.DROPPER_FACING_SOUTH.id;
	
	public enum dropperFacingWest = _.DROPPER_FACING_WEST.id;
	
	public enum dropperFacingEast = _.DROPPER_FACING_EAST.id;
	
	public enum activeDropperFacingDown = _.ACTIVE_DROPPER_FACING_DOWN.id;
	
	public enum activeDropperFacingUp = _.ACTIVE_DROPPER_FACING_UP.id;
	
	public enum activeDropperFacingNorth = _.ACTIVE_DROPPER_FACING_NORTH.id;
	
	public enum activeDropperFacingSouth = _.ACTIVE_DROPPER_FACING_SOUTH.id;
	
	public enum activeDropperFacingWest = _.ACTIVE_DROPPER_FACING_WEST.id;
	
	public enum activeDropperFacingEast = _.ACTIVE_DROPPER_FACING_EAST.id;
	
	public enum observerFacingDown = _.OBSERVER_FACING_DOWN.id;
	
	public enum observerFacingUp = _.OBSERVER_FACING_UP.id;
	
	public enum observerFacingNorth = _.OBSERVER_FACING_NORTH.id;
	
	public enum observerFacingSouth = _.OBSERVER_FACING_SOUTH.id;
	
	public enum observerFacingWest = _.OBSERVER_FACING_WEST.id;
	
	public enum observerFacingEast = _.OBSERVER_FACING_EAST.id;

	public enum noteBlock = _.NOTE_BLOCK.id;
	
	public enum bedFootFacingSouth = _.BED_FOOT_FACING_SOUTH.id;
	
	public enum bedFootFacingWest = _.BED_FOOT_FACING_WEST.id;
	
	public enum bedFootFacingNorth = _.BED_FOOT_FACING_NORTH.id;
	
	public enum bedFootFacingEast = _.BED_FOOT_FACING_EAST.id;
	
	public enum occupiedBedFootFacingSouth = _.OCCUPIED_BED_FOOT_FACING_SOUTH.id;
	
	public enum occupiedBedFootFacingWest = _.OCCUPIED_BED_FOOT_FACING_WEST.id;
	
	public enum occupiedBedFootFacingNorth = _.OCCUPIED_BED_FOOT_FACING_NORTH.id;
	
	public enum occupiedBedFootFacingEast = _.OCCUPIED_BED_FOOT_FACING_EAST.id;
	
	public enum bedHeadFacingSouth = _.BED_HEAD_FACING_SOUTH.id;
	
	public enum bedHeadFacingWest = _.BED_HEAD_FACING_WEST.id;
	
	public enum bedHeadFacingNorth = _.BED_HEAD_FACING_NORTH.id;
	
	public enum bedHeadFacingEast = _.BED_HEAD_FACING_EAST.id;
	
	public enum occupiedBedHeadFacingSouth = _.OCCUPIED_BED_HEAD_FACING_SOUTH.id;
	
	public enum occupiedBedHeadFacingWest = _.OCCUPIED_BED_HEAD_FACING_WEST.id;
	
	public enum occupiedBedHeadFacingNorth = _.OCCUPIED_BED_HEAD_FACING_NORTH.id;
	
	public enum occupiedBedHeadFacingEast = _.OCCUPIED_BED_HEAD_FACING_EAST.id;

	public enum railNorthSouth = _.RAIL_NORTH_SOUTH.id;

	public enum railEastWest = _.RAIL_EAST_WEST.id;
	
	public enum railAscendingEast = _.RAIL_ASCENDING_EAST.id;
	
	public enum railAscendingWest = _.RAIL_ASCENDING_WEST.id;
	
	public enum railAscendingNorth = _.RAIL_ASCENDING_NORTH.id;
	
	public enum railAscendingSouth = _.RAIL_ASCENDING_SOUTH.id;
	
	public enum railCurvedSouthEast = _.RAIL_CURVED_SOUTH_EAST.id;
	
	public enum railCurvedSouthWest = _.RAIL_CURVED_SOUTH_WEST.id;
	
	public enum railCurvedNorthEast = _.RAIL_CURVED_NORTH_EAST.id;
	
	public enum railCurvedNorthWest = _.RAIL_CURVED_NORTH_WEST.id;
	
	public enum poweredRailNorthSouth = _.POWERED_RAIL_NORTH_SOUTH.id;
	
	public enum poweredRailEastWest = _.POWERED_RAIL_EAST_WEST.id;
	
	public enum poweredRailAscendingEast = _.POWERED_RAIL_ASCENDING_EAST.id;
	
	public enum poweredRailAscendingWest = _.POWERED_RAIL_ASCENDING_WEST.id;
	
	public enum poweredRailAscendingNorth = _.POWERED_RAIL_ASCENDING_NORTH.id;
	
	public enum poweredRailAscendingSouth = _.POWERED_RAIL_ASCENDING_SOUTH.id;
	
	public enum activePoweredRailNorthSouth = _.ACTIVE_POWERED_RAIL_NORTH_SOUTH.id;
	
	public enum activePoweredRailEastWest = _.ACTIVE_POWERED_RAIL_EAST_WEST.id;
	
	public enum activePoweredRailAscendingEast = _.ACTIVE_POWERED_RAIL_ASCENDING_EAST.id;
	
	public enum activePoweredRailAscendingWest = _.ACTIVE_POWERED_RAIL_ASCENDING_WEST.id;
	
	public enum activePoweredRailAscendingNorth = _.ACTIVE_POWERED_RAIL_ASCENDING_NORTH.id;
	
	public enum activePoweredRailAscendingSouth = _.ACTIVE_POWERED_RAIL_ASCENDING_SOUTH.id;
	
	public enum activatorRailNorthSouth = _.ACTIVATOR_RAIL_NORTH_SOUTH.id;
	
	public enum activatorRailEastWest = _.ACTIVATOR_RAIL_EAST_WEST.id;
	
	public enum activatorRailAscendingEast = _.ACTIVATOR_RAIL_ASCENDING_EAST.id;
	
	public enum activatorRailAscendingWest = _.ACTIVATOR_RAIL_ASCENDING_WEST.id;
	
	public enum activatorRailAscendingNorth = _.ACTIVATOR_RAIL_ASCENDING_NORTH.id;
	
	public enum activatorRailAscendingSouth = _.ACTIVATOR_RAIL_ASCENDING_SOUTH.id;
	
	public enum activeActivatorRailNorthSouth = _.ACTIVE_ACTIVATOR_RAIL_NORTH_SOUTH.id;
	
	public enum activeActivatorRailEastWest = _.ACTIVE_ACTIVATOR_RAIL_EAST_WEST.id;
	
	public enum activeActivatorRailAscendingEast = _.ACTIVE_ACTIVATOR_RAIL_ASCENDING_EAST.id;
	
	public enum activeActivatorRailAscendingWest = _.ACTIVE_ACTIVATOR_RAIL_ASCENDING_WEST.id;
	
	public enum activeActivatorRailAscendingNorth = _.ACTIVE_ACTIVATOR_RAIL_ASCENDING_NORTH.id;
	
	public enum activeActivatorRailAscendingSouth = _.ACTIVE_ACTIVATOR_RAIL_ASCENDING_SOUTH.id;
	
	public enum detectorRailNorthSouth = _.DETECTOR_RAIL_NORTH_SOUTH.id;
	
	public enum detectorRailEastWest = _.DETECTOR_RAIL_EAST_WEST.id;
	
	public enum detectorRailAscendingEast = _.DETECTOR_RAIL_ASCENDING_EAST.id;
	
	public enum detectorRailAscendingWest = _.DETECTOR_RAIL_ASCENDING_WEST.id;
	
	public enum detectorRailAscendingNorth = _.DETECTOR_RAIL_ASCENDING_NORTH.id;
	
	public enum detectorRailAscendingSouth = _.DETECTOR_RAIL_ASCENDING_SOUTH.id;
	
	public enum activeDetectorRailNorthSouth = _.ACTIVE_DETECTOR_RAIL_NORTH_SOUTH.id;
	
	public enum activeDetectorRailEastWest = _.ACTIVE_DETECTOR_RAIL_EAST_WEST.id;
	
	public enum activeDetectorRailAscendingEast = _.ACTIVE_DETECTOR_RAIL_ASCENDING_EAST.id;
	
	public enum activeDetectorRailAscendingWest = _.ACTIVE_DETECTOR_RAIL_ASCENDING_WEST.id;
	
	public enum activeDetectorRailAscendingNorth = _.ACTIVE_DETECTOR_RAIL_ASCENDING_NORTH.id;
	
	public enum activeDetectorRailAscendingSouth = _.ACTIVE_DETECTOR_RAIL_ASCENDING_SOUTH.id;
	
	public enum pistonFacingDown = _.PISTON_FACING_DOWN.id;
	
	public enum pistonFacingUp = _.PISTON_FACING_UP.id;
	
	public enum pistonFacingNorth = _.PISTON_FACING_NORTH.id;
	
	public enum pistonFacingSouth = _.PISTON_FACING_SOUTH.id;
	
	public enum pistonFacingWest = _.PISTON_FACING_WEST.id;
	
	public enum pistonFacingEast = _.PISTON_FACING_EAST.id;
	
	public alias PistonFacingEverywhere = MineableBlock!(_.PISTON_FACING_EVERYWHERE, MiningTool.init, Drop(Items.piston, 1));
	public enum pistonFacingEverywhere = _.PISTON_FACING_EVERYWHERE.id;
	
	public alias PistonFacingEverywhere1 = MineableBlock!(_.PISTON_FACING_EVERYWHERE_1, MiningTool.init, Drop(Items.piston, 1));
	public enum pistonFacingEverywhere1 = _.PISTON_FACING_EVERYWHERE_1.id;
	
	public enum extendedPistonFacingDown = _.EXTENDED_PISTON_FACING_DOWN.id;
	
	public enum extendedPistonFacingUp = _.EXTENDED_PISTON_FACING_UP.id;
	
	public enum extendedPistonFacingNorth = _.EXTENDED_PISTON_FACING_NORTH.id;
	
	public enum extendedPistonFacingSouth = _.EXTENDED_PISTON_FACING_SOUTH.id;
	
	public enum extendedPistonFacingWest = _.EXTENDED_PISTON_FACING_WEST.id;
	
	public enum extendedPistonFacingEast = _.EXTENDED_PISTON_FACING_EAST.id;
	
	public alias ExtendedPistonFacingEverywhere = MineableBlock!(_.EXTENDED_PISTON_FACING_EVERYWHERE, MiningTool.init, Drop(Items.piston, 1));
	public enum extendedPistonFacingEverywhere = _.EXTENDED_PISTON_FACING_EVERYWHERE.id;
	
	public alias ExtendedPistonFacingEverywhere1 = MineableBlock!(_.EXTENDED_PISTON_FACING_EVERYWHERE_1, MiningTool.init, Drop(Items.piston, 1));
	public enum extendedPistonFacingEverywhere1 = _.EXTENDED_PISTON_FACING_EVERYWHERE_1.id;
	
	public enum stickyPistonFacingDown = _.STICKY_PISTON_FACING_DOWN.id;
	
	public enum stickyPistonFacingUp = _.STICKY_PISTON_FACING_UP.id;
	
	public enum stickyPistonFacingNorth = _.STICKY_PISTON_FACING_NORTH.id;
	
	public enum stickyPistonFacingSouth = _.STICKY_PISTON_FACING_SOUTH.id;
	
	public enum stickyPistonFacingWest = _.STICKY_PISTON_FACING_WEST.id;
	
	public enum stickyPistonFacingEast = _.STICKY_PISTON_FACING_EAST.id;
	
	public alias StickyPistonFacingEverywhere = MineableBlock!(_.STICKY_PISTON_FACING_EVERYWHERE, MiningTool.init, Drop(Items.stickyPiston, 1));
	public enum stickyPistonFacingEverywhere = _.STICKY_PISTON_FACING_EVERYWHERE.id;
	
	public alias StickyPistonFacingEverywhere1 = MineableBlock!(_.STICKY_PISTON_FACING_EVERYWHERE_1, MiningTool.init, Drop(Items.stickyPiston, 1));
	public enum stickyPistonFacingEverywhere1 = _.STICKY_PISTON_FACING_EVERYWHERE_1.id;
	
	public enum extendedStickyPistonFacingDown = _.EXTENDED_STICKY_PISTON_FACING_DOWN.id;
	
	public enum extendedStickyPistonFacingUp = _.EXTENDED_STICKY_PISTON_FACING_UP.id;
	
	public enum extendedStickyPistonFacingNorth = _.EXTENDED_STICKY_PISTON_FACING_NORTH.id;
	
	public enum extendedStickyPistonFacingSouth = _.EXTENDED_STICKY_PISTON_FACING_SOUTH.id;
	
	public enum extendedStickyPistonFacingWest = _.EXTENDED_STICKY_PISTON_FACING_WEST.id;
	
	public enum extendedStickyPistonFacingEast = _.EXTENDED_STICKY_PISTON_FACING_EAST.id;
	
	public alias ExtendedStickyPistonFacingEverywhere = MineableBlock!(_.EXTENDED_STICKY_PISTON_FACING_EVERYWHERE, MiningTool.init, Drop(Items.piston, 1));
	public enum extendedStickyPistonFacingEverywhere = _.EXTENDED_STICKY_PISTON_FACING_EVERYWHERE.id;
	
	public alias ExtendedStickyPistonFacingEverywhere1 = MineableBlock!(_.EXTENDED_STICKY_PISTON_FACING_EVERYWHERE_1, MiningTool.init, Drop(Items.piston, 1));
	public enum extendedStickyPistonFacingEverywhere1 = _.EXTENDED_STICKY_PISTON_FACING_EVERYWHERE_1.id;

	public enum pistonHeadFacingDown = _.PISTON_HEAD_FACING_DOWN.id;
	
	public enum pistonHeadFacingUp = _.PISTON_HEAD_FACING_UP.id;
	
	public enum pistonHeadFacingNorth = _.PISTON_HEAD_FACING_NORTH.id;
	
	public enum pistonHeadFacingSouth = _.PISTON_HEAD_FACING_SOUTH.id;
	
	public enum pistonHeadFacingWest = _.PISTON_HEAD_FACING_WEST.id;
	
	public enum pistonHeadFacingEast = _.PISTON_HEAD_FACING_EAST.id;

	public enum pistonExtension = _.PISTON_EXTENSION.id;

	public alias WhiteWool = MineableBlock!(_.WHITE_WOOL, MiningTool(false, Tools.shears), Drop(Items.whiteWool, 1));
	public enum whiteWool = _.WHITE_WOOL.id;
	
	public alias OrangeWool = MineableBlock!(_.ORANGE_WOOL, MiningTool(false, Tools.shears), Drop(Items.orangeWool, 1));
	public enum orangeWool = _.ORANGE_WOOL.id;
	
	public alias MagentaWool = MineableBlock!(_.MAGENTA_WOOL, MiningTool(false, Tools.shears), Drop(Items.magentaWool, 1));
	public enum magentaWool = _.MAGENTA_WOOL.id;
	
	public alias LightBlueWool = MineableBlock!(_.LIGHT_BLUE_WOOL, MiningTool(false, Tools.shears), Drop(Items.lightBlueWool, 1));
	public enum lightBlueWool = _.LIGHT_BLUE_WOOL.id;
	
	public alias YellowWool = MineableBlock!(_.YELLOW_WOOL, MiningTool(false, Tools.shears), Drop(Items.yellowWool, 1));
	public enum yellowWool = _.YELLOW_WOOL.id;
	
	public alias LimeWool = MineableBlock!(_.LIME_WOOL, MiningTool(false, Tools.shears), Drop(Items.limeWool, 1));
	public enum limeWool = _.LIME_WOOL.id;
	
	public alias PinkWool = MineableBlock!(_.PINK_WOOL, MiningTool(false, Tools.shears), Drop(Items.pinkWool, 1));
	public enum pinkWool = _.PINK_WOOL.id;
	
	public alias GrayWool = MineableBlock!(_.GRAY_WOOL, MiningTool(false, Tools.shears), Drop(Items.grayWool, 1));
	public enum grayWool = _.GRAY_WOOL.id;
	
	public alias LightGrayWool = MineableBlock!(_.LIGHT_GRAY_WOOL, MiningTool(false, Tools.shears), Drop(Items.lightGrayWool, 1));
	public enum lightGrayWool = _.LIGHT_GRAY_WOOL.id;
	
	public alias CyanWool = MineableBlock!(_.CYAN_WOOL, MiningTool(false, Tools.shears), Drop(Items.cyanWool, 1));
	public enum cyanWool = _.CYAN_WOOL.id;
	
	public alias PurpleWool = MineableBlock!(_.PURPLE_WOOL, MiningTool(false, Tools.shears), Drop(Items.purpleWool, 1));
	public enum purpleWool = _.PURPLE_WOOL.id;
	
	public alias BlueWool = MineableBlock!(_.BLUE_WOOL, MiningTool(false, Tools.shears), Drop(Items.blueWool, 1));
	public enum blueWool = _.BLUE_WOOL.id;
	
	public alias BrownWool = MineableBlock!(_.BROWN_WOOL, MiningTool(false, Tools.shears), Drop(Items.brownWool, 1));
	public enum brownWool = _.BROWN_WOOL.id;
	
	public alias GreenWool = MineableBlock!(_.GREEN_WOOL, MiningTool(false, Tools.shears), Drop(Items.greenWool, 1));
	public enum greenWool = _.GREEN_WOOL.id;
	
	public alias RedWool = MineableBlock!(_.RED_WOOL, MiningTool(false, Tools.shears), Drop(Items.redWool, 1));
	public enum redWool = _.RED_WOOL.id;
	
	public alias BlackWool = MineableBlock!(_.BLACK_WOOL, MiningTool(false, Tools.shears), Drop(Items.blackWool, 1));
	public enum blackWool = _.BLACK_WOOL.id;
	
	public enum wool = [whiteWool, orangeWool, magentaWool, lightBlueWool, yellowWool, limeWool, pinkWool, grayWool, lightGrayWool, cyanWool, purpleWool, blueWool, brownWool, greenWool, redWool, blackWool];

	public alias WhiteCarpet = MineableBlock!(_.WHITE_CARPET, MiningTool.init, Drop(Items.whiteCarpet, 1));
	public enum whiteCarpet = _.WHITE_CARPET.id;
	
	public alias OrangeCarpet = MineableBlock!(_.ORANGE_CARPET, MiningTool.init, Drop(Items.orangeCarpet, 1));
	public enum orangeCarpet = _.ORANGE_CARPET.id;
	
	public alias MagentaCarpet = MineableBlock!(_.MAGENTA_CARPET, MiningTool.init, Drop(Items.magentaCarpet, 1));
	public enum magentaCarpet = _.MAGENTA_CARPET.id;
	
	public alias LightBlueCarpet = MineableBlock!(_.LIGHT_BLUE_CARPET, MiningTool.init, Drop(Items.lightBlueCarpet, 1));
	public enum lightBlueCarpet = _.LIGHT_BLUE_CARPET.id;
	
	public alias YellowCarpet = MineableBlock!(_.YELLOW_CARPET, MiningTool.init, Drop(Items.yellowCarpet, 1));
	public enum yellowCarpet = _.YELLOW_CARPET.id;
	
	public alias LimeCarpet = MineableBlock!(_.LIME_CARPET, MiningTool.init, Drop(Items.limeCarpet, 1));
	public enum limeCarpet = _.LIME_CARPET.id;
	
	public alias PinkCarpet = MineableBlock!(_.PINK_CARPET, MiningTool.init, Drop(Items.pinkCarpet, 1));
	public enum pinkCarpet = _.PINK_CARPET.id;
	
	public alias GrayCarpet = MineableBlock!(_.GRAY_CARPET, MiningTool.init, Drop(Items.grayCarpet, 1));
	public enum grayCarpet = _.GRAY_CARPET.id;
	
	public alias LightGrayCarpet = MineableBlock!(_.LIGHT_GRAY_CARPET, MiningTool.init, Drop(Items.lightGrayCarpet, 1));
	public enum lightGrayCarpet = _.LIGHT_GRAY_CARPET.id;
	
	public alias CyanCarpet = MineableBlock!(_.CYAN_CARPET, MiningTool.init, Drop(Items.cyanCarpet, 1));
	public enum cyanCarpet = _.CYAN_CARPET.id;
	
	public alias PurpleCarpet = MineableBlock!(_.PURPLE_CARPET, MiningTool.init, Drop(Items.purpleCarpet, 1));
	public enum purpleCarpet = _.PURPLE_CARPET.id;
	
	public alias BlueCarpet = MineableBlock!(_.BLUE_CARPET, MiningTool.init, Drop(Items.blueCarpet, 1));
	public enum blueCarpet = _.BLUE_CARPET.id;
	
	public alias BrownCarpet = MineableBlock!(_.BROWN_CARPET, MiningTool.init, Drop(Items.brownCarpet, 1));
	public enum brownCarpet = _.BROWN_CARPET.id;
	
	public alias GreenCarpet = MineableBlock!(_.GREEN_CARPET, MiningTool.init, Drop(Items.greenCarpet, 1));
	public enum greenCarpet = _.GREEN_CARPET.id;
	
	public alias RedCarpet = MineableBlock!(_.RED_CARPET, MiningTool.init, Drop(Items.redCarpet, 1));
	public enum redCarpet = _.RED_CARPET.id;
	
	public alias BlackCarpet = MineableBlock!(_.BLACK_CARPET, MiningTool.init, Drop(Items.blackCarpet, 1));
	public enum blackCarpet = _.BLACK_CARPET.id;
	
	public enum carpet = [whiteCarpet, orangeCarpet, magentaCarpet, lightBlueCarpet, yellowCarpet, limeCarpet, pinkCarpet, grayCarpet, lightGrayCarpet, cyanCarpet, purpleCarpet, blueCarpet, brownCarpet, greenCarpet, redCarpet, blackCarpet];

	public alias Dandelion = FlowerBlock!(_.DANDELION, Items.dandelion);
	public enum dandelion = _.DANDELION.id;

	public alias Poppy = FlowerBlock!(_.POPPY, Items.poppy);
	public enum poppy = _.POPPY.id;

	public alias BlueOrchid = FlowerBlock!(_.BLUE_ORCHID, Items.blueOrchid);
	public enum blueOrchid = _.BLUE_ORCHID.id;

	public alias Allium = FlowerBlock!(_.ALLIUM, Items.allium);
	public enum allium = _.ALLIUM.id;

	public alias AzureBluet = FlowerBlock!(_.AZURE_BLUET, Items.azureBluet);
	public enum azureBluet = _.AZURE_BLUET.id;

	public alias RedTulip = FlowerBlock!(_.RED_TULIP, Items.redTulip);
	public enum redTulip = _.RED_TULIP.id;

	public alias OrangeTulip = FlowerBlock!(_.ORANGE_TULIP, Items.orangeTulip);
	public enum orangeTulip = _.ORANGE_TULIP.id;

	public alias WhiteTulip = FlowerBlock!(_.WHITE_TULIP, Items.whiteTulip);
	public enum whiteTulip = _.WHITE_TULIP.id;

	public alias PinkTulip = FlowerBlock!(_.PINK_TULIP, Items.pinkTulip);
	public enum pinkTulip = _.PINK_TULIP.id;

	public alias OxeyeDaisy = FlowerBlock!(_.OXEYE_DAISY, Items.oxeyeDaisy);
	public enum oxeyeDaisy = _.OXEYE_DAISY.id;
	
	public alias SunflowerBottom = DoublePlantBlock!(_.SUNFLOWER_BOTTOM, false, sunflowerTop, Items.sunflower);
	public enum sunflowerBottom = _.SUNFLOWER_BOTTOM.id;
	
	public alias SunflowerTop = DoublePlantBlock!(_.SUNFLOWER_TOP, true, sunflowerBottom, Items.sunflower);
	public enum sunflowerTop = _.SUNFLOWER_TOP.id;
	
	public enum sunflower = [sunflowerBottom, sunflowerTop];
	
	public alias LiliacBottom = DoublePlantBlock!(_.LILIAC_BOTTOM, false, liliacTop, Items.liliac);
	public enum liliacBottom = _.LILIAC_BOTTOM.id;
	
	public alias LiliacTop = DoublePlantBlock!(_.LILIAC_TOP, true, liliacBottom, Items.liliac);
	public enum liliacTop = _.LILIAC_TOP.id;
	
	public enum liliac = [liliacBottom, liliacTop];
	
	public alias DoubleTallgrassBottom = DoublePlantBlock!(_.DOUBLE_TALLGRASS_BOTTOM, false, doubleTallgrassTop, Items.tallGrass, true);
	public enum doubleTallgrassBottom = _.DOUBLE_TALLGRASS_BOTTOM.id;
	
	public alias DoubleTallgrassTop = DoublePlantBlock!(_.DOUBLE_TALLGRASS_TOP, true, doubleTallgrassBottom, Items.tallGrass, true);
	public enum doubleTallgrassTop = _.DOUBLE_TALLGRASS_TOP.id;
	
	public enum doubleTallgrass = [doubleTallgrassBottom, doubleTallgrassTop];
	
	public alias LargeFernBottom = DoublePlantBlock!(_.LARGE_FERN_BOTTOM, false, largeFernTop, Items.fern, true);
	public enum largeFernBottom = _.LARGE_FERN_BOTTOM.id;
	
	public alias LargeFernTop = DoublePlantBlock!(_.LARGE_FERN_TOP, true, largeFernBottom, Items.fern, true);
	public enum largeFernTop = _.LARGE_FERN_TOP.id;
	
	public enum largeFern = [largeFernBottom, largeFernTop];
	
	public alias RoseBushBottom = DoublePlantBlock!(_.ROSE_BUSH_BOTTOM, false, roseBushTop, Items.roseBush);
	public enum roseBushBottom = _.ROSE_BUSH_BOTTOM.id;
	
	public alias RoseBushTop = DoublePlantBlock!(_.ROSE_BUSH_TOP, true, roseBushBottom, Items.roseBush);
	public enum roseBushTop = _.ROSE_BUSH_TOP.id;
	
	public enum roseBush = [roseBushBottom, roseBushTop];
	
	public alias PeonyBottom = DoublePlantBlock!(_.PEONY_BOTTOM, false, peonyTop, Items.peony);
	public enum peonyBottom = _.PEONY_BOTTOM.id;
	
	public alias PeonyTop = DoublePlantBlock!(_.PEONY_TOP, true, peonyBottom, Items.peony);
	public enum peonyTop = _.PEONY_TOP.id;
	
	public enum peony = [peonyBottom, peonyTop];

	public enum brownMushroom = _.BROWN_MUSHROOM.id;

	public enum redMushroom = _.RED_MUSHROOM.id;

	public alias TallGrass = PlantBlock!(_.TALL_GRASS, Items.tallGrass, Drop(Items.seeds, 0, 1));
	public enum tallGrass = _.TALL_GRASS.id;

	public alias Fern = PlantBlock!(_.FERN, Items.fern, Drop(Items.seeds, 0, 1));
	public enum fern = _.FERN.id;

	public alias DeadBush = PlantBlock!(_.DEAD_BUSH, Items.deadBush, Drop(Items.stick, 0, 2));
	public enum deadBush = _.DEAD_BUSH.id;
	
	public alias StoneSlab = MineableBlock!(_.STONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneSlab, 1));
	public enum stoneSlab = _.STONE_SLAB.id;
	
	public alias SandstoneSlab = MineableBlock!(_.SANDSTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstoneSlab, 1));
	public enum sandstoneSlab = _.SANDSTONE_SLAB.id;
	
	public alias StoneWoodenSlab = MineableBlock!(_.STONE_WOODEN_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneWoodenSlab, 1));
	public enum stoneWoodenSlab = _.STONE_WOODEN_SLAB.id;
	
	public alias CobblestoneSlab = MineableBlock!(_.COBBLESTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cobblestoneSlab, 1));
	public enum cobblestoneSlab = _.COBBLESTONE_SLAB.id;
	
	public alias BricksSlab = MineableBlock!(_.BRICKS_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.bricksSlab, 1));
	public enum bricksSlab = _.BRICKS_SLAB.id;
	
	public alias StoneBrickSlab = MineableBlock!(_.STONE_BRICK_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneBrickSlab, 1));
	public enum stoneBrickSlab = _.STONE_BRICK_SLAB.id;
	
	public alias NetherBrickSlab = MineableBlock!(_.NETHER_BRICK_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrickSlab, 1));
	public enum netherBrickSlab = _.NETHER_BRICK_SLAB.id;
	
	public alias QuartzSlab = MineableBlock!(_.QUARTZ_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.quartzSlab, 1));
	public enum quartzSlab = _.QUARTZ_SLAB.id;
	
	public alias RedSandstoneSlab = MineableBlock!(_.RED_SANDSTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstoneSlab, 1));
	public enum redSandstoneSlab = _.RED_SANDSTONE_SLAB.id;
	
	public alias PurpurSlab = MineableBlock!(_.PURPUR_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpurSlab, 1));
	public enum purpurSlab = _.PURPUR_SLAB.id;
	
	public alias OakWoodSlab = MineableBlock!(_.OAK_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodSlab, 1));
	public enum oakWoodSlab = _.OAK_WOOD_SLAB.id;
	
	public alias SpruceWoodSlab = MineableBlock!(_.SPRUCE_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodSlab, 1));
	public enum spruceWoodSlab = _.SPRUCE_WOOD_SLAB.id;
	
	public alias BirchWoodSlab = MineableBlock!(_.BIRCH_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodSlab, 1));
	public enum birchWoodSlab = _.BIRCH_WOOD_SLAB.id;
	
	public alias JungleWoodSlab = MineableBlock!(_.JUNGLE_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodSlab, 1));
	public enum jungleWoodSlab = _.JUNGLE_WOOD_SLAB.id;
	
	public alias AcaciaWoodSlab = MineableBlock!(_.ACACIA_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodSlab, 1));
	public enum acaciaWoodSlab = _.ACACIA_WOOD_SLAB.id;
	
	public alias DarkOakWoodSlab = MineableBlock!(_.DARK_OAK_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodSlab, 1));
	public enum darkOakWoodSlab = _.DARK_OAK_WOOD_SLAB.id;
	
	public alias UpperStoneSlab = MineableBlock!(_.UPPER_STONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneSlab, 1));
	public enum upperStoneSlab = _.UPPER_STONE_SLAB.id;
	
	public alias UpperSandstoneSlab = MineableBlock!(_.UPPER_SANDSTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstoneSlab, 1));
	public enum upperSandstoneSlab = _.UPPER_SANDSTONE_SLAB.id;
	
	public alias UpperStoneWoodenSlab = MineableBlock!(_.UPPER_STONE_WOODEN_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneWoodenSlab, 1));
	public enum upperStoneWoodenSlab = _.UPPER_STONE_WOODEN_SLAB.id;
	
	public alias UpperCobblestoneSlab = MineableBlock!(_.UPPER_COBBLESTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cobblestoneSlab, 1));
	public enum upperCobblestoneSlab = _.UPPER_COBBLESTONE_SLAB.id;
	
	public alias UpperBricksSlab = MineableBlock!(_.UPPER_BRICKS_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.bricksSlab, 1));
	public enum upperBricksSlab = _.UPPER_BRICKS_SLAB.id;
	
	public alias UpperStoneBrickSlab = MineableBlock!(_.UPPER_STONE_BRICK_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneBrickSlab, 1));
	public enum upperStoneBrickSlab = _.UPPER_STONE_BRICK_SLAB.id;
	
	public alias UpperNetherBrickSlab = MineableBlock!(_.UPPER_NETHER_BRICK_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrickSlab, 1));
	public enum upperNetherBrickSlab = _.UPPER_NETHER_BRICK_SLAB.id;
	
	public alias UpperQuartzSlab = MineableBlock!(_.UPPER_QUARTZ_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.quartzSlab, 1));
	public enum upperQuartzSlab = _.UPPER_QUARTZ_SLAB.id;
	
	public alias UpperRedSandstoneSlab = MineableBlock!(_.UPPER_RED_SANDSTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstoneSlab, 1));
	public enum upperRedSandstoneSlab = _.UPPER_RED_SANDSTONE_SLAB.id;
	
	public alias UpperPurpurSlab = MineableBlock!(_.UPPER_PURPUR_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpurSlab, 1));
	public enum upperPurpurSlab = _.UPPER_PURPUR_SLAB.id;
	
	public alias UpperOakWoodSlab = MineableBlock!(_.UPPER_OAK_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodSlab, 1));
	public enum upperOakWoodSlab = _.UPPER_OAK_WOOD_SLAB.id;
	
	public alias UpperSpruceWoodSlab = MineableBlock!(_.UPPER_SPRUCE_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodSlab, 1));
	public enum upperSpruceWoodSlab = _.UPPER_SPRUCE_WOOD_SLAB.id;
	
	public alias UpperBirchWoodSlab = MineableBlock!(_.BIRCH_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodSlab, 1));
	public enum upperBirchWoodSlab = _.UPPER_BIRCH_WOOD_SLAB.id;
	
	public alias UpperJungleWoodSlab = MineableBlock!(_.UPPER_JUNGLE_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodSlab, 1));
	public enum upperJungleWoodSlab = _.UPPER_JUNGLE_WOOD_SLAB.id;
	
	public alias UpperAcaciaWoodSlab = MineableBlock!(_.UPPER_ACACIA_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodSlab, 1));
	public enum upperAcaciaWoodSlab = _.UPPER_ACACIA_WOOD_SLAB.id;
	
	public alias UpperDarkOakWoodSlab = MineableBlock!(_.UPPER_DARK_OAK_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodSlab, 1));
	public enum upperDarkOakWoodSlab = _.UPPER_DARK_OAK_WOOD_SLAB.id;
	
	public alias DoubleStoneSlab = MineableBlock!(_.DOUBLE_STONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneSlab, 2));
	public enum doubleStoneSlab = _.DOUBLE_STONE_SLAB.id;
	
	public alias DoubleSandstoneSlab = MineableBlock!(_.DOUBLE_SANDSTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstoneSlab, 2));
	public enum doubleSandstoneSlab = _.DOUBLE_SANDSTONE_SLAB.id;
	
	public alias DoubleStoneWoodenSlab = MineableBlock!(_.DOUBLE_STONE_WOODEN_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneWoodenSlab, 2));
	public enum doubleStoneWoodenSlab = _.DOUBLE_STONE_WOODEN_SLAB.id;
	
	public alias DoubleCobblestoneSlab = MineableBlock!(_.DOUBLE_COBBLESTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cobblestoneSlab, 2));
	public enum doubleCobblestoneSlab = _.DOUBLE_COBBLESTONE_SLAB.id;

	public alias DoubleBricksSlab = MineableBlock!(_.DOUBLE_BRICKS_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.bricksSlab, 1));
	public enum doubleBricksSlab = _.DOUBLE_BRICKS_SLAB.id;
	
	public alias DoubleStoneBrickSlab = MineableBlock!(_.DOUBLE_STONE_BRICK_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneBrickSlab, 2));
	public enum doubleStoneBrickSlab = _.DOUBLE_STONE_BRICK_SLAB.id;
	
	public alias DoubleNetherBrickSlab = MineableBlock!(_.DOUBLE_NETHER_BRICK_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrickSlab, 2));
	public enum doubleNetherBrickSlab = _.DOUBLE_NETHER_BRICK_SLAB.id;
	
	public alias DoubleQuartzSlab = MineableBlock!(_.DOUBLE_QUARTZ_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.quartzSlab, 2));
	public enum doubleQuartzSlab = _.DOUBLE_QUARTZ_SLAB.id;
	
	public alias DoubleRedSandstoneSlab = MineableBlock!(_.DOUBLE_RED_SANDSTONE_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstoneSlab, 2));
	public enum doubleRedSandstoneSlab = _.DOUBLE_RED_SANDSTONE_SLAB.id;
	
	public alias DoublePurpurSlab = MineableBlock!(_.DOUBLE_PURPUR_SLAB, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpurSlab, 2));
	public enum doublePurpurSlab = _.DOUBLE_PURPUR_SLAB.id;
	
	public alias DoubleOakWoodSlab = MineableBlock!(_.DOUBLE_OAK_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodSlab, 2));
	public enum doubleOakWoodSlab = _.DOUBLE_OAK_WOOD_SLAB.id;
	
	public alias DoubleSpruceWoodSlab = MineableBlock!(_.DOUBLE_SPRUCE_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodSlab, 2));
	public enum doubleSpruceWoodSlab = _.DOUBLE_SPRUCE_WOOD_SLAB.id;
	
	public alias DoubleBirchWoodSlab = MineableBlock!(_.BIRCH_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodSlab, 2));
	public enum doubleBirchWoodSlab = _.DOUBLE_BIRCH_WOOD_SLAB.id;
	
	public alias DoubleJungleWoodSlab = MineableBlock!(_.DOUBLE_JUNGLE_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodSlab, 2));
	public enum doubleJungleWoodSlab = _.DOUBLE_JUNGLE_WOOD_SLAB.id;
	
	public alias DoubleAcaciaWoodSlab = MineableBlock!(_.DOUBLE_ACACIA_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodSlab, 2));
	public enum doubleAcaciaWoodSlab = _.DOUBLE_ACACIA_WOOD_SLAB.id;
	
	public alias DoubleDarkOakWoodSlab = MineableBlock!(_.DOUBLE_DARK_OAK_WOOD_SLAB, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodSlab, 2));
	public enum doubleDarkOakWoodSlab = _.DOUBLE_DARK_OAK_WOOD_SLAB.id;
	
	public alias CobblestoneStairsFacingEast = StairsBlock!(_.COBBLESTONE_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum cobblestoneStairsFacingEast = _.COBBLESTONE_STAIRS_FACING_EAST.id;
	
	public alias CobblestoneStairsFacingWest = StairsBlock!(_.COBBLESTONE_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum cobblestoneStairsFacingWest = _.COBBLESTONE_STAIRS_FACING_WEST.id;
	
	public alias CobblestoneStairsFacingSouth = StairsBlock!(_.COBBLESTONE_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum cobblestoneStairsFacingSouth = _.COBBLESTONE_STAIRS_FACING_SOUTH.id;
	
	public alias CobblestoneStairsFacingNorth = StairsBlock!(_.COBBLESTONE_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum cobblestoneStairsFacingNorth = _.COBBLESTONE_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownCobblestoneStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum upsideDownCobblestoneStairsFacingEast = _.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownCobblestoneStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum upsideDownCobblestoneStairsFacingWest = _.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownCobblestoneStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum upsideDownCobblestoneStairsFacingSouth = _.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownCobblestoneStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs);
	public enum upsideDownCobblestoneStairsFacingNorth = _.UPSIDE_DOWN_COBBLESTONE_STAIRS_FACING_NORTH.id;

	public enum cobblestoneStairs = [cobblestoneStairsFacingEast, cobblestoneStairsFacingWest, cobblestoneStairsFacingSouth, cobblestoneStairsFacingNorth, upsideDownCobblestoneStairsFacingEast, upsideDownCobblestoneStairsFacingWest, upsideDownCobblestoneStairsFacingSouth, upsideDownCobblestoneStairsFacingNorth];

	public alias BrickStairsFacingEast = StairsBlock!(_.BRICK_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum brickStairsFacingEast = _.BRICK_STAIRS_FACING_EAST.id;
	
	public alias BrickStairsFacingWest = StairsBlock!(_.BRICK_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum brickStairsFacingWest = _.BRICK_STAIRS_FACING_WEST.id;
	
	public alias BrickStairsFacingSouth = StairsBlock!(_.BRICK_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum brickStairsFacingSouth = _.BRICK_STAIRS_FACING_SOUTH.id;
	
	public alias BrickStairsFacingNorth = StairsBlock!(_.BRICK_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum brickStairsFacingNorth = _.BRICK_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownBrickStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_BRICK_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum upsideDownBrickStairsFacingEast = _.UPSIDE_DOWN_BRICK_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownBrickStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_BRICK_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum upsideDownBrickStairsFacingWest = _.UPSIDE_DOWN_BRICK_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownBrickStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_BRICK_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum upsideDownBrickStairsFacingSouth = _.UPSIDE_DOWN_BRICK_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownBrickStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_BRICK_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs);
	public enum upsideDownBrickStairsFacingNorth = _.UPSIDE_DOWN_BRICK_STAIRS_FACING_NORTH.id;
	
	public enum brickStairs = [brickStairsFacingEast, brickStairsFacingWest, brickStairsFacingSouth, brickStairsFacingNorth, upsideDownBrickStairsFacingEast, upsideDownBrickStairsFacingWest, upsideDownBrickStairsFacingSouth, upsideDownBrickStairsFacingNorth];

	public alias NetherBrickStairsFacingEast = StairsBlock!(_.NETHER_BRICK_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum netherBrickStairsFacingEast = _.NETHER_BRICK_STAIRS_FACING_EAST.id;
	
	public alias NetherBrickStairsFacingWest = StairsBlock!(_.NETHER_BRICK_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum netherBrickStairsFacingWest = _.NETHER_BRICK_STAIRS_FACING_WEST.id;
	
	public alias NetherBrickStairsFacingSouth = StairsBlock!(_.NETHER_BRICK_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum netherBrickStairsFacingSouth = _.NETHER_BRICK_STAIRS_FACING_SOUTH.id;
	
	public alias NetherBrickStairsFacingNorth = StairsBlock!(_.NETHER_BRICK_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum netherBrickStairsFacingNorth = _.NETHER_BRICK_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownNetherBrickStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum upsideDownNetherBrickStairsFacingEast = _.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownNetherBrickStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum upsideDownNetherBrickStairsFacingWest = _.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownNetherBrickStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum upsideDownNetherBrickStairsFacingSouth = _.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownNetherBrickStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs);
	public enum upsideDownNetherBrickStairsFacingNorth = _.UPSIDE_DOWN_NETHER_BRICK_STAIRS_FACING_NORTH.id;
	
	public enum netherBrickStairs = [netherBrickStairsFacingEast, netherBrickStairsFacingWest, netherBrickStairsFacingSouth, netherBrickStairsFacingNorth, upsideDownNetherBrickStairsFacingEast, upsideDownNetherBrickStairsFacingWest, upsideDownNetherBrickStairsFacingSouth, upsideDownNetherBrickStairsFacingNorth];

	public alias StoneBrickStairsFacingEast = StairsBlock!(_.STONE_BRICK_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum stoneBrickStairsFacingEast = _.STONE_BRICK_STAIRS_FACING_EAST.id;
	
	public alias StoneBrickStairsFacingWest = StairsBlock!(_.STONE_BRICK_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum stoneBrickStairsFacingWest = _.STONE_BRICK_STAIRS_FACING_WEST.id;
	
	public alias StoneBrickStairsFacingSouth = StairsBlock!(_.STONE_BRICK_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum stoneBrickStairsFacingSouth = _.STONE_BRICK_STAIRS_FACING_SOUTH.id;
	
	public alias StoneBrickStairsFacingNorth = StairsBlock!(_.STONE_BRICK_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum stoneBrickStairsFacingNorth = _.STONE_BRICK_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownStoneBrickStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum upsideDownStoneBrickStairsFacingEast = _.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownStoneBrickStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum upsideDownStoneBrickStairsFacingWest = _.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownStoneBrickStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum upsideDownStoneBrickStairsFacingSouth = _.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownStoneBrickStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs);
	public enum upsideDownStoneBrickStairsFacingNorth = _.UPSIDE_DOWN_STONE_BRICK_STAIRS_FACING_NORTH.id;
	
	public enum stoneBrickStairs = [stoneBrickStairsFacingEast, stoneBrickStairsFacingWest, stoneBrickStairsFacingSouth, stoneBrickStairsFacingNorth, upsideDownStoneBrickStairsFacingEast, upsideDownStoneBrickStairsFacingWest, upsideDownStoneBrickStairsFacingSouth, upsideDownStoneBrickStairsFacingNorth];

	public alias PurpurStairsFacingEast = StairsBlock!(_.PURPUR_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum purpurStairsFacingEast = _.PURPUR_STAIRS_FACING_EAST.id;
	
	public alias PurpurStairsFacingWest = StairsBlock!(_.PURPUR_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum purpurStairsFacingWest = _.PURPUR_STAIRS_FACING_WEST.id;
	
	public alias PurpurStairsFacingSouth = StairsBlock!(_.PURPUR_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum purpurStairsFacingSouth = _.PURPUR_STAIRS_FACING_SOUTH.id;
	
	public alias PurpurStairsFacingNorth = StairsBlock!(_.PURPUR_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum purpurStairsFacingNorth = _.PURPUR_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownPurpurStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_PURPUR_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum upsideDownPurpurStairsFacingEast = _.UPSIDE_DOWN_PURPUR_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownPurpurStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_PURPUR_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum upsideDownPurpurStairsFacingWest = _.UPSIDE_DOWN_PURPUR_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownPurpurStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_PURPUR_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum upsideDownPurpurStairsFacingSouth = _.UPSIDE_DOWN_PURPUR_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownPurpurStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_PURPUR_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs);
	public enum upsideDownPurpurStairsFacingNorth = _.UPSIDE_DOWN_PURPUR_STAIRS_FACING_NORTH.id;
	
	public enum purpurStairs = [purpurStairsFacingEast, purpurStairsFacingWest, purpurStairsFacingSouth, purpurStairsFacingNorth, upsideDownPurpurStairsFacingEast, upsideDownPurpurStairsFacingWest, upsideDownPurpurStairsFacingSouth, upsideDownPurpurStairsFacingNorth];

	public alias QuartzStairsFacingEast = StairsBlock!(_.QUARTZ_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum quartzStairsFacingEast = _.QUARTZ_STAIRS_FACING_EAST.id;
	
	public alias QuartzStairsFacingWest = StairsBlock!(_.QUARTZ_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum quartzStairsFacingWest = _.QUARTZ_STAIRS_FACING_WEST.id;
	
	public alias QuartzStairsFacingSouth = StairsBlock!(_.QUARTZ_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum quartzStairsFacingSouth = _.QUARTZ_STAIRS_FACING_SOUTH.id;
	
	public alias QuartzStairsFacingNorth = StairsBlock!(_.QUARTZ_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum quartzStairsFacingNorth = _.QUARTZ_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownQuartzStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum upsideDownQuartzStairsFacingEast = _.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownQuartzStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum upsideDownQuartzStairsFacingWest = _.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownQuartzStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum upsideDownQuartzStairsFacingSouth = _.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownQuartzStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs);
	public enum upsideDownQuartzStairsFacingNorth = _.UPSIDE_DOWN_QUARTZ_STAIRS_FACING_NORTH.id;
	
	public enum quartzStairs = [quartzStairsFacingEast, quartzStairsFacingWest, quartzStairsFacingSouth, quartzStairsFacingNorth, upsideDownQuartzStairsFacingEast, upsideDownQuartzStairsFacingWest, upsideDownQuartzStairsFacingSouth, upsideDownQuartzStairsFacingNorth];

	public alias SandstoneStairsFacingEast = StairsBlock!(_.SANDSTONE_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum sandstoneStairsFacingEast = _.SANDSTONE_STAIRS_FACING_EAST.id;
	
	public alias SandstoneStairsFacingWest = StairsBlock!(_.SANDSTONE_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum sandstoneStairsFacingWest = _.SANDSTONE_STAIRS_FACING_WEST.id;
	
	public alias SandstoneStairsFacingSouth = StairsBlock!(_.SANDSTONE_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum sandstoneStairsFacingSouth = _.SANDSTONE_STAIRS_FACING_SOUTH.id;
	
	public alias SandstoneStairsFacingNorth = StairsBlock!(_.SANDSTONE_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum sandstoneStairsFacingNorth = _.SANDSTONE_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownSandstoneStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum upsideDownSandstoneStairsFacingEast = _.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownSandstoneStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum upsideDownSandstoneStairsFacingWest = _.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownSandstoneStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum upsideDownSandstoneStairsFacingSouth = _.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownSandstoneStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs);
	public enum upsideDownSandstoneStairsFacingNorth = _.UPSIDE_DOWN_SANDSTONE_STAIRS_FACING_NORTH.id;
	
	public enum sandstoneStairs = [sandstoneStairsFacingEast, sandstoneStairsFacingWest, sandstoneStairsFacingSouth, sandstoneStairsFacingNorth, upsideDownSandstoneStairsFacingEast, upsideDownSandstoneStairsFacingWest, upsideDownSandstoneStairsFacingSouth, upsideDownSandstoneStairsFacingNorth];

	public alias RedSandstoneStairsFacingEast = StairsBlock!(_.RED_SANDSTONE_STAIRS_FACING_EAST, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum redSandstoneStairsFacingEast = _.RED_SANDSTONE_STAIRS_FACING_EAST.id;
	
	public alias RedSandstoneStairsFacingWest = StairsBlock!(_.RED_SANDSTONE_STAIRS_FACING_WEST, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum redSandstoneStairsFacingWest = _.RED_SANDSTONE_STAIRS_FACING_WEST.id;
	
	public alias RedSandstoneStairsFacingSouth = StairsBlock!(_.RED_SANDSTONE_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum redSandstoneStairsFacingSouth = _.RED_SANDSTONE_STAIRS_FACING_SOUTH.id;
	
	public alias RedSandstoneStairsFacingNorth = StairsBlock!(_.RED_SANDSTONE_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum redSandstoneStairsFacingNorth = _.RED_SANDSTONE_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownRedSandstoneStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_EAST, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum upsideDownRedSandstoneStairsFacingEast = _.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownRedSandstoneStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_WEST, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum upsideDownRedSandstoneStairsFacingWest = _.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownRedSandstoneStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum upsideDownRedSandstoneStairsFacingSouth = _.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownRedSandstoneStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs);
	public enum upsideDownRedSandstoneStairsFacingNorth = _.UPSIDE_DOWN_RED_SANDSTONE_STAIRS_FACING_NORTH.id;
	
	public enum redSandstoneStairs = [redSandstoneStairsFacingEast, redSandstoneStairsFacingWest, redSandstoneStairsFacingSouth, redSandstoneStairsFacingNorth, upsideDownRedSandstoneStairsFacingEast, upsideDownRedSandstoneStairsFacingWest, upsideDownRedSandstoneStairsFacingSouth, upsideDownRedSandstoneStairsFacingNorth];

	public alias OakWoodStairsFacingEast = StairsBlock!(_.OAK_WOOD_STAIRS_FACING_EAST, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum oakWoodStairsFacingEast = _.OAK_WOOD_STAIRS_FACING_EAST.id;
	
	public alias OakWoodStairsFacingWest = StairsBlock!(_.OAK_WOOD_STAIRS_FACING_WEST, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum oakWoodStairsFacingWest = _.OAK_WOOD_STAIRS_FACING_WEST.id;
	
	public alias OakWoodStairsFacingSouth = StairsBlock!(_.OAK_WOOD_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum oakWoodStairsFacingSouth = _.OAK_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias OakWoodStairsFacingNorth = StairsBlock!(_.OAK_WOOD_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum oakWoodStairsFacingNorth = _.OAK_WOOD_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownOakWoodStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_EAST, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum upsideDownOakWoodStairsFacingEast = _.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownOakWoodStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_WEST, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum upsideDownOakWoodStairsFacingWest = _.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownOakWoodStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum upsideDownOakWoodStairsFacingSouth = _.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownOakWoodStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs);
	public enum upsideDownOakWoodStairsFacingNorth = _.UPSIDE_DOWN_OAK_WOOD_STAIRS_FACING_NORTH.id;
	
	public enum oakWoodStairs = [oakWoodStairsFacingEast, oakWoodStairsFacingWest, oakWoodStairsFacingSouth, oakWoodStairsFacingNorth, upsideDownOakWoodStairsFacingEast, upsideDownOakWoodStairsFacingWest, upsideDownOakWoodStairsFacingSouth, upsideDownOakWoodStairsFacingNorth];

	public alias SpruceWoodStairsFacingEast = StairsBlock!(_.SPRUCE_WOOD_STAIRS_FACING_EAST, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum spruceWoodStairsFacingEast = _.SPRUCE_WOOD_STAIRS_FACING_EAST.id;
	
	public alias SpruceWoodStairsFacingWest = StairsBlock!(_.SPRUCE_WOOD_STAIRS_FACING_WEST, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum spruceWoodStairsFacingWest = _.SPRUCE_WOOD_STAIRS_FACING_WEST.id;
	
	public alias SpruceWoodStairsFacingSouth = StairsBlock!(_.SPRUCE_WOOD_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum spruceWoodStairsFacingSouth = _.SPRUCE_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias SpruceWoodStairsFacingNorth = StairsBlock!(_.SPRUCE_WOOD_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum spruceWoodStairsFacingNorth = _.SPRUCE_WOOD_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownSpruceWoodStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_EAST, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum upsideDownSpruceWoodStairsFacingEast = _.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownSpruceWoodStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_WEST, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum upsideDownSpruceWoodStairsFacingWest = _.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownSpruceWoodStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum upsideDownSpruceWoodStairsFacingSouth = _.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownSpruceWoodStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs);
	public enum upsideDownSpruceWoodStairsFacingNorth = _.UPSIDE_DOWN_SPRUCE_WOOD_STAIRS_FACING_NORTH.id;
	
	public enum spruceWoodStairs = [spruceWoodStairsFacingEast, spruceWoodStairsFacingWest, spruceWoodStairsFacingSouth, spruceWoodStairsFacingNorth, upsideDownSpruceWoodStairsFacingEast, upsideDownSpruceWoodStairsFacingWest, upsideDownSpruceWoodStairsFacingSouth, upsideDownSpruceWoodStairsFacingNorth];

	public alias BirchWoodStairsFacingEast = StairsBlock!(_.BIRCH_WOOD_STAIRS_FACING_EAST, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum birchWoodStairsFacingEast = _.BIRCH_WOOD_STAIRS_FACING_EAST.id;
	
	public alias BirchWoodStairsFacingWest = StairsBlock!(_.BIRCH_WOOD_STAIRS_FACING_WEST, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum birchWoodStairsFacingWest = _.BIRCH_WOOD_STAIRS_FACING_WEST.id;
	
	public alias BirchWoodStairsFacingSouth = StairsBlock!(_.BIRCH_WOOD_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum birchWoodStairsFacingSouth = _.BIRCH_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias BirchWoodStairsFacingNorth = StairsBlock!(_.BIRCH_WOOD_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum birchWoodStairsFacingNorth = _.BIRCH_WOOD_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownBirchWoodStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_EAST, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum upsideDownBirchWoodStairsFacingEast = _.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownBirchWoodStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_WEST, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum upsideDownBirchWoodStairsFacingWest = _.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownBirchWoodStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum upsideDownBirchWoodStairsFacingSouth = _.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownBirchWoodStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs);
	public enum upsideDownBirchWoodStairsFacingNorth = _.UPSIDE_DOWN_BIRCH_WOOD_STAIRS_FACING_NORTH.id;
	
	public enum birchWoodStairs = [birchWoodStairsFacingEast, birchWoodStairsFacingWest, birchWoodStairsFacingSouth, birchWoodStairsFacingNorth, upsideDownBirchWoodStairsFacingEast, upsideDownBirchWoodStairsFacingWest, upsideDownBirchWoodStairsFacingSouth, upsideDownBirchWoodStairsFacingNorth];

	public alias JungleWoodStairsFacingEast = StairsBlock!(_.JUNGLE_WOOD_STAIRS_FACING_EAST, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum jungleWoodStairsFacingEast = _.JUNGLE_WOOD_STAIRS_FACING_EAST.id;
	
	public alias JungleWoodStairsFacingWest = StairsBlock!(_.JUNGLE_WOOD_STAIRS_FACING_WEST, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum jungleWoodStairsFacingWest = _.JUNGLE_WOOD_STAIRS_FACING_WEST.id;
	
	public alias JungleWoodStairsFacingSouth = StairsBlock!(_.JUNGLE_WOOD_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum jungleWoodStairsFacingSouth = _.JUNGLE_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias JungleWoodStairsFacingNorth = StairsBlock!(_.JUNGLE_WOOD_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum jungleWoodStairsFacingNorth = _.JUNGLE_WOOD_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownJungleWoodStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_EAST, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum upsideDownJungleWoodStairsFacingEast = _.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownJungleWoodStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_WEST, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum upsideDownJungleWoodStairsFacingWest = _.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownJungleWoodStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum upsideDownJungleWoodStairsFacingSouth = _.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownJungleWoodStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs);
	public enum upsideDownJungleWoodStairsFacingNorth = _.UPSIDE_DOWN_JUNGLE_WOOD_STAIRS_FACING_NORTH.id;
	
	public enum jungleWoodStairs = [jungleWoodStairsFacingEast, jungleWoodStairsFacingWest, jungleWoodStairsFacingSouth, jungleWoodStairsFacingNorth, upsideDownJungleWoodStairsFacingEast, upsideDownJungleWoodStairsFacingWest, upsideDownJungleWoodStairsFacingSouth, upsideDownJungleWoodStairsFacingNorth];

	public alias AcaciaWoodStairsFacingEast = StairsBlock!(_.ACACIA_WOOD_STAIRS_FACING_EAST, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum acaciaWoodStairsFacingEast = _.ACACIA_WOOD_STAIRS_FACING_EAST.id;
	
	public alias AcaciaWoodStairsFacingWest = StairsBlock!(_.ACACIA_WOOD_STAIRS_FACING_WEST, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum acaciaWoodStairsFacingWest = _.ACACIA_WOOD_STAIRS_FACING_WEST.id;
	
	public alias AcaciaWoodStairsFacingSouth = StairsBlock!(_.ACACIA_WOOD_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum acaciaWoodStairsFacingSouth = _.ACACIA_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias AcaciaWoodStairsFacingNorth = StairsBlock!(_.ACACIA_WOOD_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum acaciaWoodStairsFacingNorth = _.ACACIA_WOOD_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownAcaciaWoodStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_EAST, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum upsideDownAcaciaWoodStairsFacingEast = _.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownAcaciaWoodStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_WEST, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum upsideDownAcaciaWoodStairsFacingWest = _.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownAcaciaWoodStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum upsideDownAcaciaWoodStairsFacingSouth = _.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownAcaciaWoodStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs);
	public enum upsideDownAcaciaWoodStairsFacingNorth = _.UPSIDE_DOWN_ACACIA_WOOD_STAIRS_FACING_NORTH.id;
	
	public enum acaciaWoodStairs = [acaciaWoodStairsFacingEast, acaciaWoodStairsFacingWest, acaciaWoodStairsFacingSouth, acaciaWoodStairsFacingNorth, upsideDownAcaciaWoodStairsFacingEast, upsideDownAcaciaWoodStairsFacingWest, upsideDownAcaciaWoodStairsFacingSouth, upsideDownAcaciaWoodStairsFacingNorth];

	public alias DarkOakWoodStairsFacingEast = StairsBlock!(_.DARK_OAK_WOOD_STAIRS_FACING_EAST, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum darkOakWoodStairsFacingEast = _.DARK_OAK_WOOD_STAIRS_FACING_EAST.id;
	
	public alias DarkOakWoodStairsFacingWest = StairsBlock!(_.DARK_OAK_WOOD_STAIRS_FACING_WEST, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum darkOakWoodStairsFacingWest = _.DARK_OAK_WOOD_STAIRS_FACING_WEST.id;
	
	public alias DarkOakWoodStairsFacingSouth = StairsBlock!(_.DARK_OAK_WOOD_STAIRS_FACING_SOUTH, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum darkOakWoodStairsFacingSouth = _.DARK_OAK_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias DarkOakWoodStairsFacingNorth = StairsBlock!(_.DARK_OAK_WOOD_STAIRS_FACING_NORTH, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum darkOakWoodStairsFacingNorth = _.DARK_OAK_WOOD_STAIRS_FACING_NORTH.id;
	
	public alias UpsideDownDarkOakWoodStairsFacingEast = StairsBlock!(_.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_EAST, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum upsideDownDarkOakWoodStairsFacingEast = _.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_EAST.id;
	
	public alias UpsideDownDarkOakWoodStairsFacingWest = StairsBlock!(_.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_WEST, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum upsideDownDarkOakWoodStairsFacingWest = _.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_WEST.id;
	
	public alias UpsideDownDarkOakWoodStairsFacingSouth = StairsBlock!(_.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_SOUTH, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum upsideDownDarkOakWoodStairsFacingSouth = _.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_SOUTH.id;
	
	public alias UpsideDownDarkOakWoodStairsFacingNorth = StairsBlock!(_.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_NORTH, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs);
	public enum upsideDownDarkOakWoodStairsFacingNorth = _.UPSIDE_DOWN_DARK_OAK_WOOD_STAIRS_FACING_NORTH.id;
	
	public enum darkOakWoodStairs = [darkOakWoodStairsFacingEast, darkOakWoodStairsFacingWest, darkOakWoodStairsFacingSouth, darkOakWoodStairsFacingNorth, upsideDownDarkOakWoodStairsFacingEast, upsideDownDarkOakWoodStairsFacingWest, upsideDownDarkOakWoodStairsFacingSouth, upsideDownDarkOakWoodStairsFacingNorth];

	public enum cobweb = _.COBWEB.id;

	public enum tnt = _.TNT.id;

	public alias Bookshelf = MineableBlock!(_.BOOKSHELF, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.book, 3, 3, Items.bookshelf));
	public enum bookshelf = _.BOOKSHELF.id;
	
	public alias Obsidian = MineableBlock!(_.OBSIDIAN, MiningTool(true, Tools.pickaxe, Tools.diamond), Drop(Items.obsidian, 1));
	public enum obsidian = _.OBSIDIAN.id;

	public alias GlowingObsidian = MineableBlock!(_.GLOWING_OBSIDIAN, MiningTool(true, Tools.pickaxe, Tools.diamond), Drop(Items.glowingObsidian, 1));
	public enum glowingObsidian = _.GLOWING_OBSIDIAN.id;
	
	public alias TorchFacingEast = MineableBlock!(_.TORCH_FACING_EAST, MiningTool.init, Drop(Items.torch, 1));
	public enum torchFacingEast = _.TORCH_FACING_EAST.id;
	
	public alias TorchFacingWest = MineableBlock!(_.TORCH_FACING_WEST, MiningTool.init, Drop(Items.torch, 1));
	public enum torchFacingWest = _.TORCH_FACING_WEST.id;
	
	public alias TorchFacingSouth = MineableBlock!(_.TORCH_FACING_SOUTH, MiningTool.init, Drop(Items.torch, 1));
	public enum torchFacingSouth = _.TORCH_FACING_SOUTH.id;
	
	public alias TorchFacingNorth = MineableBlock!(_.TORCH_FACING_NORTH, MiningTool.init, Drop(Items.torch, 1));
	public enum torchFacingNorth = _.TORCH_FACING_NORTH.id;
	
	public alias TorchFacingUp = MineableBlock!(_.TORCH_FACING_UP, MiningTool.init, Drop(Items.torch, 1));
	public enum torchFacingUp = _.TORCH_FACING_UP.id;

	public enum torch = [torchFacingUp, torchFacingEast, torchFacingWest, torchFacingSouth, torchFacingNorth];
	
	public enum redstoneTorchFacingEast = _.REDSTONE_TORCH_FACING_EAST.id;
	
	public enum redstoneTorchFacingWest = _.REDSTONE_TORCH_FACING_WEST.id;
	
	public enum redstoneTorchFacingSouth = _.REDSTONE_TORCH_FACING_SOUTH.id;
	
	public enum redstoneTorchFacingNorth = _.REDSTONE_TORCH_FACING_NORTH.id;
	
	public enum redstoneTorchFacingUp = _.REDSTONE_TORCH_FACING_UP.id;
	
	public enum activeRedstoneTorch = [redstoneTorchFacingUp, redstoneTorchFacingEast, redstoneTorchFacingWest, redstoneTorchFacingSouth, redstoneTorchFacingNorth];
	
	public enum inactiveRedstoneTorchFacingEast = _.INACTIVE_REDSTONE_TORCH_FACING_EAST.id;
	
	public enum inactiveRedstoneTorchFacingWest = _.INACTIVE_REDSTONE_TORCH_FACING_WEST.id;
	
	public enum inactiveRedstoneTorchFacingSouth = _.INACTIVE_REDSTONE_TORCH_FACING_SOUTH.id;
	
	public enum inactiveRedstoneTorchFacingNorth = _.INACTIVE_REDSTONE_TORCH_FACING_NORTH.id;
	
	public enum inactiveRedstoneTorchFacingUp = _.INACTIVE_REDSTONE_TORCH_FACING_UP.id;
	
	public enum inactiveRedstoneTorch = [inactiveRedstoneTorchFacingUp, inactiveRedstoneTorchFacingEast, inactiveRedstoneTorchFacingWest, inactiveRedstoneTorchFacingSouth, inactiveRedstoneTorchFacingNorth];

	public enum redstoneTorch = activeRedstoneTorch ~ inactiveRedstoneTorch;

	public enum fire = _.FIRE.id;

	public enum monsterSpawner = _.MONSTER_SPAWNER.id;
	
	public enum chestFacingNorth = _.CHEST_FACING_NORTH.id;
	
	public enum chestFacingSouth = _.CHEST_FACING_SOUTH.id;
	
	public enum chestFacingWest = _.CHEST_FACING_WEST.id;
	
	public enum chestFacingEast = _.CHEST_FACING_EAST.id;
	
	public enum chest = [chestFacingNorth, chestFacingSouth, chestFacingWest, chestFacingEast];
	
	public enum trappedChestFacingNorth = _.TRAPPED_CHEST_FACING_NORTH.id;
	
	public enum trappedChestFacingSouth = _.TRAPPED_CHEST_FACING_SOUTH.id;
	
	public enum trappedChestFacingWest = _.TRAPPED_CHEST_FACING_WEST.id;
	
	public enum trappedChestFacingEast = _.TRAPPED_CHEST_FACING_EAST.id;
	
	public enum trappedChest = [trappedChestFacingNorth, trappedChestFacingSouth, trappedChestFacingWest, trappedChestFacingEast];
	
	public enum enderChestFacingNorth = _.ENDER_CHEST_FACING_NORTH.id;
	
	public enum enderChestFacingSouth = _.ENDER_CHEST_FACING_SOUTH.id;
	
	public enum enderChestFacingWest = _.ENDER_CHEST_FACING_WEST.id;
	
	public enum enderChestFacingEast = _.ENDER_CHEST_FACING_EAST.id;
	
	public enum enderChest = [enderChestFacingNorth, enderChestFacingSouth, enderChestFacingWest, enderChestFacingEast];
	
	public enum redstoneWire0 = _.REDSTONE_WIRE_0.id;
	
	public enum redstoneWire1 = _.REDSTONE_WIRE_1.id;
	
	public enum redstoneWire2 = _.REDSTONE_WIRE_2.id;
	
	public enum redstoneWire3 = _.REDSTONE_WIRE_3.id;
	
	public enum redstoneWire4 = _.REDSTONE_WIRE_4.id;
	
	public enum redstoneWire5 = _.REDSTONE_WIRE_5.id;
	
	public enum redstoneWire6 = _.REDSTONE_WIRE_6.id;
	
	public enum redstoneWire7 = _.REDSTONE_WIRE_7.id;
	
	public enum redstoneWire8 = _.REDSTONE_WIRE_8.id;
	
	public enum redstoneWire9 = _.REDSTONE_WIRE_9.id;
	
	public enum redstoneWire10 = _.REDSTONE_WIRE_10.id;
	
	public enum redstoneWire11 = _.REDSTONE_WIRE_11.id;
	
	public enum redstoneWire12 = _.REDSTONE_WIRE_12.id;
	
	public enum redstoneWire13 = _.REDSTONE_WIRE_13.id;
	
	public enum redstoneWire14 = _.REDSTONE_WIRE_14.id;
	
	public enum redstoneWire15 = _.REDSTONE_WIRE_15.id;

	public alias CraftingTable = MineableBlock!(_.CRAFTING_TABLE, MiningTool(Tools.axe, Tools.all), Drop(Items.craftingTable, 1)); //TODO open window on click
	public enum craftingTable = _.CRAFTING_TABLE.id;
	
	public alias Seeds0 = CropBlock!(_.SEEDS_0, seeds1, [Drop(Items.seeds, 1)]);
	public enum seeds0 = _.SEEDS_0.id;
	
	public alias Seeds1 = CropBlock!(_.SEEDS_1, seeds2, [Drop(Items.seeds, 1)]);
	public enum seeds1 = _.SEEDS_1.id;
	
	public alias Seeds2 = CropBlock!(_.SEEDS_2, seeds3, [Drop(Items.seeds, 1)]);
	public enum seeds2 = _.SEEDS_2.id;
	
	public alias Seeds3 = CropBlock!(_.SEEDS_3, seeds4, [Drop(Items.seeds, 1)]);
	public enum seeds3 = _.SEEDS_3.id;
	
	public alias Seeds4 = CropBlock!(_.SEEDS_4, seeds5, [Drop(Items.seeds, 1)]);
	public enum seeds4 = _.SEEDS_4.id;
	
	public alias Seeds5 = CropBlock!(_.SEEDS_5, seeds6, [Drop(Items.seeds, 1)]);
	public enum seeds5 = _.SEEDS_5.id;
	
	public alias Seeds6 = CropBlock!(_.SEEDS_6, seeds7, [Drop(Items.seeds, 1)]);
	public enum seeds6 = _.SEEDS_6.id;

	public alias Seeds7 = CropBlock!(_.SEEDS_7, 0, [Drop(Items.seeds, 0, 3), Drop(Items.wheat, 1)]);
	public enum seeds7 = _.SEEDS_7.id;

	public enum seeds = [seeds0, seeds1, seeds2, seeds3, seeds4, seeds5, seeds6, seeds7];
	
	public alias Beetroot0 = ChanceCropBlock!(_.BEETROOT_0, beetroot1, [Drop(Items.beetrootSeeds, 1)], 2, 3);
	public enum beetroot0 = _.BEETROOT_0.id;
	
	public alias Beetroot1 = ChanceCropBlock!(_.BEETROOT_1, beetroot2, [Drop(Items.beetrootSeeds, 1)], 2, 3);
	public enum beetroot1 = _.BEETROOT_1.id;
	
	public alias Beetroot2 = ChanceCropBlock!(_.BEETROOT_2, beetroot3, [Drop(Items.beetrootSeeds, 1)], 2, 3);
	public enum beetroot2 = _.BEETROOT_2.id;
	
	public alias Beetroot3 = CropBlock!(_.BEETROOT_3, 0, [Drop(Items.beetroot, 1), Drop(Items.beetrootSeeds, 0, 3)]);
	public enum beetroot3 = _.BEETROOT_3.id;

	public enum beetroot = [beetroot0, beetroot1, beetroot2, beetroot3];
	
	public alias Carrot0 = CropBlock!(_.CARROT_0, carrot1, [Drop(Items.carrot, 1)]);
	public enum carrot0 = _.CARROT_0.id;
	
	public alias Carrot1 = CropBlock!(_.CARROT_1, carrot2, [Drop(Items.carrot, 1)]);
	public enum carrot1 = _.CARROT_1.id;
	
	public alias Carrot2 = CropBlock!(_.CARROT_2, carrot3, [Drop(Items.carrot, 1)]);
	public enum carrot2 = _.CARROT_2.id;
	
	public alias Carrot3 = CropBlock!(_.CARROT_3, carrot4, [Drop(Items.carrot, 1)]);
	public enum carrot3 = _.CARROT_3.id;
	
	public alias Carrot4 = CropBlock!(_.CARROT_4, carrot5, [Drop(Items.carrot, 1)]);
	public enum carrot4 = _.CARROT_4.id;
	
	public alias Carrot5 = CropBlock!(_.CARROT_5, carrot6, [Drop(Items.carrot, 1)]);
	public enum carrot5 = _.CARROT_5.id;
	
	public alias Carrot6 = CropBlock!(_.CARROT_6, carrot7, [Drop(Items.carrot, 1)]);
	public enum carrot6 = _.CARROT_6.id;
	
	public alias Carrot7 = CropBlock!(_.CARROT_7, 0, [Drop(Items.carrot, 1, 4)]);
	public enum carrot7 = _.CARROT_7.id;

	public enum carrot = [carrot0, carrot1, carrot2, carrot3, carrot4, carrot5, carrot6, carrot7];
	
	public alias Potato0 = CropBlock!(_.POTATO_0, potato1, [Drop(Items.potato, 1)]);
	public enum potato0 = _.POTATO_0.id;
	
	public alias Potato1 = CropBlock!(_.POTATO_1, potato2, [Drop(Items.potato, 1)]);
	public enum potato1 = _.POTATO_1.id;
	
	public alias Potato2 = CropBlock!(_.POTATO_2, potato3, [Drop(Items.potato, 1)]);
	public enum potato2 = _.POTATO_2.id;
	
	public alias Potato3 = CropBlock!(_.POTATO_3, potato4, [Drop(Items.potato, 1)]);
	public enum potato3 = _.POTATO_3.id;
	
	public alias Potato4 = CropBlock!(_.POTATO_4, potato5, [Drop(Items.potato, 1)]);
	public enum potato4 = _.POTATO_4.id;
	
	public alias Potato5 = CropBlock!(_.POTATO_5, potato6, [Drop(Items.potato, 1)]);
	public enum potato5 = _.POTATO_5.id;
	
	public alias Potato6 = CropBlock!(_.POTATO_6, potato7, [Drop(Items.potato, 1)]);
	public enum potato6 = _.POTATO_6.id;
	
	public alias Potato7 = CropBlock!(_.POTATO_7, 0, [Drop(Items.potato, 1, 4), Drop(Items.poisonousPotato, -49, 1)]);
	public enum potato7 = _.POTATO_7.id;

	public enum potato = [potato0, potato1, potato2, potato3, potato4, potato5, potato6, potato7];
	
	public alias MelonStem0 = StemBlock!(_.MELON_STEM_0, melonStem1, Items.melonSeeds);
	public enum melonStem0 = _.MELON_STEM_0.id;
	
	public alias MelonStem1 = StemBlock!(_.MELON_STEM_1, melonStem2, Items.melonSeeds);
	public enum melonStem1 = _.MELON_STEM_1.id;
	
	public alias MelonStem2 = StemBlock!(_.MELON_STEM_2, melonStem3, Items.melonSeeds);
	public enum melonStem2 = _.MELON_STEM_2.id;
	
	public alias MelonStem3 = StemBlock!(_.MELON_STEM_3, melonStem4, Items.melonSeeds);
	public enum melonStem3 = _.MELON_STEM_3.id;
	
	public alias MelonStem4 = StemBlock!(_.MELON_STEM_4, melonStem5, Items.melonSeeds);
	public enum melonStem4 = _.MELON_STEM_4.id;
	
	public alias MelonStem5 = StemBlock!(_.MELON_STEM_5, melonStem6, Items.melonSeeds);
	public enum melonStem5 = _.MELON_STEM_5.id;
	
	public alias MelonStem6 = StemBlock!(_.MELON_STEM_6, melonStem7, Items.melonSeeds);
	public enum melonStem6 = _.MELON_STEM_6.id;
	
	public alias MelonStem7 = StemBlock!(_.MELON_STEM_7, 0, Items.melonSeeds, melon);
	public enum melonStem7 = _.MELON_STEM_7.id;
	
	public alias PumpkinStem0 = StemBlock!(_.PUMPKIN_STEM_0, pumpkinStem1, Items.pumpkinSeeds);
	public enum pumpkinStem0 = _.PUMPKIN_STEM_0.id;
	
	public alias PumpkinStem1 = StemBlock!(_.PUMPKIN_STEM_1, pumpkinStem2, Items.pumpkinSeeds);
	public enum pumpkinStem1 = _.PUMPKIN_STEM_1.id;
	
	public alias PumpkinStem2 = StemBlock!(_.PUMPKIN_STEM_2, pumpkinStem3, Items.pumpkinSeeds);
	public enum pumpkinStem2 = _.PUMPKIN_STEM_2.id;
	
	public alias PumpkinStem3 = StemBlock!(_.PUMPKIN_STEM_3, pumpkinStem4, Items.pumpkinSeeds);
	public enum pumpkinStem3 = _.PUMPKIN_STEM_3.id;
	
	public alias PumpkinStem4 = StemBlock!(_.PUMPKIN_STEM_4, pumpkinStem5, Items.pumpkinSeeds);
	public enum pumpkinStem4 = _.PUMPKIN_STEM_4.id;
	
	public alias PumpkinStem5 = StemBlock!(_.PUMPKIN_STEM_5, pumpkinStem6, Items.pumpkinSeeds);
	public enum pumpkinStem5 = _.PUMPKIN_STEM_5.id;
	
	public alias PumpkinStem6 = StemBlock!(_.PUMPKIN_STEM_6, pumpkinStem7, Items.pumpkinSeeds);
	public enum pumpkinStem6 = _.PUMPKIN_STEM_6.id;
	
	public alias PumpkinStem7 = StemBlock!(_.PUMPKIN_STEM_7, 0, Items.pumpkinSeeds, pumpkin);
	public enum pumpkinStem7 = _.PUMPKIN_STEM_7.id;

	public alias SugarCanes0 = SugarCanesBlock!(_.SUGAR_CANES_0, sugarCanes1);
	public enum sugarCanes0 = _.SUGAR_CANES_0.id;
	
	public alias SugarCanes1 = SugarCanesBlock!(_.SUGAR_CANES_1, sugarCanes2);
	public enum sugarCanes1 = _.SUGAR_CANES_1.id;
	
	public alias SugarCanes2 = SugarCanesBlock!(_.SUGAR_CANES_2, sugarCanes3);
	public enum sugarCanes2 = _.SUGAR_CANES_2.id;
	
	public alias SugarCanes3 = SugarCanesBlock!(_.SUGAR_CANES_3, sugarCanes4);
	public enum sugarCanes3 = _.SUGAR_CANES_3.id;
	
	public alias SugarCanes4 = SugarCanesBlock!(_.SUGAR_CANES_4, sugarCanes5);
	public enum sugarCanes4 = _.SUGAR_CANES_4.id;
	
	public alias SugarCanes5 = SugarCanesBlock!(_.SUGAR_CANES_5, sugarCanes6);
	public enum sugarCanes5 = _.SUGAR_CANES_5.id;
	
	public alias SugarCanes6 = SugarCanesBlock!(_.SUGAR_CANES_6, sugarCanes7);
	public enum sugarCanes6 = _.SUGAR_CANES_6.id;
	
	public alias SugarCanes7 = SugarCanesBlock!(_.SUGAR_CANES_7, sugarCanes8);
	public enum sugarCanes7 = _.SUGAR_CANES_7.id;
	
	public alias SugarCanes8 = SugarCanesBlock!(_.SUGAR_CANES_8, sugarCanes9);
	public enum sugarCanes8 = _.SUGAR_CANES_8.id;
	
	public alias SugarCanes9 = SugarCanesBlock!(_.SUGAR_CANES_9, sugarCanes10);
	public enum sugarCanes9 = _.SUGAR_CANES_9.id;
	
	public alias SugarCanes10 = SugarCanesBlock!(_.SUGAR_CANES_10, sugarCanes11);
	public enum sugarCanes10 = _.SUGAR_CANES_10.id;
	
	public alias SugarCanes11 = SugarCanesBlock!(_.SUGAR_CANES_11, sugarCanes12);
	public enum sugarCanes11 = _.SUGAR_CANES_11.id;
	
	public alias SugarCanes12 = SugarCanesBlock!(_.SUGAR_CANES_12, sugarCanes13);
	public enum sugarCanes12 = _.SUGAR_CANES_12.id;
	
	public alias SugarCanes13 = SugarCanesBlock!(_.SUGAR_CANES_13, sugarCanes14);
	public enum sugarCanes13 = _.SUGAR_CANES_13.id;
	
	public alias SugarCanes14 = SugarCanesBlock!(_.SUGAR_CANES_14, sugarCanes15);
	public enum sugarCanes14 = _.SUGAR_CANES_14.id;
	
	public alias SugarCanes15 = SugarCanesBlock!(_.SUGAR_CANES_15, 0);
	public enum sugarCanes15 = _.SUGAR_CANES_15.id;

	public enum sugarCanes = [sugarCanes0, sugarCanes1, sugarCanes2, sugarCanes3, sugarCanes4, sugarCanes5, sugarCanes6, sugarCanes7, sugarCanes8, sugarCanes9, sugarCanes10, sugarCanes11, sugarCanes12, sugarCanes13, sugarCanes14, sugarCanes15];

	public alias NetherWart0 = NetherCrop!(_.NETHER_WART_0, netherWart1, Drop(Items.netherWart, 1));
	public enum netherWart0 = _.NETHER_WART_0.id;

	public alias NetherWart1 = NetherCrop!(_.NETHER_WART_1, netherWart2, Drop(Items.netherWart, 1));
	public enum netherWart1 = _.NETHER_WART_1.id;

	public alias NetherWart2 = NetherCrop!(_.NETHER_WART_2, netherWart3, Drop(Items.netherWart, 1));
	public enum netherWart2 = _.NETHER_WART_2.id;

	public alias NetherWart3 = NetherCrop!(_.NETHER_WART_3, 0, Drop(Items.netherWart, 1, 4, 0)); //TODO +1 with fortune
	public enum netherWart3 = _.NETHER_WART_3.id;
	
	public enum furnaceFacingNorth = _.FURNACE_FACING_NORTH.id;
	
	public enum furnaceFacingSouth = _.FURNACE_FACING_SOUTH.id;
	
	public enum furnaceFacingWest = _.FURNACE_FACING_WEST.id;
	
	public enum furnaceFacingEast = _.FURNACE_FACING_EAST.id;
	
	public enum furnace = [furnaceFacingNorth, furnaceFacingSouth, furnaceFacingWest, furnaceFacingEast];
	
	public enum burningFurnaceFacingNorth = _.BURNING_FURNACE_FACING_NORTH.id;
	
	public enum burningFurnaceFacingSouth = _.BURNING_FURNACE_FACING_SOUTH.id;
	
	public enum burningFurnaceFacingWest = _.BURNING_FURNACE_FACING_WEST.id;
	
	public enum burningFurnaceFacingEast = _.BURNING_FURNACE_FACING_EAST.id;
	
	public enum burningFurnace = [burningFurnaceFacingNorth, burningFurnaceFacingSouth, burningFurnaceFacingWest, burningFurnaceFacingEast];

	public alias Stonecutter = MineableBlock!(_.STONECUTTER, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stonecutter, 1));
	public enum stonecutter = _.STONECUTTER.id;
	
	public alias SignFacingSouth = SignBlock!(_.SIGN_FACING_SOUTH);
	public enum signFacingSouth = _.SIGN_FACING_SOUTH.id;
	
	public alias SignFacingSouthSouthwest = SignBlock!(_.SIGN_FACING_SOUTH_SOUTHWEST);
	public enum signFacingSouthSouthwest = _.SIGN_FACING_SOUTH_SOUTHWEST.id;
	
	public alias SignFacingSouthwest = SignBlock!(_.SIGN_FACING_SOUTHWEST);
	public enum signFacingSouthwest = _.SIGN_FACING_SOUTHWEST.id;
	
	public alias SignFacingWestWestsouth = SignBlock!(_.SIGN_FACING_WEST_WESTSOUTH);
	public enum signFacingWestWestsouth = _.SIGN_FACING_WEST_WESTSOUTH.id;
	
	public alias SignFacingWest = SignBlock!(_.SIGN_FACING_WEST);
	public enum signFacingWest = _.SIGN_FACING_WEST.id;
	
	public alias SignFacingWestNorthwest = SignBlock!(_.SIGN_FACING_WEST_NORTHWEST);
	public enum signFacingWestNorthwest = _.SIGN_FACING_WEST_NORTHWEST.id;
	
	public alias SignFacingNorthwest = SignBlock!(_.SIGN_FACING_NORTHWEST);
	public enum signFacingNorthwest = _.SIGN_FACING_NORTHWEST.id;
	
	public alias SignFacingNorthNorthwest = SignBlock!(_.SIGN_FACING_NORTH_NORTHWEST);
	public enum signFacingNorthNorthwest = _.SIGN_FACING_NORTH_NORTHWEST.id;
	
	public alias SignFacingNorth = SignBlock!(_.SIGN_FACING_NORTH);
	public enum signFacingNorth = _.SIGN_FACING_NORTH.id;
	
	public alias SignFacingNorthNortheast = SignBlock!(_.SIGN_FACING_NORTH_NORTHEAST);
	public enum signFacingNorthNortheast = _.SIGN_FACING_NORTH_NORTHEAST.id;
	
	public alias SignFacingNortheast = SignBlock!(_.SIGN_FACING_NORTHEAST);
	public enum signFacingNortheast = _.SIGN_FACING_NORTHEAST.id;
	
	public alias SignFacingEastNortheast = SignBlock!(_.SIGN_FACING_EAST_NORTHEAST);
	public enum signFacingEastNortheast = _.SIGN_FACING_EAST_NORTHEAST.id;
	
	public alias SignFacingEast = SignBlock!(_.SIGN_FACING_EAST);
	public enum signFacingEast = _.SIGN_FACING_EAST.id;
	
	public alias SignFacingEastSoutheast = SignBlock!(_.SIGN_FACING_EAST_SOUTHEAST);
	public enum signFacingEastSoutheast = _.SIGN_FACING_EAST_SOUTHEAST.id;
	
	public alias SignFacingSoutheast = SignBlock!(_.SIGN_FACING_SOUTHEAST);
	public enum signFacingSoutheast = _.SIGN_FACING_SOUTHEAST.id;
	
	public alias SignFacingSouthSoutheast = SignBlock!(_.SIGN_FACING_SOUTH_SOUTHEAST);
	public enum signFacingSouthSoutheast = _.SIGN_FACING_SOUTH_SOUTHEAST.id;

	public enum sign = [signFacingSouth, signFacingSouthSouthwest, signFacingSouthwest, signFacingWestWestsouth, signFacingWest, signFacingWestNorthwest, signFacingNorthwest, signFacingNorthNorthwest, signFacingNorth, signFacingNorthNortheast, signFacingEastNortheast, signFacingEast, signFacingEastSoutheast, signFacingSoutheast, signFacingSouthSoutheast];
	
	public alias WallSignFacingNorth = WallSignBlock!(_.WALL_SIGN_FACING_NORTH, Facing.north);
	public enum wallSignFacingNorth = _.WALL_SIGN_FACING_NORTH.id;
	
	public alias WallSignFacingSouth = WallSignBlock!(_.WALL_SIGN_FACING_SOUTH, Facing.south);
	public enum wallSignFacingSouth = _.WALL_SIGN_FACING_SOUTH.id;
	
	public alias WallSignFacingWest = WallSignBlock!(_.WALL_SIGN_FACING_WEST, Facing.west);
	public enum wallSignFacingWest = _.WALL_SIGN_FACING_WEST.id;
	
	public alias WallSignFacingEast = WallSignBlock!(_.WALL_SIGN_FACING_EAST, Facing.east);
	public enum wallSignFacingEast = _.WALL_SIGN_FACING_EAST.id;

	public enum wallSign = [wallSignFacingNorth, wallSignFacingSouth, wallSignFacingWest, wallSignFacingEast];
	
	public enum lowerOakWoodDoorFacingEast = _.LOWER_OAK_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOakWoodDoorFacingSouth = _.LOWER_OAK_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOakWoodDoorFacingWest = _.LOWER_OAK_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOakWoodDoorFacingNorth = _.LOWER_OAK_WOOD_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedOakWoodDoorFacingEast = _.LOWER_OPENED_OAK_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedOakWoodDoorFacingSouth = _.LOWER_OPENED_OAK_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedOakWoodDoorFacingWest = _.LOWER_OPENED_OAK_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedOakWoodDoorFacingNorth = _.LOWER_OPENED_OAK_WOOD_DOOR_FACING_NORTH.id;
	
	public enum upperOakWoodDoorHingeLeft = _.UPPER_OAK_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperOakWoodDoorHingeRight = _.UPPER_OAK_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredOakWoodDoorHingeLeft = _.UPPER_POWERED_OAK_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredOakWoodDoorHingeRight = _.UPPER_POWERED_OAK_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum lowerOakWoodDoor = [lowerOakWoodDoorFacingEast, lowerOakWoodDoorFacingSouth, lowerOakWoodDoorFacingWest, lowerOakWoodDoorFacingNorth];
	
	public enum upperOakWoodDoor = [upperOakWoodDoorHingeLeft, upperOakWoodDoorHingeRight, upperPoweredOakWoodDoorHingeLeft, upperPoweredOakWoodDoorHingeRight];
	
	public enum oakWoodDoor = lowerOakWoodDoor ~ upperOakWoodDoor;
	
	public enum lowerSpruceWoodDoorFacingEast = _.LOWER_SPRUCE_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerSpruceWoodDoorFacingSouth = _.LOWER_SPRUCE_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerSpruceWoodDoorFacingWest = _.LOWER_SPRUCE_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerSpruceWoodDoorFacingNorth = _.LOWER_SPRUCE_WOOD_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedSpruceWoodDoorFacingEast = _.LOWER_OPENED_SPRUCE_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedSpruceWoodDoorFacingSouth = _.LOWER_OPENED_SPRUCE_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedSpruceWoodDoorFacingWest = _.LOWER_OPENED_SPRUCE_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedSpruceWoodDoorFacingNorth = _.LOWER_OPENED_SPRUCE_WOOD_DOOR_FACING_NORTH.id;
	
	public enum upperSpruceWoodDoorHingeLeft = _.UPPER_SPRUCE_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperSpruceWoodDoorHingeRight = _.UPPER_SPRUCE_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredSpruceWoodDoorHingeLeft = _.UPPER_POWERED_SPRUCE_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredSpruceWoodDoorHingeRight = _.UPPER_POWERED_SPRUCE_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum lowerSpruceWoodDoor = [lowerSpruceWoodDoorFacingEast, lowerSpruceWoodDoorFacingSouth, lowerSpruceWoodDoorFacingWest, lowerSpruceWoodDoorFacingNorth];
	
	public enum upperSpruceWoodDoor = [upperSpruceWoodDoorHingeLeft, upperSpruceWoodDoorHingeRight, upperPoweredSpruceWoodDoorHingeLeft, upperPoweredSpruceWoodDoorHingeRight];
	
	public enum spruceWoodDoor = lowerSpruceWoodDoor ~ upperSpruceWoodDoor;

	public enum lowerBirchWoodDoorFacingEast = _.LOWER_BIRCH_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerBirchWoodDoorFacingSouth = _.LOWER_BIRCH_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerBirchWoodDoorFacingWest = _.LOWER_BIRCH_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerBirchWoodDoorFacingNorth = _.LOWER_BIRCH_WOOD_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedBirchWoodDoorFacingEast = _.LOWER_OPENED_BIRCH_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedBirchWoodDoorFacingSouth = _.LOWER_OPENED_BIRCH_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedBirchWoodDoorFacingWest = _.LOWER_OPENED_BIRCH_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedBirchWoodDoorFacingNorth = _.LOWER_OPENED_BIRCH_WOOD_DOOR_FACING_NORTH.id;
	
	public enum upperBirchWoodDoorHingeLeft = _.UPPER_BIRCH_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperBirchWoodDoorHingeRight = _.UPPER_BIRCH_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredBirchWoodDoorHingeLeft = _.UPPER_POWERED_BIRCH_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredBirchWoodDoorHingeRight = _.UPPER_POWERED_BIRCH_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum lowerBirchWoodDoor = [lowerBirchWoodDoorFacingEast, lowerBirchWoodDoorFacingSouth, lowerBirchWoodDoorFacingWest, lowerBirchWoodDoorFacingNorth];
	
	public enum upperBirchWoodDoor = [upperBirchWoodDoorHingeLeft, upperBirchWoodDoorHingeRight, upperPoweredBirchWoodDoorHingeLeft, upperPoweredBirchWoodDoorHingeRight];
	
	public enum birchWoodDoor = lowerBirchWoodDoor ~ upperBirchWoodDoor;	
	
	public enum lowerJungleWoodDoorFacingEast = _.LOWER_JUNGLE_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerJungleWoodDoorFacingSouth = _.LOWER_JUNGLE_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerJungleWoodDoorFacingWest = _.LOWER_JUNGLE_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerJungleWoodDoorFacingNorth = _.LOWER_JUNGLE_WOOD_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedJungleWoodDoorFacingEast = _.LOWER_OPENED_JUNGLE_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedJungleWoodDoorFacingSouth = _.LOWER_OPENED_JUNGLE_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedJungleWoodDoorFacingWest = _.LOWER_OPENED_JUNGLE_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedJungleWoodDoorFacingNorth = _.LOWER_OPENED_JUNGLE_WOOD_DOOR_FACING_NORTH.id;
	
	public enum upperJungleWoodDoorHingeLeft = _.UPPER_JUNGLE_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperJungleWoodDoorHingeRight = _.UPPER_JUNGLE_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredJungleWoodDoorHingeLeft = _.UPPER_POWERED_JUNGLE_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredJungleWoodDoorHingeRight = _.UPPER_POWERED_JUNGLE_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum lowerJungleWoodDoor = [lowerJungleWoodDoorFacingEast, lowerJungleWoodDoorFacingSouth, lowerJungleWoodDoorFacingWest, lowerJungleWoodDoorFacingNorth];
	
	public enum upperJungleWoodDoor = [upperJungleWoodDoorHingeLeft, upperJungleWoodDoorHingeRight, upperPoweredJungleWoodDoorHingeLeft, upperPoweredJungleWoodDoorHingeRight];
	
	public enum jungleWoodDoor = lowerJungleWoodDoor ~ upperJungleWoodDoor;
	
	public enum lowerAcaciaWoodDoorFacingEast = _.LOWER_ACACIA_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerAcaciaWoodDoorFacingSouth = _.LOWER_ACACIA_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerAcaciaWoodDoorFacingWest = _.LOWER_ACACIA_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerAcaciaWoodDoorFacingNorth = _.LOWER_ACACIA_WOOD_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedAcaciaWoodDoorFacingEast = _.LOWER_OPENED_ACACIA_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedAcaciaWoodDoorFacingSouth = _.LOWER_OPENED_ACACIA_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedAcaciaWoodDoorFacingWest = _.LOWER_OPENED_ACACIA_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedAcaciaWoodDoorFacingNorth = _.LOWER_OPENED_ACACIA_WOOD_DOOR_FACING_NORTH.id;
	
	public enum upperAcaciaWoodDoorHingeLeft = _.UPPER_ACACIA_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperAcaciaWoodDoorHingeRight = _.UPPER_ACACIA_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredAcaciaWoodDoorHingeLeft = _.UPPER_POWERED_ACACIA_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredAcaciaWoodDoorHingeRight = _.UPPER_POWERED_ACACIA_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum lowerAcaciaWoodDoor = [lowerAcaciaWoodDoorFacingEast, lowerAcaciaWoodDoorFacingSouth, lowerAcaciaWoodDoorFacingWest, lowerAcaciaWoodDoorFacingNorth];
	
	public enum upperAcaciaWoodDoor = [upperAcaciaWoodDoorHingeLeft, upperAcaciaWoodDoorHingeRight, upperPoweredAcaciaWoodDoorHingeLeft, upperPoweredAcaciaWoodDoorHingeRight];
	
	public enum acaciaWoodDoor = lowerAcaciaWoodDoor ~ upperAcaciaWoodDoor;
	
	public enum lowerDarkOakWoodDoorFacingEast = _.LOWER_DARK_OAK_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerDarkOakWoodDoorFacingSouth = _.LOWER_DARK_OAK_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerDarkOakWoodDoorFacingWest = _.LOWER_DARK_OAK_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerDarkOakWoodDoorFacingNorth = _.LOWER_DARK_OAK_WOOD_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedDarkOakWoodDoorFacingEast = _.LOWER_OPENED_DARK_OAK_WOOD_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedDarkOakWoodDoorFacingSouth = _.LOWER_OPENED_DARK_OAK_WOOD_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedDarkOakWoodDoorFacingWest = _.LOWER_OPENED_DARK_OAK_WOOD_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedDarkOakWoodDoorFacingNorth = _.LOWER_OPENED_DARK_OAK_WOOD_DOOR_FACING_NORTH.id;
	
	public enum upperDarkOakWoodDoorHingeLeft = _.UPPER_DARK_OAK_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperDarkOakWoodDoorHingeRight = _.UPPER_DARK_OAK_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredDarkOakWoodDoorHingeLeft = _.UPPER_POWERED_DARK_OAK_WOOD_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredDarkOakWoodDoorHingeRight = _.UPPER_POWERED_DARK_OAK_WOOD_DOOR_HINGE_RIGHT.id;
	
	public enum lowerDarkOakWoodDoor = [lowerDarkOakWoodDoorFacingEast, lowerDarkOakWoodDoorFacingSouth, lowerDarkOakWoodDoorFacingWest, lowerDarkOakWoodDoorFacingNorth];
	
	public enum upperDarkOakWoodDoor = [upperDarkOakWoodDoorHingeLeft, upperDarkOakWoodDoorHingeRight, upperPoweredDarkOakWoodDoorHingeLeft, upperPoweredDarkOakWoodDoorHingeRight];
	
	public enum darkOakWoodDoor = lowerDarkOakWoodDoor ~ upperDarkOakWoodDoor;

	public enum woodDoor = oakWoodDoor ~ spruceWoodDoor ~ birchWoodDoor ~ jungleWoodDoor ~ acaciaWoodDoor ~ darkOakWoodDoor;
	
	public enum lowerIronDoorFacingEast = _.LOWER_IRON_DOOR_FACING_EAST.id;
	
	public enum lowerIronDoorFacingSouth = _.LOWER_IRON_DOOR_FACING_SOUTH.id;
	
	public enum lowerIronDoorFacingWest = _.LOWER_IRON_DOOR_FACING_WEST.id;
	
	public enum lowerIronDoorFacingNorth = _.LOWER_IRON_DOOR_FACING_NORTH.id;
	
	public enum lowerOpenedIronDoorFacingEast = _.LOWER_OPENED_IRON_DOOR_FACING_EAST.id;
	
	public enum lowerOpenedIronDoorFacingSouth = _.LOWER_OPENED_IRON_DOOR_FACING_SOUTH.id;
	
	public enum lowerOpenedIronDoorFacingWest = _.LOWER_OPENED_IRON_DOOR_FACING_WEST.id;
	
	public enum lowerOpenedIronDoorFacingNorth = _.LOWER_OPENED_IRON_DOOR_FACING_NORTH.id;
	
	public enum upperIronDoorHingeLeft = _.UPPER_IRON_DOOR_HINGE_LEFT.id;
	
	public enum upperIronDoorHingeRight = _.UPPER_IRON_DOOR_HINGE_RIGHT.id;
	
	public enum upperPoweredIronDoorHingeLeft = _.UPPER_POWERED_IRON_DOOR_HINGE_LEFT.id;
	
	public enum upperPoweredIronDoorHingeRight = _.UPPER_POWERED_IRON_DOOR_HINGE_RIGHT.id;
	
	public enum lowerIronDoor = [lowerIronDoorFacingEast, lowerIronDoorFacingSouth, lowerIronDoorFacingWest, lowerIronDoorFacingNorth];
	
	public enum upperIronDoor = [upperIronDoorHingeLeft, upperIronDoorHingeRight, upperPoweredIronDoorHingeLeft, upperPoweredIronDoorHingeRight];
	
	public enum ironDoor = lowerIronDoor ~ upperIronDoor;

	public enum door = woodDoor ~ ironDoor;
	
	public enum ladderFacingNorth = _.LADDER_FACING_NORTH.id;
	
	public enum ladderFacingSouth = _.LADDER_FACING_SOUTH.id;
	
	public enum ladderFacingWest = _.LADDER_FACING_WEST.id;
	
	public enum ladderFacingEast = _.LADDER_FACING_EAST.id;

	public enum ladder = [ladderFacingNorth, ladderFacingSouth, ladderFacingWest, ladderFacingEast];

	public enum leverBottomPointingEast = _.LEVER_BOTTOM_POINTING_EAST.id;
	
	public enum leverFacingEast = _.LEVER_FACING_EAST.id;
	
	public enum leverFacingWest = _.LEVER_FACING_WEST.id;
	
	public enum leverFacingSouth = _.LEVER_FACING_SOUTH.id;
	
	public enum leverFacingNorth = _.LEVER_FACING_NORTH.id;
	
	public enum leverTopPointingSouth = _.LEVER_TOP_POINTING_SOUTH.id;
	
	public enum leverTopPointingEast = _.LEVER_TOP_POINTING_EAST.id;
	
	public enum leverBottomPointingSouth = _.LEVER_BOTTOM_POINTING_SOUTH.id;
	
	public enum unpoweredLever = [leverBottomPointingEast, leverFacingEast, leverFacingWest, leverFacingSouth, leverFacingNorth, leverTopPointingSouth, leverTopPointingEast, leverBottomPointingSouth];

	public enum poweredLeverBottomPointingEast = _.POWERED_LEVER_BOTTOM_POINTING_EAST.id;
	
	public enum poweredLeverFacingEast = _.POWERED_LEVER_FACING_EAST.id;
	
	public enum poweredLeverFacingWest = _.POWERED_LEVER_FACING_WEST.id;
	
	public enum poweredLeverFacingSouth = _.POWERED_LEVER_FACING_SOUTH.id;
	
	public enum poweredLeverFacingNorth = _.POWERED_LEVER_FACING_NORTH.id;
	
	public enum poweredLeverTopPointingSouth = _.POWERED_LEVER_TOP_POINTING_SOUTH.id;
	
	public enum poweredLeverTopPointingEast = _.POWERED_LEVER_TOP_POINTING_EAST.id;
	
	public enum poweredLeverBottomPointingSouth = _.POWERED_LEVER_BOTTOM_POINTING_SOUTH.id;
	
	public enum poweredLever = [poweredLeverBottomPointingEast, poweredLeverFacingEast, poweredLeverFacingWest, poweredLeverFacingSouth, poweredLeverFacingNorth, poweredLeverTopPointingSouth, poweredLeverTopPointingEast, poweredLeverBottomPointingSouth];

	public enum lever = unpoweredLever ~ poweredLever;
	
	public enum unpoweredStonePressurePlate = _.STONE_PRESSURE_PLATE.id;

	public enum poweredStonePressurePlate = _.POWERED_STONE_PRESSURE_PLATE.id;
	
	public enum stonePressurePlate = [unpoweredStonePressurePlate, poweredStonePressurePlate];
	
	public enum unpoweredWoodenPressurePlate = _.WOODEN_PRESSURE_PLATE.id;
	
	public enum poweredWoodenPressurePlate = _.POWERED_WOODEN_PRESSURE_PLATE.id;
	
	public enum woodenPressurePlate = [unpoweredWoodenPressurePlate, poweredWoodenPressurePlate];

	public enum heavyWeightedPressurePlate0 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_0.id;
	
	public enum heavyWeightedPressurePlate1 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_1.id;
	
	public enum heavyWeightedPressurePlate2 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_2.id;
	
	public enum heavyWeightedPressurePlate3 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_3.id;
	
	public enum heavyWeightedPressurePlate4 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_4.id;
	
	public enum heavyWeightedPressurePlate5 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_5.id;
	
	public enum heavyWeightedPressurePlate6 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_6.id;
	
	public enum heavyWeightedPressurePlate7 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_7.id;
	
	public enum heavyWeightedPressurePlate8 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_8.id;
	
	public enum heavyWeightedPressurePlate9 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_9.id;
	
	public enum heavyWeightedPressurePlate10 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_10.id;
	
	public enum heavyWeightedPressurePlate11 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_11.id;
	
	public enum heavyWeightedPressurePlate12 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_12.id;
	
	public enum heavyWeightedPressurePlate13 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_13.id;
	
	public enum heavyWeightedPressurePlate14 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_14.id;
	
	public enum heavyWeightedPressurePlate15 = _.HEAVY_WEIGHTED_PRESSURE_PLATE_15.id;
	
	public enum heavyWeightedPressurePlate = [heavyWeightedPressurePlate0, heavyWeightedPressurePlate1, heavyWeightedPressurePlate2, heavyWeightedPressurePlate3, heavyWeightedPressurePlate4, heavyWeightedPressurePlate5, heavyWeightedPressurePlate6, heavyWeightedPressurePlate7, heavyWeightedPressurePlate8, heavyWeightedPressurePlate9, heavyWeightedPressurePlate10, heavyWeightedPressurePlate11, heavyWeightedPressurePlate12, heavyWeightedPressurePlate13, heavyWeightedPressurePlate14, heavyWeightedPressurePlate15];

	public enum lightWeightedPressurePlate0 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_0.id;
	
	public enum lightWeightedPressurePlate1 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_1.id;
	
	public enum lightWeightedPressurePlate2 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_2.id;
	
	public enum lightWeightedPressurePlate3 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_3.id;
	
	public enum lightWeightedPressurePlate4 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_4.id;
	
	public enum lightWeightedPressurePlate5 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_5.id;
	
	public enum lightWeightedPressurePlate6 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_6.id;
	
	public enum lightWeightedPressurePlate7 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_7.id;
	
	public enum lightWeightedPressurePlate8 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_8.id;
	
	public enum lightWeightedPressurePlate9 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_9.id;
	
	public enum lightWeightedPressurePlate10 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_10.id;
	
	public enum lightWeightedPressurePlate11 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_11.id;
	
	public enum lightWeightedPressurePlate12 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_12.id;
	
	public enum lightWeightedPressurePlate13 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_13.id;
	
	public enum lightWeightedPressurePlate14 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_14.id;
	
	public enum lightWeightedPressurePlate15 = _.LIGHT_WEIGHTED_PRESSURE_PLATE_15.id;
	
	public enum lightWeightedPressurePlate = [lightWeightedPressurePlate0, lightWeightedPressurePlate1, lightWeightedPressurePlate2, lightWeightedPressurePlate3, lightWeightedPressurePlate4, lightWeightedPressurePlate5, lightWeightedPressurePlate6, lightWeightedPressurePlate7, lightWeightedPressurePlate8, lightWeightedPressurePlate9, lightWeightedPressurePlate10, lightWeightedPressurePlate11, lightWeightedPressurePlate12, lightWeightedPressurePlate13, lightWeightedPressurePlate14, lightWeightedPressurePlate15];

	public enum weightedPressurePlate = heavyWeightedPressurePlate ~ lightWeightedPressurePlate;

	public enum pressurePlate = stonePressurePlate ~ woodenPressurePlate ~ weightedPressurePlate;

	public enum stoneButtonFacingDown = _.STONE_BUTTON_FACING_DOWN.id;
	
	public enum stoneButtonFacingEast = _.STONE_BUTTON_FACING_EAST.id;
	
	public enum stoneButtonFacingWest = _.STONE_BUTTON_FACING_WEST.id;
	
	public enum stoneButtonFacingSouth = _.STONE_BUTTON_FACING_SOUTH.id;
	
	public enum stoneButtonFacingNorth = _.STONE_BUTTON_FACING_NORTH.id;
	
	public enum stoneButtonFacingUp = _.STONE_BUTTON_FACING_UP.id;
	
	public enum unpoweredStoneButton = [stoneButtonFacingDown, stoneButtonFacingEast, stoneButtonFacingWest, stoneButtonFacingSouth, stoneButtonFacingNorth, stoneButtonFacingUp];
	
	public enum poweredStoneButtonFacingDown = _.POWERED_STONE_BUTTON_FACING_DOWN.id;
	
	public enum poweredStoneButtonFacingEast = _.POWERED_STONE_BUTTON_FACING_EAST.id;
	
	public enum poweredStoneButtonFacingWest = _.POWERED_STONE_BUTTON_FACING_WEST.id;
	
	public enum poweredStoneButtonFacingSouth = _.POWERED_STONE_BUTTON_FACING_SOUTH.id;
	
	public enum poweredStoneButtonFacingNorth = _.POWERED_STONE_BUTTON_FACING_NORTH.id;
	
	public enum poweredStoneButtonFacingUp = _.POWERED_STONE_BUTTON_FACING_UP.id;
	
	public enum poweredStoneButton = [poweredStoneButtonFacingDown, poweredStoneButtonFacingEast, poweredStoneButtonFacingWest, poweredStoneButtonFacingSouth, poweredStoneButtonFacingNorth, poweredStoneButtonFacingUp];

	public enum stoneButton = unpoweredStoneButton ~ poweredStoneButton;

	public enum woodenButtonFacingDown = _.WOODEN_BUTTON_FACING_DOWN.id;
	
	public enum woodenButtonFacingEast = _.WOODEN_BUTTON_FACING_EAST.id;
	
	public enum woodenButtonFacingWest = _.WOODEN_BUTTON_FACING_WEST.id;
	
	public enum woodenButtonFacingSouth = _.WOODEN_BUTTON_FACING_SOUTH.id;
	
	public enum woodenButtonFacingNorth = _.WOODEN_BUTTON_FACING_NORTH.id;
	
	public enum woodenButtonFacingUp = _.WOODEN_BUTTON_FACING_UP.id;
	
	public enum unpoweredWoodenButton = [woodenButtonFacingDown, woodenButtonFacingEast, woodenButtonFacingWest, woodenButtonFacingSouth, woodenButtonFacingNorth, woodenButtonFacingUp];
	
	public enum poweredWoodenButtonFacingDown = _.POWERED_WOODEN_BUTTON_FACING_DOWN.id;
	
	public enum poweredWoodenButtonFacingEast = _.POWERED_WOODEN_BUTTON_FACING_EAST.id;
	
	public enum poweredWoodenButtonFacingWest = _.POWERED_WOODEN_BUTTON_FACING_WEST.id;
	
	public enum poweredWoodenButtonFacingSouth = _.POWERED_WOODEN_BUTTON_FACING_SOUTH.id;
	
	public enum poweredWoodenButtonFacingNorth = _.POWERED_WOODEN_BUTTON_FACING_NORTH.id;
	
	public enum poweredWoodenButtonFacingUp = _.POWERED_WOODEN_BUTTON_FACING_UP.id;
	
	public enum poweredWoodenButton = [poweredWoodenButtonFacingDown, poweredWoodenButtonFacingEast, poweredWoodenButtonFacingWest, poweredWoodenButtonFacingSouth, poweredWoodenButtonFacingNorth, poweredWoodenButtonFacingUp];

	public enum woodenButton = unpoweredWoodenButton ~ poweredWoodenButton;

	public enum button = stoneButton ~ woodenButton;

	public alias SnowLayer0 = GravityBlock!(_.SNOW_LAYER_0, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 2));
	public enum snowLayer0 = _.SNOW_LAYER_0.id;
	
	public alias SnowLayer1 = GravityBlock!(_.SNOW_LAYER_1, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 3));
	public enum snowLayer1 = _.SNOW_LAYER_1.id;
	
	public alias SnowLayer2 = GravityBlock!(_.SNOW_LAYER_2, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 4));
	public enum snowLayer2 = _.SNOW_LAYER_2.id;
	
	public alias SnowLayer3 = GravityBlock!(_.SNOW_LAYER_3, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 5));
	public enum snowLayer3 = _.SNOW_LAYER_3.id;
	
	public alias SnowLayer4 = GravityBlock!(_.SNOW_LAYER_4, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 6));
	public enum snowLayer4 = _.SNOW_LAYER_4.id;
	
	public alias SnowLayer5 = GravityBlock!(_.SNOW_LAYER_5, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 7));
	public enum snowLayer5 = _.SNOW_LAYER_5.id;
	
	public alias SnowLayer6 = GravityBlock!(_.SNOW_LAYER_6, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 8));
	public enum snowLayer6 = _.SNOW_LAYER_6.id;
	
	public alias SnowLayer7 = GravityBlock!(_.SNOW_LAYER_7, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 9));
	public enum snowLayer7 = _.SNOW_LAYER_7.id;

	public enum snowLayer = [snowLayer0, snowLayer1, snowLayer2, snowLayer3, snowLayer4, snowLayer5, snowLayer6, snowLayer7];

	public alias Snow = MineableBlock!(_.SNOW, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 4, 4, Items.snowBlock));
	public enum snow = _.SNOW.id;

	public enum ice = _.ICE.id;

	public enum packedIce = _.PACKED_ICE.id;

	public enum frostedIce0 = _.FROSTED_ICE_0.id;

	public enum frostedIce1 = _.FROSTED_ICE_1.id;

	public enum frostedIce2 = _.FROSTED_ICE_2.id;

	public enum frostedIce3 = _.FROSTED_ICE_3.id;

	public enum frostedIce = [frostedIce0, frostedIce1, frostedIce2, frostedIce3];
	
	public alias Cactus0 = CactusBlock!(_.CACTUS_0, cactus1);
	public enum cactus0 = _.CACTUS_0.id;
	
	public alias Cactus1 = CactusBlock!(_.CACTUS_1, cactus2);
	public enum cactus1 = _.CACTUS_1.id;
	
	public alias Cactus2 = CactusBlock!(_.CACTUS_2, cactus3);
	public enum cactus2 = _.CACTUS_2.id;
	
	public alias Cactus3 = CactusBlock!(_.CACTUS_3, cactus4);
	public enum cactus3 = _.CACTUS_3.id;
	
	public alias Cactus4 = CactusBlock!(_.CACTUS_4, cactus5);
	public enum cactus4 = _.CACTUS_4.id;
	
	public alias Cactus5 = CactusBlock!(_.CACTUS_5, cactus6);
	public enum cactus5 = _.CACTUS_5.id;
	
	public alias Cactus6 = CactusBlock!(_.CACTUS_6, cactus7);
	public enum cactus6 = _.CACTUS_6.id;
	
	public alias Cactus7 = CactusBlock!(_.CACTUS_7, cactus8);
	public enum cactus7 = _.CACTUS_7.id;
	
	public alias Cactus8 = CactusBlock!(_.CACTUS_8, cactus9);
	public enum cactus8 = _.CACTUS_8.id;
	
	public alias Cactus9 = CactusBlock!(_.CACTUS_9, cactus10);
	public enum cactus9 = _.CACTUS_9.id;
	
	public alias Cactus10 = CactusBlock!(_.CACTUS_10, cactus11);
	public enum cactus10 = _.CACTUS_10.id;
	
	public alias Cactus11 = CactusBlock!(_.CACTUS_11, cactus12);
	public enum cactus11 = _.CACTUS_11.id;
	
	public alias Cactus12 = CactusBlock!(_.CACTUS_12, cactus13);
	public enum cactus12 = _.CACTUS_12.id;
	
	public alias Cactus13 = CactusBlock!(_.CACTUS_13, cactus14);
	public enum cactus13 = _.CACTUS_13.id;
	
	public alias Cactus14 = CactusBlock!(_.CACTUS_14, cactus15);
	public enum cactus14 = _.CACTUS_14.id;
	
	public alias Cactus15 = CactusBlock!(_.CACTUS_15, 0);
	public enum cactus15 = _.CACTUS_15.id;

	public enum cactus = [cactus0, cactus1, cactus2, cactus3, cactus4, cactus5, cactus6, cactus7, cactus8, cactus9, cactus10, cactus11, cactus12, cactus13, cactus14, cactus15];

	public alias Clay = MineableBlock!(_.CLAY, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.clay, 4, 4, Items.clayBlock));
	public enum clay = _.CLAY.id;

	public enum jukebox = _.JUKEBOX.id;

	public alias HardenedClay = MineableBlock!(_.HARDENED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.hardenedClay, 1));
	public enum hardenedClay = _.HARDENED_CLAY.id;
	
	public alias WhiteStainedClay = MineableBlock!(_.WHITE_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.whiteStainedClay, 1));
	public enum whiteStainedClay = _.WHITE_STAINED_CLAY.id;
	
	public alias OrangeStainedClay = MineableBlock!(_.ORANGE_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.orangeStainedClay, 1));
	public enum orangeStainedClay = _.ORANGE_STAINED_CLAY.id;
	
	public alias MagentaStainedClay = MineableBlock!(_.MAGENTA_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.magentaStainedClay, 1));
	public enum magentaStainedClay = _.MAGENTA_STAINED_CLAY.id;
	
	public alias LightBlueStainedClay = MineableBlock!(_.LIGHT_BLUE_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.lightBlueStainedClay, 1));
	public enum lightBlueStainedClay = _.LIGHT_BLUE_STAINED_CLAY.id;
	
	public alias YellowStainedClay = MineableBlock!(_.YELLOW_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.yellowStainedClay, 1));
	public enum yellowStainedClay = _.YELLOW_STAINED_CLAY.id;
	
	public alias LimeStainedClay = MineableBlock!(_.LIME_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.limeStainedClay, 1));
	public enum limeStainedClay = _.LIME_STAINED_CLAY.id;
	
	public alias PinkStainedClay = MineableBlock!(_.PINK_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.pinkStainedClay, 1));
	public enum pinkStainedClay = _.PINK_STAINED_CLAY.id;
	
	public alias GrayStainedClay = MineableBlock!(_.GRAY_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.grayStainedClay, 1));
	public enum grayStainedClay = _.GRAY_STAINED_CLAY.id;
	
	public alias LightGrayStainedClay = MineableBlock!(_.LIGHT_GRAY_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.lightGrayStainedClay, 1));
	public enum lightGrayStainedClay = _.LIGHT_GRAY_STAINED_CLAY.id;
	
	public alias CyanStainedClay = MineableBlock!(_.CYAN_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cyanStainedClay, 1));
	public enum cyanStainedClay = _.CYAN_STAINED_CLAY.id;
	
	public alias PurpleStainedClay = MineableBlock!(_.PURPLE_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpleStainedClay, 1));
	public enum purpleStainedClay = _.PURPLE_STAINED_CLAY.id;
	
	public alias BlueStainedClay = MineableBlock!(_.BLUE_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.blueStainedClay, 1));
	public enum blueStainedClay = _.BLUE_STAINED_CLAY.id;
	
	public alias BrownStainedClay = MineableBlock!(_.BROWN_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.brownStainedClay, 1));
	public enum brownStainedClay = _.BROWN_STAINED_CLAY.id;
	
	public alias GreenStainedClay = MineableBlock!(_.GREEN_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.greenStainedClay, 1));
	public enum greenStainedClay = _.GREEN_STAINED_CLAY.id;
	
	public alias RedStainedClay = MineableBlock!(_.RED_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redStainedClay, 1));
	public enum redStainedClay = _.RED_STAINED_CLAY.id;
	
	public alias BlackStainedClay = MineableBlock!(_.BLACK_STAINED_CLAY, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.blackStainedClay, 1));
	public enum blackStainedClay = _.BLACK_STAINED_CLAY.id;
	
	public enum stainedClay = [whiteStainedClay, orangeStainedClay, magentaStainedClay, lightBlueStainedClay, yellowStainedClay, limeStainedClay, pinkStainedClay, grayStainedClay, lightGrayStainedClay, cyanStainedClay, purpleStainedClay, blueStainedClay, brownStainedClay, greenStainedClay, redStainedClay, blackStainedClay];

	public alias PumpkinFacingSouth = MineableBlock!(_.PUMPKIN_FACING_SOUTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum pumpkinFacingSouth = _.PUMPKIN_FACING_SOUTH.id;
	
	public alias PumpkinFacingWest = MineableBlock!(_.PUMPKIN_FACING_WEST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum pumpkinFacingWest = _.PUMPKIN_FACING_WEST.id;
	
	public alias PumpkinFacingNorth = MineableBlock!(_.PUMPKIN_FACING_NORTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum pumpkinFacingNorth = _.PUMPKIN_FACING_NORTH.id;
	
	public alias PumpkinFacingEast = MineableBlock!(_.PUMPKIN_FACING_EAST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum pumpkinFacingEast = _.PUMPKIN_FACING_EAST.id;
	
	public enum pumpkin = [pumpkinFacingSouth, pumpkinFacingWest, pumpkinFacingNorth, pumpkinFacingEast];
	
	public alias FacelessPumpkinFacingSouth = MineableBlock!(_.FACELESS_PUMPKIN_FACING_SOUTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum facelessPumpkinFacingSouth = _.FACELESS_PUMPKIN_FACING_SOUTH.id;
	
	public alias FacelessPumpkinFacingWest = MineableBlock!(_.FACELESS_PUMPKIN_FACING_WEST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum facelessPumpkinFacingWest = _.FACELESS_PUMPKIN_FACING_WEST.id;
	
	public alias FacelessPumpkinFacingNorth = MineableBlock!(_.FACELESS_PUMPKIN_FACING_NORTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum facelessPumpkinFacingNorth = _.FACELESS_PUMPKIN_FACING_NORTH.id;
	
	public alias FacelessPumpkinFacingEast = MineableBlock!(_.FACELESS_PUMPKIN_FACING_EAST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1));
	public enum facelessPumpkinFacingEast = _.FACELESS_PUMPKIN_FACING_EAST.id;

	public alias JackOLanternFacingSouth = MineableBlock!(_.JACK_O_LANTERN_FACING_SOUTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum jackOLanternFacingSouth = _.JACK_O_LANTERN_FACING_SOUTH.id;
	
	public alias JackOLanternFacingWest = MineableBlock!(_.JACK_O_LANTERN_FACING_WEST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum jackOLanternFacingWest = _.JACK_O_LANTERN_FACING_WEST.id;
	
	public alias JackOLanternFacingNorth = MineableBlock!(_.JACK_O_LANTERN_FACING_NORTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum jackOLanternFacingNorth = _.JACK_O_LANTERN_FACING_NORTH.id;
	
	public alias JackOLanternFacingEast = MineableBlock!(_.JACK_O_LANTERN_FACING_EAST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum jackOLanternFacingEast = _.JACK_O_LANTERN_FACING_EAST.id;
	
	public enum jackOLantern = [jackOLanternFacingSouth, jackOLanternFacingWest, jackOLanternFacingNorth, jackOLanternFacingEast];
	
	public alias FacelessJackOLanternFacingSouth = MineableBlock!(_.FACELESS_JACK_O_LANTERN_FACING_SOUTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum facelessJackOLanternFacingSouth = _.FACELESS_JACK_O_LANTERN_FACING_SOUTH.id;
	
	public alias FacelessJackOLanternFacingWest = MineableBlock!(_.FACELESS_JACK_O_LANTERN_FACING_WEST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum facelessJackOLanternFacingWest = _.FACELESS_JACK_O_LANTERN_FACING_WEST.id;
	
	public alias FacelessJackOLanternFacingNorth = MineableBlock!(_.FACELESS_JACK_O_LANTERN_FACING_NORTH, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum facelessJackOLanternFacingNorth = _.FACELESS_JACK_O_LANTERN_FACING_NORTH.id;
	
	public alias FacelessJackOLanternFacingEast = MineableBlock!(_.FACELESS_JACK_O_LANTERN_FACING_EAST, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1));
	public enum facelessJackOLanternFacingEast = _.FACELESS_JACK_O_LANTERN_FACING_EAST.id;
	
	public enum oakWoodFence = _.OAK_WOOD_FENCE.id;

	public enum spruceWoodFence = _.SPRUCE_WOOD_FENCE.id;

	public enum birchWoodFence = _.BIRCH_WOOD_FENCE.id;
	
	public enum jungleWoodFence = _.JUNGLE_WOOD_FENCE.id;
	
	public enum acaciaWoodFence = _.ACACIA_WOOD_FENCE.id;
	
	public enum darkOakWoodFence = _.DARK_OAK_WOOD_FENCE.id;
	
	public enum netherBrickFence = _.NETHER_BRICK_FENCE.id;

	public alias Netherrack = MineableBlock!(_.NETHERRACK, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherrack, 1)); //TODO infinite fire
	public enum netherrack = _.NETHERRACK.id;

	public alias SoulSand = MineableBlock!(_.SOUL_SAND, MiningTool(false, Tools.pickaxe, Tools.wood), Drop(Items.soulSand, 1));
	public enum soulSand = _.SOUL_SAND.id;

	public alias Glowstone = MineableBlock!(_.GLOWSTONE, MiningTool.init, Drop(Items.glowstoneDust, 2, 4, Items.glowstone)); //TODO fortune +1 but max 4
	public enum glowstone = _.GLOWSTONE.id;

	public alias NetherBrick = MineableBlock!(_.NETHER_BRICK, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrick, 1));
	public enum netherBrick = _.NETHER_BRICK.id;

	public alias RedNetherBrick = MineableBlock!(_.RED_NETHER_BRICK, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redNetherBrick, 1));
	public enum redNetherBrick = _.RED_NETHER_BRICK.id;

	public enum netherPortalEastWest = _.NETHER_PORTAL_EAST_WEST.id;

	public enum netherPortalNorthSouth = _.NETHER_PORTAL_NORTH_SOUTH.id;

	public enum netherPortal = [netherPortalEastWest, netherPortalNorthSouth];
	
	public alias Cake0 = CakeBlock!(_.CAKE_0, cake1);
	public enum cake0 = _.CAKE_0.id;
	
	public alias Cake1 = CakeBlock!(_.CAKE_1, cake2);
	public enum cake1 = _.CAKE_1.id;
	
	public alias Cake2 = CakeBlock!(_.CAKE_2, cake3);
	public enum cake2 = _.CAKE_2.id;
	
	public alias Cake3 = CakeBlock!(_.CAKE_3, cake4);
	public enum cake3 = _.CAKE_3.id;
	
	public alias Cake4 = CakeBlock!(_.CAKE_4, cake5);
	public enum cake4 = _.CAKE_4.id;
	
	public alias Cake5 = CakeBlock!(_.CAKE_5, cake6);
	public enum cake5 = _.CAKE_5.id;
	
	public alias Cake6 = CakeBlock!(_.CAKE_6, air);
	public enum cake6 = _.CAKE_6.id;

	public enum cake = [cake0, cake1, cake2, cake3, cake4, cake5, cake6];

	public enum repeaterFacingNorth1Delay = _.REPEATER_FACING_NORTH_1_DELAY.id;
	
	public enum repeaterFacingEast1Delay = _.REPEATER_FACING_EAST_1_DELAY.id;
	
	public enum repeaterFacingSouth1Delay = _.REPEATER_FACING_SOUTH_1_DELAY.id;
	
	public enum repeaterFacingWest1Delay = _.REPEATER_FACING_WEST_1_DELAY.id;
	
	public enum repeaterFacingNorth2Delay = _.REPEATER_FACING_NORTH_2_DELAY.id;
	
	public enum repeaterFacingEast2Delay = _.REPEATER_FACING_EAST_2_DELAY.id;
	
	public enum repeaterFacingSouth2Delay = _.REPEATER_FACING_SOUTH_2_DELAY.id;
	
	public enum repeaterFacingWest2Delay = _.REPEATER_FACING_WEST_2_DELAY.id;
	
	public enum repeaterFacingNorth3Delay = _.REPEATER_FACING_NORTH_3_DELAY.id;
	
	public enum repeaterFacingEast3Delay = _.REPEATER_FACING_EAST_3_DELAY.id;
	
	public enum repeaterFacingSouth3Delay = _.REPEATER_FACING_SOUTH_3_DELAY.id;
	
	public enum repeaterFacingWest3Delay = _.REPEATER_FACING_WEST_3_DELAY.id;
	
	public enum repeaterFacingNorth4Delay = _.REPEATER_FACING_NORTH_4_DELAY.id;
	
	public enum repeaterFacingEast4Delay = _.REPEATER_FACING_EAST_4_DELAY.id;
	
	public enum repeaterFacingSouth4Delay = _.REPEATER_FACING_SOUTH_4_DELAY.id;
	
	public enum repeaterFacingWest4Delay = _.REPEATER_FACING_WEST_4_DELAY.id;
	
	public enum unpoweredRepeater = [repeaterFacingNorth1Delay, repeaterFacingEast1Delay, repeaterFacingSouth1Delay, repeaterFacingWest1Delay, repeaterFacingNorth2Delay, repeaterFacingEast2Delay, repeaterFacingSouth2Delay, repeaterFacingWest2Delay, repeaterFacingNorth3Delay, repeaterFacingEast3Delay, repeaterFacingSouth3Delay, repeaterFacingWest3Delay, repeaterFacingNorth4Delay, repeaterFacingEast4Delay, repeaterFacingSouth4Delay, repeaterFacingWest4Delay];

	public enum poweredRepeaterFacingNorth1Delay = _.POWERED_REPEATER_FACING_NORTH_1_DELAY.id;
	
	public enum poweredRepeaterFacingEast1Delay = _.POWERED_REPEATER_FACING_EAST_1_DELAY.id;
	
	public enum poweredRepeaterFacingSouth1Delay = _.POWERED_REPEATER_FACING_SOUTH_1_DELAY.id;
	
	public enum poweredRepeaterFacingWest1Delay = _.POWERED_REPEATER_FACING_WEST_1_DELAY.id;
	
	public enum poweredRepeaterFacingNorth2Delay = _.POWERED_REPEATER_FACING_NORTH_2_DELAY.id;
	
	public enum poweredRepeaterFacingEast2Delay = _.POWERED_REPEATER_FACING_EAST_2_DELAY.id;
	
	public enum poweredRepeaterFacingSouth2Delay = _.POWERED_REPEATER_FACING_SOUTH_2_DELAY.id;
	
	public enum poweredRepeaterFacingWest2Delay = _.POWERED_REPEATER_FACING_WEST_2_DELAY.id;
	
	public enum poweredRepeaterFacingNorth3Delay = _.POWERED_REPEATER_FACING_NORTH_3_DELAY.id;
	
	public enum poweredRepeaterFacingEast3Delay = _.POWERED_REPEATER_FACING_EAST_3_DELAY.id;
	
	public enum poweredRepeaterFacingSouth3Delay = _.POWERED_REPEATER_FACING_SOUTH_3_DELAY.id;
	
	public enum poweredRepeaterFacingWest3Delay = _.POWERED_REPEATER_FACING_WEST_3_DELAY.id;
	
	public enum poweredRepeaterFacingNorth4Delay = _.POWERED_REPEATER_FACING_NORTH_4_DELAY.id;
	
	public enum poweredRepeaterFacingEast4Delay = _.POWERED_REPEATER_FACING_EAST_4_DELAY.id;
	
	public enum poweredRepeaterFacingSouth4Delay = _.POWERED_REPEATER_FACING_SOUTH_4_DELAY.id;
	
	public enum poweredRepeaterFacingWest4Delay = _.POWERED_REPEATER_FACING_WEST_4_DELAY.id;
	
	public enum poweredRepeater = [poweredRepeaterFacingNorth1Delay, poweredRepeaterFacingEast1Delay, poweredRepeaterFacingSouth1Delay, poweredRepeaterFacingWest1Delay, poweredRepeaterFacingNorth2Delay, poweredRepeaterFacingEast2Delay, poweredRepeaterFacingSouth2Delay, poweredRepeaterFacingWest2Delay, poweredRepeaterFacingNorth3Delay, poweredRepeaterFacingEast3Delay, poweredRepeaterFacingSouth3Delay, poweredRepeaterFacingWest3Delay, poweredRepeaterFacingNorth4Delay, poweredRepeaterFacingEast4Delay, poweredRepeaterFacingSouth4Delay, poweredRepeaterFacingWest4Delay];

	public enum repeater = unpoweredRepeater ~ poweredRepeater;

	public alias WoodenTrapdoorSouthSide = SwitchingBlock!(_.WOODEN_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedWoodenTrapdoorSouthSide);
	public enum woodenTrapdoorSouthSide = _.WOODEN_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias WoodenTrapdoorNorthSide = SwitchingBlock!(_.WOODEN_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedWoodenTrapdoorNorthSide);
	public enum woodenTrapdoorNorthSide = _.WOODEN_TRAPDOOR_NORTH_SIDE.id;
	
	public alias WoodenTrapdoorEastSide = SwitchingBlock!(_.WOODEN_TRAPDOOR_EAST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedWoodenTrapdoorEastSide);
	public enum woodenTrapdoorEastSide = _.WOODEN_TRAPDOOR_EAST_SIDE.id;
	
	public alias WoodenTrapdoorWestSide = SwitchingBlock!(_.WOODEN_TRAPDOOR_WEST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedWoodenTrapdoorWestSide);
	public enum woodenTrapdoorWestSide = _.WOODEN_TRAPDOOR_WEST_SIDE.id;
	
	public enum closedBottomWoodenTrapdoor = [woodenTrapdoorSouthSide, woodenTrapdoorNorthSide, woodenTrapdoorEastSide, woodenTrapdoorWestSide];
	
	public alias OpenedWoodenTrapdoorSouthSide = SwitchingBlock!(_.OPENED_WOODEN_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), woodenTrapdoorSouthSide);
	public enum openedWoodenTrapdoorSouthSide = _.OPENED_WOODEN_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias OpenedWoodenTrapdoorNorthSide = SwitchingBlock!(_.OPENED_WOODEN_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), woodenTrapdoorNorthSide);
	public enum openedWoodenTrapdoorNorthSide = _.OPENED_WOODEN_TRAPDOOR_NORTH_SIDE.id;
	
	public alias OpenedWoodenTrapdoorEastSide = SwitchingBlock!(_.OPENED_WOODEN_TRAPDOOR_EAST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), woodenTrapdoorEastSide);
	public enum openedWoodenTrapdoorEastSide = _.OPENED_WOODEN_TRAPDOOR_EAST_SIDE.id;
	
	public alias OpenedWoodenTrapdoorWestSide = SwitchingBlock!(_.OPENED_WOODEN_TRAPDOOR_WEST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), woodenTrapdoorWestSide);
	public enum openedWoodenTrapdoorWestSide = _.OPENED_WOODEN_TRAPDOOR_WEST_SIDE.id;
	
	public enum openedBottomWoodenTrapdoor = [openedWoodenTrapdoorSouthSide, openedWoodenTrapdoorNorthSide, openedWoodenTrapdoorEastSide, openedWoodenTrapdoorWestSide];
	
	public enum bottomWoodenTrapdoor = closedBottomWoodenTrapdoor ~ openedBottomWoodenTrapdoor;
	
	public alias TopWoodenTrapdoorSouthSide = SwitchingBlock!(_.TOP_WOODEN_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedTopWoodenTrapdoorSouthSide);
	public enum topWoodenTrapdoorSouthSide = _.TOP_WOODEN_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias TopWoodenTrapdoorNorthSide = SwitchingBlock!(_.TOP_WOODEN_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedTopWoodenTrapdoorNorthSide);
	public enum topWoodenTrapdoorNorthSide = _.TOP_WOODEN_TRAPDOOR_NORTH_SIDE.id;
	
	public alias TopWoodenTrapdoorEastSide = SwitchingBlock!(_.TOP_WOODEN_TRAPDOOR_EAST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedTopWoodenTrapdoorEastSide);
	public enum topWoodenTrapdoorEastSide = _.TOP_WOODEN_TRAPDOOR_EAST_SIDE.id;
	
	public alias TopWoodenTrapdoorWestSide = SwitchingBlock!(_.TOP_WOODEN_TRAPDOOR_WEST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), openedTopWoodenTrapdoorWestSide);
	public enum topWoodenTrapdoorWestSide = _.TOP_WOODEN_TRAPDOOR_WEST_SIDE.id;
	
	public enum closedTopWoodenTrapdoor = [topWoodenTrapdoorSouthSide, topWoodenTrapdoorNorthSide, topWoodenTrapdoorEastSide, topWoodenTrapdoorWestSide];
	
	public alias OpenedTopWoodenTrapdoorSouthSide = SwitchingBlock!(_.OPENED_TOP_WOODEN_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), topWoodenTrapdoorSouthSide);
	public enum openedTopWoodenTrapdoorSouthSide = _.OPENED_TOP_WOODEN_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias OpenedTopWoodenTrapdoorNorthSide = SwitchingBlock!(_.OPENED_TOP_WOODEN_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), topWoodenTrapdoorNorthSide);
	public enum openedTopWoodenTrapdoorNorthSide = _.OPENED_TOP_WOODEN_TRAPDOOR_NORTH_SIDE.id;
	
	public alias OpenedTopWoodenTrapdoorEastSide = SwitchingBlock!(_.OPENED_TOP_WOODEN_TRAPDOOR_EAST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), topWoodenTrapdoorEastSide);
	public enum openedTopWoodenTrapdoorEastSide = _.OPENED_TOP_WOODEN_TRAPDOOR_EAST_SIDE.id;
	
	public alias OpenedTopWoodenTrapdoorWestSide = SwitchingBlock!(_.OPENED_TOP_WOODEN_TRAPDOOR_WEST_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), topWoodenTrapdoorWestSide);
	public enum openedTopWoodenTrapdoorWestSide = _.OPENED_TOP_WOODEN_TRAPDOOR_WEST_SIDE.id;
	
	public enum openedTopWoodenTrapdoor = [openedTopWoodenTrapdoorSouthSide, openedTopWoodenTrapdoorNorthSide, openedTopWoodenTrapdoorEastSide, openedTopWoodenTrapdoorWestSide];
	
	public enum topWoodenTrapdoor = closedTopWoodenTrapdoor ~ openedBottomWoodenTrapdoor;
	
	public enum woodenTrapdoor = bottomWoodenTrapdoor ~ topWoodenTrapdoor;

	public alias IronTrapdoorSouthSide = SwitchingBlock!(_.IRON_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedIronTrapdoorSouthSide, true);
	public enum ironTrapdoorSouthSide = _.IRON_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias IronTrapdoorNorthSide = SwitchingBlock!(_.IRON_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedIronTrapdoorNorthSide, true);
	public enum ironTrapdoorNorthSide = _.IRON_TRAPDOOR_NORTH_SIDE.id;
	
	public alias IronTrapdoorEastSide = SwitchingBlock!(_.IRON_TRAPDOOR_EAST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedIronTrapdoorEastSide, true);
	public enum ironTrapdoorEastSide = _.IRON_TRAPDOOR_EAST_SIDE.id;
	
	public alias IronTrapdoorWestSide = SwitchingBlock!(_.IRON_TRAPDOOR_WEST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedIronTrapdoorWestSide, true);
	public enum ironTrapdoorWestSide = _.IRON_TRAPDOOR_WEST_SIDE.id;
	
	public enum closedBottomIronTrapdoor = [ironTrapdoorSouthSide, ironTrapdoorNorthSide, ironTrapdoorEastSide, ironTrapdoorWestSide];
	
	public alias OpenedIronTrapdoorSouthSide = SwitchingBlock!(_.OPENED_IRON_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), ironTrapdoorSouthSide, true);
	public enum openedIronTrapdoorSouthSide = _.OPENED_IRON_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias OpenedIronTrapdoorNorthSide = SwitchingBlock!(_.OPENED_IRON_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), ironTrapdoorNorthSide, true);
	public enum openedIronTrapdoorNorthSide = _.OPENED_IRON_TRAPDOOR_NORTH_SIDE.id;
	
	public alias OpenedIronTrapdoorEastSide = SwitchingBlock!(_.OPENED_IRON_TRAPDOOR_EAST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), ironTrapdoorEastSide, true);
	public enum openedIronTrapdoorEastSide = _.OPENED_IRON_TRAPDOOR_EAST_SIDE.id;
	
	public alias OpenedIronTrapdoorWestSide = SwitchingBlock!(_.OPENED_IRON_TRAPDOOR_WEST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), ironTrapdoorWestSide, true);
	public enum openedIronTrapdoorWestSide = _.OPENED_IRON_TRAPDOOR_WEST_SIDE.id;
	
	public enum openedBottomIronTrapdoor = [openedIronTrapdoorSouthSide, openedIronTrapdoorNorthSide, openedIronTrapdoorEastSide, openedIronTrapdoorWestSide];
	
	public enum bottomIronTrapdoor = closedBottomIronTrapdoor ~ openedBottomIronTrapdoor;
	
	public alias TopIronTrapdoorSouthSide = SwitchingBlock!(_.TOP_IRON_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedTopIronTrapdoorSouthSide, true);
	public enum topIronTrapdoorSouthSide = _.TOP_IRON_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias TopIronTrapdoorNorthSide = SwitchingBlock!(_.TOP_IRON_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedTopIronTrapdoorNorthSide, true);
	public enum topIronTrapdoorNorthSide = _.TOP_IRON_TRAPDOOR_NORTH_SIDE.id;
	
	public alias TopIronTrapdoorEastSide = SwitchingBlock!(_.TOP_IRON_TRAPDOOR_EAST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedTopIronTrapdoorEastSide, true);
	public enum topIronTrapdoorEastSide = _.TOP_IRON_TRAPDOOR_EAST_SIDE.id;
	
	public alias TopIronTrapdoorWestSide = SwitchingBlock!(_.TOP_IRON_TRAPDOOR_WEST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), openedTopIronTrapdoorWestSide, true);
	public enum topIronTrapdoorWestSide = _.TOP_IRON_TRAPDOOR_WEST_SIDE.id;
	
	public enum closedTopIronTrapdoor = [topIronTrapdoorSouthSide, topIronTrapdoorNorthSide, topIronTrapdoorEastSide, topIronTrapdoorWestSide];
	
	public alias OpenedTopIronTrapdoorSouthSide = SwitchingBlock!(_.OPENED_TOP_IRON_TRAPDOOR_SOUTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), topIronTrapdoorSouthSide, true);
	public enum openedTopIronTrapdoorSouthSide = _.OPENED_TOP_IRON_TRAPDOOR_SOUTH_SIDE.id;
	
	public alias OpenedTopIronTrapdoorNorthSide = SwitchingBlock!(_.OPENED_TOP_IRON_TRAPDOOR_NORTH_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), topIronTrapdoorNorthSide, true);
	public enum openedTopIronTrapdoorNorthSide = _.OPENED_TOP_IRON_TRAPDOOR_NORTH_SIDE.id;
	
	public alias OpenedTopIronTrapdoorEastSide = SwitchingBlock!(_.OPENED_TOP_IRON_TRAPDOOR_EAST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), topIronTrapdoorEastSide, true);
	public enum openedTopIronTrapdoorEastSide = _.OPENED_TOP_IRON_TRAPDOOR_EAST_SIDE.id;
	
	public alias OpenedTopIronTrapdoorWestSide = SwitchingBlock!(_.OPENED_TOP_IRON_TRAPDOOR_WEST_SIDE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), topIronTrapdoorWestSide, true);
	public enum openedTopIronTrapdoorWestSide = _.OPENED_TOP_IRON_TRAPDOOR_WEST_SIDE.id;
	
	public enum openedTopIronTrapdoor = [openedTopIronTrapdoorSouthSide, openedTopIronTrapdoorNorthSide, openedTopIronTrapdoorEastSide, openedTopIronTrapdoorWestSide];
	
	public enum topIronTrapdoor = closedTopIronTrapdoor ~ openedBottomIronTrapdoor;
	
	public enum ironTrapdoor = bottomIronTrapdoor ~ topIronTrapdoor;

	public enum trapdoor = woodenTrapdoor ~ ironTrapdoor;

	public alias StoneMonsterEgg = MonsterEggBlock!(_.STONE_MONSTER_EGG, stone);
	public enum stoneMonsterEgg = _.STONE_MONSTER_EGG.id;

	public alias CobblestoneMonsterEgg = MonsterEggBlock!(_.COBBLESTONE_MONSTER_EGG, cobblestone);
	public enum cobblestoneMonsterEgg = _.COBBLESTONE_MONSTER_EGG.id;

	public alias StoneBrickMonsterEgg = MonsterEggBlock!(_.STONE_BRICK_MONSTER_EGG, stoneBricks);
	public enum stoneBrickMonsterEgg = _.STONE_BRICK_MONSTER_EGG.id;
	
	public alias MossyStoneBrickMonsterEgg = MonsterEggBlock!(_.MOSSY_STONE_BRICK_MONSTER_EGG, mossyStoneBricks);
	public enum mossyStoneBrickMonsterEgg = _.MOSSY_STONE_BRICK_MONSTER_EGG.id;
	
	public alias CrackedStoneBrickMonsterEgg = MonsterEggBlock!(_.CRACKED_STONE_BRICK_MONSTER_EGG, crackedStoneBricks);
	public enum crackedStoneBrickMonsterEgg = _.CRACKED_STONE_BRICK_MONSTER_EGG.id;
	
	public alias ChiseledStoneBrickMonsterEgg = MonsterEggBlock!(_.CHISELED_STONE_BRICK_MONSTER_EGG, chiseledStoneBricks);
	public enum chiseledStoneBrickMonsterEgg = _.CHISELED_STONE_BRICK_MONSTER_EGG.id;

	public enum monsterEgg = [stoneMonsterEgg, cobblestoneMonsterEgg, stoneBrickMonsterEgg, mossyStoneBrickMonsterEgg, crackedStoneBrickMonsterEgg, chiseledStoneBrickMonsterEgg];

	public alias BrownMushroomPoresEverywhere = MineableBlock!(_.BROWN_MUSHROOM_PORES_EVERYWHERE, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomPoresEverywhere = _.BROWN_MUSHROOM_PORES_EVERYWHERE.id;
	
	public alias BrownMushroomCapTopWestNorth = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_WEST_NORTH, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopWestNorth = _.BROWN_MUSHROOM_CAP_TOP_WEST_NORTH.id;
	
	public alias BrownMushroomCapTopNorth = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_NORTH, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopNorth = _.BROWN_MUSHROOM_CAP_TOP_NORTH.id;
	
	public alias BrownMushroomCapTopNorthEast = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_NORTH_EAST, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopNorthEast = _.BROWN_MUSHROOM_CAP_TOP_NORTH_EAST.id;
	
	public alias BrownMushroomCapTopWest = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_WEST, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopWest = _.BROWN_MUSHROOM_CAP_TOP_WEST.id;
	
	public alias BrownMushroomCapTop = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTop = _.BROWN_MUSHROOM_CAP_TOP.id;
	
	public alias BrownMushroomCapTopEast = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_EAST, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopEast = _.BROWN_MUSHROOM_CAP_TOP_EAST.id;
	
	public alias BrownMushroomCapTopSouthWest = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_SOUTH_WEST, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopSouthWest = _.BROWN_MUSHROOM_CAP_TOP_SOUTH_WEST.id;
	
	public alias BrownMushroomCapTopSouth = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_SOUTH, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopSouth = _.BROWN_MUSHROOM_CAP_TOP_SOUTH.id;
	
	public alias BrownMushroomCapTopEastSouth = MineableBlock!(_.BROWN_MUSHROOM_CAP_TOP_EAST_SOUTH, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapTopEastSouth = _.BROWN_MUSHROOM_CAP_TOP_EAST_SOUTH.id;
	
	public alias BrownMushroomStemEverySide = MineableBlock!(_.BROWN_MUSHROOM_STEM_EVERY_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomStemEverySide = _.BROWN_MUSHROOM_STEM_EVERY_SIDE.id;
	
	public alias BrownMushroomCapsEverywhere = MineableBlock!(_.BROWN_MUSHROOM_CAPS_EVERYWHERE, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomCapsEverywhere = _.BROWN_MUSHROOM_CAPS_EVERYWHERE.id;
	
	public alias BrownMushroomStemsEverywhere = MineableBlock!(_.BROWN_MUSHROOM_STEMS_EVERYWHERE, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock));
	public enum brownMushroomStemsEverywhere = _.BROWN_MUSHROOM_STEMS_EVERYWHERE.id;
	
	public enum brownMushroomBlock = [brownMushroomPoresEverywhere, brownMushroomCapTopWestNorth, brownMushroomCapTopNorth, brownMushroomCapTopNorthEast, brownMushroomCapTopWest, brownMushroomCapTop, brownMushroomCapTopEast, brownMushroomCapTopSouthWest, brownMushroomCapTopSouth, brownMushroomCapTopEastSouth];

	public alias RedMushroomPoresEverywhere = MineableBlock!(_.RED_MUSHROOM_PORES_EVERYWHERE, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomPoresEverywhere = _.RED_MUSHROOM_PORES_EVERYWHERE.id;
	
	public alias RedMushroomCapTopWestNorth = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_WEST_NORTH, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopWestNorth = _.RED_MUSHROOM_CAP_TOP_WEST_NORTH.id;
	
	public alias RedMushroomCapTopNorth = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_NORTH, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopNorth = _.RED_MUSHROOM_CAP_TOP_NORTH.id;
	
	public alias RedMushroomCapTopNorthEast = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_NORTH_EAST, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopNorthEast = _.RED_MUSHROOM_CAP_TOP_NORTH_EAST.id;
	
	public alias RedMushroomCapTopWest = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_WEST, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopWest = _.RED_MUSHROOM_CAP_TOP_WEST.id;
	
	public alias RedMushroomCapTop = MineableBlock!(_.RED_MUSHROOM_CAP_TOP, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTop = _.RED_MUSHROOM_CAP_TOP.id;
	
	public alias RedMushroomCapTopEast = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_EAST, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopEast = _.RED_MUSHROOM_CAP_TOP_EAST.id;
	
	public alias RedMushroomCapTopSouthWest = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_SOUTH_WEST, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopSouthWest = _.RED_MUSHROOM_CAP_TOP_SOUTH_WEST.id;
	
	public alias RedMushroomCapTopSouth = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_SOUTH, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopSouth = _.RED_MUSHROOM_CAP_TOP_SOUTH.id;
	
	public alias RedMushroomCapTopEastSouth = MineableBlock!(_.RED_MUSHROOM_CAP_TOP_EAST_SOUTH, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapTopEastSouth = _.RED_MUSHROOM_CAP_TOP_EAST_SOUTH.id;
	
	public alias RedMushroomStemEverySide = MineableBlock!(_.RED_MUSHROOM_STEM_EVERY_SIDE, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomStemEverySide = _.RED_MUSHROOM_STEM_EVERY_SIDE.id;
	
	public alias RedMushroomCapsEverywhere = MineableBlock!(_.RED_MUSHROOM_CAPS_EVERYWHERE, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomCapsEverywhere = _.RED_MUSHROOM_CAPS_EVERYWHERE.id;
	
	public alias RedMushroomStemsEverywhere = MineableBlock!(_.RED_MUSHROOM_STEMS_EVERYWHERE, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock));
	public enum redMushroomStemsEverywhere = _.RED_MUSHROOM_STEMS_EVERYWHERE.id;
	
	public enum redMushroomBlock = [redMushroomPoresEverywhere, redMushroomCapTopWestNorth, redMushroomCapTopNorth, redMushroomCapTopNorthEast, redMushroomCapTopWest, redMushroomCapTop, redMushroomCapTopEast, redMushroomCapTopSouthWest, redMushroomCapTopSouth, redMushroomCapTopEastSouth];

	public enum mushroomBlock = brownMushroomBlock ~ redMushroomBlock;

	public alias IronBars = MineableBlock!(_.IRON_BARS, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironBars, 1));
	public enum ironBars = _.IRON_BARS.id;

	public alias Melon = MineableBlock!(_.MELON, MiningTool(Tools.axe | Tools.sword, Tools.all), Drop(Items.melon, 3, 7, Items.melonBlock));
	public enum melon = _.MELON.id;
	
	public enum vinesSouth = _.VINES_SOUTH.id;
	
	public enum vinesWest = _.VINES_WEST.id;
	
	public enum vinesSouthWest = _.VINES_SOUTH_WEST.id;
	
	public enum vinesNorth = _.VINES_NORTH.id;
	
	public enum vinesNorthSouth = _.VINES_NORTH_SOUTH.id;
	
	public enum vinesNorthWest = _.VINES_NORTH_WEST.id;
	
	public enum vinesNorthSouthWest = _.VINES_NORTH_SOUTH_WEST.id;
	
	public enum vinesEast = _.VINES_EAST.id;
	
	public enum vinesSouthEast = _.VINES_SOUTH_EAST.id;
	
	public enum vinesWestEast = _.VINES_WEST_EAST.id;
	
	public enum vinesSouthWestEast = _.VINES_SOUTH_WEST_EAST.id;
	
	public enum vinesNorthEast = _.VINES_NORTH_EAST.id;
	
	public enum vinesNorthSouthEast = _.VINES_NORTH_SOUTH_EAST.id;
	
	public enum vinesNorthWestEast = _.VINES_NORTH_WEST_EAST.id;

	public enum vinesEverySide = _.VINES_EVERY_SIDE.id;

	public enum oakWoodFenceGateFacingSouth = _.OAK_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum oakWoodFenceGateFacingWest = _.OAK_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum oakWoodFenceGateFacingNorth = _.OAK_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum oakWoodFenceGateFacingEast = _.OAK_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum closedOakWoodFenceGate = [oakWoodFenceGateFacingSouth, oakWoodFenceGateFacingWest, oakWoodFenceGateFacingNorth, oakWoodFenceGateFacingEast];
	
	public enum spruceWoodFenceGateFacingSouth = _.SPRUCE_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum spruceWoodFenceGateFacingWest = _.SPRUCE_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum spruceWoodFenceGateFacingNorth = _.SPRUCE_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum spruceWoodFenceGateFacingEast = _.SPRUCE_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum closedSpruceWoodFenceGate = [spruceWoodFenceGateFacingSouth, spruceWoodFenceGateFacingWest, spruceWoodFenceGateFacingNorth, spruceWoodFenceGateFacingEast];
	
	public enum birchWoodFenceGateFacingSouth = _.BIRCH_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum birchWoodFenceGateFacingWest = _.BIRCH_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum birchWoodFenceGateFacingNorth = _.BIRCH_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum birchWoodFenceGateFacingEast = _.BIRCH_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum closedBirchWoodFenceGate = [birchWoodFenceGateFacingSouth, birchWoodFenceGateFacingWest, birchWoodFenceGateFacingNorth, birchWoodFenceGateFacingEast];
	
	public enum jungleWoodFenceGateFacingSouth = _.JUNGLE_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum jungleWoodFenceGateFacingWest = _.JUNGLE_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum jungleWoodFenceGateFacingNorth = _.JUNGLE_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum jungleWoodFenceGateFacingEast = _.JUNGLE_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum closedJungleWoodFenceGate = [jungleWoodFenceGateFacingSouth, jungleWoodFenceGateFacingWest, jungleWoodFenceGateFacingNorth, jungleWoodFenceGateFacingEast];
	
	public enum acaciaWoodFenceGateFacingSouth = _.JUNGLE_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum acaciaWoodFenceGateFacingWest = _.JUNGLE_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum acaciaWoodFenceGateFacingNorth = _.JUNGLE_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum acaciaWoodFenceGateFacingEast = _.JUNGLE_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum closedAcaciaWoodFenceGate = [acaciaWoodFenceGateFacingSouth, acaciaWoodFenceGateFacingWest, acaciaWoodFenceGateFacingNorth, acaciaWoodFenceGateFacingEast];
	
	public enum darkOakWoodFenceGateFacingSouth = _.DARK_OAK_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum darkOakWoodFenceGateFacingWest = _.DARK_OAK_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum darkOakWoodFenceGateFacingNorth = _.DARK_OAK_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum darkOakWoodFenceGateFacingEast = _.DARK_OAK_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum closedDarkOakWoodFenceGate = [darkOakWoodFenceGateFacingSouth, darkOakWoodFenceGateFacingWest, darkOakWoodFenceGateFacingNorth, darkOakWoodFenceGateFacingEast];
	
	public enum closedFenceGate = closedOakWoodFenceGate ~ closedSpruceWoodFenceGate ~ closedBirchWoodFenceGate ~ closedJungleWoodFenceGate ~ closedAcaciaWoodFenceGate ~ closedDarkOakWoodFenceGate;

	public enum openedOakWoodFenceGateFacingSouth = _.OPENED_OAK_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum openedOakWoodFenceGateFacingWest = _.OPENED_OAK_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum openedOakWoodFenceGateFacingNorth = _.OPENED_OAK_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum openedOakWoodFenceGateFacingEast = _.OPENED_OAK_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum openedOakWoodFenceGate = [openedOakWoodFenceGateFacingSouth, openedOakWoodFenceGateFacingWest, openedOakWoodFenceGateFacingNorth, openedOakWoodFenceGateFacingEast];
	
	public enum openedSpruceWoodFenceGateFacingSouth = _.OPENED_SPRUCE_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum openedSpruceWoodFenceGateFacingWest = _.OPENED_SPRUCE_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum openedSpruceWoodFenceGateFacingNorth = _.OPENED_SPRUCE_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum openedSpruceWoodFenceGateFacingEast = _.OPENED_SPRUCE_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum openedSpruceWoodFenceGate = [openedSpruceWoodFenceGateFacingSouth, openedSpruceWoodFenceGateFacingWest, openedSpruceWoodFenceGateFacingNorth, openedSpruceWoodFenceGateFacingEast];
	
	public enum openedBirchWoodFenceGateFacingSouth = _.OPENED_BIRCH_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum openedBirchWoodFenceGateFacingWest = _.OPENED_BIRCH_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum openedBirchWoodFenceGateFacingNorth = _.OPENED_BIRCH_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum openedBirchWoodFenceGateFacingEast = _.OPENED_BIRCH_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum openedBirchWoodFenceGate = [openedBirchWoodFenceGateFacingSouth, openedBirchWoodFenceGateFacingWest, openedBirchWoodFenceGateFacingNorth, openedBirchWoodFenceGateFacingEast];
	
	public enum openedJungleWoodFenceGateFacingSouth = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum openedJungleWoodFenceGateFacingWest = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum openedJungleWoodFenceGateFacingNorth = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum openedJungleWoodFenceGateFacingEast = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum openedJungleWoodFenceGate = [openedJungleWoodFenceGateFacingSouth, openedJungleWoodFenceGateFacingWest, openedJungleWoodFenceGateFacingNorth, openedJungleWoodFenceGateFacingEast];
	
	public enum openedAcaciaWoodFenceGateFacingSouth = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum openedAcaciaWoodFenceGateFacingWest = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum openedAcaciaWoodFenceGateFacingNorth = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum openedAcaciaWoodFenceGateFacingEast = _.OPENED_JUNGLE_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum openedAcaciaWoodFenceGate = [openedAcaciaWoodFenceGateFacingSouth, openedAcaciaWoodFenceGateFacingWest, openedAcaciaWoodFenceGateFacingNorth, openedAcaciaWoodFenceGateFacingEast];
	
	public enum openedDarkOakWoodFenceGateFacingSouth = _.OPENED_DARK_OAK_WOOD_FENCE_GATE_FACING_SOUTH.id;
	
	public enum openedDarkOakWoodFenceGateFacingWest = _.OPENED_DARK_OAK_WOOD_FENCE_GATE_FACING_WEST.id;
	
	public enum openedDarkOakWoodFenceGateFacingNorth = _.OPENED_DARK_OAK_WOOD_FENCE_GATE_FACING_NORTH.id;
	
	public enum openedDarkOakWoodFenceGateFacingEast = _.OPENED_DARK_OAK_WOOD_FENCE_GATE_FACING_EAST.id;
	
	public enum openedDarkOakWoodFenceGate = [openedDarkOakWoodFenceGateFacingSouth, openedDarkOakWoodFenceGateFacingWest, openedDarkOakWoodFenceGateFacingNorth, openedDarkOakWoodFenceGateFacingEast];
	
	public enum openedFenceGate = openedOakWoodFenceGate ~ openedSpruceWoodFenceGate ~ openedBirchWoodFenceGate ~ openedJungleWoodFenceGate ~ openedAcaciaWoodFenceGate ~ openedDarkOakWoodFenceGate;

	public enum fenceGate = closedFenceGate ~ openedFenceGate;

	public enum enchantmentTable = _.ENCHANTMENT_TABLE.id;

	public enum brewingStandEmpty = _.BREWING_STAND_EMPTY.id;
	
	public enum brewingStandBottle1 = _.BREWING_STAND_BOTTLE_1.id;
	
	public enum brewingStandBottle2 = _.BREWING_STAND_BOTTLE_2.id;
	
	public enum brewingStandBottle12 = _.BREWING_STAND_BOTTLE_1_2.id;
	
	public enum brewingStandBottle3 = _.BREWING_STAND_BOTTLE_3.id;
	
	public enum brewingStandBottle13 = _.BREWING_STAND_BOTTLE_1_3.id;
	
	public enum brewingStandBottle23 = _.BREWING_STAND_BOTTLE_2_3.id;

	public enum brewingStandFull = _.BREWING_STAND_FULL.id;

	public enum brewingStand = [brewingStandEmpty, brewingStandBottle1, brewingStandBottle2, brewingStandBottle12, brewingStandBottle3, brewingStandBottle13, brewingStandBottle23, brewingStandFull];

	public enum cauldronEmpty = _.CAULDRON_EMPTY.id;
	
	public enum cauldronOneSixthFilled = _.CAULDRON_ONE_SIXTH_FILLED.id;
	
	public enum cauldronOneThirdFilled = _.CAULDRON_ONE_THIRD_FILLED.id;
	
	public enum cauldronThreeSixthFilled = _.CAULDRON_THREE_SIXTH_FILLED.id;
	
	public enum cauldronTwoThirdFilled = _.CAULDRON_TWO_THIRD_FILLED.id;
	
	public enum cauldronFiveSixthFilled = _.CAULDRON_FIVE_SIXTH_FILLED.id;

	public enum cauldronFilled = _.CAULDRON_FILLED.id;

	public enum cauldron = [cauldronEmpty, cauldronOneSixthFilled, cauldronOneThirdFilled, cauldronThreeSixthFilled, cauldronTwoThirdFilled, cauldronFiveSixthFilled, cauldronFilled];

	public alias EndPortalFrameSouth = InactiveEndPortalBlock!(_.END_PORTAL_FRAME_SOUTH, activeEndPortalFrameSouth, Facing.south);
	public enum endPortalFrameSouth = _.END_PORTAL_FRAME_SOUTH.id;

	public alias EndPortalFrameWest = InactiveEndPortalBlock!(_.END_PORTAL_FRAME_WEST, activeEndPortalFrameWest, Facing.west);
	public enum endPortalFrameWest = _.END_PORTAL_FRAME_WEST.id;

	public alias EndPortalFrameNorth = InactiveEndPortalBlock!(_.END_PORTAL_FRAME_NORTH, activeEndPortalFrameNorth, Facing.north);
	public enum endPortalFrameNorth = _.END_PORTAL_FRAME_NORTH.id;

	public alias EndPortalFrameEast = InactiveEndPortalBlock!(_.END_PORTAL_FRAME_EAST, activeEndPortalFrameEast, Facing.east);
	public enum endPortalFrameEast = _.END_PORTAL_FRAME_EAST.id;

	public enum inactiveEndPortalFrame = [endPortalFrameSouth, endPortalFrameWest, endPortalFrameNorth, endPortalFrameEast];
	
	public alias ActiveEndPortalFrameSouth = SimpleBlock!(_.ACTIVE_END_PORTAL_FRAME_SOUTH);
	public enum activeEndPortalFrameSouth = _.ACTIVE_END_PORTAL_FRAME_SOUTH.id;
	
	public alias ActiveEndPortalFrameWest = SimpleBlock!(_.ACTIVE_END_PORTAL_FRAME_WEST);
	public enum activeEndPortalFrameWest = _.ACTIVE_END_PORTAL_FRAME_WEST.id;
	
	public alias ActiveEndPortalFrameNorth = SimpleBlock!(_.ACTIVE_END_PORTAL_FRAME_NORTH);
	public enum activeEndPortalFrameNorth = _.ACTIVE_END_PORTAL_FRAME_NORTH.id;
	
	public alias ActiveEndPortalFrameEast = SimpleBlock!(_.ACTIVE_END_PORTAL_FRAME_EAST);
	public enum activeEndPortalFrameEast = _.ACTIVE_END_PORTAL_FRAME_EAST.id;

	public enum activeEndPortalFrame = [activeEndPortalFrameSouth, activeEndPortalFrameWest, activeEndPortalFrameNorth, activeEndPortalFrameEast];

	public enum endPortalFrame = inactiveEndPortalFrame ~ activeEndPortalFrame;

	public alias EndStone = MineableBlock!(_.END_STONE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.endStone, 1));
	public enum endStone = _.END_STONE.id;

	public alias EndStoneBricks = MineableBlock!(_.END_STONE_BRICKS, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.endStoneBricks, 1));
	public enum endStoneBricks = _.END_STONE_BRICKS.id;

	public alias EndPortal = SimpleBlock!(_.END_PORTAL); //TODO teleport to end dimension
	public enum endPortal = _.END_PORTAL.id;

	public enum endGateway = _.END_GATEWAY.id;

	public enum dragonEgg = _.DRAGON_EGG.id;

	public enum inactiveRedstoneLamp = _.REDSTONE_LAMP.id;

	public enum activeRedstoneLamp = _.ACTIVE_REDSTONE_LAMP.id;

	public enum redstoneLamp = [inactiveRedstoneLamp, activeRedstoneLamp];
	
	public alias CocoaNorth0 = BeansBlock!(_.COCOA_NORTH_0, cocoaNorth1, Facing.south, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaNorth0 = _.COCOA_NORTH_0.id;
	
	public alias CocoaEast0 = BeansBlock!(_.COCOA_EAST_0, cocoaNorth1, Facing.west, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaEast0 = _.COCOA_EAST_0.id;
	
	public alias CocoaSouth0 = BeansBlock!(_.COCOA_SOUTH_0, cocoaNorth1, Facing.north, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaSouth0 = _.COCOA_SOUTH_0.id;
	
	public alias CocoaWest0 = BeansBlock!(_.COCOA_WEST_0, cocoaNorth1, Facing.east, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaWest0 = _.COCOA_WEST_0.id;
	
	public enum cocoa0 = [cocoaNorth0, cocoaEast0, cocoaSouth0, cocoaWest0];
	
	public alias CocoaNorth1 = BeansBlock!(_.COCOA_NORTH_1, cocoaNorth2, Facing.south, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaNorth1 = _.COCOA_NORTH_1.id;
	
	public alias CocoaEast1 = BeansBlock!(_.COCOA_EAST_1, cocoaNorth2, Facing.west, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaEast1 = _.COCOA_EAST_1.id;
	
	public alias CocoaSouth1 = BeansBlock!(_.COCOA_SOUTH_1, cocoaNorth2, Facing.north, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaSouth1 = _.COCOA_SOUTH_1.id;
	
	public alias CocoaWest1 = BeansBlock!(_.COCOA_WEST_1, cocoaNorth2, Facing.east, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1));
	public enum cocoaWest1 = _.COCOA_WEST_1.id;
	
	public enum cocoa1 = [cocoaNorth1, cocoaEast1, cocoaSouth1, cocoaWest1];
	
	public alias CocoaNorth2 = BeansBlock!(_.COCOA_NORTH_2, 0, Facing.south, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3));
	public enum cocoaNorth2 = _.COCOA_NORTH_2.id;
	
	public alias CocoaEast2 = BeansBlock!(_.COCOA_EAST_2, 0, Facing.west, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3));
	public enum cocoaEast2 = _.COCOA_EAST_2.id;
	
	public alias CocoaSouth2 = BeansBlock!(_.COCOA_SOUTH_2, 0, Facing.north, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3));
	public enum cocoaSouth2 = _.COCOA_SOUTH_2.id;
	
	public alias CocoaWest2 = BeansBlock!(_.COCOA_WEST_2, 0, Facing.east, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3));
	public enum cocoaWest2 = _.COCOA_WEST_2.id;
	
	public enum cocoa2 = [cocoaNorth2, cocoaEast2, cocoaSouth2, cocoaWest2];

	public enum cocoa = cocoa0 ~ cocoa1 ~ cocoa2;
	
	public enum tripwireHookFacingSouth = _.TRIPWIRE_HOOK_FACING_SOUTH.id;
	
	public enum tripwireHookFacingWest = _.TRIPWIRE_HOOK_FACING_WEST.id;
	
	public enum tripwireHookFacingNorth = _.TRIPWIRE_HOOK_FACING_NORTH.id;
	
	public enum tripwireHookFacingEast = _.TRIPWIRE_HOOK_FACING_EAST.id;
	
	public enum unconnectedTripwireHook = [tripwireHookFacingSouth, tripwireHookFacingWest, tripwireHookFacingNorth, tripwireHookFacingEast];

	public enum connectedTripwireHookFacingSouth = _.CONNECTED_TRIPWIRE_HOOK_FACING_SOUTH.id;
	
	public enum connectedTripwireHookFacingWest = _.CONNECTED_TRIPWIRE_HOOK_FACING_WEST.id;
	
	public enum connectedTripwireHookFacingNorth = _.CONNECTED_TRIPWIRE_HOOK_FACING_NORTH.id;
	
	public enum connectedTripwireHookFacingEast = _.CONNECTED_TRIPWIRE_HOOK_FACING_EAST.id;
	
	public enum connectedTripwireHook = [connectedTripwireHookFacingSouth, connectedTripwireHookFacingWest, connectedTripwireHookFacingNorth, connectedTripwireHookFacingEast];

	public enum poweredTripwireHookFacingSouth = _.POWERED_TRIPWIRE_HOOK_FACING_SOUTH.id;
	
	public enum poweredTripwireHookFacingWest = _.POWERED_TRIPWIRE_HOOK_FACING_WEST.id;
	
	public enum poweredTripwireHookFacingNorth = _.POWERED_TRIPWIRE_HOOK_FACING_NORTH.id;
	
	public enum poweredTripwireHookFacingEast = _.POWERED_TRIPWIRE_HOOK_FACING_EAST.id;
	
	public enum poweredTripwireHook = [poweredTripwireHookFacingSouth, poweredTripwireHookFacingWest, poweredTripwireHookFacingNorth, poweredTripwireHookFacingEast];

	public enum tripwireHook = unconnectedTripwireHook ~ connectedTripwireHook ~ poweredTripwireHook;

	public enum poweredTripwire = _.POWERED_TRIPWIRE.id;

	public enum connectedTripwire = _.CONNECTED_TRIPWIRE.id;

	public enum unconnectedTripwire = _.TRIPWIRE.id;

	public enum tripwire = [unconnectedTripwire, connectedTripwire, poweredTripwire];
	
	public enum commandBlockFacingDown = _.COMMAND_BLOCK_FACING_DOWN.id;
	
	public enum commandBlockFacingUp = _.COMMAND_BLOCK_FACING_UP.id;
	
	public enum commandBlockFacingNorth = _.COMMAND_BLOCK_FACING_NORTH.id;
	
	public enum commandBlockFacingSouth = _.COMMAND_BLOCK_FACING_SOUTH.id;
	
	public enum commandBlockFacingWest = _.COMMAND_BLOCK_FACING_WEST.id;
	
	public enum commandBlockFacingEast = _.COMMAND_BLOCK_FACING_EAST.id;
	
	public enum unconditionalCommandBlock = [commandBlockFacingDown, commandBlockFacingUp, commandBlockFacingNorth, commandBlockFacingSouth, commandBlockFacingWest, commandBlockFacingEast];

	public enum conditionalCommandBlockFacingDown = _.CONDITIONAL_COMMAND_BLOCK_FACING_DOWN.id;
	
	public enum conditionalCommandBlockFacingUp = _.CONDITIONAL_COMMAND_BLOCK_FACING_UP.id;
	
	public enum conditionalCommandBlockFacingNorth = _.CONDITIONAL_COMMAND_BLOCK_FACING_NORTH.id;
	
	public enum conditionalCommandBlockFacingSouth = _.CONDITIONAL_COMMAND_BLOCK_FACING_SOUTH.id;
	
	public enum conditionalCommandBlockFacingWest = _.CONDITIONAL_COMMAND_BLOCK_FACING_WEST.id;
	
	public enum conditionalCommandBlockFacingEast = _.CONDITIONAL_COMMAND_BLOCK_FACING_EAST.id;
	
	public enum conditionalCommandBlock = [conditionalCommandBlockFacingDown, conditionalCommandBlockFacingUp, conditionalCommandBlockFacingNorth, conditionalCommandBlockFacingSouth, conditionalCommandBlockFacingWest, conditionalCommandBlockFacingEast];

	public enum commandBlock = unconditionalCommandBlock ~ conditionalCommandBlock;
	
	public enum repeatingCommandBlockFacingDown = _.REPEATING_COMMAND_BLOCK_FACING_DOWN.id;
	
	public enum repeatingCommandBlockFacingUp = _.REPEATING_COMMAND_BLOCK_FACING_UP.id;
	
	public enum repeatingCommandBlockFacingNorth = _.REPEATING_COMMAND_BLOCK_FACING_NORTH.id;
	
	public enum repeatingCommandBlockFacingSouth = _.REPEATING_COMMAND_BLOCK_FACING_SOUTH.id;
	
	public enum repeatingCommandBlockFacingWest = _.REPEATING_COMMAND_BLOCK_FACING_WEST.id;
	
	public enum repeatingCommandBlockFacingEast = _.REPEATING_COMMAND_BLOCK_FACING_EAST.id;
	
	public enum repeatingUnconditionalCommandBlock = [repeatingCommandBlockFacingDown, repeatingCommandBlockFacingUp, repeatingCommandBlockFacingNorth, repeatingCommandBlockFacingSouth, repeatingCommandBlockFacingWest, repeatingCommandBlockFacingEast];
	
	public enum repeatingConditionalCommandBlockFacingDown = _.CONDITIONAL_REPEATING_COMMAND_BLOCK_FACING_DOWN.id;
	
	public enum repeatingConditionalCommandBlockFacingUp = _.CONDITIONAL_REPEATING_COMMAND_BLOCK_FACING_UP.id;
	
	public enum repeatingConditionalCommandBlockFacingNorth = _.CONDITIONAL_REPEATING_COMMAND_BLOCK_FACING_NORTH.id;
	
	public enum repeatingConditionalCommandBlockFacingSouth = _.CONDITIONAL_REPEATING_COMMAND_BLOCK_FACING_SOUTH.id;
	
	public enum repeatingConditionalCommandBlockFacingWest = _.CONDITIONAL_REPEATING_COMMAND_BLOCK_FACING_WEST.id;
	
	public enum repeatingConditionalCommandBlockFacingEast = _.CONDITIONAL_REPEATING_COMMAND_BLOCK_FACING_EAST.id;
	
	public enum repeatingConditionalCommandBlock = [repeatingConditionalCommandBlockFacingDown, repeatingConditionalCommandBlockFacingUp, repeatingConditionalCommandBlockFacingNorth, repeatingConditionalCommandBlockFacingSouth, repeatingConditionalCommandBlockFacingWest, repeatingConditionalCommandBlockFacingEast];
	
	public enum repeatingCommandBlock = repeatingUnconditionalCommandBlock ~ repeatingConditionalCommandBlock;
	
	public enum chainCommandBlockFacingDown = _.CHAIN_COMMAND_BLOCK_FACING_DOWN.id;
	
	public enum chainCommandBlockFacingUp = _.CHAIN_COMMAND_BLOCK_FACING_UP.id;
	
	public enum chainCommandBlockFacingNorth = _.CHAIN_COMMAND_BLOCK_FACING_NORTH.id;
	
	public enum chainCommandBlockFacingSouth = _.CHAIN_COMMAND_BLOCK_FACING_SOUTH.id;
	
	public enum chainCommandBlockFacingWest = _.CHAIN_COMMAND_BLOCK_FACING_WEST.id;
	
	public enum chainCommandBlockFacingEast = _.CHAIN_COMMAND_BLOCK_FACING_EAST.id;
	
	public enum chainUnconditionalCommandBlock = [chainCommandBlockFacingDown, chainCommandBlockFacingUp, chainCommandBlockFacingNorth, chainCommandBlockFacingSouth, chainCommandBlockFacingWest, chainCommandBlockFacingEast];
	
	public enum chainConditionalCommandBlockFacingDown = _.CONDITIONAL_CHAIN_COMMAND_BLOCK_FACING_DOWN.id;
	
	public enum chainConditionalCommandBlockFacingUp = _.CONDITIONAL_CHAIN_COMMAND_BLOCK_FACING_UP.id;
	
	public enum chainConditionalCommandBlockFacingNorth = _.CONDITIONAL_CHAIN_COMMAND_BLOCK_FACING_NORTH.id;
	
	public enum chainConditionalCommandBlockFacingSouth = _.CONDITIONAL_CHAIN_COMMAND_BLOCK_FACING_SOUTH.id;
	
	public enum chainConditionalCommandBlockFacingWest = _.CONDITIONAL_CHAIN_COMMAND_BLOCK_FACING_WEST.id;
	
	public enum chainConditionalCommandBlockFacingEast = _.CONDITIONAL_CHAIN_COMMAND_BLOCK_FACING_EAST.id;
	
	public enum chainConditionalCommandBlock = [chainConditionalCommandBlockFacingDown, chainConditionalCommandBlockFacingUp, chainConditionalCommandBlockFacingNorth, chainConditionalCommandBlockFacingSouth, chainConditionalCommandBlockFacingWest, chainConditionalCommandBlockFacingEast];
	
	public enum chainCommandBlock = chainUnconditionalCommandBlock ~ chainConditionalCommandBlock;

	public enum beacon = _.BEACON.id;

	public alias FlowerPot = FlowerPotTile!(_.FLOWER_POT);
	public enum flowerPot = _.FLOWER_POT.id;

	public enum mobHeadFloor = _.MOB_HEAD_FLOOR.id;
	
	public enum mobHeadFacingNorth = _.MOB_HEAD_FACING_NORTH.id;
	
	public enum mobHeadFacingSouth = _.MOB_HEAD_FACING_SOUTH.id;
	
	public enum mobHeadFacingEast = _.MOB_HEAD_FACING_EAST.id;
	
	public enum mobHeadFacingWest = _.MOB_HEAD_FACING_WEST.id;

	public enum mobHead = [mobHeadFloor, mobHeadFacingNorth, mobHeadFacingSouth, mobHeadFacingEast, mobHeadFacingWest];

	public enum anvilNorthSouth = _.ANVIL_NORTH_SOUTH.id;
	
	public enum anvilEastWest = _.ANVIL_EAST_WEST.id;
	
	public enum anvilSouthNorth = _.ANVIL_SOUTH_NORTH.id;
	
	public enum anvilWestEast = _.ANVIL_WEST_EAST.id;
	
	public enum undamagedAnvil = [anvilNorthSouth, anvilEastWest, anvilSouthNorth, anvilWestEast];

	public enum slightlyDamagedAnvilNorthSouth = _.SLIGHTLY_DAMAGED_ANVIL_NORTH_SOUTH.id;
	
	public enum slightlyDamagedAnvilEastWest = _.SLIGHTLY_DAMAGED_ANVIL_EAST_WEST.id;
	
	public enum slightlyDamagedAnvilSouthNorth = _.SLIGHTLY_DAMAGED_ANVIL_SOUTH_NORTH.id;
	
	public enum slightlyDamagedAnvilWestEast = _.SLIGHTLY_DAMAGED_ANVIL_WEST_EAST.id;
	
	public enum slightlyDamagedAnvil = [slightlyDamagedAnvilNorthSouth, slightlyDamagedAnvilEastWest, slightlyDamagedAnvilSouthNorth, slightlyDamagedAnvilWestEast];

	public enum veryDamagedAnvilNorthSouth = _.VERY_DAMAGED_ANVIL_NORTH_SOUTH.id;
	
	public enum veryDamagedAnvilEastWest = _.VERY_DAMAGED_ANVIL_EAST_WEST.id;
	
	public enum veryDamagedAnvilSouthNorth = _.VERY_DAMAGED_ANVIL_SOUTH_NORTH.id;
	
	public enum veryDamagedAnvilWestEast = _.VERY_DAMAGED_ANVIL_WEST_EAST.id;
	
	public enum veryDamagedAnvil = [veryDamagedAnvilNorthSouth, veryDamagedAnvilEastWest, veryDamagedAnvilSouthNorth, veryDamagedAnvilWestEast];

	public enum anvil = undamagedAnvil ~ slightlyDamagedAnvil ~ veryDamagedAnvil;

	public alias LilyPad = MineableBlock!(_.LILY_PAD, MiningTool.init, Drop(Items.lilyPad, 1)); //TODO drop when the block underneath is not water nor ice
	public enum lilyPad = _.LILY_PAD.id;

	public enum comparatorFacingNorth = _.COMPARATOR_FACING_NORTH.id;
	
	public enum comparatorFacingEast = _.COMPARATOR_FACING_EAST.id;
	
	public enum comparatorFacingSouth = _.COMPARATOR_FACING_SOUTH.id;
	
	public enum comparatorFacingWest = _.COMPARATOR_FACING_WEST.id;
	
	public enum comparatorSubstractionModeFacingNorth = _.COMPARATOR_SUBSTRACTION_MODE_FACING_NORTH.id;
	
	public enum comparatorSubstractionModeFacingEast = _.COMPARATOR_SUBSTRACTION_MODE_FACING_EAST.id;
	
	public enum comparatorSubstractionModeFacingSouth = _.COMPARATOR_SUBSTRACTION_MODE_FACING_SOUTH.id;
	
	public enum comparatorSubstractionModeFacingWest = _.COMPARATOR_SUBSTRACTION_MODE_FACING_WEST.id;
	
	public enum unpoweredComparator = [comparatorFacingNorth, comparatorFacingEast, comparatorFacingSouth, comparatorFacingWest, comparatorSubstractionModeFacingNorth, comparatorSubstractionModeFacingEast, comparatorSubstractionModeFacingSouth, comparatorSubstractionModeFacingWest];

	public enum poweredComparatorFacingNorth = _.POWERED_COMPARATOR_FACING_NORTH.id;
	
	public enum poweredComparatorFacingEast = _.POWERED_COMPARATOR_FACING_EAST.id;
	
	public enum poweredComparatorFacingSouth = _.POWERED_COMPARATOR_FACING_SOUTH.id;
	
	public enum poweredComparatorFacingWest = _.POWERED_COMPARATOR_FACING_WEST.id;
	
	public enum poweredComparatorSubstractionModeFacingNorth = _.POWERED_COMPARATOR_SUBSTRACTION_MODE_FACING_NORTH.id;
	
	public enum poweredComparatorSubstractionModeFacingEast = _.POWERED_COMPARATOR_SUBSTRACTION_MODE_FACING_EAST.id;
	
	public enum poweredComparatorSubstractionModeFacingSouth = _.POWERED_COMPARATOR_SUBSTRACTION_MODE_FACING_SOUTH.id;
	
	public enum poweredComparatorSubstractionModeFacingWest = _.POWERED_COMPARATOR_SUBSTRACTION_MODE_FACING_WEST.id;
	
	public enum poweredComparator = [poweredComparatorFacingNorth, poweredComparatorFacingEast, poweredComparatorFacingSouth, poweredComparatorFacingWest, poweredComparatorSubstractionModeFacingNorth, poweredComparatorSubstractionModeFacingEast, poweredComparatorSubstractionModeFacingSouth, poweredComparatorSubstractionModeFacingWest];

	public enum daylightSensor0 = _.DAYLIGHT_SENSOR_0.id;
	
	public enum daylightSensor1 = _.DAYLIGHT_SENSOR_1.id;
	
	public enum daylightSensor2 = _.DAYLIGHT_SENSOR_2.id;
	
	public enum daylightSensor3 = _.DAYLIGHT_SENSOR_3.id;
	
	public enum daylightSensor4 = _.DAYLIGHT_SENSOR_4.id;
	
	public enum daylightSensor5 = _.DAYLIGHT_SENSOR_5.id;
	
	public enum daylightSensor6 = _.DAYLIGHT_SENSOR_6.id;
	
	public enum daylightSensor7 = _.DAYLIGHT_SENSOR_7.id;
	
	public enum daylightSensor8 = _.DAYLIGHT_SENSOR_8.id;
	
	public enum daylightSensor9 = _.DAYLIGHT_SENSOR_9.id;
	
	public enum daylightSensor10 = _.DAYLIGHT_SENSOR_10.id;
	
	public enum daylightSensor11 = _.DAYLIGHT_SENSOR_11.id;
	
	public enum daylightSensor12 = _.DAYLIGHT_SENSOR_12.id;
	
	public enum daylightSensor13 = _.DAYLIGHT_SENSOR_13.id;
	
	public enum daylightSensor14 = _.DAYLIGHT_SENSOR_14.id;
	
	public enum daylightSensor15 = _.DAYLIGHT_SENSOR_15.id;
	
	public enum daylightSensor = [daylightSensor0, daylightSensor1, daylightSensor2, daylightSensor3, daylightSensor4, daylightSensor5, daylightSensor6, daylightSensor7, daylightSensor8, daylightSensor9, daylightSensor10, daylightSensor11, daylightSensor12, daylightSensor13, daylightSensor14, daylightSensor15];

	public enum invertedDaylightSensor0 = _.INVERTED_DAYLIGHT_SENSOR_0.id;
	
	public enum invertedDaylightSensor1 = _.INVERTED_DAYLIGHT_SENSOR_1.id;
	
	public enum invertedDaylightSensor2 = _.INVERTED_DAYLIGHT_SENSOR_2.id;
	
	public enum invertedDaylightSensor3 = _.INVERTED_DAYLIGHT_SENSOR_3.id;
	
	public enum invertedDaylightSensor4 = _.INVERTED_DAYLIGHT_SENSOR_4.id;
	
	public enum invertedDaylightSensor5 = _.INVERTED_DAYLIGHT_SENSOR_5.id;
	
	public enum invertedDaylightSensor6 = _.INVERTED_DAYLIGHT_SENSOR_6.id;
	
	public enum invertedDaylightSensor7 = _.INVERTED_DAYLIGHT_SENSOR_7.id;
	
	public enum invertedDaylightSensor8 = _.INVERTED_DAYLIGHT_SENSOR_8.id;
	
	public enum invertedDaylightSensor9 = _.INVERTED_DAYLIGHT_SENSOR_9.id;
	
	public enum invertedDaylightSensor10 = _.INVERTED_DAYLIGHT_SENSOR_10.id;
	
	public enum invertedDaylightSensor11 = _.INVERTED_DAYLIGHT_SENSOR_11.id;
	
	public enum invertedDaylightSensor12 = _.INVERTED_DAYLIGHT_SENSOR_12.id;
	
	public enum invertedDaylightSensor13 = _.INVERTED_DAYLIGHT_SENSOR_13.id;
	
	public enum invertedDaylightSensor14 = _.INVERTED_DAYLIGHT_SENSOR_14.id;
	
	public enum invertedDaylightSensor15 = _.INVERTED_DAYLIGHT_SENSOR_15.id;
	
	public enum invertedDaylightSensor = [invertedDaylightSensor0, invertedDaylightSensor1, invertedDaylightSensor2, invertedDaylightSensor3, invertedDaylightSensor4, invertedDaylightSensor5, invertedDaylightSensor6, invertedDaylightSensor7, invertedDaylightSensor8, invertedDaylightSensor9, invertedDaylightSensor10, invertedDaylightSensor11, invertedDaylightSensor12, invertedDaylightSensor13, invertedDaylightSensor14, invertedDaylightSensor15];

	public enum hopperOutputFacingDown = _.HOPPER_OUTPUT_FACING_DOWN.id;
	
	public enum hopperOutputFacingNorth = _.HOPPER_OUTPUT_FACING_NORTH.id;
	
	public enum hopperOutputFacingSouth = _.HOPPER_OUTPUT_FACING_SOUTH.id;
	
	public enum hopperOutputFacingWest = _.HOPPER_OUTPUT_FACING_WEST.id;
	
	public enum hopperOutputFacingEast = _.HOPPER_OUTPUT_FACING_EAST.id;

	public enum hopper = [hopperOutputFacingDown, hopperOutputFacingNorth, hopperOutputFacingSouth, hopperOutputFacingWest, hopperOutputFacingEast];

	public alias QuartzBlock = MineableBlock!(_.QUARTZ_BLOCK, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.quartzBlock, 1));
	public enum quartzBlock = _.QUARTZ_BLOCK.id;
	
	public alias ChiseledQuartzBlock = MineableBlock!(_.CHISELED_QUARTZ_BLOCK, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.chiseledQuartzBlock, 1));
	public enum chiseledQuartzBlock = _.CHISELED_QUARTZ_BLOCK.id;
	
	public alias PillarQuartzBlockVertical = MineableBlock!(_.PILLAR_QUARTZ_BLOCK_VERTICAL, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1));
	public enum pillarQuartzBlockVertical = _.PILLAR_QUARTZ_BLOCK_VERTICAL.id;
	
	public alias PillarQuartzBlockNorthSouth = MineableBlock!(_.PILLAR_QUARTZ_BLOCK_NORTH_SOUTH, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1));
	public enum pillarQuartzBlockNorthSouth = _.PILLAR_QUARTZ_BLOCK_NORTH_SOUTH.id;
	
	public alias PillarQuartzBlockEastWest = MineableBlock!(_.PILLAR_QUARTZ_BLOCK_EAST_WEST, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1));
	public enum pillarQuartzBlockEastWest = _.PILLAR_QUARTZ_BLOCK_EAST_WEST.id;

	public enum pillarQuartzBlock = [pillarQuartzBlockVertical, pillarQuartzBlockNorthSouth, pillarQuartzBlockEastWest];

	public enum slimeBlock = _.SLIME_BLOCK.id;

	public alias Barrier = SimpleBlock!(_.BARRIER);
	public enum barrier = _.BARRIER.id;
	public enum invisibleBedrock = barrier;
	
	public alias Prismarine = MineableBlock!(_.PRISMARINE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.prismarine, 1));
	public enum prismarine = _.PRISMARINE.id;
	
	public alias PrismarineBricks = MineableBlock!(_.PRISMARINE_BRICKS, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.prismarineBricks, 1));
	public enum prismarineBricks = _.PRISMARINE_BRICKS.id;
	
	public alias DarkPrismarine = MineableBlock!(_.DARK_PRISMARINE, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.darkPrismarine, 1));
	public enum darkPrismarine = _.DARK_PRISMARINE.id;

	public alias SeaLantern = MineableBlock!(_.SEA_LANTERN, MiningTool.init, Drop(Items.prismarineCrystals, 2, 3, Items.seaLantern)); //TODO fortune
	public enum seaLantern = _.SEA_LANTERN.id;
	
	public alias HayBaleVertical = MineableBlock!(_.HAY_BALE_VERTICAL, MiningTool.init, Drop(Items.hayBale, 1));
	public enum hayBaleVertical = _.HAY_BALE_VERTICAL.id;
	
	public alias HayBaleEastWest = MineableBlock!(_.HAY_BALE_EAST_WEST, MiningTool.init, Drop(Items.hayBale, 1));
	public enum hayBaleEastWest = _.HAY_BALE_EAST_WEST.id;
	
	public alias HayBaleNorthSouth = MineableBlock!(_.HAY_BALE_NORTH_SOUTH, MiningTool.init, Drop(Items.hayBale, 1));
	public enum hayBaleNorthSouth = _.HAY_BALE_NORTH_SOUTH.id;

	public enum hayBale = [hayBaleVertical, hayBaleEastWest, hayBaleNorthSouth];

	public enum bannerFacingSouth = _.BANNER_FACING_SOUTH.id;

	public enum bannerFacingSouthSouthwest = _.BANNER_FACING_SOUTH_SOUTHWEST.id;

	public enum bannerFacingSouthwest = _.BANNER_FACING_SOUTHWEST.id;

	public enum bannerFacingWestWestsouth = _.BANNER_FACING_WEST_WESTSOUTH.id;

	public enum bannerFacingWest = _.BANNER_FACING_WEST.id;

	public enum bannerFacingWestNorthwest = _.BANNER_FACING_WEST_NORTHWEST.id;

	public enum bannerFacingNorthwest = _.BANNER_FACING_NORTHWEST.id;

	public enum bannerFacingNorthNorthwest = _.BANNER_FACING_NORTH_NORTHWEST.id;

	public enum bannerFacingNorth = _.BANNER_FACING_NORTH.id;

	public enum bannerFacingNorthNortheast = _.BANNER_FACING_NORTH_NORTHEAST.id;

	public enum bannerFacingNortheast = _.BANNER_FACING_NORTHEAST.id;

	public enum bannerFacingEastNortheast = _.BANNER_FACING_EAST_NORTHEAST.id;

	public enum bannerFacingEast = _.BANNER_FACING_EAST.id;

	public enum bannerFacingEastSoutheast = _.BANNER_FACING_EAST_SOUTHEAST.id;

	public enum bannerFacingSoutheast = _.BANNER_FACING_SOUTHEAST.id;

	public enum bannerFacingSouthSoutheast = _.BANNER_FACING_SOUTH_SOUTHEAST.id;
	
	public enum banner = [bannerFacingSouth, bannerFacingSouthSouthwest, bannerFacingSouthwest, bannerFacingWestWestsouth, bannerFacingWest, bannerFacingWestNorthwest, bannerFacingNorthwest, bannerFacingNorthNorthwest, bannerFacingNorth, bannerFacingNorthNortheast, bannerFacingEastNortheast, bannerFacingEast, bannerFacingEastSoutheast, bannerFacingSoutheast, bannerFacingSouthSoutheast];

	public enum wallBannerFacingNorth = _.WALL_BANNER_FACING_NORTH.id;

	public enum wallBannerFacingSouth = _.WALL_BANNER_FACING_SOUTH.id;

	public enum wallBannerFacingWest = _.WALL_BANNER_FACING_WEST.id;

	public enum wallBannerFacingEast = _.WALL_BANNER_FACING_EAST.id;
	
	public enum wallBanner = [wallBannerFacingNorth, wallBannerFacingSouth, wallBannerFacingWest, wallBannerFacingEast];
	
	public enum itemFrameFacingNorth = _.ITEM_FRAME_FACING_NORTH.id;
	
	public enum itemFrameFacingSouth = _.ITEM_FRAME_FACING_SOUTH.id;
	
	public enum itemFrameFacingWest = _.ITEM_FRAME_FACING_WEST.id;
	
	public enum itemFrameFacingEast = _.ITEM_FRAME_FACING_EAST.id;

	public enum itemFrame = [itemFrameFacingNorth, itemFrameFacingSouth, itemFrameFacingWest, itemFrameFacingEast];
	
	public alias EndRodFacingDown = MineableBlock!(_.END_ROD_FACING_DOWN, MiningTool.init, Drop(Items.endRod, 1));
	public enum endRodFacingDown = _.END_ROD_FACING_DOWN.id;
	
	public alias EndRodFacingUp = MineableBlock!(_.END_ROD_FACING_UP, MiningTool.init, Drop(Items.endRod, 1));
	public enum endRodFacingUp = _.END_ROD_FACING_UP.id;
	
	public alias EndRodFacingNorth = MineableBlock!(_.END_ROD_FACING_NORTH, MiningTool.init, Drop(Items.endRod, 1));
	public enum endRodFacingNorth = _.END_ROD_FACING_NORTH.id;
	
	public alias EndRodFacingSouth = MineableBlock!(_.END_ROD_FACING_SOUTH, MiningTool.init, Drop(Items.endRod, 1));
	public enum endRodFacingSouth = _.END_ROD_FACING_SOUTH.id;
	
	public alias EndRodFacingWest = MineableBlock!(_.END_ROD_FACING_WEST, MiningTool.init, Drop(Items.endRod, 1));
	public enum endRodFacingWest = _.END_ROD_FACING_WEST.id;
	
	public alias EndRodFacingEast = MineableBlock!(_.END_ROD_FACING_EAST, MiningTool.init, Drop(Items.endRod, 1));
	public enum endRodFacingEast = _.END_ROD_FACING_EAST.id;

	public enum endRod = [endRodFacingDown, endRodFacingUp, endRodFacingNorth, endRodFacingSouth, endRodFacingWest, endRodFacingEast];

	public enum chorusPlant = _.CHORUS_PLANT.id;
	
	public enum chorusFlower0 = _.CHORUS_FLOWER_0.id;
	
	public enum chorusFlower1 = _.CHORUS_FLOWER_1.id;
	
	public enum chorusFlower2 = _.CHORUS_FLOWER_2.id;
	
	public enum chorusFlower3 = _.CHORUS_FLOWER_3.id;
	
	public enum chorusFlower4 = _.CHORUS_FLOWER_4.id;
	
	public enum chorusFlower5 = _.CHORUS_FLOWER_5.id;

	public enum chorusFlower = [chorusFlower0, chorusFlower1, chorusFlower2, chorusFlower3, chorusFlower4, chorusFlower5];

	public alias PurpurBlock = MineableBlock!(_.PURPUR_BLOCK, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurBlock, 1));
	public enum purpurBlock = _.PURPUR_BLOCK.id;
	
	public alias PurpurPillarVerical = MineableBlock!(_.PURPUR_PILLAR_VERTICAL, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1));
	public enum purpurPillarVertical = _.PURPUR_PILLAR_VERTICAL.id;
	
	public alias PurpurPillarEastWest = MineableBlock!(_.PURPUR_PILLAR_EAST_WEST, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1));
	public enum purpurPillarEastWest = _.PURPUR_PILLAR_EAST_WEST.id;
	
	public alias PurpurPillarNorthSouth = MineableBlock!(_.PURPUR_PILLAR_NORTH_SOUTH, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1));
	public enum purpurPillarNorthSouth = _.PURPUR_PILLAR_NORTH_SOUTH.id;

	public enum purpurPillar = [purpurPillarVertical, purpurPillarEastWest, purpurPillarNorthSouth];

	public enum magmaBlock = _.MAGMA_BLOCK.id;

	public alias NetherWartBlock = MineableBlock!(_.NETHER_WART_BLOCK, MiningTool.init, Drop(Items.netherWartBlock, 1));
	public enum netherWartBlock = _.NETHER_WART_BLOCK.id;
	
	public alias BoneBlockVertical = MineableBlock!(_.BONE_BLOCK_VERTICAL, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1));
	public enum boneBlockVertical = _.BONE_BLOCK_VERTICAL.id;
	
	public alias BoneBlockEastWest = MineableBlock!(_.BONE_BLOCK_EAST_WEST, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1));
	public enum boneBlockEastWest = _.BONE_BLOCK_EAST_WEST.id;
	
	public alias BoneBlockNorthSouth = MineableBlock!(_.BONE_BLOCK_NORTH_SOUTH, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1));
	public enum boneBlockNorthSouth = _.BONE_BLOCK_NORTH_SOUTH.id;

	public enum boneBlock = [boneBlockVertical, boneBlockEastWest, boneBlockNorthSouth];

	public alias StructureVoid = SimpleBlock!(_.STRUCTURE_VOID);
	public enum structureVoid = _.STRUCTURE_VOID.id;

	public enum whiteShulkerBox = _.WHITE_SHULKER_BOX.id;

	public enum orangeShulkerBox = _.ORANGE_SHULKER_BOX.id;

	public enum magentaShulkerBox = _.MAGENTA_SHULKER_BOX.id;

	public enum lightBlueShulkerBox = _.LIGHT_BLUE_SHULKER_BOX.id;

	public enum yellowShulkerBox = _.YELLOW_SHULKER_BOX.id;

	public enum limeShulkerBox = _.LIME_SHULKER_BOX.id;

	public enum pinkShulkerBox = _.PINK_SHULKER_BOX.id;

	public enum grayShulkerBox = _.GRAY_SHULKER_BOX.id;

	public enum lightGrayShulkerBox = _.LIGHT_GRAY_SHULKER_BOX.id;

	public enum cyanShulkerBox = _.CYAN_SHULKER_BOX.id;

	public enum purpleShulkerBox = _.PURPLE_SHULKER_BOX.id;

	public enum blueShulkerBox = _.BLUE_SHULKER_BOX.id;

	public enum brownShulkerBox = _.BROWN_SHULKER_BOX.id;

	public enum greenShulkerBox = _.GREEN_SHULKER_BOX.id;

	public enum redShulkerBox = _.RED_SHULKER_BOX.id;

	public enum blackShulkerBox = _.BLACK_SHULKER_BOX.id;
	
	public enum shulkerBox = [whiteShulkerBox, orangeShulkerBox, magentaShulkerBox, lightBlueShulkerBox, yellowShulkerBox, limeShulkerBox, pinkShulkerBox, grayShulkerBox, lightGrayShulkerBox, cyanShulkerBox, purpleShulkerBox, blueShulkerBox, brownShulkerBox, greenShulkerBox, redShulkerBox, blackShulkerBox];

	public alias UpdateBlock = SimpleBlock!(_.UPDATE_BLOCK);
	public enum updateBlock = _.UPDATE_BLOCK.id;

	public alias AteupdBlock = SimpleBlock!(_.ATEUPD_BLOCK);
	public enum ateupdBlock = _.ATEUPD_BLOCK.id;
	
	public enum structureBlockSave = _.STRUCTURE_BLOCK_SAVE.id;
	
	public enum structureBlockLoad = _.STRUCTURE_BLOCK_LOAD.id;
	
	public enum structureBlockCorner = _.STRUCTURE_BLOCK_CORNER.id;
	
	public enum structureBlockData = _.STRUCTURE_BLOCK_DATA.id;

}

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

	private enum __ids = bytegroup(sb.pocket ? sb.pocket.id : _.UPDATE_BLOCK.pocket.id, sb.minecraft ? sb.minecraft.id : 0);

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
