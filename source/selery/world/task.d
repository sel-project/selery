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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/world/task.d, selery/world/task.d)
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
