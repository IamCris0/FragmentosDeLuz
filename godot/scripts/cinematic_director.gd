extends Node
## Director de cinemáticas en tiempo real (fase 6).
## Mueve una cámara propia con trayectorias suaves, muestra franjas panorámicas, títulos,
## subtítulos con voz y fundidos. Se puede saltar manteniendo E, Espacio, Esc o A/Start del mando.
## Cada secuencia se reproduce una sola vez por partida (story_seen["cine_<id>"]).

signal finished(id: String)
signal credits_closed(to_menu: bool)

const UI = preload("res://scripts/ui_theme.gd")
const CreditsRoll = preload("res://scripts/credits_roll.gd")
const SKIP_HOLD := 0.75
const BAR_RATIO := 0.105

var game: Node3D
var camera: Camera3D
var layer: CanvasLayer
var top_bar: ColorRect
var bottom_bar: ColorRect
var fade_rect: ColorRect
var subtitle_box: VBoxContainer
var speaker_label: Label
var subtitle_label: Label
var title_box: VBoxContainer
var title_label: Label
var title_sub: Label
var skip_box: Control
var skip_bar: ProgressBar
var credits_layer: Control
var current: String = ""
var skipping: bool = false
var hold: float = 0.0
var enabled: bool = true
var bars_amount: float = 0.0
var subtitle_timer: float = 0.0
var title_timer: float = 0.0
var active_tweens: Array[Tween] = []
var spawned: Array[Node] = []
var last_shot: Dictionary = {}
var played: Array[String] = []
var skip_armed: bool = false
var choice_buttons: Array = []
## Fase 7: secuencias registradas por los niveles del archipiélago (id -> Callable que se espera con await).
var sequences: Dictionary = {}
## Centro de la órbita de cámara durante los créditos.
var credits_center: Vector3 = Vector3(0, 12, -92)
var credits_heading: String = "Auralia vuelve a brillar"
var credits_chapter: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	enabled = not ("--qa" in args) or "--qa-cinematics" in args
	game = get_parent() as Node3D
	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.near = 0.05
	camera.far = 400.0
	camera.fov = 50.0
	add_child(camera)
	_build_ui()


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "CinematicLayer"
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	top_bar = _rect(root, "TopBar", Color(0.0, 0.0, 0.0, 1.0))
	bottom_bar = _rect(root, "BottomBar", Color(0.0, 0.0, 0.0, 1.0))
	title_box = VBoxContainer.new()
	title_box.name = "TitleCard"
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", 6)
	root.add_child(title_box)
	title_label = UI.label("", 58, UI.GOLD, "logo")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.8))
	title_label.add_theme_constant_override("outline_size", 6)
	title_box.add_child(title_label)
	title_sub = UI.label("", 20, UI.TEAL_LIGHT, "title_semibold")
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title_sub)
	title_box.modulate.a = 0.0
	subtitle_box = VBoxContainer.new()
	subtitle_box.name = "Subtitles"
	subtitle_box.alignment = BoxContainer.ALIGNMENT_CENTER
	subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_box.add_theme_constant_override("separation", 4)
	root.add_child(subtitle_box)
	speaker_label = UI.label("", 15, UI.GOLD, "title")
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_box.add_child(speaker_label)
	subtitle_label = UI.label("", 22, UI.INK, "body_bold")
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_box.add_child(subtitle_label)
	subtitle_box.modulate.a = 0.0
	skip_box = VBoxContainer.new()
	skip_box.name = "SkipHint"
	skip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skip_box)
	var hint := UI.label("Mantén E / A para saltar", 12, Color("b9c9c3"), "body_bold")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_box.add_child(hint)
	skip_bar = ProgressBar.new()
	skip_bar.show_percentage = false
	skip_bar.custom_minimum_size = Vector2(170, 4)
	skip_bar.max_value = 1.0
	skip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under := StyleBoxFlat.new()
	under.bg_color = Color(1, 1, 1, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.GOLD
	skip_bar.add_theme_stylebox_override("background", under)
	skip_bar.add_theme_stylebox_override("fill", fill)
	skip_box.add_child(skip_bar)
	skip_box.modulate.a = 0.0
	fade_rect = _rect(root, "Fade", Color(0.0, 0.0, 0.0, 0.0))
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits_layer = Control.new()
	credits_layer.name = "Credits"
	credits_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(credits_layer)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _rect(parent: Control, title: String, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = title
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var bar := size.y * BAR_RATIO * bars_amount
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(size.x, bar)
	bottom_bar.position = Vector2(0, size.y - bar)
	bottom_bar.size = Vector2(size.x, bar)
	var narrow := size.x < 1000
	title_box.position = Vector2(0, size.y * 0.2)
	title_box.size = Vector2(size.x, 120)
	title_label.add_theme_font_size_override("font_size", 40 if narrow else 58)
	subtitle_box.size = Vector2(minf(900.0, size.x - 80.0), 90)
	subtitle_box.position = Vector2((size.x - subtitle_box.size.x) * 0.5, size.y - size.y * BAR_RATIO - 104)
	subtitle_label.add_theme_font_size_override("font_size", 18 if narrow else 22)
	skip_box.position = Vector2(size.x - 210, 18)
	skip_box.size = Vector2(180, 30)


func is_playing() -> bool:
	return current != ""


func should_play(id: String) -> bool:
	return enabled and current == "" and not GameEvents.story_seen.has("cine_" + id)


# --- Reproducción --------------------------------------------------------------------------------

func play(id: String) -> void:
	if not enabled or current != "":
		return
	current = id
	skipping = false
	skip_armed = false
	hold = 0.0
	_begin()
	match id:
		"arrival": await _seq_arrival()
		"garden": await _seq_garden()
		"guardian": await _seq_guardian()
		"finale": await _seq_finale()
		_:
			if sequences.has(id): await (sequences[id] as Callable).call()
	if not is_inside_tree():
		return
	# Los finales siguen con epílogo y créditos: el control vuelve en finish_finale().
	await _end(not id.ends_with("finale"))
	GameEvents.story_seen["cine_" + id] = true
	GameEvents.save_game()
	played.append(id)
	current = ""
	finished.emit(id)


func _begin() -> void:
	var player: CharacterBody3D = game.player
	var view := get_viewport().get_camera_3d()
	if view:
		camera.global_transform = view.global_transform
		camera.fov = view.fov
	camera.current = true
	GameEvents.set_cinematic(true)
	player.locked = true
	player.camera_drag = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud.root.visible = false
	_tween_bars(1.0, 0.6)


func _end(return_to_player: bool) -> void:
	var player: CharacterBody3D = game.player
	_hide_subtitle(0.25)
	_hide_title(0.25)
	if return_to_player and not skipping:
		var target: Camera3D = player.camera
		var start := camera.global_transform
		var start_fov := camera.fov
		var blend := create_tween()
		blend.tween_method(_blend_camera.bind(start, target, start_fov), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween_bars(0.0, 0.9)
		await _wait_tween(blend)
	if skipping and fade_rect.color.a < 0.99 and return_to_player:
		# Un salto termina con un fundido breve para ocultar el corte de cámara.
		fade_rect.color.a = 1.0
	# Completa cualquier animación pendiente para que sus efectos (faro, puerta) queden aplicados.
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_valid() and tween.is_running(): tween.custom_step(1000.0)
	for node in spawned:
		if is_instance_valid(node): node.queue_free()
	spawned.clear()
	_kill_tweens()
	if return_to_player: player.camera.current = true
	player.cinematic_state = ""
	bars_amount = 0.0
	_layout()
	skip_box.modulate.a = 0.0
	skip_bar.value = 0.0
	if return_to_player:
		game.hud.root.visible = true
		player.locked = false
		GameEvents.set_cinematic(false)
		if fade_rect.color.a > 0.0:
			var reveal := create_tween()
			reveal.tween_property(fade_rect, "color:a", 0.0, 0.45)
	var audio := game.get_node_or_null("AudioManager")
	if audio and return_to_player:
		audio.clear_cinematic_music()
		audio.stop_voice(0.4)


func _process(delta: float) -> void:
	if subtitle_timer > 0.0:
		subtitle_timer -= delta
		if subtitle_timer <= 0.0: _hide_subtitle(0.35)
	if title_timer > 0.0:
		title_timer -= delta
		if title_timer <= 0.0: _hide_title(0.8)
	if current == "":
		# Botones del final: X / E también confirman el botón enfocado.
		if not choice_buttons.is_empty() and Input.is_action_just_pressed("interact"):
			for button in choice_buttons:
				if is_instance_valid(button) and button.has_focus(): button.emit_signal("pressed")
		return
	var holding := Input.is_action_pressed("interact") or Input.is_action_pressed("jump") or Input.is_action_pressed("pause") or Input.is_action_pressed("ui_accept")
	if not holding: skip_armed = true
	if holding and skip_armed and not skipping:
		hold += delta
		skip_box.modulate.a = minf(1.0, skip_box.modulate.a + delta * 6.0)
	else:
		hold = maxf(0.0, hold - delta * 2.0)
		skip_box.modulate.a = maxf(0.35 if current != "" and not skipping else 0.0, skip_box.modulate.a - delta * 1.5)
	skip_bar.value = hold / SKIP_HOLD
	if hold >= SKIP_HOLD and not skipping:
		skip()


func skip() -> void:
	if current == "" or skipping:
		return
	skipping = true
	hold = 0.0
	var audio := game.get_node_or_null("AudioManager")
	if audio: audio.stop_voice(0.15)
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.custom_step(1000.0)
	_hide_subtitle(0.1)
	_hide_title(0.1)


func _kill_tweens() -> void:
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_valid(): tween.kill()
	active_tweens.clear()


func _track(tween: Tween) -> Tween:
	active_tweens.append(tween)
	return tween


func _wait_tween(tween: Tween) -> void:
	while is_inside_tree() and is_instance_valid(tween) and tween.is_valid() and tween.is_running() and not skipping:
		await get_tree().process_frame
	if skipping and is_instance_valid(tween) and tween.is_valid():
		tween.custom_step(1000.0)


func wait(seconds: float) -> void:
	var elapsed := 0.0
	while is_inside_tree() and elapsed < seconds and not skipping:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


# --- Herramientas de cámara ---------------------------------------------------------------------

func _place(position: Vector3, look: Vector3, fov: float) -> void:
	if position.is_equal_approx(look): look += Vector3.FORWARD * 0.01
	var up := Vector3.UP if absf((look - position).normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	camera.look_at_from_position(position, look, up)
	camera.fov = fov
	last_shot = {"position": position, "look": look, "fov": fov}


static func catmull(points: Array, t: float) -> Vector3:
	if points.size() == 1: return points[0]
	var segments := points.size() - 1
	var scaled := clampf(t, 0.0, 1.0) * segments
	var index := mini(int(scaled), segments - 1)
	var local := scaled - index
	var p0: Vector3 = points[maxi(index - 1, 0)]
	var p1: Vector3 = points[index]
	var p2: Vector3 = points[index + 1]
	var p3: Vector3 = points[mini(index + 2, segments)]
	var t2 := local * local
	var t3 := t2 * local
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * local + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Recorrido de cámara por una curva Catmull-Rom (posición y punto de mira).
func path(points: Array, looks: Array, duration: float, fov_from: float = 50.0, fov_to: float = 50.0,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	_place(points[0], looks[0], fov_from)
	var tween := _track(create_tween())
	tween.tween_method(_path_step.bind(points, looks, fov_from, fov_to), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(easing)
	await _wait_tween(tween)


func _path_step(t: float, points: Array, looks: Array, fov_from: float, fov_to: float) -> void:
	_place(catmull(points, t), catmull(looks, t), lerpf(fov_from, fov_to, t))


func _blend_camera(t: float, start: Transform3D, target: Camera3D, start_fov: float) -> void:
	if not is_instance_valid(target): return
	camera.global_transform = start.interpolate_with(target.global_transform, t)
	camera.fov = lerpf(start_fov, target.fov, t)


func _orbit_step(angle: float, center: Vector3, radius: float, height: float, fov: float, look_offset: Vector3) -> void:
	var a := deg_to_rad(angle)
	_place(center + Vector3(sin(a) * radius, height, cos(a) * radius), center + look_offset, fov)


func shot(from: Vector3, from_look: Vector3, to: Vector3, to_look: Vector3, duration: float,
		fov_from: float = 50.0, fov_to: float = 50.0) -> void:
	await path([from, to], [from_look, to_look], duration, fov_from, fov_to)


func orbit(center: Vector3, radius: float, height: float, from_deg: float, to_deg: float, duration: float,
		fov: float = 45.0, look_offset: Vector3 = Vector3.ZERO) -> void:
	var tween := _track(create_tween())
	tween.tween_method(_orbit_step.bind(center, radius, height, fov, look_offset), from_deg, to_deg, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait_tween(tween)


# --- Rótulos, subtítulos, fundidos ---------------------------------------------------------------

func _tween_bars(target: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_bars, bars_amount, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_bars(value: float) -> void:
	bars_amount = value
	_layout()


func title_card(title: String, subtitle: String, duration: float) -> void:
	if skipping: return
	title_label.text = title
	title_sub.text = subtitle
	title_timer = duration
	var tween := create_tween()
	tween.tween_property(title_box, "modulate:a", 1.0, 0.9)


func _hide_title(duration: float) -> void:
	title_timer = 0.0
	var tween := create_tween()
	tween.tween_property(title_box, "modulate:a", 0.0, duration)


## Muestra un subtítulo y reproduce su voz si existe. Devuelve la duración prevista.
func say(speaker: String, text: String, voice_cue: String = "", minimum: float = 0.0) -> float:
	if skipping: return 0.0
	speaker_label.text = speaker
	subtitle_label.text = text
	var length := 0.0
	var audio := game.get_node_or_null("AudioManager")
	if audio and voice_cue != "": length = audio.play_voice(voice_cue)
	var duration := maxf(maxf(minimum, length + 0.45), 1.6 + text.length() * 0.055)
	subtitle_timer = duration
	var tween := create_tween()
	tween.tween_property(subtitle_box, "modulate:a", 1.0, 0.3)
	return duration


func _hide_subtitle(duration: float) -> void:
	subtitle_timer = 0.0
	var tween := create_tween()
	tween.tween_property(subtitle_box, "modulate:a", 0.0, duration)


func fade(alpha: float, duration: float, blocking: bool = true) -> void:
	var tween := _track(create_tween())
	tween.tween_property(fade_rect, "color:a", alpha, duration)
	if blocking: await _wait_tween(tween)


# --- Secuencias ----------------------------------------------------------------------------------

func _seq_arrival() -> void:
	var audio := game.get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("title")
	fade_rect.color.a = 1.0
	fade(0.0, 1.6, false)
	title_card("AURALIA", "La ciudad suspendida", 5.0)
	await path([Vector3(52, 30, 44), Vector3(38, 21, 20), Vector3(27, 15, 2)],
		[Vector3(0, 6, -36), Vector3(0, 5, -46), Vector3(0, 5, -56)], 6.5, 44.0, 40.0)
	say("LUMA", "Siete fragmentos. Un faro dormido desde hace cien años…", "vo_cine_arrival_1", 4.0)
	await path([Vector3(-24, 17, -66), Vector3(-9, 12.5, -73), Vector3(9, 10.5, -76)],
		[Vector3(0, 9, -93), Vector3(0, 10, -94), Vector3(0, 10.5, -94)], 6.0, 50.0, 40.0)
	say("LUMA", "…y, por fin, alguien ha escuchado la señal.", "vo_cine_arrival_2", 3.5)
	await path([Vector3(0, 6.5, -20), Vector3(0, 3.4, -7), Vector3(0.4, 2.2, 1.0), Vector3(1.3, 1.75, 4.35)],
		[Vector3(0, 2.5, 0), Vector3(0, 1.9, 4), Vector3(0, 1.6, 7), Vector3(0, 1.5, 7)], 7.0, 58.0, 42.0)
	await wait(0.6)


func _seq_garden() -> void:
	var audio := game.get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("garden")
	var gate: Node3D = game.gate
	await shot(Vector3(7.0, 3.6, -26.5), Vector3(0, 2.3, -33), Vector3(4.6, 3.1, -28.8), Vector3(0, 2.5, -33), 3.2, 52.0, 46.0)
	say("LUMA", "El jardín recuerda su melodía.", "vo_cine_garden_1", 2.6)
	if not skipping: game.call("dissolve_gate", 2.6)
	await shot(Vector3(-4.2, 3.3, -35.0), Vector3(0, 1.9, -41.4), Vector3(-1.8, 2.7, -37.3), Vector3(0, 1.8, -41.4), 4.2, 50.0, 44.0)
	say("LUMA", "El camino al Paso del Cielo está abierto.", "vo_cine_garden_2", 2.6)
	await wait(1.4)
	if is_instance_valid(gate) and skipping:
		game.call("dissolve_gate", 0.0)


func _seq_guardian() -> void:
	var audio := game.get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("combat")
	var guardian: Node3D = game.get_node_or_null("Zones/PortalFinal/BeaconEcho")
	if not is_instance_valid(guardian):
		return
	var center := guardian.global_position + Vector3.UP * 1.25
	var visual: Node3D = guardian.get_node_or_null("Visual")
	var light: OmniLight3D = guardian.get_node_or_null("CoreLight")
	if visual:
		var final_scale := visual.scale
		visual.scale = final_scale * 0.45
		var grow := _track(create_tween())
		grow.tween_interval(0.5)
		grow.tween_property(visual, "scale", final_scale, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if light:
		var burst := _track(create_tween())
		burst.tween_interval(0.5)
		burst.tween_property(light, "light_energy", 7.0, 0.5)
		burst.tween_property(light, "light_energy", 1.2, 1.2)
	GameEvents.sound_requested.emit("enemy_alert")
	await shot(center + Vector3(4.2, 0.1, 6.2), center, center + Vector3(2.3, -0.25, 3.7), center + Vector3(0, 0.3, 0), 3.4, 50.0, 38.0)
	GameEvents.sound_requested.emit("guardian_charge")
	title_card("ECO DEL FARO", "Guardián de la luz rota", 3.6)
	await orbit(center, 4.3, 0.6, -35.0, 38.0, 4.0, 42.0)
	say("LUMA", "Ese eco nació del núcleo roto. Interrumpe su carga con tu pulso de luz.", "vo_cine_guardian_1", 3.5)
	await shot(last_shot.position, last_shot.look, center + Vector3(2.6, 0.9, 5.4), center, 2.6, 42.0, 46.0)
	if is_instance_valid(guardian):
		guardian.set("windup_time", 0.0)
		guardian.set("attack_time", 1.4)


func _seq_finale() -> void:
	var audio := game.get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("finale")
	var player: CharacterBody3D = game.player
	player.global_position = Vector3(0, 4.05, -86.3)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = PI
	player.cinematic_state = "pulse"
	var heart := Vector3(0, 12.9, -95.5)
	var beacon: Node = game.get_node_or_null("BeaconRestoration")
	_spawn_fragments(player.global_position + Vector3(0.25, 1.25, -0.35), heart)
	say("LUMA", "Los siete fragmentos vuelven a casa.", "vo_cine_finale_1", 3.0)
	await shot(Vector3(1.35, 5.95, -83.1), Vector3(0, 6.2, -91), Vector3(0.85, 5.75, -84.0), Vector3(0, 7.2, -91), 4.2, 52.0, 48.0)
	player.cinematic_state = ""
	var ignition := _track(create_tween())
	ignition.tween_interval(0.9)
	ignition.tween_callback(_ignite.bind(heart, beacon))
	say("LUMA", "El faro vuelve a cantar.", "vo_cine_finale_2", 2.6)
	await shot(Vector3(6.2, 5.0, -82.6), Vector3(0, 10.5, -93), Vector3(3.8, 5.5, -84.6), Vector3(0, 13.5, -95), 4.4, 50.0, 56.0)
	say("LUMA", "Una luz tras otra, las islas lejanas responden.", "vo_cine_finale_3", 4.0)
	await path([Vector3(0, 9.5, -77), Vector3(-6, 22, -70), Vector3(-14, 34, -62)],
		[Vector3(0, 14, -93), Vector3(0, 22, -92), Vector3(0, 24, -92)], 6.2, 55.0, 58.0)
	say("LUMA", "No has devuelto la ciudad al pasado, Neri. Le has dado un mañana.", "vo_cine_finale_4", 4.5)
	await path([Vector3(-92, 40, -8), Vector3(-80, 34, 12)], [Vector3(0, 8, -62), Vector3(0, 8, -58)], 6.5, 50.0, 46.0)
	var companion := _spawn_companion(Vector3(1.35, 4.0, -85.7))
	player.cinematic_state = "wave"
	player.visual.rotation.y = PI * 0.62
	say("NERI", "Alguien más vio la señal. Vamos, Luma.", "vo_cine_finale_5", 3.0)
	await shot(Vector3(3.3, 5.7, -81.6), Vector3(0.7, 5.3, -86.0), Vector3(2.5, 5.5, -82.7), Vector3(0.6, 5.4, -86.2), 4.6, 44.0, 38.0)
	if companion: spawned.append(companion)
	await fade(1.0, 1.6)


func _spawn_fragments(origin: Vector3, target: Vector3) -> void:
	var packed: PackedScene = load("res://assets/props/fragment_collectible.glb")
	for i in 7:
		var piece := Node3D.new()
		piece.name = "RisingFragment%d" % i
		game.add_child(piece)
		spawned.append(piece)
		if packed:
			var model := packed.instantiate() as Node3D
			model.scale = Vector3.ONE * 1.6
			piece.add_child(model)
		var glow := OmniLight3D.new()
		glow.light_color = Color("f9c74f")
		glow.light_energy = 1.4
		glow.omni_range = 2.2
		piece.add_child(glow)
		var angle := TAU * i / 7.0
		var spiral := origin + Vector3(cos(angle) * 1.1, 1.3 + i * 0.1, sin(angle) * 1.1)
		piece.global_position = origin
		var control := origin.lerp(target, 0.5) + Vector3(cos(angle) * 4.0, 3.5, sin(angle) * 2.0)
		var tween := _track(create_tween())
		tween.tween_interval(0.12 * i)
		tween.tween_property(piece, "global_position", spiral, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_emit_sound.bind("fragment_rise"))
		tween.tween_method(_fragment_step.bind(piece, spiral, control, target), 0.0, 1.0, 2.2 + i * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(_hide_node.bind(piece))


func _fragment_step(t: float, piece: Node3D, spiral: Vector3, control: Vector3, target: Vector3) -> void:
	if not is_instance_valid(piece): return
	var a := spiral.lerp(control, t)
	var b := control.lerp(target, t)
	piece.global_position = a.lerp(b, t)
	piece.rotation.y += 0.2


func _hide_node(node: Node3D) -> void:
	if is_instance_valid(node): node.hide()


func _emit_sound(cue: String) -> void:
	GameEvents.sound_requested.emit(cue)


func _ignite(heart: Vector3, beacon: Node) -> void:
	_flash(heart, 9.0)
	if is_instance_valid(beacon) and beacon.has_method("restore"): beacon.restore(true)


func _flash(point: Vector3, energy: float) -> void:
	var light := OmniLight3D.new()
	light.name = "BeaconFlash"
	light.light_color = Color("ffe6a8")
	light.omni_range = 30.0
	light.light_energy = energy
	game.add_child(light)
	light.global_position = point
	spawned.append(light)
	var tween := _track(create_tween())
	tween.tween_property(light, "light_energy", 0.0, 2.2)
	GameEvents.sound_requested.emit("beacon_ignite")


func _spawn_companion(point: Vector3) -> Node3D:
	var packed: PackedScene = load("res://assets/characters/luma_spirit.glb")
	if not packed: return null
	var luma := packed.instantiate() as Node3D
	luma.name = "LumaCompanion"
	luma.set_script(load("res://scripts/luma_spirit.gd"))
	game.add_child(luma)
	luma.global_position = point
	luma.rotation.y = -PI * 0.55
	luma.scale = Vector3.ONE * 0.01
	var tween := _track(create_tween())
	tween.tween_property(luma, "scale", Vector3.ONE * 0.85, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return luma


# --- Créditos ------------------------------------------------------------------------------------

## Registra una secuencia de un nivel (fase 7).
func register(id: String, sequence: Callable) -> void:
	sequences[id] = sequence


## Epílogo y créditos sobre el faro restaurado. Devuelve true si el jugador elige el menú principal.
func roll_credits() -> bool:
	var roll: Control = CreditsRoll.new()
	roll.build(true, credits_chapter)
	if "--qa" in OS.get_cmdline_user_args(): roll.speed = 900.0
	credits_layer.add_child(roll)
	var backdrop_tween := create_tween()
	backdrop_tween.tween_property(fade_rect, "color:a", 0.55, 1.6)
	camera.current = true
	var orbit_tween := create_tween().set_loops()
	orbit_tween.tween_method(_orbit_step.bind(credits_center, 26.0, 6.0, 48.0, Vector3(0, 4, 0)), 0.0, 360.0, 80.0)
	roll.start()
	current = "credits"
	skipping = false
	skip_armed = false
	hold = 0.0
	while is_inside_tree() and roll.running and not skipping:
		await get_tree().process_frame
	orbit_tween.kill()
	roll.queue_free()
	current = ""
	skipping = false
	skip_box.modulate.a = 0.0
	var choice := await _credits_choice()
	credits_closed.emit(choice)
	return choice


func _credits_choice() -> bool:
	var panel := VBoxContainer.new()
	panel.name = "CreditsChoice"
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_constant_override("separation", 14)
	panel.theme = UI.build_theme()
	credits_layer.add_child(panel)
	var heading := UI.label(credits_heading, 30, UI.GOLD, "title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(heading)
	var explore := Button.new()
	explore.text = "Seguir explorando"
	explore.custom_minimum_size = Vector2(300, 46)
	panel.add_child(explore)
	var menu := Button.new()
	menu.text = "Volver al menú principal"
	menu.custom_minimum_size = Vector2(300, 46)
	panel.add_child(menu)
	panel.position -= panel.get_combined_minimum_size() * 0.5
	explore.grab_focus.call_deferred()
	var result := [false, false]
	explore.pressed.connect(_choose.bind(result, false))
	menu.pressed.connect(_choose.bind(result, true))
	choice_buttons = [explore, menu]
	if "--qa" in OS.get_cmdline_user_args():
		result[0] = true
	while is_inside_tree() and not result[0]:
		await get_tree().process_frame
	choice_buttons.clear()
	panel.queue_free()
	return result[1]


func _choose(result: Array, to_menu: bool) -> void:
	result[0] = true
	result[1] = to_menu
