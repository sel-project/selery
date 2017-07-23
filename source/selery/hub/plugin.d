module selery.hub.plugin;

public import selery.plugin;
import selery.server : Server;

interface HubPlugin {}

class PluginOf(T) : Plugin if(is(T == Object) || is(T : HubPlugin)) {
	
	public this(string name, string[] authors, string vers, bool api, string languages, string textures) {
		this.n_name = name;
		this.n_authors = authors;
		this.n_version = vers;
		this.n_api = api;
		this.n_languages = languages;
		this.n_textures = textures;
		static if(!is(T : Object)) this.hasMain = true;
	}
	
	public override void load(shared Server server) {
		//TODO register events
	}
	
}
