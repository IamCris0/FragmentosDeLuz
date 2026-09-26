extends SceneTree
## Renderiza un modelo aislado para revisión artística.
## Uso: godot --path godot --script res://tools/preview_model.gd -- <res://modelo.glb> <salida.png> [yaw_grados] [distancia] [altura_objetivo]

var frames: int = 0
var output: String
var model: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://assets/characters/luma_spirit.glb"
	output = args[1] if args.size() > 1 else "/tmp/preview.png"
	var yaw: float = deg_to_rad(float(args[2])) if args.size() > 2 else 0.0
	var distance: float = float(args[3]) if args.size() > 3 else 2.6
	var target_y: float = float(args[4]) if args.size() > 4 else 1.2
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2c3e4f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9fb8cc")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 1.1
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color("8fb8e8")
	fill.light_energy = 0.45
	world.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("59646a")
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	model = (load(path) as PackedScene).instantiate()
	world.add_child(model)
	if args.size() > 5 and args[5] != "":
		model.set_script(load(args[5]))
		model._ready()
	var camera := Camera3D.new()
	camera.fov = 35
	world.add_child(camera)
	camera.look_at_from_position(Vector3(sin(yaw) * distance, target_y + 0.25, cos(yaw) * distance), Vector3(0, target_y, 0))
	camera.current = true


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(output)
		print("PREVIEW_SAVED ", output)
		quit()
	return false
