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
module sel.block.blocks;

import com.sel;

import sel.block.block : Block;
import sel.block.farming;
import sel.block.fluid;
import sel.block.miscellaneous;
import sel.block.redstone;
import sel.block.solid;
import sel.block.tile;
import sel.item.items : Items;
import sel.item.tool : Tools;

/**
 * Storage for a world's blocks.
 */
public class BlockStorage {

	private static BlockStorage instance;
	
	private Block[] sel;
	private Block*[][256] minecraft, pocket;
	
	public this() {
		if(instance is null) {
			foreach_reverse(block ; instantiateDefaultBlocks()) {
				this.register(block);
			}
			foreach(immutable member ; __traits(allMembers, Tiles)) {
				mixin("alias T = Tiles." ~ member ~ ";");
				this.registerTile!T(new T());
			}
			instance = this;
		} else {
			this.sel = instance.sel.dup;
			this.minecraft = instance.minecraft.dup;
			this.pocket = instance.pocket.dup;
		}
	}
	
	public void register(Block block) {
		if(block !is null) {
			if(this.sel.length <= block.id) this.sel.length = block.id + 1;
			this.sel[block.id] = block;
			auto pointer = &this.sel[block.id];
			if(block.minecraft) {
				if(this.minecraft[block.minecraftId].length <= block.minecraftMeta) this.minecraft[block.minecraftId].length = block.minecraftMeta + 1;
				this.minecraft[block.minecraftId][block.minecraftMeta] = pointer;
			}
			if(block.pocket) {
				if(this.minecraft[block.pocketId].length <= block.pocketMeta) this.minecraft[block.pocketId].length = block.pocketMeta + 1;
				this.minecraft[block.pocketId][block.pocketMeta] = pointer;
			}
		}
	}

	public void registerTile(T:Tile)(T tile) {
		this.register(tile);
		//TODO register tile data
	}

	/**
	 * Gets a block using its sel-id.
	 * This method only takes an argument as SEL blocks
	 * are identified by a single number instead of an id and
	 * optional metadata as in Minecraft and Minecraft: Pocket Edition.
	 * Example:
	 * ---
	 * auto block = 1 in blocks;
	 * assert(block.name == "stone");
	 * assert(blocks[Blocks.grass].name == "grass");
	 * ---
	 */
	public @safe Block* opBinaryRight(string op : "in")(block_t id) {
		if(id < this.sel.length) {
			auto ret = &this.sel[id];
			if(*ret !is null) return ret;
		}
		return null;
	}

	/// ditto
	public @safe Block* opIndex(block_t id) {
		return id in this;
	}

	/**
	 * Gets a block with the id used in Minecraft.
	 * Example:
	 * ---
	 * auto block = blocks.fromMinecraft(217);
	 * assert(block.name == "structure void");
	 * assert(blocks.fromMinecraft(248) is null);
	 * ---
	 */
	public @safe Block* fromMinecraft(ubyte id, ubyte meta=0) {
		auto data = this.minecraft[id];
		if(data.length > meta) return data[meta];
		else return null;
	}

	/**
	 * Gets a block with the id used in Minecraft: Pocket Edition.
	 * Example:
	 * ---
	 * auto block = blocks.fromPocket(33, 2);
	 * assert(block && block.name == "piston facing north");
	 * assert(blocks.fromPocket(255) is null); // structure block
	 * ---
	 */
	public @safe Block* fromPocket(ubyte id, ubyte meta=0) {
		auto data = this.pocket[id];
		if(data.length > meta) return data[meta];
		else return null;
	}

	public pure nothrow @property @safe @nogc size_t length() {
		return this.sel.length;
	}

