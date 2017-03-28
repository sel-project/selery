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
module sel.util.format;

import std.algorithm : canFind;
import std.conv : to;
import std.regex : replaceAll, ctRegex;
import std.string : replace, toLower, strip;
import std.traits : EnumMembers;

import common.util.format : Text;

import sel.util : str;

/**
 * Formats two or more arrays to be centred, adding blank
 * spaces at the start of shorter strings.
 * That should be used in Minecraft: Pocket Edition tips
 * and popups:
 * Params;
 * 		string = array of the string to be centred
 * Returns: an array with the same length of the given one with the formatted strings
 */
public @safe string[] centre(string[] strings) {
	//trim all the strings
	foreach(uint i ; 0..strings.length.to!uint) {
		strings[i] = strings[i].strip;
	}
	uint[] lengths;
	uint highest = 0;
	foreach(uint index, string s; strings) {
		lengths ~= s.formatlength;
		if(lengths[index] > lengths[highest]) {
			highest = index;
		}
	}
	foreach(uint index, string str; strings) {
		if(str.length < lengths[highest]) {
			uint space = (lengths[highest] - lengths[index]) / 2 / 4;
			foreach(uint i ; 0..space) {
				str = ' ' ~ str;
			}
			strings[index] = str;
		}
	}
	return strings;
}

// gets the length of a character
private @safe uint formatlength(string s) {
	uint length = 0;
	bool bold = false;
	s = s.replaceAll(ctRegex!"§[a-fA-F0-9kmno]", "");
	for(uint i=0; i<s.length; i++) {
		char c = s[i];
		if(c == '§' && i < s.length-1) {
			char next = s[i+1];
			if(next == Text.bold[$-1]) {
				bold = true;
				i++;
				continue;
			} else if(next == Text.reset[$-1]) {
				bold = false;
				i++;
				continue;
			}
		}
		switch(c) {
			case 'i':
			case '.':
			case ',':
			case ':':
			case ';':
				length += 1;
				break;
			case 'l':
			case '\'':
				length += 2;
				break;
			case 't':
			case ' ':
			case 'I':
				length += 3;
				break;
			case 'f':
			case 'k':
			case '<':
			case '>':
			case '"':
				length += 4;
				break;
			default:
				length += 5;
				break;
		}
		length++;
		if(bold) length++;
	}
	return length == 0 ? 0 : --length;
}
