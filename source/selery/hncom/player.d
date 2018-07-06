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
 * Packets related to a player. The first field of every packet is an `hub id`
 * that uniquely identifies a player in the hub and never changes until it disconnects.
 * 
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/hncom/player.d, selery/hncom/player.d)
 */
module selery.hncom.player;

import selery.hncom.about;
import selery.hncom.io;

/**
 * Adds a player to the node.
 */
@clientbound class Add : HncomPacket {
	
	enum ubyte ID = 24;
	
	struct ServerAddress { string ip; ushort port; }
	
	struct Skin { string name; ubyte[] data; ubyte[] cape; string geometryName; ubyte[] geometryData; }
	
	// reason
	enum : ubyte {
		
		FIRST_JOIN = 0,				/// The player has been automatically put on this node because it's a non-full main node.
		TRANSFERRED = 1,			/// The player has been transferred to this node.
		FORCIBLY_TRANSFERRED = 2,	/// The player was on a node that has wrongly disconnected (probably crashing) and the player has been transferred to the first non-full main node.
		
	}
	
	// permission level
	enum : ubyte {
		
		USER = 0,
		OPERATOR = 1,
		HOST = 2,
		AUTOMATION = 3,
		ADMIN = 4,
		
	}
	
	// input mode
	enum : ubyte {
		
		KEYBOARD = 0,
		TOUCH = 1,
		CONTROLLER = 2,
		
	}
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Reason for which the player has been added to the node.
	 */
	ubyte reason;
	
	/**
	 * Optional data set by the Transfer packet if the player was transferred from another node.
	 * The content depends on the node's implementation or even by one of its plugins.
	 */
	ubyte[] transferMessage;
	
	/**
	 * Game used by the player, which could either be Minecraft: Java Edition or Minecraft (Bedrock Engine).
	 * It should be one of the keys given in NodeInfo's acceptedGames field.
	 */
	ubyte type;
	
	/**
	 * Version of the protocol used by the client. Should be contained in the list given
	 * to the hub in the NodeInfo's acceptedGames field.
	 */
	uint protocol;
	
	/**
	 * Client's UUID, given by Mojang's or Microsoft's services if the server is in
	 * online mode or given by the client (and not verified) if the server is in offline mode.
	 */
	HncomUUID uuid;
	
	/**
	 * Username of the player.
	 */
	string username;
	
	/**
	 * Display name of the player, which can contain formatting codes. By default it's equals
	 * to the username but it can be updated by the node using the UpdateDisplayName packet.
	 */
	string displayName;
	
	/**
	 * Name of the game played by the client; for example Minecraft or Minecraft: Java Edition.
	 */
	string gameName;
	
	/**
	 * Version of the game used by the client, usually in the format major.minor[.patch],
	 * calculated by the server or given by the client during the authentication process.
	 * The node should verify that the version exists and matches the protocol indicated
	 * in the protocol field.
	 */
	string gameVersion;
	
	/**
	 * Player's permission level that indicates its administration power. It's set to USER
	 * by default, which has no particular permission.
	 */
	ubyte permissionLevel;
	
	/**
	 * Dimension in which the player was playing before being transferred in the MCPE format
	 * (0: overworld, 1: nether, 2: end). It shouldn't be considered if the client just joined
	 * the server instead of being transferred.
	 */
	ubyte dimension;
	
	/**
	 * Client's view distance (or chunk radius).
	 */
	uint viewDistance;
	
	/**
	 * Remote address of the player.
	 */
	HncomAddress clientAddress;
	
	/**
	 * Address used by the client to connect to the server. The value of this field is the address
	 * the client has saved in its servers list. For example a client that joins through `localhost`
	 * and a client that joins through `127.0.0.1` will connect to the same server with the same ip
	 * but the field of this value will be different (`localhost` for the first client and
	 * `127.0.0.1` for the latter).
	 */
	ServerAddress serverAddress;
	
	/**
	 * Client's skin, given by the client or downloaded from Mojang's services in online mode.
	 */
	Skin skin;
	
	/**
	 * Client's language, in the same format as HubInfo's language field, which should be updated
	 * from the node when the client changes it.
	 */
	string language;
	
	/**
	 * Client's input mode. May be a controller, a mouse/keyboard set or a touch screen.
	 */
	ubyte inputMode;
	
	/**
	 * Additional JSON data.
	 * Example:
	 * ---
	 * // bedrock engine
	 * {
	 *    "edu": false,
	 *    "DeviceOS": 1,
	 *    "DeviceModel": "ONEPLUS A0001"
	 * }
	 * ---
	 */
	string gameData;
	
	mixin Make;
	
}

/**
 * Removes a player from the node.
 * If the player is removed using Kick or Transfer this packet is not sent.
 */
@clientbound class Remove : HncomPacket {
	
	enum ubyte ID = 25;
	
	// reason
	enum : ubyte {
		
		LEFT,			/// The player has closed the connection.
		TIMED_OUT,		/// The hub has closed the connection because didn't had any response from the client for too long.
		KICKED,			/// The player has been manually kicked.
		TRANSFERRED,	/// The player has been transferred by the hub
		
	}
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Reason of the disconnection.
	 */
	ubyte reason;
	
	mixin Make;
	
}

