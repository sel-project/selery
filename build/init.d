/+ dub.json:
{
	"name": "init"
}
+/
module init;

import std.process;

void main(string[] args) {

	spawnShell("cd ../node && dub init.d");

}
