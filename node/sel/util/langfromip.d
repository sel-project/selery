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
module sel.util.langfromip;

import std.algorithm : canFind;
import std.bitmanip : peek, nativeToBigEndian;
import std.conv : to;
import std.csv;
import std.file : read, write;
import std.typecons;
import std.socket : Address, InternetAddress, Internet6Address, getAddress;
import std.string : split, indexOf;

import common.path : Paths;

import sel.server : server;

/**
 * Class containing informations about IP's location to
 * set a player's language from its position.
 * Only the langauges indicated as available in the SEL's
 * configuration file are loaded.
 * The csv file that contains the IPs is taken from https://db-ip.com/db/download/country
 *
 * Only IP v4 is currently supported.
 */
class LangSearcher {

	alias Slice = Tuple!(uint, "min", uint, "max");

	private immutable string language;
	private immutable string[] accepted;

	private string[Slice] register;

	public this(string language, string[] accepted) {
		this.language = language;
		this.accepted = accepted.idup;
	}

	public void fromCSV() {
		foreach(record ; csvReader!(Tuple!(string, "from", string, "to", string, "code"))(cast(string)read(Paths.res ~ "dbip-country.csv"))) {
			if(record.from.indexOf(".") != -1) {
				// ipv4
				string lang = this.languageFor(record.code);
				if(lang != this.language) {
					this.register[Slice(this.ipcode(record.from), this.ipcode(record.to))] = lang;
				}
			} else {
				//TODO ipv6
			}
		}
	}

	public void fromBin() {
		ubyte[] data = cast(ubyte[])read(Paths.res ~ "dbip-country.bin");
		size_t index = 0;
		while(index < data.length) {
			string lang = this.languageFor(cast(string)data[index..index+2].dup);
			Slice[] slices;
			index += 2;
			foreach(i ; 0..peek!ushort(data, &index)) {
				slices ~= Slice(peek!uint(data, &index), peek!uint(data, &index));
			}
			foreach(i ; 0..peek!ushort(data, &index)) {
				//TODO read 32 bytes
				index += 32;
			}
			if(lang != this.language) {
				foreach(slice ; slices) this.register[slice] = lang;
			}
		}
	}

	/**
	 * Format:
	 * 		[
	 * 			country (char[2])
 	 * 			ipv4 length (ushort-be) [
 	 * 				from (uint-be)
 	 * 				to (uint-be)
 	 * 			]
 	 * 			ipv6 length (ushort-be) [
 	 * 				from (ubyte[16])
 	 * 				to (ubyte[16])
 	 * 			]
	 * 		]
	 * 		eof
	 */
	public void convert() {
		Tuple!(uint[], "v4", ubyte[16][], "v6")[string] addresses;
		foreach(record ; csvReader!(Tuple!(string, "from", string, "to", string, "code"))(cast(string)read(Paths.res ~ "dbip-country.csv"))) {
			if(record.code !in addresses) addresses[record.code] = typeof(addresses[""]).init;
			if(record.from.indexOf(".") != -1) {
				// ipv4
				addresses[record.code].v4 ~= [InternetAddress.parse(record.from), InternetAddress.parse(record.to)];
			} else {
				//TODO ipv6
			}
		}
		ubyte[] data;
		foreach(string country, addr; addresses) {
			data ~= cast(ubyte[])country;
			data ~= nativeToBigEndian(cast(ushort)(addr.v4.length / 2));
			foreach(v4 ; addr.v4) {
				data ~= nativeToBigEndian(v4);
			}
			data ~= nativeToBigEndian(cast(ushort)(addr.v6.length / 2));
			foreach(v6 ; addr.v6) {
				data ~= v6;
			}
		}
		write(Paths.res ~ "dbip-country.bin", data);
	}

	private @safe uint ipcode(string ip) {
		return InternetAddress.parse(ip); //TODO what if it's IPv6?
	}

	/**
	 * Gets a language for an IP address.
	 * Params:
	 * 		sip = an IP address encoded as xxx.xxx.xxx.xxx
	 * Returns: the language for the IP's country or the default one is the region's country isn't available
	 */
	public @safe string langFor(int ip) {
		foreach(Slice slice, string code; this.register) {
			if(ip >= slice.min && ip <= slice.max) {
				return code;
			}
		}
		return server.settings.language;
	}
	
