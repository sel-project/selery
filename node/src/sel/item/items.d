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

import com.sel;

import sel.block.blocks : Blocks;
import sel.entity.effect : Effects;
import sel.item.consumeable;
import sel.item.item : Item, SimpleItem;
import sel.item.miscellaneous;
import sel.item.placeable;
import sel.item.tool;

static import sul.items;
public import sul.items : _ = Items;

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
			foreach_reverse(a ; __traits(allMembers, Items)) {
				static if(mixin("is(" ~ a ~ " : Item)")) {
					mixin("this.register(new " ~ a ~ "());");
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
	
	public void register(T:Item)(T item) {
		static if(__traits(compiles, new T(ushort.max))) {
			auto f = (ushort damage){ return cast(Item)new T(damage); };
		} else {
			auto f = (ushort damage){ return cast(Item)new T(); };
		}
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
		return this.indexes.length < index ? this.indexes[index] : null;
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
	 * assert(items.fromString("mdnn pttn") is null);
	 * ---
	 */
	public Item fromString(string name, ushort damage=0) {
		auto f = name.toLower.replace("_", " ") in this.strings;
		return f ? (*f)(damage) : null;
	}

}

interface Items {
	
	public enum air = _.air.index;
	
	public enum stone = _.stone.index;
	public alias Stone = PlaceableItem!(_.stone, Blocks.stone);
	
	public enum granite = _.granite.index;
	public alias Granite = PlaceableItem!(_.granite, Blocks.granite);
	
	public enum polishedGranite = _.polishedGranite.index;
	public alias PolishedGranite = PlaceableItem!(_.polishedGranite, Blocks.polishedGranite);
	
	public enum diorite = _.diorite.index;
	public alias Diorite = PlaceableItem!(_.diorite, Blocks.diorite);
	
	public enum polishedDiorite = _.polishedDiorite.index;
	public alias PolishedDiorite = PlaceableItem!(_.polishedDiorite, Blocks.polishedDiorite);
	
	public enum andesite = _.andesite.index;
	public alias Andesite = PlaceableItem!(_.andesite, Blocks.andesite);
	
	public enum polishedAndesite = _.polishedAndesite.index;
	public alias PolishedAndesite = PlaceableItem!(_.polishedAndesite, Blocks.polishedAndesite);
	
	public enum grass = _.grass.index;
	public alias Grass = PlaceableItem!(_.grass, Blocks.grass);
	
	public enum dirt = _.dirt.index;
	public alias Dirt = PlaceableItem!(_.dirt, Blocks.dirt);
	
	public enum coarseDirt = _.coarseDirt.index;
	public alias CoarseDirt = PlaceableItem!(_.coarseDirt, Blocks.coarseDirt);
	
	public enum podzol = _.podzol.index;
	public alias Podzol = PlaceableItem!(_.podzol, Blocks.podzol);
	
	public enum cobblestone = _.cobblestone.index;
	public alias Cobblestone = PlaceableItem!(_.cobblestone, Blocks.cobblestone);
	
	public enum oakWoodPlanks = _.oakWoodPlanks.index;
	public alias OakWoodPlanks = PlaceableItem!(_.oakWoodPlanks, Blocks.oakWoodPlanks);
	
	public enum spruceWoodPlanks = _.spruceWoodPlanks.index;
	public alias SpruceWoodPlanks = PlaceableItem!(_.spruceWoodPlanks, Blocks.spruceWoodPlanks);
	
	public enum birchWoodPlanks = _.birchWoodPlanks.index;
	public alias BirchWoodPlanks = PlaceableItem!(_.birchWoodPlanks, Blocks.birchWoodPlanks);
	
	public enum jungleWoodPlanks = _.jungleWoodPlanks.index;
	public alias JungleWoodPlanks = PlaceableItem!(_.jungleWoodPlanks, Blocks.jungleWoodPlanks);
	
	public enum acaciaWoodPlanks = _.acaciaWoodPlanks.index;
	public alias AcaciaWoodPlanks = PlaceableItem!(_.acaciaWoodPlanks, Blocks.acaciaWoodPlanks);
	
	public enum darkOakWoodPlanks = _.darkOakWoodPlanks.index;
	public alias DarkOakWoodPlanks = PlaceableItem!(_.darkOakWoodPlanks, Blocks.darkOakWoodPlanks);
	
	public enum woodPlanks = [oakWoodPlanks, spruceWoodPlanks, birchWoodPlanks, jungleWoodPlanks, acaciaWoodPlanks, darkOakWoodPlanks];
	
	public enum oakSapling = _.oakSapling.index;
	public alias OakSapling = PlaceableItem!(_.oakSapling, Blocks.oakSapling, Blocks.dirts);
	
	public enum spruceSapling = _.spruceSapling.index;
	public alias SpruceSapling = PlaceableItem!(_.spruceSapling, Blocks.spruceSapling, Blocks.dirts);
	
	public enum birchSapling = _.birchSapling.index;
	public alias BirchSapling = PlaceableItem!(_.birchSapling, Blocks.birchSapling, Blocks.dirts);
	
	public enum jungleSapling = _.jungleSapling.index;
	public alias JungleSapling = PlaceableItem!(_.jungleSapling, Blocks.jungleSapling, Blocks.dirts);
	
	public enum acaciaSapling = _.acaciaSapling.index;
	public alias AcaciaSapling = PlaceableItem!(_.acaciaSapling, Blocks.acaciaSapling, Blocks.dirts);
	
	public enum darkOakSapling = _.darkOakSapling.index;
	public alias DarkOakSapling = PlaceableItem!(_.darkOakSapling, Blocks.darkOakSapling, Blocks.dirts);
	
	public enum sapling = [oakSapling, spruceSapling, birchSapling, acaciaSapling, darkOakSapling];
	
	public enum bedrock = _.bedrock.index;
	public alias Bedrock = PlaceableItem!(_.bedrock, Blocks.bedrock);
	
	public enum sand = _.sand.index;
	public alias Sand = PlaceableItem!(_.sand, Blocks.sand);
	
	public enum redSand = _.redSand.index;
	public alias RedSand = PlaceableItem!(_.redSand, Blocks.redSand);
	
	public enum gravel = _.gravel.index;
	public alias Gravel = PlaceableItem!(_.gravel, Blocks.gravel);
	
	public enum goldOre = _.goldOre.index;
	public alias GoldOre = PlaceableItem!(_.goldOre, Blocks.goldOre);
	
	public enum ironOre = _.ironOre.index;
	public alias IronOre = PlaceableItem!(_.ironOre, Blocks.ironOre);
	
	public enum coalOre = _.coalOre.index;
	public alias CoalOre = PlaceableItem!(_.coalOre, Blocks.coalOre);
	
	public enum oakWood = _.oakWood.index;
	public alias OakWood = WoodItem!(_.oakWood, Blocks.oakWood);
	
	public enum spruceWood = _.spruceWood.index;
	public alias SpruceWood = WoodItem!(_.spruceWood, Blocks.spruceWood);
	
	public enum birchWood = _.birchWood.index;
	public alias BirchWood = WoodItem!(_.birchWood, Blocks.birchWood);
	
	public enum jungleWood = _.jungleWood.index;
	public alias JungleWood = WoodItem!(_.jungleWood, Blocks.jungleWood);
	
	public enum acaciaWood = _.acaciaWood.index;
	public alias AcaciaWood = WoodItem!(_.acaciaWood, Blocks.acaciaWood);
	
	public enum darkOakWood = _.darkOakWood.index;
	public alias DarkOakWood = WoodItem!(_.darkOakWood, Blocks.darkOakWood);
	
	public enum oakLeaves = _.oakLeaves.index;
	public alias OakLeaves = PlaceableItem!(_.oakLeaves, Blocks.oakLeavesNoDecay);
	
	public enum spruceLeaves = _.spruceLeaves.index;
	public alias SpruceLeaves = PlaceableItem!(_.spruceLeaves, Blocks.spruceLeavesNoDecay);
	
	public enum birchLeaves = _.birchLeaves.index;
	public alias BirchLeaves = PlaceableItem!(_.birchLeaves, Blocks.birchLeavesNoDecay);
	
	public enum jungleLeaves = _.jungleLeaves.index;
	public alias JungleLeaves = PlaceableItem!(_.jungleLeaves, Blocks.jungleLeavesNoDecay);
	
	public enum acaciaLeaves = _.acaciaLeaves.index;
	public alias AcaciaLeaves = PlaceableItem!(_.acaciaLeaves, Blocks.acaciaLeavesNoDecay);
	
	public enum darkOakLeaves = _.darkOakLeaves.index;
	public alias DarkOakLeaves = PlaceableItem!(_.darkOakLeaves, Blocks.darkOakLeavesNoDecay);
	
	public enum sponge = _.sponge.index;
	public alias Sponge = PlaceableItem!(_.sponge, Blocks.sponge);
	
	public enum wetSponge = _.wetSponge.index;
	public alias WetSponge = PlaceableItem!(_.wetSponge, Blocks.wetSponge);
	
	public enum glass = _.glass.index;
	public alias Glass = PlaceableItem!(_.glass, Blocks.glass);
	
	public enum lapisLazuliOre = _.lapisLazuliOre.index;
	public alias LapisLazuliOre = PlaceableItem!(_.lapisLazuliOre, Blocks.lapisLazuliOre);
	
	public enum lapisLazuliBlock = _.lapisLazuliBlock.index;
	public alias LapisLazuliBlock = PlaceableItem!(_.lapisLazuliBlock, Blocks.lapisLazuliBlock);
	
	public enum dispenser = _.dispenser.index;
	public alias Dispenser = SimpleItem!(_.dispenser);
	
	public enum sandstone = _.sandstone.index;
	public alias Sandstone = PlaceableItem!(_.sandstone, Blocks.sandstone);
	
	public enum chiseledSandstone = _.chiseledSandstone.index;
	public alias ChiseledSandstone = PlaceableItem!(_.chiseledSandstone, Blocks.chiseledSandstone);
	
	public enum smoothSandstone = _.smoothSandstone.index;
	public alias SmoothSandstone = PlaceableItem!(_.smoothSandstone, Blocks.smoothSandstone);
	
	public enum noteBlock = _.noteBlock.index;
	public alias NoteBlock = PlaceableItem!(_.noteBlock, Blocks.noteBlock);
	
	public enum poweredRail = _.poweredRail.index;
	public alias PoweredRail = SimpleItem!(_.poweredRail);
	
	public enum detectorRail = _.detectorRail.index;
	public alias DetectorRail = SimpleItem!(_.detectorRail);
	
	public enum stickyPiston = _.stickyPiston.index;
	public alias StickyPiston = SimpleItem!(_.stickyPiston);
	
	public enum cobweb = _.cobweb.index;
	public alias Cobweb = PlaceableItem!(_.cobweb, Blocks.cobweb);
	
	public enum tallGrass = _.tallGrass.index;
	public alias TallGrass = PlaceableItem!(_.tallGrass, Blocks.tallGrass, Blocks.dirts);
	
	public enum fern = _.fern.index;
	public alias Fern = PlaceableItem!(_.fern, Blocks.fern, Blocks.dirts);
	
	public enum deadBush = _.deadBush.index;
	public alias DeadBush = PlaceableItem!(_.deadBush, Blocks.deadBush, [Blocks.sand.id, Blocks.redSand.id, Blocks.dirt.id, Blocks.podzol.id, Blocks.coarseDirt.id, Blocks.hardenedClay.id] ~ Blocks.stainedClay);
	
	public enum piston = _.piston.index;
	public alias Piston = SimpleItem!(_.piston);
	
	public enum whiteWool = _.whiteWool.index;
	public alias WhiteWool = PlaceableItem!(_.whiteWool, Blocks.whiteWool);
	
	public enum orangeWool = _.orangeWool.index;
	public alias OrangeWool = PlaceableItem!(_.orangeWool, Blocks.orangeWool);
	
	public enum magentaWool = _.magentaWool.index;
	public alias MagentaWool = PlaceableItem!(_.magentaWool, Blocks.magentaWool);
	
	public enum lightBlueWool = _.lightBlueWool.index;
	public alias LightBlueWool = PlaceableItem!(_.lightBlueWool, Blocks.lightBlueWool);
	
	public enum yellowWool = _.yellowWool.index;
	public alias YellowWool = PlaceableItem!(_.yellowWool, Blocks.yellowWool);
	
	public enum limeWool = _.limeWool.index;
	public alias LimeWool = PlaceableItem!(_.limeWool, Blocks.limeWool);
	
	public enum pinkWool = _.pinkWool.index;
	public alias PinkWool = PlaceableItem!(_.pinkWool, Blocks.pinkWool);
	
	public enum grayWool = _.grayWool.index;
	public alias GrayWool = PlaceableItem!(_.grayWool, Blocks.grayWool);
	
	public enum lightGrayWool = _.lightGrayWool.index;
	public alias LightGrayWool = PlaceableItem!(_.lightGrayWool, Blocks.lightGrayWool);
	
	public enum cyanWool = _.cyanWool.index;
	public alias CyanWool = PlaceableItem!(_.cyanWool, Blocks.cyanWool);
	
	public enum purpleWool = _.purpleWool.index;
	public alias PurpleWool = PlaceableItem!(_.purpleWool, Blocks.purpleWool);
	
	public enum blueWool = _.blueWool.index;
	public alias BlueWool = PlaceableItem!(_.blueWool, Blocks.blueWool);
	
	public enum brownWool = _.brownWool.index;
	public alias BrownWool = PlaceableItem!(_.brownWool, Blocks.brownWool);
	
	public enum greenWool = _.greenWool.index;
	public alias GreenWool = PlaceableItem!(_.greenWool, Blocks.greenWool);
	
	public enum redWool = _.redWool.index;
	public alias RedWool = PlaceableItem!(_.redWool, Blocks.redWool);
	
	public enum blackWool = _.blackWool.index;
	public alias BlackWool = PlaceableItem!(_.blackWool, Blocks.blackWool);
	
	public enum wool = [whiteWool, orangeWool, magentaWool, lightBlueWool, yellowWool, limeWool, pinkWool, grayWool, lightGrayWool, cyanWool, purpleWool, blueWool, brownWool, greenWool, redWool, blackWool];
	
	public enum dandelion = _.dandelion.index;
	public alias Dandelion = PlaceableItem!(_.dandelion, Blocks.dandelion);
	
	public enum poppy = _.poppy.index;
	public alias Poppy = PlaceableItem!(_.poppy, Blocks.poppy);
	
	public enum blueOrchid = _.blueOrchid.index;
	public alias BlueOrchid = PlaceableItem!(_.blueOrchid, Blocks.blueOrchid);
	
	public enum allium = _.allium.index;
	public alias Allium = PlaceableItem!(_.allium, Blocks.allium);
	
	public enum azureBluet = _.azureBluet.index;
	public alias AzureBluet = PlaceableItem!(_.azureBluet, Blocks.azureBluet);
	
	public enum redTulip = _.redTulip.index;
	public alias RedTulip = PlaceableItem!(_.redTulip, Blocks.redTulip);
	
	public enum orangeTulip = _.orangeTulip.index;
	public alias OrangeTulip = PlaceableItem!(_.orangeTulip, Blocks.orangeTulip);
	
	public enum whiteTulip = _.whiteTulip.index;
	public alias WhiteTulip = PlaceableItem!(_.whiteTulip, Blocks.whiteTulip);
	
	public enum pinkTulip = _.pinkTulip.index;
	public alias PinkTulip = PlaceableItem!(_.pinkTulip, Blocks.pinkTulip);
	
	public enum oxeyeDaisy = _.oxeyeDaisy.index;
	public alias OxeyeDaisy = PlaceableItem!(_.oxeyeDaisy, Blocks.oxeyeDaisy);
	
	public enum brownMushroom = _.brownMushroom.index; //TODO place on low light level
	public alias BrownMushroom = PlaceableItem!(_.brownMushroom, Blocks.brownMushroom, [Blocks.podzol]);
	
	public enum redMushroom = _.redMushroom.index;
	public alias RedMushroom = PlaceableItem!(_.redMushroom, Blocks.redMushroom, [Blocks.podzol]);
	
	public enum goldBlock = _.goldBlock.index;
	public alias GoldBlock = PlaceableItem!(_.goldBlock, Blocks.goldBlock);
	
	public enum ironBlock = _.ironBlock.index;
	public alias IronBlock = PlaceableItem!(_.ironBlock, Blocks.ironBlock);
	
	public enum stoneSlab = _.stoneSlab.index;
	public alias StoneSlab = SlabItem!(_.stoneSlab, Blocks.stoneSlab, Blocks.upperStoneSlab, Blocks.doubleStoneSlab);
	
	public enum sandstoneSlab = _.sandstoneSlab.index;
	public alias SandstoneSlab = SlabItem!(_.sandstoneSlab, Blocks.sandstoneSlab, Blocks.upperSandstoneSlab, Blocks.doubleSandstoneSlab);
	
	public enum stoneWoodenSlab = _.stoneWoodenSlab.index;
	public alias StoneWoodenSlab = SlabItem!(_.stoneWoodenSlab, Blocks.stoneWoodenSlab, Blocks.upperStoneWoodenSlab, Blocks.doubleStoneWoodenSlab);
	
	public enum cobblestoneSlab = _.cobblestoneSlab.index;
	public alias CobblestoneSlab = SlabItem!(_.cobblestoneSlab, Blocks.cobblestoneSlab, Blocks.upperCobblestoneSlab, Blocks.doubleCobblestoneSlab);
	
	public enum bricksSlab = _.bricksSlab.index;
	public alias BricksSlab = SlabItem!(_.bricksSlab, Blocks.bricksSlab, Blocks.upperBricksSlab, Blocks.doubleBricksSlab);
	
	public enum stoneBrickSlab = _.stoneBrickSlab.index;
	public alias StoneBrickSlab = SlabItem!(_.stoneBrickSlab, Blocks.stoneBrickSlab, Blocks.upperStoneBrickSlab, Blocks.doubleStoneBrickSlab);
	
	public enum netherBrickSlab = _.netherBrickSlab.index;
	public alias NetherBrickSlab = SlabItem!(_.netherBrickSlab, Blocks.netherBrickSlab, Blocks.upperNetherBrickSlab, Blocks.doubleNetherBrickSlab);
	
	public enum quartzSlab = _.quartzSlab.index;
	public alias QuartzSlab = SlabItem!(_.quartzSlab, Blocks.quartzSlab, Blocks.upperQuartzSlab, Blocks.doubleQuartzSlab);
	
	public enum bricks = _.bricks.index;
	public alias Bricks = PlaceableItem!(_.bricks, Blocks.bricks);
	
	public enum tnt = _.tnt.index;
	public alias Tnt = PlaceableItem!(_.tnt, Blocks.tnt);
	
	public enum bookshelf = _.bookshelf.index;
	public alias Bookshelf = PlaceableItem!(_.bookshelf, Blocks.bookshelf);
	
	public enum mossStone = _.mossStone.index;
	public alias MossStone = PlaceableItem!(_.mossStone, Blocks.mossStone);
	
	public enum obsidian = _.obsidian.index;
	public alias Obsidian = PlaceableItem!(_.obsidian, Blocks.obsidian);
	
	public enum torch = _.torch.index;
	public alias Torch = TorchItem!(_.torch, Blocks.torch);
	
	public enum monsterSpawner = _.monsterSpawner.index;
	public alias MonsterSpawner = PlaceableItem!(_.monsterSpawner, Blocks.monsterSpawner);
	
	public enum oakWoodStairs = _.oakWoodStairs.index;
	public alias OakWoodStairs = StairsItem!(_.oakWoodStairs, Blocks.oakWoodStairs);
	
	public enum chest = _.chest.index;
	//TODO place tile in right direction
	
	public enum diamondOre = _.diamondOre.index;
	public alias DiamondOre = PlaceableItem!(_.diamondOre, Blocks.diamondOre);
	
	public enum diamondBlock = _.diamondBlock.index;
	public alias DiamondBlock = PlaceableItem!(_.diamondBlock, Blocks.diamondBlock);
	
	public enum craftingTable = _.craftingTable.index;
	public alias CraftingTable = PlaceableItem!(_.craftingTable, Blocks.craftingTable);
	
	public enum furnace = _.furnace.index;
	//TODO place tile in the right direction
	
	public enum ladder = _.ladder.index;
	//TODO place in the right direction
	
	public enum rail = _.rail.index;
	//TODO
	
	public enum cobblestoneStairs = _.cobblestoneStairs.index;
	public alias CobblestoneStairs = StairsItem!(_.cobblestoneStairs, Blocks.cobblestoneStairs);
	
	public enum lever = _.lever.index;
	//TODO
	
	public enum stonePressurePlate = _.stonePressurePlate.index;
	
	public enum woodenPressurePlate = _.woodenPressurePlate.index;
	
	public enum redstoneOre = _.redstoneOre.index;
	public alias RedstoneOre = PlaceableItem!(_.redstoneOre, Blocks.redstoneOre);
	
	public enum redstoneTorch = _.redstoneTorch.index;
	
	public enum stoneButton = _.stoneButton.index;
	
	public enum snowLayer = _.snowLayer.index;
	
	public enum ice = _.ice.index;
	public alias Ice = PlaceableItem!(_.ice, Blocks.ice);
	
	public enum snowBlock = _.snowBlock.index;
	public alias SnowBlock = PlaceableItem!(_.snowBlock, Blocks.snow);
	
	public enum cactus = _.cactus.index;
	public alias Cactus = PlaceableItem!(_.cactus, Blocks.cactus0, [Blocks.sand.id, Blocks.redSand.id] ~ Blocks.cactus); //TODO do not place near other blocks
	
	public enum clayBlock = _.clayBlock.index;
	public alias ClayBlock = PlaceableItem!(_.clayBlock, Blocks.clay);
	
	public enum jukebox = _.jukebox.index;
	public alias Jukebox = PlaceableItem!(_.jukebox, Blocks.jukebox);
	
	public enum oakFence = _.oakFence.index;
	
	public enum pumpkin = _.pumpkin.index;
	
	public enum netherrack = _.netherrack.index;
	public alias Netherrack = PlaceableItem!(_.netherrack, Blocks.netherrack);
	
	public enum soulSand = _.soulSand.index;
	public alias SoulSand = PlaceableItem!(_.soulSand, Blocks.soulSand);
	
	public enum glowstone = _.glowstone.index;
	public alias Glowstone = PlaceableItem!(_.glowstone, Blocks.glowstone);
	
	public enum jackOLantern = _.jackOLantern.index;
	
	public enum whiteStainedGlass = _.whiteStainedGlass.index;
	public alias WhiteStainedGlass = PlaceableItem!(_.whiteStainedGlass, Blocks.whiteStainedGlass);
	
	public enum orangeStainedGlass = _.orangeStainedGlass.index;
	public alias OrangeStainedGlass = PlaceableItem!(_.orangeStainedGlass, Blocks.orangeStainedGlass);
	
	public enum magentaStainedGlass = _.magentaStainedGlass.index;
	public alias MagentaStainedGlass = PlaceableItem!(_.magentaStainedGlass, Blocks.magentaStainedGlass);
	
	public enum lightBlueStainedGlass = _.lightBlueStainedGlass.index;
	public alias LightBlueStainedGlass = PlaceableItem!(_.lightBlueStainedGlass, Blocks.lightBlueStainedGlass);
	
	public enum yellowStainedGlass = _.yellowStainedGlass.index;
	public alias YellowStainedGlass = PlaceableItem!(_.yellowStainedGlass, Blocks.yellowStainedGlass);
	
	public enum limeStainedGlass = _.limeStainedGlass.index;
	public alias LimeStainedGlass = PlaceableItem!(_.limeStainedGlass, Blocks.limeStainedGlass);
	
	public enum pinkStainedGlass = _.pinkStainedGlass.index;
	public alias PinkStainedGlass = PlaceableItem!(_.pinkStainedGlass, Blocks.pinkStainedGlass);
	
	public enum grayStainedGlass = _.grayStainedGlass.index;
	public alias GrayStainedGlass = PlaceableItem!(_.grayStainedGlass, Blocks.grayStainedGlass);
	
	public enum lightGrayStainedGlass = _.lightGrayStainedGlass.index;
	public alias LightGrayStainedGlass = PlaceableItem!(_.lightGrayStainedGlass, Blocks.lightGrayStainedGlass);
	
	public enum cyanStainedGlass = _.cyanStainedGlass.index;
	public alias CyanStainedGlass = PlaceableItem!(_.cyanStainedGlass, Blocks.cyanStainedGlass);
	
	public enum purpleStainedGlass = _.purpleStainedGlass.index;
	public alias PurpleStainedGlass = PlaceableItem!(_.purpleStainedGlass, Blocks.purpleStainedGlass);
	
	public enum blueStainedGlass = _.blueStainedGlass.index;
	public alias BlueStainedGlass = PlaceableItem!(_.blueStainedGlass, Blocks.blueStainedGlass);
	
	public enum brownStainedGlass = _.brownStainedGlass.index;
	public alias BrownStainedGlass = PlaceableItem!(_.brownStainedGlass, Blocks.brownStainedGlass);
	
	public enum greenStainedGlass = _.greenStainedGlass.index;
	public alias GreenStainedGlass = PlaceableItem!(_.greenStainedGlass, Blocks.greenStainedGlass);
	
	public enum redStainedGlass = _.redStainedGlass.index;
	public alias RedStainedGlass = PlaceableItem!(_.redStainedGlass, Blocks.redStainedGlass);
	
	public enum blackStainedGlass = _.blackStainedGlass.index;
	public alias BlackStainedGlass = PlaceableItem!(_.blackStainedGlass, Blocks.blackStainedGlass);
	
	public enum stainedGlass = [whiteStainedGlass, orangeStainedGlass, magentaStainedGlass, lightBlueStainedGlass, yellowStainedGlass, limeStainedGlass, pinkStainedGlass, grayStainedGlass, lightGrayStainedGlass, cyanStainedGlass, purpleStainedGlass, blueStainedGlass, brownStainedGlass, greenStainedGlass, redStainedGlass, blackStainedGlass];
	
	public enum woodenTrapdoor = _.woodenTrapdoor.index;
	
	public enum stoneMonsterEgg = _.stoneMonsterEgg.index;
	public alias StoneMonsterEgg = PlaceableItem!(_.stoneMonsterEgg, Blocks.stoneMonsterEgg);
	
	public enum cobblestoneMonsterEgg = _.cobblestoneMonsterEgg.index;
	public alias CobblestoneMonsterEgg = PlaceableItem!(_.cobblestoneMonsterEgg, Blocks.cobblestoneMonsterEgg);
	
	public enum stoneBrickMonsterEgg = _.stoneBrickMonsterEgg.index;
	public alias StoneBrickMonsterEgg = PlaceableItem!(_.stoneBrickMonsterEgg, Blocks.stoneBrickMonsterEgg);
	
	public enum mossyStoneBrickMonsterEgg = _.mossyStoneBrickMonsterEgg.index;
	public alias MossyStoneBrickMonsterEgg = PlaceableItem!(_.mossyStoneBrickMonsterEgg, Blocks.mossyStoneBrickMonsterEgg);
	
	public enum crackedStoneBrickMonsterEgg = _.crackedStoneBrickMonsterEgg.index;
	public alias CrackedStoneBrickMonsterEgg = PlaceableItem!(_.crackedStoneBrickMonsterEgg, Blocks.crackedStoneBrickMonsterEgg);
	
	public enum chiseledStoneBrickMonsterEgg = _.chiseledStoneBrickMonsterEgg.index;
	public alias ChiseledStoneBrickMonsterEgg = PlaceableItem!(_.chiseledStoneBrickMonsterEgg, Blocks.chiseledStoneBrickMonsterEgg);
	
	public enum stoneBricks = _.stoneBricks.index;
	public alias StoneBricks = PlaceableItem!(_.stoneBricks, Blocks.stoneBricks);
	
	public enum mossyStoneBricks = _.mossyStoneBricks.index;
	public alias MossyStoneBricks = PlaceableItem!(_.mossyStoneBricks, Blocks.mossyStoneBricks);
	
	public enum crackedStoneBricks = _.crackedStoneBricks.index;
	public alias CrackedStoneBricks = PlaceableItem!(_.crackedStoneBricks, Blocks.crackedStoneBricks);
	
	public enum chiseledStoneBricks = _.chiseledStoneBricks.index;
	public alias ChiseledStoneBricks = PlaceableItem!(_.chiseledStoneBricks, Blocks.chiseledStoneBricks);
	
	public enum brownMushroomBlock = _.brownMushroomBlock.index;
	public alias BrownMushroomBlock = PlaceableItem!(_.brownMushroomBlock, Blocks.brownMushroomCapsEverywhere);
	
	public enum redMushroomBlock = _.redMushroomBlock.index;
	public alias RedMushroomBlock = PlaceableItem!(_.redMushroomBlock, Blocks.redMushroomCapsEverywhere);
	
	public enum ironBars = _.ironBars.index;
	public alias IronBars = PlaceableItem!(_.ironBars, Blocks.ironBars);
	
	public enum glassPane = _.glassPane.index;
	public alias GlassPane = PlaceableItem!(_.glassPane, Blocks.glassPane);
	
	public enum melonBlock = _.melonBlock.index;
	public alias MelonBlock = PlaceableItem!(_.melonBlock, Blocks.melon);
	
	public enum vines = _.vines.index;
	
	public enum oakFenceGate = _.oakFenceGate.index;
	
	public enum brickStairs = _.brickStairs.index;
	
	public enum stoneBrickStairs = _.stoneBrickStairs.index;
	
	public enum mycelium = _.mycelium.index;
	public alias Mycelium = PlaceableItem!(_.mycelium, Blocks.mycelium);
	
	public enum lilyPad = _.lilyPad.index;
	public alias LilyPad = PlaceableItem!(_.lilyPad, Blocks.lilyPad, [Blocks.flowingWater0.id, Blocks.stillWater0.id, Blocks.ice.id] ~ Blocks.frostedIce);
	
	public enum netherBrickBlock = _.netherBrickBlock.index;
	public alias NetherBrickBlock = PlaceableItem!(_.netherBrickBlock, Blocks.netherBrick);
	
	public enum netherBrickFence = _.netherBrickFence.index;
	public alias NetherBrickFence = PlaceableItem!(_.netherBrickFence, Blocks.netherBrickFence);
	
	public enum netherBrickStairs = _.netherBrickStairs.index;
	
	public enum enchantmentTable = _.enchantmentTable.index;
	public alias EnchantmentTable = PlaceableItem!(_.enchantmentTable, Blocks.enchantmentTable);
	
	public enum endPortalFrame = _.endPortalFrame.index;
	
	public enum endStone = _.endStone.index;
	public alias EndStone = PlaceableItem!(_.endStone, Blocks.endStone);
	
	public enum dragonEgg = _.dragonEgg.index;
	public alias DragonEgg = PlaceableItem!(_.dragonEgg, Blocks.dragonEgg);
	
	public enum redstoneLamp = _.redstoneLamp.index;
	public alias RedstoneLamp = PlaceableItem!(_.redstoneLamp, Blocks.redstoneLamp);
	
	public enum oakWoodSlab = _.oakWoodSlab.index;
	
	public enum spruceWoodSlab = _.spruceWoodSlab.index;
	
	public enum birchWoodSlab = _.birchWoodSlab.index;
	
	public enum jungleWoodSlab = _.jungleWoodSlab.index;
	
	public enum acaciaWoodSlab = _.acaciaWoodSlab.index;
	
	public enum darkOakWoodSlab = _.darkOakWoodSlab.index;
	
	public enum sandstoneStairs = _.sandstoneStairs.index;
	
	public enum emeraldOre = _.emeraldOre.index;
	public alias EmeraldOre = PlaceableItem!(_.emeraldOre, Blocks.emeraldOre);
	
	public enum enderChest = _.enderChest.index;
	
	public enum tripwireHook = _.tripwireHook.index;
	
	public enum emeraldBlock = _.emeraldBlock.index;
	public alias EmeraldBlock = PlaceableItem!(_.emeraldBlock, Blocks.emeraldBlock);
	
	public enum spruceWoodStairs = _.spruceWoodStairs.index;
	
	public enum birchWoodStairs = _.birchWoodStairs.index;
	
	public enum jungleWoodStairs = _.jungleWoodStairs.index;
	
	public enum commandBlock = _.commandBlock.index;
	
	public enum beacon = _.beacon.index;
	public alias Beacon = PlaceableItem!(_.beacon, Blocks.beacon);
	
	public enum cobblestoneWall = _.cobblestoneWall.index;
	public alias CobblestoneWall = PlaceableItem!(_.cobblestoneWall, Blocks.cobblestoneWall);
	
	public enum mossyCobblestoneWall = _.mossyCobblestoneWall.index;
	public alias MossyCobblestoneWall = PlaceableItem!(_.mossyCobblestoneWall, Blocks.mossyCobblestoneWall);
	
	public enum woodenButton = _.woodenButton.index;
	
	public enum anvil = _.anvil.index;
	
	public enum trappedChest = _.trappedChest.index;
	
	public enum lightWeightedPressurePlate = _.lightWeightedPressurePlate.index;
	
	public enum heavyWeightedPressurePlate = _.heavyWeightedPressurePlate.index;
	
	public enum daylightSensor = _.daylightSensor.index;
	
	public enum redstoneBlock = _.redstoneBlock.index;
	public alias RedstoneBlock = PlaceableItem!(_.redstoneBlock, Blocks.redstoneBlock);
	
	public enum netherQuartzOre = _.netherQuartzOre.index;
	public alias NetherQuartzOre = PlaceableItem!(_.netherQuartzOre, Blocks.netherQuartzOre);
	
	public enum hopper = _.hopper.index;
	
	public enum quartzBlock = _.quartzBlock.index;
	public alias QuartzBlock = PlaceableItem!(_.quartzBlock, Blocks.quartzBlock);
	
	public enum chiseledQuartzBlock = _.chiseledQuartzBlock.index;
	public alias ChiseledQuartzBlock = PlaceableItem!(_.chiseledQuartzBlock, Blocks.chiseledQuartzBlock);
	
	public enum pillarQuartzBlock = _.pillarQuartzBlock.index;
	
	public enum quartzStairs = _.quartzStairs.index;
	
	public enum activatorRail = _.activatorRail.index;
	
	public enum dropper = _.dropper.index;
	
	public enum whiteStainedClay = _.whiteStainedClay.index;
	public alias WhiteStainedClay = PlaceableItem!(_.whiteStainedClay, Blocks.whiteStainedClay);
	
	public enum orangeStainedClay = _.orangeStainedClay.index;
	public alias OrangeStainedClay = PlaceableItem!(_.orangeStainedClay, Blocks.orangeStainedClay);
	
	public enum magentaStainedClay = _.magentaStainedClay.index;
	public alias MagentaStainedClay = PlaceableItem!(_.magentaStainedClay, Blocks.magentaStainedClay);
	
	public enum lightBlueStainedClay = _.lightBlueStainedClay.index;
	public alias LightBlueStainedClay = PlaceableItem!(_.lightBlueStainedClay, Blocks.lightBlueStainedClay);
	
	public enum yellowStainedClay = _.yellowStainedClay.index;
	public alias YellowStainedClay = PlaceableItem!(_.yellowStainedClay, Blocks.yellowStainedClay);
	
	public enum limeStainedClay = _.limeStainedClay.index;
	public alias LimeStainedClay = PlaceableItem!(_.limeStainedClay, Blocks.limeStainedClay);
	
	public enum pinkStainedClay = _.pinkStainedClay.index;
	public alias PinkStainedClay = PlaceableItem!(_.pinkStainedClay, Blocks.pinkStainedClay);
	
	public enum grayStainedClay = _.grayStainedClay.index;
	public alias GrayStainedClay = PlaceableItem!(_.grayStainedClay, Blocks.grayStainedClay);
	
	public enum lightGrayStainedClay = _.lightGrayStainedClay.index;
	public alias LightGrayStainedClay = PlaceableItem!(_.lightGrayStainedClay, Blocks.lightGrayStainedClay);
	
	public enum cyanStainedClay = _.cyanStainedClay.index;
	public alias CyanStainedClay = PlaceableItem!(_.cyanStainedClay, Blocks.cyanStainedClay);
	
	public enum purpleStainedClay = _.purpleStainedClay.index;
	public alias PurpleStainedClay = PlaceableItem!(_.purpleStainedClay, Blocks.purpleStainedClay);
	
	public enum blueStainedClay = _.blueStainedClay.index;
	public alias BlueStainedClay = PlaceableItem!(_.blueStainedClay, Blocks.blueStainedClay);
	
	public enum brownStainedClay = _.brownStainedClay.index;
	public alias BrownStainedClay = PlaceableItem!(_.brownStainedClay, Blocks.brownStainedClay);
	
	public enum greenStainedClay = _.greenStainedClay.index;
	public alias GreenStainedClay = PlaceableItem!(_.greenStainedClay, Blocks.greenStainedClay);
	
	public enum redStainedClay = _.redStainedClay.index;
	public alias RedStainedClay = PlaceableItem!(_.redStainedClay, Blocks.redStainedClay);
	
	public enum blackStainedClay = _.blackStainedClay.index;
	public alias BlackStainedClay = PlaceableItem!(_.blackStainedClay, Blocks.blackStainedClay);
	
	public enum stainedClay = [whiteStainedClay, orangeStainedClay, magentaStainedClay, lightBlueStainedClay, yellowStainedClay, limeStainedClay, pinkStainedClay, grayStainedClay, lightGrayStainedClay, cyanStainedClay, purpleStainedClay, blueStainedClay, brownStainedClay, greenStainedClay, redStainedClay, blackStainedClay];
	
	public enum whiteStainedGlassPane = _.whiteStainedGlassPane.index;
	public alias WhiteStainedGlassPane = PlaceableItem!(_.whiteStainedGlassPane, Blocks.whiteStainedGlassPane);
	
	public enum orangeStainedGlassPane = _.orangeStainedGlassPane.index;
	public alias OrangeStainedGlassPane = PlaceableItem!(_.orangeStainedGlassPane, Blocks.orangeStainedGlassPane);
	
	public enum magentaStainedGlassPane = _.magentaStainedGlassPane.index;
	public alias MagentaStainedGlassPane = PlaceableItem!(_.magentaStainedGlassPane, Blocks.magentaStainedGlassPane);
	
	public enum lightBlueStainedGlassPane = _.lightBlueStainedGlassPane.index;
	public alias LightBlueStainedGlassPane = PlaceableItem!(_.lightBlueStainedGlassPane, Blocks.lightBlueStainedGlassPane);
	
	public enum yellowStainedGlassPane = _.yellowStainedGlassPane.index;
	public alias YellowStainedGlassPane = PlaceableItem!(_.yellowStainedGlassPane, Blocks.yellowStainedGlassPane);
	
	public enum limeStainedGlassPane = _.limeStainedGlassPane.index;
	public alias LimeStainedGlassPane = PlaceableItem!(_.limeStainedGlassPane, Blocks.limeStainedGlassPane);
	
	public enum pinkStainedGlassPane = _.pinkStainedGlassPane.index;
	public alias PinkStainedGlassPane = PlaceableItem!(_.pinkStainedGlassPane, Blocks.pinkStainedGlassPane);
	
	public enum grayStainedGlassPane = _.grayStainedGlassPane.index;
	public alias GrayStainedGlassPane = PlaceableItem!(_.grayStainedGlassPane, Blocks.grayStainedGlassPane);
	
	public enum lightGrayStainedGlassPane = _.lightGrayStainedGlassPane.index;
	public alias LightGrayStainedGlassPane = PlaceableItem!(_.lightGrayStainedGlassPane, Blocks.lightGrayStainedGlassPane);
	
	public enum cyanStainedGlassPane = _.cyanStainedGlassPane.index;
	public alias CyanStainedGlassPane = PlaceableItem!(_.cyanStainedGlassPane, Blocks.cyanStainedGlassPane);
	
	public enum purpleStainedGlassPane = _.purpleStainedGlassPane.index;
	public alias PurpleStainedGlassPane = PlaceableItem!(_.purpleStainedGlassPane, Blocks.purpleStainedGlassPane);
	
	public enum blueStainedGlassPane = _.blueStainedGlassPane.index;
	public alias BlueStainedGlassPane = PlaceableItem!(_.blueStainedGlassPane, Blocks.blueStainedGlassPane);
	
	public enum brownStainedGlassPane = _.brownStainedGlassPane.index;
	public alias BrownStainedGlassPane = PlaceableItem!(_.brownStainedGlassPane, Blocks.brownStainedGlassPane);
	
	public enum greenStainedGlassPane = _.greenStainedGlassPane.index;
	public alias GreenStainedGlassPane = PlaceableItem!(_.greenStainedGlassPane, Blocks.greenStainedGlassPane);
	
	public enum redStainedGlassPane = _.redStainedGlassPane.index;
	public alias RedStainedGlassPane = PlaceableItem!(_.redStainedGlassPane, Blocks.redStainedGlassPane);
	
	public enum blackStainedGlassPane = _.blackStainedGlassPane.index;
	public alias BlackStainedGlassPane = PlaceableItem!(_.blackStainedGlassPane, Blocks.blackStainedGlassPane);
	
	public enum stainedGlassPane = [whiteStainedGlassPane, orangeStainedGlassPane, magentaStainedGlassPane, lightBlueStainedGlassPane, yellowStainedGlassPane, limeStainedGlassPane, pinkStainedGlassPane, grayStainedGlassPane, lightGrayStainedGlassPane, cyanStainedGlassPane, purpleStainedGlassPane, blueStainedGlassPane, brownStainedGlassPane, greenStainedGlassPane, redStainedGlassPane, blackStainedGlassPane];
	
	public enum acaciaWoodStairs = _.acaciaWoodStairs.index;
	
	public enum darkOakWoodStairs = _.darkOakWoodStairs.index;
	
	public enum slimeBlock = _.slimeBlock.index;
	public alias SlimeBlock = PlaceableItem!(_.slimeBlock, Blocks.slimeBlock);
	
	public enum barrier = _.barrier.index;
	public enum invisibleBedrock = barrier;
	public alias Barrier = PlaceableItem!(_.barrier, Blocks.barrier);
	public alias InvisibleBedrock = Barrier;
	
	public enum ironTrapdoor = _.ironTrapdoor.index;
	
	public enum prismarine = _.prismarine.index;
	public alias Prismarine = PlaceableItem!(_.prismarine, Blocks.prismarine);
	
	public enum prismarineBricks = _.prismarineBricks.index;
	public alias PrismarineBricks = PlaceableItem!(_.prismarineBricks, Blocks.prismarineBricks);
	
	public enum darkPrismarine = _.darkPrismarine.index;
	public alias DarkPrismarine = PlaceableItem!(_.darkPrismarine, Blocks.darkPrismarine);
	
	public enum seaLantern = _.seaLantern.index;
	public alias SeaLantern = PlaceableItem!(_.seaLantern, Blocks.seaLantern);
	
	public enum hayBale = _.hayBale.index;
	
	public enum whiteCarpet = _.whiteCarpet.index;
	public alias WhiteCarpet = PlaceableItem!(_.whiteCarpet, Blocks.whiteCarpet);
	
	public enum orangeCarpet = _.orangeCarpet.index;
	public alias OrangeCarpet = PlaceableItem!(_.orangeCarpet, Blocks.orangeCarpet);
	
	public enum magentaCarpet = _.magentaCarpet.index;
	public alias MagentaCarpet = PlaceableItem!(_.magentaCarpet, Blocks.magentaCarpet);
	
	public enum lightBlueCarpet = _.lightBlueCarpet.index;
	public alias LightBlueCarpet = PlaceableItem!(_.lightBlueCarpet, Blocks.lightBlueCarpet);
	
	public enum yellowCarpet = _.yellowCarpet.index;
	public alias YellowCarpet = PlaceableItem!(_.yellowCarpet, Blocks.yellowCarpet);
	
	public enum limeCarpet = _.limeCarpet.index;
	public alias LimeCarpet = PlaceableItem!(_.limeCarpet, Blocks.limeCarpet);
	
	public enum pinkCarpet = _.pinkCarpet.index;
	public alias PinkCarpet = PlaceableItem!(_.pinkCarpet, Blocks.pinkCarpet);
	
	public enum grayCarpet = _.grayCarpet.index;
	public alias GrayCarpet = PlaceableItem!(_.grayCarpet, Blocks.grayCarpet);
	
	public enum lightGrayCarpet = _.lightGrayCarpet.index;
	public alias LightGrayCarpet = PlaceableItem!(_.lightGrayCarpet, Blocks.lightGrayCarpet);
	
	public enum cyanCarpet = _.cyanCarpet.index;
	public alias CyanCarpet = PlaceableItem!(_.cyanCarpet, Blocks.cyanCarpet);
	
	public enum purpleCarpet = _.purpleCarpet.index;
	public alias PurpleCarpet = PlaceableItem!(_.purpleCarpet, Blocks.purpleCarpet);
	
	public enum blueCarpet = _.blueCarpet.index;
	public alias BlueCarpet = PlaceableItem!(_.blueCarpet, Blocks.blueCarpet);
	
	public enum brownCarpet = _.brownCarpet.index;
	public alias BrownCarpet = PlaceableItem!(_.brownCarpet, Blocks.brownCarpet);
	
	public enum greenCarpet = _.greenCarpet.index;
	public alias GreenCarpet = PlaceableItem!(_.greenCarpet, Blocks.greenCarpet);
	
	public enum redCarpet = _.redCarpet.index;
	public alias RedCarpet = PlaceableItem!(_.redCarpet, Blocks.redCarpet);
	
	public enum blackCarpet = _.blackCarpet.index;
	public alias BlackCarpet = PlaceableItem!(_.blackCarpet, Blocks.blackCarpet);
	
	public enum carpet = [whiteCarpet, orangeCarpet, magentaCarpet, lightBlueCarpet, yellowCarpet, limeCarpet, pinkCarpet, grayCarpet, lightGrayCarpet, cyanCarpet, purpleCarpet, blueCarpet, brownCarpet, greenCarpet, redCarpet, blackCarpet];
	
	public enum hardenedClay = _.hardenedClay.index;
	public alias HardenedClay = PlaceableItem!(_.hardenedClay, Blocks.hardenedClay);
	
	public enum coalBlock = _.coalBlock.index;
	public alias CoalBlock = PlaceableItem!(_.coalBlock, Blocks.coalBlock);
	
	public enum packedIce = _.packedIce.index;
	public alias PackedIce = PlaceableItem!(_.packedIce, Blocks.packedIce);
	
	public enum sunflower = _.sunflower.index;
	
	public enum liliac = _.liliac.index;
	
	public enum doubleTallgrass = _.doubleTallgrass.index;
	
	public enum largeFern = _.largeFern.index;
	
	public enum roseBush = _.roseBush.index;
	
	public enum peony = _.peony.index;
	
	public enum redSandstone = _.redSandstone.index;
	public alias RedSandstone = PlaceableItem!(_.redSandstone, Blocks.redSandstone);
	
	public enum chiseledRedSandstone = _.chiseledRedSandstone.index;
	public alias ChiseledRedSandstone = PlaceableItem!(_.chiseledRedSandstone, Blocks.chiseledRedSandstone);
	
	public enum smoothRedSandstone = _.smoothRedSandstone.index;
	public alias SmoothRedSandstone = PlaceableItem!(_.smoothRedSandstone, Blocks.smoothRedSandstone);
	
	public enum redSandstoneStairs = _.redSandstoneStairs.index;
	
	public enum redSandstoneSlab = _.redSandstoneSlab.index;
	
	public enum spruceFenceGate = _.spruceFenceGate.index;
	
	public enum birchFenceGate = _.birchFenceGate.index;
	
	public enum jungleFenceGate = _.jungleFenceGate.index;
	
	public enum acaciaFenceGate = _.acaciaFenceGate.index;
	
	public enum darkOakFenceGate = _.darkOakFenceGate.index;
	
	public enum endRod = _.endRod.index;
	
	public enum chorusPlant = _.chorusPlant.index;
	
	public enum chorusFlower = _.chorusFlower.index;
	
	public enum purpurBlock = _.purpurBlock.index;
	public alias PurpurBlock = PlaceableItem!(_.purpurBlock, Blocks.purpurBlock);
	
	public enum purpurPillar = _.purpurPillar.index;
	
	public enum purpurStairs = _.purpurStairs.index;
	
	public enum purpurSlab = _.purpurSlab.index;
	
	public enum endStoneBricks = _.endStoneBricks.index;
	public alias EndStoneBricks = PlaceableItem!(_.endStoneBricks, Blocks.endStoneBricks);
	
	public enum grassPath = _.grassPath.index;
	public alias GrassPath = PlaceableItem!(_.grassPath, Blocks.grassPath);
	
	public enum repeatingCommandBlock = _.repeatingCommandBlock.index;
	
	public enum chainCommandBlock = _.chainCommandBlock.index;
	
	public enum frostedIce = _.frostedIce.index;
	public alias FrostedIce = PlaceableItem!(_.frostedIce, Blocks.frostedIce0);
	
	public enum magmaBlock = _.magmaBlock.index;
	public alias MagmaBlock = PlaceableItem!(_.magmaBlock, Blocks.magmaBlock);
	
	public enum netherWartBlock = _.netherWartBlock.index;
	public alias NetherWartBlock = PlaceableItem!(_.netherWartBlock, Blocks.netherWartBlock);
	
	public enum redNetherBrick = _.redNetherBrick.index;
	public alias RedNetherBrick = PlaceableItem!(_.redNetherBrick, Blocks.redNetherBrick);
	
	public enum boneBlock = _.boneBlock.index;
	
	public enum structureVoid = _.structureVoid.index;
	public alias StructureVoid = PlaceableItem!(_.structureVoid, Blocks.structureVoid);
	
	public enum observer = _.observer.index;
	
	public enum whiteShulkerBox = _.whiteShulkerBox.index;
	public alias WhiteShulkerBox = PlaceableItem!(_.whiteShulkerBox, Blocks.whiteShulkerBox);
	
	public enum orangeShulkerBox = _.orangeShulkerBox.index;
	public alias OrangeShulkerBox = PlaceableItem!(_.orangeShulkerBox, Blocks.orangeShulkerBox);
	
	public enum magentaShulkerBox = _.magentaShulkerBox.index;
	public alias MagentaShulkerBox = PlaceableItem!(_.magentaShulkerBox, Blocks.magentaShulkerBox);
	
	public enum lightBlueShulkerBox = _.lightBlueShulkerBox.index;
	public alias LightBlueShulkerBox = PlaceableItem!(_.lightBlueShulkerBox, Blocks.lightBlueShulkerBox);
	
	public enum yellowShulkerBox = _.yellowShulkerBox.index;
	public alias YellowShulkerBox = PlaceableItem!(_.yellowShulkerBox, Blocks.yellowShulkerBox);
	
	public enum limeShulkerBox = _.limeShulkerBox.index;
	public alias LimeShulkerBox = PlaceableItem!(_.limeShulkerBox, Blocks.limeShulkerBox);
	
	public enum pinkShulkerBox = _.pinkShulkerBox.index;
	public alias PinkShulkerBox = PlaceableItem!(_.pinkShulkerBox, Blocks.pinkShulkerBox);
	
	public enum grayShulkerBox = _.grayShulkerBox.index;
	public alias GrayShulkerBox = PlaceableItem!(_.grayShulkerBox, Blocks.grayShulkerBox);
	
	public enum lightGrayShulkerBox = _.lightGrayShulkerBox.index;
	public alias LightGrayShulkerBox = PlaceableItem!(_.lightGrayShulkerBox, Blocks.lightGrayShulkerBox);
	
	public enum cyanShulkerBox = _.cyanShulkerBox.index;
	public alias CyanShulkerBox = PlaceableItem!(_.cyanShulkerBox, Blocks.cyanShulkerBox);
	
	public enum purpleShulkerBox = _.purpleShulkerBox.index;
	public alias PurpleShulkerBox = PlaceableItem!(_.purpleShulkerBox, Blocks.purpleShulkerBox);
	
	public enum blueShulkerBox = _.blueShulkerBox.index;
	public alias BlueShulkerBox = PlaceableItem!(_.blueShulkerBox, Blocks.blueShulkerBox);
	
	public enum brownShulkerBox = _.brownShulkerBox.index;
	public alias BrownShulkerBox = PlaceableItem!(_.brownShulkerBox, Blocks.brownShulkerBox);
	
	public enum greenShulkerBox = _.greenShulkerBox.index;
	public alias GreenShulkerBox = PlaceableItem!(_.greenShulkerBox, Blocks.greenShulkerBox);
	
	public enum redShulkerBox = _.redShulkerBox.index;
	public alias RedShulkerBox = PlaceableItem!(_.redShulkerBox, Blocks.redShulkerBox);
	
	public enum blackShulkerBox = _.blackShulkerBox.index;
	public alias BlackShulkerBox = PlaceableItem!(_.blackShulkerBox, Blocks.blackShulkerBox);
	
	public enum shulkerBox = [whiteShulkerBox, orangeShulkerBox, magentaShulkerBox, lightBlueShulkerBox, yellowShulkerBox, limeShulkerBox, pinkShulkerBox, grayShulkerBox, lightGrayShulkerBox, cyanShulkerBox, purpleShulkerBox, blueShulkerBox, brownShulkerBox, greenShulkerBox, redShulkerBox, blackShulkerBox];
	
	public enum stonecutter = _.stonecutter.index;
	public alias Stonecutter = PlaceableItem!(_.stonecutter, Blocks.stonecutter);
	
	public enum glowingObsidian = _.glowingObsidian.index;
	public alias GlowingObsidian = PlaceableItem!(_.glowingObsidian, Blocks.glowingObsidian);
	
	public enum netherReactorCore = _.netherReactorCore.index;
	public alias NetherReactorCore = PlaceableItem!(_.netherReactorCore, Blocks.netherReactorCore);
	
	public enum updateBlock = _.updateBlock.index;
	public alias UpdateBlock = PlaceableItem!(_.updateBlock, Blocks.updateBlock);
	
	public enum ateupdBlock = _.ateupdBlock.index;
	public alias AteupdBlock = PlaceableItem!(_.ateupdBlock, Blocks.ateupdBlock);
	
	public enum structureSave = _.structureSave.index;
	public alias StructureSave = PlaceableItem!(_.structureSave, Blocks.structureBlockSave);
	
	public enum structureLoad = _.structureLoad.index;
	public alias StructureLoad = PlaceableItem!(_.structureLoad, Blocks.structureBlockLoad);
	
	public enum structureCorner = _.structureCorner.index;
	public alias StructureCorner = PlaceableItem!(_.structureCorner, Blocks.structureBlockCorner);
	
	public enum structureData = _.structureData.index;
	public alias StructureData = PlaceableItem!(_.structureData, Blocks.structureBlockData);
	
	
	public enum ironShovel = _.ironShovel.index;
	public alias IronShovel = ShovelItem!(_.ironShovel, Tools.iron, Durability.iron, 4);
	
	public enum ironPickaxe = _.ironPickaxe.index;
	public alias IronPickaxe = PickaxeItem!(_.ironPickaxe, Tools.iron, Durability.iron, 5);
	
	public enum ironAxe = _.ironAxe.index;
	public alias IronAxe = AxeItem!(_.ironAxe, Tools.iron, Durability.iron, 6);
	
	public enum flintAndSteel = _.flintAndSteel.index;
	
	public enum apple = _.apple.index;
	public alias Apple = FoodItem!(_.apple, 4, 2.4);
	
	public enum bow = _.bow.index;
	
	public enum arrow = _.arrow.index;
	public alias Arrow = SimpleItem!(_.arrow);
	
	public enum coal = _.coal.index;
	public alias Coal = SimpleItem!(_.coal);
	
	public enum charcoal = _.charcoal.index;
	public alias Charcoal = SimpleItem!(_.charcoal);
	
	public enum diamond = _.diamond.index;
	public alias Diamond = SimpleItem!(_.diamond);
	
	public enum ironIngot = _.ironIngot.index;
	public alias IronIngot = SimpleItem!(_.ironIngot);
	
	public enum goldIngot = _.goldIngot.index;
	public alias GoldIngot = SimpleItem!(_.goldIngot);
	
	public enum ironSword = _.ironSword.index;
	public alias IronSword = SwordItem!(_.ironSword, Tools.iron, Durability.iron, 7);
	
	public enum woodenSword = _.woodenSword.index;
	public alias WoodenSword = SwordItem!(_.woodenSword, Tools.wood, Durability.wood, 5);
	
	public enum woodenShovel = _.woodenShovel.index;
	public alias WoodenShovel = ShovelItem!(_.woodenShovel, Tools.wood, Durability.wood, 2);
	
	public enum woodenPickaxe = _.woodenPickaxe.index;
	public alias WoodenPickaxe = PickaxeItem!(_.woodenPickaxe, Tools.wood, Durability.wood, 3);
	
	public enum woodenAxe = _.woodenAxe.index;
	public alias WoodenAxe = AxeItem!(_.woodenAxe, Tools.wood, Durability.wood, 4);
	
	public enum stoneSword = _.stoneSword.index;
	public alias StoneSword = SwordItem!(_.stoneSword, Tools.stone, Durability.stone, 6);
	
	public enum stoneShovel = _.stoneShovel.index;
	public alias StoneShovel = ShovelItem!(_.stoneShovel, Tools.stone, Durability.stone, 3);
	
	public enum stonePickaxe = _.stonePickaxe.index;
	public alias StonePickaxe = PickaxeItem!(_.stonePickaxe, Tools.stone, Durability.stone, 4);
	
	public enum stoneAxe = _.stoneAxe.index;
	public alias StoneAxe = AxeItem!(_.stoneAxe, Tools.stone, Durability.stone, 5);
	
	public enum diamondSword = _.diamondSword.index;
	public alias DiamondSword = SwordItem!(_.diamondSword, Tools.diamond, Durability.diamond, 8);
	
	public enum diamondShovel = _.diamondShovel.index;
	public alias DiamondShovel = ShovelItem!(_.diamondShovel, Tools.diamond, Durability.diamond, 5);
	
	public enum diamondPickaxe = _.diamondPickaxe.index;
	public alias DiamondPickaxe = PickaxeItem!(_.diamondPickaxe, Tools.diamond, Durability.diamond, 6);
	
	public enum diamondAxe = _.diamondAxe.index;
	public alias DiamondAxe = AxeItem!(_.diamondAxe, Tools.diamond, Durability.diamond, 7);
	
	public enum stick = _.stick.index;
	public alias Stick = SimpleItem!(_.stick);
	
	public enum bowl = _.bowl.index;
	public alias Bowl = SimpleItem!(_.bowl);
	
	public enum mushroomStew = _.mushroomStew.index;
	public alias MushroomStew = SoupItem!(_.mushroomStew, 6, 7.2);
	
	public enum goldenSword = _.goldenSword.index;
	public alias GoldenSword = SwordItem!(_.goldenSword, Tools.gold, Durability.gold, 5);
	
	public enum goldenShovel = _.goldenShovel.index;
	public alias GoldenShovel = ShovelItem!(_.goldenShovel, Tools.gold, Durability.gold, 2);
	
	public enum goldenPickaxe = _.goldenPickaxe.index;
	public alias GoldenPickaxe = PickaxeItem!(_.goldenPickaxe, Tools.gold, Durability.gold, 3);
	
	public enum goldenAxe = _.goldenAxe.index;
	public alias GoldenAxe = AxeItem!(_.goldenAxe, Tools.gold, Durability.gold, 4);
	
	public enum stringItem = _.string.index;
	
	public enum feather = _.feather.index;
	public alias Feather = SimpleItem!(_.feather);
	
	public enum gunpowder = _.gunpowder.index;
	public alias Gunpowder = SimpleItem!(_.gunpowder);
	
	public enum woodenHoe = _.woodenHoe.index;
	public alias WoodenHoe = HoeItem!(_.woodenHoe, Tools.wood, Durability.wood);
	
	public enum stoneHoe = _.stoneHoe.index;
	public alias StoneHoe = HoeItem!(_.stoneHoe, Tools.stone, Durability.stone);
	
	public enum ironHoe = _.ironHoe.index;
	public alias IronHoe = HoeItem!(_.ironHoe, Tools.iron, Durability.iron);
	
	public enum diamondHoe = _.diamondHoe.index;
	public alias DiamondHoe = HoeItem!(_.diamondHoe, Tools.diamond, Durability.diamond);
	
	public enum goldenHoe = _.goldenHoe.index;
	public alias GoldenHoe = HoeItem!(_.goldenHoe, Tools.gold, Durability.gold);
	
	public enum seeds = _.seeds.index;
	public alias Seeds = PlaceableItem!(_.seeds, Blocks.seeds0, Blocks.farmland);
	
	public enum wheat = _.wheat.index;
	public alias Wheat = SimpleItem!(_.wheat);
	
	public enum bread = _.bread.index;
	public alias Bread = FoodItem!(_.bread, 5, 6);
	
	public enum leatherCap = _.leatherCap.index;
	public alias LeatherCap = ColorableArmorItem!(_.leatherCap, 56, Armor.cap, 1);
	
	public enum leatherTunic = _.leatherTunic.index;
	public alias LeatherTunic = ColorableArmorItem!(_.leatherTunic, 81, Armor.tunic, 3);
	
	public enum leatherPants = _.leatherPants.index;
	public alias LeatherPants = ColorableArmorItem!(_.leatherPants, 76, Armor.pants, 2);
	
	public enum leatherBoots = _.leatherBoots.index;
	public alias LeatherBoots = ColorableArmorItem!(_.leatherBoots, 66, Armor.boots, 1);
	
	public enum chainHelmet = _.chainHelmet.index;
	public alias ChainHelmet = ArmorItem!(_.chainHelmet, 166, Armor.helmet, 2);
	
	public enum chainChestplate = _.chainChestplate.index;
	public alias ChainChestplate = ArmorItem!(_.chainChestplate, 241, Armor.chestplate, 5);
	
	public enum chainLeggings = _.chainLeggings.index;
	public alias ChainLeggings = ArmorItem!(_.chainLeggings, 226, Armor.leggings, 4);
	
	public enum chainBoots = _.chainBoots.index;
	public alias ChainBoots = ArmorItem!(_.chainBoots, 196, Armor.boots, 1);
	
	public enum ironHelmet = _.ironHelmet.index;
	public alias IronHelmet = ArmorItem!(_.ironHelmet, 166, Armor.helmet, 2);
	
	public enum ironChestplate = _.ironChestplate.index;
	public alias IronChestplate = ArmorItem!(_.ironChestplate, 241, Armor.chestplate, 6);
	
	public enum ironLeggings = _.ironLeggings.index;
	public alias IronLeggings = ArmorItem!(_.ironLeggings, 226, Armor.leggings, 5);
	
	public enum ironBoots = _.ironBoots.index;
	public alias IronBoots = ArmorItem!(_.ironBoots, 196, Armor.boots, 2);
	
	public enum diamondHelmet = _.diamondHelmet.index;
	public alias DiamondHelmet = ArmorItem!(_.diamondHelmet, 364, Armor.helmet, 3);
	
	public enum diamondChestplate = _.diamondChestplate.index;
	public alias DiamondChestplate = ArmorItem!(_.diamondChestplate, 529, Armor.chestplate, 8);
	
	public enum diamondLeggings = _.diamondLeggings.index;
	public alias DiamondLeggings = ArmorItem!(_.diamondLeggings, 496, Armor.leggings, 6);
	
	public enum diamondBoots = _.diamondBoots.index;
	public alias DiamondBoots = ArmorItem!(_.diamondBoots, 430, Armor.boots, 3);
	
	public enum goldenHelmet = _.goldenHelmet.index;
	public alias GoldenHelmet = ArmorItem!(_.goldenHelmet, 78, Armor.helmet, 2);
	
	public enum goldenChestplate = _.goldenChestplate.index;
	public alias GoldenChestplate = ArmorItem!(_.goldenChestplate, 113, Armor.chestplate, 5);
	
	public enum goldenLeggings = _.goldenLeggings.index;
	public alias GoldenLeggings = ArmorItem!(_.goldenLeggings, 106, Armor.leggings, 3);
	
	public enum goldenBoots = _.goldenBoots.index;
	public alias GoldenBoots = ArmorItem!(_.goldenBoots, 92, Armor.boots, 1);
	
	public enum flint = _.flint.index;
	public alias Flint = SimpleItem!(_.flint);
	
	public enum rawPorkchop = _.rawPorkchop.index;
	public alias RawPorkchop = FoodItem!(_.rawPorkchop, 3, 1.8);
	
	public enum cookedPorkchop = _.cookedPorkchop.index;
	public alias CookedPorkchop = FoodItem!(_.cookedPorkchop, 8, 12.8);
	
	public enum painting = _.painting.index;
	
	public enum goldenApple = _.goldenApple.index;
	public alias GoldenApple = FoodItem!(_.goldenApple, 4, 9.6, [effectInfo(Effects.regeneration, 5, "II"), effectInfo(Effects.absorption, 120, "I")]);
	
	public enum enchantedGoldenApple = _.enchantedGoldenApple.index;
	public alias EnchantedGoldenApple = FoodItem!(_.enchantedGoldenApple, 4, 9.6, [effectInfo(Effects.regeneration, 20, "II"), effectInfo(Effects.absorption, 120, "IV"), effectInfo(Effects.resistance, 300, "I"), effectInfo(Effects.fireResistance, 300, "I")]);
	
	public enum sign = _.sign.index;
	
	public enum oakDoor = _.oakDoor.index;
	
	public enum bucket = _.bucket.index;
	
	public enum waterBucket = _.waterBucket.index;
	
	public enum lavaBucket = _.lavaBucket.index;
	
	public enum minecart = _.minecart.index;
	
	public enum saddle = _.saddle.index;
	
	public enum ironDoor = _.ironDoor.index;
	
	public enum redstoneDust = _.redstoneDust.index;
	
	public enum snowball = _.snowball.index;
	
	public enum oakBoat = _.oakBoat.index;
	
	public enum leather = _.leather.index;
	public alias Leather = SimpleItem!(_.leather);
	
	public enum milkBucket = _.milkBucket.index;
	public alias MilkBucket = ClearEffectsItem!(_.milkBucket, bucket);
	
	public enum brick = _.brick.index;
	public alias Brick = SimpleItem!(_.brick);
	
	public enum clay = _.clay.index;
	public alias Clay = SimpleItem!(_.clay);
	
	public enum sugarCanes = _.sugarCanes.index;
	
	public enum paper = _.paper.index;
	public alias Paper = SimpleItem!(_.paper);
	
	public enum book = _.book.index;
	public alias Book = SimpleItem!(_.book);
	
	public enum slimeball = _.slimeball.index;
	public alias Slimeball = SimpleItem!(_.slimeball);
	
	public enum minecartWithChest = _.minecartWithChest.index;
	
	public enum minecartWithFurnace = _.minecartWithFurnace.index;
	
	public enum egg = _.egg.index;
	
	public enum compass = _.compass.index;
	public alias Compass = SimpleItem!(_.compass);
	
	public enum fishingRod = _.fishingRod.index;
	
	public enum clock = _.clock.index;
	public alias Clock = SimpleItem!(_.clock);
	
	public enum glowstoneDust = _.glowstoneDust.index;
	public alias GlowstoneDust = SimpleItem!(_.glowstoneDust);
	
	public enum rawFish = _.rawFish.index;
	public alias RawFish = FoodItem!(_.rawFish, 2, .4);
	
	public enum rawSalmon = _.rawSalmon.index;
	public alias RawSalmon = FoodItem!(_.rawSalmon, 2, .4);
	
	public enum clownfish = _.clownfish.index;
	public alias Clowfish = FoodItem!(_.clownfish, 1, .2);
	
	public enum pufferfish = _.pufferfish.index;
	public alias Pufferfish = FoodItem!(_.pufferfish, 1, .2, [effectInfo(Effects.hunger, 15, "III"), effectInfo(Effects.poison, 60, "IV"), effectInfo(Effects.nausea, 15, "II")]);
	
	public enum cookedFish = _.cookedFish.index;
	public alias CookedFish = FoodItem!(_.cookedFish, 5, 6);
	
	public enum cookedSalmon = _.cookedSalmon.index;
	public alias CookedSalmon = FoodItem!(_.cookedSalmon, 6, 9.6);
	
	public enum inkSac = _.inkSac.index;
	public alias InkSac = SimpleItem!(_.inkSac);
	
	public enum roseRed = _.roseRed.index;
	public alias RoseRed = SimpleItem!(_.roseRed);
	
	public enum cactusGreen = _.cactusGreen.index;
	public alias CactusGreen = SimpleItem!(_.cactusGreen);
	
	public enum cocoaBeans = _.cocoaBeans.index;
	public alias CocoaBeans = BeansItem!(_.cocoaBeans, [Blocks.cocoaNorth0, Blocks.cocoaEast0, Blocks.cocoaSouth0, Blocks.cocoaWest0]);
	
	public enum lapisLazuli = _.lapisLazuli.index;
	public alias LapisLazuli = SimpleItem!(_.lapisLazuli);
	
	public enum purpleDye = _.purpleDye.index;
	public alias PurpleDye = SimpleItem!(_.purpleDye);
	
	public enum cyanDye = _.cyanDye.index;
	public alias CyanDye = SimpleItem!(_.cyanDye);
	
	public enum lightGrayDye = _.lightGrayDye.index;
	public alias LightGrayDye = SimpleItem!(_.lightGrayDye);
	
	public enum grayDye = _.grayDye.index;
	public alias GrayDye = SimpleItem!(_.grayDye);
	
	public enum pinkDye = _.pinkDye.index;
	public alias PinkDye = SimpleItem!(_.pinkDye);
	
	public enum limeDye = _.limeDye.index;
	public alias LimeDye = SimpleItem!(_.limeDye);
	
	public enum dandelionYellow = _.dandelionYellow.index;
	public alias DandelionYellow = SimpleItem!(_.dandelionYellow);
	
	public enum lightBlueDye = _.lightBlueDye.index;
	public alias LightBlueDye = SimpleItem!(_.lightBlueDye);
	
	public enum magentaDye = _.magentaDye.index;
	public alias MagentaDye = SimpleItem!(_.magentaDye);
	
	public enum orangeDye = _.orangeDye.index;
	public alias OrangeDye = SimpleItem!(_.orangeDye);
	
	public enum boneMeal = _.boneMeal.index;
	
	public enum bone = _.bone.index;
	public alias Bone = SimpleItem!(_.bone);
	
	public enum sugar = _.sugar.index;
	public alias Sugar = SimpleItem!(_.sugar);
	
	public enum cake = _.cake.index;
	public alias Cake = PlaceableItem!(_.cake, Blocks.cake0);
	
	//TODO beds
	
	public enum redstoneRepeater = _.redstoneRepeater.index;
	
	public enum cookie = _.cookie.index;
	public alias Cookie = FoodItem!(_.cookie, 2, .4);
	
	public enum map = _.map.index;
	public alias Map = MapItem!(_.map);
	
	public enum shears = _.shears.index;
	
	public enum melon = _.melon.index;
	public alias Melon = FoodItem!(_.melon, 2, 1.2);
	
	public enum pumpkinSeeds = _.pumpkinSeeds.index;
	public alias PumpkinSeeds = PlaceableItem!(_.pumpkinSeeds, Blocks.pumpkinStem0, Blocks.farmland);
	
	public enum melonSeeds = _.melonSeeds.index;
	public alias MelonSeeds = PlaceableItem!(_.melonSeeds, Blocks.melonStem0, Blocks.farmland);
	
	public enum rawBeef = _.rawBeef.index;
	public alias RawBeef = FoodItem!(_.rawBeef, 3, 1.8);
	
	public enum steak = _.steak.index;
	public alias Steak = FoodItem!(_.steak, 8, 12.8);
	
	public enum rawChicken = _.rawChicken.index;
	public alias RawChicken = FoodItem!(_.rawChicken, 2, 1.2);
	
	public enum cookedChicken = _.cookedChicken.index;
	public alias CookedChicked = FoodItem!(_.cookedChicken, 6, 7.2);
	
	public enum rottenFlesh = _.rottenFlesh.index;
	public alias RottenFlesh = FoodItem!(_.rottenFlesh, 4, .8, [effectInfo(Effects.hunger, 30, "I", .8)]);
	
	public enum enderPearl = _.enderPearl.index;
	
	public enum blazeRod = _.blazeRod.index;
	public alias BlazeRod = SimpleItem!(_.blazeRod);
	
	public enum ghastTear = _.ghastTear.index;
	public alias GhastTear = SimpleItem!(_.ghastTear);
	
	public enum goldNugget = _.goldNugget.index;
	public alias GoldNugget = SimpleItem!(_.goldNugget);
	
	public enum netherWart = _.netherWart.index;
	public alias NetherWart = PlaceableItem!(_.netherWart, Blocks.netherWart0, [Blocks.soulSand]);
	
	public enum potion = _.potion.index;
	
	public enum glassBottle = _.glassBottle.index;
	
	public enum spiderEye = _.spiderEye.index;
	public alias SpiderEye = SimpleItem!(_.spiderEye);
	
	public enum fermentedSpiderEye = _.fermentedSpiderEye.index;
	public alias FermentedSpiderEye = SimpleItem!(_.fermentedSpiderEye);
	
	public enum blazePowder = _.blazePowder.index;
	public alias BlazePowder = SimpleItem!(_.blazePowder);
	
	public enum magmaCream = _.magmaCream.index;
	public alias MagmaCream = SimpleItem!(_.magmaCream);
	
	public enum brewingStand = _.brewingStand.index;
	public alias BrewingStand = PlaceableItem!(_.brewingStand, Blocks.brewingStandEmpty);
	
	public enum cauldron = _.cauldron.index;
	public alias Cauldron = PlaceableItem!(_.cauldron, Blocks.cauldronEmpty);
	
	public enum eyeOfEnder = _.eyeOfEnder.index;
	
	public enum glisteringMelon = _.glisteringMelon.index;
	public alias GlisteringMelon = SimpleItem!(_.glisteringMelon);
	
	//TODO spawn eggs
	
	public enum bottleOEnchanting = _.bottleOEnchanting.index;
	
	public enum fireCharge = _.fireCharge.index;
	
	public enum bookAndQuill = _.bookAndQuill.index;
	
	public enum writtenBook = _.writtenBook.index;
	
	public enum emerald = _.emerald.index;
	public alias Emerald = SimpleItem!(_.emerald);
	
	public enum itemFrame = _.itemFrame.index;
	
	public enum flowerPot = _.flowerPot.index;
	public alias FlowerPot = PlaceableOnSolidItem!(_.flowerPot, Blocks.flowerPot);
	
	public enum carrot = _.carrot.index;
	public alias Carrot = CropFoodItem!(_.carrot, 3, 4.8, Blocks.carrot0);
	
	public enum potato = _.potato.index;
	public alias Potato = CropFoodItem!(_.potato, 1, .6, Blocks.potato0);
	
	public enum bakedPotato = _.bakedPotato.index;
	public alias BakedPotato = FoodItem!(_.bakedPotato, 5, 7.2);
	
	public enum poisonousPotato = _.poisonousPotato.index;
	public alias PoisonousPotato = FoodItem!(_.poisonousPotato, 2, 1.2, [effectInfo(Effects.poison, 4, "I", .6)]);
	
	public enum emptyMap = _.emptyMap.index;
	
	public enum goldenCarrot = _.goldenCarrot.index;
	public alias GoldenCarrot = FoodItem!(_.goldenCarrot, 6, 14.4);
	
	public enum skeletonSkull = _.skeletonSkull.index;
	
	public enum witherSkeletonSkull = _.witherSkeletonSkull.index;
	
	public enum zombieHead = _.zombieHead.index;
	
	public enum humanHead = _.humanHead.index;
	
	public enum creeperHead = _.creeperHead.index;
	
	public enum dragonHead = _.dragonHead.index;
	
	public enum carrotOnAStick = _.carrotOnAStick.index;
	
	public enum netherStar = _.netherStar.index;
	public alias NetherStar = SimpleItem!(_.netherStar);
	
	public enum pumpkinPie = _.pumpkinPie.index;
	public alias PumpkinPie = FoodItem!(_.pumpkinPie, 8, 4.8);
	
	public enum fireworkRocket = _.fireworkRocket.index;
	
	public enum fireworkStar = _.fireworkStar.index;
	
	public enum enchantedBook = _.enchantedBook.index;
	
	public enum redstoneComparator = _.redstoneComparator.index;
	
	public enum netherBrick = _.netherBrick.index;
	public alias NetherBrick = SimpleItem!(_.netherBrick);
	
	public enum netherQuartz = _.netherQuartz.index;
	public alias NetherQuartz = SimpleItem!(_.netherQuartz);
	
	public enum minecartWithTnt = _.minecartWithTnt.index;
	
	public enum minecartWithHopper = _.minecartWithHopper.index;
	
	public enum prismarineShard = _.prismarineShard.index;
	public alias PrismarineShard = SimpleItem!(_.prismarineShard);
	
	public enum prismarineCrystals = _.prismarineCrystals.index;
	public alias PrismarineCrystals = SimpleItem!(_.prismarineCrystals);
	
	public enum rawRabbit = _.rawRabbit.index;
	public alias RawRabbit = FoodItem!(_.rawRabbit, 3, 1.8);
	
	public enum cookedRabbit = _.cookedRabbit.index;
	public alias CookedRabbit = FoodItem!(_.cookedRabbit, 5, 6);
	
	public enum rabbitStew = _.rabbitStew.index;
	public alias RabbitStew = SoupItem!(_.rabbitStew, 10, 12);
	
	public enum rabbitFoot = _.rabbitFoot.index;
	public alias RabbitFoot = SimpleItem!(_.rabbitFoot);
	
	public enum rabbitHide = _.rabbitHide.index;
	public alias RabbitHide = SimpleItem!(_.rabbitHide);
	
	public enum armorStand = _.armorStand.index;
	
	public enum leatherHorseArmor = _.leatherHorseArmor.index;
	
	public enum ironHorseArmor = _.ironHorseArmor.index;
	
	public enum goldenHorseArmor = _.goldenHorseArmor.index;
	
	public enum diamondHorseArmor = _.diamondHorseArmor.index;
	
	public enum lead = _.lead.index;
	
	public enum nameTag = _.nameTag.index;
	
	public enum minecartWithCommandBlock = _.minecartWithCommandBlock.index;
	
	public enum rawMutton = _.rawMutton.index;
	public alias RawMutton = FoodItem!(_.rawMutton, 2, 1.2);
	
	public enum cookedMutton = _.cookedMutton.index;
	public alias CookedMutton = FoodItem!(_.cookedMutton, 6, 9.6);
	
	public enum banner = _.banner.index;
	
	public enum endCrystal = _.endCrystal.index;
	
	public enum spruceDoor = _.spruceDoor.index;
	
	public enum birchDoor = _.birchDoor.index;
	
	public enum jungleDoor = _.jungleDoor.index;
	
	public enum acaciaDoor = _.acaciaDoor.index;
	
	public enum darkOakDoor = _.darkOakDoor.index;
	
	public enum chorusFruit = _.chorusFruit.index;
	public alias ChorusFruit = TeleportationItem!(_.chorusFruit, 4, 2.4);
	
	public enum poppedChorusFruit = _.poppedChorusFruit.index;
	public alias PoppedChorusFruit = SimpleItem!(_.poppedChorusFruit);
	
	public enum beetroot = _.beetroot.index;
	public alias Beetroot = FoodItem!(_.beetroot, 1, 1.2);
	
	public enum beetrootSeeds = _.beetrootSeeds.index;
	public alias BeetrootSeeds = PlaceableItem!(_.beetrootSeeds, Blocks.beetroot0, Blocks.farmland);
	
	public enum beetrootSoup = _.beetrootSoup.index;
	public alias BeetrootSoup = SoupItem!(_.beetrootSoup, 6, 7.2);
	
	public enum dragonsBreath = _.dragonsBreath.index;
	
	public enum splashPotion = _.splashPotion.index;
	
	public enum spectralArrow = _.spectralArrow.index;
	
	public enum tippedArrow = _.tippedArrow.index;
	
	public enum lingeringPotion = _.lingeringPotion.index;
	
	public enum shield = _.shield.index;
	
	public enum elytra = _.elytra.index;
	
	public enum spruceBoat = _.spruceBoat.index;
	
	public enum birchBoat = _.birchBoat.index;
	
	public enum jungleBoat = _.jungleBoat.index;
	
	public enum acaciaBoat = _.acaciaBoat.index;
	
	public enum darkOakBoat = _.darkOakBoat.index;
	
	public enum undyingTotem = _.undyingTotem.index;
	
	public enum shulkerShell = _.shulkerShell.index;
	public alias ShulkerShell = SimpleItem!(_.shulkerShell);
	
	public enum ironNugget = _.ironNugget.index;
	public alias IronNugget = SimpleItem!(_.ironNugget);
	
	//TODO discs
	
}
