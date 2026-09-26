shader_type spatial;
// Fase 7: mar de nubes bajo el archipiélago. Relieve de nubes con ruido fractal, luz falsa del sol,
// borde luminoso y desvanecimiento en la distancia para fundirse con el cielo.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 top_color : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform vec4 shade_color : source_color = vec4(0.55, 0.52, 0.72, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.95, 0.75, 0.7, 1.0);
uniform vec3 sun_direction = vec3(0.4, 0.6, -0.5);
uniform float scale = 0.018;
uniform float speed = 0.012;
uniform float fade_distance = 260.0;
uniform float height = 3.0;

varying vec3 world_pos;
varying float puff;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.07 + 17.3; a *= 0.5; }
	return v;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = w.xz * scale + vec2(TIME * speed, TIME * speed * 0.6);
	puff = fbm(p);
	VERTEX.y += pow(puff, 1.6) * height * 2.0;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale + vec2(TIME * speed, TIME * speed * 0.6);
	float e = 0.6;
	float hx = fbm(p + vec2(e * scale * 30.0, 0.0)) - fbm(p - vec2(e * scale * 30.0, 0.0));
	float hz = fbm(p + vec2(0.0, e * scale * 30.0)) - fbm(p - vec2(0.0, e * scale * 30.0));
	vec3 n = normalize(vec3(-hx * 4.0, 1.0, -hz * 4.0));
	float light = clamp(dot(n, normalize(sun_direction)) * 0.7 + 0.45, 0.0, 1.0);
	float detail = fbm(p * 3.3 + 2.0);
	float billow = 1.0 - abs(fbm(p * 1.7 + 9.0) * 2.0 - 1.0);
	float body = smoothstep(0.3, 0.8, puff * 0.6 + billow * 0.3 + detail * 0.15);
	vec3 color = mix(shade_color.rgb, top_color.rgb, clamp(body * 0.6 + light * 0.55, 0.0, 1.0));
	color += top_color.rgb * pow(billow, 6.0) * 0.25 * light;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	color = mix(color, horizon_color.rgb, smoothstep(fade_distance * 0.45, fade_distance, dist));
	ALBEDO = color;
}
