module core.input;
import raylib;

struct Axis {
    int positive, negative;
}

final class Input {
    private int[string] actions;
    private Axis[string] axes;

    private this() {}
    private static shared Input _instance;
    static Input get() {
        if (_instance is null) {
            synchronized {
                if (_instance is null) _instance = cast(shared) new Input(); }
        }
        return cast(Input) _instance;
    }

    public void bindAction(string name, int key) nothrow {
        actions[name] = key; }
    public void bindAxis(string name, Axis axis) nothrow {
        axes[name] = axis; }

    public bool getAction(string name, bool pressed = false) nothrow {
        if (auto key = name in actions) return (pressed) ? IsKeyPressed(*key) : IsKeyDown(*key);
        else return false;
    }
    public float getAxis(string name) nothrow {
        float val = 0.0f;
        Axis* axis = name in axes;

        if (!axis) return 0.0f;
        if (IsKeyDown(axis.positive)) val += 1.0f;
        else if (IsKeyDown(axis.negative)) val -= 1.0f;
        return val;
    }
}