extends CanvasLayer

const MAIN_SCENE := "res://scenes/main_island.tscn"
const UI = preload("res://scripts/ui_theme.gd")
const Audio = preload("res://scripts/audio_manager.gd")
const CAPTIONS: Array[Dictionary] = [
	{
		"title": "AURALIA",
		"text": "Antes de la tormenta, el faro mantenía unidas las islas suspendidas."
	},
	{
		"title": "LA FRACTURA",
		"text": "Una señal imposible partió el núcleo en siete fragmentos de luz."
	},
	{
		"title": "NERI",
		"text": "Años después, Neri encuentra el eco perdido en su escáner."
	},
	{
		"title": "EL UMBRAL",
		"text": "En las ruinas espera Luma, y con ella la última ruta hacia el faro."
	}
]

var index: int = 0
var panel: TextureRect
var title_label: Label
var body_label: Label
var progress_label: Label
var advance: Button
var skip: Button
var tint: ColorRect
var root: Control
var reveal: float = 0.0
var artwork: Texture2D
var art_motion: Tween
var changing_scene: bool = false
var narrator: AudioStreamPlayer


func _exit_tree() -> void:
	if art_motion:
		art_motion.kill()
		art_motion = null
	var music := get_node_or_null("PrologueMusic") as AudioStreamPlayer
	if music:
		music.stop()
		music.stream = null
	if narrator:
		narrator.stop()
		narrator.stream = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.load_game()
	if not "--qa-prologue" in OS.get_cmdline_user_args() and not "--replay-prologue" in OS.get_cmdline_user_args() and ("--qa" in OS.get_cmdline_user_args() or "--skip-prologue" in OS.get_cmdline_user_args() or GameEvents.story_seen.has("prologue")):
		call_deferred("_start_game")
		return
	_build_ui()
	_show_panel(0)
	var music := AudioStreamPlayer.new()
	music.name = "PrologueMusic"
	music.stream = load(Audio.music_path("title"))
	music.bus = "Music"
	music.volume_db = -8.0
	add_child(music)
	music.play()
	narrator = AudioStreamPlayer.new()
	narrator.name = "Narrator"
	narrator.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Effects"
	add_child(narrator)
	_narrate(0)
	if "--qa-prologue" in OS.get_cmdline_user_args():
		_qa.call_deferred()


func _build_ui() -> void:
	root = Control.new()
	root.name = "ComicRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("090d16")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	panel = TextureRect.new()
	panel.name = "PrologueImage"
	artwork = load("res://assets/story/prologue_comic.png")
	panel.texture = artwork
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	tint = ColorRect.new()
	tint.name = "PanelFocus"
	tint.color = Color(0.01, 0.02, 0.04, 0.12)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(tint)
	var shade := ColorRect.new()
	shade.name = "CaptionShade"
	shade.color = Color(0.015, 0.025, 0.035, 0.72)
	shade.anchor_left = 0
	shade.anchor_top = 0.72
	shade.anchor_right = 1
	shade.anchor_bottom = 1
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.name = "CaptionBox"
	box.anchor_left = 0.06
	box.anchor_top = 0.73
	box.anchor_right = 0.94
	box.anchor_bottom = 0.97
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_override("font", UI.font("title"))
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color("f1d48b"))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title_label)
	body_label = Label.new()
	body_label.name = "Body"
	body_label.add_theme_font_override("font", UI.font("body_bold"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 21)
	body_label.add_theme_color_override("font_color", Color("e9f0e7"))
	body_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	body_label.add_theme_constant_override("shadow_offset_y", 2)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_label)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	progress_label = Label.new()
	progress_label.name = "Progress"
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color("b8c6c1"))
	row.add_child(progress_label)
	skip = _button("Saltar")
	advance = _button("Continuar")
	row.add_child(skip)
	row.add_child(advance)
	skip.pressed.connect(_finish)
	advance.pressed.connect(_next)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _button(caption: String) -> Button:
	var node := Button.new()
	node.theme = UI.build_theme()
	node.text = caption
	node.custom_minimum_size = Vector2(132, 42)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 16)
	return node


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var small := size.x < 900
	title_label.add_theme_font_size_override("font_size", 26 if small else 34)
	body_label.add_theme_font_size_override("font_size", 17 if small else 21)
	advance.custom_minimum_size.x = 116 if small else 132
	skip.custom_minimum_size.x = 98 if small else 132


