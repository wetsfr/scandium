module script_engine;

import libtcc;
import raylib;

import core.stdc.math : sqrtf, floorf, ceilf, roundf, sinf, cosf, tanf,
    atan2f, powf, expf, logf, fmodf, hypotf, fabsf;
import core.stdc.string : memset, memcpy;

import std.array : join, replace;
import std.regex : regex, replaceAll;
import std.datetime.systime : Clock, unixTimeToStdTime;
import std.file : exists, isDir, read, readText, write, append, remove, mkdirRecurse,
    rmdirRecurse, getSize, dirEntries, SpanMode;
import std.format : format;
import std.path : baseName;
import std.random : Mt19937, uniform, unpredictableSeed;
import std.string : toStringz, fromStringz;

import ecs.ecs;
import ecs.world;
import ecs.components.transform;
import ecs.components.renderer.renderer;
import ecs.components.renderer.light_source;
import ecs.components.audio;
import ecs.components.rigidbody;
import ecs.components.ui;
import core.asset;
import core.input;
import core.log;

immutable apiHeader = import("script_api.h");

enum cPrelude = "typedef _Bool bool;\n"
    ~ "#define true 1\n"
    ~ "#define false 0\n"
    ~ "#define NULL ((void*)0)\n";

alias EntityFn = extern(C) void function(uint entity);

struct Script {
    TCCState* state;
    EntityFn initFn;
    EntityFn updateFn;
    EntityFn destroyFn;
}

struct MainScript {
    TCCState* state;
    extern(C) void function() initFn;
    extern(C) void function(float dt) updateFn;
    extern(C) void function() closeFn;
}

enum ComponentType : int {
    transform,
    renderer,
    light,
    audio,
    rigidbody,
    collider,
    primitive,
    text,
}

struct ScView(C, string[] names) {
    static foreach (n; names)
        mixin("typeof(C." ~ n ~ ")* " ~ n ~ ";");

    static ScView of(ref C c) {
        ScView r;
        static foreach (n; names)
            mixin("r." ~ n ~ " = &c." ~ n ~ ";");
        return r;
    }
}

alias scTransform = ScView!(Transform3D, ["position", "rotation", "scale"]);
alias scAudioSource = ScView!(AudioSource, ["sound", "minDistance", "maxDistance", "volume",
    "pitch", "looped", "playing", "paused", "enablePan"]);
alias scMeshRenderer = ScView!(MeshRenderer, ["model", "tiling"]);
alias scLightSource = ScView!(LightSource, ["color", "radius", "enabled"]);
alias scRigidbody = ScView!(Rigidbody3D, ["mass", "friction", "restitution", "isKinematic"]);
alias scUIPrimitive = ScView!(UIPrimitive, ["type", "size", "position", "rotation", "color",
    "texture", "layer", "active"]);

struct scMeshCollider {
    ColliderType type;
    Vector3* size;
    bool* isTrigger;

    static scMeshCollider of(ref Collider c) {
        return scMeshCollider(c.type, &c.size, &c.isTrigger);
    }
}

__gshared char* textPtr;
struct scUIText {
    char** text;
    Font** font;
    Vector2* position;
    Color* color;
    float* size;
    int* layer;
    bool* active;

    static scUIText of(ref UIText c) {
        textPtr = cast(char*) c.text.toStringz;
        return scUIText(&textPtr, &c.font, &c.position, &c.color, &c.size, &c.layer, &c.active);
    }
}

struct Timer {
    Entity entity;
    EntityFn fn;
    float remaining;
}
__gshared Timer[] timers;

__gshared World gWorld;
__gshared bool cursorLocked = false;
__gshared Mt19937 scRng;

__gshared scTransform trScratch;
__gshared scAudioSource auScratch;
__gshared scMeshRenderer rnScratch;
__gshared scLightSource lsScratch;
__gshared scRigidbody rbScratch;
__gshared scMeshCollider clScratch;
__gshared scUIPrimitive prScratch;
__gshared scUIText txScratch;
__gshared string nameStr;

__gshared char[] readBuf;
__gshared char[] listBuf;

string str(const(char)* p) { return fromStringz(p).idup; }
string tmp(const(char)* p) { return cast(string) fromStringz(p); }

