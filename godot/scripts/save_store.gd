extends RefCounted
## Guardado validado con escritura atómica y copia de seguridad.
## Fase 7 (v4): nivel actual, progreso por isla del archipiélago, destellos y habilidades.
## Las partidas v1–v3 se migran conservando el progreso del capítulo I.

const VERSION := 4
const LevelData = preload("res://scripts/level_data.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const INITIAL_TUTORIAL := "Mueve a Neri con WASD. Mantén clic derecho para orientar la cámara hacia el arco."
const CHECKPOINTS := [Vector3(0, 0.2, 7), Vector3(0, 0.2, -24), Vector3(0, 4.2, -54), Vector3(0, 4.2, -79)]
const FRAGMENT_IDS := ["fragment_0", "fragment_1", "fragment_2", "fragment_3", "fragment_4", "fragment_5", "fragment_6"]
const MAX_DESTELLOS := 999


static func number(value: Variant, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback


static func flags(value: Variant, limit: int = 64) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key in value:
			if key is String and key.length() <= 96 and value[key] is bool and value[key]:
				result[key] = true
				if result.size() >= limit: break
	return result


## Un nivel está disponible si el anterior está completo (Auralia siempre; Grutas tras el capítulo I).
static func level_unlocked(id: String, chapter_one_done: bool, levels: Dictionary) -> bool:
	if id == "auralia": return true
	var previous := LevelData.requirement(id)
	if previous == "": return false
	if previous == "auralia": return chapter_one_done
	return levels.has(previous) and bool((levels[previous] as Dictionary).get("done", false))


static func normalize_levels(value: Variant, chapter_one_done: bool) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary: return result
	# Se recorre en el orden del archipiélago para que "done" solo cuente si el nivel estaba desbloqueado.
	for id: String in LevelData.ORDER:
		if id == "auralia" or not value.has(id) or not value[id] is Dictionary: continue
		var entry: Dictionary = value[id]
		var count: int = LevelData.checkpoints(id).size()
		var unlocked := level_unlocked(id, chapter_one_done, result)
		result[id] = {"checkpoint": clampi(int(number(entry.get("checkpoint"), 0)), 0, count - 1) if unlocked else 0,
			"flags": flags(entry.get("flags"), 64) if unlocked else {},
			"done": unlocked and entry.get("done") is bool and entry["done"]}
	return result


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	if not value.get("fragments") is Dictionary: return {}
	var version := number(value.get("version", 1), -1)
	if version < 1 or version > VERSION or version != floor(version): return {}
	var fragments := flags(value.get("fragments"), 64)
	for key in fragments.keys():
		if not key in FRAGMENT_IDS:
			fragments.erase(key)
	var zone := clampi(int(number(value.get("zone"), 0)), 0, 3)
	var checkpoint: Vector3 = CHECKPOINTS[zone]
	var coordinates: Variant = value.get("checkpoint")
	if coordinates is Array and coordinates.size() == 3:
		var point := Vector3(number(coordinates[0], INF), number(coordinates[1], INF), number(coordinates[2], INF))
		if point.is_finite():
			for safe: Vector3 in CHECKPOINTS:
				if safe.distance_to(point) < 0.15: checkpoint = safe
	var puzzle: bool = value.get("puzzle") is bool and value["puzzle"]
	var completed: bool = value.get("completed") is bool and value["completed"] and fragments.size() == 7 and puzzle
	var allowed_enemies := LevelData.all_enemies()
	var purified := flags(value.get("purified_ids"), 96)
	for key in purified.keys():
		if not key in allowed_enemies:
			purified.erase(key)
	# --- v4 -------------------------------------------------------------------------------------
	var levels := normalize_levels(value.get("levels"), completed)
	var level: String = value.get("level") if value.get("level") is String else "auralia"
	if not LevelData.exists(level) or not level_unlocked(level, completed, levels): level = "auralia"
	var skills := flags(value.get("skills"), 32)
	for key in skills.keys():
		if not SkillData.valid(key): skills.erase(key)
	return {"version": VERSION, "fragments": fragments, "puzzle": puzzle,
		"lever": value.get("lever") is bool and value["lever"], "completed": completed,
		"checkpoint": [checkpoint.x, checkpoint.y, checkpoint.z], "zone": zone,
		"objective": value.get("objective", "Encuentra a Luma junto al arco antiguo") if value.get("objective", "") is String else "Encuentra a Luma junto al arco antiguo",
		"story": flags(value.get("story"), 192), "tutorial": clampi(int(number(value.get("tutorial"), 0)), 0, 99),
		"tutorial_text": value.get("tutorial_text", INITIAL_TUTORIAL) if value.get("tutorial_text", "") is String else INITIAL_TUTORIAL,
		"enemies_purified": maxi(purified.size(), clampi(int(number(value.get("enemies_purified"), 0)), 0, allowed_enemies.size())),
		"purified_ids": purified, "energy": clampf(number(value.get("energy"), 100), 0, 130),
		"level": level, "levels": levels,
		"destellos": clampi(int(number(value.get("destellos"), 0)), 0, MAX_DESTELLOS),
		"destello_ids": flags(value.get("destello_ids"), 256), "skills": skills}


static func read_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data


static func load_best(path: String) -> Dictionary:
	var document := read_document(path)
	if number(document.get("version"), 1) > VERSION:
		return {"data": {}, "recovered": false, "incompatible": true}
	var data := normalize(document) if not document.is_empty() else {}
	if not data.is_empty(): return {"data": data, "recovered": false, "incompatible": false}
	var backup := read_document(path + ".bak")
	data = normalize(backup) if not backup.is_empty() else {}
	return {"data": data, "recovered": not data.is_empty(), "incompatible": false}


static func write_atomic(path: String, value: Dictionary) -> Error:
	var data := normalize(value)
	if data.is_empty(): return ERR_INVALID_DATA
	var previous := read_document(path)
	if number(previous.get("version"), 1) > VERSION: return ERR_UNAVAILABLE
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	if normalize(read_document(temporary)).is_empty(): return ERR_FILE_CORRUPT
	# Never replace the healthy backup with a truncated or malformed primary file.
	if not previous.is_empty() and not normalize(previous).is_empty():
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK: return error
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK: return error
	return DirAccess.rename_absolute(temporary, path)
