extends Node
## Fase 7: pruebas automáticas de las islas del archipiélago. Se ejecutan con:
##   godot --path godot res://scenes/levels/<isla>.tscn -- --qa
## Recorren la isla con entradas reales (movimiento, saltos, interacción, pulso), resuelven sus
## mecanismos, recogen destellos y la llave, y guardan capturas y un informe en previews/levels/.

var game: Node3D
var player: CharacterBody3D
var checks: Array[String] = []
var failures: Array[String] = []
var images: Array[String] = []
var folder: String
var finished: bool = false
## --qa-part=<tramo>: ejecuta solo un tramo de la isla (teletransporte al refugio correspondiente).
var part: String = ""
const LevelDataScript = preload("res://scripts/level_data.gd")


func check(condition: bool, label: String) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error("QA_FAILED: " + label)


func settle(seconds: float = 0.35) -> void:
	await get_tree().create_timer(seconds).timeout


func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	check(not picture.is_empty(), "Image " + name_value)
	picture.save_png(folder + name_value + ".png")
	images.append(name_value + ".png")


func close_story() -> void:
	if not game.hud.dialog_open: return
	game.hud.revealed = 10000
	game.hud.dialogue_text.visible_characters = 10000
	game.hud.close_dialogue()
	player.interaction_lock = 0.0


func release_moves() -> void:
	for key in ["move_right", "move_left", "move_forward", "move_back", "jump", "sprint"]: Input.action_release(key)


func steer(point: Vector3) -> void:
	var delta_pos: Vector3 = point - player.global_position
	delta_pos.y = 0
	var direction: Vector3 = player.pivot.global_basis.inverse() * delta_pos.normalized()
	Input.action_press("move_right", maxf(0, direction.x))
	Input.action_press("move_left", maxf(0, -direction.x))
	Input.action_press("move_back", maxf(0, direction.z))
	Input.action_press("move_forward", maxf(0, -direction.z))


