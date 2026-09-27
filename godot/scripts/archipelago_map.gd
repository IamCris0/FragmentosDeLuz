extends Node3D
## Fase 7: Carta del Archipiélago. Diorama 3D de las islas sobre el mar de nubes: se elige una isla
## con izquierda/derecha (teclado, ratón o mando), se ve su progreso y se viaja con Enter / A.
## K o la cruceta arriba abren la Constelación. --qa-map ejecuta su prueba.

const UI = preload("res://scripts/ui_theme.gd")
const LevelData = preload("res://scripts/level_data.gd")
const Audio = preload("res://scripts/audio_manager.gd")
const StoryArt = preload("res://scripts/story_art.gd")
const ComicOverlay = preload("res://scripts/comic_overlay.gd")
## Interludio opcional en viñetas (assets/story/chapter2_comic*.png, ver docs/PROMPTS_IA.md).
const CH2_COMIC := [
	{"title": "LA SEÑAL IMPOSIBLE", "text": "Cuando el faro volvió a cantar, su luz cruzó el cielo más lejos que nunca… y algo le respondió."},
	{"title": "EL ARCHIPIÉLAGO", "text": "Tres islas despertaron: unas grutas de cristal, unos picos donde aún sopla el viento y un viejo observatorio bajo las estrellas."},
	{"title": "LA CONSTELACIÓN", "text": "En el escáner de Neri, cada destello encendía una estrella nueva. Juntas dibujaban un camino."},
	{"title": "EL VIAJE", "text": "Luma no dudó: «Esta vez no esperaremos a que la señal nos encuentre. Vamos a buscarla»."},
]
const ConstellationPanel = preload("res://scripts/constellation_panel.gd")
const Style = preload("res://scripts/crystal_style.gd")
const Destello = preload("res://scripts/destello.gd")
const TITLE_SCENE := "res://scenes/title_menu.tscn"
const MAP_INTRO := "Esta es la carta del archipiélago, Neri. Cada isla que despiertes quedará unida a las demás por un hilo de luz.\n\nLas Grutas Prismáticas nos esperan primero. Cuando recuperes las llaves del prisma y del viento, el Observatorio abrirá su cúpula… y sabremos quién envió la señal."

var islands: Dictionary = {}
var halos: Dictionary = {}
var order: Array[String] = []
var selected: int = 0
var camera: Camera3D
var camera_target: Vector3
var camera_eye: Vector3
var time: float = 0.0
var layer: CanvasLayer
var root: Control
var info_title: Label
var info_subtitle: Label
var info_status: Label
var info_stats: Label
var balance: Label
var travel_button: Button
var constellation_button: Button
var menu_button: Button
var island_buttons: Dictionary = {}
var constellation: Control
var fade: ColorRect
var dialog: PanelContainer
var dialog_text: Label
var dialog_open: bool = false
var comic_open: bool = false
var postcard: TextureRect
var music: AudioStreamPlayer
var ui_sound: AudioStreamPlayer
var voice: AudioStreamPlayer
var leaving: bool = false
var blades: Array[Node3D] = []


func _ready() -> void:
	GameEvents.load_game()
	if "--qa-map" in OS.get_cmdline_user_args():
		# Estado de prueba: capítulo I completo, ninguna isla del archipiélago todavía.
		for i in 7: GameEvents.fragment_ids["fragment_%d" % i] = true
		GameEvents.collected = 7
		GameEvents.puzzle_solved = true
		GameEvents.completed = true
		GameEvents.story_seen["map_intro"] = true
		GameEvents.sync_awards()
	if "--qa-art" in OS.get_cmdline_user_args():
		# Ilustraciones de ensayo en user://: interludio, postales e iconos, sin tocar el proyecto.
		StoryArt.base = load("res://tools/qa_art_fixtures.gd").build()
		for i in 7: GameEvents.fragment_ids["fragment_%d" % i] = true
		GameEvents.collected = 7
		GameEvents.puzzle_solved = true
		GameEvents.completed = true
		GameEvents.story_seen.erase("map_intro")
		GameEvents.story_seen.erase("chapter2_comic")
	GameEvents.set_cinematic(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for id in LevelData.ORDER: order.append(id)
	_build_world()
	_build_ui()
	_build_audio()
	selected = _initial_selection()
	_select(selected, true)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.2)
	if "--qa-map" in OS.get_cmdline_user_args():
		_qa.call_deferred()
	else:
		# El cómic del interludio y la guía de Luma son dos hitos independientes:
		# una partida que ya vio la guía (map_intro) antes de añadirse las
		# ilustraciones debe poder ver igualmente el cómic en su próxima visita.
		_start_story.call_deferred()
	if "--qa-art" in OS.get_cmdline_user_args():
		_qa_art.call_deferred()


