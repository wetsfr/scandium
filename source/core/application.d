module core.application; 
import std.string;
import raylib;
import json;

import core.asset;
import core.log;
import core.input;
import core.game_time;
import core.config;
import core.pak;

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

/* core app */
enum AppMode { Developer = 0, Distribution = 1 }
enum VERSION = "1.0.0";
enum MODE = AppMode.Developer;
enum PAK_PATH = "game.pak";


// GLOBALVAR shadername
enum ShaderName = "default";
// GLOBALVAR skyboxsize
enum SkyboxSize = 500.0f;
// GLOBALVAR configpath
enum ConfigPath = "app.cfg";

struct AppSettings {
    // basic
    string windowTitle = "Application";
    int width = 800;
    int height = 600;
    bool debugLog = false;
    bool fullscreen = false;
    int max_fps = 60;

    // renderer
    int maxLights = 12;

    // physics
    float physicsStep = 1.0f / 60.0f;
    int maxSubSteps = 10;
    float gravity = 20.81f;
}

final class Application {
    AppSettings settings;
    AppMode appMode;

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

    void initialize(AppMode mode = AppMode.Developer) {
        this.settings = generateAppSettings(ConfigPath);
        this.asset = asset.get;
        this.log = log.get;
        this.input = input.get;
        this.time = time.get;
        this.appMode = mode;
        if (appMode == AppMode.Distribution) mountPak(PAK_PATH);

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
        if (settings.fullscreen) ToggleBorderlessWindowed();
        log.log(LogType.info, "app created!");
        asset.loadShaderFromMemory(ShaderName, import("vs.glsl"), import("fs.glsl"));

        auto entry = Json.parse(core.pak.readText("entry.json"), true);
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
