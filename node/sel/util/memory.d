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
module sel.util.memory;

import core.memory : GC;
import core.thread : dur, Thr = Thread;
import std.array : split;
import std.conv : ConvException, to;
import std.datetime : StopWatch;
import std.file : read;
import std.math : isNaN, round;
import std.process : executeShell, thisProcessID;
import std.string;

import sel.util.concurrency : Thread;

/**
 * Collection thread that does the actions of collection
 * an minimization every x seconds.
 */
class Collector : Thread {

	public override void run() {

		auto duration = dur!"seconds"(14);

		while(this.running) {
			Thr.sleep(duration);
			GC.collect();
			GC.minimize();
		}

	}

}

/**
 * Gets the current RAM usage.
 * Returns: the memory in bytes or nan if it was impossible to read the memory usage
 */
public @property ulong memory() {
	version(linux) {
		try {
			string[] output = split(split(cast(string)read("/proc/self/status"), "VmRSS")[1], " ");
			uint index = 0;
			while(index < output.length) {
				try {
					return to!ulong(round(to!float(output[index++])*1000));
				} catch(ConvException e) {}
			}
		} catch(Exception e) {}
	} else version(Windows) {
		foreach(string line ; split(executeShell("tasklist /fi \"pid eq " ~ to!string(thisProcessID) ~ "\"").output, "\n")) {
			if(line.indexOf("K") > 0) {
				string number = line[0..line.indexOf("K")-1];
				return to!ulong(number[number.lastIndexOf(" ")+1..$].replace(".", "")) * 1000;
			}
		}
	}
	//return float.nan;
	throw new Exception("Can't read memory");
}

/**
 * Gets the current CPU usage(0..cpus*100).
 * Doesn't work yet on Windows.
 * Returns: the used CPU as a percentage or nan if it was impossible to read the CPU usage
 */
public @property float cpu() {
	version(linux) {
		try {
			return to!float(strip(chomp(executeShell("ps -p " ~ to!string(thisProcessID) ~ " -o %cpu=").output)));
		} catch(Exception e) {}
	}
	return float.nan;
}

/**
 * Gets the highest amount of available RAM on the machine.
 * Doesn't work yet on Windows.
 * Returns: the highest amount of available memory in bytes or ulong.max if it was impossible to read it
 */
public @property ulong maxmemory(ulong mem) {
	ulong max = ulong.max;
	version(linux) {
		import std.file : read;
		string[] m = (cast(string)read("/proc/meminfo")).split("MemTotal:");
		if(m.length > 0) {
			m = m[1].split("kB");
			try {
				max = to!ulong(m[0].strip) * 1000;
			} catch(ConvException e) {}
		}
	}
	//get the indicated memory
	return mem < max ? mem : max;
}

/**
 * Gets the memory in bytes from a string.
 * Params:
 * 		value = a value formatted as "float type"
 * Returns: the given value in bytes, or 0 if bad formatting
 * Example:
 * ---
 * assert("100 kB".bytes == 100000);
 * assert("1000 MB".bytes == "1 GB".bytes);
 * ---
 */
public @property @safe ulong bytes(string value) {
	string[] mem = value.split(" ");
	if(mem.length == 2) {
		double num = to!double(mem[0]);
		switch(mem[1]) {
			case "B":
				break;
			case "kB":
				num *= 1000;
				break;
			case "KiB":
				num *= 1024;
				break;
			case "MB":
				num *= 1000 * 1000;
				break;
			case "MiB":
				num *= 1024 * 1024;
				break;
			case "GB":
				num *= 1000 * 1000 * 1000;
				break;
			case "GiB":
				num *= 1024 * 1024 * 1024;
				break;
			case "TB":
				num *= 1000 * 1000 * 1000 * 1000;
				break;
			case "TiB":
				num *= 1024 * 1024 * 1024 * 1024;
				break;
			case "PB":
				num *= 1000 * 1000 * 1000 * 1000 * 1000;
				break;
			case "PiB":
				num *= 1024 * 1024 * 1024 * 1024 * 1024;
				break;
			case "EB":
				num *= 1000 * 1000 * 1000 * 1000 * 1000 * 1000;
				break;
			case "EiB":
				num *= 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024;
				break;
			default:
				num = 0;
				break;
		}
		return to!ulong(num);
	}
	return ulong.init;
}

/**
 * Formats the given memory with the best unity of measurement.
 * Params:
 * 		mem = the memory to be formatted
 * 		bon = boolean value indicating whether or not to use powers of 2s instead of power of 10s
 * Returns: the formatted string
 * Example:
 * ---
 * assert(usage(1024, false) == "1.024 kB");
 * d(usage(memory));
 * ---
 */
public @property @safe string usage(double mem, bool bin=false) {
	if(mem.isNaN()) return "??? B";
	string[] values = bin ? ["B", "KiB", "MiB", "GiB", "TiB"] : ["B", "kB", "MB", "GB", "TB"];
	uint index = 0;
	uint div = bin ? 1024 : 1000;
	while(mem > div && index < values.length) {
		mem /= div;
		index++;
	}
	return to!string(round(mem*100)/100) ~ " " ~ values[index];
}

