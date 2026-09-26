extends RefCounted
## Fase 7: Picos del Céfiro. Praderas altas al amanecer, nubes de piedra que se desmoronan,
## molinos que despiertan con válvulas de viento y una gran corriente que lleva a la cumbre.
##
## Recorrido: Mirador (0,0,0) -> Escalera de Nubes -> meseta (0,2,-43) -> Molinos Antiguos (0,3,-68)
## -> corriente central -> Cumbre (0,14,-92).

const GRASS := Color("5f9a62")


static func build(kit) -> void:
	var world: Node3D = kit.world
	world.set_script(load("res://scripts/level_cefiro.gd"))
	world.set("level_id", "cefiro")
	world.set("fall_limit", -12.0)
	world.set("music_themes", ["cefiro", "cefiro_summit"])
	kit.environment({
		"sky": {"zenith_color": Color("3d7cc2"), "horizon_color": Color("ffc9a0"), "ground_color": Color("b3a2c7"),
			"sun_color": Color("fff0d0"), "sun_dir": Vector3(0.35, 0.14, -0.93), "sun_size": 0.0035, "sun_glow": 0.7,
			"star_amount": 0.0, "cloud_amount": 0.6, "cloud_color": Color("fff4ea"), "aurora_amount": 0.0,
			"nebula_amount": 0.0, "horizon_sharpness": 2.2},
		"ambient": Color("c6d6ec"), "ambient_energy": 0.55, "fog_color": Color("f0cdbb"), "fog_density": 0.0022,
		"sun_color": Color("ffe4c2"), "sun_energy": 1.15, "sun_rotation": Vector3(-24, 158, 0), "exposure": 0.95, "glow": 0.6,
	})
	kit.cloud_sea(-18.0, {"top_color": Color("fff7ef"), "shade_color": Color("b9a8cc"), "horizon_color": Color("ffd2b0"),
		"sun_direction": Vector3(0.35, 0.3, -0.9), "height": 4.0, "fade_distance": 260.0, "scale": 0.02})
	var ground: Material = kit.stone(Color("8fb07e"))
	var path: Material = kit.stone(Color("d9d2c2"))
	var pole: Material = kit.stone(Color("6d6a64"))
	var wood: Material = kit.mat(Color("7a5a3f"), 0.0, 0.85)
	var style := {"crystal_color": Color("d8fff8"), "glow_color": Color("5fd9c9"), "cliff_top": Color(0.78, 0.66, 0.52),
		"cliff_deep": Color(0.42, 0.38, 0.46), "cliff_moss": Color(0.36, 0.56, 0.34), "cliff_vein": Color(0.4, 0.9, 0.82)}
	var zones: Node3D = kit.attach(world, Node3D.new(), "Zones")
	# --- Mirador del Céfiro -----------------------------------------------------------------------
	style["seed"] = 131
	var lookout: Node3D = kit.island(zones, "Lookout", Vector3.ZERO, Vector2(22, 20), ground, style)
	paved_path(kit, lookout, Vector2(22, 20), path)
	kit.meadow(lookout, Vector2(22, 20), GRASS)
	kit.gate(lookout, "ArrivalGate", Vector3(0, 0, 7.9), true)
	kit.checkpoint(lookout, 0, Vector3(0, 0, 5), Vector3(10, 4, 2))
	kit.luma(lookout, Vector3(-3.5, 0, 2.0), 0.5)
	windmill(kit, lookout, "Windmill_Lookout", Vector3(-7.5, 0, -4.0), 0.75, 0.6, true)
	kit.enemy(lookout, "C_Echo_1", "echo", Vector3(3.0, 0, -4.0), 2.2, 1)
	kit.wind(lookout, "Updraft_0", Vector3(7.0, 0, -3.5), Vector3(3.0, 8.0, 3.0), 7.0)
	kit.cloud(lookout, "Ledge_0", Vector3(7.0, 4.8, -8.2), 0.75)
	kit.destello(lookout, "d_cefiro_1", Vector3(7.0, 5.8, -8.2))
	kit.memory(lookout, "lore_c1", Vector3(-7.5, 0, 4.0), "Los guardianes del viento no tenían alas. Tenían paciencia: esperaban al borde del acantilado hasta que el aire subía y entonces se dejaban llevar.")
	for p in [Vector3(-8.5, 0, 7.0), Vector3(8.8, 0, 3.0), Vector3(-9.0, 0, -8.0)]:
		kit.model(lookout, "environment/tree", "WindTree", p, Vector3.ONE * kit.rng.randf_range(1.0, 1.4), kit.rng.randf() * TAU)
	for side in [-1, 1]:
		kit.banner(lookout, Vector3(side * 4.2, 0, -7.8), Color("2f6f7a") if side > 0 else Color("c2733f"), pole)
	kit.wind_streaks(lookout, "AmbientWind", Vector3(0, 6, -10), Vector3(20, 5, 20), Vector3(1, 0.05, -0.3), 26)
	# --- Escalera de Nubes -------------------------------------------------------------------------
	var steps: Node3D = kit.attach(world, Node3D.new(), "CloudSteps")
	kit.cloud(steps, "Cloud_1", Vector3(0, -1.5, -18.0), 1.0)
	kit.cloud(steps, "Cloud_2", Vector3(2.2, -0.8, -22.5), 0.8, "crumble")
	kit.cloud(steps, "Cloud_3", Vector3(-0.6, 0.0, -26.5), 1.0)
	kit.cloud(steps, "Cloud_Side", Vector3(-5.8, 0.5, -28.0), 0.7, "crumble")
	kit.destello(steps, "d_cefiro_2", Vector3(-5.8, 1.5, -28.0))
	kit.cloud(steps, "Cloud_4", Vector3(-2.0, 0.9, -30.5), 0.9, "moving", {"offset": Vector3(5, 0, 0), "period": 7.0})
	kit.cloud(steps, "Cloud_5", Vector3(0, 1.5, -34.4), 0.8, "crumble")
	# --- Meseta ------------------------------------------------------------------------------------
	style["seed"] = 149
	var plateau: Node3D = kit.island(zones, "Plateau", Vector3(0, 2, -43), Vector2(18, 14), ground, style)
	paved_path(kit, plateau, Vector2(18, 14), path)
	kit.meadow(plateau, Vector2(18, 14), GRASS, 420)
	kit.checkpoint(plateau, 1, Vector3(0, 0, 5.5), Vector3(10, 4, 2), Vector3(-3.4, 0, 0))
	kit.enemy(plateau, "C_Cefiro_1", "cefiro", Vector3(-3.0, 0, -2.0), 2.5, 2)
	kit.enemy(plateau, "C_Cefiro_2", "cefiro", Vector3(4.0, 0, 2.0), 2.0, 2)
	kit.wind(plateau, "Updraft_1", Vector3(5.0, 0, -3.0), Vector3(3.0, 10.0, 3.0), 7.0)
	kit.cloud(plateau, "HighCloud", Vector3(5.0, 6.8, -7.8), 0.8)
	kit.destello(plateau, "d_cefiro_3", Vector3(5.0, 7.8, -7.8))
	kit.model(plateau, "environment/tree", "WindTree", Vector3(-6.5, 0, 3.5), Vector3.ONE * 1.3, 0.4)
	kit.banner(plateau, Vector3(-5.0, 0, -5.5), Color("2f6f7a"), pole)
	kit.walkway(world, "PlateauRamp", Vector3(0, 2, -49.8), Vector3(0, 3, -56.2), 4.0, path, pole)
	# --- Molinos Antiguos --------------------------------------------------------------------------
	style["seed"] = 163
	var mills: Node3D = kit.island(zones, "Mills", Vector3(0, 3, -68), Vector2(30, 24), ground, style)
	paved_path(kit, mills, Vector2(30, 24), path)
	kit.meadow(mills, Vector2(30, 24), GRASS, 800)
	kit.checkpoint(mills, 2, Vector3(0, 0, 11.0), Vector3(10, 4, 2), Vector3(3.4, 0, 0))
	windmill(kit, mills, "Windmill_1", Vector3(-10, 0, 6), 1.0, 0.5)
	windmill(kit, mills, "Windmill_2", Vector3(10, 0, 6), 1.0, -0.5)
	windmill(kit, mills, "Windmill_3", Vector3(0, 0, -9.0), 1.1, 0.0)
	valve(kit, mills, "Valve_1", Vector3(-7.0, 0, 3.8), "valve_1", 0.6)
	valve(kit, mills, "Valve_2", Vector3(7.0, 0, 3.8), "valve_2", -0.6)
	valve(kit, mills, "Valve_3", Vector3(3.0, 0, -6.2), "valve_3", 0.0)
	var vent: Node3D = kit.cylinder(mills, "GreatVent", Vector3(0, 0.03, 0), 2.3, 0.1, kit.mat(Color("8f8a80"), 0.0, 0.8), false, 16)
	vent.name = "GreatVent"
	kit.cylinder(mills, "GreatVentGrate", Vector3(0, 0.09, 0), 1.9, 0.03, kit.mat(Color("4ecdc4"), 1.2, 0.4), false, 16)
	kit.wind(mills, "GreatUpdraft", Vector3(0, 0, 0), Vector3(4.2, 16.0, 4.2), 8.5, Vector3.ZERO, false)
	kit.destello(mills, "d_cefiro_5", Vector3(0, 10.0, 0))
	kit.enemy(mills, "C_Cefiro_3", "cefiro", Vector3(0, 0, 6.0), 3.0, 2)
	kit.enemy(mills, "C_Echo_2", "echo", Vector3(-6.0, 0, -2.0), 2.4, 2)
	kit.enemy(mills, "C_Echo_3", "echo", Vector3(6.0, 0, -4.0), 2.4, 2)
	# Carrusel sobre el vacío con una nube lejana y su destello.
	var carousel: AnimatableBody3D = kit.attach(world, AnimatableBody3D.new(), "Carousel")
	carousel.position = Vector3(-20.0, 3.0, -72.0)
	carousel.set_script(load("res://scripts/carousel.gd"))
	carousel.set("period", 11.0)
	kit.cylinder(carousel, "Hub", Vector3(0, 0.4, 0), 0.6, 1.6, pole, false, 10)
	for side in [-1, 1]:
		kit.box(carousel, "Arm", Vector3(side * 2.1, 1.05, 0), Vector3(3.6, 0.18, 0.3), wood, false)
		kit.box(carousel, "ArmPlatform", Vector3(side * 4.0, 0.15, 0), Vector3(2.4, 0.3, 2.4), path, false)
		var shape: CollisionShape3D = kit.attach(carousel, CollisionShape3D.new(), "ArmCollision")
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 0.3, 2.4)
		shape.shape = box
		shape.position = Vector3(side * 4.0, 0.15, 0)
	kit.cloud(world, "FarCloud", Vector3(-28.6, 3.3, -72.0), 0.8)
	kit.destello(world, "d_cefiro_4", Vector3(-28.6, 4.3, -72.0))
	# Viento lateral entre los molinos y la cumbre.
	kit.wind(world, "Crosswind", Vector3(0, 18.0, -79.0), Vector3(14.0, 10.0, 6.0), 0.0, Vector3(5.0, 0, 0))
	kit.wind_streaks(world, "CrosswindStreaks", Vector3(0, 18.0, -79.0), Vector3(7.0, 5.0, 3.0), Vector3(1, 0, 0), 30)
	# --- Cumbre del Céfiro -------------------------------------------------------------------------
	style["seed"] = 181
	var summit: Node3D = kit.island(zones, "Summit", Vector3(0, 14, -92), Vector2(20, 16), ground, style)
	paved_path(kit, summit, Vector2(20, 16), path)
	kit.meadow(summit, Vector2(20, 16), GRASS.lightened(0.1), 420)
	kit.checkpoint(summit, 3, Vector3(0, 0, 6.0), Vector3(12, 5, 2), Vector3(3.4, 0, 0))
	kit.key_altar(summit, Vector3(0, 0, -3.0), Color("8fe9d6"), path, kit.mat(Color("c9a54e"), 0.4, 0.35, 0.7))
	kit.gate(summit, "ExitGate", Vector3(0, 0, -6.5), false)
	kit.memory(summit, "lore_c2", Vector3(-6.0, 0, -1.0), "Los molinos no molían grano: cantaban. Cada aspa daba una nota al viento y la canción llevaba las noticias de isla en isla. Cuando callaron, el archipiélago dejó de hablar.")
	kit.destello(summit, "d_cefiro_6", Vector3(7.0, 1.0, -5.5))
	kit.enemy(summit, "C_Cefiro_4", "cefiro", Vector3(-3.0, 0, 2.0), 2.5, 2)
	kit.enemy(summit, "C_Echo_4", "echo", Vector3(4.0, 0, 0.0), 2.2, 2)
	for side in [-1, 1]:
		kit.banner(summit, Vector3(side * 3.0, 0, -5.0), Color("e8d6a8"), pole)
		kit.model(summit, "environment/column", "SummitColumn", Vector3(side * 5.5, 0, -6.0), Vector3(1, 1.4, 1))
	kit.wind_streaks(summit, "AmbientWind", Vector3(0, 4, 0), Vector3(14, 4, 12), Vector3(1, 0.1, 0.2), 24)
	# --- Fondo -------------------------------------------------------------------------------------
	for i in 16:
		var x: float = kit.rng.randf_range(34, 80) * (1 if i % 2 else -1)
		var backdrop: Node3D = kit.model(world, "environment/island_rock", "DistantIsland", Vector3(x, kit.rng.randf_range(-10, 16), kit.rng.randf_range(-140, 30)), Vector3.ONE * kit.rng.randf_range(0.6, 1.9), kit.rng.randf() * TAU)
		if i % 3 == 0: kit.model(backdrop, "environment/windmill", "DistantMill", Vector3(0, 0, 0), Vector3.ONE * 0.9)
	kit.player_and_interface(Vector3(0, 0.2, 6))


