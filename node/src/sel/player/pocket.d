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
module sel.player.pocket;

import etc.c.curl : CurlOption;

import std.algorithm : max, sort;
import std.conv : to;
import std.file : read, write, exists, mkdirRecurse;
import std.json;
import std.net.curl : get, HTTP, CurlException;
import std.process : executeShell;
import std.socket : Address;
import std.string : split, join, startsWith, replace, strip;
import std.system : Endian;
import std.typecons : Tuple;
import std.uuid : UUID;
import std.zlib : Compress, HeaderFormat;

import common.path : Paths;
import common.sel;

import nbt.stream;
import nbt.tags;

import sel.server : server;
import sel.settings;
import sel.block.block : Block, PlacedBlock;
import sel.block.tile : Tile;
import sel.entity.effect : Effect, Effects;
import sel.entity.entity : Entity;
import sel.entity.human : Skin;
import sel.entity.living : Living;
import sel.entity.metadata : SelMetadata = Metadata;
import sel.entity.noai : Lightning, ItemEntity;
import sel.item.inventory;
import sel.item.slot : Slot;
import sel.math.vector;
import sel.player.player;
import sel.util.command : Command;
import sel.util.lang;
import sel.util.log;
import sel.world.chunk : Chunk;
import sel.world.map : Map;
import sel.world.particle;
import sel.world.world : World;

import sul.utils.var : varuint;

abstract class PocketPlayer : Player {

	protected static Stream stream, networkStream;

	public static this() {
		stream = new ClassicStream!(Endian.littleEndian)();
		networkStream = new NetworkStream!(Endian.littleEndian)();
	}

	private bool n_edu;
	private long n_xuid;
	private ubyte n_os;
	private string n_device_model;
	
	private uint title_duration;
	private uint subtitle_duration;
	
	private BlockPosition[] broken_by_this;

	private string n_titles;

	protected bool send_commands;
	
	public this(uint hubId, Address address, string serverAddress, ushort serverPort, string name, string displayName, Skin skin, UUID uuid, string language, ubyte inputMode, uint latency, float packetLoss, long xuid, bool edu, ubyte deviceOs, string deviceModel) {
		super(hubId, null, EntityPosition(0), address, serverAddress, serverPort, name, displayName, skin, uuid, language, inputMode, latency);
		this.n_packet_loss = packetLoss;
		this.n_edu = edu;
		this.n_xuid = xuid;
		this.n_os = deviceOs;
		this.n_device_model = deviceModel;
	}
	
	public final override pure nothrow @property @safe @nogc ubyte gameVersion() {
		return PE;
	}

	/**
	 * Indicates whether or not the player is using Minecraft: Education
	 * Edition.
	 */
	public final pure nothrow @property @safe @nogc bool edu() {
		return this.n_edu;
	}

	/**
	 * Gets the player's XBOX user id.
	 * It's always the same value for the same user, if authenticated.
	 * It's 0 if the server is not in online mode.
	 * This value can be used to retrieve more informations about the
	 * player using the XBOX live services.
	 */
	public final pure nothrow @property @safe @nogc long xuid() {
		return this.n_xuid;
	}

	/**
	 * Gets the player's operative system, as indicated by the client
	 * in the login packet.
	 * Example:
	 * ---
	 * if(player.os != PlayerOS.android) {
	 *    player.kick("Only android players are allowed");
	 * }
	 * ---
	 */
	public final pure nothrow @property @safe @nogc ubyte os() {
		return this.n_os;
	}

	/**
	 * Gets the player's device model (name and identifier) as indicated
	 * by the client in the login packet.
	 * Example:
	 * ---
	 * if(!player.deviceModel.toLower.startsWith("oneplus")) {
	 *    player.kick("This server is reserved for oneplus users");
	 * }
	 */
	public final pure nothrow @property @safe @nogc string deviceModel() {
		return this.n_device_model;
	}

	public final override pure nothrow @property @safe @nogc byte dimension() {
		return this.world.dimension.pe;
	}

	alias operator = super.operator;

	public override @property bool operator(bool op) {
		if(super.operator(op) == op && this.send_commands) {
			this.sendCommands();
		}
		return op;
	}

	public override @trusted Command registerCommand(Command command) {
		super.registerCommand(command);
		if(this.send_commands) {
			this.sendCommands();
		}
		return command;
	}

	public override @trusted void unregisterCommand(Command command) {
		super.unregisterCommand(command);
		if(this.send_commands) {
			this.sendCommands();
		}
	}

	protected void sendCommands();


	// generic PE handlings
	
	protected override bool handleBlockBreaking() {
		BlockPosition position = this.breaking;
		if(super.handleBlockBreaking()) {
			this.broken_by_this ~= position;
			return true;
		} else {
			return false;
		}
	}
	
}

// send function are overwritten with static ifs
// handle functions are created for every version using static ifs
class PocketPlayerImpl(uint __protocol) : PocketPlayer {

	mixin("import Types = sul.protocol.pocket" ~ __protocol.to!string ~ ".types;");
	mixin("import Play = sul.protocol.pocket" ~ __protocol.to!string ~ ".play;");

	mixin("import sul.attributes.pocket" ~ __protocol.to!string ~ " : Attributes;");
	mixin("import sul.metadata.pocket" ~ __protocol.to!string ~ " : Metadata;");

