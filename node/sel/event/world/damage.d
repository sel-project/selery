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
module sel.event.world.damage;

import std.algorithm : max;

import sel.block.block : Block;
import sel.entity.effect;
import sel.entity.entity : Entity;
import sel.entity.human : Human;
import sel.entity.interfaces;
import sel.entity.living : Living;
import sel.entity.noai : Lightning;
import sel.event.event : Cancellable;
import sel.event.world.entity : EntityEvent;
import sel.event.world.player : PlayerEvent;
import sel.item.enchanting;
import sel.item.item : Item;
import sel.item.slot : Slot;
import sel.item.tool : Tool;
import sel.math.vector;
import sel.player.player : Player;
import sel.world.world : World;

private enum Modifiers : size_t {

	NONE = 0,

	RESISTANCE = 1 << 0,
	FALLING = 1 << 1,
	ARMOR = 1 << 2,
	FIRE = 1 << 3,
	BLAST = 1 << 4,
	PROJECTILE = 1 << 5,
	
	ALL = size_t.max

}

// damage caused by itself
interface EntityDamageEvent : EntityEvent, Cancellable {
	
	public pure nothrow @property @safe @nogc Entity victim();
	
	public pure nothrow @property @safe @nogc float originalDamage();
	
	public pure nothrow @property @safe @nogc float damage();
	
	public pure nothrow @property @safe @nogc float damage(float damage);

	public pure nothrow @property @safe @nogc bool imminent();
	
	public pure nothrow @property @safe @nogc string message();
	
	public pure nothrow @property @safe @nogc string[] args();
	
	public static mixin template Implementation(size_t modifiers) {

		mixin Cancellable.Implementation;

		mixin EntityEvent.Implementation;
		
		private float n_original_damage;
		private float m_damage;
		
		protected string n_message;
		protected string[] n_args;
		
		protected @safe entityDamage(Entity entity, float damage, string message) {
			this.n_entity = entity;
			this.n_original_damage = damage;
			this.calculateDamage();
			this.n_message = message;
			this.n_args ~= entity.displayName;
		}
		
		protected @safe void calculateDamage() {
			
			static if(modifiers != Modifiers.NONE) {
			
				float damage = this.originalDamage;
				
				if(cast(Living)this.entity) {
				
					Living victim = cast(Living)this.entity;
					
					static if(modifiers & Modifiers.RESISTANCE) {
						if(victim.hasEffect(Effects.RESISTANCE)) {
							damage /= 1.2 * victim.getEffect(Effects.RESISTANCE).levelFromOne;
						}
					}
					
					static if(modifiers & Modifiers.FALLING) {
						if(victim.hasEffect(Effects.JUMP)) {
							damage -= victim.getEffect(Effects.JUMP).levelFromOne;
						}
					}
					
					static if(modifiers & Modifiers.ARMOR) {
						if(cast(Human)victim) {
							Human human = cast(Human)victim;
							
							float protection = human.inventory.protection;
							damage *= 1f - max(protection / 5f, protection - damage / 2f) / 25f;
							
							float epf = 0f;
							foreach(size_t i, Slot slot; human.inventory.armor) {
								if(!slot.empty) {
									if(slot.item.hasEnchantment(Enchantments.PROTECTION)) {
										epf += slot.item.getEnchantmentLevel(Enchantments.PROTECTION);
									}
									static if(modifiers & Modifiers.FIRE) {
										if(slot.item.hasEnchantment(Enchantments.FIRE_PROTECTION)) {
											epf += slot.item.getEnchantmentLevel(Enchantments.FIRE_PROTECTION) * 2;
										}
									}
									static if(modifiers & Modifiers.BLAST) {
										if(slot.item.hasEnchantment(Enchantments.BLAST_PROTECTION)) {
											epf += slot.item.getEnchantmentLevel(Enchantments.BLAST_PROTECTION) * 2;
										}
									}
									static if(modifiers & Modifiers.PROJECTILE) {
										if(slot.item.hasEnchantment(Enchantments.PROJECTILE_PROTECTION)) {
											epf += slot.item.getEnchantmentLevel(Enchantments.PROJECTILE_PROTECTION) * 2;
										}
									}
									static if(modifiers & Modifiers.FALLING) {
										// boots only
										if(i == 3 && slot.item.hasEnchantment(Enchantments.FEATHER_FALLING)) {
											epf += slot.item.getEnchantmentLevel(Enchantments.FEATHER_FALLING) * 3;
										}
									}
									if(epf >= 20) {
										epf = 20f;
										break;
									}
								}
							}
							if(epf > 0) {
								damage *= 1f - epf / 25f;
							}

						}
					}
				
				}
				
				this.m_damage = damage < 0 ? 0 : damage;
				
			} else {
				
				this.m_damage = this.originalDamage;
				
			}
			
		}
		
		public final override pure nothrow @property @safe @nogc Entity victim() {
			return this.entity;
		}
		
		public final override pure nothrow @property @safe @nogc float originalDamage() {
			return this.n_original_damage;
		}
		
		public final override pure nothrow @property @safe @nogc float damage() {
			return this.m_damage;
		}
		
		public final override pure nothrow @property @safe @nogc float damage(float damage) {
			return this.m_damage = damage;
		}

		public override pure nothrow @property @safe @nogc bool imminent() {
			return false;
		}
		
		public final override pure nothrow @property @safe @nogc string message() {
			return this.n_message;
		}
		
		public final override pure nothrow @property @safe @nogc string[] args() {
			return this.n_args;
		}
		
	}

}

