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
module selery.node.info;

import std.concurrency : Tid;
import std.conv : to;
import std.json : JSONValue, JSON_TYPE;
import std.socket : Address;
import std.string : toLower, startsWith;
import std.uuid : UUID;

import sel.hncom.about : __BEDROCK__, __JAVA__;
import sel.hncom.player : Add;

import selery.about;
import selery.entity.human : Skin;
import selery.player.player : InputMode, DeviceOS, PermissionLevel;

/**
 * Generic informations about a player in the server.
 */
final class PlayerInfo {

	/**
	 * Player's id assigned by the hub and unique for the player's session.
	 */
	public immutable uint hubId;

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

	public Add.ServerAddress usedAddress;

	public string language;

	public Skin skin;

	public PermissionLevel permissionLevel;

	public uint latency;
	public float packetLoss;

	public string gameName;
	public string gameVersion;
	public string game;

	public bool edu = false;

	public InputMode inputMode;
	public DeviceOS deviceOs = DeviceOS.unknown;
	public string deviceModel;
	public long xuid;

	public shared WorldInfo world; // should never be null after initialised by the first Player construction

	public this(Add add) {
		this.hubId = add.hubId;
		this.type = add.type;
		this.protocol = add.protocol;
		this.name = add.username;
		this.lname = add.username.toLower();
		this.displayName = add.displayName;
		this.uuid = add.uuid;
		this.permissionLevel = cast(PermissionLevel)add.permissionLevel;
		this.address = add.clientAddress;
		this.ip = add.clientAddress.toAddrString();
		this.port = to!ushort(add.clientAddress.toPortString());
		this.usedAddress = add.serverAddress;
		this.language = add.language;
		this.inputMode = cast(InputMode)add.inputMode;
		this.gameName = add.gameName;
		this.gameVersion = add.gameVersion;
		if(add.gameData.type == JSON_TYPE.OBJECT) {
			if(type == __BEDROCK__) {
				this.edu = "edu" in add.gameData && add.gameData["edu"].type == JSON_TYPE.TRUE;
				auto deviceOs = "DeviceOS" in add.gameData;
				if(deviceOs && deviceOs.type == JSON_TYPE.INTEGER && deviceOs.integer <= 9) this.deviceOs = cast(DeviceOS)deviceOs.integer;
				auto deviceModel = "DeviceModel" in add.gameData;
				if(deviceModel && deviceModel.type == JSON_TYPE.STRING) this.deviceModel = deviceModel.str;
			}
		}
		this.game = this.gameName ~ " " ~ this.gameVersion;
	}

}

/**
 * Generic information about a world.
 */
final class WorldInfo {

	/**
	 * World's id, may be given by the server (for main worlds) or by the
	 * parent world (children worlds).
	 */
	public immutable uint id;

	/**
	 * World's name, which is given by the user who creates the world.
	 * It may not be unique on the node. Children worlds have the same id
	 * as their parent's.
	 */
	public immutable string name;

	/**
	 * Thread where the world exists.
	 * Children worlds inherit the tid from their parents.
	 */
	public Tid tid;

	/**
	 * Number of entities (players included), players and chunks
	 * in the world (children's not included) for statistic purposes.
	 */
	public size_t entities, players, chunks;

	public shared(WorldInfo) parent = null;
	public shared(WorldInfo)[uint] children;

	public this(uint id, string name) {
		this.id = id;
		this.name = name;
	}

}
