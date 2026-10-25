module ecs.systems.renderer;
import raylib;
import std.math;

import ecs.environment;
import ecs.components.renderer.light_source;
import ecs.components.renderer.renderer;
import ecs.components.transform;
import ecs.components.renderer.camera;

import ecs.world;
import ecs.ecs;
import core.application;
import core.asset;
import core.log;


private struct LightLoc {
    int posLoc, colorLoc, radiusLoc, enabledLoc;
}

final class RendererSystem {
    private World world;
    private Environment env;
    private Shader* main;

    private int viewLoc, ambientLoc, fogStartLoc, fogEndLoc, fogColorLoc, tilingLoc;

    private LightLoc[] lights;
    private int lightCount = 0;

    void onMeshRenderer(Registry reg, Entity e) {
        auto ref component = world.get!MeshRenderer(e);
        if (!component.model) return;

        for (int i = 0; i < component.model.materialCount; i++)
            component.model.materials[i].shader = *main;
        
        SetShaderValue(*main, tilingLoc, &component.tiling, ShaderUniformDataType.SHADER_UNIFORM_VEC2);
    }

    void onLightSource(Registry reg, Entity e) {
        lightCount++;
        if (lightCount > Application.get.settings.maxLights) 
            Log.get.log(LogType.error, "too many lights on a scene!");
    }

    void onLightDestroy(Registry reg, Entity e) {
        lightCount--;
        if (lightCount < 0) lightCount = 0;
    }

