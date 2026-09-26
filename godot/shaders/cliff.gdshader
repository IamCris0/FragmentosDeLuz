shader_type spatial;

// Acantilados de las islas (fase 6): textura pintada en triplanar, estratos cálidos que se oscurecen
// hacia la raíz, musgo en las caras que miran arriba y vetas de cristal turquesa que laten suavemente.
uniform sampler2D stone : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 top_tint : source_color = vec3(0.72, 0.58, 0.45);
uniform vec3 deep_tint : source_color = vec3(0.36, 0.32, 0.38);
uniform vec3 moss_tint : source_color = vec3(0.24, 0.42, 0.27);
uniform vec3 vein_color : source_color = vec3(0.31, 0.85, 0.80);
uniform float scale = 0.18;
uniform float top_y = 0.0;
uniform float depth = 8.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(stone, p.zy * scale).rgb;
	vec3 y = texture(stone, p.xz * scale).rgb;
	vec3 z = texture(stone, p.xy * scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 base = triplanar(world_pos, world_normal);
	float h = clamp((top_y - world_pos.y) / depth, 0.0, 1.0);
	float strata = 0.5 + 0.5 * sin(world_pos.y * 3.1 + sin(world_pos.x * 0.35 + world_pos.z * 0.27) * 1.7);
	vec3 tint = mix(top_tint, deep_tint, smoothstep(0.0, 1.0, h));
	tint *= mix(0.86, 1.08, strata);
	float moss = smoothstep(0.55, 0.9, world_normal.y) * (1.0 - h);
	vec3 color = mix(base * tint * 1.65, moss_tint, moss * 0.7);
	float vein_noise = sin(world_pos.x * 0.9 + sin(world_pos.y * 1.7) * 2.0) * sin(world_pos.z * 0.8 + world_pos.y * 0.6);
	float vein = smoothstep(0.985, 0.998, abs(vein_noise)) * smoothstep(0.25, 0.7, h);
	ALBEDO = mix(color, vein_color, vein * 0.7);
	// Luz de relleno estilizada: la cara inferior nunca queda negra (la ilustración es luminosa).
	EMISSION = color * 0.16 * (0.4 + h) + vein_color * vein * (0.9 + 0.4 * sin(TIME * 1.4 + world_pos.x * 0.2));
	ROUGHNESS = 0.92;
}
