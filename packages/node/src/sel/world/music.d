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
module sel.world.music;

import std.conv : to;
import std.file;
import std.string : split, strip, startsWith, toUpper;
import std.typecons : Tuple;

import sel.math.vector;
import sel.world.world : World;

enum Instruments {

	PIANO = 0,
	HARP = 0,
	DOUBLE_BASS = 1,
	SNARE_DRUM = 2,
	CLICKS = 3,
	STICKS = 3,
	BASS_DRUM = 4,

}

alias Note = Tuple!(ubyte, "instrument", uint, "pitch");

struct Music {

	public static Music fromFile(string file) {
		return Music(cast(string)read(file));
	}

	public Note[][] notes;

	public this(string content) {
		ubyte instrument = Instruments.PIANO;
		size_t pause = 1;
		foreach(string line ; content.toUpper.split("\n")) {
			line = line.strip;
			if(line.length > 0 && line[0] != ';') {
				if(line.startsWith("USING ")) {
					switch(line[6..$]) {
						case "PIANO":
						case "HARP":
							instrument = Instruments.PIANO;
							break;
						case "DOUBLE_BASS":
						case "DOUBLE BASS":
						case "BASS":
							instrument = Instruments.DOUBLE_BASS;
							break;
						case "SNARE_DRUM":
						case "SNARE DRUM":
						case "DRUM":
							instrument = Instruments.SNARE_DRUM;
							break;
						case "CLICKS":
						case "STICKS":
							instrument = Instruments.CLICKS;
							break;
						case "BASS_DRUM":
						case "BASS DRUM":
							instrument = Instruments.BASS_DRUM;
							break;
						default:
							throw new Exception("Unknown instrument \"" ~ line[6..$] ~ "\"");
					}
				} else if(line.startsWith("PAUSE ")) {
					pause = to!size_t(line[6..$].strip);
				} else {
					foreach(string note ; line.split(",")) {
						note = note.strip;
						if(note.length > 0) {
							if(note[0] == '@') {
								// pause
								foreach(size_t i ; 0..(note.length==1 ? pause : to!size_t(note[1..$]))) this.notes ~= new Note[0];
							} else if(note in NOTES) {
								this.notes ~= [Note(instrument, NOTES[note])];
							}
						}
					}
				}
			}
		}
	}
	
	enum NOTES = [
		"-F#": 0,
		"-G": 1,
		"-G#": 2,
		"A": 3,
		"A#": 4,
		"B": 5,
		"C": 6,
		"C#": 7,
		"D": 8,
		"D#": 9,
		"E": 10,
		"F": 11,
		"F#": 12,
		"G": 13,
		"G#": 14,
		"+A": 15,
		"+A#": 16,
		"+B": 17,
		"+C": 18,
		"+C#": 19,
		"+D": 20,
		"+D#": 21,
		"+E": 22,
		"+F": 23,
		"+F#": 24,
	];

}

void play(Music music, World world, EntityPosition position=EntityPosition.init, bool loop=true) {
	import sel.server : server; //TODO register the task on the world
	size_t pointer = 0;
	server.addTask({
		foreach(Note note ; music.notes[pointer]) {
			foreach(player ; world.players) {
				player.sendMusic(position.isNaN ? player.position : position, note.instrument, note.pitch);
			}
		}
		++pointer %= music.notes.length;
	}, 1, loop ? size_t.max : music.notes.length);
}

void play(string file, World world, EntityPosition position=EntityPosition.init, bool loop=true) {
	play(Music.fromFile(file), world, position, loop);
}
