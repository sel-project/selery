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
module sel.item.items;

import std.string : replace, toLower;

import sel.about : item_t;
import sel.block.blocks : Blocks;
import sel.entity.effect : Effects;
import sel.item.consumeable;
import sel.item.item : Item, SimpleItem;
import sel.item.miscellaneous;
import sel.item.placeable;
import sel.item.tool;

import sul.items : _ = Items;

/**
 * Storage for a world's items.
 */
public class ItemStorage {

	private static ItemStorage instance;
	
	private Item function(ushort damage)[] indexes;
	private Item function(ushort damage)[ushort][] minecraft, pocket;
	private Item function(ushort damage)[string] strings;
	
	public this() {
		if(instance is null) {
			version(NoItems) {} else {
				foreach_reverse(a ; __traits(allMembers, Items)) {
					mixin("alias T = Items." ~ a ~ ";");
					static if(is(T : Item)) {
						static if(__traits(compiles, new T(ushort.max))) {
							this.register((ushort damage){ return cast(Item)new T(damage); });
						} else {
							this.register((ushort damage){ return cast(Item)new T(); });
						}
					}
				}
			}
			instance = this;
		} else {
			this.indexes = instance.indexes.dup;
			this.minecraft = instance.minecraft.dup;
			this.pocket = instance.pocket.dup;
			this.strings = instance.strings.dup;
		}
	}

	private void register(Item function(ushort) f) {
		auto item = f(0);
		if(this.indexes.length <= item.data.index) this.indexes.length = item.data.index + 1;
		this.indexes[item.data.index] = f;
		if(item.minecraft) {
			if(this.minecraft.length < item.minecraftId) this.minecraft.length = item.minecraftId + 1;
			this.minecraft[item.minecraftId][item.minecraftMeta] = f;
		}
		if(item.pocket) {
			if(this.pocket.length < item.pocketId) this.pocket.length = item.pocketId + 1;
			this.pocket[item.pocketId][item.pocketMeta] = f;
		}
		this.strings[item.name] = f;
	}
	
	public Item function(ushort) getConstructor(size_t index) {
		return index < this.indexes.length ? this.indexes[index] : null;
	}
	
	public Item get(size_t index, ushort damage=0) {
		return index < this.indexes.length ? this.indexes[index](damage) : null;
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

	/**
	 * Gets an item using a string.
	 * Returns: an instance of Item or null if there are no items with the given name
	 * Example:
	 * ---
	 * assert(items.fromString("grass") == Items.grass);
	 * assert(items.fromString("polished granite") == Items.polishedGranite);
	 * assert(items.fromString("polished_andesite") == Items.polishedAndesite);
	 * assert(items.fromString("not an item") is null);
	 * ---
	 */
	public Item fromString(string name, ushort damage=0) {
		auto f = name.toLower.replace("_", " ") in this.strings;
		return f ? (*f)(damage) : null;
	}

}

interface Items {

	mixin((){
		string ret;
		foreach(member ; __traits(allMembers, _)) {
			ret ~= "enum " ~ member ~ "=_." ~ member ~ ".index;";
		}
		return ret;
	}());

	alias Stone = PlaceableItem!(_.stone, Blocks.stone);

	alias Granite = PlaceableItem!(_.granite, Blocks.granite);

	alias PolishedGranite = PlaceableItem!(_.polishedGranite, Blocks.polishedGranite);

	alias Diorite = PlaceableItem!(_.diorite, Blocks.diorite);

	alias PolishedDiorite = PlaceableItem!(_.polishedDiorite, Blocks.polishedDiorite);

	alias Andesite = PlaceableItem!(_.andesite, Blocks.andesite);

	alias PolishedAndesite = PlaceableItem!(_.polishedAndesite, Blocks.polishedAndesite);

	alias Grass = PlaceableItem!(_.grass, Blocks.grass);

	alias Dirt = PlaceableItem!(_.dirt, Blocks.dirt);

	alias CoarseDirt = PlaceableItem!(_.coarseDirt, Blocks.coarseDirt);

	alias Podzol = PlaceableItem!(_.podzol, Blocks.podzol);

	alias Cobblestone = PlaceableItem!(_.cobblestone, Blocks.cobblestone);

	alias OakWoodPlanks = PlaceableItem!(_.oakWoodPlanks, Blocks.oakWoodPlanks);
	
	alias SpruceWoodPlanks = PlaceableItem!(_.spruceWoodPlanks, Blocks.spruceWoodPlanks);

	alias BirchWoodPlanks = PlaceableItem!(_.birchWoodPlanks, Blocks.birchWoodPlanks);

	alias JungleWoodPlanks = PlaceableItem!(_.jungleWoodPlanks, Blocks.jungleWoodPlanks);

	alias AcaciaWoodPlanks = PlaceableItem!(_.acaciaWoodPlanks, Blocks.acaciaWoodPlanks);

	alias DarkOakWoodPlanks = PlaceableItem!(_.darkOakWoodPlanks, Blocks.darkOakWoodPlanks);

	alias OakSapling = PlaceableItem!(_.oakSapling, Blocks.oakSapling, Blocks.dirts);

	alias SpruceSapling = PlaceableItem!(_.spruceSapling, Blocks.spruceSapling, Blocks.dirts);

	alias BirchSapling = PlaceableItem!(_.birchSapling, Blocks.birchSapling, Blocks.dirts);

	alias JungleSapling = PlaceableItem!(_.jungleSapling, Blocks.jungleSapling, Blocks.dirts);

	alias AcaciaSapling = PlaceableItem!(_.acaciaSapling, Blocks.acaciaSapling, Blocks.dirts);

	alias DarkOakSapling = PlaceableItem!(_.darkOakSapling, Blocks.darkOakSapling, Blocks.dirts);

	alias Bedrock = PlaceableItem!(_.bedrock, Blocks.bedrock);

	alias Sand = PlaceableItem!(_.sand, Blocks.sand);

	alias RedSand = PlaceableItem!(_.redSand, Blocks.redSand);

	alias Gravel = PlaceableItem!(_.gravel, Blocks.gravel);

	alias GoldOre = PlaceableItem!(_.goldOre, Blocks.goldOre);

	alias IronOre = PlaceableItem!(_.ironOre, Blocks.ironOre);

	alias CoalOre = PlaceableItem!(_.coalOre, Blocks.coalOre);

