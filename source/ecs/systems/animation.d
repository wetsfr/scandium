module ecs.systems.animation;
import raylib;
import std.math : fmod;
import std.string : fromStringz, toStringz;

import ecs.ecs;
import ecs.world;
import ecs.components.animator;
import ecs.components.renderer.renderer;
import core.log;
import core.asset;

private int frames(ref const ModelAnimation a) { return a.keyframeCount; }
final class AnimationSystem {
    private World world;

    void initialize(World w) { world = w; }

    void onAnimator(Registry reg, Entity e) {
        auto ref an = world.get!Animator(e);
        if (!world.has!MeshRenderer(e)) {
            Log.get.log(LogType.error, "animator needs a mesh-renderer on the same entity");
            return;
        }

        auto path = an.modelName in Asset.get.modelPaths;
        if (path is null) {
            Log.get.log(LogType.error, "animator: unknown model \"" ~ an.modelName ~ "\"");
            return;
        }
        string file = *path;
        
        an.animCount = 0;
        an.anims = LoadModelAnimations(toStringz(file), &an.animCount);
        if (an.animCount == 0)
            Log.get.log(LogType.warning, "no animations in " ~ file);
        
        an.mdl = new Model;
        *an.mdl = LoadModel(toStringz(file));
        auto ref mr = world.get!MeshRenderer(e);
        mr.model = an.mdl;
        world.renderer.onMeshRenderer(reg, e);
    }

    void onAnimatorDestroy(Registry reg, Entity e) {
        auto ref an = world.get!Animator(e);
        if (world.has!MeshRenderer(e)) {
            auto ref mr = world.get!MeshRenderer(e);
            if (mr.model is an.mdl) mr.model = null;
        }
        if (an.anims) UnloadModelAnimations(an.anims, an.animCount);
        if (an.mdl) UnloadModel(*an.mdl);
        an.anims = null;
        an.mdl = null;
    }

    void update(float dt) {
        foreach (entity, _; world.view!Animator()) {
            auto ref an = world.get!Animator(entity);
            if (!an.playing || an.animCount == 0 || an.mdl is null) continue;

            auto anim = an.anims[an.current];
            int count = frames(anim);
            if (count <= 0) continue;

            an.time += dt * an.fps * an.speed;
            if (an.time >= count) {
                if (an.looped) an.time = fmod(an.time, cast(float) count);
                else { an.time = count - 1; an.playing = false; }
            } else if (an.time < 0) {
                if (an.looped) an.time = fmod(an.time, cast(float) count) + count;
                else { an.time = 0; an.playing = false; }
            }
            UpdateModelAnimation(*an.mdl, anim, an.time);
        }
    }

    bool play(Entity e, string name, bool loop = true, float speed = 1.0f) {
        if (!world.has!Animator(e)) return false;
        auto ref an = world.get!Animator(e);
        foreach (i; 0 .. an.animCount) {
            if (fromStringz(an.anims[i].name.ptr) == name) {
                an.current = i;
                an.time = 0;
                an.looped = loop;
                an.speed = speed;
                an.playing = true;
                return true;
            }
        }
        return false;
    }

    void pause(Entity e)  { if (world.has!Animator(e)) world.get!Animator(e).playing = false; }
    void resume(Entity e) { if (world.has!Animator(e)) world.get!Animator(e).playing = true; }

    void stop(Entity e) {
        if (!world.has!Animator(e)) return;
        auto ref an = world.get!Animator(e);
        an.playing = false;
        an.time = 0;
        if (an.animCount > 0 && an.mdl !is null)
            UpdateModelAnimation(*an.mdl, an.anims[an.current], 0);
    }

    void setSpeed(Entity e, float speed) {
        if (world.has!Animator(e)) world.get!Animator(e).speed = speed;
    }
}