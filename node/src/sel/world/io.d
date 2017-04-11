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
module sel.world.io;

import std.conv : to;
import std.file : exists, writeFile = write, readFile = read, mkdirRecurse, dirEntries, SpanMode, isFile, isDir;
import std.json;
import std.path : dirSeparator;
import std.string;
import std.system;
import std.zlib;

import common.sel : Software;
import common.util.time : seconds;

import nbt.stream : ClassicStream;
import nbt.tags;

import sel.block.block : Block;
import sel.math.vector;
import sel.util.util;
import sel.util.buffers;
import sel.world.chunk : Chunk, Section;
import sel.world.world : World;

// debug
import sel.util.log;

/**
 * The SEL (Section Level) world format
 */
struct Sel(Endian endianness) {

	@disable this();

	enum Sections : ubyte {

		mods = 0,
		sections = 1,
		biomes = 2,
		lights = 3,
		entities = 4,
		tiles = 5

	}

	public static void writeWorld(World world, string location, int compress=6) {

		if(!location.endsWith(dirSeparator)) location ~= dirSeparator;

		if(!exists(location)) mkdirRecurse(location);

		writeLevelInfo(world, location ~ "level.json");

		foreach(int x, Chunk[int] chunks; world.chunks) {
			foreach(int z, Chunk chunk; chunks) {
				writeChunk(chunk, location ~ "chunks" ~ dirSeparator ~ to!string(x) ~ "_" ~ to!string(z) ~ ".sc", compress);
			}
		}

	}

	public static void writeLevelInfo(World world, string location) {
		JSONValue[string] json;
		json["vendor"] = Software.name;
		json["saved"] = seconds;
		json["name"] = world.name;
		json["seed"] = world.seed;
		json["generator"] = world.type;
		json["difficulty"] = world.rules.difficulty;
		json["gamemode"] = world.rules.gamemode;
		json["time"] = world.time;
		json["spawn"] = ["x": JSONValue(world.spawnPoint.x), "y": JSONValue(world.spawnPoint.y), "z": JSONValue(world.spawnPoint.z)];
		json["rain"] = world.weather.rain;
		json["thunder"] = world.weather.thunder;
		json["intensity"] = world.weather.intensity;
		writeFile(location, JSONValue(json).toPrettyString());
	}

	public static Chunk writeChunk(Chunk chunk, string location, int compress=6) {

		Writer writer = Writer(Buffer!endianness.instance);

		// header
		writer ~= cast(ubyte[])"sectionlevel1";

		// endianness
		writer.write!ubyte(cast(ubyte)endianness);

		void writeSection(ubyte id, ubyte[] data) {
			writer.write!ubyte(id);
			size_t length = data.length;
			if(compress > 0 && data.length > 1024) {
				writer.write!bool(true);
				Compress c = new Compress(compress, HeaderFormat.deflate);
				data = cast(ubyte[])c.compress(data.dup);
				data ~= cast(ubyte[])c.flush();
				writer.write!uint(data.length.to!uint);
			} else {
				writer.write!bool(false);
			}
			writer.write!uint(length.to!uint);
			writer ~= data;
		}

		//TODO mods
		// array of strings (length is uint for array and strings)

		// sections (4-? bytes)
		if(!chunk.empty) {

			Writer cw = Writer(Buffer!endianness.instance);

			cw.write!uint(chunk.sections.length.to!uint);

			foreach(i, section; chunk.sections) {
				cw.write!uint(i.to!uint);
				cw.reserve(4096*2 + 16*16*8 + 16*16*8);
				foreach(block ; section.blocks) {
					cw.write!ushort(block ? (*block).id : 0);
				}
				cw ~= section.skyLight;
				cw ~= section.blocksLight;
			}

			writeSection(Sections.sections, cw);

		}

		// biomes (256 bytes)
		{
			ubyte[16 * 16] biomes;
			foreach(i, biome; chunk.biomes) {
				biomes[i] = biome.id;
			}
			writeSection(Sections.biomes, biomes);
		}

		// lights (512 bytes)
		if(!chunk.empty) {
			writeSection(Sections.lights, chunk.lights);
		}

		//TODO tiles
		// array of nbts (length is uint)
		// nbt => (x : ubyte, y : uint, z : ubyte, compound : ubyte[])

		//TODO entities (length is uint)
		// array of entities
		// entity => (x : float, y : float, z : float, compound : ubyte[])

		mkdirRecurse(location[0..location.lastIndexOf(dirSeparator)]);
		writeFile(location, writer);

		return chunk;

	}

