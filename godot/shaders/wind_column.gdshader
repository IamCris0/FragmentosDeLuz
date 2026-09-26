shader_type spatial;
// Fase 7: corriente de viento. Franjas translúcidas que suben (columna) o se desplazan (lateral).
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.75, 0.96, 0.92, 1.0);
uniform float strength = 1.0;
uniform float direction = 1.0;   // 1 = ascendente, 0 = lateral
uniform vec3 lateral = vec3(1.0, 0.0, 0.0);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float streaks(vec2 uv, float speed) {
	vec2 cell = vec2(floor(uv.x * 14.0), 0.0);
	float offset = hash(cell) * 7.0;
	float band = fract(uv.y * 1.6 - TIME * speed * (0.6 + hash(cell + 3.1) * 0.8) + offset);
	float line = smoothstep(0.0, 0.18, band) * smoothstep(0.55, 0.2, band);
	float width = abs(fract(uv.x * 14.0) - 0.5) * 2.0;
	return line * smoothstep(1.0, 0.3, width);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float glow;
	float fade;
	if (direction > 0.5) {
		glow = streaks(vec2(UV.x, UV.y * 3.0), -0.9);
		fade = smoothstep(0.0, 0.18, 1.0 - UV.y) * smoothstep(0.0, 0.12, UV.y);
	} else {
		vec3 dir = normalize(lateral + vec3(0.0001));
		vec3 side = normalize(cross(dir, vec3(0.0, 1.0, 0.0)));
		vec2 p = vec2(dot(world_pos, side) * 0.25 + world_pos.y * 0.7, dot(world_pos, dir) * 0.12);
		glow = streaks(p, 1.4);
		fade = 1.0;
	}
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp((glow * 0.55 + fres * 0.12) * fade * strength, 0.0, 1.0);
}
