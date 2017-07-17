![SEL Logo](https://i.imgur.com/cTu1FE5.png)

**A Server for Minecraft and Minecraft: Pocket Edition written in [D](https://dlang.org)**

[![Join Chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sel-project/Lobby)
[![Build Status](https://travis-ci.org/sel-project/selery.svg?branch=master)](https://travis-ci.org/sel-project/selery)
[![Build status](https://ci.appveyor.com/api/projects/status/k92u01kgy09rbwmm?svg=true)](https://ci.appveyor.com/project/Kripth/selery)

The server is still in development and some features are not supported yet.

![Minecraft versions](https://img.shields.io/badge/Minecraft-1.10%20--%201.12-brightgreen.svg)

![Minecraft: Pocket Edition versions](https://img.shields.io/badge/Minecraft%3A%20Pocket%20Edition-1.1-brightgreen.svg)

### Structure

SEL is based on the [hub-node communication protocol](https://sel-utils.github.io/protocol/hncom), which means that it must always run as two separate instances (hub and node), which are connected through a socket.

## Create a server

Before building any configuration the plugins should be initialized:
```
cd init
dub run
```

#### Lite (hub + 1 node)

:warning: doesn't compile using 32-bit DMD

:warning: doesn't work using DMD in release mode

```
cd build
dub build --config=lite
./selery [-edu] [-realm] [custom-args]
```

#### Hub

```
cd build
dub build --config=hub
./selery-hub [-edu] [-realm]
```

#### Node

:warning: does not work with DMD >2.074

```
cd build
dub build --config=node
./selery-node [--name=node] [--ip=localhost] [--port=28232] [--main=true] [--password=] [custom-args]
```
