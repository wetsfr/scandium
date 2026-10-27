module ecs.components.animator;
import raylib;

struct Animator {
    int animCount;
    int current = 0;
    float time = 0.0f;
    float speed = 1.0f;
    float fps = 60.0f;

    string modelName;
    ModelAnimation* anims;
    Model* mdl; // animator's own model

    bool looped;
    bool playing;
}