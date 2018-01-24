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
module selery.player.java;

import std.algorithm : sort, min, canFind, clamp;
import std.conv : to;
import std.digest.digest : toHexString;
import std.digest.sha : sha1Of;
import std.json : JSONValue;
import std.math : abs, log2, ceil;
import std.socket : Address;
import std.string : split, join, toLower;
import std.system : Endian;
import std.uuid : UUID;
import std.zlib : Compress, HeaderFormat;

import sel.nbt.stream;
import sel.nbt.tags;

import selery.about;
import selery.block.block : Block, PlacedBlock;
import selery.block.tile : Tile;
import selery.config : Gamemode, Difficulty, Dimension;
import selery.effect : Effect;
import selery.entity.entity : Entity;
import selery.entity.human : Skin;
import selery.entity.living : Living;
import selery.entity.metadata : SelMetadata = Metadata;
import selery.entity.noai : ItemEntity, Lightning;
import selery.event.world.player : PlayerMoveEvent;
import selery.inventory.inventory;
import selery.item.slot : Slot;
import selery.lang : Translation;
import selery.log : Format, Message;
import selery.math.vector;
import selery.node.info : PlayerInfo;
import selery.player.player;
import selery.util.util : array_index;
import selery.world.chunk : Chunk;
import selery.world.map : Map;
import selery.world.world : World;

import sul.utils.var : varuint;

abstract class JavaPlayer : Player {

	protected static string resourcePack, resourcePackPort, resourcePack2Hash, resourcePack3Hash;
	
	public static ulong ulongPosition(BlockPosition position) {
		return (to!long(position.x & 0x3FFFFFF) << 38) | (to!long(position.y & 0xFFF) << 26) | (position.z & 0x3FFFFFF);
	}
	
	public static BlockPosition blockPosition(ulong position) {
		int nval(uint num) {
			if((num & 0x3000000) == 0) return num;
			else return -(num ^ 0x3FFFFFF) - 1;
		}
		return BlockPosition(nval((position >> 38) & 0x3FFFFFF), (position >> 26) & 0xFFF, nval(position & 0x3FFFFFF));
	}
	
	protected static byte convertDimension(Dimension dimension) {
		with(Dimension) final switch(dimension) {
			case overworld: return 0;
			case nether: return -1;
			case end: return 1;
		}
	}

	public static void updateResourcePacks(void[] rp2, void[] rp3, string url, ushort port) {
		resourcePack = url;
		resourcePackPort = ":" ~ to!string(port);
		resourcePack2Hash = toLower(toHexString(sha1Of(rp2)));
		resourcePack3Hash = toLower(toHexString(sha1Of(rp3)));
	}

	private bool consuming;
	private uint consuming_time;
	
	private bool first_spawned;
	
	private ushort[] loaded_maps;
	
	public this(shared PlayerInfo info, World world, EntityPosition position) {
		super(info, world, position);
		if(resourcePack.length == 0) {
			// no resource pack
			this.hasResourcePack = true;
		}
	}
	
	public override void tick() {
		super.tick();
		if(this.consuming) {
			if(++this.consuming_time == 30) {
				this.consuming_time = 0;
				if(!this.consumeItemInHand()) {
					this.consuming = false;
				}
			}
		}
	}
	
	alias world = super.world;
	
	public override @property @trusted World world(World world) {
		this.loaded_maps.length = 0;
		return super.world(world);
	}

	public final override void disconnectImpl(const Translation translation) {
		if(translation.translatable.java.length) {
			this.server.kick(this.hubId, translation.translatable.java, translation.parameters);
		} else {
			this.disconnect(this.server.lang.translate(translation, this.language));
		}
	}
	
	/**
	 * Encodes a message into a JSONValue that can be parsed and displayed
	 * by the client.
	 * More info on the format: wiki.vg/Chat
	 */
	public JSONValue encodeMessage(Message[] messages) {
		JSONValue[] array;
		JSONValue[string] current_format;
		void parseText(string text) {
			auto e = current_format.dup;
			e["text"] = text;
			array ~= JSONValue(e);
		}
		foreach(message ; messages) {
			final switch(message.type) {
				case Message.FORMAT:
					switch(message.format) with(Format) {
						case darkBlue: current_format["color"] = "dark_blue"; break;
						case darkGreen: current_format["color"] = "dark_green"; break;
						case darkAqua: current_format["color"] = "dark_aqua"; break;
						case darkRed: current_format["color"] = "dark_red"; break;
						case darkPurple: current_format["color"] = "dark_purple"; break;
						case darkGray: current_format["color"] = "dark_gray"; break;
						case lightPurple: current_format["color"] = "light_purple"; break;
						case obfuscated:
						case bold:
						case strikethrough:
						case underlined:
						case italic:
							current_format[message.format.to!string] = true;
							break;
						case reset: current_format.clear(); break;
						default:
							current_format["color"] = message.format.to!string;
							break;
					}
					break;
				case Message.TEXT:
					parseText(message.text);
					break;
				case Message.TRANSLATION:
					if(message.translation.translatable.java.length) {
						auto e = current_format.dup;
						e["translate"] = message.translation.translatable.java;
						e["with"] = message.translation.parameters;
						array ~= JSONValue(e);
					} else {
						parseText(this.server.lang.translate(message.translation.translatable.default_, message.translation.parameters, this.language));
					}
					break;
			}
		}
		if(array.length == 1) return array[0];
		else if(array.length) return JSONValue(["text": JSONValue(""), "extra": JSONValue(array)]);
		else return JSONValue(["text": ""]);
	}