	private static Block[] instantiateDefaultBlocks() {

		return [
			new Block(Blocks.air),
			new StoneBlock(Blocks.stone, Items.cobblestone, Items.stone),
			new StoneBlock(Blocks.granite, Items.granite),
			new StoneBlock(Blocks.polishedGranite, Items.polishedGranite),
			new StoneBlock(Blocks.diorite, Items.diorite),
			new StoneBlock(Blocks.polishedDiorite, Items.polishedDiorite),
			new StoneBlock(Blocks.andesite, Items.andesite),
			new StoneBlock(Blocks.polishedAndesite, Items.polishedAndesite),
			new StoneBlock(Blocks.stoneBricks, Items.stoneBricks),
			new StoneBlock(Blocks.mossyStoneBricks, Items.mossyStoneBricks),
			new StoneBlock(Blocks.crackedStoneBricks, Items.crackedStoneBricks),
			new StoneBlock(Blocks.chiseledStoneBricks, Items.chiseledStoneBricks),
			new StoneBlock(Blocks.cobblestone, Items.cobblestone),
			new StoneBlock(Blocks.mossStone, Items.mossStone),
			new StoneBlock(Blocks.cobblestoneWall, Items.cobblestoneWall),
			new StoneBlock(Blocks.mossyCobblestoneWall, Items.mossyCobblestoneWall),
			new StoneBlock(Blocks.bricks, Items.bricks),
			new MineableBlock(Blocks.coalOre, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.coal, 1, 1, Items.coalOre, &Drop.plusOne), Experience(0, 2)),
			new MineableBlock(Blocks.ironOre, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.ironOre, 1)),
			new MineableBlock(Blocks.goldOre, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.goldOre, 1)),
			new MineableBlock(Blocks.diamondOre, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.diamond, 1, 1, Items.diamondOre)), //TODO +1 with fortune
			new MineableBlock(Blocks.emeraldOre, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.emerald, 1, 1, Items.emeraldOre)), //TODO +1 with fortune
			new MineableBlock(Blocks.lapisLazuliOre, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.lapisLazuli, 4, 8, Items.lapisLazuliOre), Experience(2, 5)), //TODO fortune
			new RedstoneOreBlock!false(Blocks.redstoneOre, Blocks.litRedstoneOre),
			new RedstoneOreBlock!true(Blocks.litRedstoneOre, Blocks.redstoneOre),
			new MineableBlock(Blocks.netherQuartzOre, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherQuartz, 2, 5, Items.netherQuartzOre), Experience(2, 5, 1)), //TODO fortune
			new MineableBlock(Blocks.coalBlock, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.coalBlock, 1)),
			new MineableBlock(Blocks.ironBlock, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.ironBlock, 1)),
			new MineableBlock(Blocks.goldBlock, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.goldBlock, 1)),
			new MineableBlock(Blocks.diamondBlock, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.diamondBlock, 1)),
			new MineableBlock(Blocks.emeraldBlock, MiningTool(true, Tools.pickaxe, Tools.iron), Drop(Items.emeraldBlock, 1)),
			new MineableBlock(Blocks.redstoneBlock, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redstoneBlock, 1)),
			new MineableBlock(Blocks.lapisLazuliOre, MiningTool(true, Tools.pickaxe, Tools.stone), Drop(Items.lapisLazuliBlock, 1)),
			new MineableBlock(Blocks.netherReactorCore, MiningTool(true, Tools.pickaxe, Tools.wood), [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]),
			new MineableBlock(Blocks.activeNetherReactorCore, MiningTool(true, Tools.pickaxe, Tools.wood), [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]),
			new MineableBlock(Blocks.usedNetherReactorCore, MiningTool(true, Tools.pickaxe, Tools.wood), [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]),
			new SuffocatingSpreadingBlock(Blocks.grass, MiningTool(false, Tools.shovel, Tools.wood), [Drop(Items.dirt, 1, 1, Items.grass)], [Blocks.dirt], 1, 1, 2, 2, Blocks.dirt),
			new MineableBlock(Blocks.dirt, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1)),
			new MineableBlock(Blocks.coarseDirt, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1)),
			new MineableBlock(Blocks.podzol, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1, 1, Items.podzol)),
			new SpreadingBlock(Blocks.mycelium, MiningTool(false, Tools.shovel, Tools.wood), [Drop(Items.dirt, 1, 1, Items.mycelium)], [Blocks.dirt, Blocks.grass, Blocks.podzol], 1, 1, 3, 1),
			new MineableBlock(Blocks.grassPath, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.grassPath, 1)),
			new FertileTerrainBlock!false(Blocks.farmland0, Blocks.farmland7, Blocks.dirt),
			new FertileTerrainBlock!false(Blocks.farmland1, Blocks.farmland7, Blocks.farmland0),
			new FertileTerrainBlock!false(Blocks.farmland2, Blocks.farmland7, Blocks.farmland1),
			new FertileTerrainBlock!false(Blocks.farmland3, Blocks.farmland7, Blocks.farmland2),
			new FertileTerrainBlock!false(Blocks.farmland4, Blocks.farmland7, Blocks.farmland4),
			new FertileTerrainBlock!false(Blocks.farmland5, Blocks.farmland7, Blocks.farmland4),
			new FertileTerrainBlock!false(Blocks.farmland6, Blocks.farmland7, Blocks.farmland5),
			new FertileTerrainBlock!false(Blocks.farmland7, 0, Blocks.farmland6),
			new MineableBlock(Blocks.oakWoodPlanks, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodPlanks, 1)),
			new MineableBlock(Blocks.spruceWoodPlanks, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodPlanks, 1)),
			new MineableBlock(Blocks.birchWoodPlanks, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodPlanks, 1)),
			new MineableBlock(Blocks.jungleWoodPlanks, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodPlanks, 1)),
			new MineableBlock(Blocks.acaciaWoodPlanks, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodPlanks, 1)),
			new MineableBlock(Blocks.darkOakWoodPlanks, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodPlanks, 1)),
			new SaplingBlock(Blocks.oakSapling, Items.oakSapling, Blocks.oakWood, Blocks.oakLeaves),
			new SaplingBlock(Blocks.spruceSapling, Items.spruceSapling, Blocks.spruceWood, Blocks.spruceLeaves),
			new SaplingBlock(Blocks.birchSapling, Items.birchSapling, Blocks.birchWood, Blocks.birchLeaves),
			new SaplingBlock(Blocks.jungleSapling, Items.jungleSapling, Blocks.jungleWood, Blocks.jungleLeaves),
			new SaplingBlock(Blocks.acaciaSapling, Items.acaciaSapling, Blocks.acaciaWood, Blocks.acaciaLeaves),
			new SaplingBlock(Blocks.darkOakSapling, Items.darkOakSapling, Blocks.darkOakWood, Blocks.darkOakLeaves),
			new Block(Blocks.bedrock),
			new GravityBlock(Blocks.sand, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.sand, 1)),
			new GravityBlock(Blocks.redSand, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.redSand, 1)),
			new GravelBlock(Blocks.gravel),
			new WoodBlock(Blocks.oakWoodUpDown, Items.oakWood),
			new WoodBlock(Blocks.oakWoodEastWest, Items.oakWood),
			new WoodBlock(Blocks.oakWoodNorthSouth, Items.oakWood),
			new WoodBlock(Blocks.oakWoodBark, Items.oakWood),
			new WoodBlock(Blocks.spruceWoodUpDown, Items.spruceWood),
			new WoodBlock(Blocks.spruceWoodEastWest, Items.spruceWood),
			new WoodBlock(Blocks.spruceWoodNorthSouth, Items.spruceWood),
			new WoodBlock(Blocks.spruceWoodBark, Items.spruceWood),
			new WoodBlock(Blocks.birchWoodUpDown, Items.birchWood),
			new WoodBlock(Blocks.birchWoodEastWest, Items.birchWood),
			new WoodBlock(Blocks.birchWoodNorthSouth, Items.birchWood),
			new WoodBlock(Blocks.birchWoodBark, Items.birchWood),
			new WoodBlock(Blocks.jungleWoodUpDown, Items.jungleWood),
			new WoodBlock(Blocks.jungleWoodEastWest, Items.jungleWood),
			new WoodBlock(Blocks.jungleWoodNorthSouth, Items.jungleWood),
			new WoodBlock(Blocks.jungleWoodBark, Items.jungleWood),
			new WoodBlock(Blocks.acaciaWoodUpDown, Items.acaciaWood),
			new WoodBlock(Blocks.acaciaWoodEastWest, Items.acaciaWood),
			new WoodBlock(Blocks.acaciaWoodNorthSouth, Items.acaciaWood),
			new WoodBlock(Blocks.acaciaWoodBark, Items.acaciaWood),
			new WoodBlock(Blocks.darkOakWoodUpDown, Items.darkOakWood),
			new WoodBlock(Blocks.darkOakWoodEastWest, Items.darkOakWood),
			new WoodBlock(Blocks.darkOakWoodNorthSouth, Items.darkOakWood),
			new WoodBlock(Blocks.darkOakWoodBark, Items.darkOakWood),
			new LeavesBlock!(true, true)(Blocks.oakLeavesDecay, Items.oakLeaves, Items.oakSapling, false),
			new LeavesBlock!(false, true)(Blocks.oakLeavesNoDecay, Items.oakLeaves, Items.oakSapling, false),
			new LeavesBlock!(true, true)(Blocks.oakLeavesCheckDecay, Items.oakLeaves, Items.oakSapling, false),
			new LeavesBlock!(false, true)(Blocks.oakLeavesNoDecayCheckDecay, Items.oakLeaves, Items.oakSapling, false),
			new LeavesBlock!(true, false)(Blocks.spruceLeavesDecay, Items.spruceLeaves, Items.spruceSapling, false),
			new LeavesBlock!(false, false)(Blocks.spruceLeavesNoDecay, Items.spruceLeaves, Items.spruceSapling, false),
			new LeavesBlock!(true, false)(Blocks.spruceLeavesCheckDecay, Items.spruceLeaves, Items.spruceSapling, false),
			new LeavesBlock!(true, false)(Blocks.spruceLeavesNoDecayCheckDecay, Items.spruceLeaves, Items.spruceSapling, false),
			new LeavesBlock!(true, false)(Blocks.birchLeavesDecay, Items.birchLeaves, Items.birchSapling, false),
			new LeavesBlock!(false, false)(Blocks.birchLeavesNoDecay, Items.birchLeaves, Items.birchSapling, false),
			new LeavesBlock!(true, false)(Blocks.birchLeavesCheckDecay, Items.birchLeaves, Items.birchSapling, false),
			new LeavesBlock!(false, false)(Blocks.birchLeavesNoDecayCheckDecay, Items.birchLeaves, Items.birchSapling, false),
			new LeavesBlock!(true, false)(Blocks.jungleLeavesDecay, Items.jungleLeaves, Items.jungleSapling, true),
			new LeavesBlock!(false, false)(Blocks.jungleLeavesNoDecay, Items.jungleLeaves, Items.jungleSapling, true),
			new LeavesBlock!(true, false)(Blocks.jungleLeavesCheckDecay, Items.jungleLeaves, Items.jungleSapling, true),
			new LeavesBlock!(false, true)(Blocks.jungleLeavesNoDecayCheckDecay, Items.jungleLeaves, Items.jungleSapling, true),
			new LeavesBlock!(true, false)(Blocks.acaciaLeavesDecay, Items.acaciaLeaves, Items.acaciaSapling, false),
			new LeavesBlock!(false, false)(Blocks.acaciaLeavesNoDecay, Items.acaciaLeaves, Items.acaciaSapling, false),
			new LeavesBlock!(true, false)(Blocks.acaciaLeavesCheckDecay, Items.acaciaLeaves, Items.acaciaSapling, false),
			new LeavesBlock!(false, false)(Blocks.acaciaLeavesNoDecayCheckDecay, Items.acaciaLeaves, Items.acaciaSapling, false),
			new LeavesBlock!(true, true)(Blocks.darkOakLeavesDecay, Items.darkOakLeaves, Items.darkOakSapling, false),
			new LeavesBlock!(false, true)(Blocks.darkOakLeavesNoDecay, Items.darkOakLeaves, Items.darkOakSapling, false),
			new LeavesBlock!(true, true)(Blocks.darkOakLeavesCheckDecay, Items.darkOakLeaves, Items.darkOakSapling, false),
			new LeavesBlock!(false, true)(Blocks.darkOakLeavesNoDecayCheckDecay, Items.darkOakLeaves, Items.darkOakSapling, false),
			new AbsorbingBlock(Blocks.sponge, Items.sponge, Blocks.wetSponge, Blocks.water, 7, 65),
			new MineableBlock(Blocks.wetSponge, MiningTool.init, Drop(Items.wetSponge, 1)),
			new MineableBlock(Blocks.glass, MiningTool.init, Drop(0, 0, 0, Items.glass)),
			new MineableBlock(Blocks.whiteStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.whiteStainedGlass)),
			new MineableBlock(Blocks.orangeStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.orangeStainedGlass)),
			new MineableBlock(Blocks.magentaStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.magentaStainedGlass)),
			new MineableBlock(Blocks.lightBlueStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.lightBlueStainedGlass)),
			new MineableBlock(Blocks.yellowStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.yellowStainedGlass)),
			new MineableBlock(Blocks.limeStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.limeStainedGlass)),
			new MineableBlock(Blocks.pinkStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.pinkStainedGlass)),
			new MineableBlock(Blocks.grayStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.grayStainedGlass)),
			new MineableBlock(Blocks.lightGrayStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.lightGrayStainedGlass)),
			new MineableBlock(Blocks.cyanStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.cyanStainedGlass)),
			new MineableBlock(Blocks.purpleStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.purpleStainedGlass)),
			new MineableBlock(Blocks.blueStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.blueStainedGlass)),
			new MineableBlock(Blocks.brownStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.brownStainedGlass)),
			new MineableBlock(Blocks.greenStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.greenStainedGlass)),
			new MineableBlock(Blocks.redStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.redStainedGlass)),
			new MineableBlock(Blocks.blackStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.blackStainedGlass)),
			new MineableBlock(Blocks.glassPane, MiningTool.init, Drop(0, 0, 0, Items.glassPane)),
			new MineableBlock(Blocks.whiteStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.whiteStainedGlassPane)),
			new MineableBlock(Blocks.orangeStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.orangeStainedGlassPane)),
			new MineableBlock(Blocks.magentaStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.magentaStainedGlassPane)),
			new MineableBlock(Blocks.lightBlueStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.lightBlueStainedGlassPane)),
			new MineableBlock(Blocks.yellowStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.yellowStainedGlassPane)),
			new MineableBlock(Blocks.limeStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.limeStainedGlassPane)),
			new MineableBlock(Blocks.pinkStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.pinkStainedGlassPane)),
			new MineableBlock(Blocks.grayStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.grayStainedGlassPane)),
			new MineableBlock(Blocks.lightGrayStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.lightGrayStainedGlassPane)),
			new MineableBlock(Blocks.cyanStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.cyanStainedGlassPane)),
			new MineableBlock(Blocks.purpleStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.purpleStainedGlassPane)),
			new MineableBlock(Blocks.blueStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.blueStainedGlassPane)),
			new MineableBlock(Blocks.brownStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.brownStainedGlassPane)),
			new MineableBlock(Blocks.greenStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.greenStainedGlassPane)),
			new MineableBlock(Blocks.redStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.redStainedGlassPane)),
			new MineableBlock(Blocks.blackStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.blackStainedGlassPane)),
			new MineableBlock(Blocks.sandstone, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstone, 1)),
			new MineableBlock(Blocks.chiseledSandstone, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.chiseledSandstone, 1)),
			new MineableBlock(Blocks.smoothSandstone, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.smoothSandstone, 1)),
			new MineableBlock(Blocks.redSandstone, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstone, 1)),
			new MineableBlock(Blocks.chiseledRedSandstone, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.chiseledRedSandstone, 1)),
			new MineableBlock(Blocks.smoothRedSandstone, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.smoothRedSandstone, 1)),
			new MineableBlock(Blocks.pistonFacingEverywhere, MiningTool.init, Drop(Items.piston, 1)),
			new MineableBlock(Blocks.pistonFacingEverywhere1, MiningTool.init, Drop(Items.piston, 1)),
			new MineableBlock(Blocks.extendedPistonFacingEverywhere, MiningTool.init, Drop(Items.piston, 1)),
			new MineableBlock(Blocks.extendedPistonFacingEverywhere1, MiningTool.init, Drop(Items.piston, 1)),
			new MineableBlock(Blocks.stickyPistonFacingEverywhere, MiningTool.init, Drop(Items.stickyPiston, 1)),
			new MineableBlock(Blocks.stickyPistonFacingEverywhere1, MiningTool.init, Drop(Items.stickyPiston, 1)),
			new MineableBlock(Blocks.extendedStickyPistonFacingEverywhere, MiningTool.init, Drop(Items.piston, 1)),
			new MineableBlock(Blocks.extendedStickyPistonFacingEverywhere1, MiningTool.init, Drop(Items.piston, 1)),
			new MineableBlock(Blocks.whiteWool, MiningTool(false, Tools.shears), Drop(Items.whiteWool, 1)),
			new MineableBlock(Blocks.orangeWool, MiningTool(false, Tools.shears), Drop(Items.orangeWool, 1)),
			new MineableBlock(Blocks.magentaWool, MiningTool(false, Tools.shears), Drop(Items.magentaWool, 1)),
			new MineableBlock(Blocks.lightBlueWool, MiningTool(false, Tools.shears), Drop(Items.lightBlueWool, 1)),
			new MineableBlock(Blocks.yellowWool, MiningTool(false, Tools.shears), Drop(Items.yellowWool, 1)),
			new MineableBlock(Blocks.limeWool, MiningTool(false, Tools.shears), Drop(Items.limeWool, 1)),
			new MineableBlock(Blocks.pinkWool, MiningTool(false, Tools.shears), Drop(Items.pinkWool, 1)),
			new MineableBlock(Blocks.grayWool, MiningTool(false, Tools.shears), Drop(Items.grayWool, 1)),
			new MineableBlock(Blocks.lightGrayWool, MiningTool(false, Tools.shears), Drop(Items.lightGrayWool, 1)),
			new MineableBlock(Blocks.cyanWool, MiningTool(false, Tools.shears), Drop(Items.cyanWool, 1)),
			new MineableBlock(Blocks.purpleWool, MiningTool(false, Tools.shears), Drop(Items.purpleWool, 1)),
			new MineableBlock(Blocks.blueWool, MiningTool(false, Tools.shears), Drop(Items.blueWool, 1)),
			new MineableBlock(Blocks.brownWool, MiningTool(false, Tools.shears), Drop(Items.brownWool, 1)),
			new MineableBlock(Blocks.greenWool, MiningTool(false, Tools.shears), Drop(Items.greenWool, 1)),
			new MineableBlock(Blocks.redWool, MiningTool(false, Tools.shears), Drop(Items.redWool, 1)),
			new MineableBlock(Blocks.blackWool, MiningTool(false, Tools.shears), Drop(Items.blackWool, 1)),
			new MineableBlock(Blocks.whiteCarpet, MiningTool.init, Drop(Items.whiteCarpet, 1)),
			new MineableBlock(Blocks.orangeCarpet, MiningTool.init, Drop(Items.orangeCarpet, 1)),
			new MineableBlock(Blocks.magentaCarpet, MiningTool.init, Drop(Items.magentaCarpet, 1)),
			new MineableBlock(Blocks.lightBlueCarpet, MiningTool.init, Drop(Items.lightBlueCarpet, 1)),
			new MineableBlock(Blocks.yellowCarpet, MiningTool.init, Drop(Items.yellowCarpet, 1)),
			new MineableBlock(Blocks.limeCarpet, MiningTool.init, Drop(Items.limeCarpet, 1)),
			new MineableBlock(Blocks.pinkCarpet, MiningTool.init, Drop(Items.pinkCarpet, 1)),
			new MineableBlock(Blocks.grayCarpet, MiningTool.init, Drop(Items.grayCarpet, 1)),
			new MineableBlock(Blocks.lightGrayCarpet, MiningTool.init, Drop(Items.lightGrayCarpet, 1)),
			new MineableBlock(Blocks.cyanCarpet, MiningTool.init, Drop(Items.cyanCarpet, 1)),
			new MineableBlock(Blocks.purpleCarpet, MiningTool.init, Drop(Items.purpleCarpet, 1)),
			new MineableBlock(Blocks.blueCarpet, MiningTool.init, Drop(Items.blueCarpet, 1)),
			new MineableBlock(Blocks.brownCarpet, MiningTool.init, Drop(Items.brownCarpet, 1)),
			new MineableBlock(Blocks.greenCarpet, MiningTool.init, Drop(Items.greenCarpet, 1)),
			new MineableBlock(Blocks.redCarpet, MiningTool.init, Drop(Items.redCarpet, 1)),
			new MineableBlock(Blocks.blackCarpet, MiningTool.init, Drop(Items.blackCarpet, 1)),
			new FlowerBlock(Blocks.dandelion, Items.dandelion),
			new FlowerBlock(Blocks.poppy, Items.poppy),
			new FlowerBlock(Blocks.blueOrchid, Items.blueOrchid),
			new FlowerBlock(Blocks.allium, Items.allium),
			new FlowerBlock(Blocks.azureBluet, Items.azureBluet),
			new FlowerBlock(Blocks.redTulip, Items.redTulip),
			new FlowerBlock(Blocks.orangeTulip, Items.orangeTulip),
			new FlowerBlock(Blocks.whiteTulip, Items.whiteTulip),
			new FlowerBlock(Blocks.pinkTulip, Items.pinkTulip),
			new FlowerBlock(Blocks.oxeyeDaisy, Items.oxeyeDaisy),
			new DoublePlantBlock(Blocks.sunflowerBottom, false, Blocks.sunflowerTop, Items.sunflower),
			new DoublePlantBlock(Blocks.sunflowerTop, true, Blocks.sunflowerBottom, Items.sunflower),
			new DoublePlantBlock(Blocks.liliacBottom, false, Blocks.liliacTop, Items.liliac),
			new DoublePlantBlock(Blocks.liliacTop, true, Blocks.liliacBottom, Items.liliac),
			new GrassDoublePlantBlock(Blocks.doubleTallgrassBottom, false, Blocks.doubleTallgrassTop, Items.tallGrass),
			new GrassDoublePlantBlock(Blocks.doubleTallgrassTop, true, Blocks.doubleTallgrassBottom, Items.tallGrass),
			new GrassDoublePlantBlock(Blocks.largeFernBottom, false, Blocks.largeFernTop, Items.fern),
			new GrassDoublePlantBlock(Blocks.largeFernTop, true, Blocks.largeFernBottom, Items.fern),
			new DoublePlantBlock(Blocks.roseBushBottom, false, Blocks.roseBushTop, Items.roseBush),
			new DoublePlantBlock(Blocks.roseBushTop, true, Blocks.roseBushBottom, Items.roseBush),
			new DoublePlantBlock(Blocks.peonyBottom, false, Blocks.peonyTop, Items.peony),
			new DoublePlantBlock(Blocks.peonyTop, true, Blocks.peonyBottom, Items.peony),
			new PlantBlock(Blocks.tallGrass, Items.tallGrass, Drop(Items.seeds, 0, 1)),
			new PlantBlock(Blocks.fern, Items.fern, Drop(Items.seeds, 0, 1)),
			new PlantBlock(Blocks.deadBush, Items.deadBush, Drop(Items.stick, 0, 2)),
			new MineableBlock(Blocks.stoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneSlab, 1)),
			new MineableBlock(Blocks.sandstoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstoneSlab, 1)),
			new MineableBlock(Blocks.stoneWoodenSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneWoodenSlab, 1)),
			new MineableBlock(Blocks.cobblestoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cobblestoneSlab, 1)),
			new MineableBlock(Blocks.bricksSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.bricksSlab, 1)),
			new MineableBlock(Blocks.stoneBrickSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneBrickSlab, 1)),
			new MineableBlock(Blocks.netherBrickSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrickSlab, 1)),
			new MineableBlock(Blocks.quartzSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.quartzSlab, 1)),
			new MineableBlock(Blocks.redSandstoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstoneSlab, 1)),
			new MineableBlock(Blocks.purpurSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpurSlab, 1)),
			new MineableBlock(Blocks.oakWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodSlab, 1)),
			new MineableBlock(Blocks.spruceWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodSlab, 1)),
			new MineableBlock(Blocks.birchWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodSlab, 1)),
			new MineableBlock(Blocks.jungleWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodSlab, 1)),
			new MineableBlock(Blocks.acaciaWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodSlab, 1)),
			new MineableBlock(Blocks.darkOakWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodSlab, 1)),
			new MineableBlock(Blocks.upperStoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneSlab, 1)),
			new MineableBlock(Blocks.upperSandstoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstoneSlab, 1)),
			new MineableBlock(Blocks.upperStoneWoodenSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneWoodenSlab, 1)),
			new MineableBlock(Blocks.upperCobblestoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cobblestoneSlab, 1)),
			new MineableBlock(Blocks.upperBricksSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.bricksSlab, 1)),
			new MineableBlock(Blocks.upperStoneBrickSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneBrickSlab, 1)),
			new MineableBlock(Blocks.upperNetherBrickSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrickSlab, 1)),
			new MineableBlock(Blocks.upperQuartzSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.quartzSlab, 1)),
			new MineableBlock(Blocks.upperRedSandstoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstoneSlab, 1)),
			new MineableBlock(Blocks.upperPurpurSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpurSlab, 1)),
			new MineableBlock(Blocks.upperOakWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodSlab, 1)),
			new MineableBlock(Blocks.upperSpruceWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodSlab, 1)),
			new MineableBlock(Blocks.birchWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodSlab, 1)),
			new MineableBlock(Blocks.upperJungleWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodSlab, 1)),
			new MineableBlock(Blocks.upperAcaciaWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodSlab, 1)),
			new MineableBlock(Blocks.upperDarkOakWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodSlab, 1)),
			new MineableBlock(Blocks.doubleStoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneSlab, 2)),
			new MineableBlock(Blocks.doubleSandstoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.sandstoneSlab, 2)),
			new MineableBlock(Blocks.doubleStoneWoodenSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneWoodenSlab, 2)),
			new MineableBlock(Blocks.doubleCobblestoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cobblestoneSlab, 2)),
			new MineableBlock(Blocks.doubleBricksSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.bricksSlab, 1)),
			new MineableBlock(Blocks.doubleStoneBrickSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stoneBrickSlab, 2)),
			new MineableBlock(Blocks.doubleNetherBrickSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrickSlab, 2)),
			new MineableBlock(Blocks.doubleQuartzSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.quartzSlab, 2)),
			new MineableBlock(Blocks.doubleRedSandstoneSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redSandstoneSlab, 2)),
			new MineableBlock(Blocks.doublePurpurSlab, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpurSlab, 2)),
			new MineableBlock(Blocks.doubleOakWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.oakWoodSlab, 2)),
			new MineableBlock(Blocks.doubleSpruceWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.spruceWoodSlab, 2)),
			new MineableBlock(Blocks.birchWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.birchWoodSlab, 2)),
			new MineableBlock(Blocks.doubleJungleWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jungleWoodSlab, 2)),
			new MineableBlock(Blocks.doubleAcaciaWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.acaciaWoodSlab, 2)),
			new MineableBlock(Blocks.doubleDarkOakWoodSlab, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.darkOakWoodSlab, 2)),
			new StairsBlock(Blocks.cobblestoneStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.cobblestoneStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.cobblestoneStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.cobblestoneStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.upsideDownCobblestoneStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.upsideDownCobblestoneStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.upsideDownCobblestoneStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.upsideDownCobblestoneStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.cobblestoneStairs),
			new StairsBlock(Blocks.brickStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.brickStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.brickStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.brickStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.upsideDownBrickStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.upsideDownBrickStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.upsideDownBrickStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.upsideDownBrickStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.brickStairs),
			new StairsBlock(Blocks.netherBrickStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.netherBrickStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.netherBrickStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.netherBrickStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.upsideDownNetherBrickStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.upsideDownNetherBrickStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.upsideDownNetherBrickStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.upsideDownNetherBrickStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.netherBrickStairs),
			new StairsBlock(Blocks.stoneBrickStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.stoneBrickStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.stoneBrickStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.stoneBrickStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.upsideDownStoneBrickStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.upsideDownStoneBrickStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.upsideDownStoneBrickStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.upsideDownStoneBrickStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.stoneBrickStairs),
			new StairsBlock(Blocks.purpurStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.purpurStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.purpurStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.purpurStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.upsideDownPurpurStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.upsideDownPurpurStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.upsideDownPurpurStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.upsideDownPurpurStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.purpurStairs),
			new StairsBlock(Blocks.quartzStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.quartzStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.quartzStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.quartzStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.upsideDownQuartzStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.upsideDownQuartzStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.upsideDownQuartzStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.upsideDownQuartzStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.quartzStairs),
			new StairsBlock(Blocks.sandstoneStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.sandstoneStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.sandstoneStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.sandstoneStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.upsideDownSandstoneStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.upsideDownSandstoneStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.upsideDownSandstoneStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.upsideDownSandstoneStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.sandstoneStairs),
			new StairsBlock(Blocks.redSandstoneStairsFacingEast, Facing.east, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.redSandstoneStairsFacingWest, Facing.west, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.redSandstoneStairsFacingSouth, Facing.south, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.redSandstoneStairsFacingNorth, Facing.north, false, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.upsideDownRedSandstoneStairsFacingEast, Facing.east, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.upsideDownRedSandstoneStairsFacingWest, Facing.west, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.upsideDownRedSandstoneStairsFacingSouth, Facing.south, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.upsideDownRedSandstoneStairsFacingNorth, Facing.north, true, MiningTool(true, Tools.pickaxe, Tools.wood), Items.redSandstoneStairs),
			new StairsBlock(Blocks.oakWoodStairsFacingEast, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.oakWoodStairsFacingWest, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.oakWoodStairsFacingSouth, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.oakWoodStairsFacingNorth, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.upsideDownOakWoodStairsFacingEast, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.upsideDownOakWoodStairsFacingWest, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.upsideDownOakWoodStairsFacingSouth, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.upsideDownOakWoodStairsFacingNorth, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.oakWoodStairs),
			new StairsBlock(Blocks.spruceWoodStairsFacingEast, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.spruceWoodStairsFacingWest, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.spruceWoodStairsFacingSouth, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.spruceWoodStairsFacingNorth, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.upsideDownSpruceWoodStairsFacingEast, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.upsideDownSpruceWoodStairsFacingWest, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.upsideDownSpruceWoodStairsFacingSouth, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.upsideDownSpruceWoodStairsFacingNorth, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.spruceWoodStairs),
			new StairsBlock(Blocks.birchWoodStairsFacingEast, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.birchWoodStairsFacingWest, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.birchWoodStairsFacingSouth, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.birchWoodStairsFacingNorth, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.upsideDownBirchWoodStairsFacingEast, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.upsideDownBirchWoodStairsFacingWest, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.upsideDownBirchWoodStairsFacingSouth, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.upsideDownBirchWoodStairsFacingNorth, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.birchWoodStairs),
			new StairsBlock(Blocks.jungleWoodStairsFacingEast, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.jungleWoodStairsFacingWest, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.jungleWoodStairsFacingSouth, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.jungleWoodStairsFacingNorth, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.upsideDownJungleWoodStairsFacingEast, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.upsideDownJungleWoodStairsFacingWest, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.upsideDownJungleWoodStairsFacingSouth, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.upsideDownJungleWoodStairsFacingNorth, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.jungleWoodStairs),
			new StairsBlock(Blocks.acaciaWoodStairsFacingEast, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.acaciaWoodStairsFacingWest, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.acaciaWoodStairsFacingSouth, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.acaciaWoodStairsFacingNorth, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.upsideDownAcaciaWoodStairsFacingEast, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.upsideDownAcaciaWoodStairsFacingWest, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.upsideDownAcaciaWoodStairsFacingSouth, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.upsideDownAcaciaWoodStairsFacingNorth, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.acaciaWoodStairs),
			new StairsBlock(Blocks.darkOakWoodStairsFacingEast, Facing.east, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.darkOakWoodStairsFacingWest, Facing.west, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.darkOakWoodStairsFacingSouth, Facing.south, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.darkOakWoodStairsFacingNorth, Facing.north, false, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.upsideDownDarkOakWoodStairsFacingEast, Facing.east, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.upsideDownDarkOakWoodStairsFacingWest, Facing.west, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.upsideDownDarkOakWoodStairsFacingSouth, Facing.south, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new StairsBlock(Blocks.upsideDownDarkOakWoodStairsFacingNorth, Facing.north, true, MiningTool(false, Tools.axe, Tools.wood), Items.darkOakWoodStairs),
			new MineableBlock(Blocks.bookshelf, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.book, 3, 3, Items.bookshelf)),
			new MineableBlock(Blocks.obsidian, MiningTool(true, Tools.pickaxe, Tools.diamond), Drop(Items.obsidian, 1)),
			new MineableBlock(Blocks.glowingObsidian, MiningTool(true, Tools.pickaxe, Tools.diamond), Drop(Items.glowingObsidian, 1)),
			new MineableBlock(Blocks.torchFacingEast, MiningTool.init, Drop(Items.torch, 1)),
			new MineableBlock(Blocks.torchFacingWest, MiningTool.init, Drop(Items.torch, 1)),
			new MineableBlock(Blocks.torchFacingSouth, MiningTool.init, Drop(Items.torch, 1)),
			new MineableBlock(Blocks.torchFacingNorth, MiningTool.init, Drop(Items.torch, 1)),
			new MineableBlock(Blocks.torchFacingUp, MiningTool.init, Drop(Items.torch, 1)),
			new MineableBlock(Blocks.craftingTable, MiningTool(Tools.axe, Tools.all), Drop(Items.craftingTable, 1)), //TODO open window on click
			new StageCropBlock(Blocks.seeds0, Blocks.seeds1, [Drop(Items.seeds, 1)]),
			new StageCropBlock(Blocks.seeds1, Blocks.seeds2, [Drop(Items.seeds, 1)]),
			new StageCropBlock(Blocks.seeds2, Blocks.seeds3, [Drop(Items.seeds, 1)]),
			new StageCropBlock(Blocks.seeds3, Blocks.seeds4, [Drop(Items.seeds, 1)]),
			new StageCropBlock(Blocks.seeds4, Blocks.seeds5, [Drop(Items.seeds, 1)]),
			new StageCropBlock(Blocks.seeds5, Blocks.seeds6, [Drop(Items.seeds, 1)]),
			new StageCropBlock(Blocks.seeds6, Blocks.seeds7, [Drop(Items.seeds, 1)]),
			new FarmingBlock(Blocks.seeds7, [Drop(Items.seeds, 0, 3), Drop(Items.wheat, 1)]),
			new ChanceCropBlock(Blocks.beetroot0, Blocks.beetroot1, [Drop(Items.beetrootSeeds, 1)], 2, 3),
			new ChanceCropBlock(Blocks.beetroot1, Blocks.beetroot2, [Drop(Items.beetrootSeeds, 1)], 2, 3),
			new ChanceCropBlock(Blocks.beetroot2, Blocks.beetroot3, [Drop(Items.beetrootSeeds, 1)], 2, 3),
			new FarmingBlock(Blocks.beetroot3, [Drop(Items.beetroot, 1), Drop(Items.beetrootSeeds, 0, 3)]),
			new StageCropBlock(Blocks.carrot0, Blocks.carrot1, [Drop(Items.carrot, 1)]),
			new StageCropBlock(Blocks.carrot1, Blocks.carrot2, [Drop(Items.carrot, 1)]),
			new StageCropBlock(Blocks.carrot2, Blocks.carrot3, [Drop(Items.carrot, 1)]),
			new StageCropBlock(Blocks.carrot3, Blocks.carrot4, [Drop(Items.carrot, 1)]),
			new StageCropBlock(Blocks.carrot4, Blocks.carrot5, [Drop(Items.carrot, 1)]),
			new StageCropBlock(Blocks.carrot5, Blocks.carrot6, [Drop(Items.carrot, 1)]),
			new StageCropBlock(Blocks.carrot6, Blocks.carrot7, [Drop(Items.carrot, 1)]),
			new FarmingBlock(Blocks.carrot7, [Drop(Items.carrot, 1, 4)]),
			new StageCropBlock(Blocks.potato0, Blocks.potato1, [Drop(Items.potato, 1)]),
			new StageCropBlock(Blocks.potato1, Blocks.potato2, [Drop(Items.potato, 1)]),
			new StageCropBlock(Blocks.potato2, Blocks.potato3, [Drop(Items.potato, 1)]),
			new StageCropBlock(Blocks.potato3, Blocks.potato4, [Drop(Items.potato, 1)]),
			new StageCropBlock(Blocks.potato4, Blocks.potato5, [Drop(Items.potato, 1)]),
			new StageCropBlock(Blocks.potato5, Blocks.potato6, [Drop(Items.potato, 1)]),
			new StageCropBlock(Blocks.potato6, Blocks.potato7, [Drop(Items.potato, 1)]),
			new FarmingBlock(Blocks.potato7, [Drop(Items.potato, 1, 4), Drop(Items.poisonousPotato, -49, 1)]),
			new StemBlock!StageCropBlock(Blocks.melonStem0, Items.melonSeeds, Blocks.melonStem1),
			new StemBlock!StageCropBlock(Blocks.melonStem1, Items.melonSeeds, Blocks.melonStem2),
			new StemBlock!StageCropBlock(Blocks.melonStem2, Items.melonSeeds, Blocks.melonStem3),
			new StemBlock!StageCropBlock(Blocks.melonStem3, Items.melonSeeds, Blocks.melonStem4),
			new StemBlock!StageCropBlock(Blocks.melonStem4, Items.melonSeeds, Blocks.melonStem5),
			new StemBlock!StageCropBlock(Blocks.melonStem5, Items.melonSeeds, Blocks.melonStem6),
			new StemBlock!StageCropBlock(Blocks.melonStem6, Items.melonSeeds, Blocks.melonStem7),
			new StemBlock!(FruitCropBlock!false)(Blocks.melonStem7, Items.melonSeeds, Blocks.melon),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem0, Items.pumpkinSeeds, Blocks.pumpkinStem1),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem1, Items.pumpkinSeeds, Blocks.pumpkinStem2),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem2, Items.pumpkinSeeds, Blocks.pumpkinStem3),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem3, Items.pumpkinSeeds, Blocks.pumpkinStem4),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem4, Items.pumpkinSeeds, Blocks.pumpkinStem5),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem5, Items.pumpkinSeeds, Blocks.pumpkinStem6),
			new StemBlock!StageCropBlock(Blocks.pumpkinStem6, Items.pumpkinSeeds, Blocks.pumpkinStem7),
			new StemBlock!(FruitCropBlock!true)(Blocks.pumpkinStem7, Items.pumpkinSeeds, cast(block_t[4])Blocks.pumpkin[0..4]),
			new SugarCanesBlock(Blocks.sugarCanes0, Blocks.sugarCanes1),
			new SugarCanesBlock(Blocks.sugarCanes1, Blocks.sugarCanes2),
			new SugarCanesBlock(Blocks.sugarCanes2, Blocks.sugarCanes3),
			new SugarCanesBlock(Blocks.sugarCanes3, Blocks.sugarCanes4),
			new SugarCanesBlock(Blocks.sugarCanes4, Blocks.sugarCanes5),
			new SugarCanesBlock(Blocks.sugarCanes5, Blocks.sugarCanes6),
			new SugarCanesBlock(Blocks.sugarCanes6, Blocks.sugarCanes7),
			new SugarCanesBlock(Blocks.sugarCanes7, Blocks.sugarCanes8),
			new SugarCanesBlock(Blocks.sugarCanes8, Blocks.sugarCanes9),
			new SugarCanesBlock(Blocks.sugarCanes9, Blocks.sugarCanes10),
			new SugarCanesBlock(Blocks.sugarCanes10, Blocks.sugarCanes11),
			new SugarCanesBlock(Blocks.sugarCanes11, Blocks.sugarCanes12),
			new SugarCanesBlock(Blocks.sugarCanes12, Blocks.sugarCanes13),
			new SugarCanesBlock(Blocks.sugarCanes13, Blocks.sugarCanes14),
			new SugarCanesBlock(Blocks.sugarCanes14, Blocks.sugarCanes15),
			new SugarCanesBlock(Blocks.sugarCanes15, 0),
			new StageNetherCropBlock(Blocks.netherWart0, Blocks.netherWart1, Drop(Items.netherWart, 1)),
			new StageNetherCropBlock(Blocks.netherWart1, Blocks.netherWart2, Drop(Items.netherWart, 1)),
			new StageNetherCropBlock(Blocks.netherWart2, Blocks.netherWart3, Drop(Items.netherWart, 1)),
			new NetherCropBlock(Blocks.netherWart3, Drop(Items.netherWart, 1, 4, 0)), //TODO +1 with fortune
			new MineableBlock(Blocks.stonecutter, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.stonecutter, 1)),
			new GravityBlock(Blocks.snowLayer0, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 2)),
			new GravityBlock(Blocks.snowLayer1, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 3)),
			new GravityBlock(Blocks.snowLayer2, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 4)),
			new GravityBlock(Blocks.snowLayer3, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 5)),
			new GravityBlock(Blocks.snowLayer4, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 6)),
			new GravityBlock(Blocks.snowLayer5, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 7)),
			new GravityBlock(Blocks.snowLayer6, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 8)),
			new GravityBlock(Blocks.snowLayer7, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 9)),
			new MineableBlock(Blocks.snow, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 4, 4, Items.snowBlock)),
			new CactusBlock(Blocks.cactus0, Blocks.cactus1),
			new CactusBlock(Blocks.cactus1, Blocks.cactus2),
			new CactusBlock(Blocks.cactus2, Blocks.cactus3),
			new CactusBlock(Blocks.cactus3, Blocks.cactus4),
			new CactusBlock(Blocks.cactus4, Blocks.cactus5),
			new CactusBlock(Blocks.cactus5, Blocks.cactus6),
			new CactusBlock(Blocks.cactus6, Blocks.cactus7),
			new CactusBlock(Blocks.cactus7, Blocks.cactus8),
			new CactusBlock(Blocks.cactus8, Blocks.cactus9),
			new CactusBlock(Blocks.cactus9, Blocks.cactus10),
			new CactusBlock(Blocks.cactus10, Blocks.cactus11),
			new CactusBlock(Blocks.cactus11, Blocks.cactus12),
			new CactusBlock(Blocks.cactus12, Blocks.cactus13),
			new CactusBlock(Blocks.cactus13, Blocks.cactus14),
			new CactusBlock(Blocks.cactus14, Blocks.cactus15),
			new CactusBlock(Blocks.cactus15, 0),
			new MineableBlock(Blocks.clay, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.clay, 4, 4, Items.clayBlock)),
			new MineableBlock(Blocks.hardenedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.hardenedClay, 1)),
			new MineableBlock(Blocks.whiteStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.whiteStainedClay, 1)),
			new MineableBlock(Blocks.orangeStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.orangeStainedClay, 1)),
			new MineableBlock(Blocks.magentaStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.magentaStainedClay, 1)),
			new MineableBlock(Blocks.lightBlueStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.lightBlueStainedClay, 1)),
			new MineableBlock(Blocks.yellowStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.yellowStainedClay, 1)),
			new MineableBlock(Blocks.limeStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.limeStainedClay, 1)),
			new MineableBlock(Blocks.pinkStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.pinkStainedClay, 1)),
			new MineableBlock(Blocks.grayStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.grayStainedClay, 1)),
			new MineableBlock(Blocks.lightGrayStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.lightGrayStainedClay, 1)),
			new MineableBlock(Blocks.cyanStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.cyanStainedClay, 1)),
			new MineableBlock(Blocks.purpleStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.purpleStainedClay, 1)),
			new MineableBlock(Blocks.blueStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.blueStainedClay, 1)),
			new MineableBlock(Blocks.brownStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.brownStainedClay, 1)),
			new MineableBlock(Blocks.greenStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.greenStainedClay, 1)),
			new MineableBlock(Blocks.redStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redStainedClay, 1)),
			new MineableBlock(Blocks.blackStainedClay, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.blackStainedClay, 1)),
			new MineableBlock(Blocks.pumpkinFacingSouth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.pumpkinFacingWest, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.pumpkinFacingNorth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.pumpkinFacingEast, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.facelessPumpkinFacingSouth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.facelessPumpkinFacingWest, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.facelessPumpkinFacingNorth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.facelessPumpkinFacingEast, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.pumpkin, 1)),
			new MineableBlock(Blocks.jackOLanternFacingSouth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.jackOLanternFacingWest, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.jackOLanternFacingNorth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.jackOLanternFacingEast, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.facelessJackOLanternFacingSouth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.facelessJackOLanternFacingWest, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.facelessJackOLanternFacingNorth, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.facelessJackOLanternFacingEast, MiningTool(false, Tools.axe, Tools.wood), Drop(Items.jackOLantern, 1)),
			new MineableBlock(Blocks.netherrack, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherrack, 1)), //TODO infinite fire
			new MineableBlock(Blocks.soulSand, MiningTool(false, Tools.pickaxe, Tools.wood), Drop(Items.soulSand, 1)),
			new MineableBlock(Blocks.glowstone, MiningTool.init, Drop(Items.glowstoneDust, 2, 4, Items.glowstone)), //TODO fortune +1 but max 4
			new MineableBlock(Blocks.netherBrick, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.netherBrick, 1)),
			new MineableBlock(Blocks.redNetherBrick, MiningTool(true, Tools.pickaxe, Tools.wood), Drop(Items.redNetherBrick, 1)),
			new CakeBlock(Blocks.cake0, Blocks.cake1),
			new CakeBlock(Blocks.cake1, Blocks.cake2),
			new CakeBlock(Blocks.cake2, Blocks.cake3),
			new CakeBlock(Blocks.cake3, Blocks.cake4),
			new CakeBlock(Blocks.cake4, Blocks.cake5),
			new CakeBlock(Blocks.cake5, Blocks.cake6),
			new CakeBlock(Blocks.cake6, 0),
			new SwitchingBlock!false(Blocks.woodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorSouthSide),
			new SwitchingBlock!false(Blocks.woodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorNorthSide),
			new SwitchingBlock!false(Blocks.woodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorEastSide),
			new SwitchingBlock!false(Blocks.woodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorWestSide),
			new SwitchingBlock!false(Blocks.openedWoodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorSouthSide),
			new SwitchingBlock!false(Blocks.openedWoodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorNorthSide),
			new SwitchingBlock!false(Blocks.openedWoodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorEastSide),
			new SwitchingBlock!false(Blocks.openedWoodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorWestSide),
			new SwitchingBlock!false(Blocks.topWoodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorSouthSide),
			new SwitchingBlock!false(Blocks.topWoodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorNorthSide),
			new SwitchingBlock!false(Blocks.topWoodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorEastSide),
			new SwitchingBlock!false(Blocks.topWoodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorWestSide),
			new SwitchingBlock!false(Blocks.openedTopWoodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorSouthSide),
			new SwitchingBlock!false(Blocks.openedTopWoodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorNorthSide),
			new SwitchingBlock!false(Blocks.openedTopWoodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorEastSide),
			new SwitchingBlock!false(Blocks.openedTopWoodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorWestSide),
			new SwitchingBlock!true(Blocks.ironTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorSouthSide),
			new SwitchingBlock!true(Blocks.ironTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorNorthSide),
			new SwitchingBlock!true(Blocks.ironTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorEastSide),
			new SwitchingBlock!true(Blocks.ironTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorWestSide),
			new SwitchingBlock!true(Blocks.openedIronTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorSouthSide),
			new SwitchingBlock!true(Blocks.openedIronTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorNorthSide),
			new SwitchingBlock!true(Blocks.openedIronTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorEastSide),
			new SwitchingBlock!true(Blocks.openedIronTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorWestSide),
			new SwitchingBlock!true(Blocks.topIronTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorSouthSide),
			new SwitchingBlock!true(Blocks.topIronTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorNorthSide),
			new SwitchingBlock!true(Blocks.topIronTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorEastSide),
			new SwitchingBlock!true(Blocks.topIronTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorWestSide),
			new SwitchingBlock!true(Blocks.openedTopIronTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorSouthSide),
			new SwitchingBlock!true(Blocks.openedTopIronTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorNorthSide),
			new SwitchingBlock!true(Blocks.openedTopIronTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorEastSide),
			new SwitchingBlock!true(Blocks.openedTopIronTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorWestSide),
			new MonsterEggBlock(Blocks.stoneMonsterEgg, Blocks.stone),
			new MonsterEggBlock(Blocks.cobblestoneMonsterEgg, Blocks.cobblestone),
			new MonsterEggBlock(Blocks.stoneBrickMonsterEgg, Blocks.stoneBricks),
			new MonsterEggBlock(Blocks.mossyStoneBrickMonsterEgg, Blocks.mossyStoneBricks),
			new MonsterEggBlock(Blocks.crackedStoneBrickMonsterEgg, Blocks.crackedStoneBricks),
			new MonsterEggBlock(Blocks.chiseledStoneBrickMonsterEgg, Blocks.chiseledStoneBricks),
			new MineableBlock(Blocks.brownMushroomPoresEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopWestNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopNorthEast, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopWest, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTop, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopEast, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopSouthWest, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapTopEastSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomStemEverySide, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomCapsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.brownMushroomStemsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)),
			new MineableBlock(Blocks.redMushroomPoresEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopWestNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopNorthEast, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopWest, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTop, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopEast, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopSouthWest, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapTopEastSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomStemEverySide, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomCapsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.redMushroomStemsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)),
			new MineableBlock(Blocks.ironBars, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironBars, 1)),
			new MineableBlock(Blocks.melon, MiningTool(Tools.axe | Tools.sword, Tools.all), Drop(Items.melon, 3, 7, Items.melonBlock)),
			new InactiveEndPortalBlock(Blocks.endPortalFrameSouth, Blocks.activeEndPortalFrameSouth, Facing.south),
			new InactiveEndPortalBlock(Blocks.endPortalFrameWest, Blocks.activeEndPortalFrameWest, Facing.west),
			new InactiveEndPortalBlock(Blocks.endPortalFrameNorth, Blocks.activeEndPortalFrameNorth, Facing.north),
			new InactiveEndPortalBlock(Blocks.endPortalFrameEast, Blocks.activeEndPortalFrameEast, Facing.east),
			new Block(Blocks.activeEndPortalFrameSouth),
			new Block(Blocks.activeEndPortalFrameWest),
			new Block(Blocks.activeEndPortalFrameNorth),
			new Block(Blocks.activeEndPortalFrameEast),
			new MineableBlock(Blocks.endStone, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.endStone, 1)),
			new MineableBlock(Blocks.endStoneBricks, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.endStoneBricks, 1)),
			new Block(Blocks.endPortal), //TODO teleport to end dimension
			new GrowingBeansBlock(Blocks.cocoaNorth0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.south, Blocks.cocoaNorth1),
			new GrowingBeansBlock(Blocks.cocoaEast0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.west, Blocks.cocoaEast1),
			new GrowingBeansBlock(Blocks.cocoaSouth0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.north, Blocks.cocoaSouth1),
			new GrowingBeansBlock(Blocks.cocoaWest0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.east, Blocks.cocoaWest1),
			new GrowingBeansBlock(Blocks.cocoaNorth1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.south, Blocks.cocoaNorth2),
			new GrowingBeansBlock(Blocks.cocoaEast1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.west, Blocks.cocoaEast2),
			new GrowingBeansBlock(Blocks.cocoaSouth1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.north, Blocks.cocoaSouth2),
			new GrowingBeansBlock(Blocks.cocoaWest1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.east, Blocks.cocoaWest2),
			new BeansBlock(Blocks.cocoaNorth2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.south),
			new BeansBlock(Blocks.cocoaEast2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.west),
			new BeansBlock(Blocks.cocoaSouth2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.north),
			new BeansBlock(Blocks.cocoaWest2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.east),
			new MineableBlock(Blocks.lilyPad, MiningTool.init, Drop(Items.lilyPad, 1)), //TODO drop when the block underneath is not water nor ice
			new MineableBlock(Blocks.quartzBlock, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.quartzBlock, 1)),
			new MineableBlock(Blocks.chiseledQuartzBlock, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.chiseledQuartzBlock, 1)),
			new MineableBlock(Blocks.pillarQuartzBlockVertical, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1)),
			new MineableBlock(Blocks.pillarQuartzBlockNorthSouth, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1)),
			new MineableBlock(Blocks.pillarQuartzBlockEastWest, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1)),
			new Block(Blocks.barrier),
			new MineableBlock(Blocks.prismarine, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.prismarine, 1)),
			new MineableBlock(Blocks.prismarineBricks, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.prismarineBricks, 1)),
			new MineableBlock(Blocks.darkPrismarine, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.darkPrismarine, 1)),
			new MineableBlock(Blocks.seaLantern, MiningTool.init, Drop(Items.prismarineCrystals, 2, 3, Items.seaLantern)), //TODO fortune
			new MineableBlock(Blocks.hayBaleVertical, MiningTool.init, Drop(Items.hayBale, 1)),
			new MineableBlock(Blocks.hayBaleEastWest, MiningTool.init, Drop(Items.hayBale, 1)),
			new MineableBlock(Blocks.hayBaleNorthSouth, MiningTool.init, Drop(Items.hayBale, 1)),
			new MineableBlock(Blocks.endRodFacingDown, MiningTool.init, Drop(Items.endRod, 1)),
			new MineableBlock(Blocks.endRodFacingUp, MiningTool.init, Drop(Items.endRod, 1)),
			new MineableBlock(Blocks.endRodFacingNorth, MiningTool.init, Drop(Items.endRod, 1)),
			new MineableBlock(Blocks.endRodFacingSouth, MiningTool.init, Drop(Items.endRod, 1)),
			new MineableBlock(Blocks.endRodFacingWest, MiningTool.init, Drop(Items.endRod, 1)),
			new MineableBlock(Blocks.endRodFacingEast, MiningTool.init, Drop(Items.endRod, 1)),
			new MineableBlock(Blocks.purpurBlock, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurBlock, 1)),
			new MineableBlock(Blocks.purpurPillarVertical, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1)),
			new MineableBlock(Blocks.purpurPillarEastWest, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1)),
			new MineableBlock(Blocks.purpurPillarNorthSouth, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1)),
			new MineableBlock(Blocks.netherWartBlock, MiningTool.init, Drop(Items.netherWartBlock, 1)),
			new MineableBlock(Blocks.boneBlockVertical, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1)),
			new MineableBlock(Blocks.boneBlockEastWest, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1)),
			new MineableBlock(Blocks.boneBlockNorthSouth, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1)),
			new Block(Blocks.structureVoid),
			new Block(Blocks.updateBlock),
			new Block(Blocks.ateupdBlock),
		];

	}

}

