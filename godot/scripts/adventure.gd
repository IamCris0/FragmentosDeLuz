extends Node3D

const TITLES: Array[String] = ["UMBRAL DE AURALIA", "JARDÍN DE ECOS", "PASO DEL CIELO", "FARO DE AURALIA"]
const ORDER: Array[int] = [1, 0, 2]
var rune_progress: int = 0
var entered_zone: int = -1
var pulse: float = 0
var threat_clock: float = 0.0
var director: Node
var gate_dissolving: bool = false
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUDLayer
@onready var gate: StaticBody3D = $Zones/Puzzle/PuzzleGate


const MAP_SCENE := "res://scenes/archipelago_map.tscn"
const CH2_CALL := "¿Lo sientes, Neri? La luz del faro ha llegado más lejos que nunca. Tres islas le responden: unas grutas de cristal, unos picos donde aún sopla el viento… y el viejo Observatorio. La señal imposible sigue sonando allí arriba.\n\nEl portal del faro ya puede llevarte hasta ellas. Y mira tu escáner: guarda cada destello que encuentras. Úsalos para encender tu constelación (K) y hacerte más fuerte."


func _enter_tree() -> void:
	GameEvents.load_game()
	GameEvents.enter_level("auralia")


func _ready() -> void:
	GameEvents.set_cinematic(false)
	var feedback := Node3D.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(load("res://scripts/combat_feedback.gd"))
	add_child(feedback)
	var beacon := Node3D.new()
	beacon.name = "BeaconRestoration"
	beacon.set_script(load("res://scripts/beacon_restoration.gd"))
	add_child(beacon)
	director = Node.new()
	director.name = "CinematicDirector"
	director.set_script(load("res://scripts/cinematic_director.gd"))
	add_child(director)
	hud.player = player
	player.global_position = GameEvents.checkpoint
	GameEvents.fragments_changed.emit(GameEvents.collected, 7)
	GameEvents.energy_changed.emit(GameEvents.energy, GameEvents.max_energy)
	GameEvents.objective_changed.emit(GameEvents.objective)
	GameEvents.tutorial_changed.emit(GameEvents.tutorial_stage, GameEvents.tutorial_text)
	_refresh_gate()
	if GameEvents.completed:
		GameEvents.set_objective("Auralia vuelve a brillar" if GameEvents.story_seen.has("ch2_call") and GameEvents.is_level_done("observatorio") else "Cruza el portal del faro hacia el archipiélago")
	GameEvents.destellos_changed.emit(GameEvents.destellos, 0)
	if "--qa" in OS.get_cmdline_user_args():
		var qa:Node=load("res://tools/qa_adventure.gd").new()
		add_child(qa)
		qa.run.call_deferred(self)
	elif not GameEvents.story_seen.has("arrival"):
		if director.should_play("arrival"):
			await get_tree().process_frame
			await director.play("arrival")
		else:
			await get_tree().create_timer(0.8).timeout
		GameEvents.story("arrival", "NERI · EL FARO DORMIDO", "La señal de mi escáner termina aquí. Islas que no deberían flotar. Un faro que no debería seguir encendido.\n\nHay ecos moviéndose entre las ruinas. Si el escáner responde, quizás pueda empujarlos con una descarga de luz.")
	elif GameEvents.story_seen.has("cine_finale") and not GameEvents.story_seen.has("ch2_call"):
		# Fase 7: partidas que ya completaron el capítulo I reciben la llamada del archipiélago.
		await get_tree().create_timer(1.0).timeout
		chapter_two_call()


