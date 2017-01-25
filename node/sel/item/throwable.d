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
module sel.item.throwable;
/*
import sel.player : Player;
import sel.entity.projectile : Projectile, EntitySnowball = Snowball, EntityEgg = Egg, EntityEnderpearl = Enderpearl, EntityPotion = Potion;
import sel.item.consumeable : Potions;
import sel.item.item : Item, Items, register;

struct ThrowableInit {

	public static void init() {

		register!Snowball(Items.SNOWBALL);
		register!Egg(Items.EGG);
		register!Enderpearl(Items.SLIMEBALL);

		//can't do that with a loop :(
		register!WaterBottleSplashPotion(Items.SPLASH_POTION, Potions.WATER_BOTTLE);
		register!MundaneSplashPotion(Items.SPLASH_POTION, Potions.MUNDANE);
		register!MundaneExtendedSplashPotion(Items.SPLASH_POTION, Potions.MUNDANE_EXTENDED);
		register!ThickSplashPotion(Items.SPLASH_POTION, Potions.THICK);
		register!AwkwardSplashPotion(Items.SPLASH_POTION, Potions.AWKWARD);
		register!NightVisionSplashPotion(Items.SPLASH_POTION, Potions.NIGHT_VISION);
		register!NightVisionExtendedSplashPotion(Items.SPLASH_POTION, Potions.NIGHT_VISION_EXTENDED);
		register!InvisibilitySplashPotion(Items.SPLASH_POTION, Potions.INVISIBILITY);
		register!InvisibilityExtendedSplashPotion(Items.SPLASH_POTION, Potions.INVISIBILITY_EXTENDED);
		register!LeapingSplashPotion(Items.SPLASH_POTION, Potions.LEAPING);
		register!LeapingExtendedSplashPotion(Items.SPLASH_POTION, Potions.LEAPING_EXTENDED);
		register!LeapingPlusSpashPotion(Items.SPLASH_POTION, Potions.LEAPING_PLUS);
		register!FireResistanceSplashPotion(Items.SPLASH_POTION, Potions.FIRE_RESISTANCE);
		register!FireResistanceExtendedSplashPotions(Items.SPLASH_POTION, Potions.FIRE_RESISTANCE_EXTENDED);
		register!SpeedSplashPotion(Items.SPLASH_POTION, Potions.SPEED);
		register!SpeedExtendedSplashPotion(Items.SPLASH_POTION, Potions.SPEED_EXTENDED);
		register!SpeedPlusSplashPotion(Items.SPLASH_POTION, Potions.SPEED_PLUS);
		register!SlownessSplashPotion(Items.SPLASH_POTION, Potions.SLOWNESS);
		register!SlownessExtendedSplashPotion(Items.SPLASH_POTION, Potions.SLOWNESS_EXTENDED);
		register!WaterBreathingSplashPotion(Items.SPLASH_POTION, Potions.WATER_BREATHING);
		register!WaterBreathingExtendedSplashPotion(Items.SPLASH_POTION, Potions.WATER_BREATHING_EXTENDED);
		register!HealingSplashPotion(Items.SPLASH_POTION, Potions.HEALING);
		register!HealingPlusSplashPotion(Items.SPLASH_POTION, Potions.HEALING_PLUS);
		register!HarmingSplasPotion(Items.SPLASH_POTION, Potions.HARMING);
		register!HarmingPlusSplashPotion(Items.SPLASH_POTION, Potions.HARMING_PLUS);
		register!PoisonSplashPotion(Items.SPLASH_POTION, Potions.POISON);
		register!PoisonExtendedSplashPotion(Items.SPLASH_POTION, Potions.POISON_EXTENDED);
		register!PoisonPlusSplashPotion(Items.SPLASH_POTION, Potions.POISON_PLUS);
		register!RegenerationSplashPotion(Items.SPLASH_POTION, Potions.REGENERATION);
		register!RegenerationExtendedSplashPotion(Items.SPLASH_POTION, Potions.REGENERATION_EXTENDED);
		register!RegenerationPlusSpashPotion(Items.SPLASH_POTION, Potions.REGENERATION_PLUS);
		register!StrengthSpashPotion(Items.SPLASH_POTION, Potions.STRENGTH);
		register!StrengthExtendedSplashPotion(Items.SPLASH_POTION, Potions.STRENGTH_EXTENDED);
		register!StrengthPlusSplashPotion(Items.SPLASH_POTION, Potions.STRENGTH_PLUS);
		register!WeaknessSplashPotion(Items.SPLASH_POTION, Potions.WEAKNESS);
		register!WeaknessExtendedSplashPotion(Items.SPLASH_POTION, Potions.WEAKNESS_EXTENDED);

	}

}

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