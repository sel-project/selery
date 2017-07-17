![SEL Logo](https://i.imgur.com/cTu1FE5.png)

**A Server for Minecraft and Minecraft: Pocket Edition written in [D](https://dlang.org)**

[![Join Chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sel-project/Lobby)
[![Build Status](https://travis-ci.org/sel-project/selery.svg?branch=master)](https://travis-ci.org/sel-project/selery)
[![Build status](https://ci.appveyor.com/api/projects/status/k92u01kgy09rbwmm?svg=true)](https://ci.appveyor.com/project/Kripth/selery)

The server is still in development and some features are not supported yet.

![Minecraft versions](https://img.shields.io/badge/Minecraft-1.10%20--%201.12-brightgreen.svg)

![Minecraft: Pocket Edition versions](https://img.shields.io/badge/Minecraft%3A%20Pocket%20Edition-1.1-brightgreen.svg)

### Structure

SEL is based on the [hub-node communication protocol](https://sel-utils.github.io/protocol/hncom), which means that it can run as two separate instances (hub and node), which are connected through a socket.

## Create a server

:warning: does not work with DMD >2.074

:warning: doesn't compile using 32-bit DMD

:warning: doesn't work using DMD in release mode

```
git clone git://github.com/sel-project/selery
cd selery/builder
dub --single init.d
dub build
cd ..
./selery-default [-edu] [-realm]
```

If you're on Windows you must compile using a 64-bit architecture (for example `dub build -a x86_64`)