func _process(delta: float) -> void:
	pulse += delta
	threat_clock -= delta
	if threat_clock <= 0.0:
		threat_clock = 0.15
		var count: int = 0
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy.is_threat(): count += 1
		GameEvents.set_threat(count)
	var z: float = player.global_position.z
	var zone: int = 0 if z > -20 else (1 if z > -43 else (2 if z > -75 else 3))
	if zone != entered_zone:
		entered_zone = zone
		GameEvents.zone = zone
		GameEvents.zone_changed.emit(zone, TITLES[zone])
		if zone == 0: GameEvents.checkpoint = Vector3(0,0.2,7)
		elif zone == 1: GameEvents.checkpoint = Vector3(0,0.2,-24)
		elif zone == 2 and player.global_position.y > 3: GameEvents.checkpoint = Vector3(0,4.2,-54)
		elif zone == 3: GameEvents.checkpoint = Vector3(0,4.2,-79)
		if zone == 1 and not GameEvents.puzzle_solved: GameEvents.set_objective("Restaura la melodía de las tres runas")
		elif zone == 2: GameEvents.set_objective("Explora el Paso del Cielo y recupera sus fragmentos")
		elif zone == 3 and not GameEvents.completed: GameEvents.set_objective("Reúne los siete fragmentos y activa el faro")
		GameEvents.save_game()
		if zone == 3 and not GameEvents.purified_ids.has("BeaconEcho") and director.should_play("guardian"):
			_play_when_free.call_deferred("guardian")
	if zone == 2 and player.global_position.y > 3.7 and z < -53 and GameEvents.checkpoint.z > -40:
		GameEvents.checkpoint = Vector3(0,4.2,-54)
		GameEvents.save_game()
	var vortex: ShaderMaterial = $Zones/PortalFinal/Portal/Vortex.material_override
	vortex.set_shader_parameter("active", GameEvents.collected == 7 and GameEvents.puzzle_solved and (GameEvents.completed or GameEvents.purified_ids.has("BeaconEcho")))
	$Zones/Entrance/Luma/Visual.position.y = sin(pulse * 1.1) * 0.045
	_update_tutorial(zone)


func _update_tutorial(zone: int) -> void:
	if GameEvents.completed:
		if GameEvents.tutorial_stage != 99: GameEvents.set_tutorial(99, "")
		return
	if GameEvents.tutorial_stage < 1 and player.global_position.distance_to($Zones/Entrance/Luma.global_position) < 5.2:
		GameEvents.set_tutorial(1, "Cuando aparezca el aviso, pulsa E para hablar o examinar objetos.")
	elif GameEvents.tutorial_stage < 2 and GameEvents.story_seen.has("luma_intro") and player.global_position.z < -4.0:
		GameEvents.set_tutorial(2, "Un eco bloquea el camino. Pulsa Q cerca de él para emitir un pulso de luz.")
	elif GameEvents.tutorial_stage < 4 and zone == 1:
		GameEvents.set_tutorial(4, "Las runas responden al orden OLA, SOL y ESTRELLA. Si fallas, escucha la pista y vuelve a intentar.")
	elif GameEvents.tutorial_stage < 5 and zone == 2:
		GameEvents.set_tutorial(5, "Espacio para saltar y C para esquivar. La rodada no atraviesa muros: cuidado con los bordes del puente.")
	elif GameEvents.tutorial_stage < 6 and zone == 3:
		GameEvents.set_tutorial(6, "El guardián libera ondas por el suelo. Sáltalas con Espacio, esquiva con C o interrumpe la carga con Q.")


func activate_rune(index: int) -> void:
	if GameEvents.puzzle_solved:
		GameEvents.toast_requested.emit("La melodía del jardín está completa")
		return
	if index != ORDER[rune_progress]:
		rune_progress = 0
		GameEvents.toast_requested.emit("El eco se apaga. El agua debe sonar primero.")
		GameEvents.sound_requested.emit("wrong")
	else:
		rune_progress += 1
		GameEvents.sound_requested.emit("rune_%d" % index)
		GameEvents.toast_requested.emit("Resonancia %d / 3" % rune_progress)
	_refresh_runes()
	if rune_progress == 3:
		GameEvents.puzzle_solved = true
		GameEvents.puzzle_changed.emit(true)
		GameEvents.sound_requested.emit("solved")
		GameEvents.set_objective("Recoge la luz del jardín y asciende al Paso del Cielo")
		GameEvents.toast_requested.emit("El jardín despierta. El camino está abierto.")
		var cinematic: bool = director.should_play("garden")
		gate_dissolving = cinematic
		_refresh_gate()
		GameEvents.save_game()
		if cinematic:
			_play_when_free.call_deferred("garden")


func _refresh_runes() -> void:
	for i in range(3):
		var light: OmniLight3D = get_node("Zones/Puzzle/Resonator_%d/OmniLight3D" % i)
		light.light_color = Color("f9c74f") if ORDER.slice(0,rune_progress).has(i) else Color("4ecdc4")
		light.light_energy = 2.0 if ORDER.slice(0,rune_progress).has(i) else 1.0


