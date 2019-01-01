/*
 * Copyright (c) 2017-2019 sel-project
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
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/world/damage.d, selery/event/world/damage.d)
 */
module selery.event.world.damage;

import std.algorithm : max;

import selery.block.block : Block;
import selery.effect;
import selery.enchantment;
import selery.entity.entity : Entity;
import selery.entity.human : Human;
import selery.entity.interfaces;
import selery.entity.living : Living;
import selery.entity.noai : Lightning;
import selery.event.event : Cancellable;
import selery.event.world.entity : EntityEvent;
import selery.event.world.player : PlayerEvent;
import selery.item.item : Item;
import selery.item.slot : Slot;
import selery.item.tool : Tools;
import selery.lang : Translation, Translatable;
import selery.math.vector;
import selery.player.player : Player;
import selery.world.world : World;

private enum Modifiers : size_t {

	none = 0,

	resistance = 1 << 0,
	falling = 1 << 1,
	armor = 1 << 2,
	fire = 1 << 3,
	blast = 1 << 4,
	projectile = 1 << 5,
	
	all = size_t.max

}

// damage caused by itself
interface EntityDamageEvent : EntityEvent, Cancellable {
	
	public pure nothrow @property @safe @nogc Entity victim();
	
	public pure nothrow @property @safe @nogc float originalDamage();
	
	public pure nothrow @property @safe @nogc float damage();
	
	public pure nothrow @property @safe @nogc float damage(float damage);

	public pure nothrow @property @safe @nogc bool imminent();
	
	public pure nothrow @property @safe @nogc Translation message();
	
