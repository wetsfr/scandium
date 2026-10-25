module ecs.components.audio;
import raylib;

struct AudioSource {
    Sound* sound;
    float minDistance = 10.0f;
    float maxDistance = 50.0f;
    float volume = 1.0f;
    float pitch = 1.0f;
    bool looped = false;

    bool playing = false;
    bool paused = false;
    bool enablePan = false;

    void playOneShot() nothrow { PlaySound(*sound); }
    void stop() nothrow { StopSound(*sound); }
    void togglePause() nothrow { paused = !paused; if (paused) PauseSound(*sound); else ResumeSound(*sound); }
} 