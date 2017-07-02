![SEL Logo](https://i.imgur.com/cTu1FE5.png)

**A Server for Minecraft and Minecraft: Pocket Edition written in D**

[![Join chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sel-project/Lobby)
[![Build Status](https://travis-ci.org/sel-project/sel-server.svg?branch=master)](https://travis-ci.org/sel-project/sel-server)
[![Build status](https://ci.appveyor.com/api/projects/status/9siwvb0p8l9yhx77?svg=true)](https://ci.appveyor.com/project/Kripth/sel-server)

The server is still in development and some features are not supported yet.

### Structure

SEL is based on the [hub-node communication protocol](https://sel-utils.github.io/hncom/2.html), which means that it must always run as two separate instances (hub and node), which are connected through a socket.

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