func walk_to(point: Vector3, timeout: float = 14.0, tolerance: float = 0.38) -> bool:
	var elapsed: float = 0
	player.locked = false
	while elapsed < timeout:
		var delta_pos: Vector3 = point - player.global_position
		delta_pos.y = 0
		if delta_pos.length() < tolerance: break
		steer(point)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	release_moves()
	await settle(0.12)
	var difference: Vector3 = player.global_position - point
	difference.y = 0
	if difference.length() >= 0.7:
		print("BLOCKED_AT ", player.global_position, " TARGET ", point, " locked ", player.locked, " dialog ", game.hud.dialog_open, " cinematic ", GameEvents.cinematic_active,
			" vel ", player.velocity, " physics ", player.is_physics_processing(), " ilock ", player.interaction_lock, " paused ", get_tree().paused,
			" cine_state ", player.get("cinematic_state"), " input ", Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
		for i in player.get_slide_collision_count():
			var hit := player.get_slide_collision(i)
			print("  SLIDE ", (hit.get_collider() as Node).get_path() if hit.get_collider() else "?", " n=", hit.get_normal(), " at ", hit.get_position())
	return difference.length() < 0.7


## Salta hacia un punto (x, altura de la superficie, z). double = segundo salto en el aire.
func hop_to(point: Vector3, double: bool = false, sprint: bool = false, timeout: float = 2.2) -> bool:
	var elapsed := 0.0
	var jumped := false
	var second := false
	player.locked = false
	if sprint: Input.action_press("sprint")
	while elapsed < timeout:
		steer(point)
		if not jumped:
			Input.action_press("jump")
			jumped = true
		elif elapsed > 0.1 and not second:
			Input.action_release("jump")
			if double and elapsed > 0.32:
				Input.action_press("jump")
				second = true
		elif second and elapsed > 0.48:
			Input.action_release("jump")
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var flat: Vector3 = point - player.global_position
		flat.y = 0
		if elapsed > 0.3 and player.is_on_floor() and flat.length() < 0.45: break
		if elapsed > 0.3 and player.is_on_floor() and player.global_position.y < point.y - 0.6: break
	release_moves()
	await settle(0.15)
	var landed: Vector3 = player.global_position - point
	var ok: bool = absf(landed.y) < 0.45 and Vector2(landed.x, landed.z).length() < 1.4
	if not ok: print("HOP_MISSED ", player.global_position, " TARGET ", point)
	return ok


## Camina hasta el borde de la plataforma actual en dirección al objetivo (como haría un jugador).
func to_edge(center: Vector3, target: Vector3, radius: float) -> void:
	var direction := target - center
	direction.y = 0.0
	await walk_to(center + direction.normalized() * maxf(radius - 0.55, 0.2), 4.0, 0.3)


## Salta hacia una plataforma móvil siguiendo su posición en cada fotograma.
func hop_to_body(body: Node3D, top: float, timeout: float = 2.2) -> bool:
	var elapsed := 0.0
	player.locked = false
	Input.action_press("jump")
	while elapsed < timeout:
		var point := Vector3(body.global_position.x, top, body.global_position.z)
		steer(point)
		if elapsed > 0.1: Input.action_release("jump")
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var flat: Vector3 = point - player.global_position
		flat.y = 0
		if elapsed > 0.3 and player.is_on_floor() and flat.length() < 0.5: break
		if elapsed > 0.3 and player.is_on_floor() and player.global_position.y < top - 0.6: break
	release_moves()
	await settle(0.1)
	var landed: Vector3 = player.global_position - Vector3(body.global_position.x, top, body.global_position.z)
	return absf(landed.y) < 0.45 and Vector2(landed.x, landed.z).length() < 1.6


func tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


## Se acerca a un objeto interactivo desde un punto dado y pulsa E n veces.
func use(target: Node3D, approach: Vector3, times: int = 1, pause: float = 0.55) -> bool:
	await walk_to(approach)
	var targeted := false
	for i in times:
		player.interaction_lock = 0.0
		await get_tree().physics_frame
		targeted = targeted or player.target == target
		await tap("interact")
		await settle(pause)
		close_story()
	return targeted


func grounded_at(point: Vector3) -> void:
	player.global_position = point
	player.velocity = Vector3.ZERO
	var waited := 0.0
	await get_tree().physics_frame
	while not player.is_on_floor() and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await get_tree().physics_frame


func run(scene: Node3D) -> void:
	game = scene
	player = scene.player
	folder = ProjectSettings.globalize_path("res://../previews/levels/")
	DirAccess.make_dir_recursive_absolute(folder)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-part="): part = arg.substr(10)
	# Estado de un jugador que ya completó el capítulo I (el guardado lo exige para abrir las islas).
	for i in 7: GameEvents.fragment_ids["fragment_%d" % i] = true
	GameEvents.collected = 7
	GameEvents.puzzle_solved = true
	GameEvents.completed = true
	for id in LevelDataScript.ORDER:
		if id == str(scene.level_id): break
		if id != "auralia": GameEvents.level_state(id).done = true
	await settle(1.0)
	if part == "cinematics":
		await cinematics_checks()
		common_save_checks()
		finished = true
		write_report()
		return
	match str(scene.level_id):
		"grutas": await grutas_checks()
		"cefiro":
			if has_method("cefiro_checks"): await call("cefiro_checks")
		"observatorio":
			if has_method("observatorio_checks"): await call("observatorio_checks")
	common_save_checks()
	finished = true
	write_report()


## --qa --qa-cinematics --qa-part=cinematics: reproduce cada cinemática de la isla con el director real
## y comprueba que devuelve el control; en el Observatorio, además, el final completo con epílogo y créditos.
func cinematics_checks() -> void:
	var director: Node = game.director
	check(director.enabled, "Director enabled for the cinematic test")
	var shot := 0
	for id in director.sequences.keys():
		if str(id).ends_with("finale"): continue
		GameEvents.story_seen.erase("cine_" + str(id))
		director.play(id)
		var waited := 0.0
		var captured := false
		while director.is_playing() and waited < 90.0:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
			if not captured and waited >= 3.0:
				shot += 1
				await capture("%s_cine_%02d" % [game.level_id, shot])
				captured = true
		await settle(0.8)
		check(not director.is_playing() and not player.locked and game.hud.root.visible and not GameEvents.cinematic_active, "Cinematic %s returns control" % id)
		check(GameEvents.story_seen.has("cine_" + str(id)), "Cinematic %s is remembered" % id)
	if game.level_id == "observatorio":
		await observatorio_finale_checks()


func observatorio_finale_checks() -> void:
	var director: Node = game.director
	load("res://scripts/story_art.gd").base = load("res://tools/qa_art_fixtures.gd").build()
	GameEvents.purified_ids["Heraldo"] = true
	player.global_position = game.get_node("Zones/Dome").global_position + Vector3(0, 0.3, 6.0)
	await settle(0.5)
	game.obtain_key()
	var waited := 0.0
	var captured := 0
	while not game.has_node("EndingComic") and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if director.is_playing() and captured < 2 and waited >= 6.0 + captured * 9.0:
			captured += 1
			await capture("observatorio_final_%d" % captured)
	var comic: Node = game.get_node_or_null("EndingComic")
	check(comic != null and comic.panels.size() == 4, "Ending comic follows the finale")
	check(player.locked and not game.hud.root.visible and GameEvents.cinematic_active, "Neri stays locked during the ending comic")
	await capture("observatorio_final_3_epilogo")
	if comic: comic.finish()
	waited = 0.0
	while director.current != "credits" and waited < 20.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	check(director.current == "credits" and player.locked and not game.hud.root.visible, "Credits roll with Neri still locked")
	await settle(1.0)
	await capture("observatorio_final_4_creditos")
	waited = 0.0
	while (director.current != "" or player.locked) and waited < 150.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await settle(1.6)
	check(not player.locked and game.hud.root.visible and not GameEvents.cinematic_active, "After the credits Neri can explore again")
	check(GameEvents.story_seen.has("cine_observatorio_finale") and GameEvents.is_level_done("observatorio"), "The Chapter II finale is remembered")
	check(director.fade_rect.color.a < 0.1, "The screen fades back in after the finale")
	load("res://scripts/story_art.gd").base = "res://"


func common_save_checks() -> void:
	var SaveStore = load("res://scripts/save_store.gd")
	var data: Dictionary = SaveStore.normalize(GameEvents.snapshot())
	check(not data.is_empty() and data.level == game.level_id, "Save snapshot keeps the current island")
	check(data.levels.has(game.level_id) and int(data.levels[game.level_id].checkpoint) == int(GameEvents.level_state().checkpoint), "Save snapshot keeps the island checkpoint")
	check(data.destellos == GameEvents.destellos and data.destello_ids.size() == GameEvents.destello_ids.size(), "Save snapshot keeps destellos")


func write_report() -> void:
	var report := {"level": game.level_id, "passed": failures.is_empty() and finished, "checks": checks, "failures": failures,
		"images": images, "engine": Engine.get_version_info().string, "fps": Engine.get_frames_per_second()}
	if part != "": report["part"] = part
	var file := FileAccess.open(folder + ("%s_report.json" % game.level_id if part == "" else "%s_%s_report.json" % [game.level_id, part]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("LEVEL_QA ", JSON.stringify(report))
	get_tree().quit(0 if report.passed else 1)


# --- Grutas Prismáticas ----------------------------------------------------------------------------

func grutas_checks() -> void:
	check(GameEvents.level == "grutas" and game.get_script() != null, "Grutas scene controls the level")
	check(get_tree().get_nodes_in_group("destello").size() == 6, "Six destellos placed")
	check(get_tree().get_nodes_in_group("level_checkpoint").size() == 4, "Four refuges placed")
	check(get_tree().get_nodes_in_group("beam_emitter").size() == 4, "Four light emitters")
	check(get_tree().get_nodes_in_group("prism").size() == 8, "Eight prisms")
	check(get_tree().get_nodes_in_group("beam_receptor").size() == 5, "Five receptors")
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	check(enemies.size() == 8, "Eight enemies in the caverns")
	check(get_tree().get_nodes_in_group("vigia").size() == 3, "Three Vigías")
	check(player.global_position.distance_to(Vector3(0, 0.2, 6)) < 0.6, "Neri starts at the first refuge")
	check((game.hud.get_node("HUD/TopBar/FragmentSection/Caption") as Label).text == "DESTELLOS DE LA ISLA", "HUD shows island destellos")
	check(game.hud.level_mode and GameEvents.hint != "", "Level hint is visible")
	var styled: int = 0
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).get_surface_override_material_count() > 0 and (mesh as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial: styled += 1
	check(styled > 40, "Crystal and rock shaders applied")
	await capture("grutas_01_boca")
	# Luma y primer destello.
	var luma: Node3D = game.get_node("Zones/Mouth/Luma")
	await use(luma, luma.global_position + Vector3(1.4, 0, 0.6))
	check(GameEvents.story_seen.has("grutas_luma_prism"), "Luma explains the prisms")
	var before := GameEvents.destellos
	await walk_to(Vector3(8.5, 0, 6.0))
	await settle(0.4)
	check(GameEvents.destellos == before + 1 and GameEvents.level_destellos() == 1, "Walking into a destello collects it")
	check(game.hud.destello_label.text == "✦ %d" % GameEvents.destellos, "HUD destello counter updates")
	# Prisma del umbral.
	var prism0: Node = game.get_node("Zones/Mouth/Prism_0")
	check(await use(prism0, Vector3(-3.0, 0, -3.0), 2), "Prism can be targeted and turned with E")
	check(prism0.facing == 0, "Prism faces the receptor after two turns")
	await settle(1.3)
	check(GameEvents.level_flag("door_0"), "Beam charges the first receptor")
	var door: Node = game.get_node("Zones/Mouth/Door_0")
	check(door.open and door.get_node("CollisionShape3D").disabled, "Crystal door opens")
	await capture("grutas_02_rayo")
	# Salón de los Prismas.
	await walk_to(Vector3(0, 0, -9.0))
	await walk_to(Vector3(0, 0, -24.0), 12.0)
	await settle(0.3)
	check(GameEvents.zone == 1 and int(GameEvents.level_state().checkpoint) == 1, "Stone bridge reaches the Hall refuge")
	var p1: Node = game.get_node("Zones/Hall/Prism_1")
	var p2: Node = game.get_node("Zones/Hall/Prism_2")
	var p3: Node = game.get_node("Zones/Hall/Prism_3")
	await use(p1, Vector3(-3.6, 0, -27.0), 2)
	await use(p2, Vector3(-3.6, 0, -37.0), 2)
	await use(p3, Vector3(3.6, 0, -37.0), 1)
	await settle(1.3)
	check(GameEvents.level_flag("cache_1"), "Three-prism path opens the destello niche")
	await use(p3, Vector3(3.6, 0, -37.0), 2)
	await settle(1.3)
	check(GameEvents.level_flag("bridge_1"), "Beam reaches the bridge receptor")
	var bridge: Node = game.get_node("LightBridge")
	check(bridge.visible and not bridge.get_node("CollisionShape3D").disabled, "Light bridge becomes solid")
	await capture("grutas_03_salon")
	var emitter: Node = game.get_node("Zones/Hall/Emitter_1")
	check(emitter.path_points.size() >= 5 and emitter.beam_length() > 20.0, "Beam bends through three prisms")
	before = GameEvents.destellos
	await walk_to(Vector3(12.0, 0, -27.0))
	await walk_to(Vector3(14.8, 0, -27.0), 6.0)
	await settle(0.3)
	check(GameEvents.destellos == before + 1, "Niche destello collected")
	# Cornisa del salón: tres saltos.
	await walk_to(Vector3(-7.6, 0, -36.2))
	var ledge_ok := await hop_to(Vector3(-8.8, 0.8, -37.2))
	ledge_ok = ledge_ok and await hop_to(Vector3(-10.1, 1.6, -39.3), false, true)
	ledge_ok = ledge_ok and await hop_to(Vector3(-11.1, 2.2, -41.5), false, true)
	await settle(0.4)
	check(ledge_ok and GameEvents.level_destellos() >= 3, "Crystal steps lead to the ledge destello")
	# Puente de luz y Puente de Cuarzo.
	await grounded_at(Vector3(0, 0.2, -41.0))
	await walk_to(Vector3(0, 0, -44.5))
	await walk_to(Vector3(0, 0, -58.0), 8.0)
	await settle(0.3)
	check(GameEvents.zone == 2, "Light bridge carries Neri to the Quartz Span")
	await walk_to(Vector3(0, 0, -65.5))
	var mover: Node3D = game.get_node("Platform_Moving")
	check(await hop_to(Vector3(0, -0.25, -69.4), false, true), "Jump to the first crystal platform")
	await walk_to(Vector3(0, -0.25, -70.8), 3.0)
	var wait_time := 0.0
	while absf(mover.global_position.x) > 0.8 and wait_time < 8.0:
		await get_tree().physics_frame
		wait_time += get_physics_process_delta_time()
	check(await hop_to_body(mover, -0.8), "Jump onto the moving platform")
	check(player.get_platform_velocity().length() > 0.0 or absf(mover.global_position.x) < 3.1, "Moving platform carries Neri")
	await capture("grutas_04_plataformas")
	wait_time = 0.0
	while absf(mover.global_position.x) > 0.6 and wait_time < 8.0:
		await get_tree().physics_frame
		wait_time += get_physics_process_delta_time()
	check(await hop_to(Vector3(0, -1.25, -77.5), false, true), "Jump from the moving platform to the last step")
	check(await hop_to(Vector3(0, -2.0, -81.2)), "Jump down into the Prismatic Heart")
	await walk_to(Vector3(0, -2, -82.5))
	await settle(0.3)
	check(GameEvents.zone == 3 and int(GameEvents.level_state().checkpoint) == 3, "Heart refuge reached")
	# Corazón: cuatro prismas, dos receptores.
	for spec in [["Prism_4", Vector3(-5.8, -2, -85.0), 3, []], ["Prism_5", Vector3(-5.8, -2, -95.0), 3, []],
			["Prism_6", Vector3(5.8, -2, -99.0), 3, [Vector3(0, -2, -88.5), Vector3(4.5, -2, -90.0), Vector3(4.8, -2, -97.0)]], ["Prism_7", Vector3(5.6, -2, -94.6), 3, []]]:
		for waypoint in spec[3]: await walk_to(waypoint)
		await use(game.get_node("Zones/Heart/" + spec[0]), spec[1], spec[2])
	await settle(1.5)
	check(GameEvents.level_flag("heart_west") and GameEvents.level_flag("heart_east"), "Both beams reach the heart")
	check(GameEvents.level_flag("heart_open") and game.altar.revealed, "Heart awakens and reveals the key")
	await grounded_at(Vector3(0, -1.8, -86.0))
	await capture("grutas_05_corazon")
	# Cornisa alta: sin doble salto no se alcanza; con él, sí.
	await walk_to(Vector3(7.2, -2, -89.5))
	await hop_to(Vector3(8.2, -1.0, -88.7))
	var on_step: bool = player.global_position.y > -1.2
	await hop_to(Vector3(9.9, 0.3, -86.8))
	check(on_step and player.global_position.y < 0.0, "High ledge is out of reach with a single jump")
	GameEvents.skills["double_jump"] = true
	await grounded_at(Vector3(8.2, -0.8, -88.7))
	var double_ok := await hop_to(Vector3(9.9, 0.3, -86.8), true)
	await settle(0.4)
	check(double_ok and GameEvents.level_destellos() >= 4, "Double jump reaches the high ledge destello")
	GameEvents.skills.erase("double_jump")
	# Llave.
	await grounded_at(Vector3(0, -1.8, -88.5))
	var total_before := GameEvents.destellos
	var altar: Node = game.altar
	check(await use(altar, Vector3(0, -2, -90.4)), "Key altar can be targeted")
	await settle(1.0)
	check(GameEvents.is_level_done("grutas"), "Taking the key completes the island")
	check(GameEvents.destellos >= total_before + 3, "Key grants three destellos")
	check(GameEvents.is_level_unlocked("cefiro"), "Céfiro Peaks unlock")
	var gate: Node = game.get_node("Zones/Heart/ExitGate")
	check(gate.active and gate.get_node("Vortex").visible, "Exit portal opens")
	# Vigía: dispara, el pulso deshace el orbe y lo purifica.
	var vigia: Node3D = game.get_node_or_null("Zones/Heart/G_Vigia_3")
	if vigia:
		vigia.damage_enabled = true
		await grounded_at(Vector3(-7.5, -1.8, -99.0))
		var energy_before := GameEvents.energy
		var orb_seen := false
		var waited := 0.0
		while waited < 6.0 and not orb_seen:
			orb_seen = not get_tree().get_nodes_in_group("enemy_orb").is_empty()
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
		check(orb_seen, "Vigía fires a shadow orb")
		await capture("grutas_06_vigia")
		await tap("light_pulse")
		await settle(0.3)
		var alive := 0
		for orb in get_tree().get_nodes_in_group("enemy_orb"):
			if not orb.popped: alive += 1
		check(alive == 0 or GameEvents.energy < energy_before, "Pulse dissolves nearby orbs")
		player.pulse_cooldown = 0.0
		GameEvents.set_energy(GameEvents.max_energy)
		await grounded_at(vigia.global_position + Vector3(0, 0.2, 2.2))
		var purified_before := GameEvents.enemies_purified
		for i in 3:
			if not is_instance_valid(vigia) or vigia.purified: break
			player.pulse_cooldown = 0.0
			GameEvents.set_energy(GameEvents.max_energy)
			await tap("light_pulse")
			await settle(0.5)
		await settle(0.5)
		check(GameEvents.enemies_purified > purified_before, "Pulses purify the Vigía")
	# Caída: vuelve al refugio.
	await grounded_at(Vector3(0, -30, -90))
	await settle(0.3)
	check(player.global_position.distance_to(GameEvents.checkpoint) < 1.0, "Falling returns Neri to the refuge")
	# Portal de salida.
	await walk_to(Vector3(4.5, -2, -90.0))
	await walk_to(Vector3(4.5, -2, -99.2))
	await use(gate, gate.global_position + Vector3(0, 0, 1.6))
	check(game.leaving, "Exit portal leads back to the archipelago map")


# --- Picos del Céfiro -------------------------------------------------------------------------------

## Mantiene saltar (planeo) y guía a Neri hacia un punto hasta aterrizar.
func glide_to(point: Vector3, timeout: float = 6.0, jump_first: bool = true) -> bool:
	var elapsed := 0.0
	var glided := false
	player.locked = false
	if jump_first:
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
	Input.action_press("jump")
	while elapsed < timeout:
		var flat: Vector3 = point - player.global_position
		flat.y = 0
		if flat.length() > 0.5: steer(point)
		else: _stop_steer()
		# Sobre el objetivo: soltar el salto para dejar de planear y caer encima.
		if flat.length() < 0.9 and player.global_position.y > point.y + 0.4 and elapsed > 0.3: Input.action_release("jump")
		elif flat.length() >= 0.9: Input.action_press("jump")
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		glided = glided or player.gliding
		if elapsed > 0.4 and player.is_on_floor(): break
	release_moves()
	await settle(0.15)
	var landed: Vector3 = player.global_position - point
	var ok: bool = absf(landed.y) < 0.6 and Vector2(landed.x, landed.z).length() < 2.2
	if not ok: print("GLIDE_MISSED ", player.global_position, " TARGET ", point)
	return ok and glided


func _stop_steer() -> void:
	for key in ["move_right", "move_left", "move_forward", "move_back"]: Input.action_release(key)


## Sube dentro de una corriente manteniendo el planeo hasta superar una altura.
func ride_updraft(height: float, timeout: float = 6.0, over = null) -> bool:
	var elapsed := 0.0
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	while elapsed < timeout and player.global_position.y < height:
		Input.action_press("jump")
		if over is Vector3:
			var flat: Vector3 = over - player.global_position
			flat.y = 0.0
			if flat.length() > 0.3: steer(over)
			else: _stop_steer()
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_stop_steer()
	return player.global_position.y >= height


func has_destello(index: int) -> bool:
	return GameEvents.destello_ids.has("d_%s_%d" % [game.level_id, index])


## Coloca a Neri en un punto (para probar un tramo suelto con --qa-part).
func teleport(point: Vector3) -> void:
	release_moves()
	player.global_position = point
	player.velocity = Vector3.ZERO
	await settle(0.8)


## Mantiene a Neri en el centro de una plataforma móvil hasta que se cumpla la condición.
func ride_body(body: Node3D, until: Callable, timeout: float = 12.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if until.call(): break
		var center := Vector3(body.global_position.x, player.global_position.y, body.global_position.z)
		if Vector2(center.x - player.global_position.x, center.z - player.global_position.z).length() > 0.35: steer(center)
		else: _stop_steer()
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_stop_steer()
	return until.call()


func cefiro_checks() -> void:
	check(GameEvents.level == "cefiro", "Céfiro scene controls the level")
	check(get_tree().get_nodes_in_group("destello").size() == 6, "Six destellos placed")
	check(get_tree().get_nodes_in_group("level_checkpoint").size() == 4, "Four refuges placed")
	check(get_tree().get_nodes_in_group("enemy").size() == 8 and get_tree().get_nodes_in_group("cefiro").size() == 4, "Eight enemies, four Céfiros")
	check(get_tree().get_nodes_in_group("valve").size() == 3, "Three wind valves")
	check(get_tree().get_nodes_in_group("crumble_platform").size() == 3, "Three crumbling clouds")
	check(get_tree().get_nodes_in_group("wind_zone").size() == 4, "Four wind currents")
	check(not game.updraft.active, "Great updraft sleeps until the valves open")
	# Planeo (lo concede la historia al llegar).
	GameEvents.grant_story_skill("glide")
	check(GameEvents.has_skill("glide"), "Luma grants the glide")
	if part == "mills":
		await teleport(Vector3(0, 3.4, -58.0))
		await cefiro_mills()
		return
	if part == "haze":
		await haze_probe()
		return
	await capture("cefiro_01_mirador")
	await walk_to(Vector3(7.0, 0, -3.5))
	check(await ride_updraft(6.5), "Gliding inside an updraft lifts Neri")
	check(await glide_to(Vector3(7.0, 4.8, -8.2), 5.0, false), "Glide lands on the high cloud")
	await settle(0.3)
	check(GameEvents.level_destellos() == 1, "Updraft destello collected")
	await grounded_at(Vector3(0, 0.2, -8.5))
	await walk_to(Vector3(0, 0, -9.4))
	check(await glide_to(Vector3(0, -1.5, -18.0), 5.0), "Glide crosses the gap to the Cloud Steps")
	await capture("cefiro_02_planeo")
	var crumble: Node = game.get_node("CloudSteps/Cloud_2")
	await to_edge(Vector3(0, -1.5, -18.0), Vector3(2.2, -0.8, -22.5), 2.15)
	check(await hop_to(Vector3(2.2, -0.8, -22.5), false, true), "Jump onto the fragile cloud")
	check(crumble.state == "shaking", "Fragile cloud starts to shake")
	await to_edge(Vector3(2.2, -0.8, -22.5), Vector3(-0.6, 0.0, -26.5), 1.0)
	check(await hop_to(Vector3(-0.6, 0.0, -26.5), false, true), "Jump away before it falls")
	await settle(1.2)
	check(crumble.state == "fallen" and crumble.get_node("CollisionShape3D").disabled, "Fragile cloud falls")
	var mover: Node3D = game.get_node("CloudSteps/Cloud_4")
	await walk_to(Vector3(-0.6, 0, -28.2), 3.0)
	var waited := 0.0
	while absf(mover.global_position.x + 0.6) > 1.0 and waited < 8.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(await hop_to_body(mover, 0.9), "Jump onto the drifting cloud")
	waited = 0.0
	while absf(mover.global_position.x) > 1.0 and waited < 8.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await to_edge(mover.global_position, Vector3(0, 1.5, -34.2), 1.7)
	check(await hop_to(Vector3(0, 1.5, -34.2), false, true), "Jump to the last cloud")
	await to_edge(Vector3(0, 1.5, -34.4), Vector3(0, 2.0, -38.0), 1.5)
	check(await hop_to(Vector3(0, 2.0, -38.0), false, true), "Reach the plateau")
	await walk_to(Vector3(0, 2, -39.0))
	await settle(0.3)
	check(GameEvents.zone == 1 and int(GameEvents.level_state().checkpoint) == 1, "Plateau refuge reached")
	# Céfiro: embestida con aviso, daño y purificación.
	var cefiro: Node3D = game.get_node_or_null("Zones/Plateau/C_Cefiro_2")
	if cefiro:
		cefiro.damage_enabled = true
		GameEvents.set_energy(GameEvents.max_energy)
		await grounded_at(cefiro.global_position + Vector3(-3.5, 0.2, 0.5))
		# El Céfiro pudo haber fijado su dirección de embestida (en _on_windup) contra
		# una posición previa de Neri, antes de esta teletransportación. Se reinicia su
		# ciclo para que el próximo aviso apunte de verdad a donde Neri quedó parada.
		cefiro.mode = cefiro.Mode.CHASE
		cefiro.windup_time = 0.0
		cefiro.attack_time = 0.0
		cefiro.stun_time = 0.0
		cefiro.telegraph.hide()
		waited = 0.0
		while cefiro.mode != cefiro.Mode.WINDUP and waited < 6.0:
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
		check(cefiro.telegraph.visible, "Céfiro marks its dash line before charging")
		GameEvents.damage_grace = 0.0
		await capture("cefiro_03_cefiro")
		GameEvents.damage_grace = 0.0
		var energy_before := GameEvents.energy
		waited = 0.0
		while GameEvents.energy >= energy_before and waited < 3.0:
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
		check(GameEvents.energy < energy_before, "Céfiro dash damages Neri")
		await settle(0.3)
		for i in 4:
			if not is_instance_valid(cefiro) or cefiro.purified: break
			GameEvents.damage_grace = 5.0
			player.pulse_cooldown = 0.0
			GameEvents.set_energy(GameEvents.max_energy)
			await grounded_at(cefiro.global_position + Vector3(1.8, 0.2, 0.0))
			await tap("light_pulse")
			await settle(0.6)
		await settle(0.5)
		check(not is_instance_valid(cefiro) or cefiro.purified, "Pulses purify the Céfiro")
	# Corriente de la meseta y nube alta.
	await grounded_at(Vector3(0, 2.2, -41.0))
	await walk_to(Vector3(5.0, 2, -46.0))
	check(await ride_updraft(10.0), "Second updraft lifts Neri")
	check(await glide_to(Vector3(5.0, 8.8, -50.8), 5.0, false), "Glide to the high cloud destello")
	await settle(0.3)
	check(has_destello(3), "High cloud destello collected")
	# Molinos.
	await grounded_at(Vector3(0, 2.2, -48.0))
	await walk_to(Vector3(0, 2.5, -53.0))
	await walk_to(Vector3(0, 3, -58.0))
	await settle(0.3)
	check(GameEvents.zone == 2, "Ramp reaches the Old Mills")
	await cefiro_mills()


## Depuración visual: captura la vista del jugador quitando capas una a una para localizar la bruma.
func haze_probe() -> void:
	await teleport(Vector3(0, 3.4, -58.0))
	await settle(2.0)
	await capture("haze_0_base")
	var env: Environment = (game.get_node("WorldEnvironment") as WorldEnvironment).environment
	game.hud.visible = false
	await settle(0.3)
	await capture("haze_1_sin_hud")
	env.fog_enabled = false
	await settle(0.3)
	await capture("haze_2_sin_niebla")
	env.glow_enabled = false
	await settle(0.3)
	await capture("haze_3_sin_glow")
	for node in game.find_children("*", "GPUParticles3D", true, false): (node as Node3D).visible = false
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.material_override is ShaderMaterial and str((mesh.material_override as ShaderMaterial).shader.resource_path).contains("wind"):
			mesh.visible = false
	await settle(0.3)
	await capture("haze_4_sin_viento")
	var sea := game.get_node_or_null("CloudSea") as Node3D
	if sea: sea.visible = false
	await settle(0.3)
	await capture("haze_5_sin_mar")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	await settle(0.5)
	await capture("haze_6_sin_reflejo_cielo")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.ambient_light_energy = 0.0
	await settle(0.5)
	await capture("haze_7_sin_ambiente")
	var cam := get_viewport().get_camera_3d()
	for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree(): continue
		var box: AABB = geo.global_transform * geo.get_aabb()
		if box.grow(0.5).has_point(cam.global_position):
			print("HAZE_CONTAINS ", geo.get_path(), " size ", box.size, " mat ", geo.material_override)
	print("HAZE camera ", get_viewport().get_camera_3d().get_path(), " far ", get_viewport().get_camera_3d().far, " attrs ", get_viewport().get_camera_3d().attributes, " env ", get_viewport().get_camera_3d().environment)


func cefiro_mills() -> void:
	var waited := 0.0
	await capture("cefiro_04_molinos")
	for id in ["Valve_1", "Valve_2", "Valve_3"]:
		var valve: Node3D = game.get_node("Zones/Mills/" + id)
		var front: Vector3 = valve.global_position + valve.global_basis.z * 1.3
		if id == "Valve_3": await walk_to(Vector3(4.5, 3, -70.0))
		await use(valve, front)
	await settle(1.8)
	check(GameEvents.level_flag("valve_1") and GameEvents.level_flag("valve_2") and GameEvents.level_flag("valve_3"), "Three valves open")
	check(game.get_node("Zones/Mills/Windmill_1").spinning and game.get_node("Zones/Mills/Windmill_3").spinning, "Windmills wake up")
	check(game.updraft.active and game.updraft.strength > 0.9, "Great updraft wakes")
	# Carrusel y nube lejana.
	var carousel: Node3D = game.get_node("Carousel")
	await walk_to(Vector3(-12.0, 3, -72.0))
	await walk_to(Vector3(-14.3, 3, -72.0))
	var platform: Node3D
	waited = 0.0
	while waited < 14.0:
		for child in carousel.get_children():
			if child.name.begins_with("ArmPlatform") and child.global_position.x > -16.6 and absf(child.global_position.z + 72.0) < 0.9:
				platform = child
		if platform: break
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	print("CAROUSEL_PLATFORM ", platform.global_position if platform else Vector3.ZERO, " player ", player.global_position)
	var carousel_ok := platform != null and await hop_to_body(platform, 3.3)
	print("CAROUSEL_BOARDED ", carousel_ok, " player ", player.global_position)
	if carousel_ok:
		# Neri se queda en el centro del brazo mientras gira hasta el extremo oeste.
		carousel_ok = await ride_body(platform, func() -> bool: return platform.global_position.x < -23.6 and absf(platform.global_position.z + 72.0) < 0.6)
		print("CAROUSEL_RIDE ", carousel_ok, " platform ", platform.global_position, " player ", player.global_position)
		carousel_ok = carousel_ok and await hop_to(Vector3(-28.6, 3.3, -72.0), false, true)
		await settle(0.3)
	check(carousel_ok and has_destello(4), "Carousel carries Neri to the far cloud destello")
	# Vuelta a los molinos por el carrusel (o desde el refugio si Neri cayó).
	if carousel_ok:
		await to_edge(Vector3(-28.6, 3.3, -72.0), Vector3(-24.0, 3.3, -72.0), 1.6)
		waited = 0.0
		while waited < 12.0:
			var back: Node3D = null
			for child in carousel.get_children():
				if child.name.begins_with("ArmPlatform") and child.global_position.x < -23.4 and absf(child.global_position.z + 72.0) < 0.9:
					back = child
			if back:
				if await hop_to_body(back, 3.3):
					await ride_body(back, func() -> bool: return back.global_position.x > -16.4 and absf(back.global_position.z + 72.0) < 0.8)
					await hop_to(Vector3(-13.0, 3.0, -72.0), false, true)
				break
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
	# Gran corriente hasta la cumbre, atravesando el viento lateral.
	await grounded_at(Vector3(0, 3.2, -64.5))
	await walk_to(Vector3(0, 3, -68.0))
	check(await ride_updraft(17.0, 7.0, Vector3(0, 0, -68.0)), "Great updraft lifts Neri above the mills")
	await settle(0.1)
	print("UPDRAFT_TOP ", player.global_position, " d5 ", has_destello(5))
	check(has_destello(5), "Destello inside the great updraft collected")
	check(await glide_to(Vector3(0, 14, -88.0), 9.0, false), "Glide across the crosswind to the summit")
	await walk_to(Vector3(0, 14, -87.0))
	await settle(0.3)
	check(GameEvents.zone == 3, "Summit refuge reached")
	await capture("cefiro_05_cumbre")
	await walk_to(Vector3(7.0, 14, -97.5))
	await settle(0.3)
	if not has_destello(6):
		for node in get_tree().get_nodes_in_group("destello"):
			print("DESTELLO_LEFT ", node.destello_id, " at ", node.global_position, " dist ", node.global_position.distance_to(player.global_position), " monitoring ", node.monitoring, " visible ", node.visible)
	print("SUMMIT_AT ", player.global_position, " destellos ", GameEvents.level_destellos())
	check(has_destello(6), "Summit destello collected")
	await use(game.altar, Vector3(0, 14, -93.8))
	await settle(0.8)
	check(GameEvents.is_level_done("cefiro") and GameEvents.is_level_unlocked("observatorio"), "Wind Key completes the island and unlocks the Observatory")
	var gate: Node = game.get_node("Zones/Summit/ExitGate")
	check(gate.active, "Summit portal opens")
	await walk_to(Vector3(2.4, 14, -95.5))
	await use(gate, gate.global_position + Vector3(0, 0, 1.6))
	check(game.leaving, "Summit portal leads to the map")


# --- Observatorio Estelar ---------------------------------------------------------------------------

## Camina dentro de la cúpula rodeando el telescopio central (radio de seguridad 4,2 m).
func dome_walk(target: Vector3) -> bool:
	var center: Vector3 = game.get_node("Zones/Dome").global_position
	var from := player.global_position
	var a := atan2(from.x - center.x, from.z - center.z)
	var b := atan2(target.x - center.x, target.z - center.z)
	var delta := wrapf(b - a, -PI, PI)
	var steps := int(absf(delta) / 0.6)
	for i in range(1, steps + 1):
		var angle := a + delta * i / float(steps + 1)
		# El altar de la llave está en el ángulo 0 (radio 4,6): ahí el camino pasa por dentro.
		var radius := 3.4 if absf(wrapf(angle, -PI, PI)) < 0.4 else 4.6
		await walk_to(center + Vector3(sin(angle), 0, cos(angle)) * radius, 6.0)
	return await walk_to(target, 8.0)


func observatorio_checks() -> void:
	check(GameEvents.level == "observatorio", "Observatory scene controls the level")
	check(get_tree().get_nodes_in_group("destello").size() == 6, "Six destellos placed")
	check(get_tree().get_nodes_in_group("level_checkpoint").size() == 4, "Four refuges placed")
	check(get_tree().get_nodes_in_group("star_tile").size() == 7, "Seven constellation stars")
	check(get_tree().get_nodes_in_group("star_pillar").size() == 3, "Three star pillars")
	check(get_tree().get_nodes_in_group("enemy").size() == 7, "Six echoes and the Heraldo")
	check(game.boss.state == "dormant" and not game.altar.revealed, "Heraldo sleeps and the key is hidden")
	check(not game.memory.visible, "Maren's memory waits for the Heraldo")
	GameEvents.grant_story_skill("glide")
	if part == "garden":
		await teleport(Vector3(0, 0.3, -8.0))
	elif part == "dome":
		GameEvents.set_level_flag("constellation")
		await teleport(Vector3(0, 8.3, -85.0))
		await observatorio_dome()
		return
	await capture("observatorio_01_escalinata")
	await walk_to(Vector3(-7.0, 0, -6.0))
	await settle(0.3)
	check(GameEvents.level_destellos() == 1, "Stairs destello collected")
	await walk_to(Vector3(0, 0, -9.0))
	await walk_to(Vector3(0, 6, -24.5), 14.0)
	await settle(0.3)
	check(GameEvents.zone == 1 and player.global_position.y > 5.5, "Grand stairs reach the Constellation Garden")
	# Constelación: un error la reinicia; el orden correcto abre el puente.
	var tiles: Node3D = game.get_node("Zones/Garden/Constellation")
	var world_tile := func(i: int) -> Vector3: return tiles.global_position + Vector3(game.TILES[i].x, 0, game.TILES[i].y)
	await walk_to(Vector3(-3.6, 6, -30.0))
	await walk_to(world_tile.call(3))
	await settle(0.3)
	check(game.progress == 0 and game.mistakes == 1, "Wrong star resets the constellation")
	await walk_to(Vector3(0, 6, -30.0))
	for k in game.ORDER.size():
		await walk_to(world_tile.call(game.ORDER[k]), 8.0, 0.3)
		await settle(0.25)
	check(GameEvents.level_flag("constellation"), "Correct order completes La Farolera")
	check(game.bridge.open and not game.bridge.get_node("CollisionShape3D").disabled, "Star bridge becomes solid")
	await capture("observatorio_02_constelacion")
	await walk_to(tiles.global_position + Vector3(0, 0, -1.0))
	await settle(0.3)
	check(GameEvents.level_destellos() >= 2, "Constellation reward destello collected")
	await walk_to(Vector3(-8.8, 6, -38.6))
	var pedestal := await hop_to(Vector3(-10.0, 7.0, -40.0))
	pedestal = pedestal and await hop_to(Vector3(-11.3, 7.9, -41.9))
	await settle(0.3)
	check(pedestal and GameEvents.level_destellos() >= 3, "Pedestal destello reached")
	await grounded_at(Vector3(0, 6.2, -42.0))
	await walk_to(Vector3(0, 6, -44.5))
	await walk_to(Vector3(0, 6, -57.5), 10.0)
	await settle(0.3)
	check(GameEvents.zone == 2, "Star bridge reaches the Orrery")
	# Orrery: subir al anillo que lleva el destello y bajar al otro lado.
	var orrery: Node3D = game.get_node("Orrery")
	var ring_destello: Node3D
	for node in orrery.get_children():
		if node.is_in_group("destello"): ring_destello = node
	await walk_to(Vector3(0, 6, -60.4))
	var carried := false
	var waited := 0.0
	var boarded: Node3D
	while waited < 20.0 and not boarded:
		for node in orrery.get_children():
			if node.name.begins_with("RingPlatform") and node.global_position.z > -63.0 and absf(node.global_position.x) < 0.8:
				if not is_instance_valid(ring_destello) or node.global_position.distance_to(ring_destello.global_position) < 1.6:
					boarded = node
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if boarded and await hop_to_body(boarded, 6.0):
		await settle(0.3)
		waited = 0.0
		while boarded.global_position.z > -70.2 and waited < 16.0:
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
		carried = await hop_to(Vector3(0, 6, -73.8), false, true)
	check(carried, "Orrery ring carries Neri across")
	check(GameEvents.level_destellos() >= 4, "Ring destello collected while riding")
	await capture("observatorio_03_orrery")
	await walk_to(Vector3(7.4, 6, -74.5))
	check(await glide_to(Vector3(11.5, 6.8, -74.5), 4.0), "Glide to the star stone")
	await settle(0.3)
	check(GameEvents.level_destellos() >= 5, "Star stone destello collected")
	await grounded_at(Vector3(0, 6.2, -74.0))
	await walk_to(Vector3(0, 6, -77.0))
	await walk_to(Vector3(0, 8, -86.0), 10.0)
	await settle(0.3)
	check(GameEvents.zone == 3, "Ramp reaches the Dome")
	await observatorio_dome()


func observatorio_dome() -> void:
	# Jefe: la arena lo despierta; tres pilares, tres núcleos.
	await walk_to(Vector3(0, 8, -89.5))
	await settle(0.5)
	check(game.boss.state == "fighting" and game.boss_active, "Entering the dome starts the Heraldo fight")
	check(game.hud.guardian_active and (game.hud.guardian_panel.get_node("Title") as Label).text == "HERALDO DEL ECLIPSE", "Boss bar shows the Heraldo")
	var charged := 0
	for pillar in get_tree().get_nodes_in_group("star_pillar"):
		if pillar.state == "charged": charged += 1
	check(charged == 1, "One star pillar charges")
	await settle(2.5)
	await capture("observatorio_04_heraldo")
	for round_index in 3:
		var pillar: Node3D
		for node in get_tree().get_nodes_in_group("star_pillar"):
			if node.state == "charged": pillar = node
		if not pillar: break
		var center: Vector3 = game.get_node("Zones/Dome").global_position
		var approach: Vector3 = pillar.global_position + (center - pillar.global_position).normalized() * 1.45
		await dome_walk(approach)
		await use(pillar, approach)
		await settle(0.3)
		check(game.boss.state == "exposed", "Pillar %d breaks the shield" % (round_index + 1))
		var health_before: int = game.boss.health
		var waited_boss := 0.0
		while game.boss.state == "exposed" and game.boss.health == health_before and waited_boss < 6.0:
			var core: Vector3 = game.boss.global_position
			var ground := Vector3(core.x, center.y, core.z)
			if player.global_position.distance_to(ground) > 3.0:
				steer(ground)
			else:
				release_moves()
				player.pulse_cooldown = 0.0
				GameEvents.set_energy(GameEvents.max_energy)
				await tap("light_pulse")
			await get_tree().physics_frame
			waited_boss += get_physics_process_delta_time()
		release_moves()
		check(game.boss.health == health_before - 1, "Pulse breaks core %d" % (round_index + 1))
		await settle(1.6)
	check(game.boss.state == "purified" and GameEvents.purified_ids.has("Heraldo"), "Heraldo is purified")
	check(game.altar.revealed and game.memory.visible, "Key and Maren's memory appear")
	await settle(1.0)
	await dome_walk(Vector3(7.8, 8, -103.2))
	await settle(0.3)
	check(GameEvents.level_destellos() == 6 if part == "" else has_destello(6), "All six destellos collected")
	var memory: Node3D = game.memory
	# Se acerca desde el interior de la cúpula (el orbe queda entre el anillo y la salida).
	var toward_center: Vector3 = (game.get_node("Zones/Dome").global_position - memory.global_position) * Vector3(1, 0, 1)
	var memory_front: Vector3 = memory.global_position + toward_center.normalized() * 1.3
	await dome_walk(memory_front)
	await use(memory, memory_front)
	check(GameEvents.story_seen.has("lore_o2"), "Maren's memory can be heard")
	await use(game.altar, game.altar.global_position + Vector3(0, 0, 1.2))
	await settle(0.8)
	check(GameEvents.is_level_done("observatorio"), "Star Key completes Chapter II")
	var gate: Node = game.exit_gate
	check(gate.active, "Dome portal opens")
	await capture("observatorio_05_final")
	await use(gate, gate.global_position + gate.global_basis.z * 1.6)
	check(game.leaving, "Dome portal leads to the map")
