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
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hub/handler/handler.d, selery/hub/handler/handler.d)
 */
module selery.hub.handler.handler;

import std.json : JSONValue;
import std.socket : SocketException;
import std.string : toLower, indexOf, strip, split, join;

import sel.format : Format;
import sel.server.bedrock : BedrockServerImpl;
import sel.server.java : JavaServerImpl;
import sel.server.query : Query;
import sel.server.util : ServerInfo, GenericServer;

import selery.about;
import selery.config : Config;
import selery.hub.handler.hncom : HncomHandler, LiteNode;
import selery.hub.handler.rcon : RconHandler;
import selery.hub.handler.webadmin : WebAdminHandler;
import selery.hub.server : HubServer;
import selery.lang : Translation;
import selery.util.thread : SafeThread;

/**
 * Main handler with the purpose of starting children handlers,
 * store constant informations and reload them when needed.
 */
class Handler {

	private shared HubServer server;

	private shared JSONValue additionalJson;
	private shared string socialJson; // already encoded

	public shared this(shared HubServer server, shared ServerInfo info, shared Query _query) {

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

		void startGenericServer(shared GenericServer gs, string name, const(Config.Hub.Address)[] addresses) {
			foreach(address ; addresses) {
				try {
					gs.start(address.ip, address.port, _query);
					debug server.logger.log(Translation("handler.listening", [Format.green ~ name ~ Format.reset, address.toString()]));
				} catch(SocketException e) {
					server.logger.logError(Translation("handler.error.bind", [name, address.toString(), (e.msg.indexOf(":")!=-1 ? e.msg.split(":")[$-1].strip : e.msg)]));
				} catch(Throwable t) {
					server.logger.logError(Translation("handler.error.address", [name, address.toString()]));
				}
			}
		}

		with(server.config.hub) {

			if(!server.lite) {
				auto s = new shared HncomHandler(server, &this.additionalJson);
				s.start(acceptedNodes, hncomPort);
			} else {
				new SafeThread(server.config.lang, { new shared LiteNode(server, &this.additionalJson); }).start();
			}

			if(bedrock) {
				auto s = new shared BedrockServerImpl!supportedBedrockProtocols(info, server);
				startGenericServer(s, "bedrock", bedrock.addresses);
			}

			if(java) {
				auto s = new shared JavaServerImpl!supportedJavaProtocols(info, server);
				startGenericServer(s, "java", java.addresses);
			}

			if(rcon) {
				auto s = new shared RconHandler(server);
				startGenericServer(s, "rcon", rconAddresses);
			}

			if(webAdmin) {
				auto s = new shared WebAdminHandler(server);
				startGenericServer(s, "web_admin", webAdminAddresses);
			}

		}

	}

	/**
	 * Regenerates the social json adding a string field
	 * for each social field that is not empty in the settings.
	 */
	private shared void regenerateSocialJson() {
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
	public shared void shutdown() {
		//TODO gracefully shutdown every thread
	}

}

deprecated("Server is never reloaded") interface Reloadable {

	public shared void reload();

}
