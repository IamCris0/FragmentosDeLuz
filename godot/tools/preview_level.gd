extends SceneTree
## Fase 7: captura una isla del archipiélago (o la carta) desde varias cámaras libres para revisar el diseño.
## Uso: godot --path godot --script res://tools/preview_level.gd -- <escena.tscn> <prefijo_salida> <paleta> "x,y,z,mx,my,mz[,fov]" ...
## La isla conserva su aspecto (cristales, cielo, rayos) pero sin HUD, audio ni lógica de juego.

var frames: int = 0
var shots: Array = []
var prefix: String
var camera: Camera3D
var index: int = 0
var world: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	prefix = args[1]
	var palette: String = args[2]
	for i in range(3, args.size()):
		var parts: PackedStringArray = args[i].split(",")
		shots.append([Vector3(float(parts[0]), float(parts[1]), float(parts[2])), Vector3(float(parts[3]), float(parts[4]), float(parts[5])), float(parts[6]) if parts.size() > 6 else 50.0])
	world = (load(path) as PackedScene).instantiate()
	world.set_script(null)
	for title in ["HUDLayer", "AudioManager"]:
		var node := world.get_node_or_null(title)
		if node:
			world.remove_child(node)
			node.free()
	var player := world.get_node_or_null("Player")
	if player:
		player.set_script(null)
		var own := player.find_child("Camera3D", true, false) as Camera3D
		if own: own.current = false
	root.add_child(world)
	load("res://scripts/crystal_style.gd").apply(world, palette)
	camera = Camera3D.new()
	camera.far = 500
	world.add_child(camera)
	camera.current = true
	_place()


func _place() -> void:
	var shot: Array = shots[index]
	camera.fov = shot[2]
	camera.look_at_from_position(shot[0], shot[1])


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 40:
		_capture.call_deferred()
	return false


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var output := "%s_%d.png" % [prefix, index]
	root.get_viewport().get_texture().get_image().save_png(output)
	print("PREVIEW_SAVED ", output)
	index += 1
	frames = 26
	if index >= shots.size():
		quit()
	else:
		_place()