interface Blocks {

	static import sul.blocks;

	mixin((){
		string ret;
		foreach(member ; __traits(allMembers, sul.blocks.Blocks)) {
			ret ~= "alias " ~ member ~ "=sul.blocks.Blocks." ~ member ~ ";";
		}
		return ret;
	}());

	// dirt and related
	enum block_t[] farmland = [farmland0, farmland1, farmland2, farmland3, farmland4, farmland5, farmland6, farmland7];
	enum block_t[] dirts = cast(block_t[])[dirt, grass, podzol, coarseDirt] ~ farmland;

	// wooden logs
	enum block_t[] oakWood = [oakWoodUpDown, oakWoodEastWest, oakWoodNorthSouth, oakWoodBark];
	enum block_t[] spruceWood = [spruceWoodUpDown, spruceWoodEastWest, spruceWoodNorthSouth, spruceWoodBark];
	enum block_t[] birchWood = [birchWoodUpDown, birchWoodEastWest, birchWoodNorthSouth, birchWoodBark];
	enum block_t[] jungleWood = [jungleWoodUpDown, jungleWoodEastWest, jungleWoodNorthSouth, jungleWoodBark];
	enum block_t[] acaciaWood = [acaciaWoodUpDown, acaciaWoodEastWest, acaciaWoodNorthSouth, acaciaWoodBark];
	enum block_t[] darkOakWood = [darkOakWoodUpDown, darkOakWoodEastWest, darkOakWoodNorthSouth, darkOakWoodBark];
	enum block_t[] wood = oakWood ~ spruceWood ~ birchWood ~ jungleWood ~ acaciaWood ~ darkOakWood;

