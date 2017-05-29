module sel.util.hncom;

import std.conv : to;
import std.string : capitalize;
import std.typetuple : TypeTuple;

import sel.about : Software;

private enum smod = "sul.protocol.hncom" ~ to!string(Software.hncom) ~ ".";
private alias Sections = TypeTuple!("util", "login", "status", "player", "world", "types");

mixin((){
	string ret;
	foreach(section ; Sections) {
		ret ~= "public import Hncom" ~ capitalize(section) ~ "=" ~ smod ~ section ~ ";";
	}
	return ret;
}());

/+mixin((){
	string ret;
	foreach(section ; Sections) {
		//mixin("static import " ~ smod ~ section ~ ";");
		ret ~= "public struct Hncom" ~ capitalize(section) ~ "{@disable this();";
		static if(is(typeof(mixin(smod ~ section ~ ".Packets.length")))) {
			ret ~= "alias Packets = " ~ smod ~ section ~ ".Packets;";
		}
		foreach(Packet ; __traits(allMembers, mixin(smod ~ section))) {
			mixin("alias _packet = " ~ smod ~ section ~ "." ~ packet ~ ";");
			static if(is(_packet == class) || is(_packet == struct)) {
				ret ~= "alias " ~ packet ~ "=" ~ smod ~ section ~ "." ~ packet ~ ";";
			}
		}
		ret ~= "}";
	}
	return ret;
}());+/