	alias OakWood = WoodItem!(_.oakWood, Blocks.oakWood);

	alias SpruceWood = WoodItem!(_.spruceWood, Blocks.spruceWood);

	alias BirchWood = WoodItem!(_.birchWood, Blocks.birchWood);

	alias JungleWood = WoodItem!(_.jungleWood, Blocks.jungleWood);

	alias AcaciaWood = WoodItem!(_.acaciaWood, Blocks.acaciaWood);

	alias DarkOakWood = WoodItem!(_.darkOakWood, Blocks.darkOakWood);

	alias OakLeaves = PlaceableItem!(_.oakLeaves, Blocks.oakLeavesNoDecay);

	alias SpruceLeaves = PlaceableItem!(_.spruceLeaves, Blocks.spruceLeavesNoDecay);

	alias BirchLeaves = PlaceableItem!(_.birchLeaves, Blocks.birchLeavesNoDecay);

	alias JungleLeaves = PlaceableItem!(_.jungleLeaves, Blocks.jungleLeavesNoDecay);

	alias AcaciaLeaves = PlaceableItem!(_.acaciaLeaves, Blocks.acaciaLeavesNoDecay);

	alias DarkOakLeaves = PlaceableItem!(_.darkOakLeaves, Blocks.darkOakLeavesNoDecay);

	alias Sponge = PlaceableItem!(_.sponge, Blocks.sponge);

	alias WetSponge = PlaceableItem!(_.wetSponge, Blocks.wetSponge);

	alias Glass = PlaceableItem!(_.glass, Blocks.glass);

	alias LapisLazuliOre = PlaceableItem!(_.lapisLazuliOre, Blocks.lapisLazuliOre);

	alias LapisLazuliBlock = PlaceableItem!(_.lapisLazuliBlock, Blocks.lapisLazuliBlock);

	alias Dispenser = SimpleItem!(_.dispenser);

	alias Sandstone = PlaceableItem!(_.sandstone, Blocks.sandstone);

	alias ChiseledSandstone = PlaceableItem!(_.chiseledSandstone, Blocks.chiseledSandstone);

	alias SmoothSandstone = PlaceableItem!(_.smoothSandstone, Blocks.smoothSandstone);

	alias NoteBlock = PlaceableItem!(_.noteBlock, Blocks.noteBlock);

	alias PoweredRail = SimpleItem!(_.poweredRail);

	alias DetectorRail = SimpleItem!(_.detectorRail);

	alias StickyPiston = SimpleItem!(_.stickyPiston);

	alias Cobweb = PlaceableItem!(_.cobweb, Blocks.cobweb);

	alias TallGrass = PlaceableItem!(_.tallGrass, Blocks.tallGrass, Blocks.dirts);

	alias Fern = PlaceableItem!(_.fern, Blocks.fern, Blocks.dirts);

	alias DeadBush = PlaceableItem!(_.deadBush, Blocks.deadBush, [Blocks.sand, Blocks.redSand, Blocks.dirt, Blocks.podzol, Blocks.coarseDirt, Blocks.hardenedClay] ~ Blocks.stainedClay);

	alias Piston = SimpleItem!(_.piston);

	alias WhiteWool = PlaceableItem!(_.whiteWool, Blocks.whiteWool);

	alias OrangeWool = PlaceableItem!(_.orangeWool, Blocks.orangeWool);

	alias MagentaWool = PlaceableItem!(_.magentaWool, Blocks.magentaWool);

	alias LightBlueWool = PlaceableItem!(_.lightBlueWool, Blocks.lightBlueWool);

	alias YellowWool = PlaceableItem!(_.yellowWool, Blocks.yellowWool);

	alias LimeWool = PlaceableItem!(_.limeWool, Blocks.limeWool);

	alias PinkWool = PlaceableItem!(_.pinkWool, Blocks.pinkWool);

	alias GrayWool = PlaceableItem!(_.grayWool, Blocks.grayWool);

	alias LightGrayWool = PlaceableItem!(_.lightGrayWool, Blocks.lightGrayWool);

	alias CyanWool = PlaceableItem!(_.cyanWool, Blocks.cyanWool);

	alias PurpleWool = PlaceableItem!(_.purpleWool, Blocks.purpleWool);

	alias BlueWool = PlaceableItem!(_.blueWool, Blocks.blueWool);

	alias BrownWool = PlaceableItem!(_.brownWool, Blocks.brownWool);

	alias GreenWool = PlaceableItem!(_.greenWool, Blocks.greenWool);

	alias RedWool = PlaceableItem!(_.redWool, Blocks.redWool);

	alias BlackWool = PlaceableItem!(_.blackWool, Blocks.blackWool);

	alias Dandelion = PlaceableItem!(_.dandelion, Blocks.dandelion);

	alias Poppy = PlaceableItem!(_.poppy, Blocks.poppy);
	
	alias BlueOrchid = PlaceableItem!(_.blueOrchid, Blocks.blueOrchid);
	
	alias Allium = PlaceableItem!(_.allium, Blocks.allium);
	
	alias AzureBluet = PlaceableItem!(_.azureBluet, Blocks.azureBluet);
	
	alias RedTulip = PlaceableItem!(_.redTulip, Blocks.redTulip);
	
	alias OrangeTulip = PlaceableItem!(_.orangeTulip, Blocks.orangeTulip);
	
	alias WhiteTulip = PlaceableItem!(_.whiteTulip, Blocks.whiteTulip);
	
	alias PinkTulip = PlaceableItem!(_.pinkTulip, Blocks.pinkTulip);
	
	alias OxeyeDaisy = PlaceableItem!(_.oxeyeDaisy, Blocks.oxeyeDaisy);
	
	alias BrownMushroom = PlaceableItem!(_.brownMushroom, Blocks.brownMushroom, [Blocks.podzol]);
	
	alias RedMushroom = PlaceableItem!(_.redMushroom, Blocks.redMushroom, [Blocks.podzol]);
	
	alias GoldBlock = PlaceableItem!(_.goldBlock, Blocks.goldBlock);
	
	alias IronBlock = PlaceableItem!(_.ironBlock, Blocks.ironBlock);
	
	alias StoneSlab = SlabItem!(_.stoneSlab, Blocks.stoneSlab, Blocks.upperStoneSlab, Blocks.doubleStoneSlab);
	
