extends "res://scripts/enemy_sentinel.gd"
## Fase 7: Vigía. Eco flotante que mantiene la distancia y dispara orbes de sombra.
## Q cerca de él lo aturde y deshace los orbes; la rodada permite atravesarlos.

const Orb = preload("res://scripts/light_orb.gd")
@export var shot_range: float = 8.5
@export var volley: int = 1
var eye_material: StandardMaterial3D
var ring_a: Node3D
var ring_b: Node3D
var eye: Node3D


func _ready() -> void:
	super._ready()
	if purified: return
	add_to_group("vigia")
	detection_radius = 11.0
	chase_speed = 1.6
	speed = 0.9
	var ring := warning_ring.mesh as TorusMesh
	ring.inner_radius = 0.62
	ring.outer_radius = 0.68
	warning_ring.position.y = 1.3
	warning_ring.rotation.x = PI * 0.5
	for mark in health_marks: mark.position.y = 2.1
	if visual:
		ring_a = visual.find_child("VigiaRingA", true, false) as Node3D
		ring_b = visual.find_child("VigiaRingB", true, false) as Node3D
		eye = visual.find_child("VigiaEye", true, false) as Node3D
		var eye_mesh := eye as MeshInstance3D
		if eye_mesh and eye_mesh.mesh:
			var source := eye_mesh.mesh.surface_get_material(0) as StandardMaterial3D
			if source:
				eye_material = source.duplicate() as StandardMaterial3D
				eye_mesh.set_surface_override_material(0, eye_material)
	if core_light: core_light.position.y = 1.3


func has_sight() -> bool:
	if not is_instance_valid(player) or absf(player.global_position.y - global_position.y) > 3.5:
		return false
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, player.global_position + Vector3.UP * 0.9, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _attack_range() -> float:
	return shot_range


func _windup_duration() -> float:
	return 0.95 if health >= 2 else 0.75


func _on_windup() -> void:
	GameEvents.sound_requested.emit("vigia_charge")


func _resolve_attack(active: bool, _distance: float) -> void:
	attack_time = 2.1
	if not active or not is_instance_valid(player): return
	GameEvents.sound_requested.emit("vigia_shot")
	var origin := global_position + Vector3.UP * 1.3
	var aim := (player.global_position + Vector3.UP * 0.95 - origin).normalized()
	var shots := volley if health >= 2 else volley + 1
	for i in shots:
		var orb := Orb.new()
		orb.damage_enabled = damage_enabled
		get_tree().current_scene.add_child(orb)
		var spread := (i - (shots - 1) * 0.5) * 0.28
		orb.launch(origin + aim * 0.45, aim.rotated(Vector3.UP, spread))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if purified or not is_instance_valid(player) or not visual: return
	var flat := player.global_position - global_position
	flat.y = 0.0
	if (mode == Mode.CHASE or mode == Mode.RECOVERY) and flat.length() < 3.6 and flat.length() > 0.05:
		_move_towards(global_position - flat.normalized() * 2.0, speed * 1.3 * delta)
	if mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVERY] and flat.length() > 0.1:
		look_at(global_position + flat.normalized(), Vector3.UP)
	# El modelo mira hacia +Z: se gira para que el ojo apunte a -Z (hacia donde mira el eco).
	visual.rotation.y = PI
	visual.position.y = sin(phase * 1.8) * 0.12
	if ring_a: ring_a.rotation.y += delta * (5.0 if mode == Mode.WINDUP else 1.2)
	if ring_b: ring_b.rotation.x += delta * (4.0 if mode == Mode.WINDUP else 0.8)
	if eye_material:
		eye_material.emission_energy_multiplier = 7.0 if mode == Mode.WINDUP else (0.6 if mode == Mode.STUNNED else 3.0)
