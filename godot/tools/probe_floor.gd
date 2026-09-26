extends SceneTree
## Sonda de depuración: lanza rayos verticales y horizontales para ver qué colisiona en un tramo.
## Uso: godot --headless --path godot --script res://tools/probe_floor.gd -- <escena> x y z0 z1 pasos

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node = (load(args[0]) as PackedScene).instantiate()
	scene.set_script(null)
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var x := float(args[1])
	var y := float(args[2])
	var z0 := float(args[3])
	var z1 := float(args[4])
	var steps := int(args[5])
	var space := (scene as Node3D).get_world_3d().direct_space_state
	for i in steps + 1:
		var z := lerpf(z0, z1, float(i) / steps)
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, y + 3.0, z), Vector3(x, y - 3.0, z))
		var hit := space.intersect_ray(query)
		if hit.is_empty(): print("PROBE z=%.2f none" % z)
		else: print("PROBE z=%.2f y=%.3f n=%s %s" % [z, hit.position.y, hit.normal, (hit.collider as Node).get_path()])
	for h in [0.1, 0.3, 0.6, 1.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, y + h, z0), Vector3(x, y + h, z1))
		var hit := space.intersect_ray(query)
		print("SIDE h=%.1f %s" % [h, "none" if hit.is_empty() else "%s %s" % [hit.position, (hit.collider as Node).get_path()]])
	quit()
