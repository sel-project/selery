Selery [![GitHub release](https://img.shields.io/github/release/sel-project/selery.svg)](https://github.com/sel-project/selery/releases)
======

[![Linux x86_64 build](https://sel-bot.github.io/status/sel-project/selery/linux_x86_64_badge.svg)](https://travis-ci.org/sel-project/selery)
[![OS X x86_64 build](https://sel-bot.github.io/status/sel-project/selery/osx_x86_64_badge.svg)](https://travis-ci.org/sel-project/selery)
[![Windows x86 build](https://sel-bot.github.io/status/sel-project/selery/windows_x86_badge.svg)](https://ci.appveyor.com/project/Kripth/selery)
[![Windows x64 build](https://sel-bot.github.io/status/sel-project/selery/windows_x64_badge.svg)](https://ci.appveyor.com/project/Kripth/selery)

The server is still in development and some features are not supported yet.

Supported Minecraft (Bedrock Engine) versions:
- [1.2.7](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.7), [1.2.8](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.8) and [1.2.9](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.9)
- [1.2.6](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.6)
- [1.2.5](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.5)
- [1.2.0](https://minecraft.gamepedia.com/Bedrock_Edition_1.2), [1.2.1](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.1), [1.2.2](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.2) and [1.2.3](https://minecraft.gamepedia.com/Bedrock_Edition_1.2.3)

Supported Minecraft: Java Edition versions:
- [1.12](https://minecraft.gamepedia.com/1.12), [1.12.1](https://minecraft.gamepedia.com/1.12.1) and [1.12.2](https://minecraft.gamepedia.com/1.12.2)
- [1.11](https://minecraft.gamepedia.com/1.11), [1.11.1](https://minecraft.gamepedia.com/1.11.1) and [1.11.2](https://minecraft.gamepedia.com/1.11.2)
- [1.10](https://minecraft.gamepedia.com/1.10), [1.10.1](https://minecraft.gamepedia.com/1.10.1) and [1.10.2](https://minecraft.gamepedia.com/1.10.2)

## Installation

### From a pre-built package

Pre-built packages are compiled with the latest version of LDC in release mode and can be found in the [releases](https://github.com/sel-project/selery/releases) page.

### From source

- Clone the repository using `git clone git://github.com/sel-project/selery` or download the zipped repository from the latest release.
- If you want to use the latest release run `git checkout $(git describe --tags --abbrev=0)` in the repository's location.
- Build by running `build.bat` on Windows or `build.sh` on Linux/OS X.
- Run the generated executable file.

All in one:
```
git clone git://github.com/sel-project/selery
cd selery
./build.sh
```

## Structure

Selery is based on the [hub-node communication protocol](https://github.com/sel-project/sel-hncom), which means that it can run as two separate instances (hub and node), which are connected through a socket.

## Libraries

- [arsd-official:terminal](https://code.dlang.org/packages/arsd-official%3Aterminal)
- [diet-ng](https://code.dlang.org/packages/diet-ng)
- [imageformats](https://code.dlang.org/packages/imageformats) ([BSL-1.0 Licence](https://github.com/lgvz/imageformats/blob/master/LICENSE))
- [resusage](https://code.dlang.org/packages/resusage) ([BSL-1.0 Licence](https://github.com/FreeSlave/resusage/blob/master/LICENSE_1_0.txt))
- [sel-hncom](https://code.dlang.org/packages/sel-hncom) ([LGPL-3.0 Licence](https://github.com/sel-project/sel-hncom/blob/master/LICENSE))
- [sel-nbt](https://code.dlang.org/packages/sel-nbt) ([LGPL-3.0 Licence](https://github.com/sel-project/sel-nbt/blob/master/LICENSE))
- [sel-net](https://code.dlang.org/packages/sel-net) ([LGPL-3.0 Licence](https://github.com/sel-project/sel-net/blob/master/LICENSE))
- [sel-server](https://code.dlang.org/packages/sel-server) ([LGPL-3.0 Licence](https://github.com/sel-project/sel-server/blob/master/LICENSE))
- [sel-utils](https://code.dlang.org/packages/sel-utils)
- [string-transform-d](https://code.dlang.org/packages/string-transform-d)
- [toml](https://code.dlang.org/packages/toml)
- [toml:json](https://code.dlang.org/packages/toml%3Ajson)
