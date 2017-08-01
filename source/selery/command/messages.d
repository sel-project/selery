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
deprecated module selery.command.messages;

import selery.lang : Translation;

enum ABOUT_PLUGINS = Translation("commands.about.plugins");
enum ABOUT_SOFTWARE = Translation("commands.about.software");

enum DEOP_FAILED = Translation.all("commands.deop.failed");
enum DEOP_MESSAGE = Translation.fromPocket("commands.deop.message");
enum DEOP_SUCCESS = Translation.all("commands.deop.success");

enum DIFFICULTY_SUCCESS = Translation.all("commands.difficulty.success");

enum GAMEMODE_SUCCESS_OTHER = Translation.all("commands.gamemode.success.other");
enum GAMEMODE_SUCCESS_SELF = Translation.all("commands.gamemode.success.self");

enum GENERIC_INVALID_BOOLEAN = Translation.all("commands.generic.boolean.invalid");
enum GENERIC_INVALID_PARAMETER = Translation.all("commands.generic.parameter.invalid");
enum GENERIC_INVALID_SYNTAX = Translation.all("commands.generic.syntax");				//TODO has 3 parameters on PE
enum GENERIC_NOT_FOUND = Translation.fromMinecraft("commands.generic.notFound");
enum GENERIC_NUM_INVALID = Translation.all("commands.generic.num.invalid");
enum GENERIC_NUM_TOO_BIG = Translation.all("commands.generic.num.tooBig");
enum GENERIC_NUM_TOO_SMALL = Translation.all("commands.generic.num.tooSmall");
enum GENERIC_PLAYER_NOT_FOUND = Translation("commands.kick.not.found", "commands.generic.player.notFound", "commands.kick.not.found");
enum GENERIC_TARGET_NOT_FOUND = Translation.all("commands.generic.noTargetMatch");
enum GENERIC_TARGET_NOT_PLAYER = Translation.all("commands.generic.targetNotPlayer");
enum GENERIC_USAGE = Translation.all("commands.generic.usage");

enum HELP_COMMAND_ALIASES = Translation.fromPocket("commands.help.command.aliases");
enum HELP_FOOTER = Translation.all("commands.help.footer");
enum HELP_HEADER = Translation.all("commands.help.header");
enum HELP_INVALID_SENDER = Translation("commands.help.invalidSender");

enum KICK_SUCCESS_REASON = Translation.all("commands.kick.success.reason");
enum KICK_SUCCESS = Translation.all("commands.kick.success");

enum MESSAGE_INCOMING = Translation.all("commands.message.display.incoming");
enum MESSAGE_OUTGOING = Translation.all("commands.message.display.outgoing");
enum MESSAGE_SAME_TARGET = Translation.all("commands.message.sameTarget");

enum OP_FAILED = Translation.all("commands.op.failed");
enum OP_MESSAGE = Translation.fromPocket("commands.op.message");
enum OP_SUCCESS = Translation.all("commands.op.success");

enum RELOAD_SUCCESS = Translation("commands.reload.success");

enum SEED_SUCCESS = Translation.all("commands.seed.success");

enum STOP_FAILED = Translation("commands.stop.failed");
enum STOP_START = Translation.all("commands.stop.start");

enum TOGGLEDOWNFALL_SUCCESS = Translation.all("commands.downfall.success");

enum TRANSFERSERVER_INVALID_PORT = Translation.fromPocket("commands.transferserver.invalid.port");
enum TRANSFERSERVER_SUCCESS = Translation.fromPocket("commands.transferserver.successful");

enum WEATHER_CLEAR = Translation.all("commands.weather.clear");
enum WEATHER_RAIN = Translation.all("commands.weather.rain");
enum WEATHER_THUNDER = Translation.all("commands.weather.thunder");
