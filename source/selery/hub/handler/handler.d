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
module selery.hub.handler.handler;

import std.json : JSONValue;
import std.socket : SocketException;
import std.string : toLower, indexOf, strip, split, join;

import sel.server.bedrock : BedrockServerImpl;
import sel.server.java : JavaServerImpl;
import sel.server.query : Query;
import sel.server.util : ServerInfo, GenericServer;

import selery.about;
import selery.config : Config;
import selery.format : Text;
import selery.hub.handler.hncom : HncomHandler, LiteNode;
import selery.hub.handler.rcon : RconHandler;
import selery.hub.handler.webadmin : WebAdminHandler;
import selery.hub.handler.webview : WebViewHandler;
import selery.hub.server : HubServer;
import selery.log : log, error_log;
import selery.util.thread : SafeThread;

/**
 * Main handler with the purpose of starting children handlers,
 * store constant informations and reload them when needed.
 */
class Handler {

	private shared HubServer server;

	private shared JSONValue additionalJson;
	private shared string socialJson; // already encoded

	private shared Reloadable[] reloadables;

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
					debug log(server.lang.translate("handler.listening", [Text.green ~ name ~ Text.reset, address.toString()]));
				} catch(SocketException e) {
					error_log(server.lang.translate("handler.error.bind", [name, address.toString(), (e.msg.indexOf(":")!=-1 ? e.msg.split(":")[$-1].strip : e.msg)]));
				} catch(Throwable t) {
					error_log(server.lang.translate("handler.error.address", [name, address.toString()]));
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

			if(webView) {
				auto s = new shared WebViewHandler(server, &this.socialJson);
				startGenericServer(s, "web_view", webViewAddresses);
				this.reloadables ~= s;
			}

			if(webAdmin) {
				auto s = new shared WebAdminHandler(server);
				startGenericServer(s, "web_admin", webAdminAddresses);
			}

		}

	}

	/**
	 * Reloads the resources that can be reloaded.
	 * Those resources are the social json (always reloaded) and
	 * the web's pages (index, icon and info) when the http handler
	 * is running (when the server has been started with "web-enabled"
	 * equals to true).
	 */
	public shared void reload() {
		this.regenerateSocialJson();
		foreach(reloadable ; this.reloadables) {
			reloadable.reload();
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
		additional["minecraft"] = ["edu": config.hub.edu, "realm": config.hub.realm];
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

interface Reloadable {

	public shared void reload();

}
