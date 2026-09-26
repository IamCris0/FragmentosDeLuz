shader_type spatial;
// Fase 7: suelo del Observatorio. Mármol nocturno con vetas doradas, rejilla de estrellas incrustadas
// y un círculo astral que se ilumina con «glow».
render_mode diffuse_burley;

uniform vec4 marble : source_color = vec4(0.13, 0.16, 0.27, 1.0);
uniform vec4 vein : source_color = vec4(0.85, 0.7, 0.4, 1.0);
uniform vec4 star_tint : source_color = vec4(1.0, 0.9, 0.62, 1.0);
uniform float glow = 0.4;
uniform float tile = 2.0;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.1 + 3.7; a *= 0.5; }
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = fbm(p * 0.35);
	float veins = smoothstep(0.02, 0.0, abs(fbm(p * 0.5 + n * 2.0) - 0.5)) * 0.8;
	vec2 cell = fract(p / tile) - 0.5;
	vec2 id = floor(p / tile);
	float seam = smoothstep(0.47, 0.5, max(abs(cell.x), abs(cell.y)));
	float h = hash(id);
	vec2 sp = abs(cell);
	float star_shape = max(1.0 - (sp.x * 9.0 + sp.y * 1.6), 1.0 - (sp.y * 9.0 + sp.x * 1.6));
	float inlay = step(0.82, h) * smoothstep(0.0, 0.25, star_shape);
	vec3 base = marble.rgb * (0.75 + 0.35 * n) - vec3(seam * 0.05);
	ALBEDO = base + vein.rgb * veins * 0.25 + star_tint.rgb * inlay * 0.4;
	ROUGHNESS = 0.3 + n * 0.3;
	METALLIC = 0.05;
	EMISSION = star_tint.rgb * inlay * (0.4 + glow * 1.6) * (0.7 + 0.3 * sin(TIME * 1.5 + h * 20.0)) + vein.rgb * veins * glow * 0.25;
}
