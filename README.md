![SEL Logo](https://i.imgur.com/cTu1FE5.png)

**A Server for Minecraft and Minecraft: Pocket Edition written in D**

[![Join chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sel-project/Lobby)
[![Build Status](https://travis-ci.org/sel-project/sel-server.svg?branch=master)](https://travis-ci.org/sel-project/sel-server)
[![Build status](https://ci.appveyor.com/api/projects/status/9siwvb0p8l9yhx77?svg=true)](https://ci.appveyor.com/project/Kripth/sel-server)

The server is still in development and some features are not supported yet.

### Structure

SEL is based on the [hub-node communication protocol](https://sel-utils.github.io/hncom/2.html), which means that it must always run as two separate instances (hub and node), which are connected through a socket.

## Create a server

### Using SEL Manager

SEL uses a manager to create, compile, run and delete servers. The instructions for the installation can be found at [sel-manager](https://github.com/sel-project/sel-manager/tree/sel-server-2)'s [README](https://github.com/sel-project/sel-manager/blob/sel-server-2/README.md) file.

#### Lite

A lite server is composed by an hub and a node automatically connected to each other. The result will look like a single server. This type of the server can be used by small servers that can handle all the players on a single node.

```
sel init <server> --version=~master [--path=auto] [-edu] [-realm]
sel build <server> [-release] [dub-options]
sel start <server>
```

#### Hub

An hub is the network of the server. It handles the new connections, performs checks on the ips, does uncompression, handles queries and external consoles. An hub alone can be seen in the players' server list and can also accept players, but it will kick them because the server is full. To work properly at least one main node should be connected to the hub.

```
sel init <server> --type=hub --version=~master [--path=auto] [-edu] [-realm]
sel build <server> [-release] [dub-options]
sel start <server>
```

#### Node

```
sel init <server> --type=node --version=~master [--path=auto]
sel build <server> [-release] [dub-options]
sel connect <server> [--name=<server>] [--ip=localhost] [--port=28232] [--password=] [--main=true]
```

### Using DUB

Before building any configuration the plugins should be initialized:
```
cd init
dub run
```

#### Lite

```
cd build
dub build --config=lite
./lite [-edu] [-realm] [custom-args]
```

#### Hub

```
cd build
dub build --config=hub
./hub [-edu] [-realm]
```

#### Node

:warning: does not work with DMD 2.074

```
cd build
dub build --config=node
./node [--name=node] [--ip=localhost] [--port=28232] [--main=true] [--password=] [custom-args]
```
