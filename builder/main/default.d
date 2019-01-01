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
module loader.default_;

import core.thread : Thread, dur;

import std.concurrency : LinkTerminated;
import std.conv : to;
import std.file : write, exists, mkdirRecurse;
import std.path : dirSeparator;
import std.string : indexOf, lastIndexOf, replace;

import selery.config : Config;
import selery.crash : logCrash;
import selery.hub.hncom : LiteNode;
import selery.hub.plugin.plugin : HubPluginOf;
import selery.hub.server : HubServer;
import selery.node.handler : TidAddress;
import selery.node.plugin.plugin : NodePluginOf;
import selery.node.server : NodeServer;

import config : ConfigType;
import pluginloader;
import starter;

void main(string[] args) {

	start(ConfigType.default_, args, (Config config){

		new Thread({ new shared HubServer(true, config, loadPlugins!(HubPluginOf, "hub")(config), args); }).start();

		while(!LiteNode.ready) Thread.sleep(dur!"msecs"(1)); //TODO add a limit in case of failure
		
		try {
			
			new shared NodeServer(new TidAddress(cast()LiteNode.tid), config, loadPlugins!(NodePluginOf, "node")(config), args);
			
		} catch(LinkTerminated) {
			
		} catch(Throwable e) {

			logCrash("node", config.lang, e);
			
		} finally {
			
			import core.stdc.stdlib : exit;
			exit(1);
			
		}
		
	});
	
}

