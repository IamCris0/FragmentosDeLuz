extends RefCounted
## Fase 7: Grutas Prismáticas. Cuatro islas-caverna a cielo abierto unidas por un puente de piedra,
## un puente de luz y plataformas de cristal. Rayos, prismas y receptores abren el camino.
##
## Recorrido (eje -Z): Boca de la Gruta (0,0,0) -> Salón de los Prismas (0,0,-34) -> Puente de Cuarzo
## (0,0,-60.5) -> plataformas -> Corazón Prismático (0,-2,-92).

const GROUND := Color("7d7299")
const WALL_TINT := Color("5d5578")


static func build(kit) -> void:
	var world: Node3D = kit.world
	world.set_script(load("res://scripts/level_grutas.gd"))
	world.set("level_id", "grutas")
	world.set("fall_limit", -18.0)
	world.set("music_themes", ["grutas", "grutas_deep"])
	kit.environment({
		"sky": {"zenith_color": Color("070a1c"), "horizon_color": Color("33244f"), "ground_color": Color("140f24"),
			"sun_color": Color("c9d6ff"), "sun_dir": Vector3(-0.45, 0.32, -0.83), "sun_size": 0.0016, "sun_glow": 0.16,
			"star_amount": 1.1, "cloud_amount": 0.25, "cloud_color": Color("3d2f63"), "aurora_amount": 0.7,
			"aurora_a": Color("5ff2d6"), "aurora_b": Color("9a6bff"), "nebula_amount": 0.8, "nebula_color": Color("7a4fd0")},
		"ambient": Color("8a88b8"), "ambient_energy": 0.6, "fog_color": Color("2b2652"), "fog_density": 0.0042,
		"sun_color": Color("b9c3ff"), "sun_energy": 0.45, "sun_rotation": Vector3(-38, 150, 0), "exposure": 0.95, "glow": 0.9,
	})
	kit.cloud_sea(-24.0, {"top_color": Color("6e5aa6"), "shade_color": Color("251d44"), "horizon_color": Color("33244f"),
		"sun_direction": Vector3(-0.4, 0.5, -0.7), "height": 3.5, "fade_distance": 240.0})
	var ground: Material = kit.stone(GROUND)
	var trim: Material = kit.stone(Color("9b94b8"))
	var dark: Material = kit.mat(Color("403a5c"), 0.0, 0.9)
	var style := {"crystal_color": Color("e1d2ff"), "glow_color": Color("9b6bff"), "cliff_top": Color(0.46, 0.4, 0.62),
		"cliff_deep": Color(0.2, 0.16, 0.3), "cliff_moss": Color(0.42, 0.34, 0.66), "cliff_vein": Color(0.72, 0.52, 1.0)}
	var zones: Node3D = kit.attach(world, Node3D.new(), "Zones")
	# --- Boca de la Gruta -----------------------------------------------------------------------
	style["seed"] = 71
	var mouth: Node3D = kit.island(zones, "Mouth", Vector3.ZERO, Vector2(24, 22), ground, style)
	rock_ring(kit, mouth, Vector2(24, 22), [["north", 0.0, 6.0], ["south", 0.0, 9.0]], 3)
	kit.gate(mouth, "ArrivalGate", Vector3(0, 0, 7.9), true)
	kit.checkpoint(mouth, 0, Vector3(0, 0, 5), Vector3(10, 4, 2))
	kit.luma(mouth, Vector3(-3.5, 0, 2.0), 0.5)
	emitter(kit, mouth, "Emitter_0", Vector3(-9, 0, -4), -PI * 0.5)
	prism(kit, mouth, "Prism_0", Vector3(-4.5, 0, -4), 2)
	receptor(kit, mouth, "Receptor_0", Vector3(-4.5, 0, -7.8), "door_0")
	door(kit, mouth, "Door_0", Vector3(0, 1.7, -10.3), Vector3(6.2, 3.4, 0.4), "door_0")
	for side in [-1, 1]:
		var pillar_body: Node3D = kit.box(mouth, "DoorPillar", Vector3(side * 4.3, 1.8, -10.3), Vector3(2.4, 3.6, 1.3), dark)
		pillar_body.get_node("Mesh").visible = false
		kit.model(mouth, "environment/cave_rock", "DoorRock", Vector3(side * 4.4, -0.3, -10.3), Vector3(1.05, 1.1, 0.8), side * 0.4)
	kit.enemy(mouth, "G_Echo_1", "echo", Vector3(4, 0, -3), 2.4, 1)
	kit.destello(mouth, "d_grutas_1", Vector3(8.5, 1.0, 6.0))
	kit.memory(mouth, "lore_g1", Vector3(-7.5, 0, 5.5), "Los talladores de luz trabajaban de noche. No cortaban el cristal: lo convencían. Decían que un prisma bien orientado podía llevar una promesa hasta la otra punta del archipiélago.")
	spire(kit, mouth, Vector3(9.0, 0, 2.5), 1.3, 0.4)
	spire(kit, mouth, Vector3(-9.5, 0, 7.5), 1.0, 2.1)
	spire(kit, mouth, Vector3(7.5, 0, -7.5), 0.9, 1.3)
	shards(kit, mouth, [Vector3(3, 0, 7), Vector3(-6, 0, -1), Vector3(6.5, 0, -1.5), Vector3(-2, 0, -7.5)])
	kit.ambient_particles(mouth, "AmbientSpores", Vector3(0, 2.0, 0), Vector3(10, 2, 9), Color("c8a8ff"), 50)
	arch(kit, mouth, Vector3(0, -0.4, -10.8), 0.0, 1.05)
	# --- Puente de piedra -------------------------------------------------------------------------
	kit.bridge(world, "StoneBridge", -11.0, -23.0, 0.0, 0.0, trim, kit.stone(Color("6f6891")))
	# --- Salón de los Prismas ---------------------------------------------------------------------
	style["seed"] = 83
	var hall: Node3D = kit.island(zones, "Hall", Vector3(0, 0, -34), Vector2(28, 22), ground, style)
	rock_ring(kit, hall, Vector2(28, 22), [["south", 0.0, 5.5], ["north", 0.0, 5.0], ["east", 7.0, 3.5]], 5)
	kit.checkpoint(hall, 1, Vector3(0, 0, 9.0), Vector3(10, 4, 2), Vector3(-3.4, 0, 0))
	emitter(kit, hall, "Emitter_1", Vector3(-11, 0, 6), -PI * 0.5)
	prism(kit, hall, "Prism_1", Vector3(-5, 0, 6), 2)
	prism(kit, hall, "Prism_2", Vector3(-5, 0, -4), 3)
	prism(kit, hall, "Prism_3", Vector3(5, 0, -4), 1)
	receptor(kit, hall, "Receptor_Bridge", Vector3(5, 0, -7.6), "bridge_1")
	receptor(kit, hall, "Receptor_Cache", Vector3(5, 0, 6.6), "cache_1")
	# Nicho del destello: se abre con el receptor del caché (lado este).
	kit.box(hall, "CacheFloor", Vector3(14.6, -0.1, 7.0), Vector3(3.2, 0.2, 4.0), ground)
	for z in [5.0, 9.0]:
		kit.box(hall, "CacheWall", Vector3(14.6, 1.6, z), Vector3(3.2, 3.2, 0.5), dark)
	kit.box(hall, "CacheBack", Vector3(16.1, 1.6, 7.0), Vector3(0.5, 3.2, 4.0), dark)
	door(kit, hall, "Door_Cache", Vector3(13.2, 1.5, 7.0), Vector3(0.35, 3.0, 3.6), "cache_1")
	kit.destello(hall, "d_grutas_2", Vector3(14.8, 1.0, 7.0))
	# Cornisa con destello: tres saltos sobre rocas de cristal.
	for step in [[Vector3(-8.8, 0.4, -3.2), Vector3(1.8, 0.8, 1.8)], [Vector3(-10.1, 0.8, -5.3), Vector3(1.6, 1.6, 1.6)], [Vector3(-11.2, 1.1, -7.6), Vector3(2.4, 2.2, 2.4)]]:
		kit.box(hall, "CrystalStep", step[0], step[1], trim)
	kit.destello(hall, "d_grutas_3", Vector3(-11.2, 3.2, -7.6))
	kit.enemy(hall, "G_Echo_2", "echo", Vector3(-1, 0, 2.0), 2.4, 2)
	kit.enemy(hall, "G_Echo_3", "echo", Vector3(8, 0, 2.5), 2.0, 2)
	kit.enemy(hall, "G_Vigia_1", "vigia", Vector3(0, 0, -8.0), 1.6, 2)
	spire(kit, hall, Vector3(0, 0, 1.2), 1.5, 0.2)
	spire(kit, hall, Vector3(10.5, 0, -7.5), 1.0, 1.0)
	spire(kit, hall, Vector3(-11.0, 0, 2.0), 0.9, 2.5)
	shards(kit, hall, [Vector3(2.5, 0, -8.5), Vector3(-2.5, 0, 7.5), Vector3(9, 0, 4.5), Vector3(-7.5, 0, 1.0)])
	kit.ambient_particles(hall, "AmbientSpores", Vector3(0, 2.2, 0), Vector3(12, 2, 9), Color("c8a8ff"), 60)
	arch(kit, hall, Vector3(0, -0.4, 10.6), 0.0, 1.0)
	arch(kit, hall, Vector3(0, -0.4, -10.8), 0.0, 1.0)
	# Puente de luz (se materializa con el receptor del puente).
	door(kit, world, "LightBridge", Vector3(0, -0.16, -50.0), Vector3(3.6, 0.32, 10.2), "bridge_1", true)
	# --- Puente de Cuarzo -------------------------------------------------------------------------
	style["seed"] = 97
	style["vine_count"] = 12
	var span: Node3D = kit.island(zones, "Span", Vector3(0, 0, -60.5), Vector2(14, 11), ground, style)
	style.erase("vine_count")
	kit.checkpoint(span, 2, Vector3(0, 0, 2.0), Vector3(8, 4, 2), Vector3(3.0, 0, 0))
	spire(kit, span, Vector3(-5.2, 0, 1.0), 0.9, 0.7)
	spire(kit, span, Vector3(5.3, 0, -2.5), 0.8, 2.0)
	for side in [-1, 1]:
		kit.model(span, "environment/cave_rock", "SpanRock", Vector3(side * 6.2, -0.2, 3.8), Vector3.ONE * 0.9, side * 0.7)
	# Descenso sobre la sima: plataformas de cristal, una móvil y una lateral con destello.
	crystal_platform(kit, world, "Platform_A", Vector3(0, -0.5, -69.4), Vector3(3.6, 0.5, 3.6), trim)
	var mover: AnimatableBody3D = kit.attach(world, AnimatableBody3D.new(), "Platform_Moving")
	mover.position = Vector3(-3.0, -1.0, -73.6)
	mover.set_script(load("res://scripts/mover.gd"))
	mover.set("offset", Vector3(6, 0, 0))
	mover.set("period", 6.5)
	platform_body(kit, mover, Vector3(3.0, 0.4, 3.0), trim)
	crystal_platform(kit, world, "Platform_Side", Vector3(-6.8, -0.8, -73.6), Vector3(2.4, 0.5, 2.4), trim)
	kit.destello(world, "d_grutas_4", Vector3(-6.8, 0.3, -73.6))
	crystal_platform(kit, world, "Platform_B", Vector3(0, -1.5, -77.6), Vector3(3.6, 0.5, 3.0), trim)
	var pillar: Node3D = kit.cylinder(world, "VigiaPillar", Vector3(7.0, -3.0, -73.5), 1.1, 4.0, dark, true, 8, 0.8)
	pillar.name = "VigiaPillar"
	kit.enemy(world, "G_Vigia_2", "vigia", Vector3(7.0, -1.0, -73.5), 0.3, 2)
	# --- Corazón Prismático -----------------------------------------------------------------------
	style["seed"] = 109
	var heart: Node3D = kit.island(zones, "Heart", Vector3(0, -2, -92), Vector2(28, 24), ground, style)
	rock_ring(kit, heart, Vector2(28, 24), [["south", 0.0, 5.5]], 7)
	kit.checkpoint(heart, 3, Vector3(0, 0, 10.0), Vector3(10, 4, 2), Vector3(3.4, 0, 0))
	kit.cylinder(heart, "HeartDais", Vector3(0, 0.2, -4.0), 2.6, 0.4, trim, true, 12)
	var core := spire(kit, heart, Vector3(0, 0.35, -4.0), 1.9, 0.0)
	core.name = "HeartCrystal"
	kit.light(heart, Vector3(0, 3.5, -4.0), Color("b18cff"), 2.4, 10.0, "HeartGlow")
	emitter(kit, heart, "Emitter_West", Vector3(-10.5, 0, 6), -PI * 0.5)
	prism(kit, heart, "Prism_4", Vector3(-7, 0, 6), 1)
	prism(kit, heart, "Prism_5", Vector3(-7, 0, -4), 2)
	receptor(kit, heart, "Receptor_West", Vector3(-3.6, 0, -4), "heart_west")
	emitter(kit, heart, "Emitter_East", Vector3(10.5, 0, -8), PI * 0.5)
	prism(kit, heart, "Prism_6", Vector3(7, 0, -8), 3)
	prism(kit, heart, "Prism_7", Vector3(7, 0, -4), 0)
	receptor(kit, heart, "Receptor_East", Vector3(3.6, 0, -4), "heart_east")
	kit.key_altar(heart, Vector3(0, 0, 0.4), Color("b18cff"), trim, kit.mat(Color("c9a54e"), 0.4, 0.35, 0.7))
	kit.gate(heart, "ExitGate", Vector3(0, 0, -8.8), false)
	kit.enemy(heart, "G_Echo_4", "echo", Vector3(-5.5, 0, 2.5), 2.2, 2)
	kit.enemy(heart, "G_Echo_5", "echo", Vector3(5.5, 0, 2.5), 2.2, 2)
	kit.enemy(heart, "G_Vigia_3", "vigia", Vector3(-4.0, 0, -9.0), 1.2, 2)
	kit.destello(heart, "d_grutas_5", Vector3(-9.5, 1.0, -7.2))
	# Cornisa alta: requiere doble salto (Constelación, rama del Viento).
	kit.box(heart, "HighLedge", Vector3(9.9, 1.15, 5.2), Vector3(2.4, 2.3, 2.4), trim)
	kit.box(heart, "LedgeStep", Vector3(8.2, 0.5, 3.3), Vector3(1.4, 1.0, 1.4), trim)
	kit.destello(heart, "d_grutas_6", Vector3(9.9, 3.3, 5.2))
	kit.memory(heart, "lore_g2", Vector3(-8.5, 0, 7.5), "El corazón prismático nunca se apagó del todo. Cuando el faro cayó, los talladores sellaron su luz aquí para que la señal tuviera dónde apoyarse. Ahora vuelve a latir.")
	spire(kit, heart, Vector3(-10.5, 0, -1.0), 1.2, 0.8)
	spire(kit, heart, Vector3(11.0, 0, 1.5), 1.1, 2.4)
	shards(kit, heart, [Vector3(-4, 0, 8), Vector3(4.5, 0, 7.5), Vector3(-9, 0, 2.5), Vector3(9.5, 0, -6.5), Vector3(0, 0, -9)])
	kit.ambient_particles(heart, "AmbientSpores", Vector3(0, 2.4, 0), Vector3(12, 2.5, 10), Color("d6b8ff"), 70)
	arch(kit, heart, Vector3(0, -0.4, 11.6), 0.0, 1.05)
	# --- Fondo: islas lejanas con cristales ---------------------------------------------------------
	for i in 14:
		var x: float = kit.rng.randf_range(34, 70) * (1 if i % 2 else -1)
		var backdrop: Node3D = kit.model(world, "environment/island_rock", "DistantIsland", Vector3(x, kit.rng.randf_range(-16, 8), kit.rng.randf_range(-130, 30)), Vector3.ONE * kit.rng.randf_range(0.6, 1.8), kit.rng.randf() * TAU)
		if i % 2 == 0: kit.model(backdrop, "environment/crystal_spire", "DistantCrystal", Vector3(0, 0, 0), Vector3.ONE * 1.4)
	kit.player_and_interface(Vector3(0, 0.2, 6))


