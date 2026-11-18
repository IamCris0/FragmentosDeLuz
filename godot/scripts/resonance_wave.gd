extends Node3D

var speed: float = 6.0
var max_radius: float = 6.5
var damage: float = 28.0
var damage_enabled: bool = true
var radius: float = 0.15
var hit_player: bool = false
var absorbed: bool = false
var practice: bool = false
var ring: MeshInstance3D
var material: StandardMaterial3D
var player: CharacterBody3D


func _ready() -> void:
	add_to_group("resonance_wave")
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	ring = MeshInstance3D.new()
	ring.name = "ExpandingFront"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 96
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.position.y = 0.14
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("ffd995")
	material.emission_enabled = true
	material.emission = Color("ff974d")
	material.emission_energy_multiplier = 2.0
	ring.material_override = material
	add_child(ring)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.locked:
		queue_free()
		return
	var previous := radius
	radius += speed * delta
	ring.scale = Vector3(radius, 1.0, radius)
	material.albedo_color.a = clampf((max_radius - radius) / 0.8, 0.0, 1.0)
	var offset := player.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	# Sweep the annulus between frames; height and cover permit jump/obstacle evasion.
	if not hit_player and not absorbed and (damage_enabled or practice) and distance >= previous - 0.38 and distance <= radius + 0.38:
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, player.global_position + Vector3.UP * 0.8, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			if offset.y >= 0.55 and offset.y <= 2.0 and not player.is_on_floor():
				absorbed = true
				if practice:
					GameEvents.toast_requested.emit("Buen salto. Ante el guardián, este gesto devuelve energía.")
					GameEvents.sound_requested.emit("rune_1")
					return
				var before := GameEvents.energy
				GameEvents.set_energy(before + 8.0)
				var gain := roundi(GameEvents.energy - before)
				GameEvents.toast_requested.emit("Resonancia absorbida · +%d energía" % gain if gain > 0 else "Resonancia absorbida")
				GameEvents.sound_requested.emit("pickup")
			elif absf(offset.y) < 0.55:
				hit_player = true
				if practice:
					GameEvents.toast_requested.emit("Salta justo antes de que el aro toque tus botas.")
				elif GameEvents.damage_player(damage, "La onda del guardián alcanzó tu luz"):
					GameEvents.sound_requested.emit("hit")
	if radius >= max_radius: queue_free()
