shader_type spatial;
// Modelos pintados de Meshy: textura de color, luz propia en las zonas saturadas y brillantes
// (runas, cristales, ojos) y balanceo opcional de la copa de los árboles.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float glow = 1.6;
uniform float glow_boost = 1.0;
uniform vec3 flash : source_color = vec3(0.0);
uniform float sway = 0.0;
uniform float sway_from = 1.4;
uniform float sway_to = 4.0;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D metallic_tex : filter_linear_mipmap_anisotropic;
uniform bool has_normal = false;
uniform bool has_roughness = false;
uniform bool has_metallic = false;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);

void vertex() {
	if (sway > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float weight = smoothstep(sway_from, sway_to, VERTEX.y);
		float gust = sin(TIME * 1.15 + world.x * 0.4 + world.z * 0.3) + 0.35 * sin(TIME * 2.3 + world.z);
		VERTEX.x += gust * weight * sway;
		VERTEX.z += cos(TIME * 0.8 + world.x * 0.7) * weight * sway * 0.4;
	}
}

void fragment() {
	vec3 color = texture(albedo_tex, UV).rgb;
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float mask = smoothstep(0.22, 0.5, high - low) * smoothstep(0.4, 0.75, high);
	ALBEDO = color;
	ROUGHNESS = roughness_value * (has_roughness ? dot(texture(roughness_tex, UV), roughness_channel) : 1.0);
	METALLIC = metallic_value * (has_metallic ? dot(texture(metallic_tex, UV), metallic_channel) : 1.0);
	if (has_normal) NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = color * mask * glow * glow_boost + flash;
}
