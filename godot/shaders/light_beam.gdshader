shader_type spatial;
// Fase 7: rayo de luz de las Grutas. Núcleo brillante, halo suave y pulsos que viajan hacia delante.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float intensity = 1.0;
uniform float length_m = 10.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;     // CylinderMesh: UV.x rodea el cilindro
	float fres = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float travel = fract(UV.y * length_m * 0.25 + TIME * 1.8);
	float pulses = smoothstep(0.0, 0.08, travel) * smoothstep(0.35, 0.1, travel);
	float core = fres;
	ALBEDO = beam_color.rgb * (1.2 + pulses * 1.5) + vec3(0.3) * core;
	ALPHA = clamp((0.25 + 0.55 * core + 0.35 * pulses) * intensity, 0.0, 1.0);
}
