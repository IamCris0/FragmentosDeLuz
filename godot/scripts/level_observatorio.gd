extends "res://scripts/level_controller.gd"
## Fase 7: Observatorio Estelar. Puzle de la constelación «La Farolera», anillos giratorios del
## orrery, combate contra el Heraldo del Eclipse y final del Capítulo II con Maren, el telescopio
## y los créditos.

const Style = preload("res://scripts/crystal_style.gd")
## Constelación «La Farolera»: posiciones locales del jardín y orden correcto de las baldosas
## (también las usa tools/levels/observatorio_builder.gd).
const TILES := [Vector2(0, -6.5), Vector2(-2.6, -4.0), Vector2(2.6, -4.0), Vector2(-3.6, 0.0), Vector2(3.6, 0.0), Vector2(-2.0, 3.4), Vector2(2.0, 3.4)]
const ORDER := [0, 1, 3, 5, 6, 4, 2]
const HINTS := [
	"Sube la gran escalinata. Los vigías disparan desde lo alto: esquiva con C o usa Q de cerca.",
	"Pisa las estrellas en el orden de la estela: empieza por la estrella mayor y sigue la silueta del farol.",
	"Sube a un anillo del orrery cuando roce el borde y bájate al llegar al otro lado.",
	"Enciende el pilar estelar que brilla para romper el escudo. Con el núcleo expuesto, acércate y pulsa Q.",
]
const MAREN := "MAREN · LA ÚLTIMA FAROLERA"
const StoryArt = preload("res://scripts/story_art.gd")
const ComicOverlay = preload("res://scripts/comic_overlay.gd")
## Epílogo opcional en viñetas antes de los créditos (assets/story/chapter2_ending*.png).
const ENDING_COMIC := [
	{"title": "LA FAROLERA", "text": "Maren sonrió por última vez bajo la cúpula. Su luz no se apagó: se quedó en el telescopio, apuntando al futuro."},
	{"title": "EL HILO DE LUZ", "text": "Desde el Observatorio, un rayo unió las islas. Prisma, viento y estrella volvieron a hablar entre ellas."},
	{"title": "LUMA", "text": "Luma ya no esperaba una respuesta. Por primera vez en cien años, era ella quien la escribía."},
	{"title": "MÁS ALLÁ", "text": "Y en el borde del escáner de Neri, una señal nueva parpadeó… mucho más lejos."},
]

var altar: Node
var boss: Node
var tiles: Array = []
var progress: int = 0
var mistakes: int = 0
var lines: Array[MeshInstance3D] = []
var reward: Node
var bridge: Node
var arena: Area3D
var memory: Node
var exit_gate: Node
var maren: Node3D
var fight_started: bool = false


func setup_level() -> void:
	Style.apply(self, "star")
	altar = get_node("Zones/Dome/KeyAltar")
	boss = get_node("Zones/Dome/Heraldo")
	boss.arena_center = get_node("Zones/Dome").global_position
	boss.defeated.connect(_on_boss_defeated)
	bridge = get_node("StarBridge")
	for node in get_node("Zones/Garden/Constellation").get_children():
		if node.is_in_group("destello"): reward = node
	arena = get_node("Zones/Dome/ArenaTrigger")
	arena.collision_layer = 0
	arena.collision_mask = 2
	arena.body_entered.connect(_on_arena_entered)
	memory = get_node("Zones/Dome/Memory_lore_o2")
	exit_gate = get_node("Zones/Dome/ExitGate")
	for i in TILES.size():
		var tile: Node = get_node("Zones/Garden/Constellation/StarTile_%d" % i)
		tile.stepped.connect(_on_tile_stepped)
		tiles.append(tile)
	if GameEvents.level_flag("constellation"):
		progress = ORDER.size()
		for tile in tiles: tile.set_lit(true)
		_draw_lines()
		if reward: reward.reveal()
	var defeated: bool = GameEvents.purified_ids.has("Heraldo")
	memory.visible = defeated
	memory.set_process(defeated)
	if not defeated: memory.remove_from_group("interactable")
	if defeated: altar.reveal(false)
	director.register("observatorio_intro", _seq_intro)
	director.register("observatorio_bridge", _seq_bridge)
	director.register("observatorio_boss", _seq_boss)
	director.register("observatorio_maren", _seq_maren)
	director.register("observatorio_finale", _seq_finale)
	director.credits_chapter = 2
	director.credits_center = get_node("Zones/Dome").global_position + Vector3(0, 4, 0)
	director.credits_heading = "El archipiélago vuelve a brillar"
	_update_objective()
	_update_hint()


