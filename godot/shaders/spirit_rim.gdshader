shader_type spatial;
render_mode blend_mix, cull_back;

// Cabeza de Luma: cáscara clara con borde luminoso (fresnel) que respira.
uniform vec3 base_color : source_color = vec3(0.66, 0.96, 0.92);
uniform vec3 rim_color : source_color = vec3(0.31, 0.95, 0.86);
uniform float rim_power = 2.6;
uniform float pulse = 0.5;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = base_color;
	ROUGHNESS = 0.35;
	EMISSION = base_color * 0.28 + rim_color * fresnel * (1.4 + pulse * 0.9);
}