// damage caused by another entity
interface EntityDamageByEntityEvent : EntityDamageEvent {
	
	public pure nothrow @property @safe @nogc Entity damager();
	
	public pure nothrow @property @safe @nogc bool doKnockback();
	
	public pure nothrow @property @safe @nogc EntityPosition knockback();
	
	public pure nothrow @property @safe @nogc bool isCritical();

	public static mixin template Implementation(bool impl_entity_damage_event, size_t modifiers) {
	
		static if(impl_entity_damage_event) {
			mixin EntityDamageEvent.Implementation!modifiers;
		}
		
		private Entity n_damager;
		protected EntityPosition n_knockback;
		protected float knockback_modifier = .32;
		protected bool n_critical;
		
		protected @safe entityDamageByEntity(Entity victim, Entity damager, float damage, string message) {
			this.entityDamage(victim, this.isCritical ? damage * 1.5 : damage, message);
			this.n_damager = damager;
			this.n_args ~= damager.displayName;
		}
		
		public pure nothrow @property @safe @nogc Entity damager() {
			return this.n_damager;
		}
		
		public pure nothrow @property @safe @nogc bool doKnockback() {
			return this.knockback_modifier != 0;
		}
		
		public pure nothrow @property @safe @nogc EntityPosition knockback() {
			return EntityPosition(this.n_knockback.x * this.knockback_modifier, .4, this.n_knockback.z * this.knockback_modifier);
		}
		
		public pure nothrow @property @safe @nogc bool isCritical() {
			return this.n_critical;
		}
	
	}

}

// void

class EntityDamageByVoidEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);

	protected @safe this() {}

	public @safe this(Entity entity) {
		this.entityDamage(entity, 4, "{death.attack.outOfWorld}");
	}

	public final override pure nothrow @property @safe @nogc bool imminent() {
		return true;
	}

}

final class EntityPushedIntoVoidEvent : EntityDamageByVoidEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.NONE);
	
	public @safe this(Entity victim, Entity damager) {
		super();
		this.entityDamageByEntity(victim, damager, 4, "{death.attack.outOfWorld.player}");
	}

	mixin Cancellable.FinalImplementation;

}

// command

class EntityDamageByCommandEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 0xFFFF, "{death.attack.generic}");
	}

	public final override pure nothrow @property @safe @nogc bool imminent() {
		return true;
	}

}

// attack (contact)

class EntityDamageByEntityAttackEvent : EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(true, Modifiers.RESISTANCE | Modifiers.ARMOR);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, "{death.attack.player}");
		this.n_knockback = damager.direction;
	}
	
	public pure nothrow @property @safe @nogc Item item() {
		return null;
	}

}

deprecated alias EntityAttackedByEntityEvent = EntityDamageByEntityAttackEvent;

class EntityDamageByPlayerAttackEvent : EntityDamageByEntityAttackEvent, PlayerEvent {
	
	private Item n_item;
	