	protected void handleClientStatus() {
		this.respawn();
		this.sendRespawnPacket();
		this.sendPosition();
	}

	public void handleResourcePackStatusPacket(uint status) {
		this.hasResourcePack = (status == 0);
		//log(status);
	}
	
}

class JavaPlayerImpl(uint __protocol) : JavaPlayer if(supportedJavaProtocols.canFind(__protocol)) {

	mixin("import Types = sul.protocol.java" ~ __protocol.to!string ~ ".types;");
	mixin("import Clientbound = sul.protocol.java" ~ __protocol.to!string ~ ".clientbound;");
	mixin("import Serverbound = sul.protocol.java" ~ __protocol.to!string ~ ".serverbound;");

	mixin("import sul.attributes.java" ~ __protocol.to!string ~ " : Attributes;");
	mixin("import sul.metadata.java" ~ __protocol.to!string ~ " : Metadata;");

	// also used by ItemEntity
	public static Types.Slot toSlot(Slot slot) {
		if(slot.empty) {
			return Types.Slot(-1);
		} else {
			auto ret = Types.Slot(slot.item.javaId, slot.count, slot.item.javaMeta, [NBT_TYPE.END]);
			if(slot.item.javaCompound !is null) {
				auto stream = new ClassicStream!(Endian.bigEndian)();
				stream.writeTag(cast(Tag)slot.item.javaCompound);
				ret.nbt = stream.buffer;
			}
			return ret;
		}
	}

