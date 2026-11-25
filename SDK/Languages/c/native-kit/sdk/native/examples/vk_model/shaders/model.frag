#version 450
// Lambert with a hemispheric ambient term; base colour = texture * group colour.

layout(push_constant) uniform Push {
    mat4 view_proj;
    vec4 grid;
    vec4 origin;
    vec4 color;
} pc;

layout(set = 0, binding = 0) uniform sampler2D u_base;

layout(location = 0) in vec3 v_normal;
layout(location = 1) in vec2 v_uv;

layout(location = 0) out vec4 out_color;

void main() {
    vec3 n = normalize(v_normal);
    const vec3 light_dir = normalize(vec3(0.45, 0.8, 0.35));
    float diffuse = max(dot(n, light_dir), 0.0);
    float ambient = mix(0.22, 0.38, n.y * 0.5 + 0.5);
    vec3 base = texture(u_base, v_uv).rgb * pc.color.rgb;
    out_color = vec4(base * (ambient + diffuse * 0.8), 1.0);
}
