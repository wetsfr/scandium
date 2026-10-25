module ecs.components.renderer.light_source;
import raylib;

struct LightSource {
    Vector3 color = {0.0f, 0.0f, 0.0f};
    float radius = 0.0f;
    bool enabled = false;
}