	private static ubyte[] creative_inventory;

	public static bool loadCreativeInventory() {
		enum cached = Paths.hidden ~ "creative/" ~ __protocol.to!string;
		if(!exists(cached)) {
			try {
				auto http = HTTP();
				http.handle.set(CurlOption.ssl_verifypeer, false);
				http.handle.set(CurlOption.timeout, 5);
				Types.Slot[] slots;
				foreach(item ; parseJSON(get("https://raw.githubusercontent.com/sel-utils/sel-utils.github.io/master/json/creative/pocket" ~ __protocol.to!string ~ ".min.json", http).idup)["items"].array) {
					auto obj = item.object;
					auto meta = "meta" in obj;
					auto ench = "enchantments" in obj;
					auto slot = Types.Slot(obj["id"].integer.to!int, (meta ? (*meta).integer.to!int << 8 : 0) | 1);
					if(ench) {
						stream.buffer.length = 0;
						auto list = new Named!(ListOf!Compound)("ench");
						foreach(e ; (*ench).array) {
							auto eobj = e.object;
							list ~= new Compound(new Named!Short("id", eobj["id"].integer.to!short), new Named!Short("lvl", eobj["level"].integer.to!short));
						}
						stream.writeTag(new Compound(list));
						slot.nbt = stream.buffer.dup;
					}
					slots ~= slot;
				}
				ubyte[] encoded = new Play.ContainerSetContent(121, 0, slots).encode(); // warning! the 0 (3rd byte) shold be replaced with the entity's id when sending
				Compress c = new Compress(9);
				creative_inventory = cast(ubyte[])c.compress(varuint.encode(encoded.length.to!uint) ~ encoded);
				creative_inventory ~= cast(ubyte[])c.flush();
				mkdirRecurse(Paths.hidden ~ "creative");
				write(cached, creative_inventory);
				return true;
			} catch(CurlException e) {
				warning_log("Could not download creative inventory for pocket ", __protocol);
				return false;
			}
		} else {
			creative_inventory = cast(ubyte[])read(cached);
			return true;
		}
	}

	protected Types.BlockPosition toBlockPosition(BlockPosition vector) {
		return Types.BlockPosition(typeof(Types.BlockPosition.x)(vector.x), typeof(Types.BlockPosition.y)(vector.y), typeof(Types.BlockPosition.z)(vector.z));
	}

	protected BlockPosition fromBlockPosition(Types.BlockPosition blockPosition) {
		return BlockPosition(blockPosition.x, blockPosition.y, blockPosition.z);
	}

	protected Types.Slot toSlot(Slot slot) {
		if(slot.empty) {
			return Types.Slot(0);
		} else {
			stream.buffer.length = 0;
			if(!slot.empty && slot.item.pocketCompound !is null) {
				stream.writeTag(slot.item.pocketCompound);
			}
			return Types.Slot(slot.item.pocketId, slot.item.pocketMeta << 8 | slot.count, stream.buffer);
		}
	}

	protected Slot fromSlot(Types.Slot slot) {
		if(slot.id <= 0) {
			return Slot(null);
		} else {
			auto item = this.world.items.fromPocket(slot.id & ushort.max, (slot.metaAndCount >> 8) & ushort.max);
			if(slot.nbt.length) {
				stream.buffer = slot.nbt;
				//TODO verify that this is right
				auto tag = stream.readTag();
				if(cast(Compound)tag) item.parsePocketCompound(cast(Compound)tag);
			}
			return Slot(item, slot.metaAndCount & 255);
		}
	}

	protected Types.Slot[] toSlots(Slot[] slots) {
		Types.Slot[] ret = new Types.Slot[slots.length];
		foreach(i, slot; slots) {
			ret[i] = toSlot(slot);
		}
		return ret;
	}

	protected Slot[] fromSlots(Types.Slot[] slots) {
		Slot[] ret = new Slot[slots.length];
		foreach(i, slot; slots) {
			ret[i] = this.fromSlot(slot);
		}
		return ret;
	}

	protected Metadata metadataOf(SelMetadata metadata) {
		mixin("return metadata.pocket" ~ __protocol.to!string ~ ";");
	}

	private immutable string full_version;

	private bool has_creative_inventory = false;
	
	private Tuple!(string, string)[][][string] sent_commands; // [command][overload] = [(name, type), (name, type), ...]

	private ubyte[][] queue;
	private size_t total_queue_length = 0;
	
	public this(uint hubId, string hubVersion, Address address, string serverAddress, ushort serverPort, string name, string displayName, Skin skin, UUID uuid, string language, ubyte inputMode, uint latency, float packetLoss, long xuid, bool edu, ubyte deviceOs, string deviceModel) {
		super(hubId, address, serverAddress, serverPort, name, displayName, skin, uuid, language, inputMode, latency, packetLoss, xuid, edu, deviceOs, deviceModel);
		this.startCompression!Compression(hubId);
		this.full_version = "Minecraft: " ~ (edu ? "Education" : (deviceOs == PlayerOS.windows10 ? "Windows 10" : "Pocket")) ~ " Edition " ~ verifyVersion(hubVersion, supportedPocketProtocols[__protocol]);
	}

	public final override pure nothrow @property @safe @nogc uint protocol() {
		return __protocol;
	}

