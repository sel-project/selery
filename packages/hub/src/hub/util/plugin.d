module hub.util.plugin;

public import com.plugin;

class PluginOf(T) : Plugin if(!isAbstractClass!T || is(T == struct)) {
	
	public this(string namespace, string name, string[] authors, string vers, bool api, string language) {
		this.n_namespace = namespace;
		this.n_name = name;
		this.n_authors = authors;
		this.n_version = vers;
		this.n_api = api;
		this.n_language = language;
		static if(!is(T : Object)) this.hasMain = true;
	}
	
	public override void load() {
		//TODO register events
	}
	
}
