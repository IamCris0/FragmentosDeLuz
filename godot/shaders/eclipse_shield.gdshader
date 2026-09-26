shader_type spatial;
// Fase 7: escudo del Heraldo del Eclipse. Burbuja de Fresnel con celdas hexagonales que fluyen.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 shield_color : source_color = vec4(1.0, 0.55, 0.3, 1.0);
uniform float strength = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hex(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	vec3 n = normalize(local_pos);
	vec2 uv = vec2(atan(n.z, n.x) * 3.0, n.y * 6.0 + TIME * 0.4);
	float cells = smoothstep(0.08, 0.0, hex(uv * 1.3));
	float flicker = 0.85 + 0.15 * sin(TIME * 9.0);
	ALBEDO = shield_color.rgb * (1.2 + cells);
	ALPHA = clamp((fres * 0.9 + cells * 0.35 * (0.3 + fres)) * strength * flicker, 0.0, 1.0);
}