func _refresh_gate() -> void:
	gate.visible = not GameEvents.puzzle_solved or gate_dissolving
	gate.get_node("CollisionShape3D").set_deferred("disabled", GameEvents.puzzle_solved)
	if GameEvents.puzzle_solved:
		rune_progress = 3
		_refresh_runes()



## Espera a que no haya diálogo abierto antes de lanzar una cinemática.
func _play_when_free(id: String) -> void:
	while hud.dialog_open or hud.paused or hud.journal.visible or director.is_playing():
		await get_tree().process_frame
	if director.should_play(id):
		await director.play(id)
	if id == "garden" and gate_dissolving:
		dissolve_gate(0.0)


## Disuelve la barrera del jardín (fase 6). Con duración 0 la oculta inmediatamente.
func dissolve_gate(duration: float) -> void:
	var mesh: MeshInstance3D = gate.get_node("Mesh")
	var material := mesh.material_override as ShaderMaterial
	if duration <= 0.0 or not material:
		gate_dissolving = false
		if material: material.set_shader_parameter("fade", 0.0)
		gate.visible = not GameEvents.puzzle_solved
		return
	GameEvents.sound_requested.emit("gate_dissolve")
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("fade", value), 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(dissolve_gate.bind(0.0))


## Portal completado: cinemática final, créditos y regreso al mundo o al menú.
func start_finale() -> void:
	GameEvents.completed = true
	GameEvents.story_seen["ending"] = true
	GameEvents.award("chapter1", 3)
	GameEvents.set_objective("Auralia vuelve a brillar")
	GameEvents.sound_requested.emit("portal")
	GameEvents.save_game()
	if not director.should_play("finale"):
		GameEvents.story("ending", "FRAGMENTOS DE LUZ · EPÍLOGO", "Los fragmentos se elevan de tu escáner y el cielo responde. Una luz tras otra aparece en las islas distantes.\n\nLuma sonríe: «No has devuelto la ciudad al pasado. Le has dado un mañana».\n\nNeri cruza el umbral. Al otro lado, alguien ha visto la señal.\n\nFIN DEL CAPÍTULO I · EL FARO DORMIDO")
		return
	await director.play("finale")
	var to_menu: bool = await director.roll_credits()
	finish_finale(to_menu)


func finish_finale(to_menu: bool) -> void:
	GameEvents.save_game()
	GameEvents.set_cinematic(false)
	if to_menu:
		get_tree().change_scene_to_file("res://scenes/title_menu.tscn")
		return
	player.global_position = Vector3(0, 4.05, -84.5)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = PI
	player.camera.current = true
	player.locked = false
	hud.root.visible = true
	GameEvents.set_cinematic(false)
	var audio := get_node_or_null("AudioManager")
	if audio: audio.clear_cinematic_music()
	var reveal := create_tween()
	reveal.tween_property(director.fade_rect, "color:a", 0.0, 1.2)
	GameEvents.toast_requested.emit("Auralia vuelve a brillar. Puedes seguir explorando.")
	await get_tree().create_timer(1.6).timeout
	chapter_two_call()


## Fase 7: Luma presenta el archipiélago, los destellos y la Constelación.
func chapter_two_call() -> void:
	if GameEvents.story_seen.has("ch2_call") or not GameEvents.completed: return
	while hud.dialog_open or hud.paused or hud.journal.visible or director.is_playing() or (hud.constellation and hud.constellation.visible):
		await get_tree().process_frame
	GameEvents.story("ch2_call", "LUMA · EL ARCHIPIÉLAGO", CH2_CALL)
	GameEvents.set_objective("Cruza el portal del faro hacia el archipiélago")
	GameEvents.set_tutorial(99, "")


## Fase 7: el portal del faro abre la Carta del Archipiélago.
func open_map() -> void:
	if director.is_playing(): return
	GameEvents.save_game()
	player.locked = true
	GameEvents.sound_requested.emit("portal")
	var fade := create_tween()
	fade.tween_property(director.fade_rect, "color:a", 1.0, 0.8)
	fade.tween_callback(get_tree().change_scene_to_file.bind(MAP_SCENE))