    void initialize(World world, ref Environment env) {
        this.world = world;
        this.env = env;
        lights.length = Application.get.settings.maxLights;

        main = Asset.get.getShader(ShaderName);
        viewLoc = GetShaderLocation(*main, "viewPos");
        ambientLoc = GetShaderLocation(*main, "ambientColor");
        fogStartLoc = GetShaderLocation(*main, "fogStart");
        fogEndLoc = GetShaderLocation(*main, "fogEnd");
        fogColorLoc = GetShaderLocation(*main, "fogColor");
        tilingLoc = GetShaderLocation(*main, "tiling");
        main.locs[ShaderLocationIndex.SHADER_LOC_MATRIX_MODEL] = GetShaderLocation(*main, "matModel");
        main.locs[ShaderLocationIndex.SHADER_LOC_MAP_ALBEDO]      = GetShaderLocation(*main, "texture0");
    
        for (int i = 0; i < Application.get.settings.maxLights; i++) {
            lights[i].posLoc = GetShaderLocation(*main, TextFormat("lights[%i].position", i));
            lights[i].colorLoc = GetShaderLocation(*main, TextFormat("lights[%i].color", i));
            lights[i].radiusLoc = GetShaderLocation(*main, TextFormat("lights[%i].radius", i));
            lights[i].enabledLoc = GetShaderLocation(*main, TextFormat("lights[%i].enabled", i));
        }

        SetShaderValue(*main, ambientLoc, &env.ambientColor, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
        SetShaderValue(*main, fogStartLoc, &env.fogStart, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
        SetShaderValue(*main, fogEndLoc, &env.fogEnd, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
        SetShaderValue(*main, fogColorLoc, &env.fogColor, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
    }
    void update() {
        Entity camera = world.getActiveCamera();
        auto cameraTransform = world.get!Transform3D(camera);

        SetShaderValue(*main, viewLoc, &cameraTransform.position, ShaderUniformDataType.SHADER_UNIFORM_VEC3);

        int i = 0;
        foreach (entity, transform, light; world.view!(Transform3D, LightSource)()) {
            if (i >= Application.get.settings.maxLights) break;
            int enabled = light.enabled ? 1 : 0;

            SetShaderValue(*main, lights[i].posLoc, &transform.position, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
            SetShaderValue(*main, lights[i].colorLoc, &light.color, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
            SetShaderValue(*main, lights[i].radiusLoc, &light.radius, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
            SetShaderValue(*main, lights[i].enabledLoc, &enabled, ShaderUniformDataType.SHADER_UNIFORM_INT);

            i++;
        }

        int disabled = 0;
        for (int j = i; j < Application.get.settings.maxLights; j++)
            SetShaderValue(*main, lights[j].enabledLoc, &disabled, ShaderUniformDataType.SHADER_UNIFORM_INT);
    }
    void draw() {
        Entity cam = world.getActiveCamera();
        if (cam == nullEntity) {
            Log.get.log(LogType.error, "no active camera!");
            return;
        }

        auto ref camTransform = world.get!Transform3D(cam);
        auto ref worldCamera = world.get!WorldCamera(cam);

        Camera3D camera;
        camera.fovy = worldCamera.FOV;
        camera.position = camTransform.position;
        camera.projection = CameraProjection.CAMERA_PERSPECTIVE;

        float yaw = camTransform.rotation.y * DEG2RAD;
        float pitch = camTransform.rotation.x * DEG2RAD;

        Vector3 lookDir;
        lookDir.x = -cos(pitch) * sin(yaw);
        lookDir.y = sin(pitch);
        lookDir.z = cos(pitch) * cos(yaw);

        camera.target = Vector3Add(camera.position, lookDir);
        camera.up = Vector3(0,1,0);
        worldCamera.right = Vector3Normalize(Vector3CrossProduct(camera.up, lookDir));

        Matrix view = MatrixLookAt(camera.position, camera.target, camera.up);
        Matrix proj = MatrixPerspective(camera.fovy * DEG2RAD, GetScreenWidth() / cast(float)GetScreenHeight(), 0.1f, 1000.0f);
        Matrix viewProj = MatrixMultiply(view, proj);

        BeginMode3D(camera);

        if (env.sky != null) {
            rlDisableBackfaceCulling();
            rlSetTexture(env.sky.id);
                skybox(camera.position);
            rlSetTexture(0);
            rlEnableBackfaceCulling();
        }

        BoundingBox box;
        foreach (entity, transform, mesh; world.view!(Transform3D, MeshRenderer)()) {
            if (transform.dirty) world.transformAPI.buildMatrix(entity);
            if (!mesh.model) continue;

            for (int i = 0; i < mesh.model.meshCount; i++) {
                SetShaderValue(mesh.model.materials[0].shader, tilingLoc, &mesh.tiling, ShaderUniformDataType.SHADER_UNIFORM_VEC2);
                DrawMesh(
                    mesh.model.meshes[i],
                    mesh.model.materials[mesh.model.meshMaterial[i]],
                    transform.mat
                );
            }
        }

        EndMode3D();
    }

    private void skybox(ref Vector3 p){
        rlBegin(RL_QUADS);
        rlColor4ub(255, 255, 255, 255);
            // FRONT
            rlTexCoord2f(0, 0); rlVertex3f(p.x - SkyboxSize/2, p.y - SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(1, 0); rlVertex3f(p.x + SkyboxSize/2, p.y - SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(1, 1); rlVertex3f(p.x + SkyboxSize/2, p.y + SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(0, 1); rlVertex3f(p.x - SkyboxSize/2, p.y + SkyboxSize/2, p.z - SkyboxSize/2);
            // BACK
            rlTexCoord2f(0, 0); rlVertex3f(p.x + SkyboxSize/2, p.y - SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(1, 0); rlVertex3f(p.x - SkyboxSize/2, p.y - SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(1, 1); rlVertex3f(p.x - SkyboxSize/2, p.y + SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(0, 1); rlVertex3f(p.x + SkyboxSize/2, p.y + SkyboxSize/2, p.z + SkyboxSize/2);
            // LEFT
            rlTexCoord2f(0, 0); rlVertex3f(p.x - SkyboxSize/2, p.y - SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(1, 0); rlVertex3f(p.x - SkyboxSize/2, p.y - SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(1, 1); rlVertex3f(p.x - SkyboxSize/2, p.y + SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(0, 1); rlVertex3f(p.x - SkyboxSize/2, p.y + SkyboxSize/2, p.z + SkyboxSize/2);
            // RIGHT
            rlTexCoord2f(0, 0); rlVertex3f(p.x + SkyboxSize/2, p.y - SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(1, 0); rlVertex3f(p.x + SkyboxSize/2, p.y - SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(1, 1); rlVertex3f(p.x + SkyboxSize/2, p.y + SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(0, 1); rlVertex3f(p.x + SkyboxSize/2, p.y + SkyboxSize/2, p.z - SkyboxSize/2);
            // TOP
            rlTexCoord2f(0, 0); rlVertex3f(p.x - SkyboxSize/2, p.y + SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(1, 0); rlVertex3f(p.x + SkyboxSize/2, p.y + SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(1, 1); rlVertex3f(p.x + SkyboxSize/2, p.y + SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(0, 1); rlVertex3f(p.x - SkyboxSize/2, p.y + SkyboxSize/2, p.z + SkyboxSize/2);
            // BOTTOM
            rlTexCoord2f(0, 0); rlVertex3f(p.x - SkyboxSize/2, p.y - SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(1, 0); rlVertex3f(p.x + SkyboxSize/2, p.y - SkyboxSize/2, p.z + SkyboxSize/2);
            rlTexCoord2f(1, 1); rlVertex3f(p.x + SkyboxSize/2, p.y - SkyboxSize/2, p.z - SkyboxSize/2);
            rlTexCoord2f(0, 1); rlVertex3f(p.x - SkyboxSize/2, p.y - SkyboxSize/2, p.z - SkyboxSize/2);
        rlEnd();
    }
}