shader_type canvas_item;
// Fase 7: fondo de la Constelación de Neri y de la carta. Estrellas titilantes y nebulosa suave.

uniform vec4 top_color : source_color = vec4(0.02, 0.035, 0.08, 0.97);
uniform vec4 bottom_color : source_color = vec4(0.04, 0.07, 0.09, 0.97);
uniform vec4 nebula_a : source_color = vec4(0.25, 0.55, 0.6, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.55, 0.35, 0.65, 1.0);
uniform float aspect = 1.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 45758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 11.7; a *= 0.5; }
	return v;
}

float stars(vec2 uv, float scale, float threshold) {
	vec2 cell = floor(uv * scale);
	vec2 local = fract(uv * scale) - 0.5;
	float h = hash(cell);
	if (h < threshold) return 0.0;
	vec2 offset = vec2(hash(cell + 7.1), hash(cell + 3.3)) - 0.5;
	float d = length(local - offset * 0.7);
	float twinkle = 0.6 + 0.4 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.08, 0.0, d) * twinkle * (h - threshold) / (1.0 - threshold);
}

void fragment() {
	vec2 uv = vec2(UV.x * aspect, UV.y);
	vec4 base = mix(top_color, bottom_color, UV.y);
	float n = fbm(uv * 2.2 + vec2(TIME * 0.01, 0.0));
	float m = fbm(uv * 3.1 - vec2(0.0, TIME * 0.008) + 4.0);
	vec3 nebula = nebula_a.rgb * smoothstep(0.5, 0.9, n) * 0.22 + nebula_b.rgb * smoothstep(0.55, 0.95, m) * 0.18;
	float s = stars(uv, 60.0, 0.86) + stars(uv + 0.37, 140.0, 0.9) * 0.6;
	COLOR = vec4(base.rgb + nebula + vec3(s), base.a);
}
