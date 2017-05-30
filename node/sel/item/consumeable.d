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
module sel.item.consumeable;

import sel.about : block_t, item_t;
import sel.util.util : roman;
import sel.block.block : compareBlock, blockInto;
import sel.block.blocks : Blocks;
import sel.effect;
import sel.item.item : Item, SimpleItem;
import sel.item.items : Items;
import sel.math.vector;
import sel.player.player : Player;
import sel.tuple : Tuple;
import sel.world.world : World;

static import sul.effects;
static import sul.items;

enum Residue {

	substract,
	bowl,
	bottle

}

alias EffectInfo = Tuple!(sul.effects.Effect, "effect", uint, "duration", ubyte, "level", float, "probability");

public EffectInfo effectInfo(sul.effects.Effect effect, uint duration, string level, float prob=1) {
	return EffectInfo(effect, duration, (level.roman - 1) & 255, prob);
}

enum Potions : EffectInfo {
	
	// extended = duration extended
	// plus = level 1 (default is 0)
	
	nightVision = effectInfo(Effects.nightVision, 180, "I"),
	nightVisionExtended = effectInfo(Effects.nightVision, 480, "I"),
	invisibility = effectInfo(Effects.invisibility, 180, "I"),
	invisibilityExtended = effectInfo(Effects.invisibility, 480, "I"),
	leaping = effectInfo(Effects.jumpBoost, 180, "I"),
	leapingExtended = effectInfo(Effects.jumpBoost, 480, "I"),
	leapingPlus = effectInfo(Effects.jumpBoost, 90, "II"),
	fireResistance = effectInfo(Effects.fireResistance, 180, "I"),
	fireResistanceExtended = effectInfo(Effects.fireResistance, 480, "I"),
	swiftness = effectInfo(Effects.speed, 180, "I"),
	swiftnessExtended = effectInfo(Effects.speed, 480, "I"),
	swiftnessPlus = effectInfo(Effects.speed, 90, "II"),
	slowness = effectInfo(Effects.slowness, 60, "I"),
	slownessExtended = effectInfo(Effects.slowness, 240, "I"),
	waterBreathing = effectInfo(Effects.waterBreathing, 180, "I"),
	waterBreathingExtended = effectInfo(Effects.waterBreathing, 480, "I"),
	healing = effectInfo(Effects.instantHealth, 0, "I"),
	healingPlus = effectInfo(Effects.instantHealth, 0, "II"),
	harming = effectInfo(Effects.instantDamage, 0, "I"),
	harmingPlus = effectInfo(Effects.instantDamage, 0, "II"),
	poison = effectInfo(Effects.poison, 45, "I"),
	poisonExtended = effectInfo(Effects.poison, 120, "I"),
	poisonPlus = effectInfo(Effects.poison, 22, "II"),
	regeneration = effectInfo(Effects.regeneration, 45, "I"),
	regenerationExtended = effectInfo(Effects.regeneration, 120, "I"),
	regenerationPlus = effectInfo(Effects.regeneration, 22, "II"),
	strength = effectInfo(Effects.strength, 180, "I"),
	strengthExtended = effectInfo(Effects.strength, 480, "I"),
	strengthPlus = effectInfo(Effects.strength, 90, "II"),
	weakness = effectInfo(Effects.weakness, 90, "I"),
	weaknessExtended = effectInfo(Effects.weakness, 240, "I"),
	decay = effectInfo(Effects.wither, 40, "II"),
	
}

class ConsumeableItem(sul.items.Item si, EffectInfo[] effects, Residue residue=Residue.substract) : SimpleItem!(si) {
	
	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public final override pure nothrow @property @safe @nogc bool consumeable() {
		return true;
	}
	
	public override Item onConsumed(Player player) {
		static if(effects.length) {
			foreach(EffectInfo effect ; effects) {
				if(effect.probability >= 1 || player.world.random.probability(effect.probability)) {
					player.addEffect(effect.effect, effect.level, effect.duration);
				}
			}
		}
		static if(residue == Residue.substract) return null;
		else static if(residue == Residue.bottle) return player.world.items.get(Items.glassBottle);
		else return player.world.items.get(Items.bowl);
	}
	
	alias slot this;
	
}

class FoodItem(sul.items.Item si, uint ghunger, float gsaturation, EffectInfo[] effects=[], Residue residue=Residue.substract) : ConsumeableItem!(si, effects, residue) {
	
	alias sul = si;
	
	public @safe this(E...)(E args) {
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

alias SoupItem(sul.items.Item si, uint ghunger, float gsaturation) = FoodItem!(si, ghunger, gsaturation, [], Residue.bowl);

class CropFoodItem(sul.items.Item si, uint ghunger, float gsaturation, block_t block) : FoodItem!(si, ghunger, gsaturation) {

	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override pure nothrow @property @safe @nogc bool placeable() {
		return true;
	}
	
	public override block_t place(World world, BlockPosition position, uint face) {
		if(compareBlock!(Blocks.farmland)(world[position - [0, 1, 0]])) return block;
		else return Blocks.air;
	}
	
	alias slot this;

}

class TeleportationItem(sul.items.Item si, uint ghunger, float gsaturation) : FoodItem!(si, ghunger, gsaturation) {

	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public override Item onConsumed(Player player) {
		@property int rand() {
			return player.world.random.range(-8, 8);
		}
		auto center = BlockPosition(player.position.x.blockInto, player.position.y.blockInto, player.position.z.blockInto);
		foreach(i ; 0..16) {
			auto position = center + [rand, rand, rand];
			if(!player.world[position].hasBoundingBox && !player.world[position + [0, 1, 0]].hasBoundingBox) {
				player.teleport(cast(EntityPosition)position + [.5, 0, .5]);
				break;
			}
		}
		return super.onConsumed(player);
	}
	
	alias slot this;

}

alias PotionItem(sul.items.Item si) = ConsumeableItem!(si, [], Residue.bottle);

alias PotionItem(sul.items.Item si, EffectInfo effect) = ConsumeableItem!(si, [effect], Residue.bottle);

class ClearEffectsItem(sul.items.Item si, item_t residue) : SimpleItem!(si) {
	
	alias sul = si;
	
	public @safe this(E...)(E args) {
		super(args);
	}
	
	public final override pure nothrow @property @safe @nogc bool consumeable() {
		return true;
	}

	public override Item onConsumed(Player player) {
		player.clearEffects();
		return player.world.items.get(residue);
	}
	
	alias slot this;
	
}
