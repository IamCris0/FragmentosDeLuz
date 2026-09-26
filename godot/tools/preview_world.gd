extends SceneTree
## Captura el mundo desde una cámara libre para revisar diseño (sin jugabilidad).
## Uso: godot --path godot --script res://tools/preview_world.gd -- salida.png x y z mirar_x mirar_y mirar_z [fov] [completado]

var frames: int = 0
var output: String


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0]
	var eye := Vector3(float(args[1]), float(args[2]), float(args[3]))
	var target := Vector3(float(args[4]), float(args[5]), float(args[6]))
	var fov: float = float(args[7]) if args.size() > 7 else 50.0
	if args.size() > 8 and args[8] == "1":
		root.get_node("GameEvents").completed = true
	var world: Node3D = (load("res://scenes/main_island.tscn") as PackedScene).instantiate()
	world.set_script(null)
	for title in ["HUDLayer", "AudioManager"]:
		var node := world.get_node_or_null(title)
		if node:
			world.remove_child(node)
			node.free()
	world.get_node("Player").set_script(null)
	root.add_child(world)
	if root.get_node("GameEvents").completed:
		var beacon := Node3D.new()
		beacon.set_script(load("res://scripts/beacon_restoration.gd"))
		world.add_child(beacon)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.far = 400
	world.add_child(camera)
	camera.look_at_from_position(eye, target)
	camera.current = true


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(output)
		print("PREVIEW_SAVED ", output)
		quit()
	return false
