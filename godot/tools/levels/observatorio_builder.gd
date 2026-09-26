extends RefCounted
## Fase 7: Observatorio Estelar. Noche estrellada, mármol con estrellas incrustadas, el Jardín de
## Constelaciones, los anillos giratorios del orrery y la cúpula donde espera el Heraldo del Eclipse.
##
## Recorrido: Escalinata (0,0,0) -> escalera -> Jardín (0,6,-34) -> puente estelar -> orrery
## (0,6,-58.5 / carrusel -66.5 / 0,6,-74.5) -> rampa -> Cúpula (0,8,-96).

const Level = preload("res://scripts/level_observatorio.gd")
const TILES := Level.TILES
const ORDER := Level.ORDER


static func build(kit) -> void:
	var world: Node3D = kit.world
	world.set_script(load("res://scripts/level_observatorio.gd"))
	world.set("level_id", "observatorio")
	world.set("fall_limit", -14.0)
	world.set("music_themes", ["observatorio", "boss"])
	kit.environment({
		"sky": {"zenith_color": Color("03061a"), "horizon_color": Color("1f2a5c"), "ground_color": Color("090c1e"),
			"sun_color": Color("fff3dc"), "sun_dir": Vector3(0.35, 0.42, -0.84), "sun_size": 0.0018, "sun_glow": 0.18,
			"star_amount": 1.6, "cloud_amount": 0.12, "cloud_color": Color("2a3570"), "aurora_amount": 0.45,
			"aurora_a": Color("ffd98a"), "aurora_b": Color("7fa8ff"), "nebula_amount": 1.0, "nebula_color": Color("3d5cc8")},
		"ambient": Color("8a9bd8"), "ambient_energy": 0.6, "fog_color": Color("18204a"), "fog_density": 0.003,
		"sun_color": Color("c2d0ff"), "sun_energy": 0.55, "sun_rotation": Vector3(-42, -150, 0), "exposure": 1.0, "glow": 0.9,
	})
	kit.cloud_sea(-20.0, {"top_color": Color("56669f"), "shade_color": Color("141a3a"), "horizon_color": Color("1f2a5c"),
		"sun_direction": Vector3(0.3, 0.5, -0.8), "height": 3.0, "fade_distance": 230.0})
	var floor: Material = kit.shader_mat("res://shaders/star_floor.gdshader", {"glow": 0.35})
	var marble: Material = kit.stone(Color("c9cfdf"))
	var dark: Material = kit.stone(Color("5a6384"))
	var gold: Material = kit.mat(Color("c9a54e"), 0.3, 0.35, 0.75)
	var style := {"crystal_color": Color("fff4dc"), "glow_color": Color("f1d48b"), "cliff_top": Color(0.5, 0.52, 0.66),
		"cliff_deep": Color(0.18, 0.2, 0.32), "cliff_moss": Color(0.32, 0.36, 0.58), "cliff_vein": Color(0.95, 0.85, 0.55)}
	var zones: Node3D = kit.attach(world, Node3D.new(), "Zones")
	# --- Escalinata Nocturna ----------------------------------------------------------------------
	style["seed"] = 211
	var stairs_zone: Node3D = kit.island(zones, "Stairs", Vector3.ZERO, Vector2(20, 20), floor, style)
	kit.gate(stairs_zone, "ArrivalGate", Vector3(0, 0, 7.9), true)
	kit.checkpoint(stairs_zone, 0, Vector3(0, 0, 5), Vector3(10, 4, 2))
	kit.luma(stairs_zone, Vector3(-3.5, 0, 2.0), 0.5)
	kit.memory(stairs_zone, "lore_o1", Vector3(6.5, 0, 3.0), "Maren fue la última farolera de Auralia. Construyó a Luma con restos de estrellas para que alguien siguiera escuchando cuando ella ya no pudiera.")
	kit.destello(stairs_zone, "d_observatorio_1", Vector3(-7.0, 1.0, -6.0))
	colonnade(kit, stairs_zone, [Vector3(-3.4, 0, -2), Vector3(3.4, 0, -2), Vector3(-3.4, 0, -7), Vector3(3.4, 0, -7)], gold)
	var grand: Node3D = kit.stairs(world, "GrandStairs", Vector3(0, 0, -9.8), Vector3(0, 6, -23.2), 5.0, marble, 20)
	# La rampa de colisión termina exactamente en el borde del jardín (suelo a 5,98 m): sin escalón
	# invisible que frene a Neri al subir ni al bajar.
	var box_ramp: Node = grand.get_node("Ramp")
	grand.remove_child(box_ramp)
	box_ramp.free()
	kit.walkway(grand, "Ramp", Vector3(0, -0.01, -9.8), Vector3(0, 5.99, -23.0), 5.0, marble)
	(grand.get_node("Ramp/Mesh") as Node3D).hide()
	for side in [-1, 1]:
		var rail: Node3D = kit.box(world, "StairRail", Vector3(side * 2.65, 3.6, -16.5), Vector3(0.3, 0.8, 14.8), dark)
		rail.rotation.x = atan2(6.0, 13.4)
	# --- Jardín de Constelaciones -------------------------------------------------------------------
	style["seed"] = 223
	var garden: Node3D = kit.island(zones, "Garden", Vector3(0, 6, -34), Vector2(26, 22), floor, style)
	kit.checkpoint(garden, 1, Vector3(0, 0, 9.0), Vector3(10, 4, 2), Vector3(-3.4, 0, 0))
	var tiles: Node3D = kit.attach(garden, Node3D.new(), "Constellation")
	tiles.position = Vector3(0, 0, -1.0)
	for i in TILES.size():
		var tile: Area3D = kit.attach(tiles, Area3D.new(), "StarTile_%d" % i)
		tile.set_script(load("res://scripts/star_tile.gd"))
		tile.set("index", i)
		tile.position = Vector3(TILES[i].x, 0, TILES[i].y)
	stele(kit, garden, Vector3(6.8, 0, 6.0), marble, gold)
	var reward: Area3D = kit.destello(tiles, "d_observatorio_2", Vector3(0, 1.0, -1.0))
	reward.set("hidden_until_reveal", true)
	kit.box(garden, "PedestalStep", Vector3(-10.0, 0.5, -6.0), Vector3(1.4, 1.0, 1.4), marble)
	kit.box(garden, "StarPedestal", Vector3(-11.4, 0.95, -8.0), Vector3(1.8, 1.9, 1.8), marble)
	kit.destello(garden, "d_observatorio_3", Vector3(-11.4, 2.9, -8.0))
	kit.enemy(garden, "O_Echo_1", "echo", Vector3(-8.0, 0, -2.0), 2.4, 2)
	kit.enemy(garden, "O_Echo_2", "echo", Vector3(8.0, 0, -5.0), 2.4, 2)
	kit.enemy(garden, "O_Cefiro_1", "cefiro", Vector3(5.0, 0, 3.0), 2.5, 2)
	kit.enemy(garden, "O_Vigia_1", "vigia", Vector3(0, 0, -8.5), 1.4, 2)
	colonnade(kit, garden, [Vector3(-11, 0, 6), Vector3(11, 0, 1), Vector3(-11, 0, -3), Vector3(11, 0, -7), Vector3(-6, 0, -9.5), Vector3(6, 0, -9.5)], gold)
	armillary(kit, garden, Vector3(-7.5, 0, 5.5), gold, 0.8)
	var bridge: StaticBody3D = kit.attach(world, StaticBody3D.new(), "StarBridge")
	bridge.position = Vector3(0, 5.84, -50.5)
	bridge.set_script(load("res://scripts/crystal_door.gd"))
	bridge.set("flag", "constellation")
	bridge.set("bridge", true)
	bridge.set("tint", Color(1.0, 0.82, 0.45))
	var bridge_mesh: MeshInstance3D = kit.attach(bridge, MeshInstance3D.new(), "Mesh")
	var deck := BoxMesh.new()
	deck.size = Vector3(3.6, 0.32, 10.4)
	bridge_mesh.mesh = deck
	var bridge_shape: CollisionShape3D = kit.attach(bridge, CollisionShape3D.new(), "CollisionShape3D")
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(3.6, 0.32, 10.4)
	bridge_shape.shape = deck_shape
	# --- Anillos del Orrery -----------------------------------------------------------------------
	style["seed"] = 239
	style["vine_count"] = 14
	var south: Node3D = kit.island(zones, "OrrerySouth", Vector3(0, 6, -58.5), Vector2(16, 5), floor, style)
	kit.checkpoint(south, 2, Vector3(0, 0, 1.5), Vector3(10, 4, 2), Vector3(3.4, 0, 0))
	kit.enemy(south, "O_Echo_3", "echo", Vector3(4.5, 0, 0.0), 1.6, 2)
	var north: Node3D = kit.island(zones, "OrreryNorth", Vector3(0, 6, -74.5), Vector2(16, 5), floor, style)
	style.erase("vine_count")
	kit.enemy(north, "O_Vigia_2", "vigia", Vector3(-5.0, 0, -0.5), 1.2, 2)
	var orrery: AnimatableBody3D = kit.attach(world, AnimatableBody3D.new(), "Orrery")
	orrery.position = Vector3(0, 6, -66.5)
	orrery.set_script(load("res://scripts/carousel.gd"))
	orrery.set("period", 14.0)
	var axis_mat: Material = kit.mat(Color("40569a"), 0.35, 0.35, 0.65)
	kit.cylinder(orrery, "Axis", Vector3(0, 1.0, 0), 0.7, 5.0, axis_mat, false, 16)
	for band_y in [0.1, 1.4, 2.7]:
		kit.cylinder(orrery, "AxisBand", Vector3(0, band_y, 0), 0.76, 0.12, gold, false, 16)
	armillary(kit, orrery, Vector3(0, 3.2, 0), gold, 1.2)
	for k in 3:
		var angle := TAU * k / 3.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		var arm: Node3D = kit.box(orrery, "RingArm", direction * 2.3 + Vector3.UP * 0.4, Vector3(0.25, 0.2, 3.2), gold, false)
		arm.rotation.y = angle
		var platform: Node3D = kit.box(orrery, "RingPlatform", direction * 4.2 + Vector3(0, -0.15, 0), Vector3(2.6, 0.3, 2.6), marble, false)
		platform.rotation.y = angle
		var shape: CollisionShape3D = kit.attach(orrery, CollisionShape3D.new(), "RingCollision")
		var box := BoxShape3D.new()
		box.size = Vector3(2.6, 0.3, 2.6)
		shape.shape = box
		shape.position = direction * 4.2 + Vector3(0, -0.15, 0)
		shape.rotation.y = angle
	kit.destello(orrery, "d_observatorio_4", Vector3(sin(TAU * 2.0 / 3.0), 0, cos(TAU * 2.0 / 3.0)) * 4.2 + Vector3.UP * 1.0)
	kit.cloud(world, "StarStone", Vector3(11.5, 6.8, -74.5), 0.6)
	kit.destello(world, "d_observatorio_5", Vector3(11.5, 7.8, -74.5))
	kit.walkway(world, "DomeRamp", Vector3(0, 5.99, -77.0), Vector3(0, 7.99, -83.0), 4.0, marble, dark)
	# --- Cúpula del Observatorio ------------------------------------------------------------------
	style["seed"] = 251
	var dome: Node3D = kit.island(zones, "Dome", Vector3(0, 8, -96), Vector2(26, 26), floor, style)
	kit.checkpoint(dome, 3, Vector3(0, 0, 11.0), Vector3(12, 5, 2), Vector3(3.6, 0, 0))
	kit.model(dome, "environment/observatory_dome", "ObservatoryDome", Vector3.ZERO, Vector3.ONE * 1.35, PI)
	for k in 12:
		if k == 3: continue  # entrada: sin columna en el eje de la rampa (igual que el modelo)
		var angle := TAU * k / 12.0
		var column: StaticBody3D = kit.attach(dome, StaticBody3D.new(), "DomeColumn")
		column.position = Vector3(cos(angle) * 9.45, 3.5, sin(angle) * 9.45)
		var shape: CollisionShape3D = kit.attach(column, CollisionShape3D.new(), "CollisionShape3D")
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.62
		cylinder.height = 7.0
		shape.shape = cylinder
	var telescope: Node3D = kit.model(dome, "props/telescope", "Telescope", Vector3.ZERO, Vector3.ONE, 0.0)
	var mount: StaticBody3D = kit.attach(dome, StaticBody3D.new(), "TelescopeCollision")
	mount.position = Vector3(0, 1.2, 0)
	var mount_shape: CollisionShape3D = kit.attach(mount, CollisionShape3D.new(), "CollisionShape3D")
	var mount_cylinder := CylinderShape3D.new()
	mount_cylinder.radius = 1.45
	mount_cylinder.height = 2.4
	mount_shape.shape = mount_cylinder
	telescope.name = "Telescope"
	for k in 3:
		var angle := PI + TAU * k / 3.0
		var pillar: StaticBody3D = kit.attach(dome, StaticBody3D.new(), "StarPillar_%d" % k)
		pillar.position = Vector3(sin(angle) * 6.6, 0, cos(angle) * 6.6)
		pillar.set_script(load("res://scripts/star_pillar.gd"))
		kit.model(pillar, "props/star_pillar", "Visual", Vector3.ZERO)
		var pillar_shape: CollisionShape3D = kit.attach(pillar, CollisionShape3D.new(), "CollisionShape3D")
		var pillar_cylinder := CylinderShape3D.new()
		pillar_cylinder.radius = 0.6
		pillar_cylinder.height = 3.2
		pillar_shape.shape = pillar_cylinder
		pillar_shape.position.y = 1.6
	var boss: Area3D = kit.attach(dome, Area3D.new(), "Heraldo")
	boss.position = Vector3(0, 6, 0)
	boss.set_script(load("res://scripts/boss_heraldo.gd"))
	kit.model(boss, "enemies/heraldo", "Visual", Vector3.ZERO)
	var boss_shape: CollisionShape3D = kit.attach(boss, CollisionShape3D.new(), "CollisionShape3D")
	var boss_sphere := SphereShape3D.new()
	boss_sphere.radius = 1.4
	boss_shape.shape = boss_sphere
	var arena: Area3D = kit.attach(dome, Area3D.new(), "ArenaTrigger")
	arena.position = Vector3(0, 1.5, 3.0)
	var arena_shape: CollisionShape3D = kit.attach(arena, CollisionShape3D.new(), "CollisionShape3D")
	var arena_box := BoxShape3D.new()
	arena_box.size = Vector3(14, 3, 10)
	arena_shape.shape = arena_box
	kit.key_altar(dome, Vector3(0, 0, 4.6), Color("ffe6a8"), marble, gold)
	kit.gate(dome, "ExitGate", Vector3(-6.5, 0, 7.5), false, 0.6)
	var memory: StaticBody3D = kit.memory(dome, "lore_o2", Vector3(4.2, 0, 6.8), "«La noche del eclipse encerré al Heraldo bajo la cúpula con mi propia luz. Antes de apagarme, apunté el telescopio al futuro y envié una señal. Que alguien la escuche.»\n\n— Maren, la última farolera")
	memory.name = "Memory_lore_o2"
	kit.destello(dome, "d_observatorio_6", Vector3(7.8, 1.0, -7.2))
	# --- Fondo: islas lejanas con ruinas y constelaciones -----------------------------------------
	for i in 16:
		var x: float = kit.rng.randf_range(36, 80) * (1 if i % 2 else -1)
		var backdrop: Node3D = kit.model(world, "environment/island_rock", "DistantIsland", Vector3(x, kit.rng.randf_range(-14, 14), kit.rng.randf_range(-150, 30)), Vector3.ONE * kit.rng.randf_range(0.6, 1.9), kit.rng.randf() * TAU)
		if i % 3 == 0: kit.model(backdrop, "props/star_pillar", "DistantPillar", Vector3.ZERO, Vector3.ONE * 1.4)
	kit.ambient_particles(world, "AmbientStardust", Vector3(0, 10, -50), Vector3(18, 8, 55), Color("ffe6a8"), 110, 0.02, 0.03)
	kit.player_and_interface(Vector3(0, 0.2, 6))


