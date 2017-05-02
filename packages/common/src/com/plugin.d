module com.plugin;

/**
 * Informations about a plugin and registration-related
 * utilities.
 */
class Plugin {
	
	protected string n_namespace;
	protected string n_name;
	protected string[] n_authors;
	protected string n_version;
	protected bool n_api;
	public bool hasMain;
	protected string n_language;
	
	public void delegate()[] onstart, onreload, onstop;
	
	/**
	 * Gets the plugin's namespace that corresponds to the plugin's
	 * source code in plugins/<namespace> and the plugin's resources
	 * in resources/<namespace>.
	 */
	public pure nothrow @property @safe @nogc string namespace() {
		return this.n_namespace;
	}
	
	/**
	 * Gets the plugin's name as indicated in the plugin's
	 * package.json file.
	 */
	public pure nothrow @property @safe @nogc string name() {
		return this.n_name;
	}
	
	/**
	 * Gets the plugin's authors as indicated in the plugin's
	 * package.json file.
	 */
	public pure nothrow @property @safe @nogc string[] authors() {
		return this.n_authors;
	}
	
	/**
	 * Gets the plugin's version as indicated in the plugin's
	 * package.json file.
	 * This should be in major.minor[.revision] [alpha|beta] format.
	 */
	public pure nothrow @property @safe @nogc string vers() {
		return this.n_version;
	}
	
	/**
	 * Indicates whether or not the plugin has APIs.
	 * The plugin's APIs are always in the api.d file in
	 * the plugin's directory.
	 * Example:
	 * ---
	 * static if(__traits(compile, { import example.api; })) {
	 *    assert(server.plugins.filter!(a => a.namespace == "example")[0].api);
	 * }
	 * ---
	 */
	public pure nothrow @property @safe @nogc bool api() {
		return this.n_api;
	}

	/**
	 * Gets the location of the plugin's language files.
	 * Returns: null if the plugin has no language files, a full path otherwise
	 */
	public pure nothrow @property @safe @nogc string language() {
		return this.n_language;
	}
	
	public abstract void load();
	
}

enum start;
enum reload;
enum stop;

// attributes for events
enum event;
enum global;
enum inherit;
enum cancel;
