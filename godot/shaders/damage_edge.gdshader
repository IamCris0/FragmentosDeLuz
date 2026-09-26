shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 edge = abs(UV * 2.0 - 1.0);
	float rim = smoothstep(0.64, 1.0, max(edge.x, edge.y));
	COLOR = vec4(0.82, 0.24, 0.17, rim * strength);
}
