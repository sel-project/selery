Plugins are a way to extend the functionality of Selery.
They are written in D (like Selery) and are compiled with the server.

Official plugins can be found in [selery-plugins](https://github.com/selery-plugins).

## Structure

Plugins placed in the `plugins` folders are automatically compiled with Selery to create an executable file.

### plugin.toml

Every plugin must contain a `plugin.toml` file that indicates how and when compile the plugin.
The field are the following:
- `name`: Indicates the plugin's name. It must be unique on the server.
- `authors`: An array with the authors of the plugin.
- `target`: Whether the plugin is executed on the `hub` or on the `node`. Read the main README file for more informations about Selery's model.
- `main`: The main class of the plugin that must extend `HubPlugin` or `NodePlugin`.
- `dependencies`: One or more [DUB](https://code.dlang.org) dependencies.

#### Example

```toml
name = "example"
authors = ["Kripth"]
target = "node"
main = "example.main.Example"
```

### src

The source code of the plugin is located in the `src` folder. It's a best practice to use a namespace in your plugin, putting the source code in `src/{namespace}`, following the example given in the previous section in `src/example`.

#### Example

```d
module example.main;

import selery.node.plugin;

class Example : NodePlugin {

	@start onStart() {
		server.logger.log("Hello from an example plugin!");
	}

}
```