func _show_panel(next_index: int) -> void:
	index = clampi(next_index, 0, CAPTIONS.size() - 1)
	var item := CAPTIONS[index]
	title_label.text = item["title"]
	body_label.text = item["text"]
	progress_label.text = "%d / %d" % [index + 1, CAPTIONS.size()]
	advance.text = "Entrar" if index == CAPTIONS.size() - 1 else "Continuar"
	reveal = 0.0
	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.22)
	_focus_current_panel()


func _focus_current_panel() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = artwork
	var half := artwork.get_size() * 0.5
	atlas.region = Rect2(Vector2(index % 2, index / 2) * half + Vector2(5,5), half - Vector2(10,10))
	panel.texture = atlas
	panel.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	if art_motion: art_motion.kill()
	panel.scale = Vector2.ONE
	art_motion = create_tween()
	art_motion.tween_property(panel, "scale", Vector2.ONE * 1.035, 7.0).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if not is_instance_valid(body_label):
		return
	reveal += delta * 58.0
	body_label.visible_characters = mini(int(reveal), body_label.text.length())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_finish()
		get_viewport().set_input_as_handled()


func _next() -> void:
	if changing_scene or not is_instance_valid(body_label): return
	if body_label.visible_characters >= 0 and body_label.visible_characters < body_label.text.length():
		body_label.visible_characters = -1
		reveal = body_label.text.length()
		return
	if index >= CAPTIONS.size() - 1:
		_finish()
	else:
		_show_panel(index + 1)
		_narrate(index)


## Fase 6: narración de Luma por viñeta; la música baja mientras habla.
func _narrate(panel_index: int) -> void:
	if not narrator: return
	var path := "res://assets/audio/voice/vo_prologue_%d.ogg" % panel_index
	if not ResourceLoader.exists(path): return
	narrator.stream = load(path)
	narrator.play()
	var music := get_node_or_null("PrologueMusic") as AudioStreamPlayer
	if music:
		var duck := create_tween()
		duck.tween_property(music, "volume_db", -15.0, 0.4)
		duck.tween_interval(maxf(0.5, narrator.stream.get_length() - 0.4))
		duck.tween_property(music, "volume_db", -8.0, 1.2)


func _finish() -> void:
	GameEvents.story_seen["prologue"] = true
	GameEvents.save_game()
	_start_game()


func _start_game() -> void:
	if changing_scene: return
	changing_scene = true
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)


func _qa() -> void:
	var folder := ProjectSettings.globalize_path("res://../previews/adventure/")
	var failures: Array[String] = []
	for viewport_size in [Vector2i(1440,900), Vector2i(800,640)]:
		get_window().size = viewport_size
		for i in 4:
			_show_panel(i)
			await get_tree().create_timer(0.3).timeout
			reveal = 1000.0
			await get_tree().process_frame
			if advance.get_global_rect().end.y > viewport_size.y or body_label.get_line_count() * body_label.get_line_height() > body_label.size.y:
				failures.append("Caption overflow %d %s" % [i, viewport_size])
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(folder + "prologue_%d_%d.png" % [i+1,viewport_size.x])
	var soundtrack: AudioStream = $PrologueMusic.stream
	var loops_configured: bool = (soundtrack is AudioStreamWAV and soundtrack.loop_mode == AudioStreamWAV.LOOP_FORWARD) or (soundtrack is AudioStreamOggVorbis and soundtrack.loop)
	if not loops_configured:
		failures.append("Prologue music is not configured to loop")
	$PrologueMusic.seek(soundtrack.get_length() - 0.08)
	await get_tree().create_timer(0.24).timeout
	var music_loops: bool = $PrologueMusic.playing and $PrologueMusic.get_playback_position() < 0.6
	if not music_loops: failures.append("Prologue music does not cross its loop boundary")
	var narration_files: int = 0
	for i in 4:
		if ResourceLoader.exists("res://assets/audio/voice/vo_prologue_%d.ogg" % i): narration_files += 1
	if narration_files != 4: failures.append("Prologue narration is incomplete")
	var report := {"passed":failures.is_empty(), "failures":failures, "panels":4, "viewports":["1440x900","800x640"], "music_playing":$PrologueMusic.playing, "music_loops":music_loops, "narration_files":narration_files}
	var file := FileAccess.open(folder + "prologue_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PROLOGUE_QA ", JSON.stringify(report))
	$PrologueMusic.stop()
	$PrologueMusic.stream = null
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
