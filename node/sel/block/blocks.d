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

import sel.about : block_t, item_t;
import sel.block.block : Block;
import sel.block.farming;
import sel.block.fluid;
import sel.block.miscellaneous;
import sel.block.redstone;
import sel.block.solid;
import sel.block.tile;
import sel.item.items : Items;
import sel.item.tool : Tools;

import sul.blocks : _ = Blocks;

/**
 * Storage for a world's blocks.
 */
public class BlockStorage {

	private static BlockStorage instance;
	
	private Block[] sel;
	private Block*[][256] minecraft, pocket;
	
	public this() {
		if(instance is null) {
			this.instantiateDefaultBlocks();
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

	version(NoBlocks) {

		private void instantiateDefaultBlocks() {}

	} else {

		private void instantiateDefaultBlocks() {

			const woodPickaxe = MiningTool(true, Tools.pickaxe, Tools.wood);
			const stonePickaxe = MiningTool(true, Tools.pickaxe, Tools.stone);
			const ironPickaxe = MiningTool(true, Tools.pickaxe, Tools.iron);
			const diamondPickaxe = MiningTool(true, Tools.pickaxe, Tools.diamond);

			const woodAxe = MiningTool(false, Tools.axe, Tools.wood);

			this.register(new Block(_.air));
			this.register(new StoneBlock(_.stone, Items.cobblestone, Items.stone));
			this.register(new StoneBlock(_.granite, Items.granite));
			this.register(new StoneBlock(_.polishedGranite, Items.polishedGranite));
			this.register(new StoneBlock(_.diorite, Items.diorite));
			this.register(new StoneBlock(_.polishedDiorite, Items.polishedDiorite));
			this.register(new StoneBlock(_.andesite, Items.andesite));
			this.register(new StoneBlock(_.polishedAndesite, Items.polishedAndesite));
			this.register(new StoneBlock(_.stoneBricks, Items.stoneBricks));
			this.register(new StoneBlock(_.mossyStoneBricks, Items.mossyStoneBricks));
			this.register(new StoneBlock(_.crackedStoneBricks, Items.crackedStoneBricks));
			this.register(new StoneBlock(_.chiseledStoneBricks, Items.chiseledStoneBricks));
			this.register(new StoneBlock(_.cobblestone, Items.cobblestone));
			this.register(new StoneBlock(_.mossStone, Items.mossStone));
			this.register(new StoneBlock(_.cobblestoneWall, Items.cobblestoneWall));
			this.register(new StoneBlock(_.mossyCobblestoneWall, Items.mossyCobblestoneWall));
			this.register(new StoneBlock(_.bricks, Items.bricks));
			this.register(new MineableBlock(_.coalOre, woodPickaxe, Drop(Items.coal, 1, 1, Items.coalOre, &Drop.plusOne), Experience(0, 2)));
			this.register(new MineableBlock(_.ironOre, stonePickaxe, Drop(Items.ironOre, 1)));
			this.register(new MineableBlock(_.goldOre, ironPickaxe, Drop(Items.goldOre, 1)));
			this.register(new MineableBlock(_.diamondOre, ironPickaxe, Drop(Items.diamond, 1, 1, Items.diamondOre))); //TODO +1 with fortune
			this.register(new MineableBlock(_.emeraldOre, ironPickaxe, Drop(Items.emerald, 1, 1, Items.emeraldOre))); //TODO +1 with fortune
			this.register(new MineableBlock(_.lapisLazuliOre, stonePickaxe, Drop(Items.lapisLazuli, 4, 8, Items.lapisLazuliOre), Experience(2, 5))); //TODO fortune
			this.register(new RedstoneOreBlock!false(_.redstoneOre, Blocks.litRedstoneOre));
			this.register(new RedstoneOreBlock!true(_.litRedstoneOre, Blocks.redstoneOre));
			this.register(new MineableBlock(_.netherQuartzOre, woodPickaxe, Drop(Items.netherQuartz, 2, 5, Items.netherQuartzOre), Experience(2, 5, 1))); //TODO fortune
			this.register(new MineableBlock(_.coalBlock, woodPickaxe, Drop(Items.coalBlock, 1)));
			this.register(new MineableBlock(_.ironBlock, stonePickaxe, Drop(Items.ironBlock, 1)));
			this.register(new MineableBlock(_.goldBlock, ironPickaxe, Drop(Items.goldBlock, 1)));
			this.register(new MineableBlock(_.diamondBlock, ironPickaxe, Drop(Items.diamondBlock, 1)));
			this.register(new MineableBlock(_.emeraldBlock, ironPickaxe, Drop(Items.emeraldBlock, 1)));
			this.register(new MineableBlock(_.redstoneBlock, woodPickaxe, Drop(Items.redstoneBlock, 1)));
			this.register(new MineableBlock(_.lapisLazuliOre, stonePickaxe, Drop(Items.lapisLazuliBlock, 1)));
			this.register(new MineableBlock(_.netherReactorCore, woodPickaxe, [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]));
			this.register(new MineableBlock(_.activeNetherReactorCore, woodPickaxe, [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]));
			this.register(new MineableBlock(_.usedNetherReactorCore, woodPickaxe, [Drop(Items.diamond, 3), Drop(Items.ironIngot, 6)]));
			this.register(new SuffocatingSpreadingBlock(_.grass, MiningTool(false, Tools.shovel, Tools.wood), [Drop(Items.dirt, 1, 1, Items.grass)], [Blocks.dirt], 1, 1, 2, 2, Blocks.dirt));
			this.register(new MineableBlock(_.dirt, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1)));
			this.register(new MineableBlock(_.coarseDirt, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1)));
			this.register(new MineableBlock(_.podzol, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.dirt, 1, 1, Items.podzol)));
			this.register(new SpreadingBlock(_.mycelium, MiningTool(false, Tools.shovel, Tools.wood), [Drop(Items.dirt, 1, 1, Items.mycelium)], [Blocks.dirt, Blocks.grass, Blocks.podzol], 1, 1, 3, 1));
			this.register(new MineableBlock(_.grassPath, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.grassPath, 1)));
			this.register(new FertileTerrainBlock!false(_.farmland0, Blocks.farmland7, Blocks.dirt));
			this.register(new FertileTerrainBlock!false(_.farmland1, Blocks.farmland7, Blocks.farmland0));
			this.register(new FertileTerrainBlock!false(_.farmland2, Blocks.farmland7, Blocks.farmland1));
			this.register(new FertileTerrainBlock!false(_.farmland3, Blocks.farmland7, Blocks.farmland2));
			this.register(new FertileTerrainBlock!false(_.farmland4, Blocks.farmland7, Blocks.farmland4));
			this.register(new FertileTerrainBlock!false(_.farmland5, Blocks.farmland7, Blocks.farmland4));
			this.register(new FertileTerrainBlock!false(_.farmland6, Blocks.farmland7, Blocks.farmland5));
			this.register(new FertileTerrainBlock!true(_.farmland7, 0, Blocks.farmland6));
			this.register(new MineableBlock(_.oakWoodPlanks, woodAxe, Drop(Items.oakWoodPlanks, 1)));
			this.register(new MineableBlock(_.spruceWoodPlanks, woodAxe, Drop(Items.spruceWoodPlanks, 1)));
			this.register(new MineableBlock(_.birchWoodPlanks, woodAxe, Drop(Items.birchWoodPlanks, 1)));
			this.register(new MineableBlock(_.jungleWoodPlanks, woodAxe, Drop(Items.jungleWoodPlanks, 1)));
			this.register(new MineableBlock(_.acaciaWoodPlanks, woodAxe, Drop(Items.acaciaWoodPlanks, 1)));
			this.register(new MineableBlock(_.darkOakWoodPlanks, woodAxe, Drop(Items.darkOakWoodPlanks, 1)));
			this.register(new SaplingBlock(_.oakSapling, Items.oakSapling, Blocks.oakWood, Blocks.oakLeaves));
			this.register(new SaplingBlock(_.spruceSapling, Items.spruceSapling, Blocks.spruceWood, Blocks.spruceLeaves));
			this.register(new SaplingBlock(_.birchSapling, Items.birchSapling, Blocks.birchWood, Blocks.birchLeaves));
			this.register(new SaplingBlock(_.jungleSapling, Items.jungleSapling, Blocks.jungleWood, Blocks.jungleLeaves));
			this.register(new SaplingBlock(_.acaciaSapling, Items.acaciaSapling, Blocks.acaciaWood, Blocks.acaciaLeaves));
			this.register(new SaplingBlock(_.darkOakSapling, Items.darkOakSapling, Blocks.darkOakWood, Blocks.darkOakLeaves));
			this.register(new Block(_.bedrock));
			this.register(new GravityBlock(_.sand, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.sand, 1)));
			this.register(new GravityBlock(_.redSand, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.redSand, 1)));
			this.register(new GravelBlock(_.gravel));
			this.register(new WoodBlock(_.oakWoodUpDown, Items.oakWood));
			this.register(new WoodBlock(_.oakWoodEastWest, Items.oakWood));
			this.register(new WoodBlock(_.oakWoodNorthSouth, Items.oakWood));
			this.register(new WoodBlock(_.oakWoodBark, Items.oakWood));
			this.register(new WoodBlock(_.spruceWoodUpDown, Items.spruceWood));
			this.register(new WoodBlock(_.spruceWoodEastWest, Items.spruceWood));
			this.register(new WoodBlock(_.spruceWoodNorthSouth, Items.spruceWood));
			this.register(new WoodBlock(_.spruceWoodBark, Items.spruceWood));
			this.register(new WoodBlock(_.birchWoodUpDown, Items.birchWood));
			this.register(new WoodBlock(_.birchWoodEastWest, Items.birchWood));
			this.register(new WoodBlock(_.birchWoodNorthSouth, Items.birchWood));
			this.register(new WoodBlock(_.birchWoodBark, Items.birchWood));
			this.register(new WoodBlock(_.jungleWoodUpDown, Items.jungleWood));
			this.register(new WoodBlock(_.jungleWoodEastWest, Items.jungleWood));
			this.register(new WoodBlock(_.jungleWoodNorthSouth, Items.jungleWood));
			this.register(new WoodBlock(_.jungleWoodBark, Items.jungleWood));
			this.register(new WoodBlock(_.acaciaWoodUpDown, Items.acaciaWood));
			this.register(new WoodBlock(_.acaciaWoodEastWest, Items.acaciaWood));
			this.register(new WoodBlock(_.acaciaWoodNorthSouth, Items.acaciaWood));
			this.register(new WoodBlock(_.acaciaWoodBark, Items.acaciaWood));
			this.register(new WoodBlock(_.darkOakWoodUpDown, Items.darkOakWood));
			this.register(new WoodBlock(_.darkOakWoodEastWest, Items.darkOakWood));
			this.register(new WoodBlock(_.darkOakWoodNorthSouth, Items.darkOakWood));
			this.register(new WoodBlock(_.darkOakWoodBark, Items.darkOakWood));
			this.register(new LeavesBlock!(true, true)(_.oakLeavesDecay, Items.oakLeaves, Items.oakSapling, false));
			this.register(new LeavesBlock!(false, true)(_.oakLeavesNoDecay, Items.oakLeaves, Items.oakSapling, false));
			this.register(new LeavesBlock!(true, true)(_.oakLeavesCheckDecay, Items.oakLeaves, Items.oakSapling, false));
			this.register(new LeavesBlock!(false, true)(_.oakLeavesNoDecayCheckDecay, Items.oakLeaves, Items.oakSapling, false));
			this.register(new LeavesBlock!(true, false)(_.spruceLeavesDecay, Items.spruceLeaves, Items.spruceSapling, false));
			this.register(new LeavesBlock!(false, false)(_.spruceLeavesNoDecay, Items.spruceLeaves, Items.spruceSapling, false));
			this.register(new LeavesBlock!(true, false)(_.spruceLeavesCheckDecay, Items.spruceLeaves, Items.spruceSapling, false));
			this.register(new LeavesBlock!(true, false)(_.spruceLeavesNoDecayCheckDecay, Items.spruceLeaves, Items.spruceSapling, false));
			this.register(new LeavesBlock!(true, false)(_.birchLeavesDecay, Items.birchLeaves, Items.birchSapling, false));
			this.register(new LeavesBlock!(false, false)(_.birchLeavesNoDecay, Items.birchLeaves, Items.birchSapling, false));
			this.register(new LeavesBlock!(true, false)(_.birchLeavesCheckDecay, Items.birchLeaves, Items.birchSapling, false));
			this.register(new LeavesBlock!(false, false)(_.birchLeavesNoDecayCheckDecay, Items.birchLeaves, Items.birchSapling, false));
			this.register(new LeavesBlock!(true, false)(_.jungleLeavesDecay, Items.jungleLeaves, Items.jungleSapling, true));
			this.register(new LeavesBlock!(false, false)(_.jungleLeavesNoDecay, Items.jungleLeaves, Items.jungleSapling, true));
			this.register(new LeavesBlock!(true, false)(_.jungleLeavesCheckDecay, Items.jungleLeaves, Items.jungleSapling, true));
			this.register(new LeavesBlock!(false, true)(_.jungleLeavesNoDecayCheckDecay, Items.jungleLeaves, Items.jungleSapling, true));
			this.register(new LeavesBlock!(true, false)(_.acaciaLeavesDecay, Items.acaciaLeaves, Items.acaciaSapling, false));
			this.register(new LeavesBlock!(false, false)(_.acaciaLeavesNoDecay, Items.acaciaLeaves, Items.acaciaSapling, false));
			this.register(new LeavesBlock!(true, false)(_.acaciaLeavesCheckDecay, Items.acaciaLeaves, Items.acaciaSapling, false));
			this.register(new LeavesBlock!(false, false)(_.acaciaLeavesNoDecayCheckDecay, Items.acaciaLeaves, Items.acaciaSapling, false));
			this.register(new LeavesBlock!(true, true)(_.darkOakLeavesDecay, Items.darkOakLeaves, Items.darkOakSapling, false));
			this.register(new LeavesBlock!(false, true)(_.darkOakLeavesNoDecay, Items.darkOakLeaves, Items.darkOakSapling, false));
			this.register(new LeavesBlock!(true, true)(_.darkOakLeavesCheckDecay, Items.darkOakLeaves, Items.darkOakSapling, false));
			this.register(new LeavesBlock!(false, true)(_.darkOakLeavesNoDecayCheckDecay, Items.darkOakLeaves, Items.darkOakSapling, false));
			this.register(new AbsorbingBlock(_.sponge, Items.sponge, Blocks.wetSponge, Blocks.water, 7, 65));
			this.register(new MineableBlock(_.wetSponge, MiningTool.init, Drop(Items.wetSponge, 1)));
			this.register(new MineableBlock(_.glass, MiningTool.init, Drop(0, 0, 0, Items.glass)));
			this.register(new MineableBlock(_.whiteStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.whiteStainedGlass)));
			this.register(new MineableBlock(_.orangeStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.orangeStainedGlass)));
			this.register(new MineableBlock(_.magentaStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.magentaStainedGlass)));
			this.register(new MineableBlock(_.lightBlueStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.lightBlueStainedGlass)));
			this.register(new MineableBlock(_.yellowStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.yellowStainedGlass)));
			this.register(new MineableBlock(_.limeStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.limeStainedGlass)));
			this.register(new MineableBlock(_.pinkStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.pinkStainedGlass)));
			this.register(new MineableBlock(_.grayStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.grayStainedGlass)));
			this.register(new MineableBlock(_.lightGrayStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.lightGrayStainedGlass)));
			this.register(new MineableBlock(_.cyanStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.cyanStainedGlass)));
			this.register(new MineableBlock(_.purpleStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.purpleStainedGlass)));
			this.register(new MineableBlock(_.blueStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.blueStainedGlass)));
			this.register(new MineableBlock(_.brownStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.brownStainedGlass)));
			this.register(new MineableBlock(_.greenStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.greenStainedGlass)));
			this.register(new MineableBlock(_.redStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.redStainedGlass)));
			this.register(new MineableBlock(_.blackStainedGlass, MiningTool.init, Drop(0, 0, 0, Items.blackStainedGlass)));
			this.register(new MineableBlock(_.glassPane, MiningTool.init, Drop(0, 0, 0, Items.glassPane)));
			this.register(new MineableBlock(_.whiteStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.whiteStainedGlassPane)));
			this.register(new MineableBlock(_.orangeStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.orangeStainedGlassPane)));
			this.register(new MineableBlock(_.magentaStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.magentaStainedGlassPane)));
			this.register(new MineableBlock(_.lightBlueStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.lightBlueStainedGlassPane)));
			this.register(new MineableBlock(_.yellowStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.yellowStainedGlassPane)));
			this.register(new MineableBlock(_.limeStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.limeStainedGlassPane)));
			this.register(new MineableBlock(_.pinkStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.pinkStainedGlassPane)));
			this.register(new MineableBlock(_.grayStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.grayStainedGlassPane)));
			this.register(new MineableBlock(_.lightGrayStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.lightGrayStainedGlassPane)));
			this.register(new MineableBlock(_.cyanStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.cyanStainedGlassPane)));
			this.register(new MineableBlock(_.purpleStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.purpleStainedGlassPane)));
			this.register(new MineableBlock(_.blueStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.blueStainedGlassPane)));
			this.register(new MineableBlock(_.brownStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.brownStainedGlassPane)));
			this.register(new MineableBlock(_.greenStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.greenStainedGlassPane)));
			this.register(new MineableBlock(_.redStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.redStainedGlassPane)));
			this.register(new MineableBlock(_.blackStainedGlassPane, MiningTool.init, Drop(0, 0, 0, Items.blackStainedGlassPane)));
			this.register(new MineableBlock(_.sandstone, woodPickaxe, Drop(Items.sandstone, 1)));
			this.register(new MineableBlock(_.chiseledSandstone, woodPickaxe, Drop(Items.chiseledSandstone, 1)));
			this.register(new MineableBlock(_.smoothSandstone, woodPickaxe, Drop(Items.smoothSandstone, 1)));
			this.register(new MineableBlock(_.redSandstone, woodPickaxe, Drop(Items.redSandstone, 1)));
			this.register(new MineableBlock(_.chiseledRedSandstone, woodPickaxe, Drop(Items.chiseledRedSandstone, 1)));
			this.register(new MineableBlock(_.smoothRedSandstone, woodPickaxe, Drop(Items.smoothRedSandstone, 1)));
			this.register(new MineableBlock(_.whiteWool, MiningTool(false, Tools.shears), Drop(Items.whiteWool, 1)));
			this.register(new MineableBlock(_.orangeWool, MiningTool(false, Tools.shears), Drop(Items.orangeWool, 1)));
			this.register(new MineableBlock(_.magentaWool, MiningTool(false, Tools.shears), Drop(Items.magentaWool, 1)));
			this.register(new MineableBlock(_.lightBlueWool, MiningTool(false, Tools.shears), Drop(Items.lightBlueWool, 1)));
			this.register(new MineableBlock(_.yellowWool, MiningTool(false, Tools.shears), Drop(Items.yellowWool, 1)));
			this.register(new MineableBlock(_.limeWool, MiningTool(false, Tools.shears), Drop(Items.limeWool, 1)));
			this.register(new MineableBlock(_.pinkWool, MiningTool(false, Tools.shears), Drop(Items.pinkWool, 1)));
			this.register(new MineableBlock(_.grayWool, MiningTool(false, Tools.shears), Drop(Items.grayWool, 1)));
			this.register(new MineableBlock(_.lightGrayWool, MiningTool(false, Tools.shears), Drop(Items.lightGrayWool, 1)));
			this.register(new MineableBlock(_.cyanWool, MiningTool(false, Tools.shears), Drop(Items.cyanWool, 1)));
			this.register(new MineableBlock(_.purpleWool, MiningTool(false, Tools.shears), Drop(Items.purpleWool, 1)));
			this.register(new MineableBlock(_.blueWool, MiningTool(false, Tools.shears), Drop(Items.blueWool, 1)));
			this.register(new MineableBlock(_.brownWool, MiningTool(false, Tools.shears), Drop(Items.brownWool, 1)));
			this.register(new MineableBlock(_.greenWool, MiningTool(false, Tools.shears), Drop(Items.greenWool, 1)));
			this.register(new MineableBlock(_.redWool, MiningTool(false, Tools.shears), Drop(Items.redWool, 1)));
			this.register(new MineableBlock(_.blackWool, MiningTool(false, Tools.shears), Drop(Items.blackWool, 1)));
			this.register(new MineableBlock(_.whiteCarpet, MiningTool.init, Drop(Items.whiteCarpet, 1)));
			this.register(new MineableBlock(_.orangeCarpet, MiningTool.init, Drop(Items.orangeCarpet, 1)));
			this.register(new MineableBlock(_.magentaCarpet, MiningTool.init, Drop(Items.magentaCarpet, 1)));
			this.register(new MineableBlock(_.lightBlueCarpet, MiningTool.init, Drop(Items.lightBlueCarpet, 1)));
			this.register(new MineableBlock(_.yellowCarpet, MiningTool.init, Drop(Items.yellowCarpet, 1)));
			this.register(new MineableBlock(_.limeCarpet, MiningTool.init, Drop(Items.limeCarpet, 1)));
			this.register(new MineableBlock(_.pinkCarpet, MiningTool.init, Drop(Items.pinkCarpet, 1)));
			this.register(new MineableBlock(_.grayCarpet, MiningTool.init, Drop(Items.grayCarpet, 1)));
			this.register(new MineableBlock(_.lightGrayCarpet, MiningTool.init, Drop(Items.lightGrayCarpet, 1)));
			this.register(new MineableBlock(_.cyanCarpet, MiningTool.init, Drop(Items.cyanCarpet, 1)));
			this.register(new MineableBlock(_.purpleCarpet, MiningTool.init, Drop(Items.purpleCarpet, 1)));
			this.register(new MineableBlock(_.blueCarpet, MiningTool.init, Drop(Items.blueCarpet, 1)));
			this.register(new MineableBlock(_.brownCarpet, MiningTool.init, Drop(Items.brownCarpet, 1)));
			this.register(new MineableBlock(_.greenCarpet, MiningTool.init, Drop(Items.greenCarpet, 1)));
			this.register(new MineableBlock(_.redCarpet, MiningTool.init, Drop(Items.redCarpet, 1)));
			this.register(new MineableBlock(_.blackCarpet, MiningTool.init, Drop(Items.blackCarpet, 1)));
			this.register(new FlowerBlock(_.dandelion, Items.dandelion));
			this.register(new FlowerBlock(_.poppy, Items.poppy));
			this.register(new FlowerBlock(_.blueOrchid, Items.blueOrchid));
			this.register(new FlowerBlock(_.allium, Items.allium));
			this.register(new FlowerBlock(_.azureBluet, Items.azureBluet));
			this.register(new FlowerBlock(_.redTulip, Items.redTulip));
			this.register(new FlowerBlock(_.orangeTulip, Items.orangeTulip));
			this.register(new FlowerBlock(_.whiteTulip, Items.whiteTulip));
			this.register(new FlowerBlock(_.pinkTulip, Items.pinkTulip));
			this.register(new FlowerBlock(_.oxeyeDaisy, Items.oxeyeDaisy));
			this.register(new DoublePlantBlock(_.sunflowerBottom, false, Blocks.sunflowerTop, Items.sunflower));
			this.register(new DoublePlantBlock(_.sunflowerTop, true, Blocks.sunflowerBottom, Items.sunflower));
			this.register(new DoublePlantBlock(_.liliacBottom, false, Blocks.liliacTop, Items.liliac));
			this.register(new DoublePlantBlock(_.liliacTop, true, Blocks.liliacBottom, Items.liliac));
			this.register(new GrassDoublePlantBlock(_.doubleTallgrassBottom, false, Blocks.doubleTallgrassTop, Items.tallGrass));
			this.register(new GrassDoublePlantBlock(_.doubleTallgrassTop, true, Blocks.doubleTallgrassBottom, Items.tallGrass));
			this.register(new GrassDoublePlantBlock(_.largeFernBottom, false, Blocks.largeFernTop, Items.fern));
			this.register(new GrassDoublePlantBlock(_.largeFernTop, true, Blocks.largeFernBottom, Items.fern));
			this.register(new DoublePlantBlock(_.roseBushBottom, false, Blocks.roseBushTop, Items.roseBush));
			this.register(new DoublePlantBlock(_.roseBushTop, true, Blocks.roseBushBottom, Items.roseBush));
			this.register(new DoublePlantBlock(_.peonyBottom, false, Blocks.peonyTop, Items.peony));
			this.register(new DoublePlantBlock(_.peonyTop, true, Blocks.peonyBottom, Items.peony));
			this.register(new PlantBlock(_.tallGrass, Items.tallGrass, Drop(Items.seeds, 0, 1)));
			this.register(new PlantBlock(_.fern, Items.fern, Drop(Items.seeds, 0, 1)));
			this.register(new PlantBlock(_.deadBush, Items.deadBush, Drop(Items.stick, 0, 2)));
			this.register(new MineableBlock(_.stoneSlab, woodPickaxe, Drop(Items.stoneSlab, 1)));
			this.register(new MineableBlock(_.sandstoneSlab, woodPickaxe, Drop(Items.sandstoneSlab, 1)));
			this.register(new MineableBlock(_.stoneWoodenSlab, woodPickaxe, Drop(Items.stoneWoodenSlab, 1)));
			this.register(new MineableBlock(_.cobblestoneSlab, woodPickaxe, Drop(Items.cobblestoneSlab, 1)));
			this.register(new MineableBlock(_.bricksSlab, woodPickaxe, Drop(Items.bricksSlab, 1)));
			this.register(new MineableBlock(_.stoneBrickSlab, woodPickaxe, Drop(Items.stoneBrickSlab, 1)));
			this.register(new MineableBlock(_.netherBrickSlab, woodPickaxe, Drop(Items.netherBrickSlab, 1)));
			this.register(new MineableBlock(_.quartzSlab, woodPickaxe, Drop(Items.quartzSlab, 1)));
			this.register(new MineableBlock(_.redSandstoneSlab, woodPickaxe, Drop(Items.redSandstoneSlab, 1)));
			this.register(new MineableBlock(_.purpurSlab, woodPickaxe, Drop(Items.purpurSlab, 1)));
			this.register(new MineableBlock(_.oakWoodSlab, woodAxe, Drop(Items.oakWoodSlab, 1)));
			this.register(new MineableBlock(_.spruceWoodSlab, woodAxe, Drop(Items.spruceWoodSlab, 1)));
			this.register(new MineableBlock(_.birchWoodSlab, woodAxe, Drop(Items.birchWoodSlab, 1)));
			this.register(new MineableBlock(_.jungleWoodSlab, woodAxe, Drop(Items.jungleWoodSlab, 1)));
			this.register(new MineableBlock(_.acaciaWoodSlab, woodAxe, Drop(Items.acaciaWoodSlab, 1)));
			this.register(new MineableBlock(_.darkOakWoodSlab, woodAxe, Drop(Items.darkOakWoodSlab, 1)));
			this.register(new MineableBlock(_.upperStoneSlab, woodPickaxe, Drop(Items.stoneSlab, 1)));
			this.register(new MineableBlock(_.upperSandstoneSlab, woodPickaxe, Drop(Items.sandstoneSlab, 1)));
			this.register(new MineableBlock(_.upperStoneWoodenSlab, woodPickaxe, Drop(Items.stoneWoodenSlab, 1)));
			this.register(new MineableBlock(_.upperCobblestoneSlab, woodPickaxe, Drop(Items.cobblestoneSlab, 1)));
			this.register(new MineableBlock(_.upperBricksSlab, woodPickaxe, Drop(Items.bricksSlab, 1)));
			this.register(new MineableBlock(_.upperStoneBrickSlab, woodPickaxe, Drop(Items.stoneBrickSlab, 1)));
			this.register(new MineableBlock(_.upperNetherBrickSlab, woodPickaxe, Drop(Items.netherBrickSlab, 1)));
			this.register(new MineableBlock(_.upperQuartzSlab, woodPickaxe, Drop(Items.quartzSlab, 1)));
			this.register(new MineableBlock(_.upperRedSandstoneSlab, woodPickaxe, Drop(Items.redSandstoneSlab, 1)));
			this.register(new MineableBlock(_.upperPurpurSlab, woodPickaxe, Drop(Items.purpurSlab, 1)));
			this.register(new MineableBlock(_.upperOakWoodSlab, woodAxe, Drop(Items.oakWoodSlab, 1)));
			this.register(new MineableBlock(_.upperSpruceWoodSlab, woodAxe, Drop(Items.spruceWoodSlab, 1)));
			this.register(new MineableBlock(_.birchWoodSlab, woodAxe, Drop(Items.birchWoodSlab, 1)));
			this.register(new MineableBlock(_.upperJungleWoodSlab, woodAxe, Drop(Items.jungleWoodSlab, 1)));
			this.register(new MineableBlock(_.upperAcaciaWoodSlab, woodAxe, Drop(Items.acaciaWoodSlab, 1)));
			this.register(new MineableBlock(_.upperDarkOakWoodSlab, woodAxe, Drop(Items.darkOakWoodSlab, 1)));
			this.register(new MineableBlock(_.doubleStoneSlab, woodPickaxe, Drop(Items.stoneSlab, 2)));
			this.register(new MineableBlock(_.doubleSandstoneSlab, woodPickaxe, Drop(Items.sandstoneSlab, 2)));
			this.register(new MineableBlock(_.doubleStoneWoodenSlab, woodPickaxe, Drop(Items.stoneWoodenSlab, 2)));
			this.register(new MineableBlock(_.doubleCobblestoneSlab, woodPickaxe, Drop(Items.cobblestoneSlab, 2)));
			this.register(new MineableBlock(_.doubleBricksSlab, woodPickaxe, Drop(Items.bricksSlab, 1)));
			this.register(new MineableBlock(_.doubleStoneBrickSlab, woodPickaxe, Drop(Items.stoneBrickSlab, 2)));
			this.register(new MineableBlock(_.doubleNetherBrickSlab, woodPickaxe, Drop(Items.netherBrickSlab, 2)));
			this.register(new MineableBlock(_.doubleQuartzSlab, woodPickaxe, Drop(Items.quartzSlab, 2)));
			this.register(new MineableBlock(_.doubleRedSandstoneSlab, woodPickaxe, Drop(Items.redSandstoneSlab, 2)));
			this.register(new MineableBlock(_.doublePurpurSlab, woodPickaxe, Drop(Items.purpurSlab, 2)));
			this.register(new MineableBlock(_.doubleOakWoodSlab, woodAxe, Drop(Items.oakWoodSlab, 2)));
			this.register(new MineableBlock(_.doubleSpruceWoodSlab, woodAxe, Drop(Items.spruceWoodSlab, 2)));
			this.register(new MineableBlock(_.birchWoodSlab, woodAxe, Drop(Items.birchWoodSlab, 2)));
			this.register(new MineableBlock(_.doubleJungleWoodSlab, woodAxe, Drop(Items.jungleWoodSlab, 2)));
			this.register(new MineableBlock(_.doubleAcaciaWoodSlab, woodAxe, Drop(Items.acaciaWoodSlab, 2)));
			this.register(new MineableBlock(_.doubleDarkOakWoodSlab, woodAxe, Drop(Items.darkOakWoodSlab, 2)));
			this.register(new StairsBlock(_.cobblestoneStairsFacingEast, Facing.east, false, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.cobblestoneStairsFacingWest, Facing.west, false, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.cobblestoneStairsFacingSouth, Facing.south, false, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.cobblestoneStairsFacingNorth, Facing.north, false, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.upsideDownCobblestoneStairsFacingEast, Facing.east, true, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.upsideDownCobblestoneStairsFacingWest, Facing.west, true, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.upsideDownCobblestoneStairsFacingSouth, Facing.south, true, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.upsideDownCobblestoneStairsFacingNorth, Facing.north, true, woodPickaxe, Items.cobblestoneStairs));
			this.register(new StairsBlock(_.brickStairsFacingEast, Facing.east, false, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.brickStairsFacingWest, Facing.west, false, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.brickStairsFacingSouth, Facing.south, false, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.brickStairsFacingNorth, Facing.north, false, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.upsideDownBrickStairsFacingEast, Facing.east, true, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.upsideDownBrickStairsFacingWest, Facing.west, true, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.upsideDownBrickStairsFacingSouth, Facing.south, true, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.upsideDownBrickStairsFacingNorth, Facing.north, true, woodPickaxe, Items.brickStairs));
			this.register(new StairsBlock(_.netherBrickStairsFacingEast, Facing.east, false, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.netherBrickStairsFacingWest, Facing.west, false, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.netherBrickStairsFacingSouth, Facing.south, false, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.netherBrickStairsFacingNorth, Facing.north, false, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.upsideDownNetherBrickStairsFacingEast, Facing.east, true, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.upsideDownNetherBrickStairsFacingWest, Facing.west, true, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.upsideDownNetherBrickStairsFacingSouth, Facing.south, true, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.upsideDownNetherBrickStairsFacingNorth, Facing.north, true, woodPickaxe, Items.netherBrickStairs));
			this.register(new StairsBlock(_.stoneBrickStairsFacingEast, Facing.east, false, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.stoneBrickStairsFacingWest, Facing.west, false, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.stoneBrickStairsFacingSouth, Facing.south, false, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.stoneBrickStairsFacingNorth, Facing.north, false, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.upsideDownStoneBrickStairsFacingEast, Facing.east, true, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.upsideDownStoneBrickStairsFacingWest, Facing.west, true, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.upsideDownStoneBrickStairsFacingSouth, Facing.south, true, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.upsideDownStoneBrickStairsFacingNorth, Facing.north, true, woodPickaxe, Items.stoneBrickStairs));
			this.register(new StairsBlock(_.purpurStairsFacingEast, Facing.east, false, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.purpurStairsFacingWest, Facing.west, false, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.purpurStairsFacingSouth, Facing.south, false, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.purpurStairsFacingNorth, Facing.north, false, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.upsideDownPurpurStairsFacingEast, Facing.east, true, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.upsideDownPurpurStairsFacingWest, Facing.west, true, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.upsideDownPurpurStairsFacingSouth, Facing.south, true, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.upsideDownPurpurStairsFacingNorth, Facing.north, true, woodPickaxe, Items.purpurStairs));
			this.register(new StairsBlock(_.quartzStairsFacingEast, Facing.east, false, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.quartzStairsFacingWest, Facing.west, false, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.quartzStairsFacingSouth, Facing.south, false, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.quartzStairsFacingNorth, Facing.north, false, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.upsideDownQuartzStairsFacingEast, Facing.east, true, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.upsideDownQuartzStairsFacingWest, Facing.west, true, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.upsideDownQuartzStairsFacingSouth, Facing.south, true, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.upsideDownQuartzStairsFacingNorth, Facing.north, true, woodPickaxe, Items.quartzStairs));
			this.register(new StairsBlock(_.sandstoneStairsFacingEast, Facing.east, false, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.sandstoneStairsFacingWest, Facing.west, false, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.sandstoneStairsFacingSouth, Facing.south, false, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.sandstoneStairsFacingNorth, Facing.north, false, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.upsideDownSandstoneStairsFacingEast, Facing.east, true, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.upsideDownSandstoneStairsFacingWest, Facing.west, true, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.upsideDownSandstoneStairsFacingSouth, Facing.south, true, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.upsideDownSandstoneStairsFacingNorth, Facing.north, true, woodPickaxe, Items.sandstoneStairs));
			this.register(new StairsBlock(_.redSandstoneStairsFacingEast, Facing.east, false, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.redSandstoneStairsFacingWest, Facing.west, false, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.redSandstoneStairsFacingSouth, Facing.south, false, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.redSandstoneStairsFacingNorth, Facing.north, false, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.upsideDownRedSandstoneStairsFacingEast, Facing.east, true, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.upsideDownRedSandstoneStairsFacingWest, Facing.west, true, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.upsideDownRedSandstoneStairsFacingSouth, Facing.south, true, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.upsideDownRedSandstoneStairsFacingNorth, Facing.north, true, woodPickaxe, Items.redSandstoneStairs));
			this.register(new StairsBlock(_.oakWoodStairsFacingEast, Facing.east, false, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.oakWoodStairsFacingWest, Facing.west, false, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.oakWoodStairsFacingSouth, Facing.south, false, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.oakWoodStairsFacingNorth, Facing.north, false, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.upsideDownOakWoodStairsFacingEast, Facing.east, true, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.upsideDownOakWoodStairsFacingWest, Facing.west, true, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.upsideDownOakWoodStairsFacingSouth, Facing.south, true, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.upsideDownOakWoodStairsFacingNorth, Facing.north, true, woodAxe, Items.oakWoodStairs));
			this.register(new StairsBlock(_.spruceWoodStairsFacingEast, Facing.east, false, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.spruceWoodStairsFacingWest, Facing.west, false, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.spruceWoodStairsFacingSouth, Facing.south, false, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.spruceWoodStairsFacingNorth, Facing.north, false, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.upsideDownSpruceWoodStairsFacingEast, Facing.east, true, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.upsideDownSpruceWoodStairsFacingWest, Facing.west, true, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.upsideDownSpruceWoodStairsFacingSouth, Facing.south, true, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.upsideDownSpruceWoodStairsFacingNorth, Facing.north, true, woodAxe, Items.spruceWoodStairs));
			this.register(new StairsBlock(_.birchWoodStairsFacingEast, Facing.east, false, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.birchWoodStairsFacingWest, Facing.west, false, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.birchWoodStairsFacingSouth, Facing.south, false, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.birchWoodStairsFacingNorth, Facing.north, false, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.upsideDownBirchWoodStairsFacingEast, Facing.east, true, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.upsideDownBirchWoodStairsFacingWest, Facing.west, true, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.upsideDownBirchWoodStairsFacingSouth, Facing.south, true, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.upsideDownBirchWoodStairsFacingNorth, Facing.north, true, woodAxe, Items.birchWoodStairs));
			this.register(new StairsBlock(_.jungleWoodStairsFacingEast, Facing.east, false, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.jungleWoodStairsFacingWest, Facing.west, false, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.jungleWoodStairsFacingSouth, Facing.south, false, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.jungleWoodStairsFacingNorth, Facing.north, false, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.upsideDownJungleWoodStairsFacingEast, Facing.east, true, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.upsideDownJungleWoodStairsFacingWest, Facing.west, true, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.upsideDownJungleWoodStairsFacingSouth, Facing.south, true, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.upsideDownJungleWoodStairsFacingNorth, Facing.north, true, woodAxe, Items.jungleWoodStairs));
			this.register(new StairsBlock(_.acaciaWoodStairsFacingEast, Facing.east, false, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.acaciaWoodStairsFacingWest, Facing.west, false, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.acaciaWoodStairsFacingSouth, Facing.south, false, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.acaciaWoodStairsFacingNorth, Facing.north, false, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.upsideDownAcaciaWoodStairsFacingEast, Facing.east, true, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.upsideDownAcaciaWoodStairsFacingWest, Facing.west, true, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.upsideDownAcaciaWoodStairsFacingSouth, Facing.south, true, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.upsideDownAcaciaWoodStairsFacingNorth, Facing.north, true, woodAxe, Items.acaciaWoodStairs));
			this.register(new StairsBlock(_.darkOakWoodStairsFacingEast, Facing.east, false, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.darkOakWoodStairsFacingWest, Facing.west, false, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.darkOakWoodStairsFacingSouth, Facing.south, false, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.darkOakWoodStairsFacingNorth, Facing.north, false, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.upsideDownDarkOakWoodStairsFacingEast, Facing.east, true, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.upsideDownDarkOakWoodStairsFacingWest, Facing.west, true, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.upsideDownDarkOakWoodStairsFacingSouth, Facing.south, true, woodAxe, Items.darkOakWoodStairs));
			this.register(new StairsBlock(_.upsideDownDarkOakWoodStairsFacingNorth, Facing.north, true, woodAxe, Items.darkOakWoodStairs));
			this.register(new MineableBlock(_.bookshelf, woodAxe, Drop(Items.book, 3, 3, Items.bookshelf)));
			this.register(new MineableBlock(_.obsidian, diamondPickaxe, Drop(Items.obsidian, 1)));
			this.register(new MineableBlock(_.glowingObsidian, diamondPickaxe, Drop(Items.glowingObsidian, 1)));
			this.register(new MineableBlock(_.torchFacingEast, MiningTool.init, Drop(Items.torch, 1)));
			this.register(new MineableBlock(_.torchFacingWest, MiningTool.init, Drop(Items.torch, 1)));
			this.register(new MineableBlock(_.torchFacingSouth, MiningTool.init, Drop(Items.torch, 1)));
			this.register(new MineableBlock(_.torchFacingNorth, MiningTool.init, Drop(Items.torch, 1)));
			this.register(new MineableBlock(_.torchFacingUp, MiningTool.init, Drop(Items.torch, 1)));
			this.register(new MineableBlock(_.craftingTable, MiningTool(Tools.axe, Tools.all), Drop(Items.craftingTable, 1))); //TODO open window on click
			this.register(new StageCropBlock(_.seeds0, Blocks.seeds1, [Drop(Items.seeds, 1)]));
			this.register(new StageCropBlock(_.seeds1, Blocks.seeds2, [Drop(Items.seeds, 1)]));
			this.register(new StageCropBlock(_.seeds2, Blocks.seeds3, [Drop(Items.seeds, 1)]));
			this.register(new StageCropBlock(_.seeds3, Blocks.seeds4, [Drop(Items.seeds, 1)]));
			this.register(new StageCropBlock(_.seeds4, Blocks.seeds5, [Drop(Items.seeds, 1)]));
			this.register(new StageCropBlock(_.seeds5, Blocks.seeds6, [Drop(Items.seeds, 1)]));
			this.register(new StageCropBlock(_.seeds6, Blocks.seeds7, [Drop(Items.seeds, 1)]));
			this.register(new FarmingBlock(_.seeds7, [Drop(Items.seeds, 0, 3), Drop(Items.wheat, 1)]));
			this.register(new ChanceCropBlock(_.beetroot0, Blocks.beetroot1, [Drop(Items.beetrootSeeds, 1)], 2, 3));
			this.register(new ChanceCropBlock(_.beetroot1, Blocks.beetroot2, [Drop(Items.beetrootSeeds, 1)], 2, 3));
			this.register(new ChanceCropBlock(_.beetroot2, Blocks.beetroot3, [Drop(Items.beetrootSeeds, 1)], 2, 3));
			this.register(new FarmingBlock(_.beetroot3, [Drop(Items.beetroot, 1), Drop(Items.beetrootSeeds, 0, 3)]));
			this.register(new StageCropBlock(_.carrot0, Blocks.carrot1, [Drop(Items.carrot, 1)]));
			this.register(new StageCropBlock(_.carrot1, Blocks.carrot2, [Drop(Items.carrot, 1)]));
			this.register(new StageCropBlock(_.carrot2, Blocks.carrot3, [Drop(Items.carrot, 1)]));
			this.register(new StageCropBlock(_.carrot3, Blocks.carrot4, [Drop(Items.carrot, 1)]));
			this.register(new StageCropBlock(_.carrot4, Blocks.carrot5, [Drop(Items.carrot, 1)]));
			this.register(new StageCropBlock(_.carrot5, Blocks.carrot6, [Drop(Items.carrot, 1)]));
			this.register(new StageCropBlock(_.carrot6, Blocks.carrot7, [Drop(Items.carrot, 1)]));
			this.register(new FarmingBlock(_.carrot7, [Drop(Items.carrot, 1, 4)]));
			this.register(new StageCropBlock(_.potato0, Blocks.potato1, [Drop(Items.potato, 1)]));
			this.register(new StageCropBlock(_.potato1, Blocks.potato2, [Drop(Items.potato, 1)]));
			this.register(new StageCropBlock(_.potato2, Blocks.potato3, [Drop(Items.potato, 1)]));
			this.register(new StageCropBlock(_.potato3, Blocks.potato4, [Drop(Items.potato, 1)]));
			this.register(new StageCropBlock(_.potato4, Blocks.potato5, [Drop(Items.potato, 1)]));
			this.register(new StageCropBlock(_.potato5, Blocks.potato6, [Drop(Items.potato, 1)]));
			this.register(new StageCropBlock(_.potato6, Blocks.potato7, [Drop(Items.potato, 1)]));
			this.register(new FarmingBlock(_.potato7, [Drop(Items.potato, 1, 4), Drop(Items.poisonousPotato, -49, 1)]));
			this.register(new StemBlock!StageCropBlock(_.melonStem0, Items.melonSeeds, Blocks.melonStem1));
			this.register(new StemBlock!StageCropBlock(_.melonStem1, Items.melonSeeds, Blocks.melonStem2));
			this.register(new StemBlock!StageCropBlock(_.melonStem2, Items.melonSeeds, Blocks.melonStem3));
			this.register(new StemBlock!StageCropBlock(_.melonStem3, Items.melonSeeds, Blocks.melonStem4));
			this.register(new StemBlock!StageCropBlock(_.melonStem4, Items.melonSeeds, Blocks.melonStem5));
			this.register(new StemBlock!StageCropBlock(_.melonStem5, Items.melonSeeds, Blocks.melonStem6));
			this.register(new StemBlock!StageCropBlock(_.melonStem6, Items.melonSeeds, Blocks.melonStem7));
			this.register(new StemBlock!(FruitCropBlock!false)(_.melonStem7, Items.melonSeeds, Blocks.melon));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem0, Items.pumpkinSeeds, Blocks.pumpkinStem1));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem1, Items.pumpkinSeeds, Blocks.pumpkinStem2));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem2, Items.pumpkinSeeds, Blocks.pumpkinStem3));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem3, Items.pumpkinSeeds, Blocks.pumpkinStem4));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem4, Items.pumpkinSeeds, Blocks.pumpkinStem5));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem5, Items.pumpkinSeeds, Blocks.pumpkinStem6));
			this.register(new StemBlock!StageCropBlock(_.pumpkinStem6, Items.pumpkinSeeds, Blocks.pumpkinStem7));
			this.register(new StemBlock!(FruitCropBlock!true)(_.pumpkinStem7, Items.pumpkinSeeds, cast(block_t[4])Blocks.pumpkin[0..4]));
			this.register(new SugarCanesBlock(_.sugarCanes0, Blocks.sugarCanes1));
			this.register(new SugarCanesBlock(_.sugarCanes1, Blocks.sugarCanes2));
			this.register(new SugarCanesBlock(_.sugarCanes2, Blocks.sugarCanes3));
			this.register(new SugarCanesBlock(_.sugarCanes3, Blocks.sugarCanes4));
			this.register(new SugarCanesBlock(_.sugarCanes4, Blocks.sugarCanes5));
			this.register(new SugarCanesBlock(_.sugarCanes5, Blocks.sugarCanes6));
			this.register(new SugarCanesBlock(_.sugarCanes6, Blocks.sugarCanes7));
			this.register(new SugarCanesBlock(_.sugarCanes7, Blocks.sugarCanes8));
			this.register(new SugarCanesBlock(_.sugarCanes8, Blocks.sugarCanes9));
			this.register(new SugarCanesBlock(_.sugarCanes9, Blocks.sugarCanes10));
			this.register(new SugarCanesBlock(_.sugarCanes10, Blocks.sugarCanes11));
			this.register(new SugarCanesBlock(_.sugarCanes11, Blocks.sugarCanes12));
			this.register(new SugarCanesBlock(_.sugarCanes12, Blocks.sugarCanes13));
			this.register(new SugarCanesBlock(_.sugarCanes13, Blocks.sugarCanes14));
			this.register(new SugarCanesBlock(_.sugarCanes14, Blocks.sugarCanes15));
			this.register(new SugarCanesBlock(_.sugarCanes15, 0));
			this.register(new StageNetherCropBlock(_.netherWart0, Blocks.netherWart1, Drop(Items.netherWart, 1)));
			this.register(new StageNetherCropBlock(_.netherWart1, Blocks.netherWart2, Drop(Items.netherWart, 1)));
			this.register(new StageNetherCropBlock(_.netherWart2, Blocks.netherWart3, Drop(Items.netherWart, 1)));
			this.register(new NetherCropBlock(_.netherWart3, Drop(Items.netherWart, 1, 4, 0))); //TODO +1 with fortune
			this.register(new MineableBlock(_.stonecutter, woodPickaxe, Drop(Items.stonecutter, 1)));
			this.register(new GravityBlock(_.snowLayer0, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 2)));
			this.register(new GravityBlock(_.snowLayer1, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 3)));
			this.register(new GravityBlock(_.snowLayer2, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 4)));
			this.register(new GravityBlock(_.snowLayer3, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 5)));
			this.register(new GravityBlock(_.snowLayer4, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 6)));
			this.register(new GravityBlock(_.snowLayer5, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 7)));
			this.register(new GravityBlock(_.snowLayer6, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 8)));
			this.register(new GravityBlock(_.snowLayer7, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 9)));
			this.register(new MineableBlock(_.snow, MiningTool(Tools.shovel, Tools.wood), Drop(Items.snowball, 4, 4, Items.snowBlock)));
			this.register(new CactusBlock(_.cactus0, Blocks.cactus1));
			this.register(new CactusBlock(_.cactus1, Blocks.cactus2));
			this.register(new CactusBlock(_.cactus2, Blocks.cactus3));
			this.register(new CactusBlock(_.cactus3, Blocks.cactus4));
			this.register(new CactusBlock(_.cactus4, Blocks.cactus5));
			this.register(new CactusBlock(_.cactus5, Blocks.cactus6));
			this.register(new CactusBlock(_.cactus6, Blocks.cactus7));
			this.register(new CactusBlock(_.cactus7, Blocks.cactus8));
			this.register(new CactusBlock(_.cactus8, Blocks.cactus9));
			this.register(new CactusBlock(_.cactus9, Blocks.cactus10));
			this.register(new CactusBlock(_.cactus10, Blocks.cactus11));
			this.register(new CactusBlock(_.cactus11, Blocks.cactus12));
			this.register(new CactusBlock(_.cactus12, Blocks.cactus13));
			this.register(new CactusBlock(_.cactus13, Blocks.cactus14));
			this.register(new CactusBlock(_.cactus14, Blocks.cactus15));
			this.register(new CactusBlock(_.cactus15, 0));
			this.register(new MineableBlock(_.clay, MiningTool(false, Tools.shovel, Tools.wood), Drop(Items.clay, 4, 4, Items.clayBlock)));
			this.register(new MineableBlock(_.hardenedClay, woodPickaxe, Drop(Items.hardenedClay, 1)));
			this.register(new MineableBlock(_.whiteStainedClay, woodPickaxe, Drop(Items.whiteStainedClay, 1)));
			this.register(new MineableBlock(_.orangeStainedClay, woodPickaxe, Drop(Items.orangeStainedClay, 1)));
			this.register(new MineableBlock(_.magentaStainedClay, woodPickaxe, Drop(Items.magentaStainedClay, 1)));
			this.register(new MineableBlock(_.lightBlueStainedClay, woodPickaxe, Drop(Items.lightBlueStainedClay, 1)));
			this.register(new MineableBlock(_.yellowStainedClay, woodPickaxe, Drop(Items.yellowStainedClay, 1)));
			this.register(new MineableBlock(_.limeStainedClay, woodPickaxe, Drop(Items.limeStainedClay, 1)));
			this.register(new MineableBlock(_.pinkStainedClay, woodPickaxe, Drop(Items.pinkStainedClay, 1)));
			this.register(new MineableBlock(_.grayStainedClay, woodPickaxe, Drop(Items.grayStainedClay, 1)));
			this.register(new MineableBlock(_.lightGrayStainedClay, woodPickaxe, Drop(Items.lightGrayStainedClay, 1)));
			this.register(new MineableBlock(_.cyanStainedClay, woodPickaxe, Drop(Items.cyanStainedClay, 1)));
			this.register(new MineableBlock(_.purpleStainedClay, woodPickaxe, Drop(Items.purpleStainedClay, 1)));
			this.register(new MineableBlock(_.blueStainedClay, woodPickaxe, Drop(Items.blueStainedClay, 1)));
			this.register(new MineableBlock(_.brownStainedClay, woodPickaxe, Drop(Items.brownStainedClay, 1)));
			this.register(new MineableBlock(_.greenStainedClay, woodPickaxe, Drop(Items.greenStainedClay, 1)));
			this.register(new MineableBlock(_.redStainedClay, woodPickaxe, Drop(Items.redStainedClay, 1)));
			this.register(new MineableBlock(_.blackStainedClay, woodPickaxe, Drop(Items.blackStainedClay, 1)));
			this.register(new MineableBlock(_.pumpkinFacingSouth, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.pumpkinFacingWest, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.pumpkinFacingNorth, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.pumpkinFacingEast, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.facelessPumpkinFacingSouth, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.facelessPumpkinFacingWest, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.facelessPumpkinFacingNorth, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.facelessPumpkinFacingEast, woodAxe, Drop(Items.pumpkin, 1)));
			this.register(new MineableBlock(_.jackOLanternFacingSouth, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.jackOLanternFacingWest, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.jackOLanternFacingNorth, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.jackOLanternFacingEast, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.facelessJackOLanternFacingSouth, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.facelessJackOLanternFacingWest, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.facelessJackOLanternFacingNorth, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.facelessJackOLanternFacingEast, woodAxe, Drop(Items.jackOLantern, 1)));
			this.register(new MineableBlock(_.netherrack, woodPickaxe, Drop(Items.netherrack, 1))); //TODO infinite fire
			this.register(new MineableBlock(_.soulSand, MiningTool(false, Tools.pickaxe, Tools.wood), Drop(Items.soulSand, 1)));
			this.register(new MineableBlock(_.glowstone, MiningTool.init, Drop(Items.glowstoneDust, 2, 4, Items.glowstone))); //TODO fortune +1 but max 4
			this.register(new MineableBlock(_.netherBrick, woodPickaxe, Drop(Items.netherBrick, 1)));
			this.register(new MineableBlock(_.redNetherBrick, woodPickaxe, Drop(Items.redNetherBrick, 1)));
			this.register(new CakeBlock(_.cake0, Blocks.cake1));
			this.register(new CakeBlock(_.cake1, Blocks.cake2));
			this.register(new CakeBlock(_.cake2, Blocks.cake3));
			this.register(new CakeBlock(_.cake3, Blocks.cake4));
			this.register(new CakeBlock(_.cake4, Blocks.cake5));
			this.register(new CakeBlock(_.cake5, Blocks.cake6));
			this.register(new CakeBlock(_.cake6, 0));
			this.register(new SwitchingBlock!false(_.woodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorSouthSide));
			this.register(new SwitchingBlock!false(_.woodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorNorthSide));
			this.register(new SwitchingBlock!false(_.woodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorEastSide));
			this.register(new SwitchingBlock!false(_.woodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedWoodenTrapdoorWestSide));
			this.register(new SwitchingBlock!false(_.openedWoodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorSouthSide));
			this.register(new SwitchingBlock!false(_.openedWoodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorNorthSide));
			this.register(new SwitchingBlock!false(_.openedWoodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorEastSide));
			this.register(new SwitchingBlock!false(_.openedWoodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.woodenTrapdoorWestSide));
			this.register(new SwitchingBlock!false(_.topWoodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorSouthSide));
			this.register(new SwitchingBlock!false(_.topWoodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorNorthSide));
			this.register(new SwitchingBlock!false(_.topWoodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorEastSide));
			this.register(new SwitchingBlock!false(_.topWoodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.openedTopWoodenTrapdoorWestSide));
			this.register(new SwitchingBlock!false(_.openedTopWoodenTrapdoorSouthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorSouthSide));
			this.register(new SwitchingBlock!false(_.openedTopWoodenTrapdoorNorthSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorNorthSide));
			this.register(new SwitchingBlock!false(_.openedTopWoodenTrapdoorEastSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorEastSide));
			this.register(new SwitchingBlock!false(_.openedTopWoodenTrapdoorWestSide, MiningTool(Tools.axe, Tools.all), Drop(Items.woodenTrapdoor, 1), Blocks.topWoodenTrapdoorWestSide));
			this.register(new SwitchingBlock!true(_.ironTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorSouthSide));
			this.register(new SwitchingBlock!true(_.ironTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorNorthSide));
			this.register(new SwitchingBlock!true(_.ironTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorEastSide));
			this.register(new SwitchingBlock!true(_.ironTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedIronTrapdoorWestSide));
			this.register(new SwitchingBlock!true(_.openedIronTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorSouthSide));
			this.register(new SwitchingBlock!true(_.openedIronTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorNorthSide));
			this.register(new SwitchingBlock!true(_.openedIronTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorEastSide));
			this.register(new SwitchingBlock!true(_.openedIronTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.ironTrapdoorWestSide));
			this.register(new SwitchingBlock!true(_.topIronTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorSouthSide));
			this.register(new SwitchingBlock!true(_.topIronTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorNorthSide));
			this.register(new SwitchingBlock!true(_.topIronTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorEastSide));
			this.register(new SwitchingBlock!true(_.topIronTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.openedTopIronTrapdoorWestSide));
			this.register(new SwitchingBlock!true(_.openedTopIronTrapdoorSouthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorSouthSide));
			this.register(new SwitchingBlock!true(_.openedTopIronTrapdoorNorthSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorNorthSide));
			this.register(new SwitchingBlock!true(_.openedTopIronTrapdoorEastSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorEastSide));
			this.register(new SwitchingBlock!true(_.openedTopIronTrapdoorWestSide, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironTrapdoor, 1), Blocks.topIronTrapdoorWestSide));
			this.register(new MonsterEggBlock(_.stoneMonsterEgg, Blocks.stone));
			this.register(new MonsterEggBlock(_.cobblestoneMonsterEgg, Blocks.cobblestone));
			this.register(new MonsterEggBlock(_.stoneBrickMonsterEgg, Blocks.stoneBricks));
			this.register(new MonsterEggBlock(_.mossyStoneBrickMonsterEgg, Blocks.mossyStoneBricks));
			this.register(new MonsterEggBlock(_.crackedStoneBrickMonsterEgg, Blocks.crackedStoneBricks));
			this.register(new MonsterEggBlock(_.chiseledStoneBrickMonsterEgg, Blocks.chiseledStoneBricks));
			this.register(new MineableBlock(_.brownMushroomPoresEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopWestNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopNorthEast, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopWest, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTop, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopEast, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopSouthWest, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapTopEastSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomStemEverySide, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomCapsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.brownMushroomStemsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.brownMushroom, 0, 2, Items.brownMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomPoresEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopWestNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopNorth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopNorthEast, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopWest, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTop, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopEast, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopSouthWest, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapTopEastSouth, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomStemEverySide, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomCapsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.redMushroomStemsEverywhere, MiningTool(Tools.axe, Tools.all), Drop(Items.redMushroom, 0, 2, Items.redMushroomBlock)));
			this.register(new MineableBlock(_.ironBars, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.ironBars, 1)));
			this.register(new MineableBlock(_.melon, MiningTool(Tools.axe | Tools.sword, Tools.all), Drop(Items.melon, 3, 7, Items.melonBlock)));
			this.register(new InactiveEndPortalBlock(_.endPortalFrameSouth, Blocks.activeEndPortalFrameSouth, Facing.south));
			this.register(new InactiveEndPortalBlock(_.endPortalFrameWest, Blocks.activeEndPortalFrameWest, Facing.west));
			this.register(new InactiveEndPortalBlock(_.endPortalFrameNorth, Blocks.activeEndPortalFrameNorth, Facing.north));
			this.register(new InactiveEndPortalBlock(_.endPortalFrameEast, Blocks.activeEndPortalFrameEast, Facing.east));
			this.register(new Block(_.activeEndPortalFrameSouth));
			this.register(new Block(_.activeEndPortalFrameWest));
			this.register(new Block(_.activeEndPortalFrameNorth));
			this.register(new Block(_.activeEndPortalFrameEast));
			this.register(new MineableBlock(_.endStone, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.endStone, 1)));
			this.register(new MineableBlock(_.endStoneBricks, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.endStoneBricks, 1)));
			this.register(new Block(_.endPortal)); //TODO teleport to end dimension
			this.register(new GrowingBeansBlock(_.cocoaNorth0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.south, Blocks.cocoaNorth1));
			this.register(new GrowingBeansBlock(_.cocoaEast0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.west, Blocks.cocoaEast1));
			this.register(new GrowingBeansBlock(_.cocoaSouth0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.north, Blocks.cocoaSouth1));
			this.register(new GrowingBeansBlock(_.cocoaWest0, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.east, Blocks.cocoaWest1));
			this.register(new GrowingBeansBlock(_.cocoaNorth1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.south, Blocks.cocoaNorth2));
			this.register(new GrowingBeansBlock(_.cocoaEast1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.west, Blocks.cocoaEast2));
			this.register(new GrowingBeansBlock(_.cocoaSouth1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.north, Blocks.cocoaSouth2));
			this.register(new GrowingBeansBlock(_.cocoaWest1, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 1), Facing.east, Blocks.cocoaWest2));
			this.register(new BeansBlock(_.cocoaNorth2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.south));
			this.register(new BeansBlock(_.cocoaEast2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.west));
			this.register(new BeansBlock(_.cocoaSouth2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.north));
			this.register(new BeansBlock(_.cocoaWest2, MiningTool(Tools.axe, Tools.wood), Drop(Items.cocoaBeans, 2, 3), Facing.east));
			this.register(new MineableBlock(_.lilyPad, MiningTool.init, Drop(Items.lilyPad, 1))); //TODO drop when the block underneath is not water nor ice
			this.register(new MineableBlock(_.quartzBlock, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.quartzBlock, 1)));
			this.register(new MineableBlock(_.chiseledQuartzBlock, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.chiseledQuartzBlock, 1)));
			this.register(new MineableBlock(_.pillarQuartzBlockVertical, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1)));
			this.register(new MineableBlock(_.pillarQuartzBlockNorthSouth, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1)));
			this.register(new MineableBlock(_.pillarQuartzBlockEastWest, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.pillarQuartzBlock, 1)));
			this.register(new Block(_.barrier));
			this.register(new MineableBlock(_.prismarine, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.prismarine, 1)));
			this.register(new MineableBlock(_.prismarineBricks, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.prismarineBricks, 1)));
			this.register(new MineableBlock(_.darkPrismarine, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.darkPrismarine, 1)));
			this.register(new MineableBlock(_.seaLantern, MiningTool.init, Drop(Items.prismarineCrystals, 2, 3, Items.seaLantern))); //TODO fortune
			this.register(new MineableBlock(_.hayBaleVertical, MiningTool.init, Drop(Items.hayBale, 1)));
			this.register(new MineableBlock(_.hayBaleEastWest, MiningTool.init, Drop(Items.hayBale, 1)));
			this.register(new MineableBlock(_.hayBaleNorthSouth, MiningTool.init, Drop(Items.hayBale, 1)));
			this.register(new MineableBlock(_.endRodFacingDown, MiningTool.init, Drop(Items.endRod, 1)));
			this.register(new MineableBlock(_.endRodFacingUp, MiningTool.init, Drop(Items.endRod, 1)));
			this.register(new MineableBlock(_.endRodFacingNorth, MiningTool.init, Drop(Items.endRod, 1)));
			this.register(new MineableBlock(_.endRodFacingSouth, MiningTool.init, Drop(Items.endRod, 1)));
			this.register(new MineableBlock(_.endRodFacingWest, MiningTool.init, Drop(Items.endRod, 1)));
			this.register(new MineableBlock(_.endRodFacingEast, MiningTool.init, Drop(Items.endRod, 1)));
			this.register(new MineableBlock(_.purpurBlock, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurBlock, 1)));
			this.register(new MineableBlock(_.purpurPillarVertical, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1)));
			this.register(new MineableBlock(_.purpurPillarEastWest, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1)));
			this.register(new MineableBlock(_.purpurPillarNorthSouth, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.purpurPillar, 1)));
			this.register(new MineableBlock(_.netherWartBlock, MiningTool.init, Drop(Items.netherWartBlock, 1)));
			this.register(new MineableBlock(_.boneBlockVertical, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1)));
			this.register(new MineableBlock(_.boneBlockEastWest, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1)));
			this.register(new MineableBlock(_.boneBlockNorthSouth, MiningTool(Tools.pickaxe, Tools.wood), Drop(Items.boneBlock, 1)));
			this.register(new Block(_.structureVoid));
			this.register(new Block(_.updateBlock));
			this.register(new Block(_.ateupdBlock));
			
		}

	}

}

interface Blocks {

	mixin((){
		string ret;
		foreach(member ; __traits(allMembers, _)) {
			ret ~= "enum " ~ member ~ "=_." ~ member ~ ".id;";
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
