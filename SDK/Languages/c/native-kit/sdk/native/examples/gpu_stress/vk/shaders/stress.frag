#version 450

layout(location = 0) in vec2 uv;
layout(location = 1) flat in float phase;
layout(location = 0) out vec4 o_color;

// Tap count per load level, set at pipeline creation (no push constants on the console host).
layout(constant_id = 0) const int TAPS = 1;

// Texture-free ALU stand-in for the GL scene's texture taps.
void main() {
    int taps = max(TAPS, 1);
    vec2 coord = uv * 1.71 + vec2(phase, phase * 0.71);
    vec3 sum = vec3(0.0);
    for (int i = 0; i < taps; ++i) {
        vec3 s = fract(sin(vec3(coord.x * 12.9898 + coord.y * 78.233,
                                coord.x * 39.346 + coord.y * 11.135,
                                coord.x * 73.156 + coord.y * 52.235)) * 43758.5453);
        sum += s;
        coord = coord * 1.18 + s.rg * 0.47 + 0.013;
    }
    vec3 tint = vec3(0.42, 0.63, 0.85);
    o_color = vec4(mix(tint * 0.5, tint, uv.y) * (0.65 + 0.35 * sum / float(taps)), 0.38);
}