	// wooden logs (in another order)
	enum block_t[] woodUpDown = [oakWoodUpDown, spruceWoodUpDown, birchWoodUpDown, jungleWoodUpDown, acaciaWoodUpDown, darkOakWoodUpDown];
	enum block_t[] woodEastWest = [oakWoodEastWest, spruceWoodEastWest, birchWoodEastWest, jungleWoodEastWest, acaciaWoodEastWest, darkOakWoodEastWest];
	enum block_t[] woodNorthSouth = [oakWoodNorthSouth, spruceWoodNorthSouth, birchWoodNorthSouth, jungleWoodNorthSouth, acaciaWoodNorthSouth, darkOakWoodNorthSouth];
	enum block_t[] woodBark = [oakWoodBark, spruceWoodBark, birchWoodBark, jungleWoodBark, acaciaWoodBark, darkOakWoodBark];

	// planks

	// leaves
	enum block_t[] oakLeaves = [oakLeavesDecay, oakLeavesNoDecay, oakLeavesCheckDecay, oakLeavesNoDecayCheckDecay];
	enum block_t[] spruceLeaves = [spruceLeavesDecay, spruceLeavesNoDecay, spruceLeavesCheckDecay, spruceLeavesNoDecayCheckDecay];
	enum block_t[] birchLeaves = [birchLeavesDecay, birchLeavesNoDecay, birchLeavesCheckDecay, birchLeavesNoDecayCheckDecay];
	enum block_t[] jungleLeaves = [jungleLeavesDecay, jungleLeavesNoDecay, jungleLeavesCheckDecay, jungleLeavesNoDecayCheckDecay];
	enum block_t[] acaciaLeaves = [acaciaLeavesDecay, acaciaLeavesNoDecay, acaciaLeavesCheckDecay, acaciaLeavesNoDecayCheckDecay];
	enum block_t[] darkOakLeaves = [darkOakLeavesDecay, darkOakLeavesNoDecay, darkOakLeavesCheckDecay, darkOakLeavesNoDecayCheckDecay];
	enum block_t[] leaves = oakLeaves ~ spruceLeaves ~ birchLeaves ~ jungleLeaves ~ acaciaLeaves ~ darkOakLeaves;

