module core.game_time;
import raylib;

final class Time {
    private this() {}
    private static shared Time _instance;
    static Time get() {
        if (_instance is null) {
            synchronized {
                if (_instance is null) _instance = cast(shared) new Time(); }
        }
        return cast(Time) _instance;
    }

    public float delta() nothrow {
        return GetFrameTime(); }
    public int fps() nothrow {
        return GetFPS(); }
}