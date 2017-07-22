/*
 * Copyright (c) 2017 SEL
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
module selery.files;

import std.file : exists, isFile, read, write;
import std.path : dirSeparator;
import std.string : endsWith;

/**
 * File manager for assets and temp files.
 */
class Files {

	public immutable string assets;
	public immutable string temp;
	
	public this(string assets, string temp) {
		if(!assets.endsWith(dirSeparator)) assets ~= dirSeparator;
		this.assets = assets;
		if(!temp.endsWith(dirSeparator)) temp ~= dirSeparator;
		this.temp = temp;
	}

	/**
	 * Indicates whether an asset exists.
	 * Returns: true if the asset exists, false otherwise
	 */
	public inout bool hasAsset(string file) {
		return exists(this.assets ~ file) && isFile(this.assets ~ file);
	}

	/**
	 * Reads the content of an asset.
	 * Throws: FileException if the file cannot be found.
	 */
	public inout void[] readAsset(string file) {
		return read(this.assets ~ file);
	}

	/**
	 * Indicates whether a temp file exists.
	 */
	public inout bool hasTemp(string file) {
		return exists(this.temp ~ temp) && isFile(this.temp ~ file);
	}

	/**
	 * Reads the content of a temp file.
	 */
	public inout void[] readTemp(string file) {
		return read(this.temp ~ file);
	}

	/**
	 * Writes buffer to a temp file.
	 */
	public inout void writeTemp(string file, const(void)[] buffer) {
		return write(file, buffer);
	}
	
}
