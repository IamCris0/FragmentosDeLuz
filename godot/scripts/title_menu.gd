extends Node
## Menú principal (fase 6): Auralia en vivo de fondo, logotipo, partida, prólogo, ajustes y créditos.
## Argumentos: --skip-prologue / --replay-prologue / --qa pasan directamente al flujo anterior.
## --qa-menu ejecuta la validación del menú y escribe previews/adventure/menu_report.json.

const UI = preload("res://scripts/ui_theme.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const CreditsRoll = preload("res://scripts/credits_roll.gd")
const Audio = preload("res://scripts/audio_manager.gd")
const MAIN_SCENE := "res://scenes/main_island.tscn"
const PROLOGUE_SCENE := "res://scenes/prologue_comic.tscn"
const LevelData = preload("res://scripts/level_data.gd")
const VERSION_TEXT := "Capítulos I y II · versión 0.7"

var world: Node3D
var camera: Camera3D
var orbit_angle: float = 0.0
var layer: CanvasLayer
var root: Control
var logo_box: VBoxContainer
var menu_box: VBoxContainer
var buttons: Dictionary = {}
var settings: PanelContainer
var credits_shade: ColorRect
var credits: Control
var fade: ColorRect
var confirm: ConfirmationDialog
var music: AudioStreamPlayer
var ui_sound: AudioStreamPlayer
var leaving: bool = false
var has_save: bool = false
var time: float = 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--qa-menu" in args and ("--qa" in args or "--qa-prologue" in args or "--skip-prologue" in args or "--replay-prologue" in args):
		get_tree().change_scene_to_file.call_deferred(PROLOGUE_SCENE)
		return
	GameEvents.load_game()
	GameEvents.set_cinematic(false)
	get_tree().paused = false
	has_save = GameEvents.has_saved_progress()
	_build_world()
	_build_ui()
	_build_audio()
	_intro()
	if "--qa-menu" in args:
		_qa.call_deferred()


# --- Escenario 3D en vivo ----------------------------------------------------------------------

func _build_world() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	world = packed.instantiate() as Node3D
	world.set_script(null)
	for title in ["HUDLayer", "AudioManager"]:
		var node := world.get_node_or_null(title)
		if node:
			world.remove_child(node)
			node.free()
	var player := world.get_node_or_null("Player")
	if player:
		player.set_script(null)
		var tree := player.get_node_or_null("AnimationTree") as AnimationTree
		if tree: tree.active = false
		var own_camera := player.find_child("Camera3D", true, false) as Camera3D
		if own_camera: own_camera.current = false
		player.position = Vector3(0.6, 0.02, 3.2)
		(player.get_node("Visual") as Node3D).rotation.y = PI
	add_child(world)
	if player:
		var animator := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator:
			for clip in animator.get_animation_list():
				if "idle" in str(clip).to_lower():
					animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					animator.play(clip)
					break
	if GameEvents.completed:
		var beacon := Node3D.new()
		beacon.name = "BeaconRestoration"
		beacon.set_script(load("res://scripts/beacon_restoration.gd"))
		world.add_child(beacon)
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = 48.0
	camera.far = 400.0
	add_child(camera)
	camera.current = true
	orbit_angle = 0.35
	_place_camera()


func _place_camera() -> void:
	var center := Vector3(0, 4.5, -44)
	var radius := 78.0
	var eye := center + Vector3(sin(orbit_angle) * radius, 24.0 + sin(time * 0.15) * 2.0, cos(orbit_angle) * radius)
	camera.look_at_from_position(eye, center + Vector3(-sin(orbit_angle) * 12.0, 0, 0))


func _process(delta: float) -> void:
	time += delta
	if camera:
		orbit_angle += delta * 0.022
		_place_camera()
	if logo_box:
		logo_box.modulate = Color(1, 1, 1, logo_box.modulate.a).lerp(Color(1.06, 1.03, 0.95, logo_box.modulate.a), 0.5 + 0.5 * sin(time * 1.3))


# --- Interfaz ----------------------------------------------------------------------------------

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "MenuLayer"
	add_child(layer)
	root = Control.new()
	root.name = "Menu"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.build_theme()
	layer.add_child(root)
	var shade := TextureRect.new()
	shade.name = "LeftShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := GradientTexture2D.new()
	gradient.width = 256
	gradient.height = 4
	gradient.fill_from = Vector2(0, 0.5)
	gradient.fill_to = Vector2(1, 0.5)
	gradient.gradient = Gradient.new()
	gradient.gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.75])
	gradient.gradient.colors = PackedColorArray([Color(0.01, 0.025, 0.04, 0.82), Color(0.01, 0.025, 0.04, 0.5), Color(0.01, 0.025, 0.04, 0.0)])
	shade.texture = gradient
	root.add_child(shade)
	logo_box = VBoxContainer.new()
	logo_box.name = "Logo"
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_box.add_theme_constant_override("separation", -6)
	root.add_child(logo_box)
	var line_one := UI.label("FRAGMENTOS", 74, UI.GOLD, "logo")
	var line_two := UI.label("DE LUZ", 74, UI.GOLD, "logo")
	for line in [line_one, line_two]:
		line.name = "Line"
		line.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.9))
		line.add_theme_constant_override("outline_size", 8)
		line.add_theme_color_override("font_shadow_color", Color(0.95, 0.72, 0.25, 0.35))
		line.add_theme_constant_override("shadow_offset_y", 0)
		line.add_theme_constant_override("shadow_outline_size", 18)
		logo_box.add_child(line)
	var subtitle := UI.label("CAPÍTULO II  ·  LA SEÑAL IMPOSIBLE" if GameEvents.completed else "CAPÍTULO I  ·  EL FARO DORMIDO", 18, UI.TEAL_LIGHT, "title_semibold")
	subtitle.name = "Chapter"
	logo_box.add_child(subtitle)
	menu_box = VBoxContainer.new()
	menu_box.name = "Buttons"
	menu_box.add_theme_constant_override("separation", 6)
	root.add_child(menu_box)
	if has_save:
		_menu_button("Continue", "Continuar", _continue)
	_menu_button("NewGame", "Nueva partida", _new_game_requested)
	_menu_button("Prologue", "Ver prólogo", _watch_prologue)
	_menu_button("Settings", "Ajustes", _open_settings)
	_menu_button("Credits", "Créditos", _open_credits)
	_menu_button("Quit", "Salir", _quit)
	var footer := UI.label(VERSION_TEXT, 12, Color("9fb3ad"))
	footer.name = "Version"
	root.add_child(footer)
	var hint := UI.label("Enter / A  seleccionar  ·  Esc / B  volver", 12, Color("9fb3ad"))
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)
	settings = SettingsPanel.new()
	settings.build()
	root.add_child(settings)
	settings.closed.connect(_settings_closed)
	credits_shade = ColorRect.new()
	credits_shade.name = "CreditsShade"
	credits_shade.color = Color(0.01, 0.015, 0.025, 0.78)
	credits_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits_shade.hide()
	root.add_child(credits_shade)
	confirm = ConfirmationDialog.new()
	confirm.name = "ConfirmNewGame"
	confirm.title = "Nueva partida"
	confirm.dialog_text = "Ya tienes una partida guardada.\n¿Empezar de nuevo? Se reemplazará el progreso del capítulo."
	confirm.ok_button_text = "Empezar de nuevo"
	confirm.cancel_button_text = "Cancelar"
	confirm.confirmed.connect(_start_new_game)
	root.add_child(confirm)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _menu_button(id: String, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(300, 46)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", UI.font("title_semibold"))
	button.add_theme_font_size_override("font_size", 21)
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.content_margin_left = 22
	var active := StyleBoxFlat.new()
	active.bg_color = Color(0.3, 0.8, 0.75, 0.12)
	active.border_color = UI.GOLD
	active.border_width_left = 3
	active.content_margin_left = 30
	active.corner_radius_top_right = 4
	active.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", clear)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_stylebox_override("focus", active)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_color_override("font_color", Color("e7e0c8"))
	button.add_theme_color_override("font_focus_color", UI.GOLD)
	button.add_theme_color_override("font_hover_color", UI.GOLD)
	button.pressed.connect(_on_menu_pressed.bind(action))
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_play_ui.bind("ui_move"))
	menu_box.add_child(button)
	buttons[id] = button
	return button