	public final override pure nothrow @property @safe @nogc string gameFullVersion() {
		return this.full_version;
	}

	protected void sendPacket(T)(T packet) if(is(T == ubyte[]) || is(typeof(T.encode))) {
		static if(is(T == ubyte[])) {
			alias buffer = packet;
		} else {
			ubyte[] buffer = packet.encode();
		}
		this.queue ~= buffer;
		this.total_queue_length += buffer.length;
	}

	public override void flush() {
		// since protocol 110 everything is compressed
		if(this.queue.length) {
			ubyte[] payload;
			size_t total;
			size_t total_bytes = 0;
			foreach(ubyte[] packet ; this.queue) {
				total++;
				total_bytes += packet.length;
				payload ~= varuint.encode(packet.length.to!uint);
				payload ~= packet;
				if(payload.length > 1048576) {
					// do not compress more than 1 MiB
					break;
				}
			}
			this.queue = this.queue[total..$];
			this.compress(payload);
			this.total_queue_length -= total_bytes;
			if(this.queue.length) this.flush();
		}
	}

	alias world = super.world;

	public override @property World world(World world) {
		this.send_commands = false; // world-related commands are removed but no packet is needed as they are updated at respawn
		return super.world(world);
	}

	public override void transfer(string ip, ushort port) {
		this.sendPacket(new Play.Transfer(ip, port));
	}

	public override void firstspawn() {
		super.firstspawn();
		this.recalculateSpeed();
	}

	protected override void sendCompletedMessages(string[] messages) {
		// unsupported
	}
	
	protected override void sendChatMessage(string message) {
		this.sendPacket(new Play.Text().new Raw(message));
	}
	
	protected override void sendTipMessage(string message) {
		this.sendPacket(new Play.SetTitle(Play.SetTitle.SET_ACTION_BAR, message));
	}

	protected override void sendTitleMessage(Title message) {
		this.sendPacket(new Play.SetTitle(Play.SetTitle.SET_TITLE, message.title));
		if(message.subtitle.length) this.sendPacket(new Play.SetTitle(Play.SetTitle.SET_SUBTITLE, message.subtitle));
		this.sendPacket(new Play.SetTitle(Play.SetTitle.SET_TIMINGS, "", message.fadeIn.to!uint, message.stay.to!uint, message.fadeOut.to!uint));
	}

	protected override void sendHideTitles() {
		this.sendPacket(new Play.SetTitle(Play.SetTitle.HIDE));
	}

	protected override void sendResetTitles() {
		this.sendPacket(new Play.SetTitle(Play.SetTitle.RESET));
	}

	public override void sendMovementUpdates(Entity[] entities) {
		foreach(Entity entity ; entities) {
			this.sendPacket(new Play.MoveEntity(entity.id, tuple!(typeof(Play.MoveEntity.position))(entity.position + [0, entity.eyeHeight, 0]), entity.anglePitch, entity.angleYaw, cast(Living)entity ? (cast(Living)entity).angleBodyYaw : entity.angleYaw, entity.onGround));
		}
	}
	
	public override void sendMotionUpdates(Entity[] entities) {
		foreach(Entity entity ; entities) {
			this.sendPacket(new Play.SetEntityMotion(entity.id, tuple!(typeof(Play.SetEntityMotion.motion))(entity.motion)));
		}
	}
	
	public override void spawnToItself() {
		//this.sendAddList([this]);
	}

	protected override void sendOpStatus() {
		this.sendSettingsPacket();
	}

	public override void sendGamemode() {
		this.sendPacket(new Play.SetPlayerGameType(this.gamemode == 3 ? 1 : this.gamemode));
		if(this.creative) {
			if(!this.has_creative_inventory) {
				this.sendPacketPayload(creative_inventory);
				this.has_creative_inventory = true;
			}
		} else if(this.spectator) {
			if(has_creative_inventory) {
				//TODO remove armor and inventory
				this.sendPacket(new Play.ContainerSetContent(121, this.id));
				this.has_creative_inventory = false;
			}
		}
		this.sendSettingsPacket();
	}
	
	public override void sendSpawnPosition() {
		this.sendPacket(new Play.SetSpawnPosition(0, toBlockPosition(cast(Vector3!int)this.spawn), true));
	}
	
	public override void sendAddList(Player[] players) {
		Types.PlayerList[] list;
		foreach(Player player ; players) {
			if(player.id != this.id) list ~= Types.PlayerList(player.uuid, player.id, player.displayName, Types.Skin(player.skin.name, player.skin.data.dup));
		}
		if(list.length) this.sendPacket(new Play.PlayerList().new Add(list));
	}

	public override void sendUpdateLatency(Player[] players) {}

	public override void sendRemoveList(Player[] players) {
		UUID[] uuids;
		foreach(Player player ; players) {
			if(player.id != this.id) uuids ~= player.uuid;
		}
		if(uuids.length) this.sendPacket(new Play.PlayerList().new Remove(uuids));
	}
	
	public override void sendMetadata(Entity entity) {
		this.sendPacket(new Play.SetEntityData(entity.id, metadataOf(entity.metadata)));
	}
	
