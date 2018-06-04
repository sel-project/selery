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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hub/plugin/plugin.d, selery/hub/plugin/plugin.d)
 */
module selery.hub.plugin.plugin;

import std.traits : hasUDA, Parameters;

import selery.hub.server : HubServer;
public import selery.plugin;
import selery.server : Server;

class HubPlugin {

	protected shared HubServer server;

	protected shared Plugin plugin;

}

class HubPluginInfo : Plugin {

	public this(string name, string path, string[] authors, string version_, bool main) {
		super(name, path, authors, version_, main);
	}

	abstract void load(shared HubServer server);

}

class HubPluginOf(T) : HubPluginInfo if(is(T == Object) || is(T : HubPlugin)) {
	
	public this(string name, string path, string[] authors, string version_) {
		super(name, path, authors, version_, !is(T == Object));
	}
	
	public override void load(shared HubServer server) {
		static if(!is(T == Object)) {
			T main = new T();
			main.server = server;
			main.plugin = cast(shared)this;
			foreach(member ; __traits(allMembers, T)) {
				static if(is(typeof(__traits(getMember, T, member)) == function)) {
					mixin("alias F = T." ~ member ~ ";");
					enum del = "&main." ~ member;
					// start/stop
					static if(hasUDA!(F, start) && Parameters!F.length == 0) {
						this.onstart ~= mixin(del);
					}
					static if(hasUDA!(F, stop) && Parameters!F.length == 0) {
						this.onstop ~= mixin(del);
					}
					// event
					static if(hasUDA!(F, event) && Parameters!F.length == 1) {
						(cast()server.eventListener).addEventListener(mixin(del));
					}
				}
			}
		}
	}
	
}
