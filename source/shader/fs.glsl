#version 330

in vec3 fragPosition;
in vec3 fragNormal;
in vec4 fragColor;
in vec2 fragTexCoord;

struct Light {
    vec3 position;
    vec3 color;
    float radius;
    int enabled;
};

#define MAX_LIGHTS 16
uniform Light lights[MAX_LIGHTS];
uniform vec3 viewPos;
uniform vec3 ambientColor;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;

uniform sampler2D texture0;
uniform vec2 tiling;

out vec4 finalColor;

void main() {
    vec3 normal = normalize(fragNormal);
    vec3 viewDir = normalize(viewPos - fragPosition);
    vec3 totalLighting = ambientColor;

    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (lights[i].enabled == 0) continue;

        vec3 lightVec = lights[i].position - fragPosition;
        float dist = length(lightVec);

        if (dist < lights[i].radius) {
            vec3 lightDir = normalize(lightVec);

            float atten = clamp(1.0 - (dist / lights[i].radius), 0.0, 1.0);
            atten *= atten;

            float diff = max(dot(normal, lightDir), 0.0);
            totalLighting += diff * lights[i].color * atten;
            totalLighting = clamp(totalLighting, 0.0, 1.0);
        }
    }

    vec4 texel = texture(texture0, fragTexCoord * tiling);
    vec3 result = totalLighting * texel.rgb * fragColor.rgb;

    result = pow(result, vec3(1.35));

    float d = length(viewPos - fragPosition);
    float fogFactor = clamp((fogEnd - d) / (fogEnd - fogStart), 0.0, 1.0);

    finalColor = vec4(mix(fogColor, result, fogFactor), texel.a);
}