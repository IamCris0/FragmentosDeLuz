shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

void vertex() {
	VERTEX.z += sin(VERTEX.y * 1.8 + TIME * 2.0) * .05;
}

void fragment() {
	float stream = sin(UV.x * 75.0 + sin(UV.y * 16.0 + TIME * 3.0)) * .5 + .5;
	float foam = pow(sin(UV.y * 100.0 + TIME * 14.0) * .5 + .5, 12.0);
	ALBEDO = mix(vec3(.16,.64,.66),vec3(.81,.95,.91),stream*.4+foam*.3);
	EMISSION = ALBEDO*.25;
	ROUGHNESS = .25;
	ALPHA = smoothstep(0.0,.12,UV.x) * (1.0-smoothstep(.88,1.0,UV.x)) * .77;
}
