module ecs.components.particles;
import raylib;

struct Particle {
    Vector3 pos, vel;
    float life, maxLife;
}

struct ParticleEmitter {
    float rate, lifetime;
    float speed, spread;
    float startSize, endSize;
    int maxParticles;

    Vector3 direction, gravity;
    Color startColor, endColor;
    Texture* texture;
    bool enabled, additive;

    Particle[] particles;
    float accumulator = 0;
}