	public static void readWorld(C:Chunk=Chunk)(World world, string location) {

		if(!location.endsWith(dirSeparator)) location ~= dirSeparator;

		if(exists(location ~ "level.json")) {
			//TODO read world info
		}

		foreach(string path ; dirEntries(location ~ "chunks", SpanMode.breadth)) {
			if(path.isFile && path.endsWith(".sc")) {
				string[] coords = path[path.lastIndexOf(dirSeparator)..$-3].split("_");
				if(coords == 2) {
					ChunkPosition position = ChunkPosition(to!int(coords[0]), to!int(coords[1]));
					world[position] = readChunk(new C(world, position, path), path);
				}
			}
		}

	}

	public static Chunk readChunk(Chunk chunk, string location) {

		ubyte[] payload = cast(ubyte[])readFile(location);

		// header check
		assert(cast(string)Buffer!(Endian.bigEndian).instance.read_ubyte_array(13, payload) == "sectionlevel1");

		// reads data with the required endianness
		return Buffer!(Endian.bigEndian).instance.read_ubyte(payload) == Endian.bigEndian ? BigEndianSel.readChunkImpl(chunk, payload) : LittleEndianSel.readChunkImpl(chunk, payload);

	}

	public static Chunk readChunkImpl(Chunk chunk, ubyte[] payload) {

		Reader reader = Reader(Buffer!endianness.instance, payload);

		Reader nextSection() {
			bool compressed = reader.read!bool();
			ubyte[] data = reader.read(reader.read!uint());
			if(compressed) {
				UnCompress u = new UnCompress(reader.read!uint());
				data = cast(ubyte[])u.uncompress(data.dup);
				data ~= cast(ubyte[])u.flush();
			}
			return Reader(Buffer!endianness.instance, data);
		}

		while(!reader.eof) {
			ubyte id = reader.read!ubyte();
			Reader next = nextSection();
			switch(id) {
				case Sections.mods:
					// used for checking the compatibility of the saved blocks
					string[] mods = new string[next.read!uint()];
					foreach(ref string mod ; mods) {
						mod = cast(string)next.read(next.read!uint());
					}
					break;
				case Sections.sections:
					size_t[] sections = new size_t[next.read!uint()];
					foreach(size_t i ; 0..sections.length) {
						size_t section = next.read!uint();
						sections[i] = section;
						chunk.createSection(section);
						auto s = i in chunk;
						Block*[4096] blocks;
						foreach(j ; 0..4096) {
							blocks[j] = next.read!ushort() in chunk.blocks;
						}
						ubyte[2048] skyLight = next.read(2048);
						ubyte[2048] blocksLight = next.read(2048);
						(*s).blocks = blocks;
						(*s).skyLight = skyLight;
						(*s).blocksLight = blocksLight;
					}
					break;
				case Sections.biomes:
					//TODO search biome in enum
					break;
				case Sections.lights:
					ubyte[512] lights = next.read(512);
					chunk.lights = lights;
					break;
				case Sections.entities:
					foreach(size_t i ; 0..next.read!uint()) {

					}
					break;
				case Sections.tiles:
					foreach(size_t i ; 0..next.read!uint()) {

					}
					break;
				default:
					assert(0);
			}
		}

		return chunk;

	}

}

alias BigEndianSel = Sel!(Endian.bigEndian);

alias LittleEndianSel = Sel!(Endian.littleEndian);

alias DefaultSel = Sel!endian;

struct AnvilImpl(immutable(char)[3] order) {

	@disable this();

	public static void writeWorld(World world, string location) {

	}

	public static void readWorld(C:Chunk=Chunk)(World world, string location) {

		if(!location.endsWith(dirSeparator)) location ~= dirSeparator;

		//TODO read settings

		if(exists(location ~ "region") && isDir(location ~ "region")) {
			foreach(string path ; dirEntries(location ~ "region", SpanMode.breadth)) {
				if(path.isFile && path.endsWith(".mca")) {
					readRegion!C(world, path);
				}
			}
		}

	}