static func colonnade(kit, parent: Node3D, points: Array, gold: Material) -> void:
	for p in points:
		kit.model(parent, "environment/column", "StarColumn", p, Vector3(0.9, 1.2, 0.9))
		kit.light(parent, p + Vector3(0, 3.6, 0), Color("ffe1a6"), 0.9, 4.5, "ColumnLight")
		var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), "ColumnCollision")
		body.position = p + Vector3.UP * 1.6
		var shape: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.4
		cylinder.height = 3.2
		shape.shape = cylinder


static func armillary(kit, parent: Node3D, pos: Vector3, gold: Material, size: float) -> void:
	var sphere: Node3D = kit.attach(parent, Node3D.new(), "Armillary")
	sphere.position = pos + Vector3.UP * 1.6 * size
	for k in 3:
		var ring: MeshInstance3D = kit.attach(sphere, MeshInstance3D.new(), "Ring")
		var torus := TorusMesh.new()
		torus.inner_radius = (1.0 - k * 0.15) * size
		torus.outer_radius = torus.inner_radius + 0.06 * size
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = gold
		ring.rotation = Vector3(PI * 0.5 * (k % 2), k * 0.7, k * 0.4)
	var core: MeshInstance3D = kit.attach(sphere, MeshInstance3D.new(), "Core")
	var ball := SphereMesh.new()
	ball.radius = 0.22 * size
	ball.height = 0.44 * size
	core.mesh = ball
	core.material_override = kit.mat(Color("ffe6a8"), 2.5, 0.3)


