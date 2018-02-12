Selery
======

[![Linux x86_64 build](https://sel-bot.github.io/status/sel-project/selery/linux_x86_64.svg)](https://travis-ci.org/sel-project/selery)
[![OS X x86_64 build](https://sel-bot.github.io/status/sel-project/selery/osx_x86_64.svg)](https://travis-ci.org/sel-project/selery)
[![Windows x86 build](https://sel-bot.github.io/status/sel-project/selery/windows_x86.svg)](https://ci.appveyor.com/project/Kripth/selery)
[![Windows x64 build](https://sel-bot.github.io/status/sel-project/selery/windows_x64.svg)](https://ci.appveyor.com/project/Kripth/selery)

Selery is a server for Minecraft (Bedrock Engine) and Minecraft: Java Edition written in [D](https://dlang.org).

## Installation

### From a pre-built package

[![GitHub release](https://img.shields.io/github/release/sel-project/selery.svg)](https://github.com/sel-project/selery/releases)

Pre-built packages are compiled with the latest version of LDC in release mode and can be found in the [releases](https://github.com/sel-project/selery/releases) page.

```
curl -Ls https://goo.gl/5kfhJG | bash
```

### From source

To build Selery from source you'll need a [D](https://dlang.org) compiler ([DMD](https://wiki.dlang.org/DMD) for faster compilation, suitable for testing, or
[LDC](https://wiki.dlang.org/LDC) for faster and better code, better for production) and [DUB](https://code.dlang.org/getting_started), D's package manager,
which is usually included in both DMD and LDC's packages.

Packages and installers are available for several operating systems and architectures at [dlang.org's download page](https://dlang.org/download.html).

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

The build scripts supports some useful options that can be viewed by launching it with `--help`.

:warning: Due to [issue 17508](https://issues.dlang.org/show_bug.cgi?id=17508), Windows x86 must be linked using Microsoft's compiler (`-a x86_mscoff`) instead of DMD's. This action is performed automatically by the build script.

## Setting up

Selery's configuration file is created when the server is started in the same path as the executable.
It is named `selery.toml` for the default configuration, `selery.hub.toml` for the hub and `selery.node.toml` for the node.

Every option can also be overriden by a command-line option without altering the configuration file.
```
selery --display-name="My Minecraft Server"
selery --java-enabled=false
selery --language=it
selery --command-me=false
selery --bedrock-accepted-protocols=160
selery --java-addresses=0.0.0.0:25565,192.168.1.216:8129
```

**More useful command-line options:**

- `--about` or `-a` to print the software's build informations in JSON format. The `--pretty` option can be used to print a pretty JSON instead of a minified one.
- `--init` or `-i` to initialize the configuration file.
- `--update-config` or `-uc` to rewrite the configuration file, maintaining the current configuration. It should be used after updating the software to a newer version that changes the configuration format.
- `--reset` to reset the whole configuration file to its default values.
