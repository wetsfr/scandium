module core.config;
import core.application;
import core.ini;

AppSettings generateAppSettings(string path) {
    Ini ini = parseIniFile(path);
    return AppSettings(
        ini.get("window", "title", "window"),
        ini.getInt("window", "width", 800),
        ini.getInt("window", "height", 600),
        ini.getBool("window", "debug_log", false),
        ini.getBool("window", "fullscreen", false),
        ini.getInt("window", "max_fps", 60),

        ini.getInt("render", "max_lights", 16),

        ini.getFloat("physics", "step", 1.0f/60.0f),
        ini.getInt("physics", "max_substeps", 10),
        ini.getFloat("physics", "gravity", 20.81f)   
    );
}