	// leaves (in another order)
	enum block_t[] leavesDecay = [oakLeavesDecay, spruceLeavesDecay, birchLeavesDecay, jungleLeavesDecay, acaciaLeavesDecay, darkOakLeavesDecay];
	enum block_t[] leavesNoDecay = [oakLeavesNoDecay, spruceLeavesNoDecay, birchLeavesNoDecay, jungleLeavesNoDecay, acaciaLeavesNoDecay, darkOakLeavesNoDecay];
	enum block_t[] leavesCheckDecay = [oakLeavesCheckDecay, spruceLeavesCheckDecay, birchLeavesCheckDecay, jungleLeavesCheckDecay, acaciaLeavesCheckDecay, darkOakLeavesCheckDecay];
	enum block_t[] leavesNoDecayCheckDecay = [oakLeavesNoDecayCheckDecay, spruceLeavesNoDecayCheckDecay, birchLeavesNoDecayCheckDecay, jungleLeavesNoDecayCheckDecay, acaciaLeavesNoDecayCheckDecay, darkOakLeavesNoDecayCheckDecay];

	// water
	enum block_t[] flowingWater = [flowingWater0, flowingWater1, flowingWater2, flowingWater3, flowingWater4, flowingWater5, flowingWater6, flowingWater7];
	enum block_t[] flowingWaterFalling = [flowingWaterFalling0, flowingWaterFalling1, flowingWaterFalling2, flowingWaterFalling3, flowingWaterFalling4, flowingWaterFalling5, flowingWaterFalling6, flowingWaterFalling7];
	enum block_t[] stillWater = [stillWater0, stillWater1, stillWater2, stillWater3, stillWater4, stillWater5, stillWater6, stillWater7];
	enum block_t[] stillWaterFalling = [stillWaterFalling0, stillWaterFalling1, stillWaterFalling2, stillWaterFalling3, stillWaterFalling4, stillWaterFalling5, stillWaterFalling6, stillWaterFalling7];
	enum block_t[] water = flowingWater ~ flowingWaterFalling ~ stillWater ~ stillWaterFalling;