func _on_menu_pressed(action: Callable) -> void:
	if leaving: return
	_play_ui("ui_select")
	action.call()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var narrow := size.x < 1000 or size.y < 720
	var left := 64.0 if not narrow else 36.0
	for line in logo_box.get_children():
		if line.name == "Line": line.add_theme_font_size_override("font_size", 50 if narrow else 74)
	logo_box.position = Vector2(left, size.y * (0.1 if narrow else 0.14))
	logo_box.size = Vector2(size.x * 0.6, 0)
	var logo_height := logo_box.get_combined_minimum_size().y
	menu_box.position = Vector2(left - 22.0, logo_box.position.y + logo_height + (22.0 if narrow else 48.0))
	menu_box.size = Vector2(320, 0)
	var footer := root.get_node("Version") as Control
	footer.position = Vector2(left, size.y - 34)
	var hint := root.get_node("Hint") as Label
	hint.size = Vector2(420, 20)
	hint.position = Vector2(size.x - 440, size.y - 34)
	settings.size = settings.get_combined_minimum_size()
	settings.position = ((size - settings.size) * 0.5).max(Vector2.ZERO)


func _intro() -> void:
	logo_box.modulate.a = 0.0
	menu_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.6)
	tween.parallel().tween_property(logo_box, "modulate:a", 1.0, 1.8).set_delay(0.6)
	tween.tween_property(menu_box, "modulate:a", 1.0, 0.7)
	_focus_menu("Continue" if has_save else "NewGame")


