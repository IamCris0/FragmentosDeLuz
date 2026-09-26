shader_type sky;
// Fase 7: cielo procedural del archipiélago. Degradado, sol o luna con halo, nubes altas, estrellas,
// nebulosa y aurora. Cada isla ajusta sus colores (noche en las Grutas y el Observatorio, amanecer
// ventoso en el Céfiro).

uniform vec4 zenith_color : source_color = vec4(0.05, 0.06, 0.16, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.35, 0.25, 0.45, 1.0);
uniform vec4 ground_color : source_color = vec4(0.12, 0.1, 0.2, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.9, 0.75, 1.0);
uniform vec3 sun_dir = vec3(0.3, 0.25, -0.9);
uniform float sun_size = 0.03;
uniform float sun_glow = 0.35;
uniform float star_amount = 1.0;
uniform float cloud_amount = 0.3;
uniform vec4 cloud_color : source_color = vec4(0.8, 0.7, 0.9, 1.0);
uniform float aurora_amount = 0.0;
uniform vec4 aurora_a : source_color = vec4(0.3, 1.0, 0.8, 1.0);
uniform vec4 aurora_b : source_color = vec4(0.6, 0.4, 1.0, 1.0);
uniform float nebula_amount = 0.0;
uniform vec4 nebula_color : source_color = vec4(0.5, 0.3, 0.8, 1.0);
uniform float horizon_sharpness = 3.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), u.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 7.1; a *= 0.5; }
	return v;
}

float stars(vec3 dir, float scale, float threshold) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 local = fract(p) - 0.5;
	float h = hash(cell);
	if (h < threshold) return 0.0;
	vec3 offset = vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 1.3)) - 0.5;
	float d = length(local - offset * 0.6);
	float twinkle = 0.65 + 0.35 * sin(TIME * (0.8 + h * 3.0) + h * 30.0);
	return smoothstep(0.1, 0.0, d) * twinkle * (h - threshold) / (1.0 - threshold);
}

void sky() {
	vec3 dir = EYEDIR;
	if (AT_CUBEMAP_PASS) {
		// Iluminación ambiental: solo el degradado y el sol (barato para el mapa de radiancia).
		vec3 base = mix(horizon_color.rgb, zenith_color.rgb, clamp(dir.y, 0.0, 1.0));
		base = mix(base, ground_color.rgb, smoothstep(0.0, -0.25, dir.y));
		COLOR = base + sun_color.rgb * pow(max(dot(dir, normalize(sun_dir)), 0.0), 12.0) * sun_glow;
	} else {
	float up = dir.y;
	vec3 color = mix(horizon_color.rgb, zenith_color.rgb, pow(clamp(up, 0.0, 1.0), 1.0 / horizon_sharpness * 1.6));
	color = mix(color, ground_color.rgb, smoothstep(0.0, -0.25, up));
	vec3 sdir = normalize(sun_dir);
	float sun_dot = dot(dir, sdir);
	float disc = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.8, sun_dot);
	float halo = pow(max(sun_dot, 0.0), 12.0) * sun_glow + pow(max(sun_dot, 0.0), 180.0) * sun_glow * 2.0;
	color += sun_color.rgb * (disc * 2.5 + halo);
	if (up > -0.05) {
		vec2 sky_uv = dir.xz / (up + 0.25);
		float n = fbm(sky_uv * 1.3 + vec2(TIME * 0.004, TIME * 0.002));
		float neb = fbm(sky_uv * 0.7 - vec2(TIME * 0.002, 0.0) + 11.0);
		color += nebula_color.rgb * smoothstep(0.45, 0.85, neb) * nebula_amount * smoothstep(0.0, 0.4, up);
		float s = stars(dir, 90.0, 0.93) + stars(dir, 210.0, 0.95) * 0.7;
		color += vec3(s) * star_amount * smoothstep(0.0, 0.3, up) * (1.0 - smoothstep(0.4, 0.8, n * cloud_amount * 2.0));
		float clouds = smoothstep(0.5, 0.85, n) * cloud_amount * smoothstep(-0.02, 0.2, up);
		color = mix(color, cloud_color.rgb * (0.8 + 0.4 * halo), clouds);
		if (aurora_amount > 0.0) {
			float band = sin(dir.x * 4.0 + fbm(vec2(dir.x * 2.0, TIME * 0.05)) * 4.0 + TIME * 0.1);
			float curtain = smoothstep(0.05, 0.25, up) * smoothstep(0.65, 0.3, up);
			float waves = pow(fbm(vec2(dir.x * 6.0 + TIME * 0.05, up * 3.0)), 2.0);
			vec3 aur = mix(aurora_a.rgb, aurora_b.rgb, smoothstep(0.1, 0.6, up));
			color += aur * curtain * waves * (0.5 + 0.5 * band) * aurora_amount * 1.6;
		}
	}
	COLOR = color;
	}
}