	public override void sendChunk(Chunk chunk) {

		Types.ChunkData data;

		auto sections = chunk.sections;
		size_t[] keys = sections.keys;
		sort(keys);
		ubyte top = keys.length ? to!ubyte(keys[$-1] + 1) : 0;
		foreach(size_t i ; 0..top) {
			Types.Section section;
			auto section_ptr = i in sections;
			if(section_ptr) {
				auto s = *section_ptr;
				foreach(ubyte x ; 0..16) {
					foreach(ubyte z ; 0..16) {
						foreach(ubyte y ; 0..16) {
							auto ptr = s[x, y, z];
							if(ptr) {
								Block block = *ptr;
								section.blockIds[x << 8 | z << 4 | y] = block.pocketId != 0 ? block.pocketId : ubyte(248);
								if(block.pocketMeta != 0) section.blockMetas[x << 7 | z << 3 | y >> 1] |= to!ubyte(block.pocketMeta << (y % 2 == 1 ? 4 : 0));
							}
						}
					}
				}
				section.skyLight = s.skyLight;
				section.blockLight = s.blocksLight;
			} else {
				section.skyLight = 255;
				section.blockLight = 0;
			}
			data.sections ~= section;
		}
		//data.heights = chunk.lights;
		foreach(i, biome; chunk.biomes) {
			data.biomes[i] = biome.id;
		}
		//TODO extra data

		networkStream.buffer.length = 0;
		foreach(tile ; chunk.tiles) {
			if(tile.compound.pe !is null) {
				auto compound = tile.compound.pe.dup;
				compound["id"] = new String(tile.spawnId.pe);
				compound["x"] = new Int(tile.position.x);
				compound["y"] = new Int(tile.position.y);
				compound["z"] = new Int(tile.position.z);
				networkStream.writeTag(compound);
			}
		}
		data.blockEntities = networkStream.buffer;

		this.sendPacket(new Play.FullChunkData(tuple!(typeof(Play.FullChunkData.position))(chunk.position), data));

		/*if(chunk.translatable_tiles.length > 0) {
			foreach(Tile tile ; chunk.translatable_tiles) {
				if(tile.tags) this.sendTile(tile, true);
			}
		}*/
	}
	
	public override void unloadChunk(ChunkPosition pos) {
		// no UnloadChunk packet :(
	}

	public override void sendChangeDimension(group!byte from, group!byte to) {
		//if(from.pe == to.pe) this.sendPacket(new Play.ChangeDimension((to.pe + 1) % 3, typeof(Play.ChangeDimension.position)(0, 128, 0), true));
		if(from.pe != to.pe) this.sendPacket(new Play.ChangeDimension(to.pe));
	}
	
	public override void sendInventory(ubyte flag=PlayerInventory.ALL, bool[] slots=[]) {
		//slot only
		foreach(ushort index, bool slot; slots) {
			if(slot) {
				//TODO if slot is in the hotbar the third argument should not be 0
				this.sendPacket(new Play.ContainerSetSlot(Windows.INVENTORY.pe, index, 0, toSlot(this.inventory[index])));
			}
		}
		//normal inventory
		if((flag & PlayerInventory.INVENTORY) > 0) {
			this.sendPacket(new Play.ContainerSetContent(0, this.id, toSlots(this.inventory[]), [9, 10, 11, 12, 13, 14, 15, 16, 17]));
		}
		//armour
		if((flag & PlayerInventory.ARMOR) > 0) {
			this.sendPacket(new Play.ContainerSetContent(120, this.id, toSlots(this.inventory.armor[]), new int[0]));
		}
		//held item
		if((flag & PlayerInventory.HELD) > 0) this.sendHeld();
	}
	
	public override void sendHeld() {
		this.sendPacket(new Play.ContainerSetSlot(0, this.inventory.hotbar[this.inventory.selected] + 9, this.inventory.selected, toSlot(this.inventory.held)));
	}
	
	public override void sendEntityEquipment(Player player) {
		this.sendPacket(new Play.MobEquipment(player.id, toSlot(player.inventory.held), cast(ubyte)0, cast(ubyte)0, cast(ubyte)0));
	}
	
	public override void sendArmorEquipment(Player player) {
		this.sendPacket(new Play.MobArmorEquipment(player.id, [toSlot(player.inventory.helmet), toSlot(player.inventory.chestplate), toSlot(player.inventory.leggings), toSlot(player.inventory.boots)]));
	}
	
	public override void sendOpenContainer(ubyte type, ushort slots, BlockPosition position) {
		//TODO
		//this.sendPacket(new PocketContainerOpen(to!ubyte(type + 1), type, slots, position));
	}
	
	public override void sendHurtAnimation(Entity entity) {
		this.sendEntityEvent(entity, Play.EntityEvent.HURT_ANIMATION);
	}
	
	public override void sendDeathAnimation(Entity entity) {
		this.sendEntityEvent(entity, Play.EntityEvent.DEATH_ANIMATION);
	}

	private void sendEntityEvent(Entity entity, typeof(Play.EntityEvent.eventId) evid) {
		this.sendPacket(new Play.EntityEvent(entity.id, evid));
	}
	
	protected override void sendDeathSequence() {
		this.sendPacket(new Play.SetHealth(0));
		this.sendRespawnPacket();
	}
	