static func stele(kit, parent: Node3D, pos: Vector3, marble: Material, gold: Material) -> void:
	var slab: Node3D = kit.box(parent, "Stele", pos + Vector3(0, 1.6, 0), Vector3(0.35, 3.2, 3.0), marble)
	slab.rotation.y = -0.35
	kit.box(slab, "SteleCap", Vector3(0, 1.7, 0), Vector3(0.5, 0.2, 3.2), gold, false)
	var chart: Node3D = kit.attach(slab, Node3D.new(), "StarChart")
	chart.position = Vector3(-0.19, 0.1, 0)
	var star_material: Material = kit.mat(Color("fff1c9"), 3.0, 0.3)
	var line_material: Material = kit.mat(Color("ffd98a"), 1.6, 0.3)
	var scale := 0.19
	for i in TILES.size():
		var p: Vector2 = TILES[i] * scale
		var dot: MeshInstance3D = kit.attach(chart, MeshInstance3D.new(), "ChartStar")
		var ball := SphereMesh.new()
		ball.radius = 0.09 if i == ORDER[0] else 0.055
		ball.height = ball.radius * 2.0
		dot.mesh = ball
		dot.material_override = star_material
		dot.position = Vector3(0, -p.y, p.x)
	for k in ORDER.size() - 1:
		var a: Vector2 = TILES[ORDER[k]] * scale
		var b: Vector2 = TILES[ORDER[k + 1]] * scale
		var mid := (a + b) * 0.5
		var line: MeshInstance3D = kit.attach(chart, MeshInstance3D.new(), "ChartLine")
		var bar := BoxMesh.new()
		bar.size = Vector3(0.02, 0.025, a.distance_to(b))
		line.mesh = bar
		line.material_override = line_material
		line.position = Vector3(0, -mid.y, mid.x)
		var direction := Vector3(0, -(b.y - a.y), b.x - a.x).normalized()
		line.basis = Basis.looking_at(direction, Vector3.RIGHT)
	kit.label3d(slab, "LA FAROLERA", Vector3(-0.25, 1.95, 0), Color("f1d48b"), 30)
