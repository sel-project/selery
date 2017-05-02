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
module sel.util.task;

import com.sel : tick_t;

enum areValidTaskArgs(E...) = E.length == 0 || (E.length == 1 && is(E[0] : tick_t));

final class TaskManager {

	private size_t tids = 0;
	private Task[] tasks;

	public @safe size_t add(E...)(void delegate(E) task, size_t interval, size_t repeat, tick_t stick) if(areValidTaskArgs!E) {
		this.tasks ~= new TaskOf!E(this.tids, task, interval, repeat, stick);
		return this.tids++;
	}

	public @safe void remove(E...)(void delegate(E) task) if(areValidTaskArgs!E) {
		foreach(Task t; this.tasks) {
			if(cast(TaskOf!E)t && (cast(TaskOf!E)t).task == task) array_remove(t, this.tasks);
		}
	}

	public @safe void remove(size_t tid) {
		foreach(index, task; this.tasks) {
			if(task.id == tid) {
				this.tasks = this.tasks[0..index] ~ this.tasks[index+1..$];
				break;
			}
		}
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

abstract class Task {

	public immutable size_t id;

	public @safe @nogc this(size_t id) {
		this.id = id;
	}

	public @safe @nogc bool expired();

	public void execute(tick_t stick);

	public override bool opEquals(Object o) {
		return cast(Task)o ? (cast(Task)o).id == this.id : false;
	}

}

final class TaskOf(E...) : Task if(areValidTaskArgs!E) {
	
	private void delegate(E) n_task;
	private size_t interval;
	private size_t repeat;
	
	private tick_t start;
	private tick_t ticks = 0;
	
	public @trusted this(size_t id, void delegate(E) task, size_t interval, size_t repeat, tick_t start) {
		if(interval == 0) throw new TaskException("0 is not a valid interval");
		super(id);
		this.n_task = task;
		this.interval = interval;
		this.repeat = repeat;
		this.start = start % this.interval;
	}
	
	public override pure nothrow @property @safe @nogc bool expired() {
		return this.repeat == 0;
	}
	
	public override void execute(tick_t stick) {
		if(stick % this.interval == this.start) {
			static if(E.length == 0) {
				this.n_task();
			} else {
				this.n_task(this.ticks);
			}
			this.ticks++;
			if(this.repeat < uint.max) this.repeat--;
		}
	}

	public pure nothrow @property @safe @nogc void delegate(E) task() {
		return this.n_task;
	}

	public override @safe bool opEquals(Object o) {
		if(cast(Task)o) return (cast(Task)o).id == this.id;
		else return false;
	}
	
}

class TaskException : Exception {

	public this(string message, string file=__FILE__, size_t line=__LINE__) {
		super(message, file, line);
	}

}