	protected override @trusted void experienceUpdated() {
		auto attributes = [
			Types.Attribute(Attributes.experience.min, Attributes.experience.max, this.experience, Attributes.experience.def, Attributes.experience.name),
			Types.Attribute(Attributes.level.min, Attributes.level.max, this.level, Attributes.level.def, Attributes.level.name)
		];
		this.sendPacket(new Play.UpdateAttributes(this.id, attributes));
	}

	protected override void sendPosition() {
		this.sendPacket(new Play.MovePlayer(this.id, tuple!(typeof(Play.MovePlayer.position))(this.position), this.pitch, this.bodyYaw, this.yaw, Play.MovePlayer.ROTATION, this.onGround));
	}

	protected override void sendMotion(EntityPosition motion) {
		this.sendPacket(new Play.SetEntityMotion(this.id, tuple!(typeof(Play.SetEntityMotion.motion))(motion)));
	}

	public override void sendSpawnEntity(Entity entity) {
		if(cast(Player)entity) this.sendAddPlayer(cast(Player)entity);
		else if(cast(ItemEntity)entity) this.sendAddItemEntity(cast(ItemEntity)entity);
		else if(entity.pocket) this.sendAddEntity(entity);
	}

	public override void sendDespawnEntity(Entity entity) {
		this.sendPacket(new Play.RemoveEntity(entity.id));
	}
	
	protected void sendAddPlayer(Player player) {
		this.sendPacket(new Play.AddPlayer(player.uuid, player.name, player.id, player.id, tuple!(typeof(Play.AddPlayer.position))(player.position), tuple!(typeof(Play.AddPlayer.motion))(player.motion), player.pitch, player.bodyYaw, player.yaw, toSlot(player.inventory.held), metadataOf(player.metadata)));
	}
	
	protected void sendAddItemEntity(ItemEntity item) {
		this.sendPacket(new Play.AddItemEntity(item.id, item.id, toSlot(item.item), tuple!(typeof(Play.AddItemEntity.position))(item.position), tuple!(typeof(Play.AddItemEntity.motion))(item.motion)));
		this.sendMetadata(item);
	}
	
	protected void sendAddEntity(Entity entity) {
		this.sendPacket(new Play.AddEntity(entity.id, entity.id, entity.pocketId, tuple!(typeof(Play.AddEntity.position))(entity.position), tuple!(typeof(Play.AddEntity.motion))(entity.motion), entity.pitch, entity.yaw, new Types.Attribute[0], metadataOf(entity.metadata), typeof(Play.AddEntity.links).init));
	}

	public override @trusted void healthUpdated() {
		super.healthUpdated();
		auto attributes = [
			Types.Attribute(Attributes.health.min, this.maxHealthNoAbs, this.healthNoAbs, Attributes.health.def, Attributes.health.name),
			Types.Attribute(Attributes.absorption.min, this.maxAbsorption, this.absorption, Attributes.absorption.def, Attributes.absorption.name)
		];
		this.sendPacket(new Play.UpdateAttributes(this.id, attributes));
	}
	
	public override @trusted void hungerUpdated() {
		super.hungerUpdated();
		auto attributes = [
			Types.Attribute(Attributes.hunger.min, Attributes.hunger.max, this.hunger, Attributes.hunger.def, Attributes.hunger.name),
			Types.Attribute(Attributes.saturation.min, Attributes.saturation.max, this.saturation, Attributes.saturation.def, Attributes.saturation.name)
		];
		this.sendPacket(new Play.UpdateAttributes(this.id, attributes));
	}
	
	protected override void onEffectAdded(Effect effect, bool modified) {
		if(effect.pocket) this.sendPacket(new Play.MobEffect(this.id, modified ? Play.MobEffect.MODIFY : Play.MobEffect.ADD, effect.pocket.id, effect.level, true, cast(int)effect.duration));
	}

	protected override void onEffectRemoved(Effect effect) {
		if(effect.pocket) this.sendPacket(new Play.MobEffect(this.id, Play.MobEffect.REMOVE, effect.pocket.id, effect.level));
	}
	
	public override void recalculateSpeed() {
		super.recalculateSpeed();
		this.sendPacket(new Play.UpdateAttributes(this.id, [Types.Attribute(Attributes.speed.min, Attributes.speed.max, this.speed, Attributes.speed.def, Attributes.speed.name)]));
	}
	
	public override void sendJoinPacket() {
		// send thunders if enabled
		this.sendPacket(new Play.StartGame(this.id, this.id, tuple!(typeof(Play.StartGame.position))(this.position), this.yaw, this.pitch, this.world.seed, this.world.dimension.pe, this.world.type=="flat"?2:1, this.gamemode == 3 ? 1 : this.gamemode, this.world.rules.difficulty, tuple!(typeof(Play.StartGame.spawnPosition))(cast(Vector3!int)this.spawn), false, this.world.time.to!uint, server.settings.edu, this.world.downfall?this.world.weather.intensity:0, 0, !server.settings.realm, false, new Types.Rule[0], Software.display, server.name));
	}
	
	public override void sendTimePacket() {
		this.sendPacket(new Play.SetTime(this.world.time.to!uint));
		this.sendPacket(new Play.GameRulesChanged([Types.Rule(Types.Rule.DO_DAYLIGHT_CYCLE, this.world.rules.daylightCycle)]));
	}
	