	alias SandstoneSlab = SlabItem!(_.sandstoneSlab, Blocks.sandstoneSlab, Blocks.upperSandstoneSlab, Blocks.doubleSandstoneSlab);
	
	alias StoneWoodenSlab = SlabItem!(_.stoneWoodenSlab, Blocks.stoneWoodenSlab, Blocks.upperStoneWoodenSlab, Blocks.doubleStoneWoodenSlab);
	
	alias CobblestoneSlab = SlabItem!(_.cobblestoneSlab, Blocks.cobblestoneSlab, Blocks.upperCobblestoneSlab, Blocks.doubleCobblestoneSlab);
	
	alias BricksSlab = SlabItem!(_.bricksSlab, Blocks.bricksSlab, Blocks.upperBricksSlab, Blocks.doubleBricksSlab);
	
	alias StoneBrickSlab = SlabItem!(_.stoneBrickSlab, Blocks.stoneBrickSlab, Blocks.upperStoneBrickSlab, Blocks.doubleStoneBrickSlab);
	
	alias NetherBrickSlab = SlabItem!(_.netherBrickSlab, Blocks.netherBrickSlab, Blocks.upperNetherBrickSlab, Blocks.doubleNetherBrickSlab);
	
	alias QuartzSlab = SlabItem!(_.quartzSlab, Blocks.quartzSlab, Blocks.upperQuartzSlab, Blocks.doubleQuartzSlab);
	
	alias Bricks = PlaceableItem!(_.bricks, Blocks.bricks);
	
	alias Tnt = PlaceableItem!(_.tnt, Blocks.tnt);
	
	alias Bookshelf = PlaceableItem!(_.bookshelf, Blocks.bookshelf);
	
	alias MossStone = PlaceableItem!(_.mossStone, Blocks.mossStone);
	
	alias Obsidian = PlaceableItem!(_.obsidian, Blocks.obsidian);
	
	alias Torch = TorchItem!(_.torch, Blocks.torch);
	
	alias MonsterSpawner = PlaceableItem!(_.monsterSpawner, Blocks.monsterSpawner);
	
	alias OakWoodStairs = StairsItem!(_.oakWoodStairs, Blocks.oakWoodStairs);
	
	//TODO place tile in right direction
	
	alias DiamondOre = PlaceableItem!(_.diamondOre, Blocks.diamondOre);
	
	alias DiamondBlock = PlaceableItem!(_.diamondBlock, Blocks.diamondBlock);
	
	alias CraftingTable = PlaceableItem!(_.craftingTable, Blocks.craftingTable);
	
	//TODO place tile in the right direction
	
	//TODO place in the right direction
	
	alias CobblestoneStairs = StairsItem!(_.cobblestoneStairs, Blocks.cobblestoneStairs);

	alias RedstoneOre = PlaceableItem!(_.redstoneOre, Blocks.redstoneOre);

	alias Ice = PlaceableItem!(_.ice, Blocks.ice);
	
	alias SnowBlock = PlaceableItem!(_.snowBlock, Blocks.snow);
	
	alias Cactus = PlaceableItem!(_.cactus, Blocks.cactus0, [Blocks.sand, Blocks.redSand] ~ Blocks.cactus); //TODO do not place near other blocks
	
	alias ClayBlock = PlaceableItem!(_.clayBlock, Blocks.clay);
	
	alias Jukebox = PlaceableItem!(_.jukebox, Blocks.jukebox);

	alias Netherrack = PlaceableItem!(_.netherrack, Blocks.netherrack);
	
	alias SoulSand = PlaceableItem!(_.soulSand, Blocks.soulSand);
	
	alias Glowstone = PlaceableItem!(_.glowstone, Blocks.glowstone);

	alias WhiteStainedGlass = PlaceableItem!(_.whiteStainedGlass, Blocks.whiteStainedGlass);
	
	alias OrangeStainedGlass = PlaceableItem!(_.orangeStainedGlass, Blocks.orangeStainedGlass);
	
	alias MagentaStainedGlass = PlaceableItem!(_.magentaStainedGlass, Blocks.magentaStainedGlass);
	
	alias LightBlueStainedGlass = PlaceableItem!(_.lightBlueStainedGlass, Blocks.lightBlueStainedGlass);
	
	alias YellowStainedGlass = PlaceableItem!(_.yellowStainedGlass, Blocks.yellowStainedGlass);
	
	alias LimeStainedGlass = PlaceableItem!(_.limeStainedGlass, Blocks.limeStainedGlass);
	
	alias PinkStainedGlass = PlaceableItem!(_.pinkStainedGlass, Blocks.pinkStainedGlass);
	
	alias GrayStainedGlass = PlaceableItem!(_.grayStainedGlass, Blocks.grayStainedGlass);
	
	alias LightGrayStainedGlass = PlaceableItem!(_.lightGrayStainedGlass, Blocks.lightGrayStainedGlass);
	
	alias CyanStainedGlass = PlaceableItem!(_.cyanStainedGlass, Blocks.cyanStainedGlass);
	
	alias PurpleStainedGlass = PlaceableItem!(_.purpleStainedGlass, Blocks.purpleStainedGlass);
	
	alias BlueStainedGlass = PlaceableItem!(_.blueStainedGlass, Blocks.blueStainedGlass);
	
	alias BrownStainedGlass = PlaceableItem!(_.brownStainedGlass, Blocks.brownStainedGlass);
	
	alias GreenStainedGlass = PlaceableItem!(_.greenStainedGlass, Blocks.greenStainedGlass);
	
	alias RedStainedGlass = PlaceableItem!(_.redStainedGlass, Blocks.redStainedGlass);
	
	alias BlackStainedGlass = PlaceableItem!(_.blackStainedGlass, Blocks.blackStainedGlass);
	
	alias StoneMonsterEgg = PlaceableItem!(_.stoneMonsterEgg, Blocks.stoneMonsterEgg);
	
	alias CobblestoneMonsterEgg = PlaceableItem!(_.cobblestoneMonsterEgg, Blocks.cobblestoneMonsterEgg);
	
	alias StoneBrickMonsterEgg = PlaceableItem!(_.stoneBrickMonsterEgg, Blocks.stoneBrickMonsterEgg);
	
	alias MossyStoneBrickMonsterEgg = PlaceableItem!(_.mossyStoneBrickMonsterEgg, Blocks.mossyStoneBrickMonsterEgg);
	
