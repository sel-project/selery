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
/// DDOC_EXCLUDE
module sel.plugin;

public import common.format : Text;
public import common.sel;
public import common.util;

public import sel.settings;

public import sel.server : server;
public import sel.player;

public import sel.plugin.config : Config, _, Value, value;
public import sel.plugin.file : exists, isDir, isFile, read, write, remove;
public import sel.plugin.plugin : start, reload, stop, event, global, inherit, cancel, command, description, aliases, params, op, hidden, task, arguments;

public import sel.util.command : Position, Target;
public import sel.util.log : log, debug_log, warning_log, error_log;
