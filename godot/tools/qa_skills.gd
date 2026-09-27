extends Node
## Fase 7: pruebas de la Constelación de Neri (árbol de habilidades). Se ejecutan en cualquier isla:
##   godot --path godot res://scenes/levels/grutas.tscn -- --qa --qa-skills
## Compra estrellas desde el panel (armar y confirmar), comprueba bloqueos por coste y requisito,
## mide el efecto real de cada habilidad con entradas del jugador (pulso, nova, doble salto, planeo,
## égida, brújula) y verifica que el guardado conserva las estrellas y el saldo.

var game: Node3D
var player: CharacterBody3D
var hud: Node
var checks: Array[String] = []
var failures: Array[String] = []
var images: Array[String] = []
var folder: String
var last_pulse: Dictionary = {}


func check(condition: bool, label: String) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error("QA_FAILED: " + label)


func settle(seconds: float = 0.35) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame


func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	check(not picture.is_empty(), "Image " + name_value)
	picture.save_png(folder + name_value + ".png")
	images.append(name_value + ".png")


## Pulsa una acción como evento de entrada (los menús escuchan eventos, no el estado de Input).
func press_event(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## Compra una estrella como lo haría el jugador en el panel: primera pulsación arma, segunda enciende.
func buy(id: String) -> bool:
	var panel: Control = hud.constellation
	var star: Button = panel.stars[id]
	var before: int = GameEvents.destellos
	star.grab_focus()
	await get_tree().process_frame
	star.pressed.emit()
	await get_tree().process_frame
	var armed: bool = panel.armed == id
	star.pressed.emit()
	await get_tree().process_frame
	var cost: int = int(load("res://scripts/skill_data.gd").skill(id).cost)
	return armed and GameEvents.has_skill(id) and GameEvents.destellos == before - cost


## Salta desde el suelo; con `second` pulsa otra vez en el aire. Devuelve la altura máxima alcanzada.
func jump_height(second: bool) -> float:
	await grounded()
	var base: float = player.global_position.y
	var top: float = base
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var elapsed := 0.0
	var pressed_again := false
	while elapsed < 2.5:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		top = maxf(top, player.global_position.y)
		if second and not pressed_again and player.velocity.y < 1.0:
			Input.action_press("jump")
			await frames(2)
			Input.action_release("jump")
			pressed_again = true
		if elapsed > 0.3 and player.is_on_floor(): break
	return top - base


func grounded() -> void:
	var waited := 0.0
	while not player.is_on_floor() and waited < 3.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	await frames(4)


## Planea tras un doble salto y devuelve la velocidad vertical más baja con las alas abiertas.
func glide_fall_speed() -> float:
	await grounded()
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var elapsed := 0.0
	var second := false
	var slowest := 0.0
	var glide_time := 0.0
	while elapsed < 4.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if not second and player.velocity.y < 1.0:
			Input.action_press("jump")
			second = true
		if player.gliding:
			glide_time += get_physics_process_delta_time()
			if glide_time > 0.5: slowest = minf(slowest, player.velocity.y)
		if elapsed > 0.4 and player.is_on_floor(): break
	Input.action_release("jump")
	return slowest


func pulse(hold: float) -> Dictionary:
	last_pulse = {}
	player.pulse_cooldown = 0.0
	GameEvents.set_energy(GameEvents.max_energy)
	Input.action_press("light_pulse")
	var elapsed := 0.0
	await get_tree().physics_frame
	while elapsed < hold:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	Input.action_release("light_pulse")
	elapsed = 0.0
	while last_pulse.is_empty() and elapsed < 1.5:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	return last_pulse


func _on_pulse(_origin: Vector3, radius: float, _force: float) -> void:
	last_pulse = {"radius": radius, "power": GameEvents.pulse_power}


func run(scene: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1440, 900)
	game = scene
	player = scene.player
	hud = scene.hud
	folder = preload("res://tools/qa_support.gd").output_folder("levels")
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 7: GameEvents.fragment_ids["fragment_%d" % i] = true
	GameEvents.collected = 7
	GameEvents.puzzle_solved = true
	GameEvents.completed = true
	GameEvents.skills.clear()
	GameEvents._apply_skill_stats()
	GameEvents.pulse_requested.connect(_on_pulse)
	# Neri se queda en un rincón tranquilo de la entrada, lejos de los ecos.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await settle(1.0)
	player.global_position = GameEvents.checkpoint
	await grounded()

	# --- Reglas de compra ----------------------------------------------------------------------------
	GameEvents.destellos = 1
	check(GameEvents.skill_block_reason("pulse_wide").begins_with("Necesitas"), "A star costs destellos")
	check(GameEvents.skill_block_reason("pulse_quick").begins_with("Enciende antes"), "A star needs its previous star")
	check(not GameEvents.unlock_skill("pulse_wide") and not GameEvents.has_skill("pulse_wide"), "Cannot buy without enough destellos")
	GameEvents.destellos = 40
	GameEvents.destellos_changed.emit(GameEvents.destellos, 0)

	# --- Panel ---------------------------------------------------------------------------------------
	await press_event("constellation")
	await settle(0.5)
	check(hud.constellation.visible and player.locked, "K opens the constellation and pauses Neri")
	var normal_radius: float = GameEvents.pulse_radius()
	check(await buy("pulse_wide"), "Arm and confirm buys Pulso amplio (2 destellos)")
	check(GameEvents.pulse_radius() > normal_radius * 1.2, "Pulso amplio widens the pulse")
	for id in ["pulse_quick", "pulse_nova", "agile_roll", "stride", "double_jump", "vitality"]:
		check(await buy(id), "Buys " + id)
	hud.constellation._select("serene_glide")
	await settle(0.3)
	await capture("skills_01_constelacion")
	check(GameEvents.skill_block_reason("serene_glide") == "" and GameEvents.destellos == 40 - 2 - 3 - 5 - 2 - 2 - 3 - 3, "Balance matches the stars bought")
	hud.constellation.close()
	await settle(0.4)
	check(not hud.constellation.visible and not player.locked, "Closing the constellation returns control")

	# --- Luz: pulso amplio y nova ----------------------------------------------------------------------
	var tap_pulse := await pulse(0.05)
	check(not tap_pulse.is_empty() and absf(float(tap_pulse.radius) - 4.6 * 1.25) < 0.01 and int(tap_pulse.power) == 1, "A tap fires the wide pulse")
	await settle(0.3)
	var nova := await pulse(0.8)
	check(not nova.is_empty() and float(nova.radius) > 4.6 * 1.25 * 1.4 and int(nova.power) == 2, "Holding Q charges a nova (wider, double power)")
	check(player.pulse_cooldown > GameEvents.pulse_cooldown(), "The nova needs a longer recharge")
	check(GameEvents.pulse_cooldown() < 2.4 * 0.75, "Pulso veloz shortens the recharge")

	# --- Viento: doble salto, zancada, rodada, planeo sereno -------------------------------------------
	GameEvents.skills.erase("glide")
	GameEvents.skills.erase("double_jump")
	var single := await jump_height(true)
	GameEvents.skills["double_jump"] = true
	var double := await jump_height(true)
	print("JUMPS single ", single, " double ", double)
	check(double > single + 0.8, "Double jump reaches much higher (%.2f m vs %.2f m)" % [double, single])
	check(GameEvents.dodge_cost() < 12.0 and GameEvents.sprint_drain() < 18.0, "Rodada ágil and Zancada lower energy costs")
	GameEvents.grant_story_skill("glide")
	var plain_glide := await glide_fall_speed()
	check(GameEvents.unlock_skill("serene_glide"), "Planeo sereno can be bought once the glide is known")
	var serene := await glide_fall_speed()
	print("GLIDE plain ", plain_glide, " serene ", serene)
	check(plain_glide < -1.8 and serene > plain_glide + 0.5, "Planeo sereno slows the descent (%.2f vs %.2f m/s)" % [serene, plain_glide])

	# --- Corazón: vitalidad, égida y brújula -----------------------------------------------------------
	check(is_equal_approx(GameEvents.max_energy, 130.0), "Vitalidad raises the energy to 130")
	check(GameEvents.unlock_skill("ember") and GameEvents.unlock_skill("aegis"), "Brasa interior and Égida de luz can be bought")
	check(GameEvents.shield_ready, "The aegis starts charged")
	GameEvents.damage_grace = 0.0
	GameEvents.set_energy(100.0)
	GameEvents.damage_player(20.0, "Prueba")
	check(is_equal_approx(GameEvents.energy, 100.0) and not GameEvents.shield_ready, "The aegis absorbs a full hit")
	await settle(0.2)
	await capture("skills_02_egida")
	GameEvents.damage_grace = 0.0
	GameEvents.damage_player(20.0, "Prueba")
	check(GameEvents.energy < 100.0, "Without the aegis the next hit hurts")
	GameEvents.shield_timer = 0.05
	await settle(0.4)
	check(GameEvents.shield_ready, "The aegis recharges")
	check(not hud.compass_box.visible, "No compass before buying it")
	check(GameEvents.unlock_skill("compass"), "Brújula de destellos can be bought")
	await settle(0.6)
	check(hud.compass_box.visible and hud.compass_target != null, "The compass points to the nearest destello")
	await capture("skills_03_brujula")

	# --- Retrato de diálogo (ilustración externa de ensayo, ver scripts/story_art.gd) ----------------
	var StoryArt = load("res://scripts/story_art.gd")
	StoryArt.base = load("res://tools/qa_art_fixtures.gd").build()
	hud.show_dialogue("LUMA · PRUEBA", "Así se verá el retrato de Luma cuando exista su ilustración.")
	await settle(0.5)
	var portrait: Control = hud.portrait
	var box: Rect2 = hud.dialog.get_global_rect()
	check(portrait != null and portrait.visible and portrait.get_global_rect().position.y >= 0.0 and portrait.get_global_rect().end.y > box.position.y
		and portrait.get_global_rect().position.y < box.position.y, "Dialogue portrait peeks above the dialogue box")
	await capture("art_04_retrato")
	hud.close_dialogue()
	hud.close_dialogue()
	await settle(0.2)
	check(portrait == null or not portrait.visible, "The portrait hides with the dialogue")
	hud.show_dialogue("MEMORIA DEL ARCHIPIÉLAGO", "Una memoria no tiene retrato.")
	await settle(0.3)
	check(portrait == null or not portrait.visible, "Memories have no portrait")
	hud.close_dialogue()
	hud.close_dialogue()
	StoryArt.base = "res://"

	# --- Guardado ------------------------------------------------------------------------------------
	var SaveStore = load("res://scripts/save_store.gd")
	var data: Dictionary = SaveStore.normalize(GameEvents.snapshot())
	var saved_all := true
	for id in GameEvents.skills:
		if not data.skills.has(id): saved_all = false
	check(saved_all and int(data.destellos) == GameEvents.destellos, "Save keeps every star and the balance")
	write_report()


func write_report() -> void:
	var report := {"suite": "skills", "level": game.level_id, "passed": failures.is_empty(), "checks": checks,
		"failures": failures, "images": images, "skills": GameEvents.skills.keys(), "destellos": GameEvents.destellos}
	var file := FileAccess.open(folder + "skills_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SKILLS_QA ", JSON.stringify(report))
	await preload("res://tools/qa_support.gd").finish(get_tree(), 0 if report.passed else 1)
