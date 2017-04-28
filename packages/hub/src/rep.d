module rep;

import std.file;
import std.string;

void main(string[] args) {

	foreach(string file ; dirEntries("hub", SpanMode.breadth)) {
		if(file.isFile) {
			write(file, replace(cast(string)read(file), "sel.", "hub."));
		}
	}

}