void* putView(V, C)(ref V scratch, ref C c) {
    scratch = V.of(c);
    return &scratch;
}

void* getView(C, V)(Entity e, ref V scratch) {
    if (!gWorld.has!C(e)) return null;
    return putView(scratch, gWorld.get!C(e));
}

void* addView(C, V)(Entity e, ref V scratch) {
    if (!gWorld.has!C(e)) gWorld.add!C(e);
    return getView!C(e, scratch);
}

void* transformView(Entity e) {
    auto v = getView!Transform3D(e, trScratch);
    if (v) gWorld.get!Transform3D(e).dirty = true;
    return v;
}

extern(C):

// assets
void* scNewTexture(const(char)* name, const(char)* path) {
    auto n = str(name);
    Asset.get.loadTexture(n, str(path));
    return cast(void*) Asset.get.getTexture(n);
}
void* scLoadTexture(const(char)* name) {
    return cast(void*) Asset.get.getTexture(tmp(name));
}

// input
void scBindAction(const(char)* name, int key) {
    Input.get.bindAction(str(name), key);
}
void scBindAxis(const(char)* name, int positive, int negative) {
    Input.get.bindAxis(str(name), Axis(positive, negative));
}
bool scGetAction(const(char)* name, bool pressed) {
    return Input.get.getAction(tmp(name), pressed);
}
float scGetAxis(const(char)* name) {
    return Input.get.getAxis(tmp(name));
}

// generic
void scLogMessage(int type, const(char)* msg, bool logToFile) {
    try {
        auto l = Log.get;
        auto old = l.logToFile;
        scope(exit) l.logToFile = old;
        l.logToFile = logToFile;
        l.log(cast(LogType) type, str(msg));
    } catch (Exception) {}
}
float scDeltaTime() { return GetFrameTime(); }
int scGetFPS() { return GetFPS(); }
Vector2 scMouseDelta() { return GetMouseDelta(); }
void scToggleCursor() {
    cursorLocked = !cursorLocked;

    if (!cursorLocked) EnableCursor();
    else DisableCursor();
}
bool scMousePressed(int button) { return IsMouseButtonPressed(button); }
const(char)* scEntityName(Entity e) {
    if (!gWorld.registry.valid(e) || e !in gWorld.entityToName) return null;
    nameStr = gWorld.entityName(e) ~ "\0";
    return nameStr.ptr;
}

// entities
Entity scCreateEntity(const(char)* name) {
    return gWorld.create(str(name));
}
Entity scFindEntity(const(char)* name) {
    return gWorld.find(tmp(name));
}
void scDestroyEntity(Entity e) {
    gWorld.destroy(e);
}
bool scValid(Entity e) {
    return gWorld.registry.valid(e);
}

Entity scGetCurrentCamera() { return gWorld.getActiveCamera(); }
void scSetCurrentCamera(Entity cam) { gWorld.setActiveCamera(cam); }

// components
void* scAddComponent(Entity e, ComponentType type) {
    switch (type) {
        case ComponentType.transform:
            if (!gWorld.has!Transform3D(e)) gWorld.add!Transform3D(e);
            return transformView(e);
        case ComponentType.renderer:  return addView!MeshRenderer(e, rnScratch);
        case ComponentType.light:     return addView!LightSource(e, lsScratch);
        case ComponentType.audio:     return addView!AudioSource(e, auScratch);
        case ComponentType.rigidbody:
            if (!gWorld.has!Collider(e)) gWorld.add!Collider(e);
            return addView!Rigidbody3D(e, rbScratch);
        case ComponentType.collider:  return addView!Collider(e, clScratch);
        case ComponentType.primitive: return addView!UIPrimitive(e, prScratch);
        case ComponentType.text:      return addView!UIText(e, txScratch);
        default: return null;
    }
}
void* scGetComponent(Entity e, ComponentType type) {
    switch (type) {
        case ComponentType.transform: return transformView(e);
        case ComponentType.renderer:  return getView!MeshRenderer(e, rnScratch);
        case ComponentType.light:     return getView!LightSource(e, lsScratch);
        case ComponentType.audio:     return getView!AudioSource(e, auScratch);
        case ComponentType.rigidbody: return getView!Rigidbody3D(e, rbScratch);
        case ComponentType.collider:  return getView!Collider(e, clScratch);
        case ComponentType.primitive: return getView!UIPrimitive(e, prScratch);
        case ComponentType.text:      return getView!UIText(e, txScratch);
        default: return null;
    }
}
void scRemoveComponent(Entity e, ComponentType type) {
    switch (type) {
        case ComponentType.transform: gWorld.remove!Transform3D(e);  break;
        case ComponentType.renderer:  gWorld.remove!MeshRenderer(e); break;
        case ComponentType.light:     gWorld.remove!LightSource(e);  break;
        case ComponentType.audio:     gWorld.remove!AudioSource(e);  break;
        case ComponentType.rigidbody: gWorld.remove!Rigidbody3D(e);  break;
        case ComponentType.collider:  gWorld.remove!Collider(e);     break;
        case ComponentType.primitive: gWorld.remove!UIPrimitive(e);  break;
        case ComponentType.text:      gWorld.remove!UIText(e);       break;
        default: break;
    }
}