/**
 * Kicks a player from the node and the whole server. When a player is disconnected
 * from the node using this packet the hub will not send the Remove packet.
 */
@serverbound class Kick : HncomPacket {
	
	enum ubyte ID = 26;
	
	/**
	 * Player to be kicked.
	 */
	uint hubId;
	
	/**
	 * Reason of the disconnection that will be displayed in the client's
	 * disconnection screen.
	 */
	string reason;
	
	/**
	 * Whether the previous string should be translated client-side or not.
	 */
	bool translation;
	
	/**
	 * Optional parameters for the translation (Only for java clients).
	 */
	string[] parameters;
	
	mixin Make;
	
}

/**
 * Transfers a player to another node. When a player is transferred from the node the hub
 * will not send the Remove packet and there's no way, for the node, to know whether the
 * player was disconnected or successfully transferred, if not using messages through a
 * user-defined protocol.
 */
@serverbound class Transfer : HncomPacket {
	
	enum ubyte ID = 27;
	
	// on fail
	enum : ubyte {
		
		DISCONNECT = 0,		/// Disconnect with `End of Stream` message.
		AUTO = 1,			/// Connect to the first available node or disconnects if there isn't one.
		RECONNECT = 2,		/// Connect to the same node, but as a new player.
		
	}
	
	/**
	 * Player to be transferred.
	 */
	uint hubId;
	
	/**
	 * Id of the node that player will be transferred to. It should be an id of a
	 * connected node (which can be calculated using AddNode and RemoveNode packets),
	 * otherwise the player will be disconnected or moved to another node (see the following field).
	 */
	uint node;
	
	/**
	 * Optional data that will be always sent with the Add packet when the player is transferred.
	 * The content depends on the node's implementation or even by one of its plugins.
	 */
	ubyte[] message;
	
	/**
	 * Indicates the action to be taken when a transfer fails because the indicated node is
	 * not connected anymore or it cannot accept the given player's game type or protocol.
	 * If the indicated node is full the player will be simply disconnected with the `Server Full` message.
	 */
	ubyte onFail = DISCONNECT;
	
	mixin Make;
	
}

/**
 * Updates the player's display name when it is changed.
 * When this packet is sent by the node a copy is always sent back by the hub.
 */
@clientbound @serverbound class UpdateDisplayName : HncomPacket {
	
	enum ubyte ID = 28;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Player's display name that can contain formatting codes. Prefixes and suffixes should be avoided.
	 */
	string displayName;
	
	mixin Make;
	
}

/**
 * Updates the player's world. The player's dimension should be updated by
 * the hub using worldId to identify the world added with AddWorld and
 * removed with RemoveWorld.
 */
@serverbound class UpdateWorld : HncomPacket {
	
	enum ubyte ID = 29;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * World's id, that should have been previously added with the
	 * AddWorld packet.
	 */
	uint worldId;
	
	mixin Make;
	
}

/**
 * Update the player's permission level.
 * When this packet is sent by the node a copy is always sent back by the hub.
 */
@clientbound @serverbound class UpdatePermissionLevel : HncomPacket {
	
	enum ubyte ID = 30;
	
	// permission level
	enum : ubyte {
		
		USER = 0,
		OPERATOR = 1,
		HOST = 2,
		AUTOMATION = 3,
		ADMIN = 4,
		
	}
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	ubyte permissionLevel;
	
	mixin Make;
	
}

/**
 * Notifies the node that the player's view distance has been updated client-side.
 * The node may decide to not accept the new view distance and not send the required chunks.
 */
@clientbound class UpdateViewDistance : HncomPacket {
	
	enum ubyte ID = 31;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Player's new view distance as indicated by the client.
	 */
	uint viewDistance;
	
	mixin Make;
	
}

/**
 * Updates the player's language when the client changes it.
 */
@clientbound class UpdateLanguage : HncomPacket {
	
	enum ubyte ID = 32;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Player's language in the same format as HubInfo's language field.
	 */
	string language;
	
	mixin Make;
	
}

/**
 * Updates the latency between the player and the hub.
 */
@clientbound class UpdateLatency : HncomPacket {
	
	enum ubyte ID = 33;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Player's latency in milliseconds. The latency between the client and the
	 * node is then calculated adding the latency between the node and the hub
	 * to this field's value.
	 */
	uint latency;
	
	mixin Make;
	
}

/**
 * Updates the packet loss between the player and the hub.
 */
@clientbound class UpdatePacketLoss : HncomPacket {
	
	enum ubyte ID = 34;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	/**
	 * Percentage of lost packets, from 0% (no packet lost) to 100% (every
	 * packet lost).
	 */
	float packetLoss;
	
	mixin Make;
	
}

@clientbound @serverbound class GamePacket : HncomPacket {
	
	enum ubyte ID = 35;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	ubyte[] payload;
	
	mixin Make;
	
}

@serverbound class SerializedGamePacket : HncomPacket {
	
	enum ubyte ID = 36;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	ubyte[] payload;
	
	mixin Make;
	
}

@serverbound class OrderedGamePacket : HncomPacket {
	
	enum ubyte ID = 37;
	
	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	
	uint order;
	
	ubyte[] payload;
	
	mixin Make;
	
}
