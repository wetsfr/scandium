module core.asset;
import std.string : toStringz;
import raylib;

final class Asset {
    private Texture2D*[string] textures;
    private Sound*[string]     sounds;
    private Model*[string]     models;
    private Shader*[string]    shaders;
    private Font*[string]      fonts;

    private this() {}
    private static shared Asset _instance;
    static Asset get() {
        if (_instance is null) {
            synchronized {
                if (_instance is null) _instance = cast(shared) new Asset();
            }
        }
        return cast(Asset) _instance;
    }
    
    // default models
    void loadDefaults() {
        // cube
        {
            auto mdl = new Model;
            *mdl = LoadModelFromMesh(GenMeshCube(1.0f, 1.0f, 1.0f));
            if (auto old = "cube" in models) UnloadModel(**old);
            models["cube"] = mdl;
        }
        // sphere
        {
            auto mdl = new Model;
            *mdl = LoadModelFromMesh(GenMeshSphere(0.5f, 16, 32));
            if (auto old = "sphere" in models) UnloadModel(**old);
            models["sphere"] = mdl;
        }
    }

    ref Texture2D loadTexture(string name, string path) {
        auto tex = new Texture2D;
        *tex = LoadTexture(path.toStringz);

        if (auto oldPtr = name in textures)
            UnloadTexture(**oldPtr);

        textures[name] = tex;
        SetTextureWrap(*tex, TextureWrap.TEXTURE_WRAP_REPEAT);
        return *tex;
    }

    Texture2D* getTexture(string name) nothrow {
        if (auto p = name in textures) return *p;
        return null;
    }

    ref Sound loadSound(string name, string path) {
        auto snd = new Sound;
        *snd = LoadSound(path.toStringz);

        if (auto oldPtr = name in sounds) UnloadSound(**oldPtr);
        sounds[name] = snd;
        return *snd;
    }
    Sound* getSound(string name) nothrow {
        if (auto p = name in sounds) return *p;
        return null;
    }

    ref Model loadModel(string name, string path) {
        auto mdl = new Model;
        *mdl = LoadModel(path.toStringz);

        if (auto oldPtr = name in models) UnloadModel(**oldPtr);
        models[name] = mdl;
        return *mdl;
    }
    Model* getModel(string name) nothrow {
        if (auto p = name in models) return *p;
        return null;
    }
    Model* getCube() nothrow   { return getModel("cube"); }
    Model* getSphere() nothrow { return getModel("sphere"); }


    ref Shader loadShader(string name, string vs, string fs) {
        auto shdr = new Shader;
        *shdr = LoadShader(vs.toStringz, fs.toStringz);

        if (auto oldPtr = name in shaders) UnloadShader(**oldPtr);
        shaders[name] = shdr;
        return *shdr;
    }
    Shader* getShader(string name) nothrow {
        if (auto p = name in shaders) return *p;
        return null;
    }

    ref Font loadFont(string name, string path) {
        auto font = new Font;
        *font = LoadFont(path.toStringz);

        if (auto oldPtr = name in fonts) UnloadFont(**oldPtr);
        fonts[name] = font;
        return *font;
    }
    Font* getFont(string name) nothrow {
        if (auto p = name in fonts) return *p;
        return null;
    }

    void unload() nothrow {
        foreach (k, tex; textures)  UnloadTexture(*tex);
        foreach (k, snd; sounds)    UnloadSound(*snd);
        foreach (k, mdl; models)    UnloadModel(*mdl);
        foreach (k, shdr; shaders)  UnloadShader(*shdr);
        foreach (k, font; fonts)    UnloadFont(*font);
    }
}