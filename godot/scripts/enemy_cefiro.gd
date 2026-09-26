extends "res://scripts/enemy_sentinel.gd"
## Fase 7: Céfiro. Espíritu de viento que marca una línea en el suelo y embiste por ella.
## Tras la embestida queda agotado unos instantes: es el momento de usar Q.

@export var dash_distance: float = 7.0
@export var dash_speed: float = 15.0
@export var knockback: float = 6.0
var dash_direction: Vector3 = Vector3.FORWARD
var dash_time: float = 0.0
var dash_hit: bool = false
var telegraph: MeshInstance3D
var telegraph_material: StandardMaterial3D
var wings: Array[Node3D] = []


func _ready() -> void:
	super._ready()
	if purified: return
	add_to_group("cefiro")
	detection_radius = 9.5
	chase_speed = 2.3
	damage = 22.0
	warning_ring.visible = false
	telegraph_material = StandardMaterial3D.new()
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.albedo_color = Color(0.6, 1.0, 0.9, 0.55)
	telegraph = MeshInstance3D.new()
	telegraph.name = "DashTelegraph"
	var strip := BoxMesh.new()
	strip.size = Vector3(0.9, 0.04, 1.0)
	telegraph.mesh = strip
	telegraph.material_override = telegraph_material
	telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	telegraph.top_level = true
	telegraph.hide()
	add_child(telegraph)
	if visual:
		for side in ["L", "R"]:
			var wing := visual.find_child("CefiroWing" + side, true, false) as Node3D
			if wing: wings.append(wing)


func _attack_range() -> float:
	return 5.8


func _windup_duration() -> float:
	return 0.95 if health >= 2 else 0.8


func _on_windup() -> void:
	warning_ring.hide()
	GameEvents.sound_requested.emit("cefiro_charge")
	dash_direction = player.global_position - global_position
	dash_direction.y = 0.0
	dash_direction = dash_direction.normalized() if dash_direction.length() > 0.05 else -global_basis.z
	look_at(global_position + dash_direction, Vector3.UP)
	var length := _dash_reach()
	telegraph.global_transform = Transform3D(Basis.looking_at(dash_direction, Vector3.UP), global_position + dash_direction * length * 0.5 + Vector3.UP * 0.05)
	telegraph.scale = Vector3(1, 1, length)
	telegraph.show()


## Distancia de embestida recortada al borde del suelo o a un muro.
func _dash_reach() -> float:
	var space := get_world_3d().direct_space_state
	var reach := 0.0
	var step := 0.5
	while reach < dash_distance:
		var point := global_position + dash_direction * (reach + step)
		var floor_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN * 1.5, 1)
		var wall_ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8 + dash_direction * reach, point + Vector3.UP * 0.8, 1)
		if space.intersect_ray(floor_ray).is_empty() or not space.intersect_ray(wall_ray).is_empty(): break
		reach += step
	return maxf(reach, 1.0)


func _resolve_attack(_active: bool, _distance: float) -> void:
	telegraph.hide()
	attack_time = 1.9
	dash_time = _dash_reach() / dash_speed
	dash_hit = false
	GameEvents.sound_requested.emit("cefiro_dash")


func apply_pulse(origin: Vector3, radius: float, force: float) -> void:
	super.apply_pulse(origin, radius, force)
	if stun_time > 0.0:
		dash_time = 0.0
		telegraph.hide()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if purified or not is_instance_valid(player): return
	if player.locked:
		telegraph.hide()
		dash_time = 0.0
	if dash_time > 0.0:
		dash_time -= delta
		var before := global_position
		_move_towards(global_position + dash_direction * 2.0, dash_speed * delta)
		if global_position.distance_to(before) < 0.001: dash_time = 0.0
		var offset := player.global_position - global_position
		offset.y = 0.0
		if not dash_hit and damage_enabled and offset.length() < 1.15 and absf(player.global_position.y - global_position.y) < 1.4:
			dash_hit = true
			if GameEvents.damage_player(damage, "El céfiro te embistió"):
				GameEvents.sound_requested.emit("hit")
				player.velocity += dash_direction * knockback + Vector3.UP * 3.0
	if mode == Mode.WINDUP:
		telegraph_material.albedo_color.a = 0.35 + 0.35 * sin(phase * 18.0)
	if not visual: return
	visual.rotation.y = PI
	var tired := mode == Mode.RECOVERY and dash_time <= 0.0
	visual.position.y = (-0.35 if tired else sin(phase * 2.0) * 0.15)
	visual.rotation.z = sin(phase * 1.3) * 0.12
	var flap_speed := 12.0 if mode == Mode.WINDUP else (3.0 if tired else 5.0)
	for i in wings.size():
		var side := -1.0 if i == 0 else 1.0
		wings[i].rotation.z = side * sin(phase * flap_speed) * (0.15 if tired else 0.45)
