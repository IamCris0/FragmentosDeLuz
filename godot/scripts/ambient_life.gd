extends Node3D
## Fase 6: bandadas de aves claras que rodean las islas al atardecer (como en la viñeta 1 del prólogo).
## Malla procedural, aleteo por nodos y trayectorias circulares con ondulación. Coste bajo.

const FLOCKS := [
	{"center": Vector3(0, 16, -20), "radius": 34.0, "speed": 0.07, "birds": 5},
	{"center": Vector3(6, 22, -70), "radius": 42.0, "speed": -0.055, "birds": 4},
	{"center": Vector3(-10, 12, -45), "radius": 26.0, "speed": 0.09, "birds": 3},
]

var flocks: Array[Dictionary] = []
var time: float = 0.0


func _ready() -> void:
	_dress_distant_islands()
	var body_mesh := _bird_body()
	var wing_mesh := _bird_wing()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f3eee2")
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color("fbe3c0")
	material.emission_energy_multiplier = 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = 1926
	for index in FLOCKS.size():
		var data: Dictionary = FLOCKS[index]
		var flock := {"data": data, "angle": rng.randf() * TAU, "birds": []}
		for i in int(data.birds):
			var bird := Node3D.new()
			bird.name = "Bird%d_%d" % [index, i]
			add_child(bird)
			var body := MeshInstance3D.new()
			body.mesh = body_mesh
			body.material_override = material
			bird.add_child(body)
			var wings: Array[Node3D] = []
			for side in [-1.0, 1.0]:
				var pivot := Node3D.new()
				pivot.position = Vector3(side * 0.05, 0.02, 0.02)
				bird.add_child(pivot)
				var wing := MeshInstance3D.new()
				wing.mesh = wing_mesh
				wing.material_override = material
				wing.scale = Vector3(side, 1, 1)
				pivot.add_child(wing)
				wings.append(pivot)
			var offset := Vector3((i % 2 * 2 - 1) * (0.9 + i * 0.6), rng.randf_range(-0.6, 0.6), -i * 1.1)
			flock.birds.append({"node": bird, "wings": wings, "offset": offset, "flap": rng.randf() * TAU,
				"rate": rng.randf_range(7.0, 9.5), "scale": rng.randf_range(0.8, 1.15)})
		flocks.append(flock)


func _bird_body() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(0, 0, 0.32), Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0, 0.05, 0.02),
		Vector3(0, 0, -0.22), Vector3(-0.08, 0, -0.3), Vector3(0.08, 0, -0.3)]
	for tri in [[0, 1, 3], [0, 3, 2], [1, 4, 3], [3, 4, 2], [4, 5, 6]]:
		for k in tri:
			tool.add_vertex(points[k])
	tool.generate_normals()
	return tool.commit()


func _bird_wing() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(0, 0, 0.1), Vector3(0, 0, -0.08), Vector3(0.28, 0.02, 0.02), Vector3(0.5, 0.03, -0.1)]
	for tri in [[0, 2, 1], [1, 2, 3]]:
		for k in tri:
			tool.add_vertex(points[k])
	tool.generate_normals()
	return tool.commit()


func _process(delta: float) -> void:
	time += delta
	for flock in flocks:
		var data: Dictionary = flock.data
		flock.angle += float(data.speed) * delta
		var a: float = flock.angle
		var center: Vector3 = data.center
		var radius: float = data.radius
		var lead := center + Vector3(cos(a) * radius, sin(a * 3.0) * 1.5, sin(a) * radius)
		var tangent := Vector3(-sin(a), 0.0, cos(a)) * signf(float(data.speed))
		var basis := Basis.looking_at(-tangent, Vector3.UP)
		for bird in flock.birds:
			var node: Node3D = bird.node
			node.position = lead + basis * (bird.offset as Vector3)
			node.basis = basis.scaled(Vector3.ONE * float(bird.scale) * 2.2)
			var flap: float = sin(time * float(bird.rate) + float(bird.flap))
			var glide: float = 0.5 + 0.5 * sin(time * 0.6 + float(bird.flap))
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				(bird.wings[i] as Node3D).rotation.z = side * flap * 0.7 * (0.35 + 0.65 * glide)


func _dress_distant_islands() -> void:
	var world := get_parent()
	if not world: return
	var Dressing = load("res://scripts/island_dressing.gd")
	for child in world.get_children():
		if child is Node3D and child.scene_file_path.ends_with("island_rock.glb") and absf(child.position.x) > 20.0:
			var material: ShaderMaterial = Dressing.cliff_material(child.position.y, 7.5 * child.scale.y)
			for mesh in child.find_children("*", "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).material_override = material
