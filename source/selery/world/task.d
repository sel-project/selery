/*
 * Copyright (c) 2017-2018 SEL
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
module selery.world.task;

import selery.about : tick_t;

enum areValidTaskArgs(E...) = E.length == 0 || (E.length == 1 && is(E[0] : tick_t));

final class TaskManager {
	
	private size_t tids = 0;
	private Task[] tasks;
	
	public @safe size_t add()(void delegate() task, size_t interval, size_t repeat, tick_t stick) {
		this.tasks ~= new Task(this.tids, task, interval, repeat, stick);
		return this.tids++;
	}
	
	public @safe bool remove()(void delegate() task) {
		foreach(index, t; this.tasks) {
			if(t.task == task) {
				this.tasks = this.tasks[0..index] ~ this.tasks[index+1..$];
				return true;
			}
		}
		return false;
	}
	
	public @safe bool remove(size_t tid) {
		foreach(index, task; this.tasks) {
			if(task.id == tid) {
				this.tasks = this.tasks[0..index] ~ this.tasks[index+1..$];
				return true;
			}
		}
		return false;
	}
	
	public void tick(tick_t tick) {
		foreach(index, task; this.tasks) {
			if(task.expired) this.tasks = this.tasks[0..index] ~ this.tasks[index+1..$];
			else task.execute(tick);
		}
	}
	
	public pure nothrow @property @safe @nogc size_t length() {
		return this.tasks.length;
	}
	
}

final class Task {
	
	public immutable size_t id;
	
	private void delegate() _task;
	private size_t interval;
	private size_t repeat;
	
	private tick_t start;
	private tick_t ticks = 0;
	
	public @safe this(size_t id, void delegate() task, size_t interval, size_t repeat, tick_t start) {
		assert(interval != 0, "0 is not a valid interval");
		this.id = id;
		this._task = task;
		this.interval = interval;
		this.repeat = repeat;
		this.start = start % this.interval;
	}
	
	public pure nothrow @property @safe @nogc bool expired() {
		return this.repeat == 0;
	}
	
	public void execute(tick_t stick) {
		if(stick % this.interval == this.start) {
			this._task();
			this.ticks++;
			if(this.repeat < uint.max) this.repeat--;
		}
	}
	
	public pure nothrow @property @safe @nogc void delegate() task() {
		return this._task;
	}
	
}
