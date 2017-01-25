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
module common.util.format;

enum Text : string {

	black = "§0",
	darkBlue = "§1",
	darkGreen = "§2",
	darkAqua = "§3",
	darkRed = "§4",
	darkPurple = "§5",
	gold = "§6",
	grey = "§7",
	darkGrey = "§8",
	blue = "§9",
	green = "§a",
	aqua = "§b",
	red = "§c",
	lightPurple = "§d",
	yellow = "§e",
	white = "§f",
	
	obfuscated = "§k",
	bold = "§l",
	strikethrough = "§m",
	underlined = "§n",
	italic = "§o",
	reset = "§r"
	
}

version(Windows) {

	import std.internal.cstring : tempCString;
	import std.string : split;

	import core.stdc.stdio : printf;
	import core.sys.windows.winbase : HANDLE, WORD, GetStdHandle, STD_OUTPUT_HANDLE;
	import core.sys.windows.wincon : SetConsoleTextAttribute;

	private HANDLE stdout;
	private WORD[char] map;

	static this() {

		stdout = GetStdHandle(STD_OUTPUT_HANDLE);

		with(Text) {
			map[black[$-1]] = 0;
			map[darkBlue[$-1]] = 1;
			map[darkGreen[$-1]] = 2;
			map[darkAqua[$-1]] = 3;
			map[darkRed[$-1]] = 4;
			map[darkPurple[$-1]] = 5;
			map[gold[$-1]] = 6;
			map[grey[$-1]] = 7;
			map[darkGrey[$-1]] = 8;
			map[blue[$-1]] = 9;
			map[green[$-1]] = 10;
			map[aqua[$-1]] = 11;
			map[red[$-1]] = 12;
			map[lightPurple[$-1]] = 13;
			map[yellow[$-1]] = 14;
			map[white[$-1]] = 15;
			//TODO formatting
			map[reset[$-1]] = 7;
		}

	}

	void writeln(string msg) {
		if(msg.length) {
			string[] spl = msg.split("§");
			string next = spl[0];
			if(spl.length > 1) {
				foreach(string part ; spl[1..$]) {
					if(part.length) {
						auto ptr = part[0] in map;
						if(ptr) {
							printf(next.tempCString());
							SetConsoleTextAttribute(stdout, *ptr);
							next = part[1..$];
						} else {
							next ~= "§" ~ part;
						}
					} else {
						next ~= "§";
					}
				}
			}
			printf(next.tempCString());
			SetConsoleTextAttribute(stdout, 7);
		}
		printf("\n");
	}

} else {

	static import std.stdio;
	import std.string : replace;

	enum Console : string {
		
		RESET = "\u001B[0m",
		
		BOLD = "\u001B[1m",
		UNDERLINED = "\u001B[2m",
		
		DEFAULT = "\u001B[39m",
		BLACK = "\u001B[30m",
		RED = "\u001B[31m",
		GREEN = "\u001B[32m",
		YELLOW = "\u001B[33m",
		BLUE = "\u001B[34m",
		MAGENTA = "\u001B[35m",
		CYAN = "\u001B[36m",
		GREY = "\u001B[37m",
		
		DARK_GREY = "\u001B[90m",
		LIGHT_RED = "\u001B[91m",
		LIGHT_GREEN = "\u001B[92m",
		LIGHT_YELLOW = "\u001B[93m",
		LIGHT_BLUE = "\u001B[94m",
		LIGHT_MAGENTA = "\u001B[95m",
		LIGHT_CYAN = "\u001B[96m",
		WHITE = "\u001B[97m",
		
	}

	void writeln(string msg) {
		std.stdio.writeln(msg
			.replace(Text.black.str, Console.BLACK.str)
			.replace(Text.darkBlue.str, Console.BLUE.str)
			.replace(Text.darkGreen.str, Console.GREEN.str)
			.replace(Text.darkAqua.str, Console.CYAN.str)
			.replace(Text.darkRed.str, Console.RED.str)
			.replace(Text.darkPurple.str, Console.MAGENTA.str)
			.replace(Text.gold.str, Console.YELLOW.str)
			.replace(Text.grey.str, Console.GREY.str)
			.replace(Text.darkGrey.str, Console.GREY.str)
			.replace(Text.blue.str, Console.LIGHT_BLUE.str)
			.replace(Text.green.str, Console.LIGHT_GREEN.str)
			.replace(Text.aqua.str, Console.LIGHT_CYAN.str)
			.replace(Text.red.str, Console.LIGHT_RED.str)
			.replace(Text.lightPurple.str, Console.LIGHT_MAGENTA.str)
			.replace(Text.yellow.str, Console.LIGHT_YELLOW.str)
			.replace(Text.white.str, Console.WHITE.str)
			.replace(Text.obfuscated.str, "")
			.replace(Text.bold.str, Console.BOLD.str)
			.replace(Text.strikethrough.str, "")
			.replace(Text.underlined.str, Console.UNDERLINED.str)
			.replace(Text.italic.str, "")
			.replace(Text.reset.str, Console.RESET.str)
		~ Console.RESET.str);
	}

	string str(T)(T t) {
		return t ~ "";
	}

}
