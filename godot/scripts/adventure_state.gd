extends Node

signal fragments_changed(collected: int, total: int)
signal energy_changed(current: float, maximum: float)
signal objective_changed(text: String)
signal story_requested(speaker: String, text: String)
signal toast_requested(text: String)
signal puzzle_changed(solved: bool)
signal crystal_activated
signal sound_requested(cue: String)
signal zone_changed(index: int, title: String)
signal tutorial_changed(stage: int, text: String)
signal threat_changed(active_enemies: int)
signal pulse_requested(origin: Vector3, radius: float, force: float)
signal pulse_changed(ratio: float, ready: bool)
signal player_hit(amount: float, reason: String)
signal enemy_purified(enemy_id: StringName, total: int)
signal player_depleted
signal dodge_started(origin: Vector3, direction: Vector3)
signal dodge_changed(ratio: float, ready: bool)
signal guardian_changed(active: bool, integrity: int, state: String)
signal save_status_changed(success: bool, message: String)
signal cinematic_changed(active: bool)
signal voice_requested(cue: String)
## Fase 7: archipiélago, destellos y Constelación de Neri.
signal destellos_changed(balance: int, gained: int)
signal skills_changed
signal level_progress_changed(caption: String, current: int, total: int)
signal hint_changed(text: String)
signal shield_changed(ready: bool, ratio: float)
signal shield_absorbed

const TOTAL: int = 7
## Fase 6: memorias de Auralia coleccionables (story_seen["lore_1".."lore_5"]).
const LORE_TOTAL: int = 5
const LORE_TITLES := {"lore_1": "Los faroleros", "lore_2": "El jardín que sonaba", "lore_3": "Mareas de luz",
	"lore_4": "Faroles lejanos", "lore_5": "La señal imposible"}