# --- Constelación ----------------------------------------------------------------------------------

func _on_tile_stepped(index: int) -> void:
	if progress >= ORDER.size(): return
	if tiles[index].lit: return
	if index == ORDER[progress]:
		tiles[index].set_lit(true)
		progress += 1
		GameEvents.sound_requested.emit("star_step")
		_draw_lines()
		if progress >= ORDER.size(): _constellation_complete()
		else: _hint_next()
	else:
		mistakes += 1
		progress = 0
		for tile in tiles: tile.set_lit(false)
		_draw_lines()
		GameEvents.sound_requested.emit("wrong")
		GameEvents.toast_requested.emit("Las estrellas se apagan. Empieza por la estrella mayor de la estela.")
		_hint_next()


func _hint_next() -> void:
	for tile in tiles: tile.hinted = false
	if mistakes >= 2 and progress < ORDER.size():
		tiles[ORDER[progress]].hinted = true


func _draw_lines() -> void:
	for line in lines: line.queue_free()
	lines.clear()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/light_beam.gdshader")
	material.set_shader_parameter("beam_color", Color(1.0, 0.86, 0.55))
	for k in range(1, mini(progress, ORDER.size())):
		var a: Vector3 = tiles[ORDER[k - 1]].global_position + Vector3.UP * 0.12
		var b: Vector3 = tiles[ORDER[k]].global_position + Vector3.UP * 0.12
		var line := MeshInstance3D.new()
		line.name = "ConstellationLine"
		var tube := CylinderMesh.new()
		tube.top_radius = 0.05
		tube.bottom_radius = 0.05
		tube.height = 1.0
		tube.radial_segments = 8
		line.mesh = tube
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		var basis := Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		basis = Basis(basis.x, basis.y * a.distance_to(b), basis.z)
		line.global_transform = Transform3D(basis, (a + b) * 0.5)
		lines.append(line)


func _constellation_complete() -> void:
	GameEvents.set_level_flag("constellation")
	GameEvents.sound_requested.emit("constellation_complete")
	GameEvents.toast_requested.emit("¡La Farolera brilla! Un puente de estrellas cruza hacia el orrery.")
	bridge.set_open(true)
	if reward: reward.reveal()
	for tile in tiles: tile.hinted = false
	_update_objective()
	_update_hint()
	if not qa_mode: await play_when_free("observatorio_bridge")


# --- Jefe --------------------------------------------------------------------------------------------

func _on_arena_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or fight_started or GameEvents.purified_ids.has("Heraldo"): return
	fight_started = true
	if not qa_mode and director.should_play("observatorio_boss"):
		await play_when_free("observatorio_boss")
	begin_fight()


func begin_fight() -> void:
	fight_started = true
	boss_active = true
	var audio := get_node_or_null("AudioManager")
	if audio: audio.target_theme = 1
	boss.start_fight()
	GameEvents.set_objective("Purifica al Heraldo del Eclipse")
	_update_hint()


func _on_boss_defeated() -> void:
	boss_active = false
	var audio := get_node_or_null("AudioManager")
	if audio: audio.target_theme = 0
	GameEvents.set_objective("Escucha a la voz del Observatorio")
	altar.reveal(not qa_mode)
	memory.visible = true
	memory.set_process(true)
	if not memory.is_in_group("interactable"): memory.add_to_group("interactable")
	_update_hint()
	if qa_mode:
		_dissolve_boss(0.1)
		return
	await play_when_free("observatorio_maren")
	_update_objective()