	public @trusted this(Entity victim, Player damager) {
		float damage = 1;
		if(!damager.inventory.held.empty) {
			this.n_item = damager.inventory.held.item;
			// damage from weapon and weapon's enchantments
			damage = this.item.attack;
			if(this.item.hasEnchantment(Enchantments.SHARPNESS)) damage *= 1.2f * this.item.getEnchantmentLevel(Enchantments.SHARPNESS);
			if(this.item.hasEnchantment(Enchantments.BANE_OF_ARTHROPODS) && cast(Arthropods)this.victim) damage *= 2.5f * this.item.getEnchantmentLevel(Enchantments.BANE_OF_ARTHROPODS);
			if(this.item.hasEnchantment(Enchantments.SMITE) && cast(Undead)this.victim) damage *= 2.5f * this.item.getEnchantmentLevel(Enchantments.SMITE);
		}
		// effects
		if(damager.hasEffect(Effects.STRENGTH)) damage *= 1.3f * damager.getEffect(Effects.STRENGTH).levelFromOne;
		if(damager.hasEffect(Effects.WEAKNESS)) damage *= .5f * damager.getEffect(Effects.WEAKNESS).levelFromOne;
		// critical
		this.n_critical = damager.falling && !damager.sprinting && damager.vehicle is null && !damager.hasEffect(Effects.BLINDNESS);
		// calculate damage
		super(victim, damager, damage);
		// more enchantments
		if(this.item !is null) {
			//TODO fire ench
			// more knockback!
			if(this.item.toolType == Tool.SWORD || this.item.toolType == Tool.AXE) {
				this.knockback_modifier = .52;
			}
			if(this.item.hasEnchantment(Enchantments.KNOCKBACK)) {
				this.knockback_modifier += .6 * this.item.getEnchantmentLevel(Enchantments.KNOCKBACK);
			}
		}
		// add weapon's name to args
		if(this.item !is null && this.item.customName != "") {
			this.n_message = "{death.attack.player.item}";
			this.n_args ~= this.item.customName;
		}
	}
	
	public final override pure nothrow @property @safe @nogc Player player() {
		return this.playerDamager;
	}
	
	public final pure nothrow @property @safe @nogc Player playerDamager() {
		return cast(Player)this.damager;
	}
	
	public final override pure nothrow @property @safe @nogc Item item() {
		return this.n_item;
	}

}

deprecated alias EntityAttackedByPlayerEvent = EntityDamageByPlayerAttackEvent;

final class PlayerDamageByPlayerAttackEvent : EntityDamageByPlayerAttackEvent {

	public @safe this(Player victim, Player damager) {
		super(victim, damager);
	}
	
	public pure nothrow @property @safe @nogc Player victimPlayer() {
		return cast(Player)this.victim;
	}

}

deprecated alias PlayerAttackedByPlayerEvent = PlayerDamageByPlayerAttackEvent;

// projectile
/*
// thrower (damager) can be null if the projectile has been thrown by a plugin or a dispencer
abstract class EntityDamageWithProjectileEvent : EntityDamageByEntityEvent {}

final class EntityDamageWithArrowEvent : EntityDamageWithProjectileEvent {}

final class EntityPummeledEvent : EntityDamageWithProjectileEvent {}

class EntityDamageWithFireballEvent : EntityDamageWithProjectileEvent {}*/

// suffocation

final class EntitySuffocationEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.inWall}");
	}

}

// drowning

class EntityDrowningEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.drown}");
	}

}

final class EntityDrowningEscapingEntityEvent : EntityDrowningEvent {
	
	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.NONE);
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, "{death.attack.drown.player}");
	}

}

// explosion

class EntityDamageByExplosionEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.RESISTANCE | Modifiers.ARMOR | Modifiers.BLAST);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity, float damage) {
		this.entityDamage(entity, damage, "{death.attack.explosion}");
	}

}

class EntityDamageByEntityExplosionEvent : EntityDamageByExplosionEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.RESISTANCE | Modifiers.ARMOR | Modifiers.BLAST);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, "{death.attack.explosion.player}");
	}

	mixin Cancellable.FinalImplementation;

}

//TODO final class EntityDamageByTntExplosionEvent : EntityDamageByEntityExplosionEvent {}

//TODO final class EntityDamageByCreeperExplosionEvent : EntityDamageByEntityExplosionEvent {}

// hot stuff (fire and lava)

interface EntityDamageByHeatEvent : EntityDamageEvent {

	public static mixin template Implementation() {
	
		mixin EntityDamageEvent.Implementation!(Modifiers.RESISTANCE | Modifiers.ARMOR | Modifiers.FIRE);
	
	}

}

interface EntityDamageByHeatEscapingEntityEvent : EntityDamageByHeatEvent, EntityDamageByEntityEvent {

	public static mixin template Implementation() {
	
		mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.RESISTANCE | Modifiers.ARMOR | Modifiers.FIRE);