	public override void sendDifficultyPacket() {
		this.sendPacket(new Play.SetDifficulty(this.world.rules.difficulty));
	}
	
	public override void sendSettingsPacket() {
		uint flags = Play.AdventureSettings.EVP_DISABLED; // player vs environment is disabled and the animation is done by server
		if(this.world.rules.immutableWorld || this.adventure || this.spectator) flags |= Play.AdventureSettings.IMMUTABLE_WORLD;
		if(!this.world.rules.pvp || this.spectator) flags |= Play.AdventureSettings.PVP_DISABLED;
		if(!this.world.rules.pvm || this.spectator) flags |= Play.AdventureSettings.PVM_DISABLED;
		if(this.creative || this.spectator) flags |= Play.AdventureSettings.ALLOW_FLIGHT;
		//if(this.spectator) flags |= Play.AdventureSettings.NO_CLIP;
		//if(this.spectator) flags |= Play.AdventureSettings.FLYING;
		this.sendPacket(new Play.AdventureSettings(flags, this.op ? Play.AdventureSettings.OPERATOR : Play.AdventureSettings.USER));
	}
	
	public override void sendRespawnPacket() {
		this.sendPacket(new Play.Respawn(tuple!(typeof(Play.Respawn.position))(this.spawn + [0, this.eyeHeight, 0])));
	}
	
	public override void setAsReadyToSpawn() {
		this.sendPacket(new Play.PlayStatus(Play.PlayStatus.SPAWNED));
		this.sendPacket(new Play.ResourcePacksInfo(false)); //TODO custom texture packs
		this.send_commands = true;
		this.sendCommands();
	}
	
	public override void sendWeather() {
		if(!this.world.downfall) {
			this.sendLevelEvent(Play.LevelEvent.STOP_RAIN, EntityPosition(0), 0);
			this.sendLevelEvent(Play.LevelEvent.STOP_THUNDER, EntityPosition(0), 0);
		} else {
			this.sendLevelEvent(Play.LevelEvent.START_RAIN, EntityPosition(0), to!uint(/*this.world.weather.rain +*/ (this.world.weather.intensity /*- 1*/) * 24000));
			this.sendLevelEvent(Play.LevelEvent.START_THUNDER, EntityPosition(0), this.world.weather.rain.to!uint);
		}
	}

	private void sendLevelEvent(typeof(Play.LevelEvent.eventId) evid, EntityPosition position, uint data) {
		this.sendPacket(new Play.LevelEvent(evid, tuple!(typeof(Play.LevelEvent.position))(position), data));
	}
	
	public override void sendLightning(Lightning lightning) {
		this.sendAddEntity(lightning);
	}
	
	public override void sendAnimation(Entity entity) {
		this.sendPacket(new Play.Animate(Play.Animate.BREAKING, entity.id));
	}
	
	public override void sendParticle(Particle particle) {
		/*ushort evid = to!ushort(particle.peid >= 2000 ? particle.peid : particle.peid | constant!"LEVEL_EVENT_ADD_PARTICLE");
		foreach(uint i ; 0..particle.count) {
			this.sendLevelEvent(evid, particle.position, particle.pedata);
		}*/
	}

	public override void sendBlocks(PlacedBlock[] blocks) {
		foreach(PlacedBlock block ; blocks) {
			this.sendPacket(new Play.UpdateBlock(toBlockPosition(block.position), block.pocketId, 176 | block.pocketMeta));
		}
		this.broken_by_this.length = 0;
	}
	
	public override void sendTile(Tile tile, bool translatable) {
		if(translatable) {
			//TODO
			//tile.to!ITranslatable.translateStrings(this.lang);
		}
		auto packet = new Play.BlockEntityData(toBlockPosition(tile.position));
		if(tile.compound.pe !is null) {
			networkStream.buffer.length = 0;
			networkStream.writeTag(tile.compound.pe);
			packet.nbt = networkStream.buffer;
		} else {
			packet.nbt ~= NBT_TYPE.END;
		}
		this.sendPacket(packet);
		/*if(translatable) {
			tile.to!ITranslatable.untranslateStrings();
		}*/
	}
	
	public override void sendPickupItem(Entity picker, Entity picked) {
		this.sendPacket(new Play.TakeItemEntity(picked.id, picker.id));
	}
	
	public override void sendPassenger(ubyte mode, uint passenger, uint vehicle) {
		this.sendPacket(new Play.SetEntityLink(passenger, vehicle, mode));
	}
	
	public override void sendExplosion(EntityPosition position, float radius, Vector3!byte[] updates) {
		Types.BlockPosition[] upd;
		foreach(Vector3!byte u ; updates) {
			upd ~= toBlockPosition(cast(Vector3!int)u);
		}
		this.sendPacket(new Play.Explode(tuple!(typeof(Play.Explode.position))(position), radius, upd));
	}
	
	public override void sendMap(Map map) {
		//TODO implement this!
		//this.sendPacket(map.pecompression.length > 0 ? new PocketBatch(map.pecompression) : map.pocketpacket);
	}

	public override void sendMusic(EntityPosition position, ubyte instrument, uint pitch) {
		this.sendPacket(new Play.LevelSoundEvent(Play.LevelSoundEvent.NOTE, tuple!(typeof(Play.LevelSoundEvent.position))(position), instrument, pitch, false));
	}