// invoke
void scInvoke(void* fn, Entity e, float seconds) {
    if (fn is null) return;
    timers ~= Timer(e, cast(EntityFn) fn, seconds);
}
void scCancelInvoke(void* fn, Entity e) {
    for (size_t i = 0; i < timers.length; ) {
        if (timers[i].fn is cast(EntityFn) fn && timers[i].entity == e) {
            timers[i] = timers[$ - 1];
            timers.length -= 1;
        } else i++;
    }
}

// transforms
void scTransformMove(Entity e, Vector3 pos) { gWorld.transformAPI.translate(e, pos); }
void scTransformRotate(Entity e, Vector3 rot) { gWorld.transformAPI.rotate(e, rot); }
void scTransformScale(Entity e, Vector3 scale) { gWorld.transformAPI.scale(e, scale); }
void scTeleport(Entity e) { gWorld.physics.teleport(e); }

// audio
void scPlayOneShot(Entity e) {
    if (gWorld.has!AudioSource(e)) gWorld.get!AudioSource(e).playOneShot();
}
void scStopAudio(Entity e) {
    if (gWorld.has!AudioSource(e)) gWorld.get!AudioSource(e).stop();
}

// raycast
RaycastHit scRaycast(Vector3 from, Vector3 to) { return gWorld.physics.raycast(from, to); }

// scenes
void scLoadScene(const(char)* name) {
    try gWorld.loadJson(str(name));
    catch (Exception) {}
}

// math
float scClamp(float value, float min, float max) {
    return value < min ? min : (value > max ? max : value);
}
float scLerp(float a, float b, float t) { return a + (b - a) * t; }
float scSmoothstep(float edge0, float edge1, float x) {
    float t = (x - edge0) / (edge1 - edge0);
    t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
    return t * t * (3.0f - 2.0f * t);
}
float scRadians(float degrees) { return degrees * DEG2RAD; }
float scDegrees(float radians) { return radians * RAD2DEG; }
float scMinf(float a, float b) { return a < b ? a : b; }
float scMaxf(float a, float b) { return a > b ? a : b; }
float scFabs(float x) { return x < 0.0f ? -x : x; }
float scSignf(float x) { return x > 0.0f ? 1.0f : (x < 0.0f ? -1.0f : 0.0f); }

void scSetSeed(uint seed) { scRng.seed(seed); }
float scRandf() { return uniform(0.0f, 1.0f, scRng); }
int scRandi(int min, int max) { return uniform!"[]"(min, max, scRng); }
float scRandRange(float min, float max) { return uniform(min, max, scRng); }

// vectors
Vector2 scVec2Add(Vector2 a, Vector2 b) { return Vector2Add(a, b); }
Vector2 scVec2Sub(Vector2 a, Vector2 b) { return Vector2Subtract(a, b); }
Vector2 scVec2Scale(Vector2 v, float s) { return Vector2Scale(v, s); }
float scVec2Dot(Vector2 a, Vector2 b) { return Vector2DotProduct(a, b); }
float scVec2Length(Vector2 v) { return Vector2Length(v); }
Vector2 scVec2Normalize(Vector2 v) { return Vector2Normalize(v); }
float scVec2Distance(Vector2 a, Vector2 b) { return Vector2Distance(a, b); }
Vector2 scVec2Lerp(Vector2 a, Vector2 b, float t) { return Vector2Lerp(a, b, t); }

