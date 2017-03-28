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
module sel.player;

import sel.settings;

public import sel.player.player : Player, isPlayer, isPlayerInstance, Gamemode, PlayerOS, Puppet, Message;
static if(__pocket) public import sel.player.pocket : PocketPlayer;
static if(__minecraft) public import sel.player.minecraft : MinecraftPlayer;
