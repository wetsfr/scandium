import raylib;
import core.application;
import ecs.world;

void main()
{
	auto app = Application.get;
	app.initialize();

	app.run();
}