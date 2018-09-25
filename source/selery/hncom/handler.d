module selery.hncom.handler;

import std.string : capitalize;
import std.traits : hasUDA;
import std.typetuple : TypeTuple;

import selery.hncom.about : clientbound, serverbound;

import xbuffer : Buffer;

static import selery.hncom.status;
static import selery.hncom.player;

interface HncomHandler(alias type) if(is(type == clientbound ) || is(type == serverbound)) {
	
	mixin((){
		string ret;
		foreach(section ; TypeTuple!("status", "player")) {
			foreach(member ; __traits(allMembers, mixin("selery.hncom." ~ section))) {
				static if(member != "Packets" && hasUDA!(__traits(getMember, mixin("selery.hncom." ~ section), member), type)) {
					ret ~= "protected void handle" ~ capitalize(section) ~ member ~ "(selery.hncom." ~ section ~ "." ~ member ~ ");";
				}
			}
		}
		return ret;
	}());
	
	public final void handleHncom(Buffer buffer) {
		switch(buffer.peek!ubyte) {
			foreach(section ; TypeTuple!("status", "player")) {
				foreach(member ; __traits(allMembers, mixin("selery.hncom." ~ section))) {
					static if(hasUDA!(__traits(getMember, mixin("selery.hncom." ~ section), member), type)) {
						mixin("alias T = selery.hncom." ~ section ~ "." ~ member ~ ";");
						case T.ID: return mixin("this.handle" ~ capitalize(section) ~ member)(T.fromBuffer(buffer));
					}
				}
			}
			default: break;
		}
	}
	
}
