extends Node

var game: Node3D
var player: CharacterBody3D
var checks: Array[String] = []
var failures: Array[String] = []
var images: Array[String] = []
var folder: String
var guardian_suite_completed: bool = false


func check(condition: bool, label: String) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error("QA_FAILED: " + label)


func settle(seconds: float = 0.35) -> void:
	await get_tree().create_timer(seconds).timeout


func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	check(not picture.is_empty(), "Image " + name_value)
	picture.save_png(folder + name_value + ".png")
	images.append(name_value + ".png")


func close_story() -> void:
	game.hud.revealed = 10000
	game.hud.dialogue_text.visible_characters = 10000
	game.hud.close_dialogue()


func walk_to(point: Vector3, timeout: float = 12.0) -> bool:
	var elapsed: float = 0
	player.locked = false
	while elapsed < timeout:
		var delta_pos: Vector3 = point - player.global_position
		delta_pos.y = 0
		if delta_pos.length() < 0.38: break
		var direction: Vector3 = player.pivot.global_basis.inverse() * delta_pos.normalized()
		Input.action_press("move_right", maxf(0,direction.x))
		Input.action_press("move_left", maxf(0,-direction.x))
		Input.action_press("move_back", maxf(0,direction.z))
		Input.action_press("move_forward", maxf(0,-direction.z))
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	for key in ["move_right","move_left","move_forward","move_back"]: Input.action_release(key)
	await settle(.12)
	var difference: Vector3 = player.global_position-point
	difference.y=0
	if difference.length()>=.7: print("BLOCKED_AT ",player.global_position," TARGET ",point)
	return difference.length()<.7


