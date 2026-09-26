shader_type spatial;
// Fase 7: cristal estilizado. Facetas planas, brillo interior que sube por la pieza, borde de Fresnel
// y destellos que recorren las caras. Se aplica en tiempo de ejecución (scripts/crystal_style.gd).
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.62, 0.5, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.38, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.9, 0.85, 1.0, 1.0);
uniform float glow_strength = 1.6;
uniform float pulse_speed = 1.2;
uniform float charge = 0.0;

varying vec3 local_pos;
varying vec3 world_pos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 flat_normal = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
	float facet = hash(floor(flat_normal * 7.0));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	float band = 0.5 + 0.5 * sin(world_pos.y * 2.2 - TIME * pulse_speed + facet * 6.0);
	float sparkle = smoothstep(0.985, 1.0, sin(TIME * 2.0 + facet * 40.0 + world_pos.x * 3.0) * 0.5 + 0.5);
	ALBEDO = base_color.rgb * (0.55 + 0.45 * facet);
	ROUGHNESS = 0.08 + facet * 0.12;
	METALLIC = 0.1;
	SPECULAR = 0.9;
	vec3 glow = glow_color.rgb * glow_strength * (0.35 + 0.4 * band + charge * 1.6);
	EMISSION = glow + rim_color.rgb * fresnel * (1.2 + charge) + vec3(sparkle) * 2.0;
}