	protected override void sendCommands() {
		this.sent_commands.clear();
		JSONValue[string] json;
		foreach(command ; this.commands_not_aliases) {
			if(command.command != "*" && (!command.op || this.op)) {
				JSONValue[string] current;
				current["permission"] = "any";
				if(command.aliases.length) {
					current["aliases"] = command.aliases;
				}
				JSONValue[string] overloads;
				foreach(i, overload; command.overloads) {
					Tuple!(string, string)[] sent_params;
					JSONValue[] params;
					foreach(j, name; overload.params) {
						auto name_type = Tuple!(string, string)(translate(name, this.lang, []), overload.pocketTypeOf(j));
						sent_params ~= name_type;
						JSONValue[string] p;
						p["name"] = name_type[0];
						p["type"] = name_type[1];
						if(j >= overload.requiredArgs) p["optional"] = true;
						if(overload.pocketTypeOf(i) == "stringenum") p["enum_values"] = overload.enumMembers(j);
						params ~= JSONValue(p);
					}
					foreach(cmd ; command.command ~ command.aliases) this.sent_commands[cmd] ~= sent_params;
					overloads[to!string(i)] = JSONValue([
						"input": ["parameters": JSONValue(params)],
						"output": (JSONValue[string]).init
					]);
				}
				current["overloads"] = overloads;
				if(command.hidden) {
					current["is_hidden"] = true;
				}
				json[command.command] = JSONValue(["versions": [JSONValue(current)]]);
			}
		}
		this.sendPacket(new Play.AvailableCommands(JSONValue(json).toString()));

	}

	mixin generateHandlers!(Play.Packets);

	protected void handleResourcePackClientResponsePacket(ubyte status, string[] resourcePackVersion) {}

	protected void handleTextChatPacket(string sender, string message) {
		this.handleTextMessage(message);
	}

	protected void handleMovePlayerPacket(long eid, typeof(Play.MovePlayer.position) position, float pitch, float bodyYaw, float yaw, ubyte mode, bool onGround) {
		position.y -= this.eyeHeight;
		this.handleMovementPacket(vector!(EntityPosition)(position), yaw, bodyYaw, pitch);
	}

	protected void handleRiderJumpPacket(long eid) {}


	protected void handleRemoveBlockPacket(Types.BlockPosition position) {
		this.handleStartBlockBreaking(fromBlockPosition(position));
	}

	protected void handleLevelSoundEventPacket(ubyte sound, typeof(Play.LevelSoundEvent.position) position, uint volume, int pitch, bool u) {}

	protected void handleEntityEventPacket(long eid, ubyte evid, int unknown) {
		if(evid == Play.EntityEvent.USE_ITEM) {
			//TODO
		}
	}

	protected void handleMobEquipmentPacket(long eid, Types.Slot item, ubyte inventorySlot, ubyte hotbarSlot, ubyte unknown) {
		/+if(hotbarSlot < 9) {
			if(inventorySlot == 255) {
				// empty
				this.inventory.hotbar[hotbarSlot] = 255;
			} else {
				inventorySlot -= 9;
				if(inventorySlot < this.inventory.length) {
					if(this.inventory.hotbar.hotbar.canFind(hotbarSlot)) {
						// switch item
						auto s = this.inventory.hotbar[hotbarSlot];
						log("switching ", s, " with ", inventorySlot);
						if(s == inventorySlot) {
							// just selecting
						} else {
							// idk what to do
						}
					} else {
						// just move
						this.inventory.hotbar[hotbarSlot] = inventorySlot;
					}
				}
			}
			this.inventory.selected = hotbarSlot;
		}
		foreach(i ; this.inventory.hotbar) {
			log(i == 255 ? "null" : to!string(this.inventory[i]));
		}+/
	}
	
	//protected void handleMobArmorEquipmentPacket(long eid, Types.Slot[4] armor) {}

	protected void handleInteractPacket(ubyte action, long target) {
		switch(action) {
			case Play.Interact.ATTACK:
				this.handleAttack(cast(uint)target);
				break;
			case Play.Interact.INTERACT:
				this.handleAttack(cast(uint)target);
				break;
			case Play.Interact.LEAVE_VEHICLE:
				//TODO
				break;
			case Play.Interact.HOVER:
				//TODO
				break;
			default:
				break;
		}
	}

	//protected void handleUseItemPacket(Types.BlockPosition blockPosition, uint hotbarSlot, uint face, typeof(Play.UseItem.facePosition) facePosition, typeof(Play.UseItem.position) position, int slot, Types.Slot item) {}

