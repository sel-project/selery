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
module sel.item.flags;

import common.sel;

struct VariableMetaFlag {}

struct ColorableFlag {}

public pure nothrow @property @safe auto ID(ushort id)() { return shortgroup(id, id); }

public pure nothrow @property @safe auto IDS(ushort pe, ushort pc)() { return shortgroup(pe, pc); }

public pure nothrow @property @safe auto META(ushort id)() { return shortgroup(id, id); }

public pure nothrow @property @safe auto METAS(ushort pe, ushort pc)() { return shortgroup(pe, pc); }

public pure nothrow @property @safe auto VARIABLE_META() { return VariableMetaFlag(); }

public pure nothrow @property @safe auto COLORABLE() { return ColorableFlag(); }
