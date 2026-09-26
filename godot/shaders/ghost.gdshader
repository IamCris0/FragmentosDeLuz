shader_type spatial;
// Fase 7: proyección luminosa de Maren (y ecos de memoria). Borde brillante, cuerpo translúcido
// y líneas de exploración que suben.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float opacity = 0.75;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float lines = smoothstep(0.7, 1.0, sin(world_pos.y * 40.0 - TIME * 4.0) * 0.5 + 0.5);
	float flicker = 0.92 + 0.08 * sin(TIME * 13.0) * sin(TIME * 7.3);
	ALBEDO = tint.rgb * (0.6 + fres * 1.4 + lines * 0.4) * flicker;
	ALPHA = clamp((0.25 + fres * 0.75 + lines * 0.15) * opacity, 0.0, 1.0);
}