	public static mixin template Implementation(size_t modifiers) {

		mixin Cancellable.Implementation;

		mixin EntityEvent.Implementation;
		
		private float n_original_damage;
		private float m_damage;
		
		protected Translation n_message;
		
		protected @safe entityDamage(Entity entity, float damage, Translatable translatable) {
			this.n_entity = entity;
			this.n_original_damage = damage;
			this.calculateDamage();
			this.n_message = Translation(translatable, entity.displayName);
		}
		
		protected @safe void calculateDamage() {
			
			static if(modifiers != Modifiers.none) {
			
				float damage = this.originalDamage;
				
				if(cast(Living)this.entity) {
				
					Living victim = cast(Living)this.entity;
					
					static if(modifiers & Modifiers.resistance) {
						if(Effect* resistance = (Effects.resistance in victim)) {
							damage /= 1.2 * (*resistance).levelFromOne;
						}
					}
					
					static if(modifiers & Modifiers.falling) {
						if(Effect* jumpBoost = (Effects.jumpBoost in victim)) {
							damage -= (*jumpBoost).levelFromOne;
						}
					}
					
					static if(modifiers & Modifiers.armor) {
						if(cast(Human)victim) {
							Human human = cast(Human)victim;
							
							float protection = human.inventory.protection;
							damage *= 1f - max(protection / 5f, protection - damage / 2f) / 25f;
							
							float epf = 0f;
							foreach(size_t i, Slot slot; human.inventory.armor) {
								if(!slot.empty) {
									if(Enchantment* p = (Enchantments.protection in slot.item)) {
										epf += (*p).level;
									}
									static if(modifiers & Modifiers.fire) {
										if(Enchantment* fireProtection = (Enchantments.fireProtection in slot.item)) {
											epf += (*fireProtection).level * 2;
										}
									}
									static if(modifiers & Modifiers.blast) {
										if(Enchantment* blastProtection = (Enchantments.blastProtection in slot.item)) {
											epf += (*blastProtection).level * 2;
										}
									}
									static if(modifiers & Modifiers.projectile) {
										if(Enchantment* projectileProtection = (Enchantments.projectileProtection in slot.item)) {
											epf += (*projectileProtection).level * 2;
										}
									}
									static if(modifiers & Modifiers.falling) {
										// boots only
										if(i == 3) {
											if(Enchantment* featherFalling = (Enchantments.featherFalling in slot.item)) {
												epf += (*featherFalling).level * 3;
											}
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
		
		public final override pure nothrow @property @safe @nogc Translation message() {
			return this.n_message;
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
		
		protected @safe entityDamageByEntity(Entity victim, Entity damager, float damage, Translatable translatable) {
			this.entityDamage(victim, this.isCritical ? damage * 1.5 : damage, translatable);
			this.n_damager = damager;
			this.n_message.parameters ~= damager.displayName;
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

	mixin EntityDamageEvent.Implementation!(Modifiers.none);

	protected @safe this() {}

	public @safe this(Entity entity) {
		this.entityDamage(entity, 4, Translatable.all("death.attack.outOfWorld"));
	}

	public final override pure nothrow @property @safe @nogc bool imminent() {
		return true;
	}

}

final class EntityPushedIntoVoidEvent : EntityDamageByVoidEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.none);
	
	public @safe this(Entity victim, Entity damager) {
		super();
		this.entityDamageByEntity(victim, damager, 4, Translatable.all("death.attack.outOfWorld")); // no message for "{0} was pushed out of the world"
	}

	mixin Cancellable.FinalImplementation;

}

// command

class EntityDamageByCommandEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.none);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 0xDEAD, Translatable.all("death.attack.generic"));
	}

	public final override pure nothrow @property @safe @nogc bool imminent() {
		return true;
	}

}

// attack (contact)

class EntityDamageByEntityAttackEvent : EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(true, Modifiers.resistance | Modifiers.armor);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, Translatable.all("death.attack.player"));
		this.n_knockback = damager.direction;
	}
	
	public pure nothrow @property @safe @nogc Item item() {
		return null;
	}

}

alias EntityAttackedByEntityEvent = EntityDamageByEntityAttackEvent;

class EntityDamageByPlayerAttackEvent : EntityDamageByEntityAttackEvent, PlayerEvent {
	
	private Item n_item;
	
	public @trusted this(Entity victim, Player damager) {
		float damage = 1;
		if(!damager.inventory.held.empty) {
			this.n_item = damager.inventory.held.item;
			// damage from weapon and weapon's enchantments
			damage = this.item.attack;
			if(Enchantment* sharpness = (Enchantments.sharpness in this.item)) damage *= 1.2f * (*sharpness).level;
			if(cast(Arthropods)this.victim){ if(Enchantment* baneOfArthropods = (Enchantments.baneOfArthropods in this.item)) damage *= 2.5f * (*baneOfArthropods).level; }
			if(cast(Undead)this.victim){ if(Enchantment* smite = (Enchantments.smite in this.item)) damage *= 2.5f * (*smite).level; }
		}
		// effects
		if(Effect* strength = (Effects.strength in damager)) damage *= 1.3f * (*strength).levelFromOne;
		if(Effect* weakness = (Effects.weakness in damager)) damage *= .5f * (*weakness).levelFromOne;
		// critical
		this.n_critical = damager.falling && !damager.sprinting && damager.vehicle is null && Effects.blindness !in damager;
		// calculate damage
		super(victim, damager, damage);
		// more enchantments
		if(this.item !is null) {
			//TODO fire ench
			// more knockback!
			if(this.item.toolType == Tools.sword || this.item.toolType == Tools.axe) {
				this.knockback_modifier = .52;
			}
			if(Enchantment* knockback = (Enchantments.knockback in this.item)) {
				this.knockback_modifier += .6 * (*knockback).level;
			}
		}
		// add weapon's name to args
		if(this.item !is null && this.item.customName != "") {
			this.n_message.translatable = Translatable.all("death.attack.player.item");
			this.n_message.parameters ~= this.item.customName;
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

alias EntityAttackedByPlayerEvent = EntityDamageByPlayerAttackEvent;

final class PlayerDamageByPlayerAttackEvent : EntityDamageByPlayerAttackEvent {

	public @safe this(Player victim, Player damager) {
		super(victim, damager);
	}
	
	public pure nothrow @property @safe @nogc Player victimPlayer() {
		return cast(Player)this.victim;
	}

}

alias PlayerAttackedByPlayerEvent = PlayerDamageByPlayerAttackEvent;

// projectile
/*
// thrower (damager) can be null if the projectile has been thrown by a plugin or a dispencer
abstract class EntityDamageWithProjectileEvent : EntityDamageByEntityEvent {}

final class EntityDamageWithArrowEvent : EntityDamageWithProjectileEvent {}

final class EntityPummeledEvent : EntityDamageWithProjectileEvent {}

class EntityDamageWithFireballEvent : EntityDamageWithProjectileEvent {}*/

// suffocation

final class EntitySuffocationEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.none);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.inWall"));
	}

}

// drowning

class EntityDrowningEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.none);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.drown"));
	}

}

final class EntityDrowningEscapingEntityEvent : EntityDrowningEvent {
	
	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.none);
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, Translatable.all("death.attack.drown.player"));
	}

}

// explosion

class EntityDamageByExplosionEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.resistance | Modifiers.armor | Modifiers.blast);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity, float damage) {
		this.entityDamage(entity, damage, Translatable.all("death.attack.explosion"));
	}

}

class EntityDamageByEntityExplosionEvent : EntityDamageByExplosionEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.resistance | Modifiers.armor | Modifiers.blast);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, Translatable.all("death.attack.explosion.player"));
	}

	mixin Cancellable.FinalImplementation;

}

//TODO final class EntityDamageByTntExplosionEvent : EntityDamageByEntityExplosionEvent {}

//TODO final class EntityDamageByCreeperExplosionEvent : EntityDamageByEntityExplosionEvent {}

// hot stuff (fire and lava)

interface EntityDamageByHeatEvent : EntityDamageEvent {

	public static mixin template Implementation() {
	
		mixin EntityDamageEvent.Implementation!(Modifiers.resistance | Modifiers.armor | Modifiers.fire);
	
	}

}

interface EntityDamageByHeatEscapingEntityEvent : EntityDamageByHeatEvent, EntityDamageByEntityEvent {

	public static mixin template Implementation() {
	
		mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.resistance | Modifiers.armor | Modifiers.fire);