## Primera visita: interludio en viñetas (si existen las ilustraciones) y después la guía de Luma.
func _start_story() -> void:
	var panels := StoryArt.comic_panels("chapter2_comic")
	if panels.size() == 4 and not GameEvents.story_seen.has("chapter2_comic"):
		comic_open = true
		# Sin foco debajo: Enter o A avanzan las viñetas en vez de pulsar «Viajar».
		get_viewport().gui_release_focus()
		var comic := ComicOverlay.new()
		comic.name = "Chapter2Comic"
		comic.setup(panels, CH2_COMIC, "vo_ch2_comic_")
		add_child(comic)
		await comic.finished
		comic_open = false
		GameEvents.story_seen["chapter2_comic"] = true
		GameEvents.save_game()
	if not GameEvents.story_seen.has("map_intro"):
		_show_intro()
	else:
		_select(selected, true)


func _initial_selection() -> int:
	for i in order.size():
		var id := order[i]
		if id != "auralia" and GameEvents.is_level_unlocked(id) and not GameEvents.is_level_done(id): return i
	return maxi(order.find(GameEvents.level), 0)


# --- Diorama ---------------------------------------------------------------------------------------

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky_islands.gdshader")
	for pair in [["zenith_color", Color("0d1430")], ["horizon_color", Color("d98f7c")], ["ground_color", Color("2a2140")],
			["sun_color", Color("ffcf9a")], ["sun_dir", Vector3(0.2, 0.08, -1.0)], ["sun_size", 0.004], ["sun_glow", 0.55],
			["star_amount", 0.8], ["cloud_amount", 0.35], ["cloud_color", Color("c98aa0")], ["aurora_amount", 0.25],
			["nebula_amount", 0.35], ["nebula_color", Color("6c4fb0")], ["horizon_sharpness", 2.0]]:
		sky_material.set_shader_parameter(pair[0], pair[1])
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a99cc4")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("8a6f94")
	env.fog_density = 0.003
	env.fog_sky_affect = 0.05
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-22, 170, 0)
	sun.light_color = Color("ffd6b0")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	plane.subdivide_width = 100
	plane.subdivide_depth = 100
	sea.mesh = plane
	sea.position = Vector3(0, -12, -20)
	var sea_material := ShaderMaterial.new()
	sea_material.shader = load("res://shaders/cloud_sea.gdshader")
	for pair in [["top_color", Color("f4c9b8")], ["shade_color", Color("6a5a8e")], ["horizon_color", Color("d98f7c")],
			["sun_direction", Vector3(0.1, 0.35, -1.0)], ["height", 3.0], ["fade_distance", 200.0], ["scale", 0.025]]:
		sea_material.set_shader_parameter(pair[0], pair[1])
	sea.material_override = sea_material
	add_child(sea)
	for id in order:
		islands[id] = _build_island(id)
	for i in range(1, order.size()):
		_thread(order[i - 1], order[i])
	# Islas de fondo sin nombre.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var rock: PackedScene = load("res://assets/environment/island_rock.glb")
	for i in 12:
		var backdrop := rock.instantiate() as Node3D
		backdrop.name = "FarIsland%d" % i
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(60, 110)
		backdrop.position = Vector3(cos(angle) * radius, rng.randf_range(-10, 10), -20 + sin(angle) * radius)
		backdrop.scale = Vector3.ONE * rng.randf_range(0.5, 1.4)
		backdrop.rotation.y = rng.randf() * TAU
		add_child(backdrop)
	camera = Camera3D.new()
	camera.name = "MapCamera"
	camera.fov = 46.0
	camera.far = 500.0
	add_child(camera)
	camera.current = true


func _level_style(id: String) -> Dictionary:
	match id:
		"grutas": return {"ground": Color("7d7299"), "crystal": Color("e1d2ff"), "glow": Color("9b6bff"), "palette": "violet"}
		"cefiro": return {"ground": Color("6aa37c"), "crystal": Color("c9fff5"), "glow": Color("4ecdc4"), "palette": "teal"}
		"observatorio": return {"ground": Color("3a4466"), "crystal": Color("fff1c9"), "glow": Color("f1d48b"), "palette": "star"}
	return {"ground": Color("3e6b4c"), "crystal": Color("7ff5e6"), "glow": Color("4ecdc4"), "palette": "teal"}


