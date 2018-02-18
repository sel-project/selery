/*
 * Copyright (c) 2017-2018 sel-project
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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/selery/source/selery/node/plugin/file.d, selery/node/plugin/file.d)
 */
module selery.node.plugin.file;

static import std.file;
import std.path : dirSeparator;
import std.string : split, join, replace;

private string path(string mod)() {
	return "resources" ~ dirSeparator ~ mod.split(".")[0] ~ dirSeparator;
}

public @property bool exists(string mod=__MODULE__)(string file) {
	return std.file.exists(path!mod ~ file);
}

public @property bool isDir(string mod=__MODULE__)(string file) {
	return std.file.isDir(path!mod ~ file);
}

public @property bool isFile(string mod=__MODULE__)(string file) {
	return std.file.isFile(path!mod ~ file);
}

public void[] read(string mod=__MODULE__)(string file) {
	return std.file.read(path!mod ~ file);
}

public void write(string mod=__MODULE__)(string file, const void[] data) {
	version(Windows) {
		file = file.replace(`/`, `\`);
	} else {
		file = file.replace(`\`, `/`);
	}
	immutable dir = path!mod ~ file.split(dirSeparator)[0..$-1].join(dirSeparator);
	if(!std.file.exists(dir)) {
		std.file.mkdirRecurse(dir);
	}
	std.file.write(path!mod ~ file, data);
}

public void remove(string mod=__MODULE__)(string file) {
	std.file.remove(path!mod ~ file);
}