const SAVE_PATH: String = "user://fragmentos_save.json"
const SaveStore = preload("res://scripts/save_store.gd")
const LevelData = preload("res://scripts/level_data.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const INITIAL_TUTORIAL := "Mueve a Neri con WASD. Mantén clic derecho para orientar la cámara hacia el arco."
const AEGIS_RECHARGE := 25.0
var collected: int = 0
var fragment_ids: Dictionary = {}
var puzzle_solved: bool = false
var lever_on: bool = false
var completed: bool = false
var checkpoint: Vector3 = Vector3(0, 0.2, 7)
var zone: int = 0
var energy: float = 100.0
var objective: String = "Encuentra a Luma junto al arco antiguo"
var story_seen: Dictionary = {}
var loaded: bool = false
var tutorial_stage: int = 0
var tutorial_text: String = INITIAL_TUTORIAL
var active_threats: int = 0
var enemies_purified: int = 0
var purified_ids: Dictionary = {}
var damage_grace: float = 0.0
var save_status: String = "El progreso se guarda al avanzar"
var save_error_notified: bool = false
var cinematic_active: bool = false
# --- Fase 7 -------------------------------------------------------------------------------------
var level: String = "auralia"
var levels: Dictionary = {}
var destellos: int = 0
var destello_ids: Dictionary = {}
var skills: Dictionary = {}
var hint: String = ""
var max_energy: float = 100.0
## Punto de control y zona de Auralia mientras se juega en otra isla (el guardado v3 los conserva).
var auralia_checkpoint: Vector3 = Vector3(0, 0.2, 7)
var auralia_zone: int = 0
## Daño del pulso en curso (2 con la Nova). Los enemigos lo leen al recibir pulse_requested.
var pulse_power: int = 1
## Título de la barra del jefe (GuardianStatus del HUD).
var boss_title: String = "GUARDIÁN DEL FARO"
var shield_ready: bool = false
var shield_timer: float = 0.0


func _physics_process(delta: float) -> void:
	damage_grace = maxf(0.0, damage_grace - delta)
	if has_skill("aegis") and not shield_ready:
		shield_timer = maxf(shield_timer - delta, 0.0)
		if shield_timer <= 0.0:
			shield_ready = true
			shield_changed.emit(true, 1.0)
			sound_requested.emit("shield_ready")
		else:
			shield_changed.emit(false, 1.0 - shield_timer / AEGIS_RECHARGE)


func collect(fragment_id: StringName) -> bool:
	if fragment_ids.has(str(fragment_id)) or collected >= TOTAL:
		return false
	fragment_ids[str(fragment_id)] = true
	collected = fragment_ids.size()
	fragments_changed.emit(collected, TOTAL)
	toast_requested.emit("Fragmento recuperado · %d de %d" % [collected, TOTAL])
	sound_requested.emit("pickup")
	if collected == TOTAL:
		set_objective("Regresa al portal y devuelve la luz a Auralia")
		crystal_activated.emit()
	save_game()
	return true


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func set_energy(value: float) -> void:
	energy = clampf(value, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)


func lore_count() -> int:
	var count: int = 0
	for id in LORE_TITLES:
		if story_seen.has(id): count += 1
	return count


func damage_player(amount: float, reason: String) -> bool:
	if damage_grace > 0.0 or amount <= 0.0:
		return false
	# Fase 7: la Égida de luz absorbe un golpe completo y se recarga.
	if has_skill("aegis") and shield_ready:
		shield_ready = false
		shield_timer = AEGIS_RECHARGE
		damage_grace = 0.9
		shield_changed.emit(false, 0.0)
		shield_absorbed.emit()
		sound_requested.emit("shield_block")
		toast_requested.emit("La égida de luz absorbió el golpe")
		return true
	# Fase 6: el modo Relato reduce a la mitad el daño recibido.
	if Preferences.difficulty == 0:
		amount *= 0.5
	damage_grace = 0.9
	set_energy(energy - amount)
	player_hit.emit(amount, reason)
	toast_requested.emit(reason)
	if energy <= 0.5:
		player_depleted.emit()
	return true


func request_pulse(origin: Vector3, radius: float = 4.6, force: float = 1.55, power: int = 1) -> void:
	pulse_power = power
	pulse_requested.emit(origin, radius, force)
	pulse_power = 1


func set_pulse_ready(ratio: float, ready: bool) -> void:
	pulse_changed.emit(clampf(ratio, 0.0, 1.0), ready)


func set_threat(count: int) -> void:
	count = max(count, 0)
	if count == active_threats:
		return
	active_threats = count
	threat_changed.emit(active_threats)


func set_tutorial(stage: int, text: String) -> void:
	if stage == tutorial_stage and text == tutorial_text:
		return
	if stage < tutorial_stage and text != "":
		return
	tutorial_stage = max(stage, tutorial_stage)
	tutorial_text = text
	tutorial_changed.emit(tutorial_stage, tutorial_text)
	save_game()


## Pista contextual de los niveles del archipiélago (no se guarda; la recalcula el nivel).
func set_hint(text: String) -> void:
	if text == hint: return
	hint = text
	hint_changed.emit(text)


func register_enemy_purified(enemy_id: StringName) -> bool:
	if purified_ids.has(str(enemy_id)):
		return false
	purified_ids[str(enemy_id)] = true
	enemies_purified += 1
	award("enemy_" + str(enemy_id), 5 if str(enemy_id) == "Heraldo" else 1)
	enemy_purified.emit(enemy_id, enemies_purified)
	save_game()
	return true


func story(id: String, speaker: String, text: String) -> void:
	story_seen[id] = true
	story_requested.emit(speaker, text)
	sound_requested.emit("story")
	voice_requested.emit("vo_" + id)
	if id.begins_with("lore_"): award(id, 1)
	save_game()


func set_cinematic(active: bool) -> void:
	if cinematic_active == active:
		return
	cinematic_active = active
	cinematic_changed.emit(active)


## Informa al menú principal si existe una partida que se pueda continuar.
func has_saved_progress() -> bool:
	if "--qa" in OS.get_cmdline_user_args() and not "--qa-menu-save" in OS.get_cmdline_user_args():
		return false
	var result: Dictionary = SaveStore.load_best(SAVE_PATH)
	var data: Dictionary = result.data
	return not data.is_empty() and (data.get("story", {}) as Dictionary).has("prologue")


# --- Fase 7: destellos y habilidades --------------------------------------------------------------

## Concede destellos una sola vez por fuente ("enemy_X", "lore_X", "key_X", "d_nivel_N", "chapter1").
func award(source: String, amount: int, quiet: bool = false) -> bool:
	if amount <= 0 or destello_ids.has(source):
		return false
	destello_ids[source] = true
	destellos = mini(destellos + amount, SaveStore.MAX_DESTELLOS)
	destellos_changed.emit(destellos, 0 if quiet else amount)
	if not quiet: sound_requested.emit("destello")
	return true


## Recompensas retroactivas: partidas anteriores reciben los destellos de lo que ya lograron.
func sync_awards() -> int:
	var before := destellos
	for id in purified_ids: award("enemy_" + str(id), 5 if str(id) == "Heraldo" else 1, true)
	for id in LORE_TITLES:
		if story_seen.has(id): award(id, 1, true)
	for id in LevelData.MEMORY_TITLES:
		if story_seen.has(id): award(id, 1, true)
	if completed: award("chapter1", 3, true)
	for id in levels:
		if bool(levels[id].get("done", false)): award("key_" + str(id), 3, true)
	return destellos - before


func has_skill(id: String) -> bool:
	return id == SkillData.ROOT or skills.has(id)


## Motivo por el que no se puede comprar una habilidad ("" si se puede).
func skill_block_reason(id: String) -> String:
	var data := SkillData.skill(id)
	if data.is_empty(): return "Estrella desconocida"
	if has_skill(id): return "Ya brilla en tu constelación"
	if not has_skill(str(data.requires)): return "Enciende antes «%s»" % SkillData.skill(str(data.requires)).get("title", "")
	if destellos < int(data.cost): return "Necesitas %d destellos" % int(data.cost)
	return ""


func unlock_skill(id: String) -> bool:
	if skill_block_reason(id) != "": return false
	destellos -= int(SkillData.skill(id).cost)
	skills[id] = true
	_apply_skill_stats()
	destellos_changed.emit(destellos, 0)
	skills_changed.emit()
	sound_requested.emit("skill_unlock")
	save_game()
	return true


## Habilidades de historia (Planeo). No cuestan destellos.
func grant_story_skill(id: String) -> void:
	if skills.has(id) or not SkillData.STORY_SKILLS.has(id): return
	skills[id] = true
	skills_changed.emit()
	save_game()


func _apply_skill_stats() -> void:
	max_energy = 130.0 if has_skill("vitality") else 100.0
	energy = minf(energy, max_energy)
	if has_skill("aegis") and not shield_ready and shield_timer <= 0.0:
		shield_ready = true
	energy_changed.emit(energy, max_energy)
	shield_changed.emit(shield_ready, 1.0 if shield_ready else 1.0 - shield_timer / AEGIS_RECHARGE)


func pulse_radius() -> float: return 4.6 * (1.25 if has_skill("pulse_wide") else 1.0)
func pulse_cooldown() -> float: return 2.4 * (0.7 if has_skill("pulse_quick") else 1.0)
func stun_multiplier() -> float: return 1.6 if has_skill("pulse_daze") else 1.0
func dodge_cost() -> float: return 7.0 if has_skill("agile_roll") else 12.0
func dodge_cooldown() -> float: return 1.0 if has_skill("agile_roll") else 1.4
func sprint_drain() -> float: return 11.0 if has_skill("stride") else 18.0
func regen_rate() -> float: return 18.0 if has_skill("ember") else 12.0
func hit_regen_delay() -> float: return 2.0 if has_skill("ember") else 3.0


# --- Fase 7: archipiélago -------------------------------------------------------------------------

func level_state(id: String = "") -> Dictionary:
	if id == "": id = level
	if not levels.has(id): levels[id] = {"checkpoint": 0, "flags": {}, "done": false}
	return levels[id]


func level_flag(flag: String, id: String = "") -> bool:
	return bool((level_state(id).flags as Dictionary).get(flag, false))


func set_level_flag(flag: String, value: bool = true, id: String = "") -> void:
	var state_flags: Dictionary = level_state(id).flags
	if value: state_flags[flag] = true
	else: state_flags.erase(flag)
	save_game()


func is_level_unlocked(id: String) -> bool:
	return SaveStore.level_unlocked(id, completed, levels)


func is_level_done(id: String) -> bool:
	if id == "auralia": return completed
	return levels.has(id) and bool(levels[id].get("done", false))


func chapter_two_open() -> bool:
	return completed


## Destellos recogidos en un nivel (solo los objetos d_nivel_N).
func level_destellos(id: String = "") -> int:
	if id == "": id = level
	var count := 0
	for key in LevelData.destello_ids(id):
		if destello_ids.has(key): count += 1
	return count


func level_memories(id: String = "") -> int:
	if id == "": id = level
	var count := 0
	for key in LevelData.level(id).memories:
		if story_seen.has(key): count += 1
	return count


func emit_level_progress() -> void:
	if level == "auralia":
		fragments_changed.emit(collected, TOTAL)
	else:
		level_progress_changed.emit("DESTELLOS DE LA ISLA", level_destellos(), int(LevelData.level(level).destellos))


func collect_destello(id: String) -> bool:
	if not award(id, 1): return false
	toast_requested.emit("Destello encontrado · %d de %d" % [level_destellos(), int(LevelData.level(level).destellos)])
	emit_level_progress()
	save_game()
	return true


## Prepara el estado al cargar la escena de un nivel.
func enter_level(id: String) -> void:
	if not LevelData.exists(id): id = "auralia"
	if level == "auralia" and id != "auralia":
		auralia_checkpoint = checkpoint
		auralia_zone = zone
	level = id
	if id == "auralia":
		checkpoint = auralia_checkpoint
		zone = auralia_zone
		return
	var points: Array = LevelData.checkpoints(id)
	var index: int = clampi(int(level_state(id).checkpoint), 0, points.size() - 1)
	checkpoint = points[index]
	zone = index
	hint = ""


func set_level_checkpoint(index: int) -> void:
	if level == "auralia": return
	var points: Array = LevelData.checkpoints(level)
	index = clampi(index, 0, points.size() - 1)
	var state := level_state()
	checkpoint = points[index]
	zone = index
	if int(state.checkpoint) != index:
		state.checkpoint = index
		save_game()


func complete_level(id: String = "") -> void:
	if id == "": id = level
	if id == "auralia" or is_level_done(id): return
	level_state(id).done = true
	award("key_" + id, 3)
	save_game()


## Viaje desde la Carta del Archipiélago. Devuelve la escena a cargar ("" si está bloqueado).
func travel_to(id: String) -> String:
	if not LevelData.exists(id) or not is_level_unlocked(id): return ""
	if level == "auralia" and id != "auralia":
		auralia_checkpoint = checkpoint
		auralia_zone = zone
	if id == "auralia":
		# Se llega por el portal del faro.
		auralia_checkpoint = LevelData.checkpoints("auralia")[3]
		auralia_zone = 3
		checkpoint = auralia_checkpoint
		zone = 3
	elif is_level_done(id):
		level_state(id).checkpoint = 0
	level = id
	if id != "auralia": enter_level(id)
	save_game()
	return LevelData.scene_for(id)


func reset() -> void:
	collected = 0
	fragment_ids.clear()
	puzzle_solved = false
	lever_on = false
	completed = false
	checkpoint = Vector3(0, 0.2, 7)
	zone = 0
	energy = 100.0
	story_seen.clear()
	objective = "Encuentra a Luma junto al arco antiguo"
	tutorial_stage = 0
	tutorial_text = INITIAL_TUTORIAL
	active_threats = 0
	enemies_purified = 0
	purified_ids.clear()
	damage_grace = 0.0
	cinematic_active = false
	level = "auralia"
	levels.clear()
	destellos = 0
	destello_ids.clear()
	skills.clear()
	hint = ""
	auralia_checkpoint = checkpoint
	auralia_zone = 0
	shield_ready = false
	shield_timer = 0.0
	_apply_skill_stats()
	loaded = true
	fragments_changed.emit(0, TOTAL)
	energy_changed.emit(energy, max_energy)
	objective_changed.emit(objective)
	threat_changed.emit(0)
	tutorial_changed.emit(0, INITIAL_TUTORIAL)
	destellos_changed.emit(0, 0)
	skills_changed.emit()
	save_game()


## Documento de guardado del estado actual (también lo usan las pruebas para validar el formato).
func snapshot() -> Dictionary:
	var chapter_checkpoint: Vector3 = checkpoint if level == "auralia" else auralia_checkpoint
	var chapter_zone: int = zone if level == "auralia" else auralia_zone
	return {"version": SaveStore.VERSION, "fragments": fragment_ids, "puzzle": puzzle_solved,
		"lever": lever_on, "completed": completed, "checkpoint": [chapter_checkpoint.x, chapter_checkpoint.y, chapter_checkpoint.z],
		"zone": chapter_zone, "objective": objective, "story": story_seen, "tutorial": tutorial_stage,
		"tutorial_text": tutorial_text, "enemies_purified": enemies_purified, "purified_ids": purified_ids, "energy": energy,
		"level": level, "levels": levels, "destellos": destellos, "destello_ids": destello_ids, "skills": skills}


## Cualquier ejecución de prueba (--qa, --qa-art, --qa-map, --qa-skills, etc.) debe
## comportarse como si fuera aislada: nunca debe leer ni sobrescribir la partida real,
## aunque se invoque sin el modificador --qa base (ver DESARROLLO.md).
func is_qa_run() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa"): return true
	return false


func save_game(manual: bool = false) -> bool:
	if is_qa_run():
		return true
	var error: Error = SaveStore.write_atomic(SAVE_PATH, snapshot())
	if error == OK:
		save_status = "Guardado a las " + Time.get_time_string_from_system()
		save_error_notified = false
	else:
		save_status = "No se pudo guardar. La copia anterior se conserva."
		if not save_error_notified: push_warning("Save failed: " + error_string(error))
		if not save_error_notified or manual: toast_requested.emit(save_status)
		save_error_notified = true
	save_status_changed.emit(error == OK, save_status)
	if manual and error == OK: toast_requested.emit("Partida guardada")
	return error == OK


func load_game() -> void:
	if loaded:
		return
	loaded = true
	if is_qa_run():
		_apply_skill_stats()
		return
	var result: Dictionary = SaveStore.load_best(SAVE_PATH)
	if result.incompatible:
		save_status = "Partida de una versión posterior: no se sobrescribirá."
		return
	if result.recovered: save_status = "Partida recuperada desde la copia de seguridad"
	var data: Dictionary = result.data
	if data.is_empty(): return
	fragment_ids = data.get("fragments", {})
	collected = mini(fragment_ids.size(), TOTAL)
	puzzle_solved = data.get("puzzle", false)
	lever_on = data.get("lever", false)
	completed = data.get("completed", false)
	zone = clampi(int(data.get("zone", 0)), 0, 3)
	objective = str(data.get("objective", objective))
	story_seen = data.get("story", {})
	tutorial_stage = int(data.get("tutorial", tutorial_stage))
	tutorial_text = str(data.get("tutorial_text", tutorial_text))
	enemies_purified = int(data.get("enemies_purified", 0))
	var saved_ids: Variant = data.get("purified_ids", {})
	purified_ids = saved_ids if saved_ids is Dictionary else {}
	var position_data: Variant = data.get("checkpoint", [0, 0.2, 7])
	if position_data is Array and position_data.size() == 3:
		checkpoint = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	levels = data.get("levels", {})
	destellos = int(data.get("destellos", 0))
	destello_ids = data.get("destello_ids", {})
	skills = data.get("skills", {})
	_apply_skill_stats()
	energy = clampf(float(data.get("energy", energy)), 0.0, max_energy)
	if energy <= 0.5: energy = 60.0
	damage_grace = 2.5
	auralia_checkpoint = checkpoint
	auralia_zone = zone
	level = "auralia"
	var saved_level: String = str(data.get("level", "auralia"))
	if saved_level != "auralia": enter_level(saved_level)
	sync_awards()
