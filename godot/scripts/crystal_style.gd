extends RefCounted
## Fase 7: sustituye en tiempo de ejecución los materiales importados de los modelos del capítulo II
## por shaders propios: cristal facetado (shaders/crystal.gdshader) y proyección luminosa
## (shaders/ghost.gdshader). Así los .glb siguen siendo simples y editables y las escenas no
## necesitan «Editable Children».

const PALETTES := {
	"violet": [Color(0.66, 0.54, 1.0), Color(0.55, 0.36, 1.0), Color(0.92, 0.86, 1.0), 1.5],
	"teal": [Color(0.55, 0.95, 0.9), Color(0.25, 0.8, 0.74), Color(0.85, 1.0, 0.97), 1.3],
	"star": [Color(0.78, 0.84, 1.0), Color(0.55, 0.65, 1.0), Color(1.0, 0.95, 0.8), 1.4],
	"gold": [Color(1.0, 0.86, 0.55), Color(1.0, 0.7, 0.3), Color(1.0, 0.95, 0.8), 1.6],
	"echo": [Color(0.55, 0.45, 0.9), Color(0.5, 0.35, 0.9), Color(0.8, 0.7, 1.0), 1.4],
}

## Tonos de roca (cliff.gdshader): cima, fondo, musgo y vetas.
const ROCKS := {
	"violet": [Color(0.52, 0.47, 0.7), Color(0.25, 0.21, 0.36), Color(0.46, 0.37, 0.72), Color(0.78, 0.58, 1.0)],
	"teal": [Color(0.7, 0.66, 0.58), Color(0.36, 0.38, 0.42), Color(0.3, 0.5, 0.36), Color(0.4, 0.9, 0.82)],
	"star": [Color(0.5, 0.52, 0.66), Color(0.2, 0.22, 0.34), Color(0.3, 0.34, 0.55), Color(0.95, 0.85, 0.55)],
}

static var cache: Dictionary = {}


static func rock_material(palette: String) -> ShaderMaterial:
	var key := "rock_" + palette
	if cache.has(key): return cache[key]
	var tones: Array = ROCKS.get(palette, ROCKS["violet"])
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/cliff.gdshader")
	material.set_shader_parameter("stone", load("res://assets/environment/stone_painted.png"))
	material.set_shader_parameter("top_tint", Vector3(tones[0].r, tones[0].g, tones[0].b))
	material.set_shader_parameter("deep_tint", Vector3(tones[1].r, tones[1].g, tones[1].b))
	material.set_shader_parameter("moss_tint", Vector3(tones[2].r, tones[2].g, tones[2].b))
	material.set_shader_parameter("vein_color", Vector3(tones[3].r, tones[3].g, tones[3].b))
	material.set_shader_parameter("top_y", 7.0)
	material.set_shader_parameter("depth", 14.0)
	material.set_shader_parameter("scale", 0.3)
	cache[key] = material
	return material


static func crystal_material(palette: String) -> ShaderMaterial:
	if cache.has(palette): return cache[palette]
	var colors: Array = PALETTES.get(palette, PALETTES["violet"])
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/crystal.gdshader")
	material.set_shader_parameter("base_color", colors[0])
	material.set_shader_parameter("glow_color", colors[1])
	material.set_shader_parameter("rim_color", colors[2])
	material.set_shader_parameter("glow_strength", colors[3])
	cache[palette] = material
	return material


## Material propio (no compartido) para piezas que cambian de estado (receptores, pilares).
static func unique_crystal(palette: String) -> ShaderMaterial:
	return crystal_material(palette).duplicate() as ShaderMaterial


static func ghost_material(tint: Color = Color(0.72, 0.9, 1.0)) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/ghost.gdshader")
	material.set_shader_parameter("tint", tint)
	return material


## Recorre root y sustituye materiales por nombre. Devuelve cuántas superficies cambió.
static func apply(root: Node, palette: String = "violet") -> int:
	var changed := 0
	var ghost: ShaderMaterial
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if not mesh_node.mesh or mesh_node.material_override: continue
		for i in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(i)
			if not source: continue
			var title := source.resource_name
			if title.begins_with("Crystal"):
				var chosen := palette
				if title == "Crystal_Teal": chosen = "teal"
				elif title == "Crystal_Echo": chosen = "echo"
				mesh_node.set_surface_override_material(i, crystal_material(chosen))
				changed += 1
			elif title.begins_with("Cave_Stone"):
				mesh_node.set_surface_override_material(i, rock_material(palette if ROCKS.has(palette) else "violet"))
				changed += 1
			elif title == "Maren_Light":
				if not ghost: ghost = ghost_material()
				mesh_node.set_surface_override_material(i, ghost)
				changed += 1
	return changed