Vector3 scVec3FromXYZ(float x, float y, float z) { return Vector3(x, y, z); }
Vector3 scVec3Add(Vector3 a, Vector3 b) { return Vector3Add(a, b); }
Vector3 scVec3Sub(Vector3 a, Vector3 b) { return Vector3Subtract(a, b); }
Vector3 scVec3Scale(Vector3 v, float s) { return Vector3Scale(v, s); }
Vector3 scVec3Neg(Vector3 v) { return Vector3Negate(v); }
float scVec3Dot(Vector3 a, Vector3 b) { return Vector3DotProduct(a, b); }
Vector3 scVec3Cross(Vector3 a, Vector3 b) { return Vector3CrossProduct(a, b); }
float scVec3Length(Vector3 v) { return Vector3Length(v); }
Vector3 scVec3Normalize(Vector3 v) { return Vector3Normalize(v); }
float scVec3Distance(Vector3 a, Vector3 b) { return Vector3Distance(a, b); }
Vector3 scVec3Lerp(Vector3 a, Vector3 b, float t) { return Vector3Lerp(a, b, t); }

// filesystem
bool scFileExists(const(char)* path) {
    try return exists(tmp(path));
    catch (Exception) return false;
}
bool scDirExists(const(char)* path) {
    try return exists(tmp(path)) && isDir(tmp(path));
    catch (Exception) return false;
}
const(char)* scReadFile(const(char)* path) {
    try {
        readBuf = cast(char[]) read(tmp(path));
        readBuf ~= '\0';
        return readBuf.ptr;
    } catch (Exception) return null;
}
bool scWriteFile(const(char)* path, const(char)* contents) {
    try {
        write(tmp(path), fromStringz(contents));
        return true;
    } catch (Exception) return false;
}
bool scAppendFile(const(char)* path, const(char)* contents) {
    try {
        append(tmp(path), fromStringz(contents));
        return true;
    } catch (Exception) return false;
}
bool scDeleteFile(const(char)* path) {
    try {
        remove(tmp(path));
        return true;
    } catch (Exception) return false;
}
bool scCreateDir(const(char)* path) {
    try {
        auto p = tmp(path);
        if (exists(p)) return false;
        mkdirRecurse(p);
        return true;
    } catch (Exception) return false;
}
bool scDeleteDir(const(char)* path) {
    try {
        auto p = tmp(path);
        if (!exists(p)) return false;
        rmdirRecurse(p);
        return true;
    } catch (Exception) return false;
}
long scFileSize(const(char)* path) {
    try return cast(long) getSize(tmp(path));
    catch (Exception) return -1;
}
const(char)* scListDir(const(char)* path) {
    try {
        listBuf.length = 0;
        foreach (entry; dirEntries(tmp(path), SpanMode.shallow)) {
            if (listBuf.length) listBuf ~= '\n';
            listBuf ~= baseName(entry.name);
        }
        listBuf ~= '\0';
        return listBuf.ptr;
    } catch (Exception) return null;
}

// time / misc
double scTimeNow() {
    return (Clock.currStdTime - unixTimeToStdTime(0)) / 1.0e7;
}
ulong scTimeMs() {
    return cast(ulong) ((Clock.currStdTime - unixTimeToStdTime(0)) / 10_000);
}
void scSleepMs(int ms) { WaitTime(ms / 1000.0); }
int scGetScreenWidth() { return GetScreenWidth(); }
int scGetScreenHeight() { return GetScreenHeight(); }

extern(D):

struct ScriptSystem {
    World world;
    MainScript main;

