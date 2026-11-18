shader_type spatial;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 stone_position;
void vertex() { stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
    vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x), mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x), mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}
void fragment() {
    float grain = noise(stone_position * 3.0) * 0.12 + noise(stone_position * 18.0) * 0.025;
    vec3 painted = texture(stone_texture, stone_position.xz * 0.39).rgb;
    float patina = dot(painted, vec3(0.2126, 0.7152, 0.0722));
    ALBEDO = mix(vec3(0.20, 0.23, 0.20), vec3(0.58, 0.53, 0.41), clamp(0.30 + patina * 0.95 + grain, 0.0, 1.0));
    ROUGHNESS = 0.92;
}