static func paved_path(kit, zone: Node3D, extent: Vector2, material: Material) -> void:
	for z in range(-int(extent.y / 2) + 1, int(extent.y / 2), 2):
		var tile: Node3D = kit.box(zone, "PathStone", Vector3(0, 0.02, z), Vector3(3.6, 0.06, 1.9), material, false)
		tile.rotation.y = kit.rng.randf_range(-0.03, 0.03)


static func windmill(kit, parent: Node3D, title: String, pos: Vector3, size: float, yaw: float, spinning: bool = false) -> Node3D:
	var mill: Node3D = kit.model(parent, "environment/windmill", title, pos, Vector3.ONE * size, yaw)
	mill.set_script(load("res://scripts/windmill_spin.gd"))
	mill.set("spinning", spinning)
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title + "Collision")
	body.position = pos + Vector3.UP * 3.0 * size
	var shape: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.6 * size
	cylinder.height = 6.0 * size
	shape.shape = cylinder
	return mill


static func valve(kit, parent: Node3D, title: String, pos: Vector3, flag: String, yaw: float) -> StaticBody3D:
	var body: StaticBody3D = kit.attach(parent, StaticBody3D.new(), title)
	body.position = pos
	body.rotation.y = yaw
	body.set_script(load("res://scripts/valve.gd"))
	body.set("flag", flag)
	kit.model(body, "props/valve", "Visual", Vector3.ZERO)
	var collision: CollisionShape3D = kit.attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.6, 0.8)
	collision.shape = shape
	collision.position.y = 0.8
	return body
