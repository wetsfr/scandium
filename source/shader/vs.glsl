#version 330

in vec3 vertexPosition;
in vec3 vertexNormal;
in vec2 vertexTexCoord;
in vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;

out vec3 fragPosition;
out vec3 fragNormal;
out vec4 fragColor;
out vec2 fragTexCoord;

void main() {
    fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
    
    fragNormal = normalize(mat3(matModel) * vertexNormal);

    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    gl_Position = mvp * vec4(vertexPosition, 1.0);
}