## Anillo de rocas de caverna con colisión alrededor de una isla. openings: [lado, centro, ancho].
static func rock_ring(kit, zone: Node3D, extent: Vector2, openings: Array, seed_value: int) -> void:
	var local := RandomNumberGenerator.new()
	local.seed = seed_value
	var hx := extent.x * 0.5 - 0.9
	var hz := extent.y * 0.5 - 0.9
	var chamfer := minf(3.0, minf(hx, hz) * 0.4)
	var outline := [Vector2(-hx + chamfer, -hz), Vector2(hx - chamfer, -hz), Vector2(hx, -hz + chamfer), Vector2(hx, hz - chamfer),
		Vector2(hx - chamfer, hz), Vector2(-hx + chamfer, hz), Vector2(-hx, hz - chamfer), Vector2(-hx, -hz + chamfer)]
	var walls: Node3D = kit.attach(zone, Node3D.new(), "CaveWalls")
	var count := 0
	for i in 8:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % 8]
		var steps := maxi(1, int(a.distance_to(b) / 2.6))
		for k in steps:
			var p := a.lerp(b, (k + 0.5) / steps)
			if _in_opening(p, hx, hz, openings): continue
			var s := local.randf_range(1.0, 1.45)
			var yaw := local.randf() * TAU
			kit.model(walls, "environment/cave_rock", "CaveRock", Vector3(p.x, -0.3, p.y), Vector3(s, s * local.randf_range(0.9, 1.35), s), yaw)
			var body: StaticBody3D = kit.attach(walls, StaticBody3D.new(), "CaveRockCollision")
			body.position = Vector3(p.x, 2.5, p.y)
			var shape: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
			var box := BoxShape3D.new()
			box.size = Vector3(2.6, 5.0, 2.6) * Vector3(s, 1.0, s)
			shape.shape = box
			count += 1