	// lava
	enum block_t[] flowingLava = [flowingLava0, flowingLava1, flowingLava2, flowingLava3, flowingLava4, flowingLava5, flowingLava6, flowingLava7];
	enum block_t[] flowingLavaFalling = [flowingLavaFalling0, flowingLavaFalling1, flowingLavaFalling2, flowingLavaFalling3, flowingLavaFalling4, flowingLavaFalling5, flowingLavaFalling6, flowingLavaFalling7];
	enum block_t[] stillLava = [stillLava0, stillLava1, stillLava2, stillLava3, stillLava4, stillLava5, stillLava6, stillLava7];
	enum block_t[] stillLavaFalling = [stillLavaFalling0, stillLavaFalling1, stillLavaFalling2, stillLavaFalling3, stillLavaFalling4, stillLavaFalling5, stillLavaFalling6, stillLavaFalling7];
	enum block_t[] lava = flowingLava ~ flowingLavaFalling ~ stillLava ~ stillLavaFalling;

	// stairs
	enum block_t[] cobblestoneStairs = [cobblestoneStairsFacingEast, cobblestoneStairsFacingWest, cobblestoneStairsFacingSouth, cobblestoneStairsFacingNorth, upsideDownCobblestoneStairsFacingEast, upsideDownCobblestoneStairsFacingWest, upsideDownCobblestoneStairsFacingSouth, upsideDownCobblestoneStairsFacingNorth];
	enum block_t[] brickStairs = [brickStairsFacingEast, brickStairsFacingWest, brickStairsFacingSouth, brickStairsFacingNorth, upsideDownBrickStairsFacingEast, upsideDownBrickStairsFacingWest, upsideDownBrickStairsFacingSouth, upsideDownBrickStairsFacingNorth];
	enum block_t[] netherStairs = [netherBrickStairsFacingEast, netherBrickStairsFacingWest, netherBrickStairsFacingSouth, netherBrickStairsFacingNorth, upsideDownNetherBrickStairsFacingEast, upsideDownNetherBrickStairsFacingWest, upsideDownNetherBrickStairsFacingSouth, upsideDownNetherBrickStairsFacingNorth];
	enum block_t[] stoneBrickStairs = [stoneBrickStairsFacingEast, stoneBrickStairsFacingWest, stoneBrickStairsFacingSouth, stoneBrickStairsFacingNorth, upsideDownStoneBrickStairsFacingEast, upsideDownStoneBrickStairsFacingWest, upsideDownStoneBrickStairsFacingSouth, upsideDownStoneBrickStairsFacingNorth];
	enum block_t[] purpurStairs = [purpurStairsFacingEast, purpurStairsFacingWest, purpurStairsFacingSouth, purpurStairsFacingNorth, upsideDownPurpurStairsFacingEast, upsideDownPurpurStairsFacingWest, upsideDownPurpurStairsFacingSouth, upsideDownPurpurStairsFacingNorth];
	enum block_t[] quartzStairs = [quartzStairsFacingEast, quartzStairsFacingWest, quartzStairsFacingSouth, quartzStairsFacingNorth, upsideDownQuartzStairsFacingEast, upsideDownQuartzStairsFacingWest, upsideDownQuartzStairsFacingSouth, upsideDownQuartzStairsFacingNorth];
	enum block_t[] sandstoneStairs = [sandstoneStairsFacingEast, sandstoneStairsFacingWest, sandstoneStairsFacingSouth, sandstoneStairsFacingNorth, upsideDownSandstoneStairsFacingEast, upsideDownSandstoneStairsFacingWest, upsideDownSandstoneStairsFacingSouth, upsideDownSandstoneStairsFacingNorth];
	enum block_t[] redSandstoneStairs = [redSandstoneStairsFacingEast, redSandstoneStairsFacingWest, redSandstoneStairsFacingSouth, redSandstoneStairsFacingNorth, upsideDownRedSandstoneStairsFacingEast, upsideDownRedSandstoneStairsFacingWest, upsideDownRedSandstoneStairsFacingSouth, upsideDownRedSandstoneStairsFacingNorth];
	enum block_t[] oakWoodStairs = [oakWoodStairsFacingEast, oakWoodStairsFacingWest, oakWoodStairsFacingSouth, oakWoodStairsFacingNorth, upsideDownOakWoodStairsFacingEast, upsideDownOakWoodStairsFacingWest, upsideDownOakWoodStairsFacingSouth, upsideDownOakWoodStairsFacingNorth];
	enum block_t[] spruceWoodStairs = [spruceWoodStairsFacingEast, spruceWoodStairsFacingWest, spruceWoodStairsFacingSouth, spruceWoodStairsFacingNorth, upsideDownSpruceWoodStairsFacingEast, upsideDownSpruceWoodStairsFacingWest, upsideDownSpruceWoodStairsFacingSouth, upsideDownSpruceWoodStairsFacingNorth];
	enum block_t[] birchWoodStairs = [birchWoodStairsFacingEast, birchWoodStairsFacingWest, birchWoodStairsFacingSouth, birchWoodStairsFacingNorth, upsideDownBirchWoodStairsFacingEast, upsideDownBirchWoodStairsFacingWest, upsideDownBirchWoodStairsFacingSouth, upsideDownBirchWoodStairsFacingNorth];
	enum block_t[] jungleWoodStairs = [jungleWoodStairsFacingEast, jungleWoodStairsFacingWest, jungleWoodStairsFacingSouth, jungleWoodStairsFacingNorth, upsideDownJungleWoodStairsFacingEast, upsideDownJungleWoodStairsFacingWest, upsideDownJungleWoodStairsFacingSouth, upsideDownJungleWoodStairsFacingNorth];
	enum block_t[] acaciaWoodStairs = [acaciaWoodStairsFacingEast, acaciaWoodStairsFacingWest, acaciaWoodStairsFacingSouth, acaciaWoodStairsFacingNorth, upsideDownAcaciaWoodStairsFacingEast, upsideDownAcaciaWoodStairsFacingWest, upsideDownAcaciaWoodStairsFacingSouth, upsideDownAcaciaWoodStairsFacingNorth];
	enum block_t[] darkOakWoodStairs = [darkOakWoodStairsFacingEast, darkOakWoodStairsFacingWest, darkOakWoodStairsFacingSouth, darkOakWoodStairsFacingNorth, upsideDownDarkOakWoodStairsFacingEast, upsideDownDarkOakWoodStairsFacingWest, upsideDownDarkOakWoodStairsFacingSouth, upsideDownDarkOakWoodStairsFacingNorth];