	protected void handlePlayerActionPacket(long eid, typeof(Play.PlayerAction.action) action, Types.BlockPosition position, int face) {
		switch(action) {
			case Play.PlayerAction.START_BREAK:
				this.handleStartBlockBreaking(fromBlockPosition(position));
				break;
			case Play.PlayerAction.ABORT_BREAK:
				this.handleAbortBlockBreaking();
				break;
			case Play.PlayerAction.STOP_BREAK:
				this.handleBlockBreaking();
				break;
			case Play.PlayerAction.RELEASE_ITEM:
				this.handleReleaseItem();
				break;
			case Play.PlayerAction.STOP_SLEEPING:
				this.handleStopSleeping();
				break;
			case Play.PlayerAction.RESPAWN:
				this.handleRespawn();
				break;
			case Play.PlayerAction.JUMP:
				this.handleJump();
				break;
			case Play.PlayerAction.START_SPRINT:
				this.handleSprinting(true);
				if(Effects.speed in this) this.recalculateSpeed();
				break;
			case Play.PlayerAction.STOP_SPRINT:
				this.handleSprinting(false);
				if(Effects.speed in this) this.recalculateSpeed();
				break;
			case Play.PlayerAction.START_SNEAK:
				this.handleSneaking(true);
				break;
			case Play.PlayerAction.STOP_SNEAK:
				this.handleSneaking(false);
				break;
			case Play.PlayerAction.START_GLIDING:
				//TODO
				break;
			case Play.PlayerAction.STOP_GLIDING:
				//TODO
				break;
			default:
				break;
		}
	}

	//protected void handlePlayerFallPacket(float distance) {}

	protected void handleAnimatePacket(uint action, long eid) {
		if(action == Play.Animate.BREAKING) this.handleArmSwing();
	}

	//protected void handleDropItemPacket(ubyte type, Types.Slot slot) {}

	//protected void handleInventoryActionPacket(uint action, Types.Slot item) {}

	//protected void handleContainerSetSlotPacket(ubyte window, uint slot, uint hotbar_slot, Types.Slot item, ubyte unknown) {}

	//protected void handleCraftingEventPacket(ubyte window, uint type, UUID uuid, Types.Slot[] input, Types.Slot[] output) {}

	protected void handleAdventureSettingsPacket(uint flags, uint permission) {
		if(flags & Play.AdventureSettings.FLYING) {
			if(!this.creative && !this.spectator) this.kick("Flying is not enabled on this server");
		}
	}

	//protected void handlePlayerInputPacket(typeof(Play.PlayerInput.motion) motion, ushort flags, bool unknown) {}

	protected void handleSetPlayerGameTypePacket(int gamemode) {
		if(this.op && gamemode >= 0 && gamemode <= 2) {
			this.gamemode = gamemode & 2;
		} else {
			this.sendGamemode();
		}
	}

	//protected void handleMapInfoRequestPacket(long mapId) {}

	protected void handleRequestChunkRadiusPacket(uint radius) {
		this.viewDistance = radius;
		this.world.playerUpdateRadius(this);
		this.sendPacket(new Play.ChunkRadiusUpdated(this.viewDistance.to!uint));
	}

	//protected void handleReplaceSelectedItemPacket(Types.Slot slot) {}

	//protected void handleShowCreditsPacket(ubyte[] payload) {}

	protected void handleCommandStepPacket(string command, string overload_str, uint u1, uint u2, bool isOutput, ulong u3, string input, string output) {
		auto cmd = command in this.sent_commands;
		if(cmd) {
			try {
				auto overload = to!size_t(overload_str);
				if(overload < (*cmd).length) {
					auto data = parseJSON(input);
					string[] args;
					if(data.type == JSON_TYPE.OBJECT) {
						auto obj = data.object;
						foreach(param ; (*cmd)[overload]) {
							auto search = param[0] in obj;
							if(search) {
								switch(param[1]) {
									case "int":
										args ~= (*search).integer.to!string;
										break;
									case "float":
										if((*search).type == JSON_TYPE.INTEGER) args ~= (*search).integer.to!string;
										else args ~= (*search).floating.to!string;
										break;
									case "bool":
										args ~= (*search).type == JSON_TYPE.TRUE ? "true" : "false";
										break;
									case "blockpos":
										auto bp = (*search).object;
										args ~= [bp["x"].integer.to!string, bp["y"].integer.to!string, bp["z"].integer.to!string];
										break;
									case "target":
										auto rules = "rules" in *search;
										auto selector = "selector" in *search;
										size_t expected = args.length + 1;
										if(rules && (*rules).type == JSON_TYPE.ARRAY) {
											auto array = (*rules).array;
											if(array.length == 1 && array[0].type == JSON_TYPE.OBJECT) {
												auto name = "value" in array[0].object;
												if(name && (*name).type == JSON_TYPE.STRING) {
													args ~= (*name).str.replace(" ", "-");
												}
											}
										} else if(selector && (*selector).type == JSON_TYPE.STRING) {
											auto list = this.watchlist!Player;
											if(list.length) {
												switch((*selector).str) {
													case "nearestPlayer":
														args ~= "@p";
														break;
													case "randomPlayer":
														args ~= "@r";
														break;
													default:
														break;
												}
											} else {
												args ~= this.cname;
											}
										}
										if(args.length != expected) {
											args ~= "";
										}
										break;
									default:
										args ~= (*search).str;
										break;
								}
							} else {
								break;
							}
						}
					}
					this.callCommandOverload(command, overload, args.idup);
				}
			} catch(Exception) {}
		}
	}
	
	enum string stringof = "PocketPlayer!" ~ to!string(__protocol);

	private static class Compression : Player.Compression {

		protected override ubyte[] compress(ubyte[] payload) {
			ubyte[] data;
			Compress compress = new Compress(6, HeaderFormat.deflate); //TODO smaller level for smaller payloads
			data ~= cast(ubyte[])compress.compress(payload);
			data ~= cast(ubyte[])compress.flush();
			return data;
		}

	}
	
}