func _focus_menu(id: String) -> void:
	var button: Button = buttons.get(id, buttons.get("NewGame"))
	if button: button.grab_focus.call_deferred()


# --- Audio -------------------------------------------------------------------------------------

func _build_audio() -> void:
	music = AudioStreamPlayer.new()
	music.name = "TitleMusic"
	music.bus = "Music"
	var path: String = Audio.music_path("title")
	if path != "":
		music.stream = Audio.looped(path)
		music.volume_db = -4.0
		add_child(music)
		music.play()
	var wind := AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.bus = "Ambience"
	wind.stream = Audio.looped("res://assets/audio/wind_soft.wav")
	wind.volume_db = -20.0
	add_child(wind)
	wind.play()
	ui_sound = AudioStreamPlayer.new()
	ui_sound.name = "UISound"
	ui_sound.bus = "Effects"
	ui_sound.volume_db = -12.0
	add_child(ui_sound)


func _play_ui(cue: String) -> void:
	if not ui_sound or leaving or time < 1.0: return
	for extension in ["wav", "ogg"]:
		var path: String = "res://assets/audio/%s.%s" % [cue, extension]
		if ResourceLoader.exists(path):
			ui_sound.stream = load(path)
			ui_sound.play()
			return


# --- Acciones ----------------------------------------------------------------------------------

func _continue() -> void:
	# Fase 7: la partida continúa en la isla donde se guardó.
	var scene := LevelData.scene_for(GameEvents.level)
	_leave(scene if ResourceLoader.exists(scene) else MAIN_SCENE)


func _new_game_requested() -> void:
	if has_save:
		confirm.popup_centered(Vector2i(480, 170))
		confirm.get_cancel_button().grab_focus.call_deferred()
	else:
		_start_new_game()


func _start_new_game() -> void:
	if leaving: return
	GameEvents.reset()
	_leave(PROLOGUE_SCENE)


func _watch_prologue() -> void:
	GameEvents.story_seen.erase("prologue")
	_leave(PROLOGUE_SCENE)


func _open_settings() -> void:
	menu_box.hide()
	logo_box.hide()
	settings.open()
	_layout()


func _settings_closed() -> void:
	menu_box.show()
	logo_box.show()
	_focus_menu("Settings")


