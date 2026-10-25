module ecs.components.renderer.renderer;
import raylib;

struct MeshRenderer {
    Model* model;
    Vector2 tiling = {1.0f, 1.0f};
    // (color tint)
}