func _dissolve_boss(duration: float) -> void:
	var visual := boss.get_node_or_null("Visual") as Node3D
	var tween := create_tween().set_parallel(true)
	tween.tween_property(boss, "scale", Vector3.ONE * 0.05, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if visual: tween.tween_property(visual, "rotation:y", visual.rotation.y + TAU, duration)
	tween.chain().tween_callback(boss.hide)


# --- Estado, pistas y diálogos -----------------------------------------------------------------------

func _update_objective() -> void:
	var text := "Sube la escalinata hacia el Jardín de Constelaciones"
	if GameEvents.is_level_done(level_id): text = "El archipiélago vuelve a unirse. Explora o cruza el portal"
	elif GameEvents.purified_ids.has("Heraldo"): text = "Toma la Llave de la Estrella y alinea el telescopio"
	elif GameEvents.zone >= 3: text = "Entra en la cúpula y enfréntate al Heraldo del Eclipse"
	elif GameEvents.zone >= 2: text = "Cruza los anillos del orrery hacia la cúpula"
	elif GameEvents.level_flag("constellation"): text = "Cruza el puente de estrellas hacia el orrery"
	elif GameEvents.zone >= 1: text = "Dibuja la constelación de la estela pisando sus estrellas"
	GameEvents.set_objective(text)


func _update_hint() -> void:
	if GameEvents.is_level_done(level_id):
		GameEvents.set_hint("")
		return
	if GameEvents.purified_ids.has("Heraldo"):
		GameEvents.set_hint("Toma la llave del altar para alinear el telescopio.")
		return
	if GameEvents.zone == 1 and GameEvents.level_flag("constellation"):
		GameEvents.set_hint("El puente de estrellas está abierto al norte del jardín.")
		return
	GameEvents.set_hint(HINTS[clampi(GameEvents.zone, 0, 3)])


func zone_entered(_index: int) -> void:
	_update_objective()
	_update_hint()


func theme_for_zone(_index: int) -> int:
	return 1 if boss_active else 0


func audio_spots() -> Array:
	return [["DomeHum", Vector3(0, 10, -96), "crystal_hum", -8.0, 22.0], ["GardenHum", Vector3(0, 7, -35), "crystal_hum", -14.0, 14.0]]


func intro() -> void:
	if GameEvents.is_level_done(level_id) and director.should_play("observatorio_finale"):
		await key_obtained()
		return
	if director.should_play("observatorio_intro"):
		await director.play("observatorio_intro")
	if not GameEvents.story_seen.has("observatorio_arrival"):
		await say_story("observatorio_arrival", "LUMA · OBSERVATORIO ESTELAR", "Conozco este lugar… Aquí trabajaba Maren, la farolera que me creó. La señal nace bajo esa cúpula, Neri.\n\nNo sé qué nos espera arriba. Pero esta vez no voy a quedarme esperando: vamos juntos.")
	_update_hint()


func luma_talk() -> void:
	if GameEvents.is_level_done(level_id):
		GameEvents.story("observatorio_luma_done", "LUMA", "Maren me dejó cuidando la luz. Ahora sé que no estaba sola: te tenía a ti, aunque aún no lo supiera.")
	elif GameEvents.level_flag("constellation"):
		GameEvents.story("observatorio_luma_dome", "LUMA", "Si el Heraldo se esconde tras su escudo, busca el pilar que brille. La luz de las estrellas es lo único que lo atraviesa.")
	else:
		GameEvents.story("observatorio_luma_stars", "LUMA", "La estela muestra a «La Farolera». Empieza por la estrella mayor, la del asa, y recorre el contorno del farol sin saltarte ninguna.")


func key_obtained() -> void:
	_update_objective()
	_update_hint()
	if qa_mode and not director.enabled: return
	await play_when_free("observatorio_finale")
	await _ending_comic()
	var to_menu: bool = await director.roll_credits()
	finish_finale(to_menu)


func _ending_comic() -> void:
	var panels := StoryArt.comic_panels("chapter2_ending")
	if panels.size() != 4: return
	get_viewport().gui_release_focus()
	var comic := ComicOverlay.new()
	comic.name = "EndingComic"
	comic.setup(panels, ENDING_COMIC, "vo_ch2_ending_")
	add_child(comic)
	await comic.finished


func finish_finale(to_menu: bool) -> void:
	GameEvents.save_game()
	GameEvents.set_cinematic(false)
	if to_menu:
		get_tree().change_scene_to_file("res://scenes/title_menu.tscn")
		return
	player.global_position = get_node("Zones/Dome").global_position + Vector3(0, 0.2, 7.5)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = PI
	player.camera.current = true
	player.locked = false
	hud.root.visible = true
	var audio := get_node_or_null("AudioManager")
	if audio: audio.clear_cinematic_music()
	var reveal := create_tween()
	reveal.tween_property(director.fade_rect, "color:a", 0.0, 1.2)
	GameEvents.toast_requested.emit("El archipiélago vuelve a brillar. Puedes seguir explorando.")
	_update_objective()


# --- Cinemáticas -------------------------------------------------------------------------------------

func _seq_intro() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("observatorio")
	director.fade_rect.color.a = 1.0
	director.fade(0.0, 2.0, false)
	director.title_card("OBSERVATORIO ESTELAR", "La señal imposible", 5.0)
	await director.path([Vector3(30, 36, -140), Vector3(20, 26, -118), Vector3(12, 18, -104)],
		[Vector3(0, 14, -96), Vector3(0, 12, -96), Vector3(0, 10, -96)], 7.0, 48.0, 44.0)
	director.say("LUMA", "La señal nace aquí. Bajo esa cúpula.", "vo_cine_obs_1", 3.0)
	await director.path([Vector3(-16, 14, -40), Vector3(-8, 10, -30), Vector3(-2, 8, -22)],
		[Vector3(0, 6, -36), Vector3(0, 6, -34), Vector3(0, 4, -18)], 6.0, 50.0, 48.0)
	director.say("LUMA", "Vamos juntos, Neri.", "vo_cine_obs_2", 2.4)
	await director.path([Vector3(0, 7, -12), Vector3(0, 3.5, -2), Vector3(1.2, 1.9, 9.6)],
		[Vector3(0, 2, -8), Vector3(0, 1.4, 2), Vector3(0, 1.5, 5)], 5.5, 55.0, 44.0)
	await director.wait(0.3)


func _seq_bridge() -> void:
	await director.shot(Vector3(8, 11, -38), Vector3(0, 6, -40), Vector3(4, 9, -42), Vector3(0, 6, -52), 3.2, 50.0, 46.0)
	var spoken: float = director.say("LUMA", "La Farolera… Maren la dibujaba en todas partes.", "vo_cine_obs_3", 3.0)
	await director.wait(maxf(1.4, spoken - 0.2))


func _seq_boss() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("boss")
	var center: Vector3 = boss.global_position
	player.cinematic_state = "idle"
	GameEvents.sound_requested.emit("heraldo_roar")
	director.title_card("HERALDO DEL ECLIPSE", "Eco primordial del faro", 3.8)
	await director.shot(center + Vector3(6, -3, 10), center, center + Vector3(3, -1, 6.5), center + Vector3(0, 0.5, 0), 3.6, 50.0, 40.0)
	var spoken: float = director.say("LUMA", "¡El eco que apagó el faro! Enciende los pilares estelares: su luz rompe el escudo.", "vo_cine_obs_4", 3.6)
	await director.orbit(center, 7.5, -1.0, 20.0, -35.0, 4.0, 44.0)
	if spoken > 4.4: await director.wait(spoken - 4.2)
	player.cinematic_state = ""


func _seq_maren() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("observatorio")
	var dome: Vector3 = get_node("Zones/Dome").global_position
	_dissolve_boss(2.0)
	GameEvents.sound_requested.emit("beacon_ignite")
	await director.shot(boss.global_position + Vector3(5, 1, 8), boss.global_position, boss.global_position + Vector3(3, 0.5, 6), boss.global_position, 2.6, 50.0, 46.0)
	maren = _spawn_maren(dome + Vector3(0, 0, 2.2))
	await director.shot(dome + Vector3(3.5, 2.2, 8.0), dome + Vector3(0, 1.4, 2.2), dome + Vector3(1.8, 1.8, 6.0), dome + Vector3(0, 1.5, 2.2), 3.2, 46.0, 40.0)
	await director.wait(maxf(3.2, director.say(MAREN, "Por fin alguien respondió a la señal.", "vo_maren_1", 3.0) - 0.2))
	await director.wait(maxf(5.0, director.say(MAREN, "Soy Maren. La noche del eclipse encerré aquí al Heraldo y envié mi luz hacia el futuro.", "vo_maren_2", 4.8) - 0.2))
	var luma_view := dome + Vector3(-2.2, 1.5, 6.5)
	await director.shot(dome + Vector3(-5.0, 2.0, 11.0), luma_view, dome + Vector3(-3.2, 1.9, 9.5), dome + Vector3(0, 1.4, 4.0), 2.2, 46.0, 42.0)
	await director.wait(maxf(3.0, director.say("LUMA", "Maren… Te esperé cien años.", "vo_cine_obs_5", 3.0) - 0.2))
	await director.wait(maxf(4.4, director.say(MAREN, "Y cuidaste la luz, pequeña. Neri: toma la llave y alinea el telescopio.", "vo_maren_3", 4.4) - 0.2))
	if maren: director.spawned.append(maren)


func _spawn_maren(point: Vector3) -> Node3D:
	var packed: PackedScene = load("res://assets/characters/maren_echo.glb")
	if not packed: return null
	var figure := packed.instantiate() as Node3D
	figure.name = "MarenEcho"
	add_child(figure)
	figure.global_position = point
	figure.rotation.y = 0.0
	Style.apply(figure, "star")
	figure.scale = Vector3.ONE * 0.05
	var tween := create_tween()
	tween.tween_property(figure, "scale", Vector3.ONE * 1.05, 1.6).set_trans(Tween.TRANS_SINE)
	var glow := OmniLight3D.new()
	glow.light_color = Color("cfe8ff")
	glow.light_energy = 2.0
	glow.omni_range = 6.0
	glow.position.y = 1.4
	figure.add_child(glow)
	return figure


func _seq_finale() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("finale2")
	var dome: Vector3 = get_node("Zones/Dome").global_position
	var telescope: Node3D = get_node("Zones/Dome/Telescope")
	var tube := telescope.find_child("TelescopeTube", true, false) as Node3D
	player.global_position = dome + Vector3(0, 0.2, 5.8)
	player.visual.rotation.y = PI
	player.cinematic_state = "pulse"
	var lens := dome + Vector3(0, 6.0, -3.5)
	_fly_keys(player.global_position + Vector3.UP * 1.3, dome + Vector3(0, 3.0, 0))
	director.say("NERI", "Prisma, viento y estrella. Todas en su sitio.", "vo_cine_obs_6", 3.0)
	await director.shot(dome + Vector3(4.0, 2.2, 9.0), dome + Vector3(0, 2.5, 0), dome + Vector3(2.5, 3.0, 7.0), dome + Vector3(0, 3.5, 0), 3.4, 50.0, 46.0)
	player.cinematic_state = ""
	if tube:
		var aim: Tween = director._track(create_tween())
		aim.tween_property(tube, "rotation:x", deg_to_rad(52.0), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	GameEvents.sound_requested.emit("heraldo_phase")
	await director.shot(dome + Vector3(-7.0, 1.5, 4.0), dome + Vector3(0, 3.0, 0), dome + Vector3(-6.0, 3.0, -2.0), dome + Vector3(0, 6.0, -4.0), 3.2, 50.0, 55.0)
	var beam := _sky_beam(lens)
	director.spawned.append(beam)
	director.say("LUMA", "¡La luz sube hasta el cielo!", "vo_cine_obs_7", 2.8)
	await director.path([dome + Vector3(0, 12, 22), dome + Vector3(-18, 30, 40), dome + Vector3(-40, 46, 70)],
		[dome + Vector3(0, 8, 0), dome + Vector3(0, 14, -10), dome + Vector3(0, 10, -40)], 6.5, 55.0, 60.0)
	for island in find_children("DistantIsland*", "Node3D", true, false):
		_light_island(island)
	GameEvents.sound_requested.emit("island_chime")
	await director.wait(maxf(4.2, director.say(MAREN, "Las islas vuelven a acercarse. Cuida de Luma por mí.", "vo_maren_4", 4.0) - 0.2))
	director.title_card("FIN DEL CAPÍTULO II", "La señal imposible", 5.0)
	await director.wait(4.0)
	await director.fade(1.0, 1.6)


func _fly_keys(origin: Vector3, target: Vector3) -> void:
	var colors := [Color("b18cff"), Color("8fe9d6"), Color("ffe6a8")]
	var packed: PackedScene = load("res://assets/props/star_key.glb")
	for i in 3:
		var key := Node3D.new()
		key.name = "FlyingKey%d" % i
		add_child(key)
		director.spawned.append(key)
		if packed:
			var model := packed.instantiate() as Node3D
			model.scale = Vector3.ONE * 0.8
			key.add_child(model)
		var light := OmniLight3D.new()
		light.light_color = colors[i]
		light.light_energy = 2.2
		light.omni_range = 3.5
		key.add_child(light)
		key.global_position = origin
		var side := Vector3(cos(i * TAU / 3.0), 0.5, sin(i * TAU / 3.0)) * 1.5
		var tween: Tween = director._track(create_tween())
		tween.tween_interval(0.25 * i)
		tween.tween_property(key, "global_position", origin + side, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(key, "global_position", target, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(key.hide)


func _sky_beam(point: Vector3) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	beam.name = "SkyBeam"
	var column := CylinderMesh.new()
	column.top_radius = 1.4
	column.bottom_radius = 0.5
	column.height = 90.0
	column.cap_top = false
	column.cap_bottom = false
	beam.mesh = column
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/beacon.gdshader")
	material.set_shader_parameter("strength", 0.0)
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = point + Vector3.UP * 45.0
	var tween: Tween = director._track(create_tween())
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("strength", v), 0.0, 1.0, 1.6)
	GameEvents.sound_requested.emit("beacon_ignite")
	return beam


func _light_island(island: Node3D) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "IslandLamp"
	lamp.light_color = Color("ffe1a6")
	lamp.light_energy = 0.0
	lamp.omni_range = 14.0
	lamp.position = Vector3(0, 4, 0)
	island.add_child(lamp)
	director.spawned.append(lamp)
	var tween: Tween = director._track(create_tween())
	tween.tween_interval(randf() * 2.0)
	tween.tween_property(lamp, "light_energy", 3.0, 1.2)