func run(scene: Node3D) -> void:
	game=scene
	player=game.player
	folder=preload("res://tools/qa_support.gd").output_folder("adventure")
	DirAccess.make_dir_recursive_absolute(folder)
	await settle(1.5)
	if "--qa-guardian" in OS.get_cmdline_user_args():
		await guardian_checks()
		await write_report()
		return
	if "--qa-avatar" in OS.get_cmdline_user_args():
		await avatar_checks()
		await write_report()
		return
	if "--qa-combat" in OS.get_cmdline_user_args():
		await combat_checks()
		await write_report()
		return
	if "--qa-cinematics" in OS.get_cmdline_user_args():
		await cinematic_checks()
		await write_report()
		return
	if "--qa-gamepad" in OS.get_cmdline_user_args():
		await gamepad_checks()
		await write_report()
		return
	if "--qa-memories" in OS.get_cmdline_user_args():
		await memory_checks()
		await write_report()
		return
	if "--qa-ramp" in OS.get_cmdline_user_args():
		GameEvents.puzzle_solved=true
		game._refresh_gate()
		player.global_position=Vector3(0,.1,-39)
		await settle()
		check(await walk_to(Vector3(0,4,-54)),"Main ramp")
		print("RAMP_RESULT ", player.global_position)
		player.global_position=Vector3(4,4.1,-64)
		await settle()
		check(await walk_to(Vector3(4,6,-57)),"Balcony ramp")
		print("BALCONY_RESULT ", player.global_position)
		await preload("res://tools/qa_support.gd").finish(get_tree(), 0 if failures.is_empty() else 1)
		return
	check(game.get_node("Zones").get_child_count()==4,"Four named zones")
	check(player.animator != null,"Imported AnimationPlayer")
	check(player.animation_names.size()>=10,"Expanded skeletal animation states")
	var skeleton:Skeleton3D=player.visual.find_child("Skeleton3D",true,false) as Skeleton3D
	check(skeleton!=null and skeleton.get_bone_count()==65,"65-bone humanoid Skeleton3D")
	check(game.hud.energy_bar is TextureProgressBar,"TextureProgressBar HUD")
	check(player.is_on_floor(),"Player rests on ground")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/title_menu.tscn" and ResourceLoader.exists("res://scenes/prologue_comic.tscn"),"Title menu is the game entry and leads to the comic prologue")
	check(InputMap.has_action("light_pulse"),"Light pulse input exists")
	var enemies:Array=get_tree().get_nodes_in_group("enemy")
	check(enemies.size()>=5,"Five echo enemies placed")
	var tutorial_echo:Node3D=game.get_node("Zones/Entrance/TutorialEcho")
	GameEvents.request_pulse(tutorial_echo.global_position,5.0,0.0)
	await settle(.45)
	check(not is_instance_valid(tutorial_echo) or tutorial_echo.get("purified"),"Tutorial echo can be purified by pulse")
	if "--qa-polish" in OS.get_cmdline_user_args():
		await polish_checks()
		await write_report()
		return
	await capture("01_entrada")
	check(await walk_to(Vector3(0,0,-1)),"Walk through entrance arch")
	check(await walk_to(Vector3(-2.0,0,-1)),"Reach Luma")
	await settle()
	check(is_instance_valid(player.target) and player.target.name=="Luma","Contextual Luma interaction")
	game.get_node("Zones/Entrance/Luma").interact(player)
	await settle(.25)
	await capture("02_historia")
	close_story()
	check(await walk_to(Vector3(5,0,-2)),"Walk to first fragment")
	await settle()
	check(GameEvents.collected==1,"Physics pickup updates HUD")
	check(not GameEvents.collect(&"fragment_0"),"Duplicate pickup rejected")
	check(await walk_to(Vector3(-7,0,-7)),"Reach second fragment")
	check(await walk_to(Vector3(0,0,-9)),"Reach bridge entrance")
	check(await walk_to(Vector3(0,0,-25)),"Cross first bridge")
	check(await walk_to(Vector3(0,0,-28)),"Reach puzzle garden")
	await capture("03_jardin")
	game.activate_rune(0)
	check(not GameEvents.puzzle_solved and game.rune_progress==0,"Wrong rune resets puzzle")
	for rune in [1,0,2]: game.activate_rune(rune)
	await settle()
	check(GameEvents.puzzle_solved,"Rune sequence solves puzzle")
	check(game.gate.get_node("CollisionShape3D").disabled,"Puzzle opens physical gate")
	check(await walk_to(Vector3(2,0,-28)),"Walk around central resonator")
	check(await walk_to(Vector3(2,0,-37)),"Pass central resonator")
	check(await walk_to(Vector3(0,0,-38)),"Reach puzzle reward")
	var chest:Node=game.get_node("Zones/Puzzle/RelicChest")
	chest.interact(player)
	await settle(.7)
	close_story()
	check(GameEvents.fragment_ids.has("fragment_3"),"Chest grants unique relic")
	check(chest.get_node("Visual/Chest_Lid").rotation.x < -1.,"Chest lid opens on hinge")
	game.get_node("Zones/Puzzle/LiftLever").interact(player)
	var lift:Node3D=game.get_node("Zones/Elevated/MovingPlatform")
	var y0:float=lift.position.y
	await settle(.7)
	check(lift.position.y!=y0,"AnimatableBody3D lift moves")
	check(game.get_node("Zones/Puzzle/LiftLever/Visual").find_child("LeverPivot",true,false).rotation.x>.6,"Lever handle animates")
	check(await walk_to(Vector3(0,4,-54)),"Climb ascent through unlocked gate")
	check(player.global_position.y>3.7,"Ramp reaches elevated floor")
	await capture("04_paso_cielo")
	check(await walk_to(Vector3(-4,4,-63)),"Reach elevated fragment")
	check(await walk_to(Vector3(-4,4,-68)),"Reach balcony approach")
	check(await walk_to(Vector3(4,4,-68)),"Align balcony ramp")
	check(await walk_to(Vector3(4,4,-64)),"Reach balcony approach")
	check(await walk_to(Vector3(4,6,-57)),"Climb balcony ramp")
	await settle()
	check(GameEvents.fragment_ids.has("fragment_5"),"Balcony fragment reachable")
	check(await walk_to(Vector3(4,4,-64)),"Descend balcony")
	check(await walk_to(Vector3(0,4,-68)),"Reach sky bridge")
	check(await walk_to(Vector3(0,4,-79)),"Cross final bridge")
	check(await walk_to(Vector3(-6,4,-84)),"Reach final fragment")
	await settle(.4)
	check(GameEvents.collected==7,"All seven fragments collected")
	check(game.hud.count_label.text=="7  /  7","HUD final count")
	check(await walk_to(Vector3(0,4,-87)),"Reach final portal")
	await capture("05_portal")
	game.get_node("Zones/PortalFinal/Portal").interact(player)
	check(not GameEvents.completed,"Final guardian protects the portal")
	var guardian:Node3D=game.get_node("Zones/PortalFinal/BeaconEcho")
	for i in 3: GameEvents.request_pulse(guardian.global_position + Vector3.UP * 0.85, 4.6, 0.0)
	await settle(.4)
	game.get_node("Zones/PortalFinal/Portal").interact(player)
	check(GameEvents.completed,"Chapter completion")
	await settle(.3)
	close_story()
	game.hud.toggle_pause()
	check(get_tree().paused,"Pause stops simulation")
	game.hud.toggle_pause()
	game.hud.open_journal()
	check(game.hud.journal.visible,"Journal opens")
	game.hud.close_journal()
	player.global_position=Vector3(0,-20,-80)
	await settle(.25)
	check(player.global_position.y>0,"Fall recovery to checkpoint")
	get_window().size=Vector2i(1024,768)
	await settle(.4)
	await capture("06_hud_1024")
	get_window().size=Vector2i(1440,900)
	player.global_position=Vector3(0,.2,7)
	player.velocity=Vector3.ZERO
	await settle(.5)
	await capture("07_inicio_final")
	await write_report()


