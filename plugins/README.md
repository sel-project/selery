Plugins are a way to extend the functionality of Selery.
They are written in D (like Selery) and are compiled with the server.

## Structure

Plugins placed in the `plugins` folders are automatically compiled with Selery to create an executable file.

Every plugin must contain a `plugin.toml` file that indicates how and when compile the plugin.
The field are the following:
- `name`: Indicates the plugin's name. It must be unique on the server.
- `authors`: An array with the authors of the plugin.
- `target`: Whether the plugin is executed on the `hub` or on the `node`. Read the main README file for more informations about Selery's model.
- `main`: The main class of the plugin that must extend `HubPlugin` or `NodePlugin`.