static func _in_opening(p: Vector2, hx: float, hz: float, openings: Array) -> bool:
	for opening in openings:
		var side: String = opening[0]
		var center: float = opening[1]
		var half: float = float(opening[2]) * 0.5 + 1.1
		match side:
			"north": if p.y < -hz + 0.5 and absf(p.x - center) < half: return true
			"south": if p.y > hz - 0.5 and absf(p.x - center) < half: return true
			"west": if p.x < -hx + 0.5 and absf(p.y - center) < half: return true
			"east": if p.x > hx - 0.5 and absf(p.y - center) < half: return true
	return false


static func spire(kit, parent: Node3D, pos: Vector3, size: float, yaw: float) -> Node3D:
	var node: Node3D = kit.model(parent, "environment/crystal_spire", "CrystalSpire", pos, Vector3.ONE * size, yaw)
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), "SpireCollision")
	body.position = pos + Vector3.UP * 1.5 * size
	var shape: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.75 * size
	cylinder.height = 3.0 * size
	shape.shape = cylinder
	kit.light(parent, pos + Vector3.UP * 2.0 * size, Color("a57dff"), 1.2, 5.0 + size * 2.0, "SpireLight")
	return node


static func shards(kit, parent: Node3D, points: Array) -> void:
	for point in points:
		kit.model(parent, "environment/crystal_shard", "CrystalShard", point, Vector3.ONE * kit.rng.randf_range(0.8, 1.4), kit.rng.randf() * TAU)


