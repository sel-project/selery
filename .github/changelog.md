### 0.2.0

The parent/children model for worlds has been replaced by the group system.

The hub now supports plugins. There are no events yet but the @start attribute
works the same way it does on the node's plugins.
Hub's plugins must specify `target = "hub"` in their `plugin.toml`.

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