    void initialize(World w) {
        world = w;
        gWorld = w;
        scRng.seed(unpredictableSeed);
    }
    void compile(Entity e, string path) {
        auto s = compileState(path);
        if (!s) return;

        Script script;
        script.state = s;
        script.initFn = tccFn!(void, uint)(s, "init").ptr;
        script.updateFn = tccFn!(void, uint)(s, "update").ptr;
        script.destroyFn = tccFn!(void, uint)(s, "destroy").ptr;

        world.add!Script(e, script);
        if (script.initFn) script.initFn(cast(uint) e);
    }
    void compileMain(string path) {
        auto s = compileState(path);
        if (!s) return;

        main.state = s;
        main.initFn = tccFn!void(s, "onInit").ptr;
        main.updateFn = tccFn!(void, float)(s, "onUpdate").ptr;
        main.closeFn = tccFn!void(s, "onClose").ptr;

        if (main.initFn) main.initFn();
    }
    void update(float dt) {
        if (!world) return;

        foreach (t; world.view!Script) {
            auto script = &world.get!Script(t[0]);
            if (script.updateFn) script.updateFn(cast(uint) t[0]);
        }

        if (main.updateFn) main.updateFn(dt);
        tickTimers(dt);
    }
    void shutdown() {
        if (!world) return;

        foreach (t; world.view!Script) {
            auto script = &world.get!Script(t[0]);
            if (script.destroyFn) script.destroyFn(cast(uint) t[0]);
            if (script.state) tcc_delete(script.state);
        }

        if (main.closeFn) main.closeFn();
        if (main.state) tcc_delete(main.state);
        main = MainScript.init;
    }
private:
    static TCCState* compileState(string path) {
        auto s = tcc_new();
        if (!s) {
            Log.get.log(LogType.error, format("could not create TCC state for %s", path));
            return null;
        }
        TccLog log;
        tccAttachLog(s, &log);
        tcc_set_options(s, "-nostdinc -nostdlib");
        tcc_set_output_type(s, TccOutput.memory);
        registerApi(s);
        string code;
        try {
            code = readText(path);
        } catch (Exception e) {
            Log.get.log(LogType.error, format("cannot read script %s: %s", path, e.msg));
            tcc_delete(s);
            return null;
        }
        code = replaceAll(code, regex(`^\s*#\s*include\s*[<"]script_api\.h[>"][^\n]*$`, "m"), "");
        code = cPrelude ~ apiHeader ~ "\n#line 1 \"" ~ path.replace("\\", "/") ~ "\"\n" ~ code;
        if (tcc_compile_string(s, code.toStringz) < 0) {
            Log.get.log(LogType.error, format("Script failed to compile: %s\n%s",
                path, log.lines.join("\n")));
            tcc_delete(s);
            return null;
        }
        if (tcc_relocate(s, TCC_RELOCATE_AUTO) < 0) {
            Log.get.log(LogType.error, format("Script failed to relocate: %s\n%s",
                path, log.lines.join("\n")));
            tcc_delete(s);
            return null;
        }
        tcc_set_error_func(s, null, null);
        return s;
    }

    void tickTimers(float dt) {
        for (size_t i = 0; i < timers.length; ) {
            timers[i].remaining -= dt;
            if (timers[i].remaining > 0) { i++; continue; }
            auto t = timers[i];
            timers[i] = timers[$ - 1];
            timers.length -= 1;
            if (world.registry.valid(t.entity) && world.has!Script(t.entity))
                t.fn(cast(uint) t.entity);
        }
    }