	//TODO ip v6
	public @safe string langFor(ubyte[16] ip) {
		return server.settings.language;
	}

	/// ditto
	public string langFor(Address address) {
		if(cast(InternetAddress)address) {
			return this.langFor((cast(InternetAddress)address).addr);
		} else if(cast(Internet6Address)address) {
			return this.langFor((cast(Internet6Address)address).addr);
		} else {
			return server.settings.language;
		}
	}

	private @safe string languageFor(string country) {
		switch(country) {

			// italian
			case "IT":
			case "SM":
				if(this.accepted.canFind("it_IT")) return "it_IT";
				else goto default;

			// spanish
			case "ES":
				if(this.accepted.canFind("es_ES")) return "es_ES";
				else goto default;
			case "AR":
				if(this.accepted.canFind("es_AR")) return "es_AR";
				else goto case "ES";
			case "BO":
				if(this.accepted.canFind("es_BO")) return "es_BO";
				else goto case "ES";
			case "CL":
				if(this.accepted.canFind("es_CL")) return "es_CL";
				else goto case "ES";
			case "CO":
				if(this.accepted.canFind("es_CO")) return "es_CO";
				else goto case "ES";
			case "CR":
				if(this.accepted.canFind("es_CR")) return "es_CR";
				else goto case "ES";
			case "DO":
				if(this.accepted.canFind("es_DO")) return "es_DO";
				else goto case "ES";
			case "EC":
				if(this.accepted.canFind("es_EC")) return "es_EC";
				else goto case "ES";
			case "SV":
				if(this.accepted.canFind("es_SV")) return "es_SV";
				else goto case "ES";
			case "GT":
				if(this.accepted.canFind("es_GT")) return "es_GT";
				else goto case "ES";
			case "HN":
				if(this.accepted.canFind("es_HN")) return "es_HN";
				else goto case "ES";
			case "MX":
				if(this.accepted.canFind("es_MX")) return "es_MX";
				else goto case "ES";
			case "NI":
				if(this.accepted.canFind("es_NI")) return "es_NI";
				else goto case "ES";
			case "PA":
				if(this.accepted.canFind("es_PA")) return "es_PA";
				else goto case "ES";
			case "PY":
				if(this.accepted.canFind("es_PY")) return "es_PY";
				else goto case "ES";
			case "PE":
				if(this.accepted.canFind("es_PE")) return "es_PE";
				else goto case "ES";
			case "PR":
				if(this.accepted.canFind("es_PR")) return "es_PR";
				else goto case "ES";
			case "UY":
				if(this.accepted.canFind("es_UY")) return "es_UY";
				else goto case "ES";
			case "VE":
				if(this.accepted.canFind("es_VE")) return "es_VE";
				else goto case "ES";

			// english
			case "GB":
				if(this.accepted.canFind("en_GB")) return "en_GB";
				else goto default;
			case "AU":
				if(this.accepted.canFind("es_AU")) return "en_AU";
				else goto case "GB";
			case "BZ":
				if(this.accepted.canFind("en_BZ")) return "en_BZ";
				else goto case "GB";
			case "BW":
				if(this.accepted.canFind("en_BW")) return "en_BW";
				else goto case "GB";
			case "CA":
				if(this.accepted.canFind("en_CA")) return "en_CA";
				else goto case "GB";
			case "CB":
				if(this.accepted.canFind("en_CB")) return "en_CB";
				else goto case "GB";
			case "IE":
				if(this.accepted.canFind("en_IE")) return "en_IE";
				else goto case "GB";
			case "JM":
				if(this.accepted.canFind("en_JM")) return "en_JM";
				else goto case "GB";
			case "NZ":
				if(this.accepted.canFind("en_NZ")) return "en_NZ";
				else goto case "GB";
			case "ZA":
				if(this.accepted.canFind("en_ZA")) return "en_ZA";
				else goto case "GB";
			case "TT":
				if(this.accepted.canFind("en_TT")) return "en_TT";
				else goto case "GB";
			case "US":
				if(this.accepted.canFind("en_US")) return "en_US";
				else goto case "GB";
			case "ZW":
				if(this.accepted.canFind("en_ZW")) return "en_ZW";
				else goto case "GB";

			default:
				return this.language;
		}
	}

}