func _open_credits() -> void:
	if credits: return
	menu_box.hide()
	logo_box.hide()
	credits_shade.show()
	credits = CreditsRoll.new()
	credits.build(false)
	root.add_child(credits)
	root.move_child(credits, credits_shade.get_index() + 1)
	credits.finished.connect(_close_credits)
	credits.start()


func _close_credits() -> void:
	if not credits: return
	credits.queue_free()
	credits = null
	credits_shade.hide()
	menu_box.show()
	logo_box.show()
	_focus_menu("Credits")


func _quit() -> void:
	if leaving: return
	leaving = true
	for button in buttons.values(): (button as Button).disabled = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(get_tree().quit)


func _leave(scene: String) -> void:
	if leaving: return
	leaving = true
	menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button in buttons.values(): (button as Button).disabled = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fade, "color:a", 1.0, 0.9)
	if music: tween.tween_property(music, "volume_db", -40.0, 0.9)
	tween.chain().tween_callback(get_tree().change_scene_to_file.bind(scene))


func _unhandled_input(event: InputEvent) -> void:
	if credits and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		_close_credits()
		get_viewport().set_input_as_handled()


# --- Validación --------------------------------------------------------------------------------

func _qa() -> void:
	var folder := ProjectSettings.globalize_path("res://../previews/adventure/")
	DirAccess.make_dir_recursive_absolute(folder)
	var checks: Array[String] = []
	var failures: Array[String] = []
	var check := func(ok: bool, label: String) -> void:
		if ok: checks.append(label)
		else:
			failures.append(label)
			push_error("QA_FAILED: " + label)
	await get_tree().create_timer(2.8).timeout
	check.call(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title_menu.tscn", "Title menu is the game entry")
	check.call(camera.current and world.get_node_or_null("Zones/Entrance") != null, "Live 3D island backdrop")
	check.call(world.get_node_or_null("HUDLayer") == null and world.get_script() == null, "Backdrop strips gameplay nodes")
	check.call(fade.color.a < 0.05 and logo_box.modulate.a > 0.95, "Intro fade reveals logo")
	check.call(buttons.has("NewGame") and buttons.has("Settings") and buttons.has("Credits") and buttons.has("Quit"), "Menu actions present")
	check.call(get_viewport().gui_get_focus_owner() is Button, "Keyboard or gamepad focus on first action")
	var before := camera.global_position
	await get_tree().create_timer(0.5).timeout
	check.call(camera.global_position.distance_to(before) > 0.01, "Backdrop camera drifts")
	if music: check.call(music.playing, "Title music plays")
	await _capture(folder + "menu_01_title.png")
	_open_settings()
	await get_tree().create_timer(0.3).timeout
	check.call(settings.visible and settings.sliders.has("Voice"), "Settings include voice volume")
	await _capture(folder + "menu_02_settings.png")
	settings.close()
	await get_tree().process_frame
	check.call(not settings.visible and get_viewport().gui_get_focus_owner() == buttons["Settings"], "Closing settings restores focus")
	for viewport_size in [Vector2i(800, 640), Vector2i(1024, 768)]:
		get_window().size = viewport_size
		await get_tree().create_timer(0.35).timeout
		var last: Button = menu_box.get_child(menu_box.get_child_count() - 1)
		check.call(last.get_global_rect().end.y <= viewport_size.y - 40 and logo_box.get_global_rect().position.y >= 0, "Menu fits %dx%d" % [viewport_size.x, viewport_size.y])
		if viewport_size.x == 800: await _capture(folder + "menu_03_800.png")
	get_window().size = Vector2i(1440, 900)
	await get_tree().create_timer(0.3).timeout
	_open_credits()
	await get_tree().create_timer(1.2).timeout
	check.call(credits != null and credits.running and credits.progress() > 0.0, "Credits scroll")
	await _capture(folder + "menu_04_credits.png")
	_close_credits()
	check.call(credits == null and menu_box.visible, "Credits close back to menu")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	var file := FileAccess.open(folder + "menu_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MENU_QA ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
