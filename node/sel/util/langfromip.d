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
import std.conv : to;
import std.csv;
import std.file : read;
import std.typecons;
import std.socket : Address, InternetAddress, Internet6Address;
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

	private string[Slice] register;

	public this(string def, string[] accepted) {
		foreach(record ; csvReader!(Tuple!(string, "from", string, "to", string, "code"))(cast(string)read(Paths.res ~ "dbip-country.csv"))) {
			if(record.from.indexOf(".") != -1) {
				// ipv4
				string lang = this.languageFor(def, accepted, record.code);
				if(lang != server.settings.language) {
					this.register[Slice(this.ipcode(record.from), this.ipcode(record.to))] = lang;
				}
			} else {
				//TODO ipv6
			}
		}
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

	private @safe string languageFor(string def, string[] accepted, string country) {
		switch(country) {

			// italian
			case "IT":
			case "SM":
				if(accepted.canFind("it_IT")) return "it_IT";
				else goto default;

			// spanish
			case "ES":
				if(accepted.canFind("es_ES")) return "es_ES";
				else goto default;
			case "AR":
				if(accepted.canFind("es_AR")) return "es_AR";
				else goto case "ES";
			case "BO":
				if(accepted.canFind("es_BO")) return "es_BO";
				else goto case "ES";
			case "CL":
				if(accepted.canFind("es_CL")) return "es_CL";
				else goto case "ES";
			case "CO":
				if(accepted.canFind("es_CO")) return "es_CO";
				else goto case "ES";
			case "CR":
				if(accepted.canFind("es_CR")) return "es_CR";
				else goto case "ES";
			case "DO":
				if(accepted.canFind("es_DO")) return "es_DO";
				else goto case "ES";
			case "EC":
				if(accepted.canFind("es_EC")) return "es_EC";
				else goto case "ES";
			case "SV":
				if(accepted.canFind("es_SV")) return "es_SV";
				else goto case "ES";
			case "GT":
				if(accepted.canFind("es_GT")) return "es_GT";
				else goto case "ES";
			case "HN":
				if(accepted.canFind("es_HN")) return "es_HN";
				else goto case "ES";
			case "MX":
				if(accepted.canFind("es_MX")) return "es_MX";
				else goto case "ES";
			case "NI":
				if(accepted.canFind("es_NI")) return "es_NI";
				else goto case "ES";
			case "PA":
				if(accepted.canFind("es_PA")) return "es_PA";
				else goto case "ES";
			case "PY":
				if(accepted.canFind("es_PY")) return "es_PY";
				else goto case "ES";
			case "PE":
				if(accepted.canFind("es_PE")) return "es_PE";
				else goto case "ES";
			case "PR":
				if(accepted.canFind("es_PR")) return "es_PR";
				else goto case "ES";
			case "UY":
				if(accepted.canFind("es_UY")) return "es_UY";
				else goto case "ES";
			case "VE":
				if(accepted.canFind("es_VE")) return "es_VE";
				else goto case "ES";

			// english
			case "GB":
				if(accepted.canFind("en_GB")) return "en_GB";
				else goto default;
			case "AU":
				if(accepted.canFind("es_AU")) return "en_AU";
				else goto case "GB";
			case "BZ":
				if(accepted.canFind("en_BZ")) return "en_BZ";
				else goto case "GB";
			case "BW":
				if(accepted.canFind("en_BW")) return "en_BW";
				else goto case "GB";
			case "CA":
				if(accepted.canFind("en_CA")) return "en_CA";
				else goto case "GB";
			case "CB":
				if(accepted.canFind("en_CB")) return "en_CB";
				else goto case "GB";
			case "IE":
				if(accepted.canFind("en_IE")) return "en_IE";
				else goto case "GB";
			case "JM":
				if(accepted.canFind("en_JM")) return "en_JM";
				else goto case "GB";
			case "NZ":
				if(accepted.canFind("en_NZ")) return "en_NZ";
				else goto case "GB";
			case "ZA":
				if(accepted.canFind("en_ZA")) return "en_ZA";
				else goto case "GB";
			case "TT":
				if(accepted.canFind("en_TT")) return "en_TT";
				else goto case "GB";
			case "US":
				if(accepted.canFind("en_US")) return "en_US";
				else goto case "GB";
			case "ZW":
				if(accepted.canFind("en_ZW")) return "en_ZW";
				else goto case "GB";

			default:
				return def;
		}
	}

}