	// blocks with colours
	enum block_t[] wool = [whiteWool, orangeWool, magentaWool, lightBlueWool, yellowWool, limeWool, pinkWool, grayWool, lightGrayWool, cyanWool, purpleWool, blueWool, brownWool, greenWool, redWool, blackWool];
	enum block_t[] stainedClay = [whiteStainedClay, orangeStainedClay, magentaStainedClay, lightBlueStainedClay, yellowStainedClay, limeStainedClay, pinkStainedClay, grayStainedClay, lightGrayStainedClay, cyanStainedClay, purpleStainedClay, blueStainedClay, brownStainedClay, greenStainedClay, redStainedClay, blackStainedClay];

	// torches
	enum block_t[] torch = [torchFacingUp, torchFacingEast, torchFacingWest, torchFacingSouth, torchFacingNorth];
	enum block_t[] redstoneTorch = [redstoneTorchFacingUp, redstoneTorchFacingEast, redstoneTorchFacingWest, redstoneTorchFacingSouth, redstoneTorchFacingNorth];

	// farming
	enum block_t[] sugarCanes = [sugarCanes0, sugarCanes1, sugarCanes2, sugarCanes3, sugarCanes4, sugarCanes5, sugarCanes6, sugarCanes7, sugarCanes8, sugarCanes9, sugarCanes10, sugarCanes11, sugarCanes12, sugarCanes13, sugarCanes14, sugarCanes15];
	enum block_t[] cactus = [cactus0, cactus1, cactus2, cactus3, cactus4, cactus5, cactus6, cactus7, cactus8, cactus9, cactus10, cactus11, cactus12, cactus13, cactus14, cactus15];

	// products of the earth
	enum block_t[] pumpkin = [pumpkinFacingSouth, pumpkinFacingWest, pumpkinFacingNorth, pumpkinFacingEast, facelessPumpkinFacingSouth, facelessPumpkinFacingWest, facelessPumpkinFacingNorth, facelessPumpkinFacingEast];

	// ice
	enum block_t[] frostedIce = [frostedIce0, frostedIce1, frostedIce2, frostedIce3];

	// cauldron
	enum block_t[] cauldron = [cauldronEmpty, cauldronOneSixthFilled, cauldronOneThirdFilled, cauldronThreeSixthFilled, cauldronTwoThirdFilled, cauldronFiveSixthFilled, cauldronFilled];

}