static func arch(kit, parent: Node3D, pos: Vector3, yaw: float, size: float) -> void:
	kit.model(parent, "environment/rock_arch", "RockArch", pos, Vector3.ONE * size, yaw)


static func emitter(kit, parent: Node3D, title: String, pos: Vector3, yaw: float) -> StaticBody3D:
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title)
	body.position = pos
	body.rotation.y = yaw
	body.set_script(load("res://scripts/beam_emitter.gd"))
	kit.model(body, "props/beam_emitter", "Visual", Vector3.ZERO)
	var collision: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.7, 1.0)
	collision.shape = shape
	collision.position.y = 0.85
	return body


static func prism(kit, parent: Node3D, title: String, pos: Vector3, facing: int) -> StaticBody3D:
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title)
	body.position = pos
	body.set_script(load("res://scripts/prism.gd"))
	body.set("facing", facing)
	kit.model(body, "props/prism", "Visual", Vector3.ZERO)
	var collision: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.8, 0.9)
	collision.shape = shape
	collision.position.y = 0.9
	return body


static func receptor(kit, parent: Node3D, title: String, pos: Vector3, flag: String) -> StaticBody3D:
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title)
	body.position = pos
	body.set_script(load("res://scripts/beam_receptor.gd"))
	body.set("flag", flag)
	kit.model(body, "props/beam_receptor", "Visual", Vector3.ZERO)
	var collision: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	return body


static func door(kit, parent: Node, title: String, pos: Vector3, size: Vector3, flag: String, is_bridge: bool = false) -> StaticBody3D:
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title)
	body.position = pos
	body.set_script(load("res://scripts/crystal_door.gd"))
	body.set("flag", flag)
	body.set("bridge", is_bridge)
	var mesh: MeshInstance3D = kit.attach(body, MeshInstance3D.new(), "Mesh")
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var collision: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return body


static func platform_body(kit, body: Node3D, size: Vector3, material: Material) -> void:
	var mesh: MeshInstance3D = kit.attach(body, MeshInstance3D.new(), "Mesh")
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	var collision: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	kit.model(body, "environment/crystal_shard", "UnderCrystal", Vector3(0, -size.y * 0.5, 0), Vector3(1.1, -1.3, 1.1), 0.4)


static func crystal_platform(kit, parent: Node, title: String, pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title)
	body.position = pos
	platform_body(kit, body, size, material)
	return body