		mixin Cancellable.FinalImplementation;
	
	}

}

class EntityBurningEvent : EntityDamageByHeatEvent {

	mixin EntityDamageByHeatEvent.Implementation;

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.onFire}");
	}

}

final class EntityBurningEscapingEntityEvent : EntityBurningEvent, EntityDamageByHeatEscapingEntityEvent {

	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, "{death.attack.onFire.player}");
	}

}

class EntityDamageByFireEvent : EntityDamageByHeatEvent {

	mixin EntityDamageByHeatEvent.Implementation;

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.inFire}");
	}

}

final class EntityDamageByFireEscapingEntityEvent : EntityDamageByFireEvent, EntityDamageByHeatEscapingEntityEvent {

	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, "{death.attack.inFire.player}");
	}

}

class EntityDamageByLavaEvent : EntityDamageByHeatEvent {

	mixin EntityDamageByHeatEvent.Implementation;

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 4, "{death.attack.lava}");
	}

}

final class EntityDamageByLavaEscapingEntityEvent : EntityDamageByLavaEvent, EntityDamageByHeatEscapingEntityEvent {

	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 4, "{death.attack.lava.player}");
	}

}

// magic

class EntityDamageByMagicEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity, float damage) {
		this.entityDamage(entity, damage, "{death.attack.magic}");
	}

}

final class EntityDamageWithMagicEvent : EntityDamageByMagicEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.NONE);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, "{death.attack.indirectMagic}");
	}

	mixin Cancellable.FinalImplementation;

}

// poison

final class EntityDamageByPoisonEvent : EntityDamageEvent {
	
	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, ""); // no message (can't die poisoned)
	}

}

// wither

final class EntityDamageByWitherEffectEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.wither}");
	}

}

// lightning

final class EntityStruckByLightningEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.RESISTANCE | Modifiers.ARMOR);
	
	private Lightning n_lightning;
	
	public @safe this(Entity entity, Lightning lightning) {
		this.entityDamage(entity, 5, "{death.attack.lightning}");
		this.n_lightning = lightning;
	}
	
	public pure nothrow @property @safe @nogc Lightning lightning() {
		return this.n_lightning;
	}
	
	public pure nothrow @property @safe @nogc EntityPosition position() {
		return this.lightning.position;
	}

}

// thorns

final class EntityDamageByThornsEvent : EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(true, Modifiers.RESISTANCE | Modifiers.ARMOR);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, "{death.attack.thorns}");
	}

}

// starvation

final class EntityStarveEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.NONE);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.starve}");
	}

}

// falling block (is the block already placed?)

class EntitySquashedByFallingBlockEvent : EntityDamageEvent {
	
	mixin EntityDamageEvent.Implementation!(Modifiers.ARMOR);
	
	private Block n_block;
	
	public @safe this(Entity entity, Block block, float damage, string message="{death.attack.fallingBlock}") {
		this.entityDamage(entity, damage, message);
	}

}

/*final class EntitySquashedByAnvilEvent : EntitySquashedByFallingBlockEvent {

	public @safe this(Entity entity, Blocks.Anvil anvil, float damage) {
		super(entity, anvil, damage, "{death.attack.anvil}");
	}

}*/

// cactus

class EntityDamageByCactusEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.RESISTANCE | Modifiers.ARMOR);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, "{death.attack.cactus}");
	}
	
}

final class EntityDamageByCactusEscapingEntityEvent : EntityDamageByCactusEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.RESISTANCE | Modifiers.ARMOR);
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, "{death.attack.cactus.player}");
	}

	mixin Cancellable.FinalImplementation;

}

// falling

class EntityFallDamageEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.FALLING);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity, float damage) {
		this.entityDamage(entity, damage, "{death.attack.fall}");
	}
	
}

final class EntityDoomedToFallEvent : EntityFallDamageEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.FALLING);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, "{death.fell.assist}");
	}

	mixin Cancellable.FinalImplementation;

}
/+
/**
 * Example:
 * ---
 * assert(is(GetDamageEvent!("void", Entity) == EntityDamageByVoidEvent));
 * ---
 */
template GetDamageEvent(string type, V:Entity=Entity, A=Object) {
	static if(type == "void") {
		static if(is(A : Entity)) {
			alias GetDamageEvent = EntityPushedIntoVoidEvent;
		} else {
			alias GetDamageEvent = EntityDamageByVoidEvent;
		}
	} else {
		static assert(0, "Cannot get a damage event");
	}
}
+/
