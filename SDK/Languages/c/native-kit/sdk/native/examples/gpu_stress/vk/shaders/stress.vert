#version 450

layout(location = 0) out vec2 uv;
layout(location = 1) flat out float phase;

// The phase travels in firstInstance: early N5 OS builds did not export
// vkCmdPushConstants, so per-draw data does not depend on push constants.
void main() {
    uv = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    phase = float(gl_InstanceIndex) / 251.0;
    gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
