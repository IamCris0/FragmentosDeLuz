extends "res://scripts/enemy_sentinel.gd"

const Wave = preload("res://scripts/resonance_wave.gd")
var wave: Node3D
var last_status: Array = []


func _ready() -> void:
	super._ready()
	add_to_group("guardian")
	if purified: return
	detection_radius = 9.0
	var mesh := warning_ring.mesh as TorusMesh
	mesh.inner_radius = 6.35
	mesh.outer_radius = 6.5
	visual.scale = Vector3.ONE * 1.25
	for mark in health_marks: mark.position.y += 0.38


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(player): return
	if player.locked or purified or stun_time > 0.0: _clear_wave()
	var active := not purified and global_position.distance_to(player.global_position) < 12.0
	var caption := "NÚCLEO INESTABLE" if health == 1 else "ECO DEL FARO"
	if mode == Mode.WINDUP: caption = "CARGANDO RESONANCIA"
	elif is_instance_valid(wave): caption = "ONDA DE RESONANCIA"
	elif mode == Mode.STUNNED: caption = "RESONANCIA INTERRUMPIDA"
	var status := [active, health, caption]
	if status != last_status:
		last_status = status
		GameEvents.guardian_changed.emit(active, health, caption)


func _attack_range() -> float:
	return 5.0


func _windup_duration() -> float:
	return 1.35 if health >= 3 else (1.15 if health == 2 else 0.95)


func _on_windup() -> void:
	GameEvents.sound_requested.emit("guardian_charge")


func _resolve_attack(active: bool, _distance: float) -> void:
	attack_time = 2.2
	if not active: return
	_clear_wave()
	wave = Wave.new()
	wave.damage_enabled = damage_enabled
	wave.speed = 5.0 if health >= 3 else (6.0 if health == 2 else 7.0)
	wave.damage = 24.0 if health >= 2 else 30.0
	get_tree().current_scene.add_child(wave)
	wave.global_position = global_position
	GameEvents.sound_requested.emit("guardian_wave")


func apply_pulse(origin: Vector3, radius: float, force: float) -> void:
	var previous := health
	super.apply_pulse(origin, radius, force)
	if health < previous: _clear_wave()


func _clear_wave() -> void:
	if is_instance_valid(wave): wave.queue_free()
	wave = null


func _purify() -> void:
	_clear_wave()
	GameEvents.guardian_changed.emit(false, 0, "")
	super._purify()
