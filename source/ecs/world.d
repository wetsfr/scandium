module ecs.world;
import ecs.ecs;
import core.asset;
import core.log;
import core.application;

import ecs.components.tag;
import ecs.components.transform;

import ecs.components.renderer.renderer;
import ecs.components.renderer.light_source;
import ecs.components.renderer.camera;
import ecs.environment;
import ecs.components.rigidbody;
import ecs.components.audio;
import ecs.components.ui;
import ecs.components.particles;
import ecs.components.animator;

import ecs.systems.renderer;
import ecs.systems.ui;
import ecs.systems.physics;
import ecs.systems.audio;
import ecs.systems.particles;
import ecs.systems.animation;

import script_engine;

import raylib;
import json;

public Color toColor(Vector3 col) {
    return Color(
        cast(ubyte)(col.x*255.0f),
        cast(ubyte)(col.y*255.0f),
        cast(ubyte)(col.z*255.0f),
        255
    );
}

public Vector3 toVectorColor(Color col) {
    return Vector3(
        col.r/255.0f,
        col.g/255.0f,
        col.b/255.0f
    );
}

private Vector2 vec2(ref const Json j) {
    return Vector2(j[0].get!float(), j[1].get!float());
}

private Vector3 vec3(ref const Json j) {
    return Vector3(j[0].get!float(), j[1].get!float(), j[2].get!float());
}

private Color rgb(ref const Json j) {
    return Color(j[0].get!ubyte(), j[1].get!ubyte(), j[2].get!ubyte(), 255);
}

final class World {
    private Registry reg;
    string[Entity] entityToName;
    Entity[string] nameToEntity;

    private Entity activeCamera = nullEntity;
    private Environment environment;

    TransformAPI transformAPI;
    RendererSystem renderer;
    PhysicsSystem physics;
    UI uiSystem;
    AudioSystem audio;
    EventBus events;
    ScriptSystem scripts;
    ParticleSystem particles;
    AnimationSystem animations;

    this() {
        reg = new Registry();
        events = new EventBus();
        scripts.initialize(this);
    }

    // entities
    Entity create(string name) {
        auto e = reg.create();
        reg.emplace!Tag(e, name);

        entityToName[e] = name;
        nameToEntity[name] = e;
        return e;
    }
    string entityName(Entity e) { return entityToName[e]; }
    void destroy(Entity e) {
        if (reg.valid(e)) {
            if (auto nameptr = e in entityToName) {
                entityToName.remove(e);
                nameToEntity.remove(*nameptr);
            }
            reg.destroy(e);
        }
    }
    Entity find(string name) {
        if (auto e = name in nameToEntity) return *e;
        return nullEntity;
    }

    // components
    ref T add(T, Args...)(Entity e, Args args) {
        return reg.emplace!T(e, args); }
    void remove(T)(Entity e) {
        reg.remove!T(e); }
    ref T get(T)(Entity e) {
        return reg.get!T(e);    }
    bool has(T)(Entity e) {
        return reg.has!T(e); }

    // ecs stuff
    auto view(Types...)() {
        return reg.view!Types(); }
    auto registry() { return reg; }
    // TODO: events...
    
    // camera
    void setActiveCamera(Entity e) nothrow { activeCamera = e; }
    Entity getActiveCamera() nothrow { return activeCamera; }

    // world
    void initialize(ref Environment env) {
        transformAPI = new TransformAPI(reg);
                
        renderer = new RendererSystem();
        uiSystem = new UI();
        physics = new PhysicsSystem();
        audio = new AudioSystem();
        particles = new ParticleSystem();
        animations = new AnimationSystem();
        environment = env;
        renderer.initialize(this, environment);
        uiSystem.initialize(this);
        physics.initialize(this, Application.get.settings.physicsStep, Application.get.settings.maxSubSteps,
            Application.get.settings.gravity);
        audio.initialize(this);
        particles.initialize(this);
        animations.initialize(this);

        reg.onUpdate!Transform3D().connect((Registry r, Entity ent) {
            r.get!Transform3D(ent).dirty = true;
        });

        reg.onConstruct!MeshRenderer().connect(&renderer.onMeshRenderer);
        reg.onConstruct!LightSource().connect(&renderer.onLightSource);
        reg.onConstruct!Rigidbody3D().connect((Registry r, Entity e) {
            physics.onRigidbody(e);
        });
        reg.onConstruct!Animator().connect(&animations.onAnimator);
        reg.onDestroy!LightSource().connect(&renderer.onLightDestroy);
        reg.onDestroy!Rigidbody3D().connect((Registry r, Entity e) {
            physics.onRigidDestroy(e);
        });
        reg.onDestroy!Animator().connect(&animations.onAnimatorDestroy);
    }
    void update(float dt) {
        renderer.update();
        uiSystem.update();
        physics.update(dt);
        particles.update(dt);
        audio.update();
        animations.update(dt);
        scripts.update(dt);
    }
    void draw() {
        renderer.draw();
        uiSystem.draw();
    }
    ~this() { scripts.shutdown(); }

