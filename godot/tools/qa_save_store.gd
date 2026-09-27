extends SceneTree

const Store = preload("res://scripts/save_store.gd")
var failures: Array[String] = []
var checks: Array[String] = []


func check(condition: bool, title: String) -> void:
	if condition: checks.append(title)
	else: failures.append(title)


func put(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var folder := ProjectSettings.globalize_path("user://qa_save_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("fixture.json")
	var initial := {"version": 3, "fragments": {"fragment_0": true}, "energy": 82.0, "zone": 1,
		"checkpoint": [0, 0.2, -24], "purified_ids": {"TutorialEcho": true}}
	check(Store.write_atomic(path, initial) == OK, "First save succeeds")
	check(Store.load_best(path).data.fragments.size() == 1, "Primary save loads")
	var advanced := initial.duplicate(true)
	advanced.fragments["fragment_1"] = true
	check(Store.write_atomic(path, advanced) == OK, "Replacing an existing save succeeds on Windows")
	check(Store.read_document(path + ".bak").fragments.size() == 1, "Backup preserves previous progress")
	put(path, "{\"version\":3,\"fragments\":")
	var restored := Store.load_best(path)
	check(restored.recovered and restored.data.fragments.size() == 1, "Truncated primary recovers from backup")
	check(Store.write_atomic(path, advanced) == OK, "Saving after recovery succeeds")
	check(Store.read_document(path + ".bak").fragments.size() == 1, "Recovery does not poison healthy backup")
	put(path + ".tmp", "interrupted write")
	check(Store.load_best(path).data.fragments.size() == 2, "Unfinished temporary write cannot replace primary")
	DirAccess.remove_absolute(path)
	check(Store.load_best(path).recovered, "Missing primary recovers from backup")
	put(path, JSON.stringify({"version": 1, "fragments": {"fragment_2": true}, "story": {"arrival": true}}))
	var legacy: Dictionary = Store.load_best(path).data
	check(legacy.version == Store.VERSION and legacy.fragments.has("fragment_2") and legacy.energy == 100, "Version one migrates with defaults")
	put(path, JSON.stringify({"version": 2, "fragments": {}, "enemies_purified": 2}))
	check(Store.load_best(path).data.enemies_purified == 2, "Version two retains legacy enemy count")
	var malformed := initial.duplicate(true)
	malformed.energy = "unknown"
	malformed.zone = []
	malformed.checkpoint = [NAN, INF, "bad"]
	malformed.story = []
	malformed.tutorial = {}
	malformed.fragments["unrelated"] = true
	malformed.fragments["fragment_1"] = false
	malformed.purified_ids["unrelated"] = true
	var sanitized := Store.normalize(malformed)
	check(sanitized.energy == 100 and sanitized.zone == 0 and sanitized.tutorial == 0, "Wrong numeric types use defaults")
	check(Vector3(sanitized.checkpoint[0], sanitized.checkpoint[1], sanitized.checkpoint[2]).is_equal_approx(Vector3(0, 0.2, 7)), "Invalid coordinates recover to safe checkpoint")
	check(sanitized.story.is_empty() and sanitized.fragments.size() == 1 and sanitized.purified_ids.size() == 1, "Invalid flags and unrelated IDs cannot inflate progress")
	malformed.energy = -45
	check(Store.normalize(malformed).energy == 0, "Energy is clamped")
	check(Store.normalize({"version": 3, "fragments": []}).is_empty(), "Malformed progress schema is rejected")
	# --- Fase 7: guardado v4 -------------------------------------------------------------------
	var chapter_one := {"version": 3, "fragments": {}, "puzzle": true, "completed": true, "story": {"prologue": true}}
	for i in 7: chapter_one.fragments["fragment_%d" % i] = true
	var v3 := Store.normalize(chapter_one)
	check(v3.version == 4 and v3.level == "auralia" and v3.levels.is_empty() and v3.destellos == 0 and v3.skills.is_empty(), "Version three migrates to v4 defaults")
	var early := chapter_one.duplicate(true)
	early.completed = false
	early.levels = {"grutas": {"checkpoint": 2, "done": true, "flags": {"door_1": true}}}
	early.level = "grutas"
	var locked := Store.normalize(early)
	check(locked.level == "auralia" and not locked.levels.grutas.done and locked.levels.grutas.flags.is_empty(), "Islands stay locked until chapter one is complete")
	var chain := chapter_one.duplicate(true)
	chain.levels = {"grutas": {"checkpoint": 99, "done": true, "flags": {"door_1": true, "bad": 3}}, "cefiro": {"checkpoint": -4, "done": true}, "unknown": {"done": true}}
	chain.level = "observatorio"
	var unlocked := Store.normalize(chain)
	check(unlocked.level == "observatorio" and unlocked.levels.grutas.checkpoint == 3 and unlocked.levels.cefiro.checkpoint == 0, "Unlocked island chain and checkpoint indices are clamped")
	check(not unlocked.levels.has("unknown") and unlocked.levels.grutas.flags.size() == 1, "Unknown islands and non-boolean flags are discarded")
	chain.levels.erase("cefiro")
	check(Store.normalize(chain).level == "auralia", "A locked current island falls back to Auralia")
	chain.skills = {"double_jump": true, "glide": true, "fly_forever": true}
	chain.destellos = 5000
	chain.purified_ids = {"G_Vigia_1": true, "Heraldo": true, "Nobody": true}
	var extras := Store.normalize(chain)
	check(extras.skills.size() == 2 and not extras.skills.has("fly_forever"), "Only known skills are restored")
	check(extras.destellos == Store.MAX_DESTELLOS and Store.normalize({"version": 4, "fragments": {}, "destellos": "x"}).destellos == 0 and Store.normalize({"version": 4, "fragments": {}, "destellos": -3}).destellos == 0, "Destellos balance is clamped")
	check(extras.purified_ids.size() == 2 and extras.purified_ids.has("Heraldo"), "Archipelago enemies are accepted and unknown IDs rejected")
	check(Store.normalize({"version": 2.5, "fragments": {}}).is_empty(), "Fractional schema version is rejected")
	put(path, JSON.stringify({"version": Store.VERSION + 1, "fragments": {"fragment_4": true}}))
	var future_before := FileAccess.get_file_as_string(path)
	check(Store.load_best(path).incompatible, "Future schema is detected")
	check(Store.write_atomic(path, initial) == ERR_UNAVAILABLE and FileAccess.get_file_as_string(path) == future_before, "Future save cannot be overwritten")
	check(Store.write_atomic(path, {}) == ERR_INVALID_DATA, "Invalid write is rejected")
	check(Store.write_atomic(folder.path_join("missing/fixture.json"), initial) != OK, "Unwritable destination reports failure")
	put(path, "broken")
	put(path + ".bak", "broken")
	check(Store.load_best(path).data.is_empty(), "Two corrupt files fail gracefully")
	for name in ["fixture.json", "fixture.json.bak", "fixture.json.tmp", "fixture.json.bak.tmp"]:
		var temporary := folder.path_join(name)
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	DirAccess.remove_absolute(folder)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "isolated_from_player_save": true}
	put(preload("res://tools/qa_support.gd").output_folder("adventure") + "save_report.json", JSON.stringify(report, "\t"))
	print("SAVE_QA ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