    static void registerApi(TCCState* s) {
        tccAddFn!scNewTexture(s, "new_texture");
        tccAddFn!scLoadTexture(s, "load_texture");

        tccAddFn!scBindAction(s, "bind_action");
        tccAddFn!scBindAxis(s, "bind_axis");
        tccAddFn!scGetAction(s, "get_action");
        tccAddFn!scGetAxis(s, "get_axis");

        tccAddFn!scLogMessage(s, "log_message");
        tccAddFn!scDeltaTime(s, "delta_time");
        tccAddFn!scGetFPS(s, "get_fps");
        tccAddFn!scMouseDelta(s, "mouse_delta");
        tccAddFn!scToggleCursor(s, "toggle_cursor");
        tccAddFn!scMousePressed(s, "mouse_pressed");
        tccAddFn!scEntityName(s, "entity_name");

        tccAddFn!scCreateEntity(s, "create_entity");
        tccAddFn!scFindEntity(s, "find_entity");
        tccAddFn!scDestroyEntity(s, "destroy_entity");
        tccAddFn!scValid(s, "valid");

        tccAddFn!scGetCurrentCamera(s, "get_current_camera");
        tccAddFn!scSetCurrentCamera(s, "set_current_camera");

        tccAddFn!scAddComponent(s, "add_component");
        tccAddFn!scGetComponent(s, "get_component");
        tccAddFn!scRemoveComponent(s, "remove_component");

        tccAddFn!scInvoke(s, "invoke");
        tccAddFn!scCancelInvoke(s, "cancel_invoke");

        tccAddFn!scTransformMove(s, "transform_move");
        tccAddFn!scTransformRotate(s, "transform_rotate");
        tccAddFn!scTransformScale(s, "transform_scale");
        tccAddFn!scTeleport(s, "teleport");

        tccAddFn!scPlayOneShot(s, "play_one_shot");
        tccAddFn!scStopAudio(s, "stop_audio");

        tccAddFn!scRaycast(s, "raycast");

        tccAddFn!scLoadScene(s, "load_scene");

        tccAddFn!scClamp(s, "clamp");
        tccAddFn!scLerp(s, "lerpf");
        tccAddFn!scSmoothstep(s, "smoothstep");
        tccAddFn!scRadians(s, "radians");
        tccAddFn!scDegrees(s, "degrees");
        tccAddFn!scMinf(s, "minf");
        tccAddFn!scMaxf(s, "maxf");
        tccAddFn!scFabs(s, "absf");
        tccAddFn!scSignf(s, "signf");

        tccAddFn!floorf(s);
        tccAddFn!ceilf(s);
        tccAddFn!roundf(s);
        tccAddFn!sqrtf(s);
        tccAddFn!sinf(s);
        tccAddFn!cosf(s);
        tccAddFn!tanf(s);
        tccAddFn!atan2f(s);
        tccAddFn!powf(s);
        tccAddFn!expf(s);
        tccAddFn!logf(s);
        tccAddFn!fmodf(s);
        tccAddFn!hypotf(s);

        tccAddFn!scSetSeed(s, "setSeed");
        tccAddFn!scRandf(s, "randf");
        tccAddFn!scRandi(s, "randi");
        tccAddFn!scRandRange(s, "randRange");

        tccAddFn!scVec2Add(s, "vec2add");
        tccAddFn!scVec2Sub(s, "vec2sub");
        tccAddFn!scVec2Scale(s, "vec2scale");
        tccAddFn!scVec2Dot(s, "vec2dot");
        tccAddFn!scVec2Length(s, "vec2length");
        tccAddFn!scVec2Normalize(s, "vec2normalize");
        tccAddFn!scVec2Distance(s, "vec2distance");
        tccAddFn!scVec2Lerp(s, "vec2lerp");

        tccAddFn!scVec3FromXYZ(s, "vec3fromxyz");
        tccAddFn!scVec3Add(s, "vec3add");
        tccAddFn!scVec3Sub(s, "vec3sub");
        tccAddFn!scVec3Scale(s, "vec3scale");
        tccAddFn!scVec3Neg(s, "vec3neg");
        tccAddFn!scVec3Dot(s, "vec3dot");
        tccAddFn!scVec3Cross(s, "vec3cross");
        tccAddFn!scVec3Length(s, "vec3length");
        tccAddFn!scVec3Normalize(s, "vec3normalize");
        tccAddFn!scVec3Distance(s, "vec3distance");
        tccAddFn!scVec3Lerp(s, "vec3lerp");

        tccAddFn!scFileExists(s, "file_exists");
        tccAddFn!scDirExists(s, "dir_exists");
        tccAddFn!scReadFile(s, "read_file");
        tccAddFn!scWriteFile(s, "write_file");
        tccAddFn!scAppendFile(s, "append_file");
        tccAddFn!scDeleteFile(s, "delete_file");
        tccAddFn!scCreateDir(s, "create_dir");
        tccAddFn!scDeleteDir(s, "delete_dir");
        tccAddFn!scFileSize(s, "file_size");
        tccAddFn!scListDir(s, "list_dir");

        tccAddFn!scTimeNow(s, "time_now");
        tccAddFn!scTimeMs(s, "time_ms");
        tccAddFn!scSleepMs(s, "sleep_ms");
        tccAddFn!scGetScreenWidth(s, "get_screen_width");
        tccAddFn!scGetScreenHeight(s, "get_screen_height");

        tccAddFn!memset(s);
        tccAddFn!memcpy(s);
    }
}