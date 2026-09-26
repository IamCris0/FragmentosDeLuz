extends Node3D

const FRAGMENT: PackedScene = preload("res://assets/props/fragment_collectible.glb")
var fragments: Array[Node3D] = []
var homes: Array[Vector3] = []
var clock: float = 0.0
var yaw: float = 0.35
var pitch: float = 0.37
var distance: float = 4.5
var busy: bool = false
var drag: bool = false
var flight: Tween
var dust: MultiMeshInstance3D
var audio_player: AudioStreamPlayer
var cue_samples: Array[AudioStreamWAV] = []

@onready var camera: Camera3D = $Camera
@onready var crystal: StaticBody3D = $Crystal
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	for i in range(GameEvents.TOTAL):
		var fragment: Node3D = FRAGMENT.instantiate() as Node3D
		fragment.name = "Fragment_%02d" % i
		$Fragments.add_child(fragment)
		var angle: float = TAU * float(i) / float(GameEvents.TOTAL)
		var home := Vector3(0.69 * sin(angle), 0.19, -0.69 * cos(angle))
		fragment.position = home
		fragments.append(fragment)
		homes.append(home)
	hud.channel_requested.connect(channel)
	hud.reset_requested.connect(reset_sanctuary)
	GameEvents.reset()
	_make_dust()
	_make_audio()
	get_viewport().size_changed.connect(_update_camera)
	_update_camera()
	if "--validate" in OS.get_cmdline_user_args():
		_validate.call_deferred()


func _make_dust() -> void:
	dust = MultiMeshInstance3D.new()
	dust.name = "CrystalMotes"
	var mesh := SphereMesh.new()
	mesh.radius = 0.003
	mesh.height = 0.006
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("a9e2cf")
	mesh.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 32
	dust.multimesh = multi
	add_child(dust)


func _make_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.volume_db = -18
	add_child(audio_player)
	for note in [0, 2, 4, 7, 9, 11, 12]:
		var bytes := PackedByteArray()
		var rate: int = 22050
		var count: int = int(rate * 0.7)
		bytes.resize(count * 2)
		var frequency: float = 440.0 * pow(2.0, float(note) / 12.0)
		for sample in range(count):
			var t: float = float(sample) / rate
			var envelope: float = minf(t / 0.015, 1.0) * exp(-t * 6.0) * minf((0.7 - t) / 0.03, 1.0)
			var wave: float = sin(TAU * frequency * t) + sin(TAU * frequency * 2.0 * t) * 0.22
			bytes.encode_s16(sample * 2, int(wave * envelope * 17000.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = bytes
		cue_samples.append(stream)


func _process(delta: float) -> void:
	clock += delta
	for i in range(fragments.size()):
		if i >= GameEvents.collected and not (busy and i == GameEvents.collected):
			fragments[i].position = homes[i] + Vector3(0, sin(clock * 1.6 + i) * 0.022, 0)
			fragments[i].rotation.y += delta * 0.65
	if dust:
		for i in range(32):
			var angle: float = i * 2.399 + clock * 0.12
			var radius: float = 0.16 + float(i % 5) * 0.035
			var pos := Vector3(cos(angle) * radius, 0.28 + fposmod(float(i) * 0.071 + clock * 0.08, 1.02), sin(angle) * radius)
			dust.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			channel()
		elif event.physical_keycode == KEY_R or event.keycode == KEY_R:
			reset_sanctuary()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			drag = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.25, 2.5, 6.0)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.25, 2.5, 6.0)
		_update_camera()
	if event is InputEventMouseMotion and drag:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.005, 0.10, 1.13)
		_update_camera()
	if event is InputEventScreenDrag:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.005, 0.10, 1.13)
		_update_camera()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		drag = false


func _update_camera() -> void:
	var target := Vector3(0, 0.25, 0)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
	var fitted_distance: float = distance * maxf(1.0, 1.18 / aspect)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * fitted_distance
	camera.look_at(target)


