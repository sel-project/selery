![SEL Logo](http://i.imgur.com/jPfQuZ0.png)

**A Server for Minecraft and Minecraft: Pocket Edition written in D**

[![Build Status](https://travis-ci.org/sel-project/sel-server.svg?branch=master)](https://travis-ci.org/sel-project/sel-server)
[![Build status](https://ci.appveyor.com/api/projects/status/9siwvb0p8l9yhx77?svg=true)](https://ci.appveyor.com/project/Kripth/sel-server)

The server is still in development and some features are not supported yet.

### Structure

SEL is based built on the [hub-node communication protocol](https://sel-project.github.io/sel-utils/hncom/1.html), which means that it must always run as two separate softwares (hub and node), which are connected through sockets.

### Create a server

SEL uses a manager to create, compile, run and delete servers. The instructions for the installation can be found at [sel-manager](https://github.com/sel-project/sel-manager)'s [README](https://github.com/sel-project/sel-manager/blob/master/README.md) file.

#### Full

A full server is composed by an hub and a node automatically connected to each other by the manager. The result will look like a single server. This type of the server can be used by small servers that can handle all the players on a single node.

```
sel init <server> full [-version=latest] [-path=auto] [-edu] [-realm]
sel build <server> [dmd-options]
sel start <server>
```

#### Hub

An hub is the network of the server. It handles the new connections, performs checks on the ips, does uncompression, handles queries and external consoles. An hub alone can be seen in the players' server list and can also accep players, but it will kick them because the server is full. To work properly at least one main node should be connected to the hub.

```
sel init <server> hub [-version=latest] [-path=auto] [-edu] [-realm]
sel build <server> [dmd-options]
sel start <server>
```

#### Node

```
sel init <server> node [-version=latest] [-path=auto]
sel build <server> [dmd-options]
sel connect <server> [-ip=localhost] [-port=28232] [-name=<server>] [-password=] [-main=true]
```

### Installing a plugin

Plugins can be added, updated and removed using the manager.

`sel <server> plugin add <plugin>`
`sel <server> plugin update <plugin>`
`sel <server> plugin remove <plugin>`

The available plugins are published at [sel-plugins](https://github.com/sel-project/sel-plugins).

### Features

* hub

	- [x] Support for multiple protocols
	- [x] Minecraft
	- [ ] Minecraft's authentication
	- [ ] Minecraft's encryption
	- [x] Minecraft: Pocket Edition
	- [ ] Minecraft: Pocket Edition's authentication
	- [ ] Minecraft: Pocket Edition's encryption
	- [x] External Console
	- [x] RCON
	- [x] Google Analytics
	- [x] Web page with server's informations and players
	
* node

	- [x] Support for multiple protocols
	- [x] Multiworld
	- [x] Chat
	- [x] Events
	- [x] PVP
	- [ ] Inventory (partial on Minecraft)
	- [x] Block's breaking
	- [ ] Block's placing
	
