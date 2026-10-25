module core.application;
import std.string;
import raylib;
import json;

import core.asset;
import core.log;
import core.input;
import core.game_time;
import core.config;

import ecs.world;
import ecs.environment;
import ecs.components.transform;
import ecs.components.renderer.camera;
import ecs.components.ui;
import ecs.components.audio;
import ecs.components.renderer.renderer;
import ecs.components.renderer.light_source;
import ecs.components.rigidbody;

import scene.scene;

import std.stdio;

// GLOBALVAR shadername
enum ShaderName = "default";
// GLOBALVAR skyboxsize
enum SkyboxSize = 500.0f;
// GLOBALVAR configpath
enum ConfigPath = "cfg.ini";

struct AppSettings {
    // basic
    string windowTitle = "Application";
    int width = 800;
    int height = 600;
    bool debugLog = false;
    int max_fps = 60;

    // renderer
    int maxLights = 12;
}

final class Application {
    AppSettings settings;

    private Asset asset;
    private Log log;
    private Input input;
    private Time time;

    // temporary
    //private World world;

    private SceneManager sceneManager;

    private this() {}
    private static shared Application _instance;
    static Application get() {
        if (_instance is null) {
            synchronized {
                if (_instance is null) _instance = cast(shared) new Application(); }
        }
        return cast(Application) _instance;
    }

    void initialize() {
        this.settings = generateAppSettings(ConfigPath);
        this.asset = asset.get;
        this.log = log.get;
        this.input = input.get;
        this.time = time.get;

        this.log.init(settings.debugLog, "latest.log");
        this.sceneManager = new SceneManager();
    }

    int run() {
        validateRaylibBinding();
        SetTraceLogLevel(TraceLogLevel.LOG_ERROR);
	    InitWindow(settings.width, 
            settings.height, toStringz(settings.windowTitle));
        SetExitKey(KeyboardKey.KEY_NULL);
        InitAudioDevice();
        this.asset.loadDefaults();
        if (settings.max_fps == 0)
            SetTargetFPS(GetMonitorRefreshRate(GetCurrentMonitor())); else SetTargetFPS(settings.max_fps);
        log.log(LogType.info, "app created!");
        asset.loadShader(ShaderName, "asset/shader/vs.glsl", "asset/shader/fs.glsl");

        auto entry = Json.parseFile("entry.json");
        foreach (ref scene; entry["scenes"]) {
            sceneManager.addScene(scene.get!string());
        }
        if (!entry.contains("main-scene")) return 1;
        sceneManager.loadScene(entry["main-scene"].get!string());


        while (!WindowShouldClose()) {
            sceneManager.update(time.delta());

            BeginDrawing();
                ClearBackground(Colors.WHITE);
                sceneManager.draw();
            EndDrawing();
	    }
            
        return 0;
    }

    ~this() {
        asset.unload();
        sceneManager.getCurrent.world.physics.shutdown();
        CloseAudioDevice();
        CloseWindow();
    }
}
