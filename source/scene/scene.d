module scene.scene;
import ecs.world;
import ecs.environment;
import json;
import core.log;
static import core.pak;

final class Scene {
    World world;
    string name;

    this(string path) {
        world = new World();
        Environment env = Environment();
        this.name = Json.parse(core.pak.readText(path), true)["data"]["name"].get!string();
        world.initialize(env);
        world.loadJson(path);
    }

    void update(float dt) { world.update(dt); }
    void draw() { world.draw(); }

    void onExit() {}
}

final class SceneManager {
    private Scene current;
    private Scene[] scenes;

    void addScene(string path) {
        scenes ~= new Scene(path);
    }

    void loadScene(string name) {
        Scene newScene;
        foreach (ref scene; scenes) {
            if (scene.name == name) { newScene = scene; break; }
        }
        if (!newScene) { Log.get.log(LogType.error, "cannot find scene \"" ~ name ~ "\""); return; }

        if (current) current.onExit();
        current = newScene;
    }

    void update(float dt) {
        if (current) current.update(dt);
    }

    void draw() {
        if (current) current.draw();
    }

    Scene getCurrent() { return current; }
}