	alias CrackedStoneBrickMonsterEgg = PlaceableItem!(_.crackedStoneBrickMonsterEgg, Blocks.crackedStoneBrickMonsterEgg);
	
	alias ChiseledStoneBrickMonsterEgg = PlaceableItem!(_.chiseledStoneBrickMonsterEgg, Blocks.chiseledStoneBrickMonsterEgg);
	
	alias StoneBricks = PlaceableItem!(_.stoneBricks, Blocks.stoneBricks);
	
	alias MossyStoneBricks = PlaceableItem!(_.mossyStoneBricks, Blocks.mossyStoneBricks);
	
	alias CrackedStoneBricks = PlaceableItem!(_.crackedStoneBricks, Blocks.crackedStoneBricks);
	
	alias ChiseledStoneBricks = PlaceableItem!(_.chiseledStoneBricks, Blocks.chiseledStoneBricks);
	
	alias BrownMushroomBlock = PlaceableItem!(_.brownMushroomBlock, Blocks.brownMushroomCapsEverywhere);
	
	alias RedMushroomBlock = PlaceableItem!(_.redMushroomBlock, Blocks.redMushroomCapsEverywhere);
	
	alias IronBars = PlaceableItem!(_.ironBars, Blocks.ironBars);
	
	alias GlassPane = PlaceableItem!(_.glassPane, Blocks.glassPane);
	
	alias MelonBlock = PlaceableItem!(_.melonBlock, Blocks.melon);

	alias Mycelium = PlaceableItem!(_.mycelium, Blocks.mycelium);
	
	alias LilyPad = PlaceableItem!(_.lilyPad, Blocks.lilyPad, [Blocks.flowingWater0, Blocks.stillWater0, Blocks.ice] ~ Blocks.frostedIce);
	
	alias NetherBrickBlock = PlaceableItem!(_.netherBrickBlock, Blocks.netherBrick);
	
	alias NetherBrickFence = PlaceableItem!(_.netherBrickFence, Blocks.netherBrickFence);
	
	alias EnchantmentTable = PlaceableItem!(_.enchantmentTable, Blocks.enchantmentTable);

	alias EndStone = PlaceableItem!(_.endStone, Blocks.endStone);
	
	alias DragonEgg = PlaceableItem!(_.dragonEgg, Blocks.dragonEgg);
	
	alias RedstoneLamp = PlaceableItem!(_.redstoneLamp, Blocks.redstoneLamp);
	
	alias EmeraldOre = PlaceableItem!(_.emeraldOre, Blocks.emeraldOre);
	
	alias EmeraldBlock = PlaceableItem!(_.emeraldBlock, Blocks.emeraldBlock);
	
	alias Beacon = PlaceableItem!(_.beacon, Blocks.beacon);
	
	alias CobblestoneWall = PlaceableItem!(_.cobblestoneWall, Blocks.cobblestoneWall);
	
	alias MossyCobblestoneWall = PlaceableItem!(_.mossyCobblestoneWall, Blocks.mossyCobblestoneWall);

	alias RedstoneBlock = PlaceableItem!(_.redstoneBlock, Blocks.redstoneBlock);
	
	alias NetherQuartzOre = PlaceableItem!(_.netherQuartzOre, Blocks.netherQuartzOre);
	
	alias QuartzBlock = PlaceableItem!(_.quartzBlock, Blocks.quartzBlock);
	
	alias ChiseledQuartzBlock = PlaceableItem!(_.chiseledQuartzBlock, Blocks.chiseledQuartzBlock);
	
	alias WhiteStainedClay = PlaceableItem!(_.whiteStainedClay, Blocks.whiteStainedClay);
	
	alias OrangeStainedClay = PlaceableItem!(_.orangeStainedClay, Blocks.orangeStainedClay);
	
	alias MagentaStainedClay = PlaceableItem!(_.magentaStainedClay, Blocks.magentaStainedClay);
	
	alias LightBlueStainedClay = PlaceableItem!(_.lightBlueStainedClay, Blocks.lightBlueStainedClay);
	
	alias YellowStainedClay = PlaceableItem!(_.yellowStainedClay, Blocks.yellowStainedClay);
	
	alias LimeStainedClay = PlaceableItem!(_.limeStainedClay, Blocks.limeStainedClay);
	
	alias PinkStainedClay = PlaceableItem!(_.pinkStainedClay, Blocks.pinkStainedClay);
	
	alias GrayStainedClay = PlaceableItem!(_.grayStainedClay, Blocks.grayStainedClay);
	
	alias LightGrayStainedClay = PlaceableItem!(_.lightGrayStainedClay, Blocks.lightGrayStainedClay);
	
	alias CyanStainedClay = PlaceableItem!(_.cyanStainedClay, Blocks.cyanStainedClay);
	
	alias PurpleStainedClay = PlaceableItem!(_.purpleStainedClay, Blocks.purpleStainedClay);
	
	alias BlueStainedClay = PlaceableItem!(_.blueStainedClay, Blocks.blueStainedClay);
	
	alias BrownStainedClay = PlaceableItem!(_.brownStainedClay, Blocks.brownStainedClay);
	
	alias GreenStainedClay = PlaceableItem!(_.greenStainedClay, Blocks.greenStainedClay);
	
	alias RedStainedClay = PlaceableItem!(_.redStainedClay, Blocks.redStainedClay);
	
	alias BlackStainedClay = PlaceableItem!(_.blackStainedClay, Blocks.blackStainedClay);

	alias WhiteStainedGlassPane = PlaceableItem!(_.whiteStainedGlassPane, Blocks.whiteStainedGlassPane);
	
	alias OrangeStainedGlassPane = PlaceableItem!(_.orangeStainedGlassPane, Blocks.orangeStainedGlassPane);
	
	alias MagentaStainedGlassPane = PlaceableItem!(_.magentaStainedGlassPane, Blocks.magentaStainedGlassPane);
	
	alias LightBlueStainedGlassPane = PlaceableItem!(_.lightBlueStainedGlassPane, Blocks.lightBlueStainedGlassPane);
	
	alias YellowStainedGlassPane = PlaceableItem!(_.yellowStainedGlassPane, Blocks.yellowStainedGlassPane);
	
	alias LimeStainedGlassPane = PlaceableItem!(_.limeStainedGlassPane, Blocks.limeStainedGlassPane);
	
	alias PinkStainedGlassPane = PlaceableItem!(_.pinkStainedGlassPane, Blocks.pinkStainedGlassPane);
	
