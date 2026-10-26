module ecs.systems.particles;
import raylib;

import ecs.world;
import ecs.components.transform;
import ecs.components.particles;

private float rnd() { return GetRandomValue(-1000, 1000) / 1000.0f; }
private float lerpf(float a, float b, float t) { return a + (b - a) * t; }
private ubyte lerpb(ubyte a, ubyte b, float t) { return cast(ubyte) lerpf(a, b, t); }

final class ParticleSystem {
    private World world;

    void initialize(World w) { this.world = w; }

    void update(float dt) {
        foreach (entity, _; world.view!ParticleEmitter()) {
            auto ref em = world.get!ParticleEmitter(entity);
            auto ref tr = world.get!Transform3D(entity);
            
            for (size_t i = 0; i < em.particles.length;) {
                auto p = &em.particles[i];
                p.life -= dt;
                if (p.life <= 0) {
                    em.particles[i] = em.particles[$ - 1];
                    em.particles.length -= 1;
                    continue;
                }
                p.vel = Vector3Add(p.vel, Vector3Scale(em.gravity, dt));
                p.pos = Vector3Add(p.pos, Vector3Scale(p.vel, dt));
                i++;
            }

            if (!em.enabled) continue;

            em.accumulator += em.rate * dt;
            while (em.accumulator >= 1.0f) {
                em.accumulator -= 1.0f;
                if (em.particles.length >= em.maxParticles) continue;

                Particle p;
                p.pos = tr.position;
                p.vel = Vector3Add(
                    Vector3Scale(em.direction, em.speed),
                    Vector3Scale(Vector3(rnd(), rnd(), rnd()), em.spread)
                );
                p.life = p.maxLife = em.lifetime;
                em.particles ~= p;
            }
        }
    }
    
    void draw(Camera3D camera) {
        Vector3 fwd   = Vector3Normalize(Vector3Subtract(camera.target, camera.position));
        Vector3 right = Vector3Normalize(Vector3CrossProduct(fwd, camera.up));
        Vector3 up    = Vector3CrossProduct(right, fwd);

        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        foreach (entity, _; world.view!ParticleEmitter()) {
            auto ref em = world.get!ParticleEmitter(entity);
            if (em.particles.length == 0) continue;

            BeginBlendMode(em.additive ? BlendMode.BLEND_ADDITIVE : BlendMode.BLEND_ALPHA);
            foreach (ref p; em.particles) {
                float t = 1.0f - p.life / p.maxLife;
                float s = lerpf(em.startSize, em.endSize, t);
                if (s <= 0) continue;
                Color c = Color(
                    lerpb(em.startColor.r, em.endColor.r, t),
                    lerpb(em.startColor.g, em.endColor.g, t),
                    lerpb(em.startColor.b, em.endColor.b, t),
                    lerpb(em.startColor.a, em.endColor.a, t)
                );
                if (em.texture !is null) {
                    DrawBillboard(camera, *em.texture, p.pos, s, c);
                } else {
                    float h = s * 0.5f;
                    Vector3 r = Vector3Scale(right, h);
                    Vector3 u = Vector3Scale(up, h);

                    Vector3 a = Vector3Subtract(Vector3Subtract(p.pos, r), u);
                    Vector3 b = Vector3Subtract(Vector3Add(p.pos, r), u);
                    Vector3 d = Vector3Add(Vector3Add(p.pos, r), u);
                    Vector3 e = Vector3Add(Vector3Subtract(p.pos, r), u);

                    rlBegin(RL_QUADS);
                        rlColor4ub(c.r, c.g, c.b, c.a);
                        rlVertex3f(a.x, a.y, a.z);
                        rlVertex3f(b.x, b.y, b.z);
                        rlVertex3f(d.x, d.y, d.z);
                        rlVertex3f(e.x, e.y, e.z);
                    rlEnd();
                }
            }
            EndBlendMode();
        }
        rlEnableBackfaceCulling();
        rlEnableDepthMask();
    }
}