func _model(parent: Node3D, path: String, pos: Vector3, size: float, yaw: float = 0.0) -> Node3D:
	var packed: PackedScene = load(path)
	var node := packed.instantiate() as Node3D
	node.position = pos
	node.scale = Vector3.ONE * size
	node.rotation.y = yaw
	parent.add_child(node)
	return node


func _build_island(id: String) -> Node3D:
	var info: Dictionary = LevelData.level(id)
	var style := _level_style(id)
	var unlocked: bool = GameEvents.is_level_unlocked(id)
	var done: bool = GameEvents.is_level_done(id)
	var island := Node3D.new()
	island.name = "Island_" + id
	island.position = info.map_position
	add_child(island)
	_model(island, "res://assets/environment/island_rock.glb", Vector3(0, -0.15, 0), 1.25)
	var top := MeshInstance3D.new()
	top.name = "Top"
	var disc := CylinderMesh.new()
	disc.top_radius = 5.6
	disc.bottom_radius = 5.8
	disc.height = 0.3
	disc.radial_segments = 14
	top.mesh = disc
	var ground := StandardMaterial3D.new()
	ground.albedo_color = style.ground if unlocked else style.ground.darkened(0.55)
	ground.albedo_texture = load("res://assets/environment/stone_painted.png")
	ground.uv1_triplanar = true
	ground.uv1_scale = Vector3.ONE * 0.5
	top.material_override = ground
	island.add_child(top)
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	dressing.set_script(load("res://scripts/island_dressing.gd"))
	dressing.set("extent", Vector2(12.5, 12.5))
	dressing.set("dressing_seed", hash(id) % 997)
	dressing.set("crystal_color", style.crystal)
	dressing.set("glow_color", style.glow)
	dressing.set("vine_count", 16)
	island.add_child(dressing)
	match id:
		"auralia":
			_model(island, "res://assets/props/portal_ring.glb", Vector3(0, 0.15, 1.8), 0.7)
			for p in [Vector3(-3.2, 0.15, -1.5), Vector3(3.0, 0.15, -2.2), Vector3(-2.2, 0.15, 3.0)]:
				_model(island, "res://assets/environment/tree.glb", p, 0.8, p.x)
			_model(island, "res://assets/environment/column.glb", Vector3(0, 0.15, -1.2), 1.6)
			if GameEvents.completed:
				var beam := MeshInstance3D.new()
				beam.name = "BeaconBeam"
				var column := CylinderMesh.new()
				column.top_radius = 0.2
				column.bottom_radius = 0.45
				column.height = 26.0
				column.cap_top = false
				column.cap_bottom = false
				beam.mesh = column
				beam.position = Vector3(0, 13.5, -1.2)
				var beam_material := ShaderMaterial.new()
				beam_material.shader = load("res://shaders/beacon.gdshader")
				beam_material.set_shader_parameter("strength", 1.0)
				beam.material_override = beam_material
				beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				island.add_child(beam)
		"grutas":
			_model(island, "res://assets/environment/crystal_spire.glb", Vector3(0, 0.15, -0.5), 1.3)
			for p in [Vector3(-3, 0.15, 1.5), Vector3(2.8, 0.15, 2.2), Vector3(3.2, 0.15, -2.5)]:
				_model(island, "res://assets/environment/crystal_shard.glb", p, 1.4, p.z)
			for p in [Vector3(-3.8, 0.1, -2.6), Vector3(4.2, 0.1, 0.2)]:
				_model(island, "res://assets/environment/cave_rock.glb", p, 0.75, p.x)
		"cefiro":
			var mill := _model(island, "res://assets/environment/windmill.glb", Vector3(0, 0.15, -0.8), 0.55)
			var turning := mill.find_child("Blades", true, false) as Node3D
			if turning: blades.append(turning)
			for p in [Vector3(-5.5, 1.5, 3.5), Vector3(5.5, 2.5, 2.8)]:
				_model(island, "res://assets/environment/cloud_stone.glb", p, 0.45, p.x)
		"observatorio":
			_model(island, "res://assets/environment/observatory_dome.glb", Vector3(0, 0.15, -0.5), 0.55)
			_model(island, "res://assets/props/telescope.glb", Vector3(0, 0.15, -0.5), 0.45, PI)
	Style.apply(island, str(style.palette))
	var light := OmniLight3D.new()
	light.light_color = style.glow
	light.light_energy = 2.2 if unlocked else 0.4
	light.omni_range = 12.0
	light.position = Vector3(0, 4, 0)
	island.add_child(light)
	var label := Label3D.new()
	label.name = "Name"
	label.text = str(info.title).to_upper() if unlocked else "???"
	label.font = UI.font("title")
	label.font_size = 64
	label.pixel_size = 0.012
	label.outline_size = 12
	label.outline_modulate = Color(0.05, 0.04, 0.08, 0.9)
	label.modulate = UI.GOLD if unlocked else Color(0.7, 0.72, 0.78, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 7.5 if id != "observatorio" else 9.0, 0)
	island.add_child(label)
	if done:
		var star := MeshInstance3D.new()
		star.name = "DoneStar"
		star.mesh = Destello.star_mesh(0.9, 0.25, 0.22)
		var star_material := StandardMaterial3D.new()
		star_material.albedo_color = Color("fff1c9")
		star_material.emission_enabled = true
		star_material.emission = Color("ffd98a")
		star_material.emission_energy_multiplier = 3.0
		star.material_override = star_material
		star.position = Vector3(0, 10.2 if id != "observatorio" else 11.8, 0)
		island.add_child(star)
	if not unlocked:
		var veil := MeshInstance3D.new()
		veil.name = "Veil"
		var sphere := SphereMesh.new()
		sphere.radius = 8.0
		sphere.height = 12.0
		veil.mesh = sphere
		veil.position.y = 1.0
		var veil_material := StandardMaterial3D.new()
		veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		veil_material.albedo_color = Color(0.12, 0.1, 0.2, 0.55)
		veil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		veil.material_override = veil_material
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island.add_child(veil)
	var halo := MeshInstance3D.new()
	halo.name = "SelectionHalo"
	var ring := TorusMesh.new()
	ring.inner_radius = 6.6
	ring.outer_radius = 6.85
	ring.rings = 64
	ring.ring_segments = 6
	halo.mesh = ring
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.albedo_color = UI.GOLD
	halo_material.emission_enabled = true
	halo_material.emission = UI.GOLD
	halo_material.emission_energy_multiplier = 2.5
	halo.material_override = halo_material
	halo.position.y = 0.3
	halo.visible = false
	island.add_child(halo)
	halos[id] = halo
	return island


