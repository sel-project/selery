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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/event/world/entity.d, selery/event/world/entity.d)
 */
module selery.event.world.entity;

import selery.entity.entity : Entity;
import selery.entity.living : Living;
import selery.event.event : Cancellable;
import selery.event.world.damage : EntityDamageEvent;
import selery.event.world.world;
import selery.lang : Translation;
import selery.world.world : World;

interface EntityEvent : WorldEvent {

	public pure nothrow @property @safe @nogc Entity entity();

	public static mixin template Implementation() {

		private Entity n_entity;

		public final override pure nothrow @property @safe @nogc Entity entity() {
			return this.n_entity;
		}

		// implements WorldEvent
		public final override pure nothrow @property @safe @nogc World world() {
			return this.entity.world;
		}

	}
	
}

final class EntityHealEvent : EntityEvent, Cancellable {

	mixin Cancellable.Implementation;

	mixin EntityEvent.Implementation;

	private uint n_amount;

	public pure nothrow @safe @nogc this(Living entity, uint amount) {
		this.n_entity = entity;
		this.n_amount = amount;
	}

	public pure nothrow @property @safe @nogc uint amount() {
		return this.n_amount;
	}

}

class EntityDeathEvent : EntityEvent {

	mixin EntityEvent.Implementation;

	private EntityDamageEvent n_damage;

	private Translation m_message;

	public pure nothrow @safe @nogc this(Living entity, EntityDamageEvent damage) {
		this.n_entity = entity;
		this.n_damage = damage;
	}

	public pure nothrow @property @safe @nogc EntityDamageEvent damageEvent() {
		return this.n_damage;
	}

	public pure nothrow @property @safe @nogc Translation message() {
		return this.m_message;
	}

	public pure nothrow @property @safe @nogc Translation message(Translation message) {
		return this.m_message = message;
	}

	public pure nothrow @property @safe @nogc Translation message(bool display) {
		if(display) {
			this.m_message = this.damageEvent.message;
		} else {
			this.m_message = Translation.init;
		}
		return this.message;
	}

}
