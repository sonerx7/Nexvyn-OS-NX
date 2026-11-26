#version 450

layout(location = 0) out vec2 v_uv;

const int kVerts[6] = int[6](0, 1, 2, 0, 2, 3);
const vec2 kUvs[4] = vec2[4](
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0),
    vec2(0.0, 1.0)
);
const vec2 kPos[4] = vec2[4](
    vec2(-1.0,  1.0),
    vec2( 1.0,  1.0),
    vec2( 1.0, -1.0),
    vec2(-1.0, -1.0)
);

void main() {
    int idx = kVerts[gl_VertexIndex];
    v_uv = kUvs[idx];
    gl_Position = vec4(kPos[idx], 0.0, 1.0);
}