		mixin Cancellable.FinalImplementation;
	
	}

}

class EntityBurningEvent : EntityDamageByHeatEvent {

	mixin EntityDamageByHeatEvent.Implementation;

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.onFire"));
	}

}

final class EntityBurningEscapingEntityEvent : EntityBurningEvent, EntityDamageByHeatEscapingEntityEvent {

	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, Translatable.all("death.attack.onFire.player"));
	}

}

class EntityDamageByFireEvent : EntityDamageByHeatEvent {

	mixin EntityDamageByHeatEvent.Implementation;

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.inFire"));
	}

}

final class EntityDamageByFireEscapingEntityEvent : EntityDamageByFireEvent, EntityDamageByHeatEscapingEntityEvent {

	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, Translatable.all("death.attack.inFire.player"));
	}

}

class EntityDamageByLavaEvent : EntityDamageByHeatEvent {
	
	mixin EntityDamageByHeatEvent.Implementation;
	
	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 4, Translatable.all("death.attack.lava"));
	}
	
}

final class EntityDamageByLavaEscapingEntityEvent : EntityDamageByLavaEvent, EntityDamageByHeatEscapingEntityEvent {
	
	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 4, Translatable.all("death.attack.lava.player"));
	}
	
}

class EntityDamageByMagmaBlockEvent : EntityDamageByHeatEvent {
	
	mixin EntityDamageByHeatEvent.Implementation;
	
	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 4, Translatable.all("death.attack.magmaBlock"));
	}
	
}

final class EntityDamageByMagmaBlockEscapingEntityEvent : EntityDamageByMagmaBlockEvent, EntityDamageByHeatEscapingEntityEvent {
	
	mixin EntityDamageByHeatEscapingEntityEvent.Implementation;
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 4, Translatable.all("death.attack.magmaBlock.player"));
	}
	
}

// magic

class EntityDamageByMagicEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.none);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity, float damage) {
		this.entityDamage(entity, damage, Translatable.all("death.attack.magic"));
	}

}

final class EntityDamageWithMagicEvent : EntityDamageByMagicEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.none);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, Translatable.all("death.attack.indirectMagic"));
	}

	mixin Cancellable.FinalImplementation;

}

// poison

final class EntityDamageByPoisonEvent : EntityDamageEvent {
	
	mixin EntityDamageEvent.Implementation!(Modifiers.none);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.init); // no message (can't die poisoned)
	}

}

// wither

final class EntityDamageByWitherEffectEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.none);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.wither"));
	}

}

// lightning

final class EntityStruckByLightningEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.resistance | Modifiers.armor);
	
	private Lightning n_lightning;
	
	public @safe this(Entity entity, Lightning lightning) {
		this.entityDamage(entity, 5, Translatable.all("death.attack.lightning"));
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

	mixin EntityDamageByEntityEvent.Implementation!(true, Modifiers.resistance | Modifiers.armor);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, Translatable.all("death.attack.thorns"));
	}

}

// starvation

final class EntityStarveEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.none);
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.starve"));
	}

}

// falling block (is the block already placed?)

class EntitySquashedByFallingBlockEvent : EntityDamageEvent {
	
	mixin EntityDamageEvent.Implementation!(Modifiers.armor);
	
	private Block n_block;
	
	public @safe this(Entity entity, Block block, float damage, const Translatable message=Translatable.all("death.attack.fallingBlock")) {
		this.entityDamage(entity, damage, message);
	}

}

/*final class EntitySquashedByAnvilEvent : EntitySquashedByFallingBlockEvent {

	public @safe this(Entity entity, Blocks.Anvil anvil, float damage) {
		super(entity, anvil, damage, Translatable.all("death.attack.anvil"));
	}

}*/

// cactus

class EntityDamageByCactusEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.resistance | Modifiers.armor);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity) {
		this.entityDamage(entity, 1, Translatable.all("death.attack.cactus"));
	}
	
}

final class EntityDamageByCactusEscapingEntityEvent : EntityDamageByCactusEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.resistance | Modifiers.armor);
	
	public @safe this(Entity victim, Entity damager) {
		this.entityDamageByEntity(victim, damager, 1, Translatable.all("death.attack.cactus.player"));
	}

	mixin Cancellable.FinalImplementation;

}

// falling

class EntityFallDamageEvent : EntityDamageEvent {

	mixin EntityDamageEvent.Implementation!(Modifiers.falling);

	protected @safe @nogc this() {}
	
	public @safe this(Entity entity, float damage) {
		this.entityDamage(entity, damage, Translatable.all("death.attack.fall"));
	}
	
}

final class EntityDoomedToFallEvent : EntityFallDamageEvent, EntityDamageByEntityEvent {

	mixin EntityDamageByEntityEvent.Implementation!(false, Modifiers.falling);
	
	public @safe this(Entity victim, Entity damager, float damage) {
		this.entityDamageByEntity(victim, damager, damage, Translatable.all("death.fell.assist"));
	}

	mixin Cancellable.FinalImplementation;

}
