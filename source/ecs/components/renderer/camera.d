module ecs.components.renderer.camera;
import raylib;

struct WorldCamera {
    float FOV;
    Vector3 right = {1.0f, .0f, .0f};
}