shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float threads = pow(0.5 + 0.5 * sin(UV.x * 100.53 + TIME * 0.8), 5.0);
	float rising = 0.65 + 0.35 * sin(UV.y * 32.0 + TIME * 2.0);
	float ends = smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.35, 1.0 - UV.y);
	ALBEDO = mix(vec3(0.15, 0.8, 0.68), vec3(1.0, 0.77, 0.28), threads);
	EMISSION = ALBEDO * 1.4;
	ALPHA = strength * ends * (0.09 + threads * 0.2) * rising;
}
