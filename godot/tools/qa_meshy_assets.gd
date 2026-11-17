extends SceneTree
## Integration regressions and rendered previews for the November art pass.
const Style = preload("res://scripts/meshy_style.gd")
const Support = preload("res://tools/qa_support.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var world: Node3D
var camera: Camera3D
var folder: String

class TestPlayer extends CharacterBody3D:
	var locked := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: checks.append(label)
	else:
		failures.append(label)
		push_error("QA_FAILED: " + label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(not picture.is_empty(), "Rendered " + label)
	picture.save_png(folder + label + ".png")

func asset(path: String) -> Node3D:
	var model := (load("res://assets/" + path + ".glb") as PackedScene).instantiate() as Node3D
	world.add_child(model)
	Style.apply(model)
	return model

func enemy(script: String, model: String) -> Node3D:
	var actor = load("res://scripts/" + script + ".gd").new()
	var visual := (load("res://assets/enemies/" + model + ".glb") as PackedScene).instantiate()
	visual.name = "Visual"
	actor.add_child(visual)
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func frame_model(model: Node3D, distance: float, height: float) -> void:
	for node in world.get_children():
		if node is Node3D and node != camera and not node is Light3D: node.visible = node == model
	model.position = Vector3.ZERO
	camera.position = Vector3(distance * 0.32, height + distance * 0.24, distance)
	camera.look_at(Vector3(0, height, 0))

func run() -> void:
	folder = Support.output_folder("meshy")
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142633")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8e3")
	environment.environment.ambient_light_energy = 0.65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.8
	world.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 42
	world.add_child(camera)
	camera.current = true
	var player := TestPlayer.new()
	player.add_to_group("player")
	world.add_child(player)
	player.position = Vector3(0, 0, 8)

	var echo = enemy("enemy_sentinel", "echo_sentinel")
	var echo_b = enemy("enemy_sentinel", "echo_sentinel")
	var first: ShaderMaterial = echo.style_materials[0]
	var second: ShaderMaterial = echo_b.style_materials[0]
	check(first != second, "Enemies own independent glow materials")
	first.set_shader_parameter("glow_boost", 2.6)
	Style.apply(world)
	var body := echo.visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check(body.get_active_material(0) == first, "Environment styling preserves the live enemy material")
	check(float(second.get_shader_parameter("glow_boost")) == 1.0, "Charging one enemy does not brighten its neighbor")
	check(Style.apply(echo.visual, true)[0] == first, "Repeated styling keeps enemy material references valid")
	first.set_shader_parameter("glow_boost", 1.0)
	await capture_enemy(echo, "echo", 4.5, 0.9)
	var vigia = enemy("enemy_vigia", "vigia")
	check(vigia.ring_a != null and vigia.ring_b != null, "Vigia retains both animated rings")
	await capture_enemy(vigia, "vigia", 5.0, 1.3)
	var boss = enemy("boss_heraldo", "heraldo")
	check(boss.corona != null and boss.shards.size() == 6, "Heraldo retains corona and six orbiting shards")
	boss.windup = 0.5
	boss._animate(0.1)
	check(float(boss.style_materials[0].get_shader_parameter("glow_boost")) == 2.6, "Heraldo texture signals attack charge")
	boss.shield.hide()
	boss.windup = 0.0
	boss._animate(0.1)
	await capture_enemy(boss, "heraldo", 9.0, 0.3)

	var cefiro = enemy("enemy_cefiro", "cefiro")
	var skeleton := cefiro.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	var mesh := cefiro.visual.find_child("CefiroBody", true, false) as MeshInstance3D
	check(skeleton != null and skeleton.get_bone_count() == 3, "Cefiro has a three-bone wing rig")
	check(mesh != null and mesh.skin != null and mesh.skin.get_bind_count() == 3, "Continuous Cefiro body is skinned")
	check(cefiro.wings.is_empty(), "Wing animation no longer uses detached mesh pieces")
	check(cefiro.wing_clips.size() == 3, "Flight, charge and recovery clips are imported")
	if skeleton and mesh and cefiro.wing_animator:
		var animator: AnimationPlayer = cefiro.wing_animator
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		frame_model(cefiro, 6.0, 0.95)
		cefiro.visual.rotation.y = 0
		for action in ["CefiroFlight", "CefiroCharge", "CefiroRest"]:
			var clip: StringName = cefiro.wing_clips.get(action, &"")
			if clip.is_empty(): continue
			animator.play(clip)
			animator.advance(0)
			var animation := animator.get_animation(clip)
			check(animation.loop_mode == Animation.LOOP_LINEAR, action + " loops")
			var poses: Array[Vector3] = []
			for fraction in [0.0, 0.25, 0.75, 1.0]:
				animator.seek(animation.length * fraction, true)
				await process_frame
				await process_frame
				var baked := mesh.bake_mesh_from_current_skeleton_pose()
				var box: AABB = (cefiro.global_transform.affine_inverse() * mesh.global_transform) * baked.get_aabb()
				# Three-meter wingspan and tail: the diagonal legitimately exceeds four meters.
				check(box.position.is_finite() and box.size.x > 2.5 and box.size.x < 3.1
					and box.size.z > 2.5 and box.size.z < 3.1 and box.size.y > 0.2 and box.size.y < 1.0
					and box.position.y > 0.2,
					action + " bounded deformation at " + str(fraction))
				poses.append(box.size)
				if fraction in [0.25, 0.75]: await capture(action + "_" + str(fraction))
			check(not poses[0].is_equal_approx(poses[1]), action + " deforms the actual mesh")
			check(poses[0].distance_to(poses[3]) < 0.001, action + " closes without a pose jump")
		cefiro.mode = cefiro.Mode.WINDUP
		cefiro._animate_wings(false)
		check(animator.current_animation == cefiro.wing_clips.CefiroCharge, "Windup selects the charge cycle")
		cefiro.mode = cefiro.Mode.RECOVERY
		cefiro._animate_wings(true)
		check(animator.current_animation == cefiro.wing_clips.CefiroRest, "Recovery selects the resting cycle")
		player.locked = true
		cefiro._physics_process(0.1)
		check(animator.speed_scale == 0, "Dialogue freezes Cefiro wing motion")
		player.locked = false
		cefiro.mode = cefiro.Mode.PATROL
		cefiro._animate_wings(false)
		check(animator.speed_scale == 1 and animator.current_animation == cefiro.wing_clips.CefiroFlight,
			"Flight resumes after dialogue")

	for name_value in ["tree", "column", "entrance_arch", "boulder"]:
		var model := asset("environment/" + name_value)
		var materials := Style.apply(model)
		check(not materials.is_empty(), name_value + " receives the textured shader")
		for material in materials:
			var texture := material.get_shader_parameter("albedo_tex") as Texture2D
			check(texture != null and texture.get_width() >= 1024, name_value + " keeps its full color texture")
			check((float(material.get_shader_parameter("sway")) > 0) == (name_value == "tree"), name_value + " correct wind classification")
		frame_model(model, 14 if name_value == "entrance_arch" else 9 if name_value == "tree" else 6, 2.4 if name_value == "entrance_arch" else 1.5)
		await capture(name_value)
	await material_collision_check()
	world.queue_free()
	await process_frame
	await process_frame
	Style.cache.clear()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var file := FileAccess.open(folder + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MESHY_QA ", JSON.stringify(report))
	await Support.finish(self, 0 if failures.is_empty() else 1)

func capture_enemy(actor: Node3D, label: String, distance: float, height: float) -> void:
	frame_model(actor, distance, height)
	actor.get_node("Visual").rotation.y = 0
	await capture(label)

func material_collision_check() -> void:
	var materials: Array[ShaderMaterial] = []
	for color in [Color.RED, Color.BLUE]:
		var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
		image.fill(color)
		var source := StandardMaterial3D.new()
		source.resource_name = "Meshy_same_name"
		source.albedo_texture = ImageTexture.create_from_image(image)
		var piece := MeshInstance3D.new()
		piece.mesh = BoxMesh.new()
		piece.mesh.material = source
		world.add_child(piece)
		materials.append(Style.apply(piece)[0])
	check(materials[0] != materials[1], "Equal material names do not collide in the environment cache")
	check(materials[0].get_shader_parameter("albedo_tex") != materials[1].get_shader_parameter("albedo_tex"), "Each cached material preserves its own texture")
