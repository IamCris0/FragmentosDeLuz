extends RefCounted
## Sustituye en ejecución los materiales «Meshy_*» de los .glb (source_tools/build_meshy_*.py) por
## shaders/meshy_prop.gdshader: conserva la textura pintada, da luz propia a runas, cristales y ojos
## y mece la copa de los árboles. Los enemigos piden un material propio (`unique`) para poder
## variar su brillo sin afectar a los demás.

const SHADER := "res://shaders/meshy_prop.gdshader"
## Ajustes por modelo: brillo y balanceo. Las hojas son verdes saturadas: sin brillo.
const TUNING := {
	"Meshy_tree": {"glow": 0.0, "sway": 0.05},
	"Meshy_boulder": {"glow": 1.2},
	"Meshy_fern": {"glow": 0.0, "sway": 0.035, "sway_from": 0.03, "sway_to": 0.55},
	"Meshy_sanctuary_lantern": {"glow": 1.8},
}

static var cache: Dictionary = {}


## Devuelve los materiales creados (uno por superficie Meshy encontrada bajo `root`).
static func apply(root: Node, unique: bool = false) -> Array[ShaderMaterial]:
	var made: Array[ShaderMaterial] = []
	if root == null: return made
	var pieces: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: pieces.append(root)
	for piece: MeshInstance3D in pieces:
		if not piece.mesh: continue
		for i in piece.mesh.get_surface_count():
			var old := piece.mesh.surface_get_material(i) as StandardMaterial3D
			if not old or not old.resource_name.begins_with("Meshy_"): continue
			# An environment pass must not replace an enemy's animated material.
			var current := piece.get_surface_override_material(i)
			var material := current as ShaderMaterial
			if current and (not material or not material.shader or material.shader.resource_path != SHADER): continue
			if material and unique and material.get_meta("meshy_owner", 0) != root.get_instance_id():
				material = material.duplicate() as ShaderMaterial
			if not material and not unique:
				# Resource identity also distinguishes textures with the same material name.
				material = cache.get(old.get_instance_id())
			if material == null:
				material = ShaderMaterial.new()
				material.shader = load(SHADER)
				material.set_shader_parameter("albedo_tex", old.albedo_texture)
				# Explicit values are readable even before the renderer compiles the shader.
				material.set_shader_parameter("glow", 1.6)
				material.set_shader_parameter("glow_boost", 1.0)
				material.set_shader_parameter("sway", 0.0)
				material.set_shader_parameter("roughness_value", old.roughness)
				material.set_shader_parameter("metallic_value", old.metallic)
				for channel in ["normal", "roughness", "metallic"]:
					var texture: Texture2D = old.get(channel + "_texture")
					material.set_shader_parameter("has_" + channel, texture != null)
					if texture: material.set_shader_parameter(channel + "_tex", texture)
				for channel in ["roughness", "metallic"]:
					var mask := Vector4.ZERO
					var index: int = old.get(channel + "_texture_channel")
					if index < 4: mask[index] = 1.0
					else: mask = Vector4(0.3333, 0.3333, 0.3333, 0.0)
					material.set_shader_parameter(channel + "_channel", mask)
				var tuning: Dictionary = TUNING.get(old.resource_name, {})
				for key in tuning: material.set_shader_parameter(key, tuning[key])
				if not unique: cache[old.get_instance_id()] = material
			if unique: material.set_meta("meshy_owner", root.get_instance_id())
			piece.set_surface_override_material(i, material)
			made.append(material)
	return made
