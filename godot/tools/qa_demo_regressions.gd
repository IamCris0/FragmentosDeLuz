extends SceneTree

const Art = preload("res://scripts/story_art.gd")
var checks: Array[String] = []
var failures: Array[String] = []

class LockedPlayer extends CharacterBody3D:
	var locked: bool = true

func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if ok: checks.append(label)
	else:
		failures.append(label)
		push_error("QA_FAILED: " + label)


func run() -> void:
	var state = root.get_node("GameEvents")
	check(state.is_qa_run(), "Specialized QA flag is recognized without --qa")
	check(not state.has_saved_progress(), "QA menu never reads the real player save")
	state.load_game()
	check(state.save_game(), "QA saving is a harmless no-op")
	var prologue = load("res://scripts/prologue_comic.gd").new()
	state.level = "cefiro"
	check(prologue.destination_scene() == "res://scenes/levels/cefiro.tscn", "Skipping the prologue preserves the saved island")
	state.story_seen["prologue"] = true
	state.replay_prologue = true
	check(prologue.destination_scene() == "res://scenes/title_menu.tscn" and state.story_seen.has("prologue"), "Replaying the prologue returns to the menu without changing progress")
	state.replay_prologue = false
	state.level = "auralia"
	prologue.free()
	var blocked = load("res://tools/fixtures/failed_save_state.gd").new()
	blocked.completed = true
	blocked.checkpoint = Vector3(0, 4.2, -79)
	blocked.zone = 3
	var before: Dictionary = blocked.snapshot().duplicate(true)
	check(blocked.travel_to("grutas").is_empty(), "Failed save cancels travel")
	check(blocked.snapshot() == before, "Failed travel restores all previous progress")
	blocked.free()
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var lateral_wind = load("res://scripts/wind_zone.gd").new()
	lateral_wind.lift = 0.0
	lateral_wind.push = Vector3.RIGHT
	root.add_child(lateral_wind)
	check(lateral_wind.column == null, "Crosswinds use particles without an opaque column")
	lateral_wind.queue_free()
	await process_frame
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphans_before, "Crosswind cleanup leaves no orphan mesh")

	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := LockedPlayer.new()
	player.add_to_group("player")
	world.add_child(player)
	player.position = Vector3(0, 0, 4)
	var boss = load("res://scripts/boss_heraldo.gd").new()
	world.add_child(boss)
	boss.set_physics_process(false)
	boss.damage_enabled = true
	state.skills.clear()
	state.energy = 100
	state.damage_grace = 0
	root.get_node("Preferences").difficulty = 1
	boss.state = "fighting"
	boss.sweep_time = 1.0
	boss.sweep_angle = 0.0
	boss.sweep_speed = 0.0
	boss._physics_process(0.25)
	check(state.energy == 100 and boss.sweep_time == 1.0, "Locked player cannot be hit by the sweep")
	check(boss.position == Vector3.ZERO, "Boss movement pauses with the encounter")
	boss.state = "exposed"
	boss.exposed_timer = 1.0
	boss._physics_process(0.25)
	check(boss.exposed_timer == 1.0, "Dialogue preserves the exposure window")
	player.locked = false
	boss._update_sweep(0.016)
	check(state.energy == 74, "Sweep damage resumes after returning control")
	world.queue_free()
	await process_frame
	await process_frame

	state.reset()
	state.completed = true
	state.collected = 7
	state.puzzle_solved = true
	state.story_seen["map_intro"] = true
	Art.base = load("res://tools/qa_art_fixtures.gd").build()
	Art.cache.clear()
	var map = load("res://scenes/archipelago_map.tscn").instantiate()
	root.size = Vector2i(1440, 900)
	root.add_child(map)
	current_scene = map
	await create_timer(0.5).timeout
	check(map.comic_open and map.has_node("Chapter2Comic"), "Existing save sees newly installed comic")
	map._travel()
	map._to_menu()
	map._open_constellation()
	check(not map.leaving and not map.constellation.visible, "Comic blocks underlying map actions")
	map.get_node("Chapter2Comic").finish()
	await create_timer(0.7).timeout
	check(state.story_seen.has("chapter2_comic") and not map.dialog_open, "Comic is remembered without repeating Luma's guide")
	check(root.gui_get_focus_owner() == map.travel_button, "Keyboard focus returns after the comic")
	map._select(0, true)
	await process_frame
	check(map.postcard.visible, "Large window shows the unlocked postcard")
	root.size = Vector2i(800, 640)
	await process_frame
	await process_frame
	check(not map.postcard.visible, "Resizing hides the postcard without reselecting")
	var panel: Control = map.root.get_node("Info")
	check(panel.get_global_rect().end.y <= 640, "Map information fits the minimum window")
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	check(map.postcard.visible, "Resizing back restores the postcard")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/qa_support.gd").output_folder("demo") + "map.png")
	map.queue_free()
	await process_frame
	await process_frame
	Art.cache.clear()
	Art.base = "res://"
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var file := FileAccess.open(preload("res://tools/qa_support.gd").output_folder("demo") + "regressions_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("DEMO_QA ", JSON.stringify(report))
	await preload("res://tools/qa_support.gd").finish(self, 0 if failures.is_empty() else 1)
