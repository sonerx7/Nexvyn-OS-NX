#version 450

layout(location = 0) out vec3 v_color;

const vec2 kPositions[3] = vec2[](
    vec2( 0.0, -0.55),
    vec2( 0.55, 0.55),
    vec2(-0.55, 0.55)
);

const vec3 kColors[3] = vec3[](
    vec3(0.95, 0.25, 0.25),
    vec3(0.20, 0.85, 0.35),
    vec3(0.20, 0.45, 0.95)
);

void main() {
    gl_Position = vec4(kPositions[gl_VertexIndex], 0.0, 1.0);
    v_color = kColors[gl_VertexIndex];
}
