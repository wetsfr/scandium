import raylib;
import core.application;
import ecs.world;
import core.pak;

void main(string[] args)
{
	if (args.length > 3 && args[1] == "--pack") {
		buildPak(args[2], args[3 .. $]);
		return ;
	}
	
	auto app = Application.get;
	app.initialize(AppMode.Distribution);

	app.run();
}