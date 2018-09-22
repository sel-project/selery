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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hub/handler.d, selery/hub/handler.d)
 */
module selery.hub.handler;

import std.json : JSONValue;
import std.socket : SocketException;
import std.string : toLower, indexOf, strip, split, join;

import sel.format : Format;
import sel.server.bedrock : BedrockServer;
import sel.server.java : JavaServer;
//import sel.server.query : Query;
import sel.server.util : ServerInfo;
//import sel.server.server : GenericServer;

import selery.about;
import selery.config : Config;
import selery.hub.hncom : HncomServer/*, LiteNode*/;
import selery.hub.server : HubServer;
import selery.lang : Translation;
import selery.util.thread : SafeThread;

/**
 * Main handler with the purpose of starting children handlers,
 * store constant informations and reload them when needed.
 */
class Handler {

	private HubServer server;

	private JSONValue additionalJson;
	private string socialJson; // already encoded

	public this(HubServer server, ServerInfo info/*, shared Query _query*/) {

		this.server = server;
		
		this.regenerateSocialJson();

		bool delegate(string ip) acceptIp; //TODO must be implemented by sel-server
		immutable forcedIp = server.config.hub.serverIp.toLower;
		if(forcedIp.length) {
			acceptIp = (string ip){ return ip.toLower == forcedIp; };
		} else {
			acceptIp = (string ip){ return true; };
		}

		// start handlers

		with(server.config.hub) {

			auto hncom = new HncomServer(server, &this.additionalJson);

			if(bedrock) {
				auto bedrock = new BedrockServer(server.eventLoop, server.info, server, server.config.hub.bedrock.protocols.dup);
				//TODO host
			}

			if(java) {
				auto java = new JavaServer(server.eventLoop, server.info, server, server.config.hub.java.protocols.dup);
				foreach(address ; server.config.hub.java.addresses) {
					java.host(address.ip, address.port);
				}
			}

		}

	}

	/**
	 * Regenerates the social json adding a string field
	 * for each social field that is not empty in the settings.
	 */
	private void regenerateSocialJson() {
		const config = this.server.config;
		this.socialJson = config.hub.social.toString();
		JSONValue[string] additional;
		additional["social"] = config.hub.social;
		additional["minecraft"] = ["edu": config.hub.edu];
		additional["software"] = ["name": Software.name, "version": Software.displayVersion];
		this.additionalJson = cast(shared)JSONValue(additional);
	}

	/**
	 * Closes the handlers and frees the resources.
	 */
	public void shutdown() {
		//TODO gracefully shutdown every thread
	}

}
