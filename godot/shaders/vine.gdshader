shader_type spatial;
render_mode cull_disabled;

// Enredadera colgante (fase 6): hojas alternas dibujadas en una tira, balanceo mayor en la punta
// y algunas hojas con brillo turquesa, como la vegetación mágica de la referencia.
instance uniform float phase = 0.0;
uniform vec3 leaf_color : source_color = vec3(0.16, 0.42, 0.28);
uniform vec3 glow_color : source_color = vec3(0.30, 0.95, 0.85);

void vertex() {
	float w = max(-VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * 0.9 + phase + w * 0.8) * w * 0.06;
	VERTEX.z += cos(TIME * 0.7 + phase) * w * 0.05;
}

void fragment() {
	float y = UV.y * 16.0;
	float row = floor(y);
	float side = mod(row, 2.0) < 1.0 ? 0.32 : 0.68;
	vec2 p = vec2((UV.x - side) * 3.0, fract(y) - 0.5);
	float leaf = 1.0 - smoothstep(0.34, 0.48, length(p * vec2(1.0, 1.5)));
	float stem = 1.0 - smoothstep(0.015, 0.05, abs(UV.x - 0.5));
	float tip = 1.0 - smoothstep(0.82, 1.0, UV.y);
	if (max(leaf, stem) * tip < 0.5) discard;
	float magic = step(0.9, fract(row * 0.37 + phase));
	ALBEDO = mix(leaf_color * mix(0.8, 1.1, fract(row * 0.61)), glow_color, magic * 0.55);
	EMISSION = glow_color * magic * 0.35;
	ROUGHNESS = 0.9;
	BACKLIGHT = leaf_color * 0.3;
}
