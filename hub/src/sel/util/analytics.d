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
module sel.util.analytics;

import std.algorithm : min;
import std.net.curl : post;
import std.string : join;
import std.typecons : Tuple, tuple;
import std.uri : encodeComponent;

import sel.about;
import sel.session.player : Player = PlayerSession;
import sel.util.thread : SafeThread;

class GoogleAnalytics {

	private immutable string app;

	private shared string[] requestQueue;

	private shared bool sending;
	private shared Tuple!(string, string)[] postRequestQueue;

	public shared this(string app) {
		this.app = app;
	}

	public shared void addPlayer(shared Player player) {
		this.genericRequest(player, ["sc=start"]);
	}

	public shared void removePlayer(shared Player player) {
		this.genericRequest(player, ["sc=end"]);
	}

	public shared void updatePlayers(shared Player[] players) {
		foreach(player ; players) {
			if(player.world !is null) this.genericRequest(player, ["t=screenview", "cd=" ~ player.world.name]);
		}
	}

	private shared void genericRequest(shared Player player, string[] data) {
		this.requestQueue ~= "v=1&tid=" ~ this.app ~
				"&uid=" ~ encodeComponent(player.iusername) ~
				"&an=" ~ encodeComponent(player.gameName) ~
				"&av=" ~ player.gameVersion ~
				"&uip=" ~ player.address.toAddrString() ~
				"&ua=" ~ encodeComponent(Software.display ~ " (" ~ (player.type == PE ? "Android" : "Windows") ~ ")") ~
				"&dr=" ~ player.serverAddress ~
				(player.language.length ? "ul=" ~ player.language : "") ~
				"&" ~ data.join("&");
	}

	public shared void sendRequests() {
		if(this.requestQueue.length) {
			if(this.requestQueue.length == 1) {
				this.sendRequestsImpl("collect", this.requestQueue[0]);
			} else {
				for(size_t i=0; i<this.requestQueue.length; i+=20) {
					this.sendRequestsImpl("batch", this.requestQueue[0..min($, i+20)].join("\r\n"));
				}
			}
			this.requestQueue.length = 0;
		}
	}

	private shared void sendRequestsImpl(string type, string data) {
		if(!this.sending) {
			sending = true;
			new SafeThread("googleAnalytics", {
				post("www.google-analytics.com/" ~ type, data);
				while(this.postRequestQueue.length) {
					auto next = this.postRequestQueue[0];
					this.postRequestQueue = this.postRequestQueue[1..$];
					post("www.google-analytics.com/" ~ next[0], next[1]);
				}
			}).start();
			sending = false;
		} else {
			this.postRequestQueue ~= tuple(type, data);
		}
	}

}
