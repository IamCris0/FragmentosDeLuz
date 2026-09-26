extends Node3D
## Fase 7: orbe de sombra disparado por los Vigías (y el Heraldo). Persigue con suavidad,
## choca contra muros, se deshace con un pulso de luz y atraviesa a Neri si esquiva a tiempo.

var velocity: Vector3 = Vector3.FORWARD
var speed: float = 5.2
var life: float = 4.5
var damage: float = 16.0
var homing: float = 0.9
var damage_enabled: bool = true
var reason: String = "Un orbe del vigía alcanzó tu luz"
var player: CharacterBody3D
var grazed: bool = false
var core_material: StandardMaterial3D
var light: OmniLight3D
var popped: bool = false
var time: float = 0.0


func _ready() -> void:
	add_to_group("enemy_orb")
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	core_material = StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color("ffb36b")
	var core := MeshInstance3D.new()
	core.name = "Core"
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 12
	sphere.rings = 6
	core.mesh = sphere
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	var outer := SphereMesh.new()
	outer.radius = 0.3
	outer.height = 0.6
	outer.radial_segments = 12
	outer.rings = 6
	shell.mesh = outer
	var shell_material := StandardMaterial3D.new()
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shell_material.albedo_color = Color(0.55, 0.3, 0.95, 0.45)
	shell.material_override = shell_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	light = OmniLight3D.new()
	light.light_color = Color("ff9a5a")
	light.light_energy = 1.4
	light.omni_range = 2.6
	add_child(light)
	GameEvents.pulse_requested.connect(_on_pulse)


func launch(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	velocity = direction.normalized() * speed


func _physics_process(delta: float) -> void:
	if popped: return
	time += delta
	life -= delta
	if not is_instance_valid(player) or player.locked:
		pop(false)
		return
	if life <= 0.0:
		pop(false)
		return
	var target := player.global_position + Vector3.UP * 0.95
	if not grazed and homing > 0.0:
		var desired := (target - global_position).normalized()
		velocity = velocity.normalized().slerp(desired, clampf(homing * delta, 0.0, 1.0)).normalized() * speed
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		pop(true)
		return
	global_position = next
	scale = Vector3.ONE * (1.0 + sin(time * 14.0) * 0.08)
	if global_position.distance_to(target) < 0.62 and not grazed:
		if damage_enabled and GameEvents.damage_player(damage, reason):
			GameEvents.sound_requested.emit("hit")
			pop(true)
		else:
			# Esquiva o inmunidad: el orbe sigue de largo y deja de perseguir.
			grazed = true


func _on_pulse(origin: Vector3, radius: float, _force: float) -> void:
	var reach := radius * (1.35 if GameEvents.has_skill("pulse_daze") else 1.0) + 0.4
	if not popped and global_position.distance_to(origin) <= reach:
		pop(true)


func pop(loud: bool) -> void:
	if popped: return
	popped = true
	if loud: GameEvents.sound_requested.emit("orb_pop")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 2.2, 0.18)
	tween.tween_property(core_material, "albedo_color:a", 0.0, 0.18)
	tween.tween_property(light, "light_energy", 0.0, 0.18)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tween.chain().tween_callback(queue_free)