	protected Slot fromSlot(Types.Slot slot) {
		if(slot.id <= 0) {
			return Slot(null);
		} else {
			auto item = this.world.items.fromJava(slot.id, slot.damage);
			if(slot.nbt.length) {
				auto tag = new ClassicStream!(Endian.bigEndian)(slot.nbt).readTag();
				if(cast(Compound)tag) item.parseJavaCompound(cast(Compound)tag);
			}
			return Slot(item, slot.count);
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

	public Metadata metadataOf(SelMetadata metadata) {
		mixin("return metadata.java" ~ __protocol.to!string ~ ";");
	}

	private Slot picked_up_item;
	
	private bool dragging;
	private size_t[] dragged_slots;

	public this(shared PlayerInfo info, World world, EntityPosition position) {
		super(info, world, position);
		this.startCompression!Compression(hubId);
	}

	protected void sendPacket(T)(T packet) if(is(typeof(T.encode))) {
		ubyte[] payload = packet.encode();
		if(payload.length > 1024) {
			this.compress(payload);
		} else {
			this.sendPacketPayload(0 ~ payload);
		}
	}

	public override void flush() {}


	protected override void sendCompletedMessages(string[] messages) {
		static if(__protocol < 307) {
			sort!"a < b"(messages);
		}
		this.sendPacket(new Clientbound.TabComplete(messages));
	}
	
	protected override void sendMessageImpl(Message[] messages) {
		this.sendPacket(new Clientbound.ChatMessage(this.encodeMessage(messages).toString(), Clientbound.ChatMessage.CHAT));
	}
	
	protected override void sendTipImpl(Message[] messages) {
		static if(__protocol >= 305) {
			this.sendPacket(new Clientbound.Title().new SetActionBar(this.encodeMessage(messages).toString()));
		} else {
			this.sendPacket(new Clientbound.ChatMessage(this.encodeMessage(messages).toString(), Clientbound.ChatMessage.ABOVE_HOTBAR));
		}
	}
	
	protected override void sendTitleImpl(Title title, Subtitle subtitle, uint fadeIn, uint stay, uint fadeOut) {
		this.sendPacket(new Clientbound.Title().new SetTitle(this.encodeMessage(title).toString()));
		if(subtitle.length) this.sendPacket(new Clientbound.Title().new SetSubtitle(this.encodeMessage(subtitle).toString()));
		this.sendPacket(new Clientbound.Title().new SetTimings(fadeIn, stay, fadeOut));
	}

	protected override void sendHideTitles() {
		this.sendPacket(new Clientbound.Title().new Hide());
	}

	protected override void sendResetTitles() {
		this.sendPacket(new Clientbound.Title().new Reset());
	}
	
	public override void sendMovementUpdates(Entity[] entities) {
		foreach(Entity entity ; entities) {
			//TODO check for old rotation
			if(entity.oldposition != entity.position) {
				if(abs(entity.position.x - entity.oldposition.x) <= 8 && abs(entity.position.y - entity.oldposition.y) <= 8 && abs(entity.position.z - entity.oldposition.z) <= 8) {
					this.sendPacket(new Clientbound.EntityLookAndRelativeMove(entity.id, (cast(Vector3!short)round((entity.position * 32 - entity.oldposition * 32) * 128)).tuple, entity.angleYaw, entity.anglePitch, entity.onGround));
				} else {
					this.sendPacket(new Clientbound.EntityTeleport(entity.id, entity.position.tuple, entity.angleYaw, entity.anglePitch, entity.onGround));
				}
			} else {
				this.sendPacket(new Clientbound.EntityLook(entity.id, entity.angleYaw, entity.anglePitch, entity.onGround));
			}
			this.sendPacket(new Clientbound.EntityHeadLook(entity.id, cast(Living)entity ? (cast(Living)entity).angleBodyYaw : entity.angleYaw));
		}
	}
	
	public override void sendMotionUpdates(Entity[] entities) {
		foreach(Entity entity ; entities) {
			this.sendPacket(new Clientbound.EntityVelocity(entity.id, entity.velocity.tuple));
		}
	}
	
	public override void sendGamemode() {
		this.sendPacket(new Clientbound.ChangeGameState(Clientbound.ChangeGameState.CHANGE_GAMEMODE, this.gamemode));
	}
	
	public override void sendSpawnPosition() {
		//this.sendPacket(Packet.SpawnPosition(toLongPosition(this.spawn.blockPosition)));
	}
	
	public override void spawnToItself() {
		this.sendPacket(new Clientbound.PlayerListItem().new AddPlayer([this.encodePlayer(this)]));
	}
	
	public override void sendAddList(Player[] players) {
		Types.ListAddPlayer[] list;
		foreach(Player player ; players) {
			list ~= this.encodePlayer(player);
		}
		this.sendPacket(new Clientbound.PlayerListItem().new AddPlayer(list));
	}

	private Types.ListAddPlayer encodePlayer(Player player) {
		return Types.ListAddPlayer(player.uuid, player.name, new Types.Property[0], player.gamemode, player.latency, player.name != player.displayName, JSONValue(["text": player.displayName]).toString());
	}

	public override void sendUpdateLatency(Player[] players) {
		Types.ListUpdateLatency[] list;
		foreach(player ; players) {
			list ~= Types.ListUpdateLatency(player.uuid, player.latency);
		}
		this.sendPacket(new Clientbound.PlayerListItem().new UpdateLatency(list));
	}
	
	public override void sendRemoveList(Player[] players) {
		UUID[] list;
		foreach(Player player ; players) {
			list ~= player.uuid;
		}
		this.sendPacket(new Clientbound.PlayerListItem().new RemovePlayer(list));
	}
	
	alias sendMetadata = super.sendMetadata;
	
	public override void sendMetadata(Entity entity) {
		this.sendPacket(new Clientbound.EntityMetadata(entity.id, metadataOf(entity.metadata)));
	}
	
	public override void sendChunk(Chunk chunk) {

		immutable overworld = chunk.world.dimension == Dimension.overworld;

		uint sections = 0;
		ubyte[] buffer;
		foreach(ubyte i ; 0..16) {
			auto s = i in chunk;
			if(s) {
				sections |= 1 << i;

				auto section = *s;

				uint[] palette = section.full ? [] : [0];
				uint[] pointers;
				foreach(ubyte y ; 0..16) {
					foreach(ubyte z ; 0..16) {
						foreach(ubyte x ; cast(ubyte[])[7, 6, 5, 4, 3, 2, 1, 0, 15, 14, 13, 12, 11, 10, 9, 8]) {
							auto block = section[x, y, z];
							if(block && (*block).javaId != 0) {
								uint b = (*block).javaId << 4 | (*block).javaMeta;
								auto p = array_index(b, palette);
								if(p >= 0) {
									pointers ~= p & 255;
								} else {
									palette ~= b;
									pointers ~= (palette.length - 1) & 255;
								}
							} else {
								pointers ~= 0;
							}
						}
					}
				}
				
				// using 8 = ubyte.sizeof
				// something lower can be used (?)
				uint size = to!uint(ceil(log2(palette.length)));
				//if(size < 4) size = 4;
				size = 8; //TODO this limits to 256 different blocks!
				buffer ~= size & 255;
				buffer ~= varuint.encode(palette.length.to!uint);
				foreach(uint p ; palette) {
					buffer ~= varuint.encode(p);
				}
				
				buffer ~= varuint.encode(4096 >> 3); // 4096 / 8 as ulong[].length
				foreach(j ; pointers) {
					buffer ~= j & 255;
				}

				buffer ~= section.skyLight;
				if(overworld) buffer ~= section.blocksLight;
			}
		}

		ubyte[16 * 16] biomes;
		foreach(i, biome; chunk.biomes) {
			biomes[i] = biome.id;
		}

		buffer ~= biomes;

		auto packet = new Clientbound.ChunkData(chunk.position.tuple, true, sections, buffer);

		auto stream = new ClassicStream!(Endian.bigEndian)();
		foreach(tile ; chunk.tiles) {
			if(tile.javaCompound !is null) {
				packet.tilesCount++;
				auto compound = tile.javaCompound.dup;
				compound["x"] = new Int(tile.position.x);
				compound["y"] = new Int(tile.position.y);
				compound["z"] = new Int(tile.position.z);
				stream.writeTag(compound);
			}
		}
		packet.tiles = stream.buffer;

		this.sendPacket(packet);

	}
	
	public override void unloadChunk(ChunkPosition pos) {
		this.sendPacket(new Clientbound.UnloadChunk(pos.tuple));
	}

	public override void sendChangeDimension(Dimension _from, Dimension _to) {
		auto from = convertDimension(_from);
		auto to = convertDimension(_to);
		if(from != to) this.sendPacket(new Clientbound.Respawn(to==-1?1:to-1));
		this.sendPacket(new Clientbound.Respawn(to, this.world.difficulty, this.world.gamemode, this.world.type));
	}

	public override void sendInventory(ubyte flag=PlayerInventory.ALL, bool[] slots=[]) {
		foreach(uint index, bool slot; slots) {
			if(slot) {
				auto s = this.inventory[index];
				this.sendPacket(new Clientbound.SetSlot(cast(ubyte)0, to!ushort(index < 9 ? index + 36 : index), toSlot(s)));
				/*if(!s.empty && s.item == Items.MAP) {
					ushort id = s.metas.pc;
					if(!in_array(id, this.loaded_maps)) {
						this.loaded_maps ~= id;
						this.handleMapRequest(id);
					}
				}*/
			}
		}
		if((flag & PlayerInventory.HELD) != 0) this.sendHeld();
	}
	
	public override void sendHeld() {
		this.sendPacket(new Clientbound.SetSlot(cast(ubyte)0, to!ushort(27 + this.inventory.selected), toSlot(this.inventory.held)));
	}

	public override void sendEntityEquipment(Player player) {
		this.sendPacket(new Clientbound.EntityEquipment(player.id, 0, toSlot(player.inventory.held)));
	}
	
	public override void sendArmorEquipment(Player player) {
		foreach(uint i, Slot slot; player.inventory.armor) {
			this.sendPacket(new Clientbound.EntityEquipment(player.id, 5 - i, toSlot(slot)));
		}
	}
	
	public override void sendOpenContainer(ubyte type, ushort slots, BlockPosition position) {
		//TODO
	}
	
	public override void sendHurtAnimation(Entity entity) {
		this.sendPacket(new Clientbound.EntityStatus(entity.id, Clientbound.EntityStatus.PLAY_HURT_ANIMATION_AND_SOUND));
	}
	
	public override void sendDeathAnimation(Entity entity) {
		this.sendPacket(new Clientbound.EntityStatus(entity.id, Clientbound.EntityStatus.PLAY_DEATH_ANIMATION_AND_SOUND));
	}
	
	protected override void sendDeathSequence() {}
	
	protected override @trusted void experienceUpdated() {
		this.sendPacket(new Clientbound.SetExperience(this.experience, this.level, 0)); //TODO total
	}
	
	protected override void sendPosition() {
		this.sendPacket(new Clientbound.PlayerPositionAndLook(this.position.tuple, this.yaw, this.pitch, ubyte.init, 0));
	}

	protected override void sendMotion(EntityPosition motion) {
		auto ret = motion * 8000;
		auto m = Vector3!short(clamp(ret.x, short.min, short.max), clamp(ret.y, short.min, short.max), clamp(ret.z, short.min, short.max));
		this.sendPacket(new Clientbound.EntityVelocity(this.id, m.tuple));
	}

	public override void sendSpawnEntity(Entity entity) {
		if(cast(Player)entity) this.sendAddPlayer(cast(Player)entity);
		else this.sendAddEntity(entity);
	}

	public override void sendDespawnEntity(Entity entity) {
		this.sendPacket(new Clientbound.DestroyEntities([entity.id]));
	}
	
	protected void sendAddPlayer(Player player) {
		this.sendPacket(new Clientbound.SpawnPlayer(player.id, player.uuid, player.position.tuple, player.angleYaw, player.anglePitch, metadataOf(player.metadata)));
	}
	
	protected void sendAddEntity(Entity entity) {
		//TODO xp orb
		//TODO painting
		if(entity.java) {
			if(entity.object) this.sendPacket(new Clientbound.SpawnObject(entity.id, entity.uuid, entity.javaId, entity.position.tuple, entity.anglePitch, entity.angleYaw, entity.objectData, entity.velocity.tuple));
			else this.sendPacket(new Clientbound.SpawnMob(entity.id, entity.uuid, entity.javaId, entity.position.tuple, entity.angleYaw, entity.anglePitch, cast(Living)entity ? (cast(Living)entity).angleBodyYaw : entity.angleYaw, entity.velocity.tuple, metadataOf(entity.metadata)));
			if(cast(ItemEntity)entity) this.sendMetadata(entity);
		}
	}
	
	public override @trusted void healthUpdated() {
		super.healthUpdated();
		this.sendPacket(new Clientbound.UpdateHealth(this.healthNoAbs, this.hunger, this.saturation));
		this.sendPacket(new Clientbound.EntityProperties(this.id, [Types.Attribute(Attributes.maxHealth.name, this.maxHealthNoAbs)]));
	}
	
	public override @trusted void hungerUpdated() {
		super.hungerUpdated();
		this.sendPacket(new Clientbound.UpdateHealth(this.healthNoAbs, this.hunger, this.saturation));
	}
	
	protected override void onEffectAdded(Effect effect, bool modified) {
		if(effect.java) this.sendPacket(new Clientbound.EntityEffect(this.id, effect.java.id, effect.level, cast(uint)effect.duration, Clientbound.EntityEffect.SHOW_PARTICLES));
	}
	
	protected override void onEffectRemoved(Effect effect) {
		if(effect.java) this.sendPacket(new Clientbound.RemoveEntityEffect(this.id, effect.java.id));
	}
	
	public override void recalculateSpeed() {
		super.recalculateSpeed();
		this.sendPacket(new Clientbound.EntityProperties(this.id, [Types.Attribute(Attributes.movementSpeed.name, this.speed)]));
	}

	public override void sendJoinPacket() {
		if(!this.first_spawned) {
			this.sendPacket(new Clientbound.JoinGame(this.id, this.gamemode, convertDimension(this.world.dimension), this.world.difficulty, ubyte.max, this.world.type, false));
			this.first_spawned = true;
		}
		this.sendPacket(new Clientbound.PluginMessage("MC|Brand", cast(ubyte[])Software.name));
	}

	public override void sendResourcePack() {
		if(!this.hasResourcePack) {
			// the game will show a confirmation popup for the first time the texture is downloaded
			static if(__protocol < 301) {
				enum v = "2";
			} else {
				enum v = "3";
			}
			string url = resourcePack;
			if(this.connectedSameMachine) url = "127.0.0.1";
			else if(this.connectedSameNetwork) url = this.ip; // not tested
			this.sendPacket(new Clientbound.ResourcePackSend("http://" ~ url ~ resourcePackPort ~ "/" ~ v, mixin("resourcePack" ~ v ~ "Hash")));
		}
	}
	
	public override void sendPermissionLevel(PermissionLevel permissionLevel) {
		this.sendPacket(new Clientbound.EntityStatus(this.id, cast(ubyte)(Clientbound.EntityStatus.SET_OP_PERMISSION_LEVEL_0 + permissionLevel)));
	}

	public override void sendDifficulty(Difficulty difficulty) {
		this.sendPacket(new Clientbound.ServerDifficulty(difficulty));
	}
	
	public override void sendWorldGamemode(Gamemode gamemode) {
		// not supported
	}

	public override void sendDoDaylightCycle(bool cycle) {
		this.sendPacket(new Clientbound.TimeUpdate(this.world.ticks, cycle ? this.world.time : -this.world.time));
	}
	
	public override void sendTime(uint time) {
		this.sendPacket(new Clientbound.TimeUpdate(this.world.ticks, this.world.time.cycle ? time : -time));
	}
	
	public override void sendWeather(bool raining, bool thunderous, uint time, uint intensity) {
		this.sendPacket(new Clientbound.ChangeGameState(raining ? Clientbound.ChangeGameState.BEGIN_RAINING : Clientbound.ChangeGameState.END_RAINING, intensity - 1));
	}
	
	public override void sendSettingsPacket() {
		//TODO
		//this.sendPacket(new MinecraftPlayerAbilites());
	}
	
	public override void sendRespawnPacket() {
		this.sendPacket(new Clientbound.Respawn(convertDimension(this.world.dimension), this.world.difficulty, to!ubyte(this.gamemode), this.world.type));
	}
	
	public override void setAsReadyToSpawn() {
		//if(!this.first_spawned) {
		//this.sendPacket(packet!"PlayerPositionAndLook"(this));
		this.sendPosition();
	}

	public override void sendLightning(Lightning lightning) {
		this.sendPacket(new Clientbound.SpawnGlobalEntity(lightning.id, Clientbound.SpawnGlobalEntity.THUNDERBOLT, lightning.position.tuple));
	}
	
	public override void sendAnimation(Entity entity) {
		static if(__protocol >= 109) {
			this.sendPacket(new Clientbound.Animation(entity.id, Clientbound.Animation.SWING_MAIN_ARM));
		} else {
			this.sendPacket(new Clientbound.Animation(entity.id, Clientbound.Animation.SWING_ARM));
		}
	}
	
	public override void sendBlocks(PlacedBlock[] blocks) {
		Types.BlockChange[][int][int] pc;
		foreach(PlacedBlock block ; blocks) {
			auto position = block.position;
			pc[position.x >> 4][position.z >> 4] ~= Types.BlockChange((position.x & 15) << 4 | (position.z & 15), position.y & 255, block.java.id << 4 | block.java.meta);
		}
		foreach(x, pcz; pc) {
			foreach(z, pb; pcz) {
				this.sendPacket(new Clientbound.MultiBlockChange(ChunkPosition(x, z).tuple, pb));
			}
		}
	}
	
	public override void sendTile(Tile tile, bool translatable) {
		auto stream = new ClassicStream!(Endian.bigEndian)();
		auto packet = new Clientbound.UpdateBlockEntity(ulongPosition(tile.position), tile.action);
		if(tile.javaCompound !is null) {
			auto compound = tile.javaCompound.dup;
			// signs become invisible without the coordinates
			compound["x"] = new Int(tile.position.x);
			compound["y"] = new Int(tile.position.y);
			compound["z"] = new Int(tile.position.z);
			stream.writeTag(compound);
			packet.nbt = stream.buffer;
		} else {
			packet.nbt ~= 0;
		}
		this.sendPacket(packet);
		/*if(translatable) {
			tile.to!ITranslatable.translateStrings(this.lang);
		}
		//this.sendPacket(new MinecraftUpdateBlockEntity(tile));
		if(translatable) {
			tile.to!ITranslatable.untranslateStrings();
		}*/
	}
	
	public override @trusted void sendPickupItem(Entity picker, Entity picked) {
		static if(__protocol >= 301) {
			this.sendPacket(new Clientbound.CollectItem(picked.id, picker.id, cast(ItemEntity)picked ? (cast(ItemEntity)picked).item.count : 1));
		} else {
			this.sendPacket(new Clientbound.CollectItem(picked.id, picker.id));
		}
	}
	
	public override void sendPassenger(ubyte mode, uint passenger, uint vehicle) {
		//TODO
		//this.sendPacket(packet!"SetPassengers"(mode == 0 ? [] : [passenger == this.id ? 0 : passenger], vehicle == this.id ? 0 : vehicle));
	}
	
	public override void sendExplosion(EntityPosition position, float radius, Vector3!byte[] updates) {
		Vector3!byte.Tuple[] records;
		foreach(update ; updates) {
			records ~= update.tuple;
		}
		this.sendPacket(new Clientbound.Explosion((cast(Vector3!float)position).tuple, radius, records, typeof(Clientbound.Explosion.motion)(0, 0, 0)));
	}
	
	public override void sendMap(Map map) {
		//TODO
		//this.sendPacket(map.minecraftpacket);
	}

	public override void sendMusic(EntityPosition position, ubyte instrument, uint pitch) {
		/*@property string sound() {
			final switch(instrument) {
				case Instruments.HARP: return "harp";
				case Instruments.DOUBLE_BASS: return "bass";
				case Instruments.SNARE_DRUM: return "snare";
				case Instruments.CLICKS: return "pling";
				case Instruments.BASS_DRUM: return "basedrum";
			}
		}
		enum float[] pitches = [.5, .533333, .566666, .6, .633333, .666666, .7, .75, .8, .85, .9, .95, 1, 1.05, 1.1, 1.2, 1.25, 1.333333, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2];
		this.sendPacket(new Clientbound.NamedSoundEffect("block.note." ~ sound, 2, (cast(Vector3!int)position).tuple, 16, pitches[pitch]));*/
	}



	mixin generateHandlers!(Serverbound.Packets);

	protected void handleTeleportConfirmPacket(uint id) {
		//TODO implement confirmations
	}

	protected void handleTabCompletePacket(string text, bool command, bool hasPosition, ulong position) {
		this.handleCompleteMessage(text, command);
	}

	protected void handleChatMessagePacket(string message) {
		this.handleTextMessage(message);
	}

	protected void handleClientStatusPacket(uint aid) {
		this.handleClientStatus(aid);
	}

	protected void handleConfirmTransactionPacket(ubyte window, ushort action, bool accepted) {}

	protected void handleEnchantItemPacket(ubyte window, ubyte enchantment) {}

	protected void handleClickWindowPacket(ubyte window, ushort slot, ubyte button, ushort actionId, uint mode, Types.Slot item) {
		int real_slot = slot >= 9 && slot <= 44 ? (slot >= 36 ? slot - 36 : slot) : -1; //TODO container's
		// the "picked up slot/item" is the one attached to the player's mouse's pointer
		bool accepted = true;
		if(window == 0) { // inventory
			switch(mode) {
				case 0:
					switch(button) {
						case 0:
							// left mouse click
							// pick up the whole stack if the picked up slot is empty
							// merge or switch them if the picked up item is not empty
							// drop the picked up slot if the slot is -999
							if(this.picked_up_item.empty) {
								if(real_slot >= 0) {
									// some valid stuff
									Slot current = this.inventory[real_slot];
									if(!current.empty) {
										// pick up that item
										this.picked_up_item = current;
										this.inventory[real_slot] = Slot(null);
									}
								}
							} else {
								if(real_slot >= 0) {
									Slot current = this.inventory[real_slot];
									if(!current.empty && this.picked_up_item.item == current.item) {
										// merge them
										if(!current.full) {
											uint count = current.count + this.picked_up_item.count;
											if(count > current.item.max) {
												count = current.item.max;
												this.picked_up_item.count = (count - current.count) & ubyte.max;
											} else {
												this.picked_up_item = Slot(null);
											}
											this.inventory[real_slot] = Slot(current.item, count & ubyte.max);
										}
									} else {
										// switch them (place if current is empty)
										this.inventory[real_slot] = this.picked_up_item;
										this.picked_up_item = current;
									}
								} else if(slot == -999) {
									this.handleDropFromPickedUp(this.picked_up_item);
								}
							}
							break;
						case 1:
							// right mouse click
							// if the picked up slot is empty pick up half the stack (with the half picked up bigger if the slot's count is an odd number)
							// if the picked up item is the same as the slot, place one (if the slot is already full, do nothing)
							// if the picked up item is different from the slot, switch them
							// drop one if the slot is -999
							if(this.picked_up_item.empty) {
								if(real_slot >= 0) {
									Slot current = this.inventory[real_slot];
									if(!current.empty) {
										ubyte picked_count = current.count / 2;
										if(current.count % 2 == 1) {
											picked_count++;
										}
										this.picked_up_item = Slot(current.item, picked_count);
										this.inventory[real_slot] = Slot(current.count == 1 ? null : current.item, current.count / 2);
									}
								}
							} else {
								if(real_slot >= 0) {
									Slot current = this.inventory[real_slot];
									if(current.empty || current.item == this.picked_up_item.item && !current.full) {
										this.inventory[real_slot] = Slot(this.picked_up_item.item, current.empty ? 1 : (current.count + 1) & ubyte.max);
										this.picked_up_item.count--;
									} else if(this.picked_up_item != current && (current.empty || !current.full)) {
										this.inventory[real_slot] = this.picked_up_item;
										this.picked_up_item = current;
									}
								} else if(slot == -999) {
									if(!this.creative) {
										Slot drop = Slot(this.picked_up_item.item, 1);
										this.handleDropFromPickedUp(drop);
										this.picked_up_item.count--;
									} else {
										this.handleDropFromPickedUp(this.picked_up_item);
									}
								}
							}
							break;
						default:
							break;
					}
					break;
				case 1:
					// moves items in the inventory using the shift buttons
					if(real_slot >= 0) {
						InventoryRange location, target;
						if(real_slot < 9) {
							location = this.inventory[0..9];
							target = this.inventory[9..$];
						} else {
							location = this.inventory[9..$];
							target = this.inventory[0..9];
							real_slot -= 9;
						}
						if(!location[real_slot].empty) location[real_slot] = target += location[real_slot];
					}
					break;
				case 2:
					// switch items from somewhere in the inventory to the hotbar
					if(button < 9 && real_slot >= 0 && real_slot != button) {
						Slot target = this.inventory[real_slot];
						if(!target.empty || !this.inventory[button].empty) {
							this.inventory[real_slot] = this.inventory[button];
							this.inventory[button] = target;
						}
					}
					break;
				case 3:
					// middle click, used in creative mode
					if(this.creative && real_slot >= 0 && !this.inventory[real_slot].empty) {
						this.picked_up_item = Slot(this.inventory[real_slot].item);
					}
					break;
				case 4:
					// dropping items with the inventory opened
					if(real_slot >= 0 && !this.inventory[real_slot].empty) {
						if(button == 0) {
							if(this.handleDrop(Slot(this.inventory[real_slot].item, 1))) {
								if(--this.inventory[real_slot].count == 0) {
									this.inventory[real_slot] = Slot(null);
								}
							}
						} else {
							if(this.handleDrop(this.inventory[real_slot])) {
								this.inventory[real_slot] = Slot(null);
							}
						}
					}
					break;
				case 5:
					// drag items
					switch(button) {
						case 0:
						case 4:
							this.dragging = true;
							break;
						case 1:
						case 5:
							if(this.dragging && real_slot >= 0 && !this.dragged_slots.canFind(real_slot)) {
								this.dragged_slots ~= real_slot;
							}
							break;
						case 2:
							if(!this.picked_up_item.empty) {
								ubyte amount = (this.picked_up_item.count / this.dragged_slots.length) & ubyte.max;
								if(amount == 0) amount = 1;
								foreach(size_t index ; this.dragged_slots) {
									Slot target = this.inventory[index];
									if(target.empty || (target.item == this.picked_up_item.item && !target.full)) {
										
									}
								}
							}
							this.dragging = false;
							this.dragged_slots.length = 0;
							break;
						case 6:
							if(!this.picked_up_item.empty) {
								foreach(size_t index ; this.dragged_slots) {
									Slot target = this.inventory[index];
									if(target.empty || (target.item == this.picked_up_item.item && !target.full)) {
										this.inventory[index] = Slot(this.picked_up_item.item, target.empty ? 1 : (target.count + 1) & ubyte.max);
										if(--this.picked_up_item.count == 0) break;
									}
								}
							}
							this.dragging = false;
							this.dragged_slots.length = 0;
							break;
						default:
							break;
					}
					break;
				case 6:
					// double click on an item (can only be done in the hotbar)
					if(real_slot >= 0 && !this.picked_up_item.empty) {
						// searches for the items not in the hotbar first
						this.inventory[real_slot] = this.picked_up_item;
						auto inv = new InventoryGroup(this.inventory[9..$], this.inventory[0..9]);
						inv.group(real_slot < 9 ? (this.inventory.length - 9 + real_slot) : (real_slot - 9));
						this.picked_up_item = this.inventory[real_slot];
						this.inventory[real_slot] = Slot(null);
					}
					break;
				default:
					break;
			}
		}
		this.sendPacket(new Clientbound.ConfirmTransaction(window, actionId, accepted));
	}

	protected void handleCloseWindowPacket(ubyte window) {
		//TODO match with open window (inventory / chest)
		if(this.alive && !this.picked_up_item.empty) {
			this.handleDropFromPickedUp(this.picked_up_item);
		}
	}

	protected void handlePluginMessagePacket(string channel, ubyte[] bytes) {}

	protected void handleUseEntityPacket(uint eid, uint type, typeof(Serverbound.UseEntity.targetPosition) targetPosition, uint hand) {
		switch(type) {
			case Serverbound.UseEntity.INTERACT:
				this.handleInteract(eid);
				break;
			case Serverbound.UseEntity.ATTACK:
				this.handleAttack(eid);
				break;
			case Serverbound.UseEntity.INTERACT_AT:

				break;
			default:
				break;
		}
	}

	protected void handlePlayerPositionPacket(typeof(Serverbound.PlayerPosition.position) position, bool onGround) {
		this.handleMovementPacket(cast(EntityPosition)position, this.yaw, this.bodyYaw, this.pitch);
	}

	protected void handlePlayerPositionAndLookPacket(typeof(Serverbound.PlayerPositionAndLook.position) position, float yaw, float pitch, bool onGround) {
		this.handleMovementPacket(cast(EntityPosition)position, yaw, yaw, pitch);
	}

	protected void handlePlayerLookPacket(float yaw, float pitch, bool onGround) {
		this.handleMovementPacket(this.position, yaw, yaw, pitch);
	}

	protected void handleVehicleMovePacket(typeof(Serverbound.VehicleMove.position) position, float yaw, float pitch) {}

	protected void handleSteerBoatPacket(bool right, bool left) {}

	protected void handlePlayerAbilitiesPacket(ubyte flags, float flyingSpeed, float walkingSpeed) {}

	protected void handlePlayerDiggingPacket(uint status, ulong position, ubyte face) {
		switch(status) {
			case Serverbound.PlayerDigging.START_DIGGING:
				this.handleStartBlockBreaking(blockPosition(position));
				break;
			case Serverbound.PlayerDigging.CANCEL_DIGGING:
				this.handleAbortBlockBreaking();
				break;
			case Serverbound.PlayerDigging.FINISH_DIGGING:
				this.handleBlockBreaking();
				break;
			case Serverbound.PlayerDigging.DROP_ITEM_STACK:
				if(!this.inventory.held.empty && this.handleDrop(this.inventory.held)) {
					this.inventory.held = Slot(null);
				}
				break;
			case Serverbound.PlayerDigging.DROP_ITEM:
				Slot held = this.inventory.held;
				if(!held.empty && this.handleDrop(Slot(held.item, 1))) {
					held.count--;
					this.inventory.held = held;
				}
				break;
			case Serverbound.PlayerDigging.FINISH_EATING:
				this.actionFlag = false;
				this.consuming = false;
				break;
			case Serverbound.PlayerDigging.SWAP_ITEM_IN_HAND:

				break;
			default:
				break;
		}
	}

	protected void handleEntityActionPacket(uint eid, uint action, uint jumpBoost) {
		switch(action) {
			case Serverbound.EntityAction.START_SNEAKING:
				this.handleSneaking(true);
				break;
			case Serverbound.EntityAction.STOP_SNEAKING:
				this.handleSneaking(false);
				break;
			case Serverbound.EntityAction.LEAVE_BED:
				
				break;
			case Serverbound.EntityAction.START_SPRINTING:
				this.handleSprinting(true);
				break;
			case Serverbound.EntityAction.STOP_SPRINTING:
				this.handleSprinting(false);
				break;
			case Serverbound.EntityAction.START_HORSE_JUMP:

				break;
			case Serverbound.EntityAction.STOP_HORSE_JUMP:

				break;
			case Serverbound.EntityAction.OPEN_HORSE_INVENTORY:

				break;
			case Serverbound.EntityAction.START_ELYTRA_FLYING:

				break;
			default:
				break;
		}
	}

	protected void handleSteerVehiclePacket(float sideways, float forward, ubyte flags) {}

	protected void handleHeldItemChangePacket(ushort slot) {
		if(slot < 9) {
			this.inventory.selected = slot; //TODO call event
			this.consuming_time = 0;
		}
	}

	protected void handleCreativeInventoryActionPacket(ushort slot, Types.Slot item) {}

	protected void handleUpdateSignPacket(ulong position, string[4] texts) {}

	protected void handleAnimationPacket(uint hand) {
		this.handleArmSwing();
	}

	protected void handleSpectatePacket(UUID uuid) {}

	protected void handlePlayerBlockPlacementPacket(ulong position, uint face, uint hand, typeof(Serverbound.PlayerBlockPlacement.cursorPosition) cursorPosition) {
		if(!this.inventory.held.empty) {
			if(this.inventory.held.item.placeable) {
				this.handleBlockPlacing(blockPosition(position), face);
			} else {
				this.handleRightClick(blockPosition(position), face);
			}
		}
	}

	protected void handleUseItemPacket(uint hand) {
		if(!this.inventory.held.empty && this.inventory.held.item.consumeable) {
			this.actionFlag = true;
			this.consuming = true;
			this.consuming_time = 0;
		}
	}


	protected void handleClientStatus(uint aid) {
		if(aid == Serverbound.ClientStatus.RESPAWN) {
			super.handleClientStatus();
		}
	}
	
	private void handleDropFromPickedUp(ref Slot slot) {
		if(this.handleDrop(slot)) {
			slot = Slot(null);
		}
	}
	
	enum string stringof = "MinecraftPlayer!" ~ to!string(__protocol);

	private static class Compression : Player.Compression {

		public override ubyte[] compress(ubyte[] payload) {
			ubyte[] data = varuint.encode(payload.length.to!uint);
			Compress compress = new Compress(6, HeaderFormat.deflate);
			data ~= cast(ubyte[])compress.compress(payload);
			data ~= cast(ubyte[])compress.flush();
			return data;
		}

	}

}
