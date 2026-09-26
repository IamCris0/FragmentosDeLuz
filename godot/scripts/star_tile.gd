extends Area3D
## Fase 7: baldosa-estrella del Jardín de Constelaciones. Al pisarla avisa al nivel (stepped).

signal stepped(index: int)

@export var index: int = 0
@export var radius: float = 0.8
var lit: bool = false
var hinted: bool = false
var disc_material: StandardMaterial3D
var star: MeshInstance3D
var light: OmniLight3D
var time: float = 0.0


func _ready() -> void:
	add_to_group("star_tile")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	if not has_node("CollisionShape3D"):
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = 1.0
		shape.shape = cylinder
		shape.position.y = 0.5
		add_child(shape)
	disc_material = StandardMaterial3D.new()
	disc_material.albedo_color = Color("1c2340")
	disc_material.emission_enabled = true
	disc_material.emission = Color("ffd98a")
	disc_material.emission_energy_multiplier = 0.25
	disc_material.metallic = 0.4
	disc_material.roughness = 0.3
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = 0.05
	cylinder_mesh.radial_segments = 24
	disc.mesh = cylinder_mesh
	disc.material_override = disc_material
	disc.position.y = 0.03
	add_child(disc)
	star = MeshInstance3D.new()
	star.name = "Star"
	star.mesh = load("res://scripts/destello.gd").star_mesh(0.28, 0.08, 0.06)
	star.material_override = disc_material
	star.position.y = 0.12
	star.rotation.x = -PI * 0.5
	add_child(star)
	light = OmniLight3D.new()
	light.light_color = Color("ffd98a")
	light.light_energy = 0.0
	light.omni_range = 3.0
	light.position.y = 0.6
	add_child(light)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"): stepped.emit(index)


func set_lit(value: bool) -> void:
	lit = value
	if lit: hinted = false


func _process(delta: float) -> void:
	time += delta
	var target := 3.2 if lit else (1.2 + sin(time * 4.0) * 0.9 if hinted else 0.25)
	disc_material.emission_energy_multiplier = lerpf(disc_material.emission_energy_multiplier, target, 1.0 - exp(-delta * 8.0))
	light.light_energy = lerpf(light.light_energy, 1.8 if lit else (0.6 if hinted else 0.0), 1.0 - exp(-delta * 6.0))
	star.position.y = 0.12 + (0.35 + sin(time * 2.0 + index) * 0.08 if lit else 0.0)
	star.rotation.y += delta * (1.5 if lit else 0.2)