func write_report() -> void:
	if "--qa-guardian" in OS.get_cmdline_user_args():
		check(guardian_suite_completed, "Guardian suite reached its final assertion")
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"images":images,
		"fps_at_end":Engine.get_frames_per_second(),"engine":Engine.get_version_info().string}
	var report_name: String = "avatar_report.json" if "--qa-avatar" in OS.get_cmdline_user_args() else ("combat_report.json" if "--qa-combat" in OS.get_cmdline_user_args() else ("polish_report.json" if "--qa-polish" in OS.get_cmdline_user_args() else "qa_report.json"))
	if "--qa-guardian" in OS.get_cmdline_user_args(): report_name = "guardian_report.json"
	if "--qa-cinematics" in OS.get_cmdline_user_args(): report_name = "cinematic_report.json"
	if "--qa-gamepad" in OS.get_cmdline_user_args(): report_name = "gamepad_report.json"
	if "--qa-memories" in OS.get_cmdline_user_args(): report_name = "memories_report.json"
	var file:=FileAccess.open(folder+report_name,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("ADVENTURE_QA ",JSON.stringify(report))
	await preload("res://tools/qa_support.gd").finish(get_tree(), 0 if failures.is_empty() else 1)


func avatar_bounds() -> AABB:
	var result := AABB()
	var first := true
	for node in player.visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.skin: continue
		var baked := mesh.bake_mesh_from_current_skeleton_pose()
		if not baked: continue
		var box: AABB = (player.global_transform.affine_inverse() * mesh.global_transform) * baked.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func avatar_checks() -> void:
	if "--qa-no-sun-shadow" in OS.get_cmdline_user_args():
		game.get_node("Sun").shadow_enabled = false
	if "--qa-no-ssao" in OS.get_cmdline_user_args():
		game.get_node("WorldEnvironment").environment.ssao_enabled = false
	if "--qa-no-shadows" in OS.get_cmdline_user_args():
		game.get_node("Sun").shadow_enabled = false
		game.get_node("WorldEnvironment").environment.ssao_enabled = false
	player.locked = true
	player.visual.rotation.y = 0.0
	player.arm.spring_length = 2.5
	player.arm.rotation.x = -0.07
	player.pivot.position.y = 1.05
	player.animation_tree.active = false
	player.set_physics_process(false)
	var skeleton: Skeleton3D = player.visual.find_child("Skeleton3D", true, false)
	check(skeleton.get_bone_count() == 65, "Imported humanoid retains finger and toe bones")
	var textured_surfaces := 0
	for node in player.visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.skin: continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material and material.albedo_texture and material.normal_texture and material.roughness_texture:
				textured_surfaces += 1
	check(textured_surfaces > 0, "Neri imports base color, normal and roughness textures")
	for clip in ["idle", "walk", "run", "jump", "fall", "land", "interact", "wave", "pulse", "hurt", "dodge"]:
		player.animator.play(player.animation_names[clip])
		await settle(0.22)
		check(player.animator.is_playing(), "Animation plays: " + clip)
		var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))
		await settle(0.1)
		check(hand != skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")), "Articulated motion: " + clip)
		var body := avatar_bounds()
		check(body.size.length() > 0.5 and body.size.length() < 3.5, "Skinned mesh bounds remain plausible: " + clip)
		if clip not in ["jump", "fall"]:
			check(body.position.y > -0.03, "Grounded animation stays above the floor: " + clip)
		if clip == "idle":
			check(body.position.y > -0.08 and body.position.y < 0.12, "Idle feet align with the gameplay floor")
			check(body.end.y > 1.6 and body.end.y < 1.9, "Idle body reaches the intended height")
		await capture("avatar_" + clip)
	player.visual.rotation.y = PI
	player.animator.play(player.animation_names["idle"])
	await settle(0.2)
	await capture("avatar_back")
	get_window().size = Vector2i(800, 640)
	game.hud.open_journal()
	await settle(0.2)
	var journal: Control = game.hud.journal
	var save_button: Button = journal.get_node("VBoxContainer/Actions/Save")
	var close_button: Button = journal.get_node("VBoxContainer/Actions/Close")
	check(journal.get_global_rect().end.y <= 640 and journal.position.y >= 0, "Journal fits minimum window")
	check(not save_button.get_global_rect().intersects(close_button.get_global_rect()), "Journal actions do not overlap")
	check(save_button.pressed.get_connections().size() == 1, "Manual save button is connected")
	for indicator in ["DestelloBank", "ShieldStatus", "Compass"]:
		check(game.hud.root.get_node(indicator).get_index() < game.hud.shade.get_index(), "HUD indicator stays behind modals: " + indicator)
	await capture("journal_800")


func test_wave(origin: Vector3) -> Node3D:
	var wave: Node3D = load("res://scripts/resonance_wave.gd").new()
	game.add_child(wave)
	wave.global_position = origin
	return wave


func test_wall(point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.3)
	collision.shape = shape
	body.add_child(collision)
	game.add_child(body)
	body.global_position = point
	return body


func guardian_checks() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	check(player.animation_names.has("dodge"), "Imported Roll animation available")
	check(InputMap.has_action("dodge"), "C dodge input configured")
	player.global_position = Vector3(0, 0.1, 7)
	player.velocity = Vector3.ZERO
	await settle(0.2)
	GameEvents.set_energy(100)
	GameEvents.damage_grace = 0
	check(player.try_dodge(Vector3.FORWARD), "Grounded dodge starts")
	check(is_equal_approx(GameEvents.energy, 88.0), "Dodge costs twelve energy")
	check(not player.try_dodge(Vector3.FORWARD), "Cooldown prevents repeated dodge")
	check(not GameEvents.damage_player(20, "QA dodge immunity"), "Early dodge protects from damage")
	await settle(0.19)
	check(player.current_animation == "dodge", "Dodge uses skeletal Roll state")
	await capture("phase5_01_roll")
	await settle(0.4)
	check(player.global_position.z < 5.1 and player.global_position.z > 3.3, "Dodge travels a bounded distance")
	check(GameEvents.damage_grace <= 0, "Dodge immunity expires")
	player.hurt_time = 0
	player.dodge_cooldown = 0
	GameEvents.set_energy(5)
	check(not player.try_dodge(Vector3.FORWARD), "Low energy blocks dodge")
	GameEvents.set_energy(100)
	player.locked = true
	check(not player.try_dodge(Vector3.FORWARD), "Dialogue lock blocks dodge")
	player.locked = false
	player.global_position = Vector3(0, 0.1, 7)
	player.velocity = Vector3.ZERO
	var wall := test_wall(Vector3(0, 1.5, 5.5))
	await settle(0.2)
	player.try_dodge(Vector3.FORWARD)
	await settle(0.6)
	check(player.global_position.z > 5.9, "Dodge cannot pass through a solid wall")
	wall.queue_free()
	await settle(0.1)
	player.global_position = Vector3(0, 0.1, 4)
	player.velocity = Vector3.ZERO
	player.dodge_cooldown = 0
	await settle(0.15)
	GameEvents.set_energy(100)
	GameEvents.damage_grace = 0
	var wave := test_wave(Vector3(0, 0, 1))
	await settle(0.55)
	check(GameEvents.energy < 80 and wave.hit_player, "Sweeping wave damages a grounded target")
	var after_hit: float = GameEvents.energy
	await settle(0.12)
	check(is_equal_approx(GameEvents.energy, after_hit), "One wave does not stack damage")
	wave.queue_free()
	player.hurt_time = 0
	GameEvents.set_energy(100)
	GameEvents.damage_grace = 0
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	wave = test_wave(Vector3(0, 0, 2))
	await settle(0.35)
	check(player.global_position.y > 0.55 and GameEvents.energy > 99, "Jump clears the wave at its crossing")
	check(not player.try_dodge(Vector3.FORWARD), "Dodge cannot start in midair")
	wave.queue_free()
	await settle(0.6)
	wall = test_wall(Vector3(0, 1.5, 2.5))
	await settle(0.1)
	GameEvents.set_energy(100)
	GameEvents.damage_grace = 0
	wave = test_wave(Vector3(0, 0, 1))
	await settle(0.65)
	check(GameEvents.energy > 99, "Solid cover blocks wave damage")
	wave.queue_free()
	wall.queue_free()
	await settle(0.1)
	player.hurt_time = 0
	player.dodge_cooldown = 0
	GameEvents.set_energy(100)
	GameEvents.damage_grace = 0
	wave = test_wave(Vector3(0, 0, 1))
	player.try_dodge(Vector3.FORWARD)
	await settle(0.4)
	check(wave.hit_player and is_equal_approx(GameEvents.energy, 88.0), "Timed roll passes through a wave without damage")
	wave.queue_free()
	player.locked = true
	await settle(0.1)
	check(player.dodge_time <= 0 and Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Dialogue immediately stops a running dodge")
	player.locked = false
	var guardian: Area3D = game.get_node("Zones/PortalFinal/BeaconEcho")
	guardian.home = Vector3(0, 0, 0)
	guardian.global_position = guardian.home
	guardian.damage_enabled = true
	guardian.set_physics_process(true)
	player.global_position = Vector3(0, 0.1, 4)
	await settle(0.2)
	check(guardian.windup_time > 0 and guardian.warning_ring.visible, "Guardian warns before ranged wave")
	check(game.hud.guardian_active, "Guardian integrity HUD appears nearby")
	await capture("phase5_02_guardian_charge")
	await settle(1.25)
	check(is_instance_valid(guardian.wave), "Guardian releases an expanding wave")
	await settle(0.25)
	await capture("phase5_03_wave")
	var initial_windup: float = guardian._windup_duration()
	guardian.apply_pulse(guardian.global_position + Vector3.UP * 0.8, 5.0, 0.0)
	check(guardian.health == 2 and not is_instance_valid(guardian.wave), "Pulse damages guardian and cancels its active wave")
	check(guardian._windup_duration() < initial_windup, "Guardian becomes faster after losing a core")
	get_window().size = Vector2i(800, 640)
	await settle(0.2)
	check(not game.hud.guardian_panel.get_global_rect().intersects(game.hud.objective_label.get_global_rect()), "Boss HUD avoids objective at minimum width")
	check(not game.hud.root.get_node("DodgeStatus/DodgeBar").get_global_rect().intersects(game.hud.prompt_panel.get_global_rect()), "Dodge meter avoids interaction prompt")
	await capture("phase5_04_boss_hud_800")
	game.hud.show_dialogue("LUMA", "Respira. El faro todavía escucha.")
	await settle(0.2)
	check(not game.hud.guardian_panel.visible and guardian.windup_time == 0, "Dialogue hides boss UI and cancels attack")
	close_story()
	guardian.apply_pulse(guardian.global_position + Vector3.UP * 0.8, 5.0, 0.0)
	guardian.apply_pulse(guardian.global_position + Vector3.UP * 0.8, 5.0, 0.0)
	await settle(0.5)
	check(GameEvents.purified_ids.has("BeaconEcho") and not game.hud.guardian_active, "Purified guardian persists and hides its HUD")
	GameEvents.completed = true
	GameEvents.puzzle_solved = true
	GameEvents.collected = 7
	GameEvents.fragments_changed.emit(7, 7)
	GameEvents.set_objective("Auralia vuelve a brillar")
	player.global_position = Vector3(0, 4.1, -82)
	player.velocity = Vector3.ZERO
	get_window().size = Vector2i(1440, 900)
	await settle(3.2)
	var beacon: Node3D = game.get_node("BeaconRestoration")
	check(beacon.restored and beacon.visible and beacon.light.light_energy > 2.9, "Chapter completion restores visible beacon")
	check(float(beacon.material.get_shader_parameter("strength")) > 0.99, "Beacon reveal reaches full strength")
	var restored: Node3D = load("res://scripts/beacon_restoration.gd").new()
	game.add_child(restored)
	check(restored.restored and restored.visible, "Completed save restores beacon immediately")
	restored.queue_free()
	await settle(0.1)
	await capture("phase5_05_restored_beacon")
	check(game.get_node("AudioManager/CombatTension").playing, "Adaptive tension layer is playing")
	guardian_suite_completed = true


func combat_checks() -> void:
	var enemy: Area3D = game.get_node("Zones/Entrance/TutorialEcho")
	for other in get_tree().get_nodes_in_group("enemy"):
		other.set_physics_process(false)
	enemy.set_physics_process(true)
	enemy.damage_enabled = true
	enemy.health = 3
	enemy.home = Vector3(0, 0, 4)
	enemy.global_position = enemy.home
	player.global_position = Vector3(0, 0.1, 5.1)
	player.velocity = Vector3.ZERO
	GameEvents.set_energy(100.0)
	GameEvents.damage_grace = 0.0
	await settle(0.25)
	check(enemy.windup_time > 0.0 and enemy.warning_ring.visible, "Enemy telegraphs before damage")
	check(GameEvents.energy > 99.0, "Windup gives player time to react")
	await capture("combat_01_warning")
	player.global_position = Vector3(0, 0.1, 7)
	await settle(1.2)
	check(GameEvents.energy > 99.0, "Leaving attack radius avoids damage")
	enemy.attack_time = 0.0
	player.global_position = enemy.global_position + Vector3(0, 0.1, 1.0)
	await settle(0.2)
	Input.action_press("light_pulse")
	await get_tree().physics_frame
	Input.action_release("light_pulse")
	await settle(0.12)
	check(enemy.stun_time > 0.0 and enemy.windup_time == 0.0, "Q cancels a pending attack")
	check(GameEvents.energy < 90.0, "Pulse spends energy")
	check(game.get_node("CombatFeedback").get_child_count() > 0, "Pulse creates visible world effect")
	await capture("combat_02_pulse")
	var stopped_at: Vector3 = enemy.global_position
	await settle(0.5)
	check(enemy.global_position.distance_to(stopped_at) < 0.01, "Stunned enemy does not patrol")
	enemy.stun_time = 0.0
	enemy.attack_time = 0.0
	player.global_position = enemy.global_position + Vector3(0, 0.1, 1.0)
	GameEvents.set_energy(100.0)
	await settle(1.4)
	check(GameEvents.energy < 99.0 and player.regeneration_delay > 0.0, "Completed attack damages and delays regeneration")
	var after_hit: float = GameEvents.energy
	check(not GameEvents.damage_player(30.0, "QA second hit") and is_equal_approx(GameEvents.energy, after_hit), "Shared immunity prevents stacked damage")
	game.hud.show_dialogue("LUMA", "El faro recuerda.")
	GameEvents.set_energy(100.0)
	await settle(2.0)
	check(GameEvents.energy == 100.0 and enemy.windup_time == 0.0, "Dialogue prevents enemy attacks")
	game.hud.close_dialogue()
	game.hud.close_dialogue()
	check(not game.hud.dialog_open and not player.locked, "Reveal then continue closes dialogue")
	enemy.set_physics_process(false)
	GameEvents.damage_grace = 0.0
	GameEvents.set_energy(5.0)
	GameEvents.damage_player(30.0, "QA depletion")
	check(player.global_position.distance_to(GameEvents.checkpoint) < 0.1, "Depletion returns player to checkpoint")
	check(GameEvents.energy >= 60.0 and GameEvents.damage_grace >= 2.0, "Respawn restores energy and protection")
	player.global_position = enemy.global_position + Vector3.UP * 4.0
	check(not enemy.has_sight(), "Enemy cannot attack a different floor")
	player.global_position = Vector3(0, 0.1, 7)
	enemy.health = 1
	GameEvents.request_pulse(enemy.global_position + Vector3.UP * 0.85, 4.6, 0.0)
	await settle(0.4)
	check(GameEvents.purified_ids.has("TutorialEcho"), "Purification records unique enemy ID")
	var total: int = GameEvents.enemies_purified
	check(not GameEvents.register_enemy_purified(&"TutorialEcho") and total == GameEvents.enemies_purified, "Enemy reward cannot duplicate")
	var reloaded := Area3D.new()
	reloaded.name = "TutorialEcho"
	reloaded.set_script(load("res://scripts/enemy_sentinel.gd"))
	game.get_node("Zones/Entrance").add_child(reloaded)
	await settle(0.1)
	check(not is_instance_valid(reloaded), "Persisted purified enemy stays absent on reload")
	GameEvents.set_tutorial(4, "Cuando aparezca el anillo dorado, aléjate o interrumpe el ataque con Q.")
	GameEvents.set_threat(1)
	game.hud.show_toast("El eco alcanzó tu luz")
	get_window().size = Vector2i(800, 640)
	await settle(0.1)
	check(not game.hud.threat_panel.get_global_rect().intersects(game.hud.toast_label.get_global_rect()), "Threat and toast do not overlap")
	check(not game.hud.tutorial_panel.get_global_rect().intersects(game.hud.prompt_panel.get_global_rect()), "Tutorial and interaction fit narrow viewport")
	await capture("combat_03_hud_800")


func polish_checks() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Visual polish checks require a graphics display")
		return
	check(game.get_node("EnvironmentLife").wind_surfaces>20,"Imported foliage receives wind materials")
	var meadow:MultiMeshInstance3D=game.get_node("Zones/Entrance/Meadow")
	check(meadow.multimesh.get_instance_transform(0).origin.distance_to(meadow.multimesh.get_instance_transform(1).origin)>5.,"Meadow instances distributed on terrain")
	await capture("polish_01_entrance")
	var earlier:Image=get_viewport().get_texture().get_image()
	await settle(.7)
	await RenderingServer.frame_post_draw
	var later:Image=get_viewport().get_texture().get_image()
	var changed:int=0
	var contrast:float=0.
	for y in range(200,850,6):
		for x in range(20,1400,6):
			var first:Color=earlier.get_pixel(x,y)
			var second:Color=later.get_pixel(x,y)
			if Vector3(first.r,first.g,first.b).distance_to(Vector3(second.r,second.g,second.b))>.035:changed+=1
			contrast=maxf(contrast,maxf(first.r,first.g)-minf(first.r,first.g))
	check(changed>50,"Visible scene pixels animate")
	check(contrast>.12,"Scene contains nonblank colored geometry")
	player.visual.rotation.y=0.
	player.arm.spring_length=2.5
	player.arm.rotation.x=-.07
	player.pivot.position.y=1.05
	await settle(.3)
	await capture("polish_02_character")
	var skeleton:Skeleton3D=player.visual.find_child("Skeleton3D",true,false)
	var head: int=skeleton.find_bone("Head")
	var initial: Transform3D=skeleton.get_bone_pose(head)
	await settle(.5)
	check(initial!=skeleton.get_bone_pose(head),"Idle skeleton moves")
	var before: Vector3=game.get_node("Zones/Puzzle/Resonator_0/ResonanceCrystal").position
	await settle(.4)
	check(before!=game.get_node("Zones/Puzzle/Resonator_0/ResonanceCrystal").position,"Crystal levitation animates")
	var luma_float: Node3D = game.get_node("Zones/Entrance/Luma/Visual").find_child("Luma_Float", true, false)
	var luma_before: Vector3 = luma_float.position if luma_float else Vector3.ZERO
	await settle(.3)
	check(luma_float != null and luma_float.position != luma_before, "Luma spirit animates procedurally")
	check(game.get_node("AudioManager").themes.size()==3,"Three adaptive music loops")
	for theme in game.get_node("AudioManager").themes:
		var looping: bool = (theme.stream is AudioStreamOggVorbis and theme.stream.loop) or (theme.stream is AudioStreamWAV and theme.stream.loop_end==int(theme.stream.get_length()*theme.stream.mix_rate))
		check(theme.playing and looping,"Music loop plays: "+str(theme.name))
	check(game.find_children("WaterfallAudio*","AudioStreamPlayer3D",true,false).size()==3,"Three spatial waterfalls")
	Preferences.set_volume("Music",0.)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"Music can be muted independently")
	Preferences.set_volume("Music",.7)
	Preferences.set_quality(0)
	check(not game.get_node("Sun").shadow_enabled,"Light graphics profile applies")
	Preferences.set_quality(1)
	check(game.get_node("Sun").shadow_enabled,"Balanced graphics restores shadows")
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await settle(.2)
	check(player.position.y>.3,"Jump rises off ground")
	await capture("polish_03_jump")
	await settle(1.)
	check(player.is_on_floor(),"Jump lands on terrain")
	game.hud.toggle_pause()
	await capture("polish_04_settings")
	get_window().size=Vector2i(800,640)
	await settle(.3)
	await capture("polish_05_settings_800")
	check(game.hud.pause_panel.get_global_rect().end.y<=640,"Settings fit minimum window")
	game.hud.toggle_pause()
	get_window().size=Vector2i(1440,900)
	player.arm.spring_length=4.4
	player.pivot.position.y=1.4
	player.arm.rotation.x=-.227
	player.global_position=Vector3(0,4.2,-84)
	player.visual.rotation.y=PI
	for i in range(7):GameEvents.collect(StringName("fragment_%d"%i))
	GameEvents.puzzle_solved=true
	await settle(.5)
	await capture("polish_06_portal")



# --- Fase 6: cinemáticas, voces y final ---------------------------------------------------------

func wait_director(director: Node, limit: float) -> float:
	var elapsed: float = 0.0
	while director.is_playing() and elapsed < limit:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return elapsed


func cinematic_checks() -> void:
	var director: Node = game.get_node("CinematicDirector")
	var audio: Node = game.get_node("AudioManager")
	check(director != null and director.enabled, "Cinematic director active in cinematic QA")
	check(AudioServer.get_bus_index("Voice") >= 0, "Dedicated voice bus")
	check(audio.play_voice("vo_luma_intro") > 3.0, "Luma dialogue is voiced")
	audio.stop_voice(0.05)
	check(ResourceLoader.exists(audio.music_path("finale")) and audio.music_path("finale").ends_with(".ogg"), "Orchestral finale track present")
	# Llegada: franjas, HUD oculto, cámara propia y retorno limpio al jugador.
	director.play("arrival")
	await settle(3.2)
	check(director.is_playing() and director.camera.current, "Arrival uses the cinematic camera")
	check(not game.hud.root.visible and player.locked and GameEvents.cinematic_active, "Arrival hides HUD and locks the player")
	check(director.bars_amount > 0.9, "Letterbox bars shown")
	await capture("cine_01_arrival")
	await settle(6.0)
	await capture("cine_02_beacon")
	await settle(5.5)
	await capture("cine_03_neri")
	await wait_director(director, 20.0)
	check(not director.is_playing() and player.camera.current and game.hud.root.visible and not player.locked, "Arrival returns control to the player")
	check(GameEvents.story_seen.has("cine_arrival") and not director.should_play("arrival"), "Arrival plays only once")
	# Salto manteniendo la tecla.
	GameEvents.story_seen.erase("cine_arrival")
	director.play("arrival")
	await settle(1.0)
	var skip_started: int = Time.get_ticks_msec()
	director.skip()
	await wait_director(director, 5.0)
	check(not director.is_playing() and Time.get_ticks_msec() - skip_started < 3500, "Cinematic can be skipped")
	check(game.hud.root.visible and not player.locked and not GameEvents.cinematic_active, "Skipping restores gameplay state")
	await settle(0.6)
	# Jardín: la puerta se disuelve dentro de la cinemática.
	player.global_position = Vector3(3.5, 0.1, -31.5)
	await settle(0.4)
	for rune in [1, 0, 2]: game.activate_rune(rune)
	await settle(0.3)
	check(GameEvents.puzzle_solved and game.gate.get_node("CollisionShape3D").disabled, "Solved garden opens the gate physically at once")
	check(director.is_playing() and director.current == "garden", "Garden awakening cinematic plays")
	await settle(3.9)
	check(game.gate.visible, "Gate stays visible while dissolving")
	await capture("cine_04_garden_gate")
	await wait_director(director, 15.0)
	await settle(0.3)
	check(not game.gate.visible and not game.gate_dissolving, "Gate hidden after the cinematic")
	# Guardián: entrar en la zona del faro dispara la presentación una sola vez.
	player.global_position = Vector3(0, 4.15, -78.5)
	await settle(0.6)
	check(director.is_playing() and director.current == "guardian", "Guardian introduction plays on entering the beacon zone")
	await settle(4.2)
	await capture("cine_05_guardian")
	await wait_director(director, 15.0)
	var guardian: Node3D = game.get_node("Zones/PortalFinal/BeaconEcho")
	check(guardian.windup_time == 0.0 and guardian.attack_time > 0.5, "Guardian waits after its introduction")
	player.global_position = Vector3(0, 4.15, -70)
	await settle(0.3)
	player.global_position = Vector3(0, 4.15, -78.5)
	await settle(0.5)
	check(not director.is_playing(), "Guardian introduction does not repeat")
	# Final completo: fragmentos, faro, islas, créditos y regreso al mundo.
	for i in 7: GameEvents.collect(StringName("fragment_%d" % i))
	for i in 3: GameEvents.request_pulse(guardian.global_position + Vector3.UP * 0.85, 4.6, 0.0)
	await settle(0.6)
	player.global_position = Vector3(0, 4.15, -87)
	await settle(0.3)
	game.get_node("Zones/PortalFinal/Portal").interact(player)
	await settle(0.4)
	check(GameEvents.completed and director.current == "finale", "Portal launches the finale cinematic")
	var beacon: Node3D = game.get_node("BeaconRestoration")
	check(not beacon.restored, "Beacon waits for its cinematic cue")
	await settle(2.4)
	await capture("cine_06_fragments")
	await settle(3.4)
	check(beacon.restored, "Finale ignites the beacon")
	await capture("cine_07_ignition")
	await settle(6.5)
	await capture("cine_08_islands")
	check(beacon.island_lights.size() >= 10, "Distant islands light up")
	await settle(6.5)
	await capture("cine_09_wide")
	await settle(4.0)
	await capture("cine_10_companions")
	var waited: float = await wait_director(director, 30.0)
	check(waited < 30.0, "Finale reaches its end")
	await settle(3.0)
	await capture("cine_11_credits")
	var limit: float = 0.0
	while GameEvents.cinematic_active and limit < 60.0:
		await get_tree().process_frame
		limit += get_process_delta_time()
	await settle(1.6)
	# Fase 7: tras los créditos Luma presenta el archipiélago (Capítulo II) antes de devolver el control.
	limit = 0.0
	while not game.hud.dialog_open and limit < 8.0:
		await get_tree().process_frame
		limit += get_process_delta_time()
	check(game.hud.dialog_open and GameEvents.story_seen.has("ch2_call"), "Luma calls Neri to the archipelago after the credits")
	game.hud.close_dialogue()
	game.hud.close_dialogue()
	await settle(0.6)
	check(not GameEvents.cinematic_active and game.hud.root.visible and not player.locked and player.camera.current, "Credits return to free exploration")
	check(GameEvents.objective == "Cruza el portal del faro hacia el archipiélago" and GameEvents.story_seen.has("ending"), "Ending recorded")
	await capture("cine_12_after")
	var luma: Node3D = game.get_node("Zones/Entrance/Luma/Visual")
	check(luma.find_child("Luma_Visor", true, false) != null, "Luma uses the spirit model")



func pad_axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


func pad_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func gamepad_checks() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	for action in ["move_forward", "jump", "interact", "light_pulse", "dodge", "pause", "journal", "camera_left", "camera_up"]:
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: has_pad = true
		check(has_pad, "Gamepad binding: " + action)
	player.global_position = Vector3(0, 0.1, 7)
	await settle(0.3)
	var start := player.global_position
	pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await settle(0.6)
	pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await settle(0.2)
	check(player.global_position.z < start.z - 0.8, "Left stick moves Neri")
	var yaw: float = player.pivot.rotation.y
	pad_axis(JOY_AXIS_RIGHT_X, 1.0)
	await settle(0.4)
	pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	check(absf(player.pivot.rotation.y - yaw) > 0.3, "Right stick turns the camera")
	check(game.hud.using_pad and game.hud.pulse_label.text.begins_with("Y"), "HUD switches to gamepad button hints")
	GameEvents.set_energy(100)
	pad_button(JOY_BUTTON_B, true)
	await get_tree().physics_frame
	pad_button(JOY_BUTTON_B, false)
	await settle(0.1)
	check(player.dodge_cooldown > 0.0, "B button dodges")
	await settle(1.5)
	pad_button(JOY_BUTTON_Y, true)
	await get_tree().physics_frame
	pad_button(JOY_BUTTON_Y, false)
	await settle(0.1)
	check(player.pulse_cooldown > 0.0, "Y button emits the light pulse")
	pad_button(JOY_BUTTON_START, true)
	await get_tree().process_frame
	pad_button(JOY_BUTTON_START, false)
	await settle(0.2)
	check(game.hud.paused and get_viewport().gui_get_focus_owner() != null, "Start pauses with a focused menu button")
	pad_button(JOY_BUTTON_A, true)
	await get_tree().process_frame
	pad_button(JOY_BUTTON_A, false)
	await settle(0.2)
	check(not game.hud.paused, "A activates the focused Continue button")
	# X cierra un diálogo sin volver a abrirlo en el mismo cuadro.
	var luma: Node3D = game.get_node("Zones/Entrance/Luma")
	player.global_position = luma.global_position + Vector3(0, 0.15, 1.5)
	await settle(0.35)
	luma.interact(player)
	await settle(0.1)
	var requests: Array[int] = [0]
	var counter := func(_speaker: String, _text: String) -> void: requests[0] += 1
	GameEvents.story_requested.connect(counter)
	game.hud.revealed = 10000
	game.hud.dialogue_text.visible_characters = -1
	pad_button(JOY_BUTTON_X, true)
	await get_tree().physics_frame
	pad_button(JOY_BUTTON_X, false)
	await settle(0.4)
	GameEvents.story_requested.disconnect(counter)
	check(not game.hud.dialog_open and requests[0] == 0, "X closes a dialogue without reopening it")
	var height: float = player.global_position.y
	game.hud.show_dialogue("LUMA", "Prueba")
	game.hud.revealed = 10000
	game.hud.dialogue_text.visible_characters = -1
	pad_button(JOY_BUTTON_A, true)
	await get_tree().physics_frame
	pad_button(JOY_BUTTON_A, false)
	await settle(0.25)
	check(not game.hud.dialog_open and player.global_position.y < height + 0.2, "A closes a dialogue without jumping")
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_W
	key_event.pressed = true
	Input.parse_input_event(key_event)
	key_event = key_event.duplicate()
	key_event.pressed = false
	Input.parse_input_event(key_event)
	await settle(0.1)
	check(not game.hud.using_pad and game.hud.pulse_label.text.begins_with("Q"), "Keyboard input restores keyboard hints")



func memory_checks() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	var memories: Array = []
	for item in get_tree().get_nodes_in_group("interactable"):
		if str(item.get("item_id")).begins_with("lore_"): memories.append(item)
	check(memories.size() == GameEvents.LORE_TOTAL, "Five Memories of Auralia placed")
	var count_before: int = GameEvents.lore_count()
	for memory in memories:
		var spot: Vector3 = memory.global_position + Vector3(0, 0.15, 1.6)
		player.global_position = spot
		player.velocity = Vector3.ZERO
		await settle(0.35)
		check(player.is_on_floor() or player.global_position.y > memory.global_position.y - 0.5, "Ground under memory " + str(memory.item_id))
		check(player.target == memory, "Memory reachable and promptable: " + str(memory.item_id))
		check(ResourceLoader.exists("res://assets/audio/voice/vo_%s.ogg" % memory.item_id), "Memory is voiced: " + str(memory.item_id))
		memory.interact(player)
		await settle(0.2)
		check(game.hud.dialog_open and game.hud.speaker_label.text == "MEMORIA DE AURALIA", "Memory tells its story: " + str(memory.item_id))
		if memory == memories[0]: await capture("memory_01_dialogue")
		close_story()
		await settle(0.1)
	check(GameEvents.lore_count() == count_before + memories.size(), "Each memory is recorded once")
	memories[0].interact(player)
	await settle(0.1)
	close_story()
	check(GameEvents.lore_count() == GameEvents.LORE_TOTAL, "Repeating a memory does not inflate the count")
	game.hud.open_journal()
	var entries: String = game.hud.get_node("HUD/Journal/VBoxContainer/Entries").text
	check("MEMORIAS DE AURALIA · 5 / 5" in entries and "La señal imposible" in entries, "Journal lists recovered memories")
	game.hud.close_journal()
	player.global_position = memories[1].global_position + Vector3(1.8, 0.15, 2.4)
	player.visual.rotation.y = PI * 0.8
	await settle(0.5)
	await capture("memory_02_orb")
	GameEvents.damage_grace = 0.0
	GameEvents.set_energy(100)
	Preferences.difficulty = 0
	GameEvents.damage_player(20.0, "QA relato")
	check(is_equal_approx(GameEvents.energy, 90.0), "Story difficulty halves damage")
	GameEvents.damage_grace = 0.0
	Preferences.difficulty = 1
	GameEvents.damage_player(20.0, "QA aventura")
	check(is_equal_approx(GameEvents.energy, 70.0), "Adventure difficulty keeps original damage")