    void loadJson(string path) {
        auto data = Json.parseFile(path, true);

        foreach (ref item; data["assets"]) {
            const a = item;
            string name = a["name"].get!string();
            string file = a["path"].get!string();
            switch (a["type"].get!string()) {
                case "texture": Asset.get.loadTexture(name, file); break;
                case "sound": Asset.get.loadSound(name, file); break;
                case "model": Asset.get.loadModel(name, file); break;
                case "font": Asset.get.loadFont(name, file); break;
                default: Log.get.log(LogType.warning, "unknown asset type for \"" ~ name ~ "\""); break;
            }
        }

        environment.fromJsonScene(path);
        renderer.initialize(this, environment);

        foreach (name, ref item; data["objects"].items) {
            const o = item;
            if (!o.contains("transform")) {
                Log.get.log(LogType.warning, "skipping entity \"" ~ name ~ "\" because it has no transform");
                continue;
            }
            auto entity = create(name);
            add!Transform3D(entity, vec3(o["transform"]["position"]), vec3(o["transform"]["rotation"]), vec3(o["transform"]["scale"]));

            if (o.contains("mesh-renderer")) {
                const c = o["mesh-renderer"];
                MeshRenderer mr;
                mr.model = Asset.get.getModel(c["model"].get!string());
                mr.tiling = vec2(c["tiling"]);
                add!MeshRenderer(entity, mr);
            }

            if (o.contains("light-source")) {
                const c = o["light-source"];
                LightSource ls;
                ls.color = toVectorColor(rgb(c["color"]));
                ls.radius = c["radius"].get!float();
                ls.enabled = c["enabled"].get!bool();
                add!LightSource(entity, ls);
            }

            if (o.contains("camera")) {
                const c = o["camera"];
                WorldCamera cam;
                cam.FOV = c["fov"].get!float();
                add!WorldCamera(entity, cam);
                if (c["active"].get!bool()) setActiveCamera(entity);
            }

            if (o.contains("audio-source")) {
                const c = o["audio-source"];
                AudioSource as;
                as.sound = Asset.get.getSound(c["sound"].get!string());
                as.minDistance = c["min-distance"].get!float();
                as.maxDistance = c["max-distance"].get!float();
                as.volume = c["volume"].get!float();
                as.pitch = c["pitch"].get!float();
                as.looped = c["looped"].get!bool();
                as.enablePan = c["enable-pan"].get!bool();
                add!AudioSource(entity, as);
            }

            if (o.contains("rigidbody")) {
                const c = o["rigidbody"];
                Collider col;
                col.type = c["collider"]["type"].get!string() == "sphere" ? ColliderType.Sphere : ColliderType.Box;
                col.size = vec3(c["collider"]["size"]);
                col.isTrigger = c["collider"]["trigger"].get!bool();
                add!Collider(entity, col);

                Rigidbody3D rb;
                rb.mass = c["mass"].get!float();
                rb.friction = c["friction"].get!float();
                rb.restitution = c["restitution"].get!float();
                rb.isKinematic = c["kinematic"].get!bool();
                add!Rigidbody3D(entity, rb);
            }

            if (o.contains("text")) {
                const c = o["text"];
                UIText text;
                text.text = c["text"].get!string();
                text.font = Asset.get.getFont(c["font"].get!string());
                text.position = vec2(c["position"]);
                text.color = Color(c["color"][0].get!ubyte(), c["color"][1].get!ubyte(), c["color"][2].get!ubyte(), c["color"][3].get!ubyte());
                text.size = c["size"].get!float();
                text.layer = c["layer"].get!int();
                text.active = c["active"].get!bool();
                add!UIText(entity, text);
            }

            if (o.contains("primitive")) {
                const c = o["primitive"];
                UIPrimitive p;
                p.type = c["type"].get!string() == "circle" ? PrimitiveType.circle : PrimitiveType.rect;
                p.size = vec2(c["size"]);
                p.position = vec2(c["position"]);
                p.rotation = c["rotation"].get!float();
                p.color = rgb(c["color"]);
                if (c.contains("texture")) p.texture = Asset.get.getTexture(c["texture"].get!string());
                p.layer = c["layer"].get!int();
                p.active = c["active"].get!bool();
                add!UIPrimitive(entity, p);
            }

            if (o.contains("particles")) {
                const c = o["particles"];
                ParticleEmitter em;
                em.rate = c["rate"].get!float();
                em.lifetime = c["lifetime"].get!float();
                em.speed = c["speed"].get!float();
                em.spread = c["spread"].get!float();
                em.direction = vec3(c["direction"]);
                em.gravity = vec3(c["gravity"]);
                em.startSize = c["start-size"].get!float();
                em.endSize = c["end-size"].get!float();
                em.maxParticles = c["max-particles"].get!int();
                em.enabled = c["enabled"].get!bool();
                em.additive = c["additive"].get!bool();
                em.startColor = rgb(c["start-color"]);
                em.endColor = rgb(c["end-color"]);
                em.texture = Asset.get.getTexture(c["texture"].get!string());

                add!ParticleEmitter(entity, em);
            }

            if (o.contains("animator")) {
                const c = o["animator"];
                Animator an;
                an.modelName = o["mesh-renderer"]["model"].get!string();
                an.speed   = c.value("speed", 1.0f);
                an.looped  = c.value("loop", true);
                an.playing = c.value("playing", true);
                an.fps     = c.value("fps", 60.0f);
                an.current = c.value("clip", 0);
                add!Animator(entity, an);
                
                if (c.contains("animation"))
                    animations.play(entity, c["animation"].get!string(), an.looped, an.speed);
            }

            if (o.contains("scripts")) {
                foreach (ref s; o["scripts"]) {
                    scripts.compile(entity, s.get!string());
                }
            }
        }
    }
}