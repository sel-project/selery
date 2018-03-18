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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/node/plugin/plugin.d, selery/node/plugin/plugin.d)
 */
module selery.node.plugin.plugin;

import std.conv : to;
import std.traits : Parameters;

import selery.about;
public import selery.plugin;

import selery.command.util : CommandSender;
import selery.event.node : NodeServerEvent;
import selery.event.world : WorldEvent;
import selery.node.server : NodeServer;
import selery.server : Server;

class NodePlugin {

	protected shared NodeServer server;

	protected shared Plugin plugin;

}

class NodePluginInfo : Plugin {
	
	public this(string name, string[] authors, string version_, bool main) {
		super(name, authors, version_, main);
	}
	
	abstract void load(shared NodeServer server);
	
}

class NodePluginOf(T) : NodePluginInfo if(is(T == Object) || is(T : NodePlugin)) {

	public this(string name, string[] authors, string version_) {
		super(name, authors, version_, !is(T == Object));
	}

	public override void load(shared NodeServer server) {
		static if(!is(T == Object)) {
			T main = new T();
			main.server = server;
			main.plugin = cast(shared)this;
			loadPluginAttributes!(true, NodeServerEvent, WorldEvent, false, CommandSender, false)(main, this, cast()server);
		}
	}

}
