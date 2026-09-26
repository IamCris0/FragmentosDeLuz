@tool
extends Node3D
## Fase 6: viste la parte inferior de cada isla como en la ilustración de referencia:
## raíces de cristal que cuelgan, un cristal-ancla en la punta y enredaderas que se mecen.
## Es determinista (semilla por zona) y se genera al cargar, en el juego, el menú y el editor.

@export var extent: Vector2 = Vector2(24, 22)
@export var dressing_seed: int = 7
@export var crystal_count: int = 10
@export var vine_count: int = 28
## Fase 7: colores de los cristales colgantes (las islas del archipiélago usan otros tonos).
@export var crystal_color: Color = Color("7ff5e6")
@export var glow_color: Color = Color("4ecdc4")
## Fase 7: tonos del acantilado (valores por defecto = los de Auralia).
@export var cliff_top: Color = Color(0.72, 0.58, 0.45)
@export var cliff_deep: Color = Color(0.36, 0.32, 0.38)
@export var cliff_moss: Color = Color(0.24, 0.42, 0.27)
@export var cliff_vein: Color = Color(0.31, 0.85, 0.80)

const CRYSTAL := "res://assets/props/crystal_energy.glb"
var built: bool = false


func _ready() -> void:
	if built:
		return
	built = true
	var rng := RandomNumberGenerator.new()
	rng.seed = dressing_seed
	var sx := extent.x / 9.0
	var sz := extent.y / 9.0
	var crystal: PackedScene = load(CRYSTAL) if ResourceLoader.exists(CRYSTAL) else null
	var glow := StandardMaterial3D.new()
	glow.albedo_color = crystal_color
	glow.emission_enabled = true
	glow.emission = glow_color
	glow.emission_energy_multiplier = 1.8
	glow.roughness = 0.15
	if crystal:
		# Raíces de cristal bajo el saliente intermedio de la roca (r ≈ 3,0–3,9 de 4,9; y ≈ -2,75).
		for i in crystal_count:
			var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / crystal_count
			var radius := rng.randf_range(3.0, 3.8)
			var point := Vector3(cos(angle) * radius * sx, -2.75 * 1.5 - 0.25, sin(angle) * radius * sz)
			_hang_crystal(crystal, point, rng.randf_range(3.2, 6.0), rng, glow)
			_hang_crystal(crystal, point + Vector3(rng.randf_range(-0.6, 0.6), 0.1, rng.randf_range(-0.6, 0.6)), rng.randf_range(1.8, 3.2), rng, glow)
			if i % 2 == 0:
				var rim := Vector3(cos(angle + 0.3) * 4.55 * sx, -0.85, sin(angle + 0.3) * 4.55 * sz)
				_hang_crystal(crystal, rim, rng.randf_range(1.8, 3.0), rng, glow)
		var anchor := _hang_crystal(crystal, Vector3(0, -7.4, 0), 8.0, rng, glow)
		anchor.rotation = Vector3(PI, rng.randf() * TAU, 0)
		for k in 4:
			var side := _hang_crystal(crystal, Vector3(cos(k * 1.6) * 1.1, -7.0, sin(k * 1.6) * 1.1), 4.5, rng, glow)
			side.rotation = Vector3(PI - 0.5, k * 1.6, 0)
		var light := OmniLight3D.new()
		light.name = "RootGlow"
		light.light_color = glow_color
		light.light_energy = 1.6
		light.omni_range = 9.0
		light.position = Vector3(0, -7.0, 0)
		add_child(light)
	_dress_cliff()
	var vine_material := ShaderMaterial.new()
	vine_material.shader = load("res://shaders/vine.gdshader")
	for i in vine_count:
		var angle := TAU * i / vine_count + rng.randf_range(-0.12, 0.12)
		var radius := rng.randf_range(4.55, 4.85)
		var point := Vector3(cos(angle) * radius * sx, -0.25, sin(angle) * radius * sz)
		var vine := MeshInstance3D.new()
		vine.name = "Vine%d" % i
		var strip := QuadMesh.new()
		var length := rng.randf_range(1.8, 5.2)
		strip.size = Vector2(rng.randf_range(0.5, 0.85), length)
		strip.subdivide_depth = 8
		strip.center_offset = Vector3(0, -length * 0.5, 0)
		vine.mesh = strip
		vine.material_override = vine_material
		vine.position = point
		vine.rotation.y = -angle + PI * 0.5
		vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vine.set_instance_shader_parameter("phase", rng.randf() * TAU)
		add_child(vine)


func _hang_crystal(scene: PackedScene, point: Vector3, size: float, rng: RandomNumberGenerator, material: Material) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = "HangingCrystal"
	node.position = point
	node.rotation = Vector3(PI + rng.randf_range(-0.28, 0.28), rng.randf() * TAU, rng.randf_range(-0.28, 0.28))
	node.scale = Vector3.ONE * size
	add_child(node)
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Aplica el material de acantilado a la roca de la isla hermana (IslandCliff) y a sus rocas sueltas.
func _dress_cliff() -> void:
	var zone := get_parent()
	if not zone: return
	var material := cliff_material(zone.global_position.y if is_inside_tree() else 0.0, 8.0)
	material.set_shader_parameter("top_tint", Vector3(cliff_top.r, cliff_top.g, cliff_top.b))
	material.set_shader_parameter("deep_tint", Vector3(cliff_deep.r, cliff_deep.g, cliff_deep.b))
	material.set_shader_parameter("moss_tint", Vector3(cliff_moss.r, cliff_moss.g, cliff_moss.b))
	material.set_shader_parameter("vein_color", Vector3(cliff_vein.r, cliff_vein.g, cliff_vein.b))
	for child in zone.get_children():
		if child is Node3D and child.scene_file_path.ends_with("island_rock.glb"):
			for mesh in child.find_children("*", "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).material_override = material


static func cliff_material(top: float, depth: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/cliff.gdshader")
	material.set_shader_parameter("stone", load("res://assets/environment/stone_painted.png"))
	material.set_shader_parameter("top_y", top)
	material.set_shader_parameter("depth", depth)
	return material
