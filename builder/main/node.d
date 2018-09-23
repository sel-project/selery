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
module loader.node;

import std.concurrency : LinkTerminated;
import std.conv : to;
import std.socket;
import std.string : startsWith;

import selery.config : Config;
import selery.crash : logCrash;
import selery.node.plugin.plugin : NodePluginOf;
import selery.node.server : NodeServer;

import config : ConfigType;
import pluginloader;
import starter;

void main(string[] args) {

	start(ConfigType.node, args, (Config config){

		Address address = getAddress(config.node.ip, config.node.port)[0];

		try {
			
			new shared NodeServer(false, address, config, loadPlugins!(NodePluginOf, "node")(config), args);
			
		} catch(LinkTerminated) {
			
		} catch(Throwable e) {

			logCrash("node", config.lang, e);
			
		} finally {
			
			import core.stdc.stdlib : exit;
			exit(1);
			
		}
		
	});
	
}