	alias GrayStainedGlassPane = PlaceableItem!(_.grayStainedGlassPane, Blocks.grayStainedGlassPane);
	
	alias LightGrayStainedGlassPane = PlaceableItem!(_.lightGrayStainedGlassPane, Blocks.lightGrayStainedGlassPane);
	
	alias CyanStainedGlassPane = PlaceableItem!(_.cyanStainedGlassPane, Blocks.cyanStainedGlassPane);
	
	alias PurpleStainedGlassPane = PlaceableItem!(_.purpleStainedGlassPane, Blocks.purpleStainedGlassPane);
	
	alias BlueStainedGlassPane = PlaceableItem!(_.blueStainedGlassPane, Blocks.blueStainedGlassPane);
	
	alias BrownStainedGlassPane = PlaceableItem!(_.brownStainedGlassPane, Blocks.brownStainedGlassPane);
	
	alias GreenStainedGlassPane = PlaceableItem!(_.greenStainedGlassPane, Blocks.greenStainedGlassPane);
	
	alias RedStainedGlassPane = PlaceableItem!(_.redStainedGlassPane, Blocks.redStainedGlassPane);
	
	alias BlackStainedGlassPane = PlaceableItem!(_.blackStainedGlassPane, Blocks.blackStainedGlassPane);

	alias SlimeBlock = PlaceableItem!(_.slimeBlock, Blocks.slimeBlock);
	
	alias Barrier = PlaceableItem!(_.barrier, Blocks.barrier);
	alias InvisibleBedrock = Barrier;

	alias Prismarine = PlaceableItem!(_.prismarine, Blocks.prismarine);
	
	alias PrismarineBricks = PlaceableItem!(_.prismarineBricks, Blocks.prismarineBricks);
	
	alias DarkPrismarine = PlaceableItem!(_.darkPrismarine, Blocks.darkPrismarine);
	
	alias SeaLantern = PlaceableItem!(_.seaLantern, Blocks.seaLantern);

	alias WhiteCarpet = PlaceableItem!(_.whiteCarpet, Blocks.whiteCarpet);
	
	alias OrangeCarpet = PlaceableItem!(_.orangeCarpet, Blocks.orangeCarpet);
	
	alias MagentaCarpet = PlaceableItem!(_.magentaCarpet, Blocks.magentaCarpet);
	
	alias LightBlueCarpet = PlaceableItem!(_.lightBlueCarpet, Blocks.lightBlueCarpet);
	
	alias YellowCarpet = PlaceableItem!(_.yellowCarpet, Blocks.yellowCarpet);
	
	alias LimeCarpet = PlaceableItem!(_.limeCarpet, Blocks.limeCarpet);
	
	alias PinkCarpet = PlaceableItem!(_.pinkCarpet, Blocks.pinkCarpet);
	
	alias GrayCarpet = PlaceableItem!(_.grayCarpet, Blocks.grayCarpet);
	
	alias LightGrayCarpet = PlaceableItem!(_.lightGrayCarpet, Blocks.lightGrayCarpet);
	
	alias CyanCarpet = PlaceableItem!(_.cyanCarpet, Blocks.cyanCarpet);
	
	alias PurpleCarpet = PlaceableItem!(_.purpleCarpet, Blocks.purpleCarpet);
	
	alias BlueCarpet = PlaceableItem!(_.blueCarpet, Blocks.blueCarpet);
	
	alias BrownCarpet = PlaceableItem!(_.brownCarpet, Blocks.brownCarpet);
	
	alias GreenCarpet = PlaceableItem!(_.greenCarpet, Blocks.greenCarpet);
	
	alias RedCarpet = PlaceableItem!(_.redCarpet, Blocks.redCarpet);
	
	alias BlackCarpet = PlaceableItem!(_.blackCarpet, Blocks.blackCarpet);

	alias HardenedClay = PlaceableItem!(_.hardenedClay, Blocks.hardenedClay);
	
	alias CoalBlock = PlaceableItem!(_.coalBlock, Blocks.coalBlock);
	
	alias PackedIce = PlaceableItem!(_.packedIce, Blocks.packedIce);

	alias RedSandstone = PlaceableItem!(_.redSandstone, Blocks.redSandstone);
	
	alias ChiseledRedSandstone = PlaceableItem!(_.chiseledRedSandstone, Blocks.chiseledRedSandstone);
	
	alias SmoothRedSandstone = PlaceableItem!(_.smoothRedSandstone, Blocks.smoothRedSandstone);

	alias PurpurBlock = PlaceableItem!(_.purpurBlock, Blocks.purpurBlock);

	alias EndStoneBricks = PlaceableItem!(_.endStoneBricks, Blocks.endStoneBricks);
	
	alias GrassPath = PlaceableItem!(_.grassPath, Blocks.grassPath);

	alias FrostedIce = PlaceableItem!(_.frostedIce, Blocks.frostedIce0);
	
	alias MagmaBlock = PlaceableItem!(_.magmaBlock, Blocks.magmaBlock);
	
	alias NetherWartBlock = PlaceableItem!(_.netherWartBlock, Blocks.netherWartBlock);
	
	alias RedNetherBrick = PlaceableItem!(_.redNetherBrick, Blocks.redNetherBrick);

	alias StructureVoid = PlaceableItem!(_.structureVoid, Blocks.structureVoid);
	
	alias WhiteShulkerBox = PlaceableItem!(_.whiteShulkerBox, Blocks.whiteShulkerBox);
	
	alias OrangeShulkerBox = PlaceableItem!(_.orangeShulkerBox, Blocks.orangeShulkerBox);
	
	alias MagentaShulkerBox = PlaceableItem!(_.magentaShulkerBox, Blocks.magentaShulkerBox);
	
	alias LightBlueShulkerBox = PlaceableItem!(_.lightBlueShulkerBox, Blocks.lightBlueShulkerBox);
	
	alias YellowShulkerBox = PlaceableItem!(_.yellowShulkerBox, Blocks.yellowShulkerBox);
	
	alias LimeShulkerBox = PlaceableItem!(_.limeShulkerBox, Blocks.limeShulkerBox);
	
	alias PinkShulkerBox = PlaceableItem!(_.pinkShulkerBox, Blocks.pinkShulkerBox);
	
	alias GrayShulkerBox = PlaceableItem!(_.grayShulkerBox, Blocks.grayShulkerBox);
	
