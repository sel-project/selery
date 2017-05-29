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
module sel.node.info;

import std.concurrency : Tid;
import std.conv : to;
import std.socket : Address;
import std.string : toLower;
import std.uuid : UUID;

import sel.entity.human : Skin;
import sel.util.hncom : HncomPlayer;

class PlayerInfo {

	/**
	 * Player's id assigned by the hub and unique for the player's session.
	 */
	public uint hubId;

	/**
	 * Indicates whether the player is still connected to the server.
	 */
	public bool online = true;

	public ubyte type;
	public uint protocol;
	public string version_;

	public string name, lname, displayName;

	public UUID uuid;

	public Address address;
	public string ip;
	public ushort port;

	public string usedIp;
	public ushort usedPort;

	public string language;

	public Skin skin;

	public uint latency;
	public float packetLoss;

	public ubyte inputMode;

	union Additional {
		HncomPlayer.Add.Pocket pocket;
		HncomPlayer.Add.Minecraft minecraft;
		HncomPlayer.Add.Console console;
	}
	public Additional additional;

	public shared WorldInfo world;

	public this(uint hubId, ubyte type, uint protocol, string version_, string name, string displayName, UUID uuid, Address address, string usedIp, ushort usedPort, string language) {
		this.hubId = hubId;
		this.type = type;
		this.protocol = protocol;
		this.version_ = version_;
		this.name = name;
		this.lname = name.toLower();
		this.displayName = displayName;
		this.uuid = uuid;
		this.address = address;
		this.ip = address.toAddrString();
		this.port = to!ushort(address.toPortString());
		this.usedIp = usedIp;
		this.usedPort = usedPort;
		this.language = language;
	}

}

class WorldInfo {
	
	public uint id;

	public Tid tid;

	public size_t entities, players;

	public this(uint id) {
		this.id = id;
	}

}
