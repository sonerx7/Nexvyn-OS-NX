#version 450
// One draw per texture group, instanceCount = number of copies: each instance picks its grid cell.

layout(push_constant) uniform Push {
    mat4 view_proj;
    vec4 grid;   // x columns, y spacing x, z spacing z, w unused
    vec4 origin; // xyz offset that centres the model on its cell, w unused
    vec4 color;  // group base colour (white when textured)
} pc;

layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec4 in_normal;
layout(location = 2) in vec2 in_uv;

layout(location = 0) out vec3 v_normal;
layout(location = 1) out vec2 v_uv;

void main() {
    int cols = int(pc.grid.x);
    int col = gl_InstanceIndex % cols;
    int row = gl_InstanceIndex / cols;
    vec3 cell = vec3((float(col) - 0.5 * float(cols - 1)) * pc.grid.y, 0.0, (float(row) - 0.5) * pc.grid.z);
    vec3 world = in_pos + pc.origin.xyz + cell;
    gl_Position = pc.view_proj * vec4(world, 1.0);
    v_normal = in_normal.xyz;
    v_uv = in_uv;
}