	alias LightGrayShulkerBox = PlaceableItem!(_.lightGrayShulkerBox, Blocks.lightGrayShulkerBox);
	
	alias CyanShulkerBox = PlaceableItem!(_.cyanShulkerBox, Blocks.cyanShulkerBox);
	
	alias PurpleShulkerBox = PlaceableItem!(_.purpleShulkerBox, Blocks.purpleShulkerBox);
	
	alias BlueShulkerBox = PlaceableItem!(_.blueShulkerBox, Blocks.blueShulkerBox);
	
	alias BrownShulkerBox = PlaceableItem!(_.brownShulkerBox, Blocks.brownShulkerBox);
	
	alias GreenShulkerBox = PlaceableItem!(_.greenShulkerBox, Blocks.greenShulkerBox);
	
	alias RedShulkerBox = PlaceableItem!(_.redShulkerBox, Blocks.redShulkerBox);
	
	alias BlackShulkerBox = PlaceableItem!(_.blackShulkerBox, Blocks.blackShulkerBox);

	alias Stonecutter = PlaceableItem!(_.stonecutter, Blocks.stonecutter);
	
	alias GlowingObsidian = PlaceableItem!(_.glowingObsidian, Blocks.glowingObsidian);
	
	alias NetherReactorCore = PlaceableItem!(_.netherReactorCore, Blocks.netherReactorCore);
	
	alias UpdateBlock = PlaceableItem!(_.updateBlock, Blocks.updateBlock);
	
	alias AteupdBlock = PlaceableItem!(_.ateupdBlock, Blocks.ateupdBlock);
	
	alias StructureSave = PlaceableItem!(_.structureSave, Blocks.structureBlockSave);
	
	alias StructureLoad = PlaceableItem!(_.structureLoad, Blocks.structureBlockLoad);
	
	alias StructureCorner = PlaceableItem!(_.structureCorner, Blocks.structureBlockCorner);
	
	alias StructureData = PlaceableItem!(_.structureData, Blocks.structureBlockData);

	
	alias IronShovel = ShovelItem!(_.ironShovel, Tools.iron, Durability.iron, 4);
	
	alias IronPickaxe = PickaxeItem!(_.ironPickaxe, Tools.iron, Durability.iron, 5);
	
	alias IronAxe = AxeItem!(_.ironAxe, Tools.iron, Durability.iron, 6);
	
	alias Apple = FoodItem!(_.apple, 4, 2.4);

	alias Arrow = SimpleItem!(_.arrow);
	
	alias Coal = SimpleItem!(_.coal);
	
	alias Charcoal = SimpleItem!(_.charcoal);
	
	alias Diamond = SimpleItem!(_.diamond);
	
	alias IronIngot = SimpleItem!(_.ironIngot);
	
	alias GoldIngot = SimpleItem!(_.goldIngot);
	
	alias IronSword = SwordItem!(_.ironSword, Tools.iron, Durability.iron, 7);
	
	alias WoodenSword = SwordItem!(_.woodenSword, Tools.wood, Durability.wood, 5);
	
	alias WoodenShovel = ShovelItem!(_.woodenShovel, Tools.wood, Durability.wood, 2);
	
	alias WoodenPickaxe = PickaxeItem!(_.woodenPickaxe, Tools.wood, Durability.wood, 3);
	
	alias WoodenAxe = AxeItem!(_.woodenAxe, Tools.wood, Durability.wood, 4);
	
	alias StoneSword = SwordItem!(_.stoneSword, Tools.stone, Durability.stone, 6);
	
	alias StoneShovel = ShovelItem!(_.stoneShovel, Tools.stone, Durability.stone, 3);
	
	alias StonePickaxe = PickaxeItem!(_.stonePickaxe, Tools.stone, Durability.stone, 4);
	
	alias StoneAxe = AxeItem!(_.stoneAxe, Tools.stone, Durability.stone, 5);
	
	alias DiamondSword = SwordItem!(_.diamondSword, Tools.diamond, Durability.diamond, 8);
	
	alias DiamondShovel = ShovelItem!(_.diamondShovel, Tools.diamond, Durability.diamond, 5);
	
	alias DiamondPickaxe = PickaxeItem!(_.diamondPickaxe, Tools.diamond, Durability.diamond, 6);
	
	alias DiamondAxe = AxeItem!(_.diamondAxe, Tools.diamond, Durability.diamond, 7);
	
	alias Stick = SimpleItem!(_.stick);
	
	alias Bowl = SimpleItem!(_.bowl);
	
	alias MushroomStew = SoupItem!(_.mushroomStew, 6, 7.2);
	
	alias GoldenSword = SwordItem!(_.goldenSword, Tools.gold, Durability.gold, 5);
	
	alias GoldenShovel = ShovelItem!(_.goldenShovel, Tools.gold, Durability.gold, 2);
	
	alias GoldenPickaxe = PickaxeItem!(_.goldenPickaxe, Tools.gold, Durability.gold, 3);
	
	alias GoldenAxe = AxeItem!(_.goldenAxe, Tools.gold, Durability.gold, 4);

	alias Feather = SimpleItem!(_.feather);
	
	alias Gunpowder = SimpleItem!(_.gunpowder);
	
	alias WoodenHoe = HoeItem!(_.woodenHoe, Tools.wood, Durability.wood);
	
	alias StoneHoe = HoeItem!(_.stoneHoe, Tools.stone, Durability.stone);
	
	alias IronHoe = HoeItem!(_.ironHoe, Tools.iron, Durability.iron);
	
	alias DiamondHoe = HoeItem!(_.diamondHoe, Tools.diamond, Durability.diamond);
	
	alias GoldenHoe = HoeItem!(_.goldenHoe, Tools.gold, Durability.gold);
	
	alias Seeds = PlaceableItem!(_.seeds, Blocks.seeds0, Blocks.farmland);
	
	alias Wheat = SimpleItem!(_.wheat);
	
	alias Bread = FoodItem!(_.bread, 5, 6);
	
	alias LeatherCap = ColorableArmorItem!(_.leatherCap, 56, Armor.cap, 1);
	
	alias LeatherTunic = ColorableArmorItem!(_.leatherTunic, 81, Armor.tunic, 3);
	
	alias LeatherPants = ColorableArmorItem!(_.leatherPants, 76, Armor.pants, 2);
	