/**
 * Memory stored as bytes and available in various formats.
 * Example:
 * ---
 * assert(Memory(1000).kilobytes == 1);
 * assert(Memory("1 MB").megabytes != Memory("1 MB").mibibytes);
 * ---
 */
struct Memory {

	/**
	 * Gets the highest value possible (18 EiB).
	 */
	public static @property @safe @nogc Memory max() {
		return Memory(ulong.max);
	}

	private ulong b;

	/**
	 * Creates a Memory instance giving a certain
	 * amount of bytes.
	 */
	public @safe @nogc this(ulong b) {
		this.b = b;
	}

	/// ditto
	public @safe @nogc this(double b) {
		this(b <= 0 || b > ulong.max ? 0 : cast(ulong)b);
	}

	/**
	 * Creates a Memory instance from a formatted string
	 * that will be decoded using the bytes function.
	 */
	public @safe this(string data) {
		this(data.bytes);
	}

	/// Gets the memory in bytes.
	public @property @safe @nogc double B() {
		return this.b;
	}

	/// ditto
	alias Bytes = B;

	/// ditto
	alias bytes = B;

	/// Gets the memory in kilobytes.
	public @property double KB() {
		return this.B / 1000.0;
	}

	/// ditto
	alias KiloBytes = KB;

	/// ditto
	alias kilobytes = KB;

	/// Gets the memory in kibibytes.
	public @property double KiB() {
		return this.B / 1024.0;
	}

	/// ditto
	alias KibiBytes = KiB;

	/// ditto
	alias kibibytes = KiB;

	/// Gets the memory in megabytes.
	public @property double MB() {
		return this.KB / 1000.0;
	}

	/// ditto
	alias MegaBytes = MB;

	/// ditto
	alias megabytes = MB;

	/// Gets the memory in mebibytes.
	public @property double MiB() {
		return this.KiB / 1024.0;
	}

	/// ditto
	alias MebiByes = MiB;

	/// ditto
	alias mebibytes = MiB;

	/// Gets the memory in gigabytes.
	public @property double GB() {
		return this.MB / 1000.0;
	}

	/// ditto
	alias GigaBytes = GB;

	/// ditto
	alias gigabytes = GB;

	/// Gets the memory in gibibytes.
	public @property double GiB() {
		return this.MiB / 1024.0;
	}

	/// ditto
	alias GibiBytes = GiB;

	/// ditto
	alias gibibytes = GiB;

	/// Gets the memory in terabytes.
	public @property double TB() {
		return this.GB / 1000.0;
	}

	/// ditto
	alias TeraBytes = TB;

	/// ditto
	alias terabytes = TB;

	/// Gets the memory in tibibytes.
	public @property double TiB() {
		return this.GiB / 1024.0;
	}

	/// ditto
	alias TibiBytes = TiB;

	/// ditto
	alias tibibytes = TiB;

	/// Gets the memory in petabytes.
	public @property double PB() {
		return this.TB / 1000.0;
	}

	/// ditto
	alias PetaBytes = PB;

	/// ditto
	alias petabytes = PB;

	/// Gets the memory in pibibyes.
	public @property double PiB() {
		return this.TiB / 1024.0;
	}

	/// ditto
	alias PibiBytes = PiB;

	/// ditto
	alias pibibytes = PiB;

	/// Gets the memory in exabytes.
	public @property double EB() {
		return this.PB / 1000.0;
	}

	/// ditto
	alias ExaBytes = EB;

	/// ditto
	alias exabytes = EB;

	/// Gets the memory in exbibytes.
	public @property double EiB() {
		return this.PiB / 1024.0;
	}

	/// ditto
	alias ExbiBytes = EiB;

	/// ditto
	alias exbibytes = EiB;

	/**
	 * Compares two Memory instances and check if thay
	 * have the value.
	 * Example:
	 * ---
	 * assert(Memory(1000) == mem!"KB"(1));
	 * ---
	 */
	public bool opCmp(Memory mem) {
		return this.b == mem.b;
	}

	/**
	 * Returns the string formatted as the best option.
	 * See_Also: usage
	 */
	public string toString() {
		return usage(this.B);
	}

}

public @safe @nogc Memory memImpl(double m)(double value) {
	return Memory(value * m);
}

/**
 * Creates a Memory instance from an amount of bytes.
 * Params:
 * 		type = the type of memory that will be used for conversion
 * 		value = the value to be converted in bytes
 * Example:
 * ---
 * assert(mem!"MB"(1) == mem!"KB"(1000));
 * ---
 */
public @safe @nogc Memory mem(string type)(double value) if(type == "B" || type == "KB" || type == "KiB" || type == "MB" || type == "MiB" || type == "GB" || type == "GiB") {
	static if(type == "B") {
		return memImpl!(1)(value);
	} else static if(type == "KB") {
		return memImpl!(1000)(value);
	} else static if(type == "KiB") {
		return memImpl!(1024)(value);
	} else static if(type == "MB") {
		return memImpl!(1000 * 1000)(value);
	} else static if(type == "MiB") {
		return memImpl!(1024 * 1024)(value);
	} else static if(type == "GB") {
		return memImpl!(1000 * 1000 * 1000)(value);
	} else static if(type == "GiB") {
		return memImpl!(1024 * 1024 * 1024)(value);
	}
}