func channel() -> void:
	if busy or GameEvents.collected >= GameEvents.TOTAL:
		return
	busy = true
	var index: int = GameEvents.collected
	var fragment: Node3D = fragments[index]
	flight = create_tween()
	flight.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	flight.tween_property(fragment, "position", Vector3(0, 0.83, 0), 0.6)
	flight.parallel().tween_property(fragment, "scale", Vector3.ONE * 0.12, 0.6)
	flight.finished.connect(func() -> void:
		fragment.visible = false
		GameEvents.collect(StringName("fragment_%02d" % index))
		audio_player.stream = cue_samples[index]
		audio_player.play()
		busy = false
	)


func reset_sanctuary() -> void:
	if flight and flight.is_valid():
		flight.kill()
	busy = false
	audio_player.stop()
	for i in range(fragments.size()):
		fragments[i].visible = true
		fragments[i].position = homes[i]
		fragments[i].scale = Vector3.ONE
	GameEvents.reset()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	picture.save_png(path)


func _validate() -> void:
	var preview_dir: String = ProjectSettings.globalize_path("res://../previews/")
	await get_tree().create_timer(1.0).timeout
	var shell: MeshInstance3D = crystal.find_child("Crystal_Shell", true, false) as MeshInstance3D
	assert(shell != null, "GLB shell was imported")
	assert(is_equal_approx(shell.get_aabb().size.y, 0.8), "Height in Godot is 0.8 m")
	assert(is_equal_approx(shell.get_aabb().get_center().y, 0.0), "Asset origin is centered")
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 0.83, 1), Vector3(0, 0.83, -1))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	assert(hit.get("collider") == crystal, "Crystal primitive collision works")
	var start_angle: float = crystal.get_node("Visual").rotation.y
	await get_tree().create_timer(0.15).timeout
	assert(crystal.get_node("Visual").rotation.y != start_angle, "Crystal animates")
	await _capture(preview_dir + "santuario_godot.png")
	for i in range(7):
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().create_timer(0.8).timeout
		key.pressed = false
		Input.parse_input_event(key)
		assert(GameEvents.collected == i + 1, "E delivers exactly one fragment")
	assert(hud.fragment_value.text == "7 / 7", "HUD signal signature matches")
	assert(not GameEvents.collect(&"fragment_00"), "Duplicate pickup rejected")
	assert(hud.prompt.disabled, "Completed state stops interaction")
	await _capture(preview_dir + "santuario_activado.png")
	reset_sanctuary()
	assert(GameEvents.collected == 0 and not hud.prompt.disabled, "Reset restores UI")
	channel()
	await get_tree().create_timer(0.15).timeout
	reset_sanctuary()
	await get_tree().create_timer(0.7).timeout
	assert(GameEvents.collected == 0 and not busy, "Reset cancels in-flight pickup")
	var old_position: Vector3 = camera.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 25)
	_unhandled_input(motion)
	assert(camera.position.distance_to(old_position) > 0.1, "Orbit responds to drag")
	press.pressed = false
	_unhandled_input(press)
	yaw = 0.35
	pitch = 0.37
	_update_camera()
	get_window().size = Vector2i(720, 960)
	await get_tree().create_timer(0.5).timeout
	assert(hud.heading.get_global_rect().end.x <= hud.root.size.x, "Narrow heading fits")
	assert(not hud.energy_bar.get_global_rect().intersects(hud.fragment_value.get_global_rect()), "Narrow HUD does not overlap")
	await _capture(preview_dir + "santuario_vertical.png")
	var report := {"status": "PASS", "engine": Engine.get_version_info().string,
		"asset_height_m": shell.get_aabb().size.y, "checks": ["GLB import", "Y-up / 0.8 m", "centered origin",
		"primitive collision raycast", "idle animation", "seven E key pickups", "HUD signals",
		"duplicate protection", "completion state", "reset", "reset during flight", "orbit input", "narrow HUD"],
		"renderer": RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(preview_dir + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VALIDATION_PASS ", JSON.stringify(report))
	get_tree().quit()