	alias LeatherBoots = ColorableArmorItem!(_.leatherBoots, 66, Armor.boots, 1);
	
	alias ChainHelmet = ArmorItem!(_.chainHelmet, 166, Armor.helmet, 2);
	
	alias ChainChestplate = ArmorItem!(_.chainChestplate, 241, Armor.chestplate, 5);
	
	alias ChainLeggings = ArmorItem!(_.chainLeggings, 226, Armor.leggings, 4);
	
	alias ChainBoots = ArmorItem!(_.chainBoots, 196, Armor.boots, 1);
	
	alias IronHelmet = ArmorItem!(_.ironHelmet, 166, Armor.helmet, 2);
	
	alias IronChestplate = ArmorItem!(_.ironChestplate, 241, Armor.chestplate, 6);
	
	alias IronLeggings = ArmorItem!(_.ironLeggings, 226, Armor.leggings, 5);
	
	alias IronBoots = ArmorItem!(_.ironBoots, 196, Armor.boots, 2);
	
	alias DiamondHelmet = ArmorItem!(_.diamondHelmet, 364, Armor.helmet, 3);
	
	alias DiamondChestplate = ArmorItem!(_.diamondChestplate, 529, Armor.chestplate, 8);
	
	alias DiamondLeggings = ArmorItem!(_.diamondLeggings, 496, Armor.leggings, 6);
	
	alias DiamondBoots = ArmorItem!(_.diamondBoots, 430, Armor.boots, 3);
	
	alias GoldenHelmet = ArmorItem!(_.goldenHelmet, 78, Armor.helmet, 2);
	
	alias GoldenChestplate = ArmorItem!(_.goldenChestplate, 113, Armor.chestplate, 5);
	
	alias GoldenLeggings = ArmorItem!(_.goldenLeggings, 106, Armor.leggings, 3);
	
	alias GoldenBoots = ArmorItem!(_.goldenBoots, 92, Armor.boots, 1);
	
	alias Flint = SimpleItem!(_.flint);
	
	alias RawPorkchop = FoodItem!(_.rawPorkchop, 3, 1.8);
	
	alias CookedPorkchop = FoodItem!(_.cookedPorkchop, 8, 12.8);
	
	alias GoldenApple = FoodItem!(_.goldenApple, 4, 9.6, [effectInfo(Effects.regeneration, 5, "II"), effectInfo(Effects.absorption, 120, "I")]);
	
	alias EnchantedGoldenApple = FoodItem!(_.enchantedGoldenApple, 4, 9.6, [effectInfo(Effects.regeneration, 20, "II"), effectInfo(Effects.absorption, 120, "IV"), effectInfo(Effects.resistance, 300, "I"), effectInfo(Effects.fireResistance, 300, "I")]);
	
	alias Leather = SimpleItem!(_.leather);
	
	alias MilkBucket = ClearEffectsItem!(_.milkBucket, bucket);
	
	alias Brick = SimpleItem!(_.brick);
	
	alias Clay = SimpleItem!(_.clay);
	
	alias Paper = SimpleItem!(_.paper);
	
	alias Book = SimpleItem!(_.book);
	
	alias Slimeball = SimpleItem!(_.slimeball);

	alias Compass = SimpleItem!(_.compass);
	
	alias Clock = SimpleItem!(_.clock);
	
	alias GlowstoneDust = SimpleItem!(_.glowstoneDust);
	
	alias RawFish = FoodItem!(_.rawFish, 2, .4);
	
	alias RawSalmon = FoodItem!(_.rawSalmon, 2, .4);
	
	alias Clowfish = FoodItem!(_.clownfish, 1, .2);
	
	alias Pufferfish = FoodItem!(_.pufferfish, 1, .2, [effectInfo(Effects.hunger, 15, "III"), effectInfo(Effects.poison, 60, "IV"), effectInfo(Effects.nausea, 15, "II")]);
	
	alias CookedFish = FoodItem!(_.cookedFish, 5, 6);
	
	alias CookedSalmon = FoodItem!(_.cookedSalmon, 6, 9.6);
	
	alias InkSac = SimpleItem!(_.inkSac);
	
	alias RoseRed = SimpleItem!(_.roseRed);
	
	alias CactusGreen = SimpleItem!(_.cactusGreen);
	
	alias CocoaBeans = BeansItem!(_.cocoaBeans, [Blocks.cocoaNorth0, Blocks.cocoaEast0, Blocks.cocoaSouth0, Blocks.cocoaWest0]);
	
	alias LapisLazuli = SimpleItem!(_.lapisLazuli);
	
	alias PurpleDye = SimpleItem!(_.purpleDye);
	
	alias CyanDye = SimpleItem!(_.cyanDye);
	
	alias LightGrayDye = SimpleItem!(_.lightGrayDye);
	
	alias GrayDye = SimpleItem!(_.grayDye);
	
	alias PinkDye = SimpleItem!(_.pinkDye);
	
	alias LimeDye = SimpleItem!(_.limeDye);
	
	alias DandelionYellow = SimpleItem!(_.dandelionYellow);
	
	alias LightBlueDye = SimpleItem!(_.lightBlueDye);
	
	alias MagentaDye = SimpleItem!(_.magentaDye);
	
	alias OrangeDye = SimpleItem!(_.orangeDye);
	
	alias Bone = SimpleItem!(_.bone);
	
	alias Sugar = SimpleItem!(_.sugar);
	
	alias Cake = PlaceableItem!(_.cake, Blocks.cake0);
	
	//TODO beds

	alias Cookie = FoodItem!(_.cookie, 2, .4);
	
	alias Map = MapItem!(_.map);

	alias Melon = FoodItem!(_.melon, 2, 1.2);
	
	alias PumpkinSeeds = PlaceableItem!(_.pumpkinSeeds, Blocks.pumpkinStem0, Blocks.farmland);
	
	alias MelonSeeds = PlaceableItem!(_.melonSeeds, Blocks.melonStem0, Blocks.farmland);
	
	alias RawBeef = FoodItem!(_.rawBeef, 3, 1.8);
	
	alias Steak = FoodItem!(_.steak, 8, 12.8);
	
	alias RawChicken = FoodItem!(_.rawChicken, 2, 1.2);
	
	alias CookedChicked = FoodItem!(_.cookedChicken, 6, 7.2);
	
