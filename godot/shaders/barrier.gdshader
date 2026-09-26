shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// fade = 1: barrera completa. Al bajar hasta 0 se disuelve de abajo hacia arriba con un borde dorado.
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// Fase 7: color configurable (por defecto, el turquesa del jardín).
uniform vec3 tint = vec3(.1, .65, .68);
uniform vec3 glow = vec3(.2, .8, .8);

void fragment() {
	float line = pow(sin(UV.y*65.0+TIME)*.5+.5,18.0);
	float cut = (1.0 - UV.y) - (1.0 - fade) * 1.15;
	if (cut < 0.0) discard;
	float dissolving = step(fade, 0.999);
	float edge = (1.0 - smoothstep(0.0, 0.08, cut)) * dissolving;
	ALBEDO=tint;
	EMISSION=glow*(.3+line) + vec3(1.0,.85,.45)*edge*2.5;
	ALPHA=(.16+line*.25)*mix(.35,1.,fade) + edge*.6;
}
