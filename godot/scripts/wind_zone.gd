extends Area3D
## Fase 7: corriente de viento. Una corriente ascendente eleva a Neri mientras planea;
## una corriente lateral lo empuja. Construye su propia columna visual y su sonido.

@export var size: Vector3 = Vector3(3, 10, 3)
## Velocidad vertical objetivo al planear dentro de la corriente (0 = sin elevación).
@export var lift: float = 7.5
## Empuje horizontal (m/s²) aplicado en el aire.
@export var push: Vector3 = Vector3.ZERO
@export var active: bool = true
@export var tint: Color = Color("bff5ec")

var column: MeshInstance3D
var material: ShaderMaterial
var particles: GPUParticles3D
var hum: AudioStreamPlayer3D
var strength: float = 1.0


func _ready() -> void:
	add_to_group("wind_zone")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	if not has_node("CollisionShape3D"):
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position.y = size.y * 0.5 if lift > 0.0 else 0.0
		add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	strength = 1.0 if active else 0.0
	_apply_visibility()


func _build_visual() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/wind_column.gdshader")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("direction", 1.0 if lift > 0.0 else 0.0)
	column = MeshInstance3D.new()
	column.name = "WindColumn"
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lift > 0.0:
		var tube := CylinderMesh.new()
		tube.top_radius = minf(size.x, size.z) * 0.5
		tube.bottom_radius = minf(size.x, size.z) * 0.42
		tube.height = size.y
		tube.radial_segments = 24
		tube.rings = 6
		tube.cap_top = false
		tube.cap_bottom = false
		column.mesh = tube
		column.position.y = size.y * 0.5
	column.material_override = material
	# Las corrientes laterales solo se ven por sus ráfagas (una caja translúcida taparía el paisaje).
	if lift > 0.0: add_child(column)
	else:
		column.free()
		column = null
	particles = GPUParticles3D.new()
	particles.name = "WindMotes"
	particles.amount = 40 if lift > 0.0 else 24
	particles.lifetime = 2.2
	particles.preprocess = 2.0
	particles.visibility_aabb = AABB(-size * 0.6 - Vector3.UP * 2.0, size * 1.2 + Vector3.UP * 4.0)
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(size.x * 0.35, 0.3, size.z * 0.35) if lift > 0.0 else size * 0.45
	if lift > 0.0:
		motion.direction = Vector3.UP
		motion.spread = 8.0
		motion.initial_velocity_min = lift * 0.6
		motion.initial_velocity_max = lift * 1.0
		motion.gravity = Vector3.ZERO
	else:
		motion.direction = push.normalized()
		motion.spread = 6.0
		motion.initial_velocity_min = 3.0
		motion.initial_velocity_max = 5.0
		motion.gravity = Vector3.ZERO
	motion.scale_min = 0.02
	motion.scale_max = 0.05
	var fade := GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	fade.gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	motion.color_ramp = fade
	particles.process_material = motion
	var streak := QuadMesh.new()
	streak.size = Vector2(0.18, 1.1) if lift > 0.0 else Vector2(1.1, 0.12)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.vertex_color_use_as_albedo = true
	streak_material.albedo_color = tint
	streak_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if lift > 0.0 else BaseMaterial3D.BILLBOARD_ENABLED
	streak.material = streak_material
	particles.draw_pass_1 = streak
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	if ResourceLoader.exists("res://assets/audio/updraft.wav"):
		hum = AudioStreamPlayer3D.new()
		hum.name = "WindHum"
		var source: AudioStream = load("res://assets/audio/updraft.wav")
		if source is AudioStreamWAV:
			var looped: AudioStreamWAV = source.duplicate()
			looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
			looped.loop_end = int(looped.get_length() * looped.mix_rate)
			source = looped
		hum.stream = source
		hum.bus = "Ambience"
		hum.volume_db = -10.0
		hum.unit_size = 4.0
		hum.max_distance = 22.0
		hum.position.y = 1.5
		add_child(hum)


func set_active(value: bool, animate: bool = true) -> void:
	active = value
	if not animate:
		strength = 1.0 if value else 0.0
		_apply_visibility()
		return
	var tween := create_tween()
	tween.tween_method(_set_strength, strength, 1.0 if value else 0.0, 1.4).set_trans(Tween.TRANS_SINE)


func _set_strength(value: float) -> void:
	strength = value
	_apply_visibility()


func _apply_visibility() -> void:
	if material: material.set_shader_parameter("strength", strength)
	if column: column.visible = strength > 0.01
	if particles:
		particles.emitting = strength > 0.3
		particles.amount_ratio = clampf(strength, 0.05, 1.0)
	if hum:
		if strength > 0.05 and not hum.playing and is_inside_tree(): hum.play()
		elif strength <= 0.05 and hum.playing: hum.stop()
		hum.volume_db = lerpf(-40.0, -10.0, strength)


## Fuerza que recibe el jugador: y = velocidad de elevación objetivo, x/z = empuje horizontal.
func force_for(_player: Node3D) -> Vector3:
	if not active or strength < 0.3: return Vector3.ZERO
	return Vector3(push.x * strength, lift * strength, push.z * strength)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and "wind_zones" in body and not body.wind_zones.has(self):
		body.wind_zones.append(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and "wind_zones" in body:
		body.wind_zones.erase(self)
