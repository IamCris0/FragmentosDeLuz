extends StaticBody3D
## Fase 7: pilar estelar de la cúpula. Cuando se carga (charge()) puede encenderse con E: dispara un
## rayo que rompe el escudo del Heraldo del Eclipse.

signal fired(pillar: Node)

@export var prompt: String = "Encender el pilar estelar"
var state: String = "dormant"
var gem: Node3D
var gem_material: StandardMaterial3D
var light: OmniLight3D
var time: float = 0.0
var beam: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("star_pillar")
	gem = find_child("PillarGem", true, false) as Node3D
	gem_material = StandardMaterial3D.new()
	gem_material.albedo_color = Color("fff4d6")
	gem_material.emission_enabled = true
	gem_material.emission = Color("ffd98a")
	gem_material.emission_energy_multiplier = 0.2
	if gem:
		var meshes: Array = gem.find_children("*", "MeshInstance3D", true, false)
		if gem is MeshInstance3D: meshes.append(gem)
		for mesh in meshes: (mesh as MeshInstance3D).material_override = gem_material
	light = OmniLight3D.new()
	light.name = "PillarLight"
	light.light_color = Color("ffd98a")
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.position.y = 3.6
	add_child(light)


func available() -> bool:
	return state == "charged"


func current_prompt() -> String:
	return prompt


func charge() -> void:
	if state == "charged": return
	state = "charged"
	GameEvents.sound_requested.emit("pillar_charge")


func reset() -> void:
	state = "dormant"


func spend() -> void:
	state = "used"


func interact(_player: Node3D) -> void:
	if state != "charged": return
	state = "fired"
	GameEvents.sound_requested.emit("beam_on")
	fired.emit(self)


func gem_position() -> Vector3:
	return (gem.global_position if gem else global_position + Vector3.UP * 3.55)


## Rayo visual desde la gema hasta un punto (el núcleo del Heraldo).
func shoot(target: Vector3, duration: float = 1.2) -> void:
	if beam: beam.queue_free()
	beam = MeshInstance3D.new()
	beam.name = "PillarBeam"
	var tube := CylinderMesh.new()
	tube.top_radius = 0.16
	tube.bottom_radius = 0.16
	tube.height = 1.0
	tube.cap_top = false
	tube.cap_bottom = false
	beam.mesh = tube
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/light_beam.gdshader")
	material.set_shader_parameter("beam_color", Color(1.0, 0.85, 0.5))
	material.set_shader_parameter("intensity", 1.6)
	beam.material_override = material
	beam.top_level = true
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var a := gem_position()
	var basis := Basis.looking_at(target - a, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	basis = Basis(basis.x, basis.y * a.distance_to(target), basis.z)
	beam.global_transform = Transform3D(basis, (a + target) * 0.5)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(beam.queue_free)


func _process(delta: float) -> void:
	time += delta
	var target := 0.2
	match state:
		"charged": target = 3.0 + sin(time * 5.0) * 1.2
		"fired": target = 4.5
		"used": target = 1.2
	gem_material.emission_energy_multiplier = lerpf(gem_material.emission_energy_multiplier, target, 1.0 - exp(-delta * 6.0))
	light.light_energy = lerpf(light.light_energy, (2.5 if state == "charged" else (1.0 if state == "used" else 0.0)), 1.0 - exp(-delta * 4.0))
	if gem: gem.rotation.y += delta * (2.5 if state == "charged" else 0.4)
