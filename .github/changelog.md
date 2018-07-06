### 0.3.0

The [sel-hncom](https://github.com/sel-project/sel-hncom) library has been merged
with Selery and now uses the [packet-maker](https://github.com/Kripth/packet-maker)
library.

New library for reading roman numbers.

### 0.2.0

The parent/children model for worlds has been replaced by the group system.
Players cannot be transferred between worlds yet.

The hub now supports plugins that can execute functions on start (with the @start
attribute) and register events like it is done in the node.
Hub's plugins must specify `target = "hub"` in their `plugin.toml` or add both
node-main and hub-main in case the plugin is created for both node and hub.

Some features has been removed and replaced by plugins, included in the ci-built
releases:
- [web-view](https://github.com/selery-plugins/web-view)
- [web-admin](https://github.com/selery-plugins/web-admin) (not finished)
- [rcon](https://github.com/selery-plugins/rcon) (not finished)
- [commands](https://github.com/selery-plugins/vanilla) (this plugin will also contain more vanilla-like features)

Plugins' language files are now located in the assets/lang folder in the plugin's
directory instead of in the lang folder.

The `--about` command now prints pretty-printed JSON by default (use `--min`
to print minified JSON) and has informations about the loaded plugins, git
repo and commit hash (if git is used) and the operative system in use.

New libraries for formatting and logging are now in use.

Deployment has been added for linux x86 and for the portable version
of Selery on Windows x86.

### 0.1.1

Added more command-line options and improved the project's README file.

### 0.1.0

Initial release.
