/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/item/consumeable.d, selery/item/consumeable.d)
 */
module selery.item.consumeable;

import std.random : uniform, uniform01;

import selery.about : block_t, item_t;
import selery.block.block : compareBlock, blockInto;
import selery.block.blocks : Blocks;
import selery.effect;
import selery.item.item : Item, SimpleItem;
import selery.item.items : Items;
import selery.math.vector;
import selery.player.player : Player;
import selery.util.tuple : Tuple;
import selery.util.util : roman;
import selery.world.world : World;

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
				if(effect.probability >= 1 || uniform01!float(player.world.random) >= effect.probability) {
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
			return uniform!"[]"(-8, 8, player.world.random);
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
