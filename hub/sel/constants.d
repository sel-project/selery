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
module sel.constants;

import std.base64 : Base64;
import std.datetime : time_t;

/**
 * Size of the buffer for the SEL protocol (hub-node communication).
 * Some inbound packets may be very large.
 * Default: 8192
 */
enum size_t NODE_BUFFER_SIZE = 8192;

/**
 * Size of the receive buffer of the Minecraft: Pocket
 * Edition's handler. It should be slighly bigger than the
 * default mtu used by the game to avoid the allocation
 * of unused memory.
 * Default: 1464
 */
enum size_t POCKET_BUFFER_SIZE = 1464;

/**
 * Default: 12
 */
enum size_t POCKET_TIMEOUT = 12;

/**
 * Mojang's 120-bytes public key used for the login packet
 * encryption.
 */
enum ubyte[] MOJANG_PUBLIC_KEY = Base64.decode("MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE8ELkixyLcwlZryUQcu1TvPOmI2B7vX83ndnWRUaXm74wFfa5f/lwQNTfrLVHa2PmenpGI6JhIMUJaWZrjmMj90NoKNFSNBuKdm8rYiXsfaz3K36x/1U26HpG0ZxK/V1V");

/**
 * Default: 64
 */
enum int MINECRAFT_BACKLOG = 64;

enum size_t MINECRAFT_BUFFER_LENGTH = 2048;

enum time_t MINECRAFT_HANDLER_TPS = 1000;

enum size_t MINECRAFT_KEEP_ALIVE_TIMEOUT = 12;

enum bool MINECRAFT_ALLOW_LEGACY_PING = true;

enum bool QUERY_SHOW_MOTD = false;

enum bool QUERY_SHOW_PLAYERS = true;

enum uint QUERY_MAX_PLAYERS = 256;

enum int EXTERNAL_CONSOLE_BACKLOG = 16;

enum size_t EXTERNAL_CONSOLE_GENERIC_BUFFER_LENGTH = 1024;

enum time_t EXTERNAL_CONSOLE_AUTH_TIMEOUT = 24000;

enum size_t EXTERNAL_CONSOLE_LOGIN_ATTEMPS = 10;

enum bool EXTERNAL_CONSOLE_LOG_FAILED_ATTEMPTS = true;

enum time_t EXTERNAL_CONSOLE_TIMEOUT = 8000;

enum size_t EXTERNAL_CONSOLE_CONNECTED_BUFFER_LENGTH = 2048;

enum int RCON_BACKLOG = 16;

enum size_t RCON_CONNECTED_BUFFER_LENGTH = 1446;

enum int WEB_BACKLOG = 32;

enum size_t WEB_BUFFER_SIZE = 1024;

enum size_t MAX_WEB_CLIENTS = 32;

enum time_t WEB_TIMEOUT = 4000;

/**
 * Compression format for web resources.
 * Valid values are "gzip" and "deflate".
 * Default: gzip
 */
enum string WEB_COMPRESSION_FORMAT = "gzip";

enum int WEB_COMPRESSION_LEVEL = 6;

enum size_t JSON_STATUS_COMPRESSION_THRESOLD = 1024;

enum time_t JSON_STATUS_REFRESH_TIMEOUT = 10;

enum bool JSON_STATUS_SHOW_PLAYERS = true;

enum uint JSON_STATUS_MAX_PLAYERS = 512;
