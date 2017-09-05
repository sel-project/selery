/*
 * Copyright (c) 2017 SEL
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
module selery.player.pocket;

import std.algorithm : min, sort, canFind;
import std.base64 : Base64;
import std.conv : to;
import std.digest.digest : toHexString;
import std.digest.sha : sha256Of;
import std.json;
import std.string : split, join, startsWith, replace, strip, toLower;
import std.system : Endian;
import std.typecons : Tuple;
import std.uuid : UUID;
import std.zlib : Compress, HeaderFormat;

import sel.nbt.stream;
import sel.nbt.tags;

import selery.about;
import selery.block.block : Block, PlacedBlock;
import selery.block.tile : Tile;
import selery.command.args : CommandArg;
import selery.command.command : Command, Position, Target;
import selery.command.util : PocketType;
import selery.effect : Effect, Effects;
import selery.entity.entity : Entity;
import selery.entity.human : Skin;
import selery.entity.living : Living;
import selery.entity.metadata : SelMetadata = Metadata;
import selery.entity.noai : Lightning, ItemEntity;
import selery.files : Files;
import selery.format : Text;
import selery.inventory.inventory;
import selery.item.slot : Slot;
import selery.lang : Translation, translate;
import selery.log;
import selery.math.vector;
import selery.node.info : PlayerInfo;
import selery.player.player;
import selery.world.chunk : Chunk;
import selery.world.map : Map;
import selery.world.world : Gamemode, Difficulty, Dimension, World;

import sul.utils.var : varuint;

abstract class PocketPlayer : Player {

	protected static Stream stream, networkStream;

	protected static ubyte[][] resourcePackChunks;
	protected static size_t resourcePackSize;
	protected static string resourcePackId;
	protected static string resourcePackHash;

	public static this() {
		stream = new ClassicStream!(Endian.littleEndian)();
		networkStream = new NetworkStream!(Endian.littleEndian)();
	}

	public static void updateResourcePacks(UUID uuid, void[] rp) {
		for(size_t i=0; i<rp.length; i+=4096) {
			resourcePackChunks ~= cast(ubyte[])rp[i..min($, i+4096)];
		}
		resourcePackSize = rp.length;
		resourcePackId = uuid.toString();
		resourcePackHash = toLower(toHexString(sha256Of(rp)));
	}

	private bool n_edu;
	private long n_xuid;
	private ubyte n_os;
	private string n_device_model;
	
	private BlockPosition[] broken_by_this;

	protected bool send_commands;
	
	public this(shared PlayerInfo info, World world, EntityPosition position) {
		super(info, world, position);
		if(resourcePackId.length == 0) {
			// no resource pack
			this.hasResourcePack = true;
		}
	}

	/**
	 * Gets the player's XBOX user id.
	 * It's always the same value for the same user, if authenticated.
	 * It's 0 if the server is not in online mode.
	 * This value can be used to retrieve more informations about the
	 * player using the XBOX live services.
	 */
	public final pure nothrow @property @trusted @nogc long xuid() {
		return this.info.xuid;
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
	public final pure nothrow @property @trusted @nogc DeviceOS deviceOs() {
		return this.info.deviceOs;
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
	public final pure nothrow @property @trusted @nogc string deviceModel() {
		return this.info.deviceModel;
	}

	public final override void disconnectImpl(const Translation translation, string[] args) {
		if(translation.pocket.length) {
			this.server.kick(this.hubId, translation.pocket, args);
		} else {
			this.disconnect(this.server.config.lang.translate(translation, this.language, args));
		}
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

	public override @trusted bool unregisterCommand(Command command) {
		immutable ret = super.unregisterCommand(command);
		if(ret && this.send_commands) {
			this.sendCommands();
		}
		return ret;
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
class PocketPlayerImpl(uint __protocol) : PocketPlayer if(supportedPocketProtocols.keys.canFind(__protocol)) {

	mixin("import Types = sul.protocol.pocket" ~ __protocol.to!string ~ ".types;");
	mixin("import Play = sul.protocol.pocket" ~ __protocol.to!string ~ ".play;");

	mixin("import sul.attributes.pocket" ~ __protocol.to!string ~ " : Attributes;");
	mixin("import sul.metadata.pocket" ~ __protocol.to!string ~ " : Metadata;");

	private static __gshared ubyte[] creative_inventory;

	public static bool loadCreativeInventory(const Files files) {
		immutable cached = "creative_" ~ __protocol.to!string;
		if(!files.hasTemp(cached)) {
			immutable asset = "creative/" ~ __protocol.to!string ~ ".json";
			if(!files.hasAsset(asset)) return false;
			static if(__protocol < 120) auto packet = new Play.ContainerSetContent(121, 0);
			else auto packet = new Play.InventoryContent(121);
			foreach(item ; parseJSON(cast(string)files.readAsset(asset))["items"].array) {
				auto obj = item.object;
				auto meta = "meta" in obj;
				auto nbt = "nbt" in obj;
				auto ench = "enchantments" in obj;
				packet.slots ~= Types.Slot(obj["id"].integer.to!int, (meta ? (*meta).integer.to!int << 8 : 0) | 1, nbt && nbt.str.length ? Base64.decode(nbt.str) : []);
			}
			ubyte[] encoded = packet.encode();
			Compress c = new Compress(9);
			creative_inventory = cast(ubyte[])c.compress(varuint.encode(encoded.length.to!uint) ~ encoded);
			creative_inventory ~= cast(ubyte[])c.flush();
			files.writeTemp(cached, creative_inventory);
		} else {
			creative_inventory = cast(ubyte[])files.readTemp(cached);
		}
		return true;
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

	public static Types.McpeUuid toUUID(UUID uuid) {
		ubyte[8] msb, lsb;
		foreach(i ; 0..8) {
			msb[i] = uuid.data[i];
			lsb[i] = uuid.data[i+8];
		}
		import std.bitmanip : bigEndianToNative;
		return Types.McpeUuid(bigEndianToNative!long(msb), bigEndianToNative!long(lsb));
	} 

	public static uint convertGamemode(uint gamemode) {
		if(gamemode == 3) return 1;
		else return gamemode;
	}

	public static Metadata metadataOf(SelMetadata metadata) {
		mixin("return metadata.pocket" ~ __protocol.to!string ~ ";");
	}

	private bool has_creative_inventory = false;
	
	private Tuple!(string, PocketType)[][][string] sent_commands; // [command][overload] = [(name, type), (name, type), ...]

	private ubyte[][] queue;
	private size_t total_queue_length = 0;
	
	public this(shared PlayerInfo info, World world, EntityPosition position) {
		super(info, world, position);
		this.startCompression!Compression(hubId);
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
		enum padding = [ubyte(0), ubyte(0)];
		// since protocol 110 everything is compressed
		if(this.queue.length) {
			ubyte[] payload;
			size_t total;
			size_t total_bytes = 0;
			foreach(ubyte[] packet ; this.queue) {
				static if(__protocol >= 120) packet = packet[0] ~ padding ~ packet[1..$];
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

	protected override void sendMessageImpl(string message) {
		this.sendPacket(new Play.Text().new Raw(message));
	}
	
	protected override void sendTranslationImpl(const Translation message, string[] args, Text[] formats) {
		string pre;
		foreach(format ; formats) {
			pre ~= format;
		}
		if(message.pocket.length) {
			this.sendPacket(new Play.Text().new Translation(pre ~ "%" ~ message.pocket, args));
		} else {
			this.sendMessageImpl(pre ~ this.server.config.lang.translate(message, this.language, args));
		}
	}

	protected override void sendCompletedMessages(string[] messages) {
		// unsupported
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
			this.sendPacket(new Play.MoveEntity(entity.id, (cast(Vector3!float)(entity.position + [0, entity.eyeHeight, 0])).tuple, entity.anglePitch, entity.angleYaw, cast(Living)entity ? (cast(Living)entity).angleBodyYaw : entity.angleYaw, entity.onGround));
		}
	}
	
	public override void sendMotionUpdates(Entity[] entities) {
		foreach(Entity entity ; entities) {
			this.sendPacket(new Play.SetEntityMotion(entity.id, (cast(Vector3!float)entity.motion).tuple));
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
				static if(__protocol < 120) this.sendPacket(new Play.ContainerSetContent(121, this.id));
				else this.sendPacket(new Play.InventoryContent(121));
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
			list ~= Types.PlayerList(toUUID(player.uuid), player.id, player.displayName, Types.Skin(player.skin.name, player.skin.data.dup, player.skin.cape.dup, player.skin.geometryName, player.skin.geometryData.dup));
		}
		if(list.length) this.sendPacket(new Play.PlayerList().new Add(list));
	}

	public override void sendUpdateLatency(Player[] players) {}

	public override void sendRemoveList(Player[] players) {
		Types.McpeUuid[] uuids;
		foreach(Player player ; players) {
			uuids ~= toUUID(player.uuid);
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
				static if(__protocol < 120) {
					section.skyLight = s.skyLight;
					section.blockLight = s.blocksLight;
				}
			} else {
				static if(__protocol < 120) {
					section.skyLight = 255;
					section.blockLight = 0;
				}
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
			if(tile.pocketCompound !is null) {
				auto compound = tile.pocketCompound.dup;
				compound["id"] = new String(tile.pocketSpawnId);
				compound["x"] = new Int(tile.position.x);
				compound["y"] = new Int(tile.position.y);
				compound["z"] = new Int(tile.position.z);
				networkStream.writeTag(compound);
			}
		}
		data.blockEntities = networkStream.buffer;

		this.sendPacket(new Play.FullChunkData(chunk.position.tuple, data));

		/*if(chunk.translatable_tiles.length > 0) {
			foreach(Tile tile ; chunk.translatable_tiles) {
				if(tile.tags) this.sendTile(tile, true);
			}
		}*/
	}
	
	public override void unloadChunk(ChunkPosition pos) {
		// no UnloadChunk packet :(
	}

	public override void sendChangeDimension(Dimension from, Dimension to) {
		//if(from == to) this.sendPacket(new Play.ChangeDimension((to + 1) % 3, typeof(Play.ChangeDimension.position)(0, 128, 0), true));
		if(from != to) this.sendPacket(new Play.ChangeDimension(to));
	}
	
	public override void sendInventory(ubyte flag=PlayerInventory.ALL, bool[] slots=[]) {
		//slot only
		foreach(ushort index, bool slot; slots) {
			if(slot) {
				//TODO if slot is in the hotbar the third argument should not be 0
				static if(__protocol < 120) this.sendPacket(new Play.ContainerSetSlot(0, index, 0, toSlot(this.inventory[index])));
				//else this.sendPacket(new Play.InventorySlot(0, index, 0, toSlot(this.inventory[index])));
			}
		}
		//normal inventory
		if((flag & PlayerInventory.INVENTORY) > 0) {
			static if(__protocol < 120) this.sendPacket(new Play.ContainerSetContent(0, this.id, toSlots(this.inventory[]), [9, 10, 11, 12, 13, 14, 15, 16, 17]));
			else this.sendPacket(new Play.InventoryContent(0, toSlots(this.inventory[])));
		}
		//armour
		if((flag & PlayerInventory.ARMOR) > 0) {
			static if(__protocol < 120) this.sendPacket(new Play.ContainerSetContent(120, this.id, toSlots(this.inventory.armor[]), new int[0]));
			else this.sendPacket(new Play.InventoryContent(120, toSlots(this.inventory.armor[])));
		}
		//held item
		if((flag & PlayerInventory.HELD) > 0) this.sendHeld();
	}
	
	public override void sendHeld() {
		static if(__protocol < 120) this.sendPacket(new Play.ContainerSetSlot(0, this.inventory.hotbar[this.inventory.selected] + 9, this.inventory.selected, toSlot(this.inventory.held)));
		//else this.sendPacket(new Play.InventorySlot(0, this.inventory.hotbar[this.inventory.selected] + 9, this.inventory.selected, toSlot(this.inventory.held)));
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
		this.sendPacket(new Play.MovePlayer(this.id, (cast(Vector3!float)this.position).tuple, this.pitch, this.bodyYaw, this.yaw, Play.MovePlayer.TELEPORT, this.onGround));
	}

	protected override void sendMotion(EntityPosition motion) {
		this.sendPacket(new Play.SetEntityMotion(this.id, (cast(Vector3!float)motion).tuple));
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
		this.sendPacket(new Play.AddPlayer(toUUID(player.uuid), player.name, player.id, player.id, (cast(Vector3!float)player.position).tuple, (cast(Vector3!float)player.motion).tuple, player.pitch, player.bodyYaw, player.yaw, toSlot(player.inventory.held), metadataOf(player.metadata)));
	}
	
	protected void sendAddItemEntity(ItemEntity item) {
		this.sendPacket(new Play.AddItemEntity(item.id, item.id, toSlot(item.item), (cast(Vector3!float)item.position).tuple, (cast(Vector3!float)item.motion).tuple, metadataOf(item.metadata)));
	}
	
	protected void sendAddEntity(Entity entity) {
		this.sendPacket(new Play.AddEntity(entity.id, entity.id, entity.pocketId, (cast(Vector3!float)entity.position).tuple, (cast(Vector3!float)entity.motion).tuple, entity.pitch, entity.yaw, new Types.Attribute[0], metadataOf(entity.metadata), typeof(Play.AddEntity.links).init));
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
		//TODO send thunders
		auto packet = new Play.StartGame(this.id, this.id);
		packet.gamemode = convertGamemode(this.gamemode);
		packet.position = (cast(Vector3!float)this.position).tuple;
		packet.yaw = this.yaw;
		packet.pitch = this.pitch;
		packet.seed = this.world.seed;
		packet.dimension = this.world.dimension;
		packet.generator = this.world.type=="flat" ? 2 : 1;
		packet.worldGamemode = convertGamemode(this.world.gamemode);
		packet.difficulty = this.world.difficulty;
		packet.spawnPosition = (cast(Vector3!int)this.spawn).tuple;
		packet.time = this.world.time.to!uint;
		packet.vers = this.server.config.hub.edu;
		packet.rainLevel = this.world.weather.raining ? this.world.weather.intensity : 0;
		packet.commandsEnabled = !this.server.config.hub.realm;
		static if(__protocol >= 120) packet.permissionLevel = this.op ? 1 : 0;
		packet.levelId = Software.display;
		packet.worldName = this.server.name;
		this.sendPacket(packet);
	}

	public override void sendResourcePack() {}
	
	public override void sendDifficulty(Difficulty difficulty) {
		this.sendPacket(new Play.SetDifficulty(difficulty));
	}

	public override void sendWorldGamemode(Gamemode gamemode) {
		this.sendPacket(new Play.SetDefaultGameType(convertGamemode(gamemode)));
	}

	public override void sendDoDaylightCycle(bool cycle) {
		this.sendGamerule(Types.Rule.DO_DAYLIGHT_CYCLE, cycle);
	}
	
	public override void sendTime(uint time) {
		this.sendPacket(new Play.SetTime(time));
	}
	
	public override void sendWeather(bool raining, bool thunderous, uint time, uint intensity) {
		if(raining) {
			this.sendLevelEvent(Play.LevelEvent.START_RAIN, EntityPosition(0), intensity * 24000);
			if(thunderous) this.sendLevelEvent(Play.LevelEvent.START_THUNDER, EntityPosition(0), time);
			else this.sendLevelEvent(Play.LevelEvent.STOP_THUNDER, EntityPosition(0), 0);
		} else {
			this.sendLevelEvent(Play.LevelEvent.STOP_RAIN, EntityPosition(0), 0);
			this.sendLevelEvent(Play.LevelEvent.STOP_THUNDER, EntityPosition(0), 0);
		}
	}
	
	public override void sendSettingsPacket() {
		uint flags = Play.AdventureSettings.EVP_DISABLED; // player vs environment is disabled and the animation is done by server
		if(this.adventure || this.spectator) flags |= Play.AdventureSettings.IMMUTABLE_WORLD;
		if(!this.world.pvp || this.spectator) flags |= Play.AdventureSettings.PVP_DISABLED;
		if(this.spectator) flags |= Play.AdventureSettings.PVM_DISABLED;
		if(this.creative || this.spectator) flags |= Play.AdventureSettings.ALLOW_FLIGHT;
		if(this.spectator) flags |= Play.AdventureSettings.NO_CLIP;
		if(this.spectator) flags |= Play.AdventureSettings.FLYING;
		this.sendPacket(new Play.AdventureSettings(flags, this.op ? Play.AdventureSettings.LEVEL_OPERATOR : Play.AdventureSettings.LEVEL_USER));
	}
	
	public override void sendRespawnPacket() {
		this.sendPacket(new Play.Respawn((cast(Vector3!float)(this.spawn + [0, this.eyeHeight, 0])).tuple));
	}
	
	public override void setAsReadyToSpawn() {
		this.sendPacket(new Play.PlayStatus(Play.PlayStatus.SPAWNED));
		if(!this.hasResourcePack) {
			// require custom texture
			this.sendPacket(new Play.ResourcePacksInfo(true, new Types.PackWithSize[0], [Types.PackWithSize(resourcePackId, Software.fullVersion, resourcePackSize)]));
		} else if(resourcePackChunks.length == 0) {
			// no resource pack
			this.sendPacket(new Play.ResourcePacksInfo(false));
		}
		this.send_commands = true;
		this.sendCommands();
	}

	private void sendLevelEvent(typeof(Play.LevelEvent.eventId) evid, EntityPosition position, uint data) {
		this.sendPacket(new Play.LevelEvent(evid, (cast(Vector3!float)position).tuple, data));
	}
	
	public override void sendLightning(Lightning lightning) {
		this.sendAddEntity(lightning);
	}
	
	public override void sendAnimation(Entity entity) {
		this.sendPacket(new Play.Animate(Play.Animate.BREAKING, entity.id));
	}

	public override void sendBlocks(PlacedBlock[] blocks) {
		foreach(PlacedBlock block ; blocks) {
			this.sendPacket(new Play.UpdateBlock(toBlockPosition(block.position), block.pocket.id, 176 | block.pocket.meta));
		}
		this.broken_by_this.length = 0;
	}
	
	public override void sendTile(Tile tile, bool translatable) {
		if(translatable) {
			//TODO
			//tile.to!ITranslatable.translateStrings(this.lang);
		}
		auto packet = new Play.BlockEntityData(toBlockPosition(tile.position));
		if(tile.pocketCompound !is null) {
			networkStream.buffer.length = 0;
			networkStream.writeTag(tile.pocketCompound);
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
		this.sendPacket(new Play.Explode((cast(Vector3!float)position).tuple, radius, upd));
	}
	
	public override void sendMap(Map map) {
		//TODO implement this!
		//this.sendPacket(map.pecompression.length > 0 ? new PocketBatch(map.pecompression) : map.pocketpacket);
	}

	public override void sendMusic(EntityPosition position, ubyte instrument, uint pitch) {
		this.sendPacket(new Play.LevelSoundEvent(Play.LevelSoundEvent.NOTE, (cast(Vector3!float)position).tuple, instrument, pitch, false));
	}

	protected override void sendCommands() {
		this.sent_commands.clear();
		auto packet = new Play.AvailableCommands();
		ushort addValue(string value) {
			foreach(ushort i, v; packet.enumValues) {
				if(v == value) return i;
			}
			packet.enumValues ~= value;
			return cast(ushort)(packet.enumValues.length - 1);
		}
		uint addEnum(string name, inout(string)[] values) {
			foreach(uint i, enum_; packet.enums) {
				if(enum_.name == name) return i;
			}
			auto enum_ = Types.Enum(name);
			foreach(value ; values) {
				enum_.valuesIndexes ~= addValue(value);
			}
			packet.enums ~= enum_;
			return packet.enums.length.to!uint - 1;
		}
		foreach(command ; this.availableCommands) {
			if(!command.hidden) {
				auto pc = Types.Command(command.name, command.description.isTranslation ? (command.description.translation.pocket.length ? command.description.translation.pocket : this.server.config.lang.translate(command.description.translation, this.language)) : command.description.message);
				if(command.aliases.length) {
					pc.aliasesEnum = addEnum(command.name ~ ".aliases", command.aliases);
				}
				foreach(overload ; command.overloads) {
					Types.Overload po;
					foreach(i, name; overload.params) {
						auto parameter = Types.Parameter(name, Types.Parameter.VALID, i >= overload.requiredArgs);
						parameter.type |= {
							final switch(overload.pocketTypeOf(i)) with(Types.Parameter) {
								case PocketType.integer: return INT;
								case PocketType.floating: return FLOAT;
								case PocketType.target: return TARGET;
								case PocketType.string: return STRING;
								case PocketType.blockpos: return POSITION;
								case PocketType.rawtext: return RAWTEXT;
								case PocketType.stringenum: return ENUM | addEnum(overload.typeOf(i), overload.enumMembers(i));
								case PocketType.boolean: return ENUM | addEnum("bool", ["true", "false"]);
							}
						}();
						po.parameters ~= parameter;
					}
					pc.overloads ~= po;
				}
				packet.commands ~= pc;
			}
		}
		if(packet.enumValues.length > 0 && packet.enumValues.length < 257) packet.enumValues.length = 257; //TODO fix protocol
		this.sendPacket(packet);
	}

	// generic

	private void sendGamerule(const string name, bool value) {
		this.sendPacket(new Play.GameRulesChanged([Types.Rule(name, Types.Rule.BOOLEAN, value)]));
	}

	mixin generateHandlers!(Play.Packets);

	protected void handleResourcePackClientResponsePacket(ubyte status, string[] packIds) {
		if(resourcePackId.length) {
			// only handle if the server has a resource pack to serve
			if(status == Play.ResourcePackClientResponse.SEND_PACKS) {
				this.sendPacket(new Play.ResourcePackDataInfo(resourcePackId, 4096u, resourcePackChunks.length.to!uint, resourcePackSize, resourcePackHash));
				foreach(uint i, chunk; resourcePackChunks) {
					this.sendPacket(new Play.ResourcePackChunkData(resourcePackId, i, i*4096u, chunk));
				}
			} else {
				//TODO
			}
		}
	}

	protected void handleResourcePackChunkDataRequestPacket(string id, uint index) {
		//TODO send chunk
	}

	protected void handleTextChatPacket(bool unknown1, string sender, string message, string xuid) {
		this.handleTextMessage(message);
	}

	protected void handleMovePlayerPacket(long eid, typeof(Play.MovePlayer.position) position, float pitch, float bodyYaw, float yaw, ubyte mode, bool onGround, long unknown7, int unknown8, int unknown9) {
		position.y -= this.eyeHeight;
		this.handleMovementPacket(cast(EntityPosition)Vector3!float(position), yaw, bodyYaw, pitch);
	}

	protected void handleRiderJumpPacket(long eid) {}

	//protected void handleLevelSoundEventPacket(ubyte sound, typeof(Play.LevelSoundEvent.position) position, uint volume, int pitch, bool u1, bool u2) {}

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

	protected void handleInteractPacket(ubyte action, long target, typeof(Play.Interact.targetPosition) position) {
		switch(action) {
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

	protected void handleAnimatePacket(uint action, long eid, float unknown2) {
		if(action == Play.Animate.BREAKING) this.handleArmSwing();
	}

	//protected void handleDropItemPacket(ubyte type, Types.Slot slot) {}

	//protected void handleInventoryActionPacket(uint action, Types.Slot item) {}

	//protected void handleContainerSetSlotPacket(ubyte window, uint slot, uint hotbar_slot, Types.Slot item, ubyte unknown) {}

	//protected void handleCraftingEventPacket(ubyte window, uint type, UUID uuid, Types.Slot[] input, Types.Slot[] output) {}

	protected void handleAdventureSettingsPacket(uint flags, uint unknown1, uint permissions, uint permissionLevel, uint customPermissions, long eid) {
		if(flags & Play.AdventureSettings.FLYING) {
			if(!this.creative && !this.spectator) this.kick("Flying is not enabled on this server");
			//TODO set as flying
		}
	}

	//protected void handlePlayerInputPacket(typeof(Play.PlayerInput.motion) motion, ushort flags, bool unknown) {}

	protected void handleSetPlayerGameTypePacket(int gamemode) {
		if(this.op && gamemode >= 0 && gamemode <= 2) {
			this.gamemode = gamemode & 0b11;
		} else {
			this.sendGamemode();
		}
	}

	//protected void handleMapInfoRequestPacket(long mapId) {}

	//protected void handleReplaceSelectedItemPacket(Types.Slot slot) {}

	//protected void handleShowCreditsPacket(ubyte[] payload) {}

	protected void handleCommandRequestPacket(string command, uint type, string requestId, uint playerId) {
		if(command.startsWith("/")) command = command[1..$];
		if(command.length) {
			this.callCommand(command);
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
