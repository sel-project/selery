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
module selery.util.messages;

import selery.lang : Translation;

final class Messages {

	@disable this();

	enum about : Translation {

		plugins = Translation("commands.about.plugins"),
		software = Translation("commands.about.software"),

	}

	enum deop : Translation {

		failed = Translation.all("commands.deop.failed"),
		message = Translation.fromPocket("commands.deop.message"),
		success = Translation.all("commands.deop.success"),

	}

	enum difficulty : Translation {

		success = Translation.all("commands.difficulty.success"),

	}

	enum gamemode : Translation {

		successOther = Translation.all("commands.gamemode.success.other"),
		successSelf = Translation.all("commands.gamemode.success.self"),

	}

	enum generic : Translation {

		invalidBoolean = Translation.all("commands.generic.boolean.invalid"),
		invalidParameter = Translation.all("commands.generic.parameter.invalid"),
		invalidSyntax = Translation.all("commands.generic.syntax"),				//TODO has 3 parameters on PE
		notFound = Translation.fromJava("commands.generic.notFound"),
		numInvalid = Translation.all("commands.generic.num.invalid"),
		numTooBig = Translation.all("commands.generic.num.tooBig"),
		numTooSmall = Translation.all("commands.generic.num.tooSmall"),
		playerNotFound = Translation("commands.kick.not.found", "commands.generic.player.notFound", "commands.kick.not.found"),
		targetNotFound = Translation.all("commands.generic.noTargetMatch"),
		targetNotPlayer = Translation.all("commands.generic.targetNotPlayer"),
		usage = Translation.all("commands.generic.usage"),

	}

	enum help : Translation {

		commandAliases = Translation.fromPocket("commands.help.command.aliases"),
		footer = Translation.all("commands.help.footer"),
		header = Translation.all("commands.help.header"),
		invalidSender = Translation("commands.help.invalidSender"),

	}

	enum kick : Translation {

		successReason = Translation.all("commands.kick.success.reason"),
		success = Translation.all("commands.kick.success"),

	}

	enum message : Translation {

		incoming = Translation.all("commands.message.display.incoming"),
		outcoming = Translation.all("commands.message.display.outgoing"),
		sameTarget = Translation.all("commands.message.sameTarget"),

	}

	enum op : Translation {

		failed = Translation.all("commands.op.failed"),
		message = Translation.fromPocket("commands.op.message"),
		success = Translation.all("commands.op.success"),

	}

	enum reload : Translation {

		success = Translation("commands.reload.success"),

	}

	enum seed : Translation {

		success = Translation.all("commands.seed.success"),

	}

	enum setmaxplayers : Translation {

		success = Translation.all("commands.setmaxplayers.success"), //TODO check java

	}

	enum stop : Translation {

		failed = Translation("commands.stop.failed"),
		start = Translation.all("commands.stop.start"),

	}

	enum toggledownfall : Translation {

		success = Translation.all("commands.downfall.success"),

	}

	enum transferserver : Translation {

		invalidPort = Translation.fromPocket("commands.transferserver.invalid.port"),
		success = Translation.fromPocket("commands.transferserver.successful"),

	}

	enum weather : Translation {

		clear = Translation.all("commands.weather.clear"),
		rain = Translation.all("commands.weather.rain"),
		thunder = Translation.all("commands.weather.thunder"),

	}

}
