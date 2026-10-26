module ecs.components.particles;
import raylib;

struct Particle {
    Vector3 pos, vel;
    float life, maxLife;
}

struct ParticleEmitter {
    float rate = 30, lifetime = 1.5f;
    float speed = 3.0f, spread = 0.6f;
    float startSize = 0.2f, endSize = 0.0f;
    int maxParticles = 256;

    Vector3 direction = Vector3(0, 1, 0);
    Vector3 gravity = Vector3(0, -2, 0);
    Color startColor = Color(255, 255, 255, 255);
    Color endColor = Color(255, 255, 255, 0);
    Texture* texture = null;
    bool enabled = true, additive = true;
    
    Particle[] particles;
    float accumulator = 0;
}