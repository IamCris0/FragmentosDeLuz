shader_type spatial;
// Fase 7: alas de luz del planeo. Lámina aditiva con plumas y borde brillante que ondula.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform float side = 1.0;
uniform vec4 core_color : source_color = vec4(0.55, 1.0, 0.9, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.86, 0.52, 1.0);

void vertex() {
	float along = abs(VERTEX.x) / 1.25;
	VERTEX.y += sin(TIME * 6.0 + along * 4.0) * 0.05 * along;
	VERTEX.z -= along * along * 0.18;
}

void fragment() {
	float along = side > 0.0 ? UV.x : 1.0 - UV.x;   // 0 = hombro, 1 = punta
	float height = UV.y;
	// Silueta: ancha junto al cuerpo, se estrecha hacia la punta con tres plumas.
	float feathers = 0.5 + 0.5 * sin(along * 18.0 - 1.2);
	float profile = mix(0.95, 0.35 + 0.2 * feathers, along);
	float center = abs(height - 0.42) * 2.0;
	float mask = smoothstep(profile, profile - 0.18, center) * smoothstep(1.0, 0.82, along);
	float streak = 0.55 + 0.45 * sin(along * 30.0 - TIME * 5.0 + height * 6.0);
	vec3 color = mix(core_color.rgb, edge_color.rgb, smoothstep(0.35, 0.95, along));
	float rim = smoothstep(profile - 0.18, profile - 0.02, center);
	ALBEDO = color * (0.6 + 0.5 * streak) + edge_color.rgb * rim * 0.8;
	ALPHA = mask * 0.75;
}
