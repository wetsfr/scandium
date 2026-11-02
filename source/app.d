import raylib;
import core.application;
import ecs.world;
import core.pak;
import std.stdio;

enum VERSION = "1.1.0";
enum MODE = AppMode.Developer;

void main(string[] args)
{
	if (args.length > 3 && args[1] == "--pack") {
		buildPak(args[2], args[3 .. $]);
		return ;
	}
	
	auto app = Application.get;
	writeln(MODE);
	app.initialize(MODE);
	writeln(app.appMode);

	app.run();
}