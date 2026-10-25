module ecs.environment;
import raylib;
import json;
import ecs.world;
import core.asset;

struct Environment {
    Vector3 ambientColor = {0.0f, 0.0f, 0.0f};
    Vector3 fogColor = {0.0f, 0.0f, 0.0f};
    Texture2D* sky = null;

    float fogStart, fogEnd;

    void fromJsonScene(string path) {
        auto scene = Json.parseFile(path, true);

        this.ambientColor = toVectorColor(Color(
            scene["data"]["environment"]["ambient"][0].get!ubyte(),
            scene["data"]["environment"]["ambient"][1].get!ubyte(),
            scene["data"]["environment"]["ambient"][2].get!ubyte(),
            255
        ));
        this.fogColor = toVectorColor(Color(
            scene["data"]["environment"]["fogColor"][0].get!ubyte(),
            scene["data"]["environment"]["fogColor"][1].get!ubyte(),
            scene["data"]["environment"]["fogColor"][2].get!ubyte(),
            255
        ));
        this.sky = Asset.get.getTexture(scene["data"]["environment"]["sky"].get!string());

        this.fogStart = scene["data"]["environment"]["fogStart"].get!float();
        this.fogEnd = scene["data"]["environment"]["fogEnd"].get!float();
    }
}