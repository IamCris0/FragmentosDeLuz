extends Node3D
## Fase 7: controlador común de las islas del archipiélago (Grutas, Céfiro, Observatorio).
## Prepara al jugador, el HUD, el audio y el director de cinemáticas; gestiona refugios, zonas,
## amenaza, calidad gráfica, llave de la isla y regreso a la carta. Cada isla lo extiende
## (scripts/level_<id>.gd) e implementa setup_level(), level_process(), intro() y zone_entered().

const LevelData = preload("res://scripts/level_data.gd")
const MAP_SCENE := "res://scenes/archipelago_map.tscn"

@export var level_id: String = "grutas"
## Altura bajo la cual Neri vuelve al último refugio.
@export var fall_limit: float = -30.0
## Pistas musicales por zona (las lee AudioManager).
@export var music_themes: Array = ["exploration"]

var player: CharacterBody3D
var hud: CanvasLayer
var director: Node
var threat_clock: float = 0.0
var boss_active: bool = false
var leaving: bool = false
var qa_mode: bool = false
## La niebla volumétrica solo se usa si la isla la configuró al construirse (el valor por defecto de
## Godot, densidad 0,05, cubría toda la isla de bruma al activarla por calidad).
var volumetric_wanted: bool = false


func _enter_tree() -> void:
	GameEvents.load_game()
	GameEvents.enter_level(level_id)


func _ready() -> void:
	qa_mode = "--qa" in OS.get_cmdline_user_args()
	GameEvents.set_cinematic(false)
	GameEvents.set_hint("")
	GameEvents.boss_title = "GUARDIÁN DEL FARO"
	player = $Player
	hud = $HUDLayer
	var feedback := Node3D.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(load("res://scripts/combat_feedback.gd"))
	add_child(feedback)
	director = Node.new()
	director.name = "CinematicDirector"
	director.set_script(load("res://scripts/cinematic_director.gd"))
	add_child(director)
	hud.player = player
	player.global_position = GameEvents.checkpoint
	player.visual.rotation.y = PI
	for node in get_tree().get_nodes_in_group("level_checkpoint"):
		node.reached.connect(_on_checkpoint_reached)
		if int(node.index) <= int(GameEvents.level_state().checkpoint): node.light_up(false)
	var configured_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if configured_environment and configured_environment.environment:
		volumetric_wanted = configured_environment.environment.volumetric_fog_enabled
	Preferences.quality_changed.connect(apply_quality)
	apply_quality(Preferences.quality)
	setup_level()
	_refresh_hud()
	var title: String = LevelData.level(level_id).zones[clampi(GameEvents.zone, 0, 3)]
	GameEvents.zone_changed.emit(GameEvents.zone, title.to_upper())
	if qa_mode:
		var suite := "res://tools/qa_skills.gd" if "--qa-skills" in OS.get_cmdline_user_args() else "res://tools/qa_levels.gd"
		var qa: Node = load(suite).new()
		qa.name = "LevelQA"
		add_child(qa)
		qa.run.call_deferred(self)
	else:
		_begin.call_deferred()


func _begin() -> void:
	await get_tree().process_frame
	await intro()


func _refresh_hud() -> void:
	GameEvents.energy_changed.emit(GameEvents.energy, GameEvents.max_energy)
	GameEvents.objective_changed.emit(GameEvents.objective)
	GameEvents.destellos_changed.emit(GameEvents.destellos, 0)
	GameEvents.emit_level_progress()


func _process(delta: float) -> void:
	threat_clock -= delta
	if threat_clock <= 0.0:
		threat_clock = 0.15
		var count: int = 0
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy.has_method("is_threat") and enemy.is_threat(): count += 1
		GameEvents.set_threat(count)
	level_process(delta)


func _on_checkpoint_reached(index: int) -> void:
	var previous: int = GameEvents.zone
	GameEvents.set_level_checkpoint(index)
	if index != previous or not GameEvents.level_flag("zone_%d" % index):
		var title: String = LevelData.level(level_id).zones[index]
		GameEvents.zone_changed.emit(index, title.to_upper())
		if not GameEvents.level_flag("zone_%d" % index):
			GameEvents.set_level_flag("zone_%d" % index)
			if index > 0: GameEvents.toast_requested.emit("Refugio encendido · " + title)
		zone_entered(index)


## Aplica el perfil de calidad al entorno de la isla (equivalente a EnvironmentLife de Auralia).
func apply_quality(level: int) -> void:
	var environment_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node and environment_node.environment:
		environment_node.environment.ssao_enabled = level > 0
		environment_node.environment.glow_enabled = true
		environment_node.environment.volumetric_fog_enabled = volumetric_wanted and level > 0 and not "--qa-no-volumetric" in OS.get_cmdline_user_args()
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun: sun.shadow_enabled = level > 0
	get_viewport().msaa_3d = Viewport.MSAA_4X if level == 2 else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = 0.8 if level == 0 else 1.0
	for particles in find_children("*", "GPUParticles3D", true, false):
		if str(particles.name).begins_with("Ambient"): (particles as GPUParticles3D).amount_ratio = 0.45 if level == 0 else 1.0


## Espera a que no haya diálogos ni menús antes de lanzar una cinemática.
func play_when_free(id: String) -> void:
	while hud.dialog_open or hud.paused or hud.journal.visible or director.is_playing() or (hud.constellation and hud.constellation.visible):
		await get_tree().process_frame
	if director.should_play(id):
		await director.play(id)


## Diálogo que espera a que se cierre (para encadenar escenas de historia).
func say_story(id: String, speaker: String, text: String) -> void:
	while hud.dialog_open or director.is_playing():
		await get_tree().process_frame
	GameEvents.story(id, speaker, text)
	while hud.dialog_open:
		await get_tree().process_frame


## La llave de la isla completa el nivel y abre el portal de regreso.
func obtain_key() -> void:
	if GameEvents.is_level_done(level_id): return
	GameEvents.sound_requested.emit("key_obtained")
	GameEvents.complete_level(level_id)
	GameEvents.toast_requested.emit(str(LevelData.level(level_id).key_title) + " obtenida")
	for gate in get_tree().get_nodes_in_group("level_gate"):
		gate.set_active(true)
	key_obtained()


func open_map() -> void:
	if leaving: return
	leaving = true
	GameEvents.save_game()
	player.locked = true
	GameEvents.sound_requested.emit("travel")
	if qa_mode: return
	var fade := create_tween()
	fade.tween_property(director.fade_rect, "color:a", 1.0, 0.8)
	fade.tween_callback(get_tree().change_scene_to_file.bind(MAP_SCENE))


# --- Métodos que cada isla sobrescribe ------------------------------------------------------------

func setup_level() -> void:
	pass


func level_process(_delta: float) -> void:
	pass


func intro() -> void:
	pass


func zone_entered(_index: int) -> void:
	pass


func key_obtained() -> void:
	pass


func theme_for_zone(_index: int) -> int:
	return 0


func audio_spots() -> Array:
	return []