	public static void readRegion(C:Chunk=Chunk)(ref World world, string location) {

		int rx = to!int(location.split(".")[$-3]) << 5;
		int rz = to!int(location.split(".")[$-2]) << 5;

		ubyte[] data = cast(ubyte[])readFile(location);

		foreach(int cx ; 0..32) {
			foreach(int cz ; 0..32) {
				ChunkPosition position = ChunkPosition(rx + cx, rz + cz);
				uint datapos = ((position.x & 31) + (position.z & 31) * 32) * 4;
				uint offset = ((data[datapos] << 16) | (data[datapos + 1] << 8) | data[datapos + 2]) * 4096;
				uint length = (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
				ubyte[] chunkdata = data[offset + 5 .. offset + 5 + length];
				if(offset == 0) continue;
				UnCompress uc = new UnCompress();
				auto uncompressed = uc.uncompress(chunkdata);
				uncompressed ~= uc.flush();
				auto compound = new Compound();
				compound.decode(new ClassicStream!(Endian.bigEndian)((cast(ubyte[])uncompressed)[3..$])); // skip tag type (1 byte) and name (2 bytes)
				if(compound.has!Compound("Level")) compound = compound.get!Compound("Level");
				Chunk chunk = new C(world, position);
				if(compound.has!(ListOf!Compound)("Sections")) {
					foreach(Compound section ; compound.get!(ListOf!Compound)("Sections")) {
						immutable sectiony = section.get!Byte("Y");
						immutable yy = sectiony << 4;
						chunk.createSection(sectiony);
						ubyte[] blocks = section.get!ByteArray("Blocks");
						ubyte[] metas = section.get!ByteArray("Data");
						foreach(ubyte x ; 0..16) {
							foreach(ubyte y ; 0..16) {
								foreach(ubyte z ; 0..16) {
									mixin("auto bpos = (" ~ order[0] ~ " << 8) | (" ~ order[1] ~ " << 4) | " ~ order[2] ~ ";");
									if(blocks[bpos] != 0) {
										uint mpos = bpos >> 1;
										bool shift = bpos & 1;
										try {
											chunk[x, yy + y, z] = world.blocks.frompc(blocks[bpos], (metas[mpos] & (shift ? 0xF0 : 0x0F)) >> (shift ? 4 : 0));
										} catch(Error e) {
											//TODO log error
										}
									}
								}
							}
						}
						void set(string l)(Section sec, ubyte[] array) {
							static if(order == "yxz") {
								dest = array;
							} else {
								foreach(ubyte x ; 0..16) {
									foreach(ubyte y ; 0..16) {
										foreach(ubyte z ; 0..16) {
											// SEL's sections are saved in yxz
											mixin("ubyte data = array[(" ~ order[0] ~ " << 7) | (" ~ order[1] ~ " << 3) | (" ~ order[2] ~ " >> 1)];");
											if(mixin("" ~ order[2]) & 1) data >>>= 4;
											data &= 15;
											if(z & 1) data <<= 4;
											mixin("sec." ~ l ~ "[(y << 7) | (x << 3) | (z >> 1)] |= data;");
										}
									}
								}
							}
						}
						if(section.has!(ByteArray)("BlockLight")) {
							set!"blocksLight"(chunk[sectiony], section.get!(ByteArray)("BlockLight").value);
						}
						if(section.has!(ByteArray)("SkyLight")) {
							set!"skyLight"(chunk[sectiony], section.get!(ByteArray)("SkyLight").value);
						}
					}
				}
				if(compound.has!(ByteArray)("Biomes")) {
					//TODO search biome in enum
					//chunk.biomes = cast(ubyte[])(compound.get!(ByteArray)("Biomes")[]);
				}
				world[] = chunk;
			}
		}

	}

}

alias Anvil = AnvilImpl!("yzx");

alias PMAnvil = AnvilImpl!("xzy");

struct LevelDB {

	@disable this();

	public static void writeWorld(World world, string location) {}

	public static void readWorld(World world, string location) {}

}