func _thread(from_id: String, to_id: String) -> void:
	var a: Vector3 = LevelData.level(from_id).map_position + Vector3.UP * 1.0
	var b: Vector3 = LevelData.level(to_id).map_position + Vector3.UP * 1.0
	var lit: bool = GameEvents.is_level_unlocked(to_id)
	var thread := MeshInstance3D.new()
	thread.name = "Thread_%s_%s" % [from_id, to_id]
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07 if lit else 0.035
	tube.bottom_radius = tube.top_radius
	tube.height = 1.0
	tube.radial_segments = 8
	thread.mesh = tube
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/light_beam.gdshader")
	material.set_shader_parameter("beam_color", Color("ffe6a8") if lit else Color(0.5, 0.5, 0.7))
	material.set_shader_parameter("intensity", 1.0 if lit else 0.3)
	thread.material_override = material
	thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var basis := Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	basis = Basis(basis.x, basis.y * a.distance_to(b), basis.z)
	add_child(thread)
	thread.global_transform = Transform3D(basis, (a + b) * 0.5)


# --- Interfaz --------------------------------------------------------------------------------------

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "MapLayer"
	add_child(layer)
	root = Control.new()
	root.name = "Map"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.build_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var shade := TextureRect.new()
	shade.name = "RightShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := GradientTexture2D.new()
	gradient.width = 256
	gradient.height = 4
	gradient.fill_from = Vector2(1, 0.5)
	gradient.fill_to = Vector2(0, 0.5)
	gradient.gradient = Gradient.new()
	gradient.gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.6])
	gradient.gradient.colors = PackedColorArray([Color(0.01, 0.02, 0.04, 0.8), Color(0.01, 0.02, 0.04, 0.45), Color(0.01, 0.02, 0.04, 0.0)])
	shade.texture = gradient
	root.add_child(shade)
	var heading := UI.label("CARTA DEL ARCHIPIÉLAGO", 34, UI.GOLD, "logo")
	heading.name = "Heading"
	heading.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.9))
	heading.add_theme_constant_override("outline_size", 6)
	root.add_child(heading)
	var chapter := UI.label("CAPÍTULO II · LA SEÑAL IMPOSIBLE", 15, UI.TEAL_LIGHT, "title_semibold")
	chapter.name = "Chapter"
	root.add_child(chapter)
	balance = UI.label("✦ %d destellos" % GameEvents.destellos, 18, Color("fff1c9"), "title_semibold")
	balance.name = "Balance"
	root.add_child(balance)
	var panel := PanelContainer.new()
	panel.name = "Info"
	panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.03, 0.05, 0.07, 0.86), Color("6f6a4e"), 22))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	postcard = TextureRect.new()
	postcard.name = "Postcard"
	postcard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	postcard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	postcard.custom_minimum_size = Vector2(300, 150)
	postcard.hide()
	box.add_child(postcard)
	info_subtitle = UI.label("", 13, UI.TEAL_LIGHT, "title_semibold")
	box.add_child(info_subtitle)
	info_title = UI.label("", 28, UI.GOLD, "title")
	info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_title.custom_minimum_size.x = 300
	box.add_child(info_title)
	info_status = UI.label("", 15, UI.INK, "body_bold")
	info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_status.custom_minimum_size.x = 300
	box.add_child(info_status)
	info_stats = UI.label("", 15, Color("d6dfd8"), "body")
	info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_stats.custom_minimum_size.x = 300
	box.add_child(info_stats)
	travel_button = _button(box, "Travel", "Viajar", _travel)
	constellation_button = _button(box, "Constellation", "Constelación", _open_constellation)
	menu_button = _button(box, "MainMenu", "Menú principal", _to_menu)
	var row := HBoxContainer.new()
	row.name = "Islands"
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)
	for i in order.size():
		var id := order[i]
		var button := Button.new()
		button.name = "Pick_" + id
		button.text = str(LevelData.level(id).title) if GameEvents.is_level_unlocked(id) else "???"
		button.custom_minimum_size = Vector2(150, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select.bind(i, false))
		row.add_child(button)
		island_buttons[id] = button
	var hint := UI.label("← → elegir isla  ·  Enter / A viajar  ·  K / cruceta arriba constelación", 13, Color("b9c9c3"), "body_bold")
	hint.name = "Hint"
	root.add_child(hint)
	dialog = PanelContainer.new()
	dialog.name = "LumaDialog"
	dialog.add_theme_stylebox_override("panel", UI.panel_style(Color(0.03, 0.05, 0.07, 0.94), Color("8d8763"), 22))
	root.add_child(dialog)
	var dialog_box := VBoxContainer.new()
	dialog_box.add_theme_constant_override("separation", 12)
	dialog.add_child(dialog_box)
	dialog_box.add_child(UI.label("LUMA · LA CARTA", 14, UI.GOLD, "title"))
	dialog_text = UI.label("", 18, UI.INK, "body")
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(620, 0)
	dialog_box.add_child(dialog_text)
	_button(dialog_box, "DialogContinue", "Continuar", _close_intro)
	dialog.hide()
	constellation = ConstellationPanel.new()
	constellation.build()
	root.add_child(constellation)
	constellation.closed.connect(func() -> void: constellation_button.grab_focus())
	GameEvents.destellos_changed.connect(func(value: int, _gained: int) -> void: balance.text = "✦ %d destellos" % value)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _button(parent: Node, id: String, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(func() -> void:
		if leaving: return
		_play_ui("ui_select")
		action.call())
	parent.add_child(button)
	return button


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	postcard.visible = postcard.texture != null and size.y >= 700
	var narrow := size.x < 1050
	root.get_node("Heading").position = Vector2(40, 26)
	root.get_node("Heading").add_theme_font_size_override("font_size", 26 if narrow else 34)
	root.get_node("Chapter").position = Vector2(42, 76 if not narrow else 64)
	balance.position = Vector2(42, 104 if not narrow else 90)
	var panel := root.get_node("Info") as PanelContainer
	panel.size = Vector2(360, 0)
	panel.size = panel.get_combined_minimum_size()
	panel.position = Vector2(size.x - panel.size.x - 36, maxf(120.0, (size.y - panel.size.y) * 0.5 - 20.0)) if not narrow else Vector2(size.x - panel.size.x - 20, 120)
	var row := root.get_node("Islands") as HBoxContainer
	row.size = row.get_combined_minimum_size()
	row.position = Vector2((size.x - row.size.x) * 0.5, size.y - 96)
	row.visible = not narrow
	var hint := root.get_node("Hint") as Label
	hint.size = Vector2(size.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, size.y - 38)
	dialog.size = Vector2(minf(700.0, size.x - 60.0), 0)
	dialog.size = dialog.get_combined_minimum_size()
	dialog.position = Vector2((size.x - dialog.size.x) * 0.5, size.y - dialog.size.y - 120)


func _select(index: int, instant: bool = false) -> void:
	selected = posmod(index, order.size())
	var id := order[selected]
	var info: Dictionary = LevelData.level(id)
	for key in halos: (halos[key] as Node3D).visible = key == id
	for key in island_buttons:
		(island_buttons[key] as Button).modulate = Color(1, 1, 1, 1) if key == id else Color(1, 1, 1, 0.6)
	var unlocked: bool = GameEvents.is_level_unlocked(id)
	var done: bool = GameEvents.is_level_done(id)
	info_subtitle.text = ("CAPÍTULO I" if id == "auralia" else "CAPÍTULO II") + " · " + (str(info.subtitle).to_upper() if unlocked else "SIN DESCUBRIR")
	info_title.text = str(info.title) if unlocked else "Isla sin descubrir"
	if not unlocked:
		var previous := LevelData.requirement(id)
		info_status.text = "Completa %s para trazar el camino." % str(LevelData.level(previous).title)
		info_stats.text = ""
	elif id == "auralia":
		info_status.text = "El faro restaurado ilumina el archipiélago." if done else "El faro aún duerme."
		info_stats.text = "Fragmentos del faro: %d / 7\nMemorias de Auralia: %d / %d" % [GameEvents.collected, GameEvents.lore_count(), GameEvents.LORE_TOTAL]
	else:
		info_status.text = ("%s obtenida. Puedes volver cuando quieras." % str(info.key_title)) if done else ("La %s te espera." % str(info.key_title))
		info_stats.text = "Destellos: %d / %d\nMemorias: %d / %d" % [GameEvents.level_destellos(id), int(info.destellos), GameEvents.level_memories(id), info.memories.size()]
	travel_button.disabled = not unlocked
	travel_button.text = "Viajar a " + str(info.title) if unlocked else "Viajar"
	var card := StoryArt.postcard(id) if unlocked else null
	postcard.texture = card
	postcard.visible = card != null and get_viewport().get_visible_rect().size.y >= 700
	if not dialog_open and not comic_open and not constellation.visible:
		if unlocked: travel_button.grab_focus.call_deferred()
		else: constellation_button.grab_focus.call_deferred()
	var center: Vector3 = info.map_position
	camera_target = center + Vector3(0, 2.0, 0)
	camera_eye = center + Vector3(-9.0, 11.0, 22.0)
	if instant:
		camera.look_at_from_position(camera_eye, camera_target)
	if not instant: _play_ui("ui_move")
	_layout()


func _process(delta: float) -> void:
	time += delta
	if camera:
		var sway := Vector3(sin(time * 0.2) * 1.5, sin(time * 0.15) * 0.6, 0)
		var eye := camera.global_position.lerp(camera_eye + sway, 1.0 - exp(-delta * 2.2))
		var look := (camera.global_position - camera.global_basis.z * 10.0).lerp(camera_target, 1.0 - exp(-delta * 3.0))
		camera.look_at_from_position(eye, look)
	for id in halos:
		var halo := halos[id] as Node3D
		if halo.visible:
			halo.rotation.y += delta * 0.4
			halo.scale = Vector3.ONE * (1.0 + sin(time * 2.0) * 0.02)
	for blade in blades:
		if is_instance_valid(blade): blade.rotation.z += delta * 0.8
	for id in islands:
		var island: Node3D = islands[id]
		island.position.y = float(LevelData.level(id).map_position.y) + sin(time * 0.5 + hash(id) % 10) * 0.25
		var star := island.get_node_or_null("DoneStar") as Node3D
		if star: star.rotation.y += delta * 1.2


func _unhandled_input(event: InputEvent) -> void:
	if leaving or comic_open or constellation.visible: return
	if dialog_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			_close_intro()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_select(selected - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_select(selected + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("constellation"):
		_open_constellation()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		menu_button.grab_focus()
		get_viewport().set_input_as_handled()


# --- Acciones --------------------------------------------------------------------------------------

func _travel() -> void:
	var id := order[selected]
	if leaving or comic_open or dialog_open or constellation.visible or not GameEvents.is_level_unlocked(id): return
	var scene := GameEvents.travel_to(id)
	if scene == "":
		info_status.text = GameEvents.save_status
		return
	leaving = true
	_play_ui("travel")
	if "--qa-map" in OS.get_cmdline_user_args(): return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fade, "color:a", 1.0, 0.9)
	if music: tween.tween_property(music, "volume_db", -40.0, 0.9)
	tween.chain().tween_callback(get_tree().change_scene_to_file.bind(scene))


func _open_constellation() -> void:
	if leaving or comic_open or dialog_open: return
	constellation.open()


func _to_menu() -> void:
	if leaving or comic_open or dialog_open or constellation.visible: return
	if not GameEvents.save_game():
		info_status.text = GameEvents.save_status
		return
	leaving = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.7)
	tween.tween_callback(get_tree().change_scene_to_file.bind(TITLE_SCENE))


func _show_intro() -> void:
	await get_tree().create_timer(1.4).timeout
	if leaving: return
	dialog_open = true
	dialog_text.text = MAP_INTRO
	dialog.show()
	_layout()
	GameEvents.story_seen["map_intro"] = true
	GameEvents.save_game()
	if voice:
		var path := "res://assets/audio/voice/vo_map_intro.ogg"
		if ResourceLoader.exists(path):
			voice.stream = load(path)
			voice.play()
	(dialog.find_child("DialogContinue", true, false) as Button).grab_focus()


func _close_intro() -> void:
	if not dialog_open: return
	dialog_open = false
	dialog.hide()
	if voice and voice.playing: voice.stop()
	_select(selected, true)


# --- Audio -----------------------------------------------------------------------------------------

func _build_audio() -> void:
	music = AudioStreamPlayer.new()
	music.name = "MapMusic"
	music.bus = "Music"
	var path: String = Audio.music_path("map")
	if path == Audio.music_path("exploration"): path = Audio.music_path("title")
	if path != "":
		music.stream = Audio.looped(path)
		music.volume_db = -5.0
		add_child(music)
		music.play()
	var wind := AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.bus = "Ambience"
	wind.stream = Audio.looped("res://assets/audio/wind_soft.wav")
	wind.volume_db = -18.0
	add_child(wind)
	wind.play()
	ui_sound = AudioStreamPlayer.new()
	ui_sound.name = "UISound"
	ui_sound.bus = "Effects"
	ui_sound.volume_db = -12.0
	add_child(ui_sound)
	voice = AudioStreamPlayer.new()
	voice.name = "Voice"
	voice.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Effects"
	add_child(voice)
	GameEvents.sound_requested.connect(_play_ui)


func _play_ui(cue: String) -> void:
	if not ui_sound or time < 0.5: return
	for extension in ["wav", "ogg"]:
		var path: String = "res://assets/audio/%s.%s" % [cue, extension]
		if ResourceLoader.exists(path):
			ui_sound.stream = load(path)
			ui_sound.play()
			return


# --- Validación --------------------------------------------------------------------------------------

func _qa() -> void:
	var folder := preload("res://tools/qa_support.gd").output_folder("levels")
	DirAccess.make_dir_recursive_absolute(folder)
	var checks: Array[String] = []
	var failures: Array[String] = []
	var check := func(ok: bool, label: String) -> void:
		if ok: checks.append(label)
		else:
			failures.append(label)
			push_error("QA_FAILED: " + label)
	await get_tree().create_timer(2.5).timeout
	check.call(islands.size() == 4 and camera.current, "Four islands on the live map")
	check.call(get_node_or_null("CloudSea") != null, "Cloud sea under the archipelago")
	check.call(order[selected] == "grutas", "Map highlights the next island to explore")
	check.call(not travel_button.disabled and get_viewport().gui_get_focus_owner() == travel_button, "Travel button focused")
	await _capture(folder + "map_01_grutas.png")
	_select(order.find("observatorio"))
	await get_tree().create_timer(1.5).timeout
	check.call(travel_button.disabled and info_title.text == "Isla sin descubrir", "Locked island cannot be travelled to")
	check.call((islands["observatorio"] as Node3D).get_node_or_null("Veil") != null, "Locked island is veiled")
	await _capture(folder + "map_02_bloqueada.png")
	var before := order[selected]
	Input.action_press("ui_left")
	await get_tree().process_frame
	Input.action_release("ui_left")
	var event := InputEventAction.new()
	event.action = "ui_left"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(0.3).timeout
	check.call(order[selected] != before, "Left input changes the selected island")
	_open_constellation()
	await get_tree().create_timer(0.8).timeout
	check.call(constellation.visible, "Constellation opens from the map")
	await _capture(folder + "map_03_constelacion.png")
	constellation.close()
	for viewport_size in [Vector2i(800, 640), Vector2i(1024, 768)]:
		get_window().size = viewport_size
		await get_tree().create_timer(0.4).timeout
		var panel := root.get_node("Info") as Control
		check.call(panel.get_global_rect().end.x <= viewport_size.x and panel.get_global_rect().end.y <= viewport_size.y, "Map panel fits %dx%d" % [viewport_size.x, viewport_size.y])
		if viewport_size.x == 800: await _capture(folder + "map_04_800.png")
	get_window().size = Vector2i(1440, 900)
	await get_tree().create_timer(0.3).timeout
	_select(order.find("grutas"), true)
	_travel()
	check.call(leaving and GameEvents.level == "grutas", "Travel sets the destination island")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var file := FileAccess.open(folder + "map_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MAP_QA ", JSON.stringify(report))
	await preload("res://tools/qa_support.gd").finish(get_tree(), 0 if failures.is_empty() else 1)


## --qa-art: el interludio en viñetas, la guía de Luma, las postales y los iconos con imágenes de ensayo.
func _qa_art() -> void:
	var folder := preload("res://tools/qa_support.gd").output_folder("levels")
	DirAccess.make_dir_recursive_absolute(folder)
	var checks: Array[String] = []
	var failures: Array[String] = []
	var check := func(ok: bool, label: String) -> void:
		if ok: checks.append(label)
		else:
			failures.append(label)
			push_error("QA_FAILED: " + label)
	await get_tree().create_timer(1.0).timeout
	var comic := get_node_or_null("Chapter2Comic")
	check.call(comic != null and comic.panels.size() == 4, "A 2x2 sheet becomes four comic panels")
	check.call(comic != null and comic_open, "The interlude plays before Luma's map guide")
	if comic:
		await get_tree().create_timer(0.8).timeout
		await _capture(folder + "art_01_interludio.png")
		var before: Texture2D = comic.image.texture
		comic.next()
		comic.next()
		await get_tree().create_timer(0.4).timeout
		check.call(comic.index == 1 and comic.image.texture != before, "Continue shows the next panel")
		for i in 8:
			if not is_instance_valid(comic) or comic.done: break
			comic.next()
			comic.next()
			await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(2.2).timeout
	check.call(not comic_open and GameEvents.story_seen.has("chapter2_comic"), "The interlude ends and is remembered")
	check.call(dialog_open and dialog.visible, "Luma's map guide follows the interlude")
	_close_intro()
	await get_tree().create_timer(0.3).timeout
	_select(order.find("auralia"))
	await get_tree().create_timer(0.8).timeout
	check.call(postcard.visible and postcard.texture != null, "Postcard shows for an unlocked island")
	var info := root.get_node("Info") as Control
	var view := get_viewport().get_visible_rect().size
	check.call(info.get_global_rect().end.y <= view.y and info.get_global_rect().position.y >= 0.0, "Info panel with postcard fits the screen")
	await _capture(folder + "art_02_postal.png")
	_select(order.find("observatorio"))
	await get_tree().create_timer(0.4).timeout
	check.call(not postcard.visible, "Locked islands keep their postcard hidden")
	constellation.open()
	await get_tree().create_timer(0.4).timeout
	constellation._select("pulse_wide")
	await get_tree().create_timer(0.3).timeout
	check.call(constellation.info_icon.visible and constellation.info_icon.texture is AtlasTexture, "Skill icon comes from the 4x4 sheet")
	await _capture(folder + "art_03_icono.png")
	constellation.close()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var file := FileAccess.open(folder + "art_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ART_QA ", JSON.stringify(report))
	await preload("res://tools/qa_support.gd").finish(get_tree(), 0 if failures.is_empty() else 1)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
