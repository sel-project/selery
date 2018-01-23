/*
 * Copyright (c) 2017-2018 SEL
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
module selery.util.messages;

import selery.lang : Translatable;

final class Messages {

	@disable this();

	enum about {

		plugins = Translatable("commands.about.plugins"),
		software = Translatable("commands.about.software"),

	}

	enum deop {

		failed = Translatable.all("commands.deop.failed"),
		message = Translatable.fromBedrock("commands.deop.message"),
		success = Translatable.all("commands.deop.success"),

	}

	enum difficulty {

		success = Translatable.all("commands.difficulty.success"),

	}

	enum gamemode {

		successOther = Translatable.all("commands.gamemode.success.other"),
		successSelf = Translatable.all("commands.gamemode.success.self"),

	}

	enum gamerule {

		invalidType = Translatable.fromBedrock("commands.gamerule.type.invalid"),
		success = Translatable.all("commands.gamerule.success"),

	}

	enum generic {

		invalidBoolean = Translatable.all("commands.generic.boolean.invalid"),
		invalidParameter = Translatable.all("commands.generic.parameter.invalid"),
		invalidSyntax = Translatable.fromJava("commands.generic.syntax"),
		notFound = Translatable.fromJava("commands.generic.notFound"),
		notFoundConsole = Translatable("commands.generic.notFound.console"),
		notImplemented = Translatable.fromBedrock("commands.generic.notimplemented"),
		numInvalid = Translatable.all("commands.generic.num.invalid"),
		numTooBig = Translatable.all("commands.generic.num.tooBig"),
		numTooSmall = Translatable.all("commands.generic.num.tooSmall"),
		playerNotFound = Translatable("commands.kick.not.found", "commands.generic.player.notFound", "commands.kick.not.found"),
		targetNotFound = Translatable.all("commands.generic.noTargetMatch"),
		targetNotPlayer = Translatable.all("commands.generic.targetNotPlayer"),
		usage = Translatable.all("commands.generic.usage"),
		usageNoParam = Translatable.fromBedrock("commands.generic.usage.noparam"),

	}

	enum help {

		commandAliases = Translatable.fromBedrock("commands.help.command.aliases"),
		footer = Translatable.all("commands.help.footer"),
		header = Translatable.all("commands.help.header"),
		invalidSender = Translatable("commands.help.invalidSender"),

	}

	enum kick {

		successReason = Translatable.all("commands.kick.success.reason"),
		success = Translatable.all("commands.kick.success"),

	}

	enum list {

		players = Translatable.all("commands.players.list"),

	}

	enum message {

		incoming = Translatable.all("commands.message.display.incoming"),
		outcoming = Translatable.all("commands.message.display.outgoing"),
		sameTarget = Translatable.all("commands.message.sameTarget"),

	}

	enum op {

		failed = Translatable.all("commands.op.failed"),
		message = Translatable.fromBedrock("commands.op.message"),
		success = Translatable.all("commands.op.success"),

	}

	enum reload {

		success = Translatable("commands.reload.success"),

	}

	enum seed {

		success = Translatable.all("commands.seed.success"),

	}

	enum setmaxplayers {

		success = Translatable.all("commands.setmaxplayers.success"), //TODO check java

	}

	enum stop {

		failed = Translatable("commands.stop.failed"),
		start = Translatable.all("commands.stop.start"),

	}

	enum time {

		added = Translatable.all("commands.time.added"),
		queryDay = Translatable.fromBedrock("commands.time.query.day"),
		queryDaytime = Translatable.fromBedrock("commands.time.query.daytime"),
		queryGametime = Translatable.fromBedrock("commands.time.query.gametime"),
		set = Translatable.all("commands.time.set"),

	}

	enum toggledownfall {

		success = Translatable.all("commands.downfall.success"),

	}

	enum transferserver {

		invalidPort = Translatable.fromBedrock("commands.transferserver.invalid.port"),
		success = Translatable.fromBedrock("commands.transferserver.successful"),

	}

	enum weather {

		clear = Translatable.all("commands.weather.clear"),
		rain = Translatable.all("commands.weather.rain"),
		thunder = Translatable.all("commands.weather.thunder"),

	}

}
