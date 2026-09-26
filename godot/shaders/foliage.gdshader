shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.16,0.40,0.25,1.0);
uniform float flexibility = 0.04;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    float weight = max(VERTEX.y,0.0);
    float gust = sin(TIME*1.15+world.x*.4+world.z*.3) + .35*sin(TIME*2.3+world.z);
    VERTEX.x += gust*weight*flexibility;
    VERTEX.z += cos(TIME*.8+world.x*.7)*weight*flexibility*.4;
}
void fragment() {
    ALBEDO = tint.rgb * mix(.83,1.08,UV.y);
    ROUGHNESS = .92;
    BACKLIGHT = tint.rgb*.22;
}
