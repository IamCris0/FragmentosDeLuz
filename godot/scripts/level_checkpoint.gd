extends Area3D
## Fase 7: refugio de una isla. Al cruzarlo se guarda el punto de control y se enciende su farol.

signal reached(index: int)

@export var index: int = 0
@export var size: Vector3 = Vector3(8, 4, 2)
## Posición local del farol (la zona de detección cubre el camino).
@export var lantern_offset: Vector3 = Vector3(3.2, 0, 0)
@export var flame_color: Color = Color("ffd08a")

var lit: bool = false
var flame_material: StandardMaterial3D
var light: OmniLight3D
var time: float = 0.0


func _ready() -> void:
	add_to_group("level_checkpoint")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	if not has_node("CollisionShape3D"):
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position.y = size.y * 0.5
		add_child(shape)
	body_entered.connect(_on_body_entered)
	_build_lantern()


func _build_lantern() -> void:
	var lantern := Node3D.new()
	lantern.name = "RefugeLantern"
	lantern.position = lantern_offset
	add_child(lantern)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("5d6f73")
	stone.roughness = 0.9
	var post := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.12
	column.bottom_radius = 0.2
	column.height = 1.5
	column.radial_segments = 8
	post.mesh = column
	post.material_override = stone
	post.position.y = 0.75
	lantern.add_child(post)
	var cage := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.27
	ring.rings = 20
	ring.ring_segments = 6
	cage.mesh = ring
	cage.material_override = stone
	cage.position.y = 1.72
	cage.rotation.x = PI * 0.5
	lantern.add_child(cage)
	flame_material = StandardMaterial3D.new()
	flame_material.albedo_color = Color(0.35, 0.4, 0.45)
	flame_material.emission_enabled = true
	flame_material.emission = flame_color
	flame_material.emission_energy_multiplier = 0.15
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var gem := SphereMesh.new()
	gem.radius = 0.16
	gem.height = 0.42
	gem.radial_segments = 6
	gem.rings = 3
	flame.mesh = gem
	flame.material_override = flame_material
	flame.position.y = 1.72
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern.add_child(flame)
	light = OmniLight3D.new()
	light.name = "RefugeLight"
	light.light_color = flame_color
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.position.y = 1.8
	lantern.add_child(light)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	if not lit: light_up(true)
	reached.emit(index)


func light_up(animate: bool = true) -> void:
	lit = true
	if not flame_material: return
	if not animate:
		flame_material.albedo_color = Color(1, 0.95, 0.85)
		flame_material.emission_energy_multiplier = 2.4
		light.light_energy = 1.5
		return
	GameEvents.sound_requested.emit("beacon_chime")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flame_material, "emission_energy_multiplier", 2.4, 0.8)
	tween.tween_property(flame_material, "albedo_color", Color(1, 0.95, 0.85), 0.8)
	tween.tween_property(light, "light_energy", 1.5, 0.8)


func _process(delta: float) -> void:
	if not lit or not light: return
	time += delta
	light.light_energy = 1.5 + sin(time * 2.3) * 0.08 + sin(time * 5.1) * 0.05
