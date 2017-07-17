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
import std.json : JSONValue, JSON_TYPE;
import std.socket : Address;
import std.string : toLower, startsWith;
import std.uuid : UUID;

import sel.about;
import sel.entity.human : Skin;
import sel.hncom.about : __JAVA__, __POCKET__;
import sel.hncom.player : Add;
import sel.player.player : InputMode, DeviceOS;

/**
 * Generic informations about a player in the server.
 */
final class PlayerInfo {

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

	public Add.ServerAddress usedAddress;

	public string language;

	public Skin skin;

	public uint latency;
	public float packetLoss;

	public string gameEdition;
	public string gameVersion;
	public string game;

	public bool edu = false;

	public InputMode inputMode = InputMode.keyboard;
	public DeviceOS deviceOs = DeviceOS.unknown;
	public string deviceModel;
	public long xuid;

	public shared WorldInfo world;

	public this(uint hubId, ubyte type, uint protocol, string name, string displayName, UUID uuid, Address address, Add.ServerAddress usedAddress, string language, JSONValue data) {
		this.hubId = hubId;
		this.type = type;
		this.protocol = protocol;
		this.name = name;
		this.lname = name.toLower();
		this.displayName = displayName;
		this.uuid = uuid;
		this.address = address;
		this.ip = address.toAddrString();
		this.port = to!ushort(address.toPortString());
		this.usedAddress = usedAddress;
		this.language = language;
		if(data.type == JSON_TYPE.OBJECT) {
			if(type == __POCKET__) {
				this.edu = "edu" in data && data["edu"].type == JSON_TYPE.TRUE;
				auto gameVersion = "GameVersion" in data;
				if(gameVersion && gameVersion.type == JSON_TYPE.STRING) this.gameVersion = gameVersion.str;
				auto deviceOs = "DeviceOS" in data;
				if(deviceOs && deviceOs.type == JSON_TYPE.INTEGER && deviceOs.integer <= 9) this.deviceOs = cast(DeviceOS)deviceOs.integer;
				auto deviceModel = "DeviceModel" in data;
				if(deviceModel && deviceModel.type == JSON_TYPE.STRING) this.deviceModel = deviceModel.str;
			}
		}
		if(type == __JAVA__) {
			this.gameEdition = "Minecraft";
			this.gameVersion = supportedMinecraftProtocols[this.protocol][0];
		} else {
			this.gameEdition = "Minecraft: " ~ (this.edu ? "Education" : [
				DeviceOS.fireos: "Fire TV",
				DeviceOS.gearvr: "Gear VR",
				DeviceOS.win10: "Windows 10",
				DeviceOS.nx: "Switch",
			].get(this.deviceOs, "Pocket")) ~ " Edition";
			this.gameVersion = verifyVersion(this.gameVersion, supportedPocketProtocols[this.protocol]);
		}
		this.game = this.gameEdition ~ " " ~ this.gameVersion;
	}
	
	private static string verifyVersion(string given, string[] accepted) {
		foreach(acc ; accepted) {
			if(acc.startsWith(given) || given.startsWith(acc)) return given;
		}
		return accepted[0];
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
	public uint id;

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

	public this(uint id) {
		this.id = id;
	}

}
