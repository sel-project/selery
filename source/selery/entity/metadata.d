/*
 * Copyright (c) 2017-2019 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright (c) 2017-2019 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/entity/metadata.d, selery/entity/metadata.d)
 */
module selery.entity.metadata;

import std.conv : to;
import std.string : join, startsWith;
import std.typetuple : TypeTuple;

import selery.about;

// still named "minecraft" in sel-utils
mixin("alias Games = TypeTuple!(" ~ (){ string[] ret;foreach(g,pr;["bedrock":supportedBedrockProtocols,"java":supportedJavaProtocols]){foreach(p;pr){ret~="\""~g~p.to!string~"\"";}}return ret.join(","); }() ~ ");");

mixin((){
	string ret;
	foreach(immutable game ; Games) {
		ret ~= "static import sul.metadata." ~ game ~ ";";
	}
	return ret;
}());

class Metadata {

	mixin((){
		string ret;
		foreach(immutable game ; Games) {
			ret ~= "public sul.metadata." ~ game ~ ".Metadata " ~ game ~ ";";
		}
		return ret;
	}());

	public bool changed = false;

	public pure nothrow @safe this() {
		foreach(immutable game ; Games) {
			mixin("this." ~ game ~ " = new sul.metadata." ~ game ~ ".Metadata();");
		}
	}

	T get(string m, T)() {
		enum string game = (){
			string ret = "";
			foreach(immutable g ; Games) {
				mixin("alias T = sul.metadata." ~ g ~ ".Metadata;");
				static if(__traits(hasMember, T, m)) ret = g;
			}
			return ret;
		}();
		static if(game.length) {
			mixin("return this." ~ game ~ "." ~ m ~ ";");
		} else {
			return T.init;
		}
	}

	T set(string m, string filter, T)(T value) {
		foreach(immutable game ; Games) {
			static if(!filter.length || game.startsWith(filter)) {
				mixin("alias T = sul.metadata." ~ game ~ ".Metadata;");
				static if(__traits(hasMember, T, m)) {
					this.changed = true;
					mixin("this." ~ game ~ "." ~ m ~ " = value;");
				}
			}
		}
		return value;
	}

	T set(string m, T)(T value) {
		return this.set!(m, "")(value);
	}

}
