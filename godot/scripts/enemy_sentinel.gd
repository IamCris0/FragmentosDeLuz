extends Area3D

@export var patrol_radius: float = 2.7
@export var speed: float = 1.15
@export var chase_speed: float = 2.15
@export var detection_radius: float = 6.8
@export var attack_radius: float = 1.65
@export var damage: float = 24.0
@export var health: int = 2
@export var tutorial_enemy: bool = false

enum Mode { PATROL, CHASE, WINDUP, RECOVERY, STUNNED }
var mode: Mode = Mode.PATROL
var home: Vector3
var phase: float = 0.0
var stun_time: float = 0.0
var attack_time: float = 0.0
var purified: bool = false
var player: CharacterBody3D
var visual: Node3D
var core_light: OmniLight3D
var damage_enabled: bool = true
var alerted: bool = false
var windup_time: float = 0.0
var warning_ring: MeshInstance3D
var warning_material: StandardMaterial3D
var health_marks: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("enemy")
	home = global_position
	if GameEvents.purified_ids.has(str(name)):
		purified = true
		queue_free()
		return
	phase = randf() * TAU
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	visual = get_node_or_null("Visual")
	core_light = get_node_or_null("CoreLight") as OmniLight3D
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	damage_enabled = not ("--qa" in OS.get_cmdline_user_args()) or "--qa-polish" in OS.get_cmdline_user_args()
	GameEvents.pulse_requested.connect(apply_pulse)
	_build_indicators()
	if tutorial_enemy:
		damage = 16.0
		chase_speed = 1.6
	elif health >= 3:
		damage = 32.0
		chase_speed = 2.65


func _build_indicators() -> void:
	warning_material = StandardMaterial3D.new()
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_material.albedo_color = Color("ffc36c")
	warning_material.emission_enabled = true
	warning_material.emission = Color("ff994f")
	warning_material.emission_energy_multiplier = 1.8
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "AttackWarning"
	var torus := TorusMesh.new()
	torus.inner_radius = attack_radius - 0.055
	torus.outer_radius = attack_radius
	torus.rings = 48
	torus.ring_segments = 8
	warning_ring.mesh = torus
	warning_ring.material_override = warning_material
	warning_ring.position.y = 0.06
	warning_ring.hide()
	add_child(warning_ring)
	for i in health:
		var mark := MeshInstance3D.new()
		mark.name = "Integrity%d" % i
		var shape := SphereMesh.new()
		shape.radius = 0.055
		shape.height = 0.11
		shape.radial_segments = 8
		shape.rings = 4
		mark.mesh = shape
		mark.material_override = warning_material
		mark.position = Vector3((i - (health - 1) * 0.5) * 0.18, 1.85, 0)
		add_child(mark)
		health_marks.append(mark)


func has_sight() -> bool:
	if not is_instance_valid(player) or absf(player.global_position.y - global_position.y) > 1.7:
		return false
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.85, player.global_position + Vector3.UP * 0.85, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func is_threat() -> bool:
	return not purified and is_instance_valid(player) and not player.locked and mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVERY]


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if purified or not is_instance_valid(player):
		return
	if player.locked:
		windup_time = 0.0
		warning_ring.hide()
		mode = Mode.PATROL
		return
	phase += delta
	stun_time = maxf(stun_time - delta, 0.0)
	attack_time = maxf(attack_time - delta, 0.0)
	var to_player := player.global_position - global_position
	var flat := Vector3(to_player.x, 0, to_player.z)
	var player_from_home := player.global_position - home
	player_from_home.y = 0.0
	var active := flat.length() < detection_radius and player_from_home.length() <= patrol_radius + 5.0 and has_sight()
	if stun_time > 0.0:
		mode = Mode.STUNNED
	elif windup_time > 0.0:
		mode = Mode.WINDUP
		windup_time = maxf(windup_time - delta, 0.0)
		warning_ring.scale = Vector3.ONE * lerpf(0.35, 1.0, 1.0 - windup_time / _windup_duration())
		if windup_time <= 0.0:
			warning_ring.hide()
			attack_time = 1.35
			mode = Mode.RECOVERY
			_resolve_attack(active, flat.length())
	elif attack_time > 0.0:
		mode = Mode.RECOVERY
	elif active:
		mode = Mode.CHASE
		if not alerted:
			alerted = true
			GameEvents.sound_requested.emit("enemy_alert")
		if flat.length() <= _attack_range():
			mode = Mode.WINDUP
			windup_time = _windup_duration()
			warning_ring.show()
			_on_windup()
		else:
			_move_towards(player.global_position, chase_speed * delta)
	else:
		mode = Mode.PATROL
		alerted = false
		_move_towards(home + Vector3(cos(phase * 0.55), 0, sin(phase * 0.55)) * patrol_radius, speed * delta)
	if visual:
		visual.rotation.y += delta * (4.0 if mode == Mode.WINDUP else (0.2 if mode == Mode.STUNNED else 0.7))
		visual.position.y = sin(phase * 2.6) * 0.06
	if core_light:
		core_light.light_color = Color("ffc36c") if mode == Mode.WINDUP else (Color("75ffe1") if mode == Mode.STUNNED else Color("a18aee"))
		core_light.light_energy = (2.5 if mode == Mode.WINDUP else 1.1) + sin(phase * 5.0) * 0.15
	for i in health_marks.size():
		health_marks[i].visible = i < health and (active or mode == Mode.STUNNED)


func _windup_duration() -> float:
	return 1.15 if tutorial_enemy else (0.65 if health_marks.size() >= 3 else 0.85)


func _attack_range() -> float:
	return attack_radius


func _on_windup() -> void:
	pass


func _resolve_attack(active: bool, distance: float) -> void:
	if active and distance <= attack_radius and damage_enabled:
		if GameEvents.damage_player(damage, "El eco alcanzó tu luz"):
			GameEvents.sound_requested.emit("hit")


func _move_towards(target: Vector3, step: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		return
	var next := global_position + direction.normalized() * minf(step, direction.length())
	var floor_ray := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 1.0, next + Vector3.DOWN * 1.5, 1)
	var wall_ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, next + direction.normalized() * 0.4 + Vector3.UP * 0.8, 1)
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(floor_ray).is_empty() and space.intersect_ray(wall_ray).is_empty():
		global_position = next
		look_at(global_position + direction.normalized(), Vector3.UP)


func apply_pulse(origin: Vector3, radius: float, force: float) -> void:
	if purified or global_position.distance_to(origin) > radius:
		return
	var ray := PhysicsRayQueryParameters3D.create(origin, global_position + Vector3.UP * 0.85, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return
	# Fase 7: Destello cegador alarga el aturdimiento y la Nova resta dos puntos de integridad.
	stun_time = 1.7 * GameEvents.stun_multiplier()
	windup_time = 0.0
	attack_time = 0.0
	mode = Mode.STUNNED
	warning_ring.hide()
	health -= maxi(GameEvents.pulse_power, 1)
	var away := global_position - origin
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.FORWARD
	_move_towards(global_position + away.normalized() * force, force)
	GameEvents.sound_requested.emit("enemy_hit")
	GameEvents.toast_requested.emit("El eco pierde forma" if health > 0 else "Eco purificado")
	if tutorial_enemy and GameEvents.tutorial_stage < 3:
		GameEvents.set_tutorial(3, "Eco purificado. C permite rodar en la dirección de movimiento. Reserva energía para esquivar o usar Q.")
	if health <= 0:
		_purify()


func _purify() -> void:
	purified = true
	monitoring = false
	GameEvents.register_enemy_purified(name)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.04, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
