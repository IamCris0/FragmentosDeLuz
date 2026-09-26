extends Node3D


func _ready() -> void:
	GameEvents.pulse_requested.connect(show_pulse)
	GameEvents.dodge_started.connect(show_dodge)


func show_dodge(origin: Vector3, direction: Vector3) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "DodgeTrail"
	dust.amount = 18
	dust.lifetime = 0.45
	dust.one_shot = true
	dust.explosiveness = 0.85
	var motion := ParticleProcessMaterial.new()
	motion.direction = -direction + Vector3.UP * 0.4
	motion.spread = 25
	motion.initial_velocity_min = 0.6
	motion.initial_velocity_max = 2.2
	motion.gravity = Vector3(0, -2, 0)
	motion.scale_min = 0.008
	motion.scale_max = 0.018
	var fade := GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.colors = PackedColorArray([Color(0.6, 0.85, 0.75, 0.55), Color(0.6, 0.85, 0.75, 0.0)])
	motion.color_ramp = fade
	dust.process_material = motion
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	dust.draw_pass_1 = mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	dust.global_position = origin + Vector3.UP * 0.1
	dust.finished.connect(dust.queue_free)
	dust.emitting = true


func show_pulse(origin: Vector3, radius: float, _force: float) -> void:
	var effect := Node3D.new()
	effect.name = "LightPulse"
	add_child(effect)
	effect.global_position = origin - Vector3.UP * 0.68
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Fase 7: la Nova (pulse_power 2) se dibuja dorada y con un anillo extra.
	var nova: bool = GameEvents.pulse_power >= 2
	material.albedo_color = Color(1.0, 0.86, 0.45, 0.85) if nova else Color(0.3, 1.0, 0.85, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.55, 0.15) if nova else Color(0.12, 0.65, 0.55)
	material.emission_energy_multiplier = 2.0
	for i in (3 if nova else 2):
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.94
		mesh.outer_radius = 1.0
		mesh.rings = 64
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.material_override = material
		ring.position.y = i * 0.42
		ring.scale = Vector3.ONE * 0.18
		effect.add_child(ring)
		var spread := create_tween()
		spread.tween_property(ring, "scale", Vector3(radius, 0.5, radius) * (1.0 - i * 0.15), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd98a") if nova else Color("7affde")
	light.omni_range = radius
	light.light_energy = 3.5
	light.position.y = 0.7
	effect.add_child(light)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(material, "albedo_color:a", 0.0, 0.5)
	fade.tween_property(light, "light_energy", 0.0, 0.5)
	fade.chain().tween_callback(effect.queue_free)
