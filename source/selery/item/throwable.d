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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/item/throwable.d, selery/item/throwable.d)
 */
module selery.item.throwable;
/*
import selery.entity.projectile : Projectile, EntitySnowball = Snowball, EntityEgg = Egg, EntityEnderpearl = Enderpearl, EntityPotion = Potion;
import selery.item.consumeable : Potions;
import selery.item.item : Item, Items, register;
import selery.player : Player;

abstract class ThrowableItem(T:Projectile, E...) : Item {

	private E args;

	public this(ushort id, ushort damage, ubyte max, E args) {
		super(id, damage, -1, max);
		this.args = args;
	}

	public override bool onThrowed(Player thrower) {
		thrower.world.spawn!T(thrower, args);
		return true;
	}

}

class Snowball : ThrowableItem!EntitySnowball {

	public this() {
		super(Items.SNOWBALL, 0, 64);
	}

}

class Egg : ThrowableItem!EntityEgg {

	public this() {
		super(Items.EGG, 0, 16);
	}

}

class Enderpearl : ThrowableItem!EntityEnderpearl {

	public this() {
		super(Items.SLIMEBALL, 0, 16);
	}

}

//class ExperienceBottle : ThrowableItem!EntityExperienceBottl

class SplashPotion(ushort meta) : ThrowableItem!(EntityPotion, ushort) {

	public this() {
		super(Items.SPLASH_POTION, meta, 1, meta);
	}

}

class WaterBottleSplashPotion : SplashPotion!(Potions.WATER_BOTTLE) {}
class MundaneSplashPotion : SplashPotion!(Potions.MUNDANE) {}
class MundaneExtendedSplashPotion : SplashPotion!(Potions.MUNDANE_EXTENDED) {}
class ThickSplashPotion : SplashPotion!(Potions.THICK) {}
class AwkwardSplashPotion : SplashPotion!(Potions.AWKWARD) {}
class NightVisionSplashPotion : SplashPotion!(Potions.NIGHT_VISION) {}
class NightVisionExtendedSplashPotion : SplashPotion!(Potions.NIGHT_VISION_EXTENDED) {}
class InvisibilitySplashPotion : SplashPotion!(Potions.INVISIBILITY) {}
class InvisibilityExtendedSplashPotion : SplashPotion!(Potions.INVISIBILITY_EXTENDED) {}
class LeapingSplashPotion : SplashPotion!(Potions.LEAPING) {}
class LeapingExtendedSplashPotion : SplashPotion!(Potions.LEAPING_EXTENDED) {}
class LeapingPlusSpashPotion : SplashPotion!(Potions.LEAPING_PLUS) {}
class FireResistanceSplashPotion : SplashPotion!(Potions.FIRE_RESISTANCE) {}
class FireResistanceExtendedSplashPotions : SplashPotion!(Potions.FIRE_RESISTANCE_EXTENDED) {}
class SpeedSplashPotion : SplashPotion!(Potions.SPEED) {}
class SpeedExtendedSplashPotion : SplashPotion!(Potions.SPEED_EXTENDED) {}
class SpeedPlusSplashPotion : SplashPotion!(Potions.SPEED_PLUS) {}
class SlownessSplashPotion : SplashPotion!(Potions.SLOWNESS) {}
class SlownessExtendedSplashPotion : SplashPotion!(Potions.SLOWNESS_EXTENDED) {}
class WaterBreathingSplashPotion : SplashPotion!(Potions.WATER_BREATHING) {}
class WaterBreathingExtendedSplashPotion : SplashPotion!(Potions.WATER_BREATHING_EXTENDED) {}
class HealingSplashPotion : SplashPotion!(Potions.HEALING) {}
class HealingPlusSplashPotion : SplashPotion!(Potions.HEALING_PLUS) {}
class HarmingSplasPotion : SplashPotion!(Potions.HARMING) {}
class HarmingPlusSplashPotion : SplashPotion!(Potions.HARMING_PLUS) {}
class PoisonSplashPotion : SplashPotion!(Potions.POISON) {}
class PoisonExtendedSplashPotion : SplashPotion!(Potions.POISON_EXTENDED) {}
class PoisonPlusSplashPotion : SplashPotion!(Potions.POISON_PLUS) {}
class RegenerationSplashPotion : SplashPotion!(Potions.REGENERATION) {}
class RegenerationExtendedSplashPotion : SplashPotion!(Potions.REGENERATION_EXTENDED) {}
class RegenerationPlusSpashPotion : SplashPotion!(Potions.REGENERATION_PLUS) {}
class StrengthSpashPotion : SplashPotion!(Potions.STRENGTH) {}
class StrengthExtendedSplashPotion : SplashPotion!(Potions.STRENGTH_EXTENDED) {}
class StrengthPlusSplashPotion : SplashPotion!(Potions.STRENGTH_PLUS) {}
class WeaknessSplashPotion : SplashPotion!(Potions.WEAKNESS) {}
class WeaknessExtendedSplashPotion : SplashPotion!(Potions.WEAKNESS_EXTENDED) {}
*/