	alias RottenFlesh = FoodItem!(_.rottenFlesh, 4, .8, [effectInfo(Effects.hunger, 30, "I", .8)]);
	
	alias BlazeRod = SimpleItem!(_.blazeRod);
	
	alias GhastTear = SimpleItem!(_.ghastTear);
	
	alias GoldNugget = SimpleItem!(_.goldNugget);
	
	alias NetherWart = PlaceableItem!(_.netherWart, Blocks.netherWart0, [Blocks.soulSand]);

	alias SpiderEye = SimpleItem!(_.spiderEye);
	
	alias FermentedSpiderEye = SimpleItem!(_.fermentedSpiderEye);
	
	alias BlazePowder = SimpleItem!(_.blazePowder);
	
	alias MagmaCream = SimpleItem!(_.magmaCream);
	
	alias BrewingStand = PlaceableItem!(_.brewingStand, Blocks.brewingStandEmpty);
	
	alias Cauldron = PlaceableItem!(_.cauldron, Blocks.cauldronEmpty);
	
	
	alias GlisteringMelon = SimpleItem!(_.glisteringMelon);
	
	//TODO spawn eggs

	alias Emerald = SimpleItem!(_.emerald);

	alias FlowerPot = PlaceableOnSolidItem!(_.flowerPot, Blocks.flowerPot);
	
	alias Carrot = CropFoodItem!(_.carrot, 3, 4.8, Blocks.carrot0);
	
	alias Potato = CropFoodItem!(_.potato, 1, .6, Blocks.potato0);
	
	alias BakedPotato = FoodItem!(_.bakedPotato, 5, 7.2);
	
	alias PoisonousPotato = FoodItem!(_.poisonousPotato, 2, 1.2, [effectInfo(Effects.poison, 4, "I", .6)]);

	alias GoldenCarrot = FoodItem!(_.goldenCarrot, 6, 14.4);

	alias NetherStar = SimpleItem!(_.netherStar);
	
	alias PumpkinPie = FoodItem!(_.pumpkinPie, 8, 4.8);
	
	alias NetherBrick = SimpleItem!(_.netherBrick);
	
	alias NetherQuartz = SimpleItem!(_.netherQuartz);

	alias PrismarineShard = SimpleItem!(_.prismarineShard);
	
	alias PrismarineCrystals = SimpleItem!(_.prismarineCrystals);
	
	alias RawRabbit = FoodItem!(_.rawRabbit, 3, 1.8);
	
	alias CookedRabbit = FoodItem!(_.cookedRabbit, 5, 6);
	
	alias RabbitStew = SoupItem!(_.rabbitStew, 10, 12);
	
	alias RabbitFoot = SimpleItem!(_.rabbitFoot);
	
	alias RabbitHide = SimpleItem!(_.rabbitHide);
	
	alias RawMutton = FoodItem!(_.rawMutton, 2, 1.2);
	
	alias CookedMutton = FoodItem!(_.cookedMutton, 6, 9.6);
	
	alias ChorusFruit = TeleportationItem!(_.chorusFruit, 4, 2.4);
	
	alias PoppedChorusFruit = SimpleItem!(_.poppedChorusFruit);
	
	alias Beetroot = FoodItem!(_.beetroot, 1, 1.2);
	
	alias BeetrootSeeds = PlaceableItem!(_.beetrootSeeds, Blocks.beetroot0, Blocks.farmland);
	
	alias BeetrootSoup = SoupItem!(_.beetrootSoup, 6, 7.2);
	
	alias ShulkerShell = SimpleItem!(_.shulkerShell);
	
	alias IronNugget = SimpleItem!(_.ironNugget);
	
	//TODO discs


	enum item_t invisibleBedrock = barrier;

	
	enum item_t[] woodPlanks = [oakWoodPlanks, spruceWoodPlanks, birchWoodPlanks, jungleWoodPlanks, acaciaWoodPlanks, darkOakWoodPlanks];
	
	enum item_t[] sapling = [oakSapling, spruceSapling, birchSapling, acaciaSapling, darkOakSapling];
	
	enum item_t[] wool = [whiteWool, orangeWool, magentaWool, lightBlueWool, yellowWool, limeWool, pinkWool, grayWool, lightGrayWool, cyanWool, purpleWool, blueWool, brownWool, greenWool, redWool, blackWool];

	enum item_t[] stainedGlass = [whiteStainedGlass, orangeStainedGlass, magentaStainedGlass, lightBlueStainedGlass, yellowStainedGlass, limeStainedGlass, pinkStainedGlass, grayStainedGlass, lightGrayStainedGlass, cyanStainedGlass, purpleStainedGlass, blueStainedGlass, brownStainedGlass, greenStainedGlass, redStainedGlass, blackStainedGlass];

	enum item_t[] stainedClay = [whiteStainedClay, orangeStainedClay, magentaStainedClay, lightBlueStainedClay, yellowStainedClay, limeStainedClay, pinkStainedClay, grayStainedClay, lightGrayStainedClay, cyanStainedClay, purpleStainedClay, blueStainedClay, brownStainedClay, greenStainedClay, redStainedClay, blackStainedClay];

	enum item_t[] stainedGlassPane = [whiteStainedGlassPane, orangeStainedGlassPane, magentaStainedGlassPane, lightBlueStainedGlassPane, yellowStainedGlassPane, limeStainedGlassPane, pinkStainedGlassPane, grayStainedGlassPane, lightGrayStainedGlassPane, cyanStainedGlassPane, purpleStainedGlassPane, blueStainedGlassPane, brownStainedGlassPane, greenStainedGlassPane, redStainedGlassPane, blackStainedGlassPane];

	enum item_t[] carpet = [whiteCarpet, orangeCarpet, magentaCarpet, lightBlueCarpet, yellowCarpet, limeCarpet, pinkCarpet, grayCarpet, lightGrayCarpet, cyanCarpet, purpleCarpet, blueCarpet, brownCarpet, greenCarpet, redCarpet, blackCarpet];

	enum item_t[] shulkerBox = [whiteShulkerBox, orangeShulkerBox, magentaShulkerBox, lightBlueShulkerBox, yellowShulkerBox, limeShulkerBox, pinkShulkerBox, grayShulkerBox, lightGrayShulkerBox, cyanShulkerBox, purpleShulkerBox, blueShulkerBox, brownShulkerBox, greenShulkerBox, redShulkerBox, blackShulkerBox];

}
