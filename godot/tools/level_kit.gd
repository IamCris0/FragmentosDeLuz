extends RefCounted
## Fase 7: utilidades para generar las escenas de las islas del archipiélago (tools/build_levels.gd).
## Todo lo que se crea queda con owner = world para que PackedScene lo guarde.

const LevelData = preload("res://scripts/level_data.gd")

var world: Node3D
var rng := RandomNumberGenerator.new()
var cache: Dictionary = {}


func _init(root: Node3D, seed_value: int) -> void:
	world = root
	rng.seed = seed_value


func attach(parent: Node, node: Node, title: String) -> Node:
	node.name = title
	parent.add_child(node, true)
	node.owner = world
	return node


# --- Materiales ---------------------------------------------------------------------------------

func mat(color: Color, emission: float = 0.0, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "m_%s_%.2f_%.2f_%.2f" % [color.to_html(), emission, roughness, metallic]
	if cache.has(key): return cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	cache[key] = material
	return material


## Piedra pintada (stone_painted.png) teñida por la isla.
func stone(tint: Color, uv_scale: float = 0.65) -> StandardMaterial3D:
	var key := "s_%s_%.2f" % [tint.to_html(), uv_scale]
	if cache.has(key): return cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	if ResourceLoader.exists("res://assets/environment/stone_painted.png"):
		material.albedo_texture = load("res://assets/environment/stone_painted.png")
		material.uv1_scale = Vector3.ONE * uv_scale
		material.uv1_triplanar = true
	cache[key] = material
	return material


func shader_mat(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(path)
	for key in params: material.set_shader_parameter(key, params[key])
	return material


# --- Primitivas -----------------------------------------------------------------------------------

func model(parent: Node, path: String, title: String, pos: Vector3, scale_value: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Node3D:
	var packed: PackedScene = load("res://assets/" + path + ".glb")
	assert(packed != null, "Asset missing: " + path)
	var node: Node3D = attach(parent, packed.instantiate(), title)
	node.position = pos
	node.scale = scale_value
	node.rotation.y = yaw
	return node


func box(parent: Node, title: String, pos: Vector3, size: Vector3, material: Material, collision: bool = true, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	attach(parent, body, title)
	body.position = pos
	body.rotation = rot
	var shape := BoxMesh.new()
	shape.size = size
	var visual: MeshInstance3D = attach(body, MeshInstance3D.new(), "Mesh")
	visual.mesh = shape
	visual.material_override = material
	if collision:
		var collider: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
		var primitive := BoxShape3D.new()
		primitive.size = size
		collider.shape = primitive
	return body


func cylinder(parent: Node, title: String, pos: Vector3, radius: float, height: float, material: Material, collision: bool = true, sides: int = 12, top_radius: float = -1.0) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	attach(parent, body, title)
	body.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var visual: MeshInstance3D = attach(body, MeshInstance3D.new(), "Mesh")
	visual.mesh = mesh
	visual.material_override = material
	if collision:
		var collider: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collider.shape = shape
	return body


func light(parent: Node, pos: Vector3, color: Color, energy: float = 1.4, radius: float = 5.0, title: String = "Light") -> OmniLight3D:
	var node: OmniLight3D = attach(parent, OmniLight3D.new(), title)
	node.position = pos
	node.light_color = color
	node.light_energy = energy
	node.omni_range = radius
	return node


func label3d(parent: Node, caption: String, pos: Vector3, color: Color = Color("f1d48b"), size: int = 36) -> Label3D:
	var title: Label3D = attach(parent, Label3D.new(), "Inscription")
	title.text = caption
	title.position = pos
	title.font_size = size
	title.pixel_size = 0.006
	title.modulate = color
	title.outline_modulate = Color("141c26")
	title.outline_size = 10
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.visibility_range_end = 22
	return title


## Suelo octogonal con colisión convexa (misma forma que las islas de Auralia).
func ground(parent: Node, title: String, extent: Vector2, material: Material, y: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = attach(parent, StaticBody3D.new(), title)
	var outline := PackedVector3Array()
	var xh := extent.x * 0.5
	var zh := extent.y * 0.5
	var chamfer := minf(3.0, minf(xh, zh) * 0.4)
	for p in [Vector2(-xh + chamfer, -zh), Vector2(xh - chamfer, -zh), Vector2(xh, -zh + chamfer), Vector2(xh, zh - chamfer),
			Vector2(xh - chamfer, zh), Vector2(-xh + chamfer, zh), Vector2(-xh, zh - chamfer), Vector2(-xh, -zh + chamfer)]:
		outline.append(Vector3(p.x, y - 0.02, p.y))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		for vertex in [Vector3(0, y - 0.02, 0), outline[i], outline[(i + 1) % 8]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x, vertex.z) * 0.2)
			surface.add_vertex(vertex)
	var mesh: MeshInstance3D = attach(body, MeshInstance3D.new(), "Mesh")
	mesh.mesh = surface.commit()
	mesh.material_override = material
	var shape: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var convex := ConvexPolygonShape3D.new()
	var points := outline.duplicate()
	for point in outline: points.append(point - Vector3.UP * 0.5)
	convex.points = points
	shape.shape = convex
	return body


## Isla flotante: acantilado (island_rock), suelo y adorno inferior (island_dressing.gd).
func island(parent: Node, title: String, center: Vector3, extent: Vector2, ground_material: Material, style: Dictionary = {}) -> Node3D:
	var zone: Node3D = attach(parent, Node3D.new(), title)
	zone.position = center
	model(zone, "environment/island_rock", "IslandCliff", Vector3(0, -0.2, 0), Vector3(extent.x / 9.0, float(style.get("depth", 1.5)), extent.y / 9.0))
	ground(zone, "Ground", extent, ground_material)
	var dressing: Node3D = attach(zone, Node3D.new(), "Dressing")
	dressing.set_script(load("res://scripts/island_dressing.gd"))
	dressing.set("extent", extent)
	dressing.set("dressing_seed", int(style.get("seed", rng.randi() % 1000)))
	for key in ["crystal_color", "glow_color", "cliff_top", "cliff_deep", "cliff_moss", "cliff_vein", "vine_count", "crystal_count"]:
		if style.has(key): dressing.set(key, style[key])
	return zone


## Rampa con volumen (superficie y colisión convexas) entre dos puntos alineados en Z.
func walkway(parent: Node, title: String, a: Vector3, b: Vector3, width: float, material: Material, trim: Material = null) -> void:
	var vertices := PackedVector3Array()
	for p in [a, b]:
		vertices.append(p + Vector3(-width * 0.5, 0, 0))
		vertices.append(p + Vector3(width * 0.5, 0, 0))
	for i in range(4):
		var p: Vector3 = vertices[i]
		vertices.append(Vector3(p.x, minf(a.y, b.y) - 0.35, p.z))
	var body: StaticBody3D = attach(parent, StaticBody3D.new(), title)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector3 = (a + b) * 0.5 - Vector3.UP * 0.2
	for face in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		for tri in [[face[0], face[1], face[2]], [face[0], face[2], face[3]]]:
			var p: Vector3 = vertices[tri[0]]
			var q: Vector3 = vertices[tri[1]]
			var r: Vector3 = vertices[tri[2]]
			var normal: Vector3 = (q - p).cross(r - p).normalized()
			if normal.dot((p + q + r) / 3.0 - center) < 0: normal = -normal
			if (q - p).cross(r - p).dot(normal) > 0:
				var temp: Vector3 = q
				q = r
				r = temp
			for v in [p, q, r]:
				surface.set_normal(normal)
				surface.set_uv(Vector2(v.x, v.z) * 0.35)
				surface.add_vertex(v)
	var mesh: MeshInstance3D = attach(body, MeshInstance3D.new(), "Mesh")
	mesh.mesh = surface.commit()
	mesh.material_override = material
	var shape: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var hull := ConvexPolygonShape3D.new()
	hull.points = vertices
	shape.shape = hull
	if trim:
		for side in [-1, 1]:
			for i in range(8):
				var p: Vector3 = a.lerp(b, (i + 0.5) / 8.0) + Vector3(side * (width * 0.5 + 0.04), 0.075, 0)
				var coping := box(parent, title + "Coping", p, Vector3(0.16, 0.15, a.distance_to(b) / 8.0), trim, false)
				coping.rotation.x = -atan2(b.y - a.y, b.z - a.z)


## Puente recto a lo largo de Z con barandillas.
func bridge(parent: Node, title: String, start_z: float, end_z: float, y: float, x: float, deck: Material, rail: Material, width: float = 4.0) -> Node3D:
	var root: Node3D = attach(parent, Node3D.new(), title)
	var length := absf(end_z - start_z)
	box(root, "Deck", Vector3(x, y - 0.18, (start_z + end_z) * 0.5), Vector3(width, 0.35, length), deck)
	for side in [-1, 1]:
		for i in range(0, int(length) + 1, 3):
			box(root, "Post", Vector3(x + side * (width * 0.5 - 0.15), y + 0.55, maxf(start_z, end_z) - i), Vector3(0.28, 1.1, 0.28), rail)
		box(root, "Rail", Vector3(x + side * (width * 0.5 - 0.1), y + 0.7, (start_z + end_z) * 0.5), Vector3(0.12, 0.14, length), rail)
	return root


## Escalera visible con rampa de colisión oculta (como el ascenso del capítulo I).
func stairs(parent: Node, title: String, from: Vector3, to: Vector3, width: float, material: Material, steps: int = 12) -> Node3D:
	var root: Node3D = attach(parent, Node3D.new(), title)
	var rise := to.y - from.y
	var run := to.z - from.z
	for i in steps:
		var t := (i + 0.5) / steps
		var p := from.lerp(to, t)
		box(root, "Step", Vector3(from.x, from.y + rise * (i + 1) / steps - 0.13, p.z), Vector3(width, 0.26, absf(run) / steps + 0.05), material, false)
	var ramp := box(root, "Ramp", (from + to) * 0.5 + Vector3.UP * (-0.12), Vector3(width, 0.3, Vector2(run, rise).length()), material)
	ramp.rotation.x = atan2(rise, -run) if run < 0 else -atan2(rise, run)
	ramp.get_node("Mesh").hide()
	return root


# --- Juego ----------------------------------------------------------------------------------------

func checkpoint(parent: Node, index: int, pos: Vector3, size: Vector3 = Vector3(10, 4, 2), lantern: Vector3 = Vector3(3.4, 0, 0)) -> Area3D:
	var area: Area3D = attach(parent, Area3D.new(), "Refuge_%d" % index)
	area.set_script(load("res://scripts/level_checkpoint.gd"))
	area.position = pos
	area.set("index", index)
	area.set("size", size)
	area.set("lantern_offset", lantern)
	return area


func destello(parent: Node, id: String, pos: Vector3) -> Area3D:
	var area: Area3D = attach(parent, Area3D.new(), "Destello_" + id.get_slice("_", 2))
	area.set_script(load("res://scripts/destello.gd"))
	area.set("destello_id", id)
	area.position = pos
	return area


func memory(parent: Node, id: String, pos: Vector3, text: String) -> StaticBody3D:
	var body: StaticBody3D = attach(parent, StaticBody3D.new(), "Memory_" + id)
	body.position = pos
	body.set_script(load("res://scripts/interactable.gd"))
	body.set("kind", "memory")
	body.set("item_id", id)
	body.set("prompt", "Escuchar recuerdo")
	body.set("story_text", text)
	var visual: Node3D = attach(body, Node3D.new(), "Visual")
	visual.set_script(load("res://scripts/memory_orb.gd"))
	var collision: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var core := SphereShape3D.new()
	core.radius = 0.3
	collision.shape = core
	collision.position.y = 1.15
	return body


const ENEMY_KINDS := {
	"echo": ["res://scripts/enemy_sentinel.gd", "enemies/echo_sentinel"],
	"vigia": ["res://scripts/enemy_vigia.gd", "enemies/vigia"],
	"cefiro": ["res://scripts/enemy_cefiro.gd", "enemies/cefiro"],
}


func enemy(parent: Node, title: String, kind: String, pos: Vector3, patrol: float = 2.8, hp: int = 2) -> Area3D:
	assert(title in LevelData.all_enemies(), "Enemy id not registered in LevelData: " + title)
	var spec: Array = ENEMY_KINDS[kind]
	var body: Area3D = attach(parent, Area3D.new(), title)
	body.position = pos
	body.set_script(load(spec[0]))
	body.set("patrol_radius", patrol)
	body.set("health", hp)
	model(body, spec[1], "Visual", Vector3.ZERO)
	var collision: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var sphere := SphereShape3D.new()
	sphere.radius = 0.85
	collision.shape = sphere
	collision.position.y = 1.0
	var core: OmniLight3D = attach(body, OmniLight3D.new(), "CoreLight")
	core.position = Vector3(0, 1.05, 0)
	core.light_color = Color("8267d6") if kind != "cefiro" else Color("7ff0de")
	core.light_energy = 1.2
	core.omni_range = 4.5
	return body


func gate(parent: Node, title: String, pos: Vector3, start_active: bool, yaw: float = 0.0, prompt: String = "Volver a la carta del archipiélago") -> StaticBody3D:
	var body: StaticBody3D = attach(parent, StaticBody3D.new(), title)
	body.position = pos
	body.rotation.y = yaw
	body.set_script(load("res://scripts/level_gate.gd"))
	body.set("start_active", start_active)
	body.set("prompt", prompt)
	model(body, "props/portal_ring", "Visual", Vector3.ZERO)
	var collision: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.5, 0.35, 0.9)
	collision.shape = shape
	collision.position.y = 0.2
	var vortex: MeshInstance3D = attach(body, MeshInstance3D.new(), "Vortex")
	var quad := QuadMesh.new()
	quad.size = Vector2(2.65, 2.65)
	vortex.mesh = quad
	vortex.position = Vector3(0, 1.92, 0.04)
	vortex.material_override = shader_mat("res://shaders/portal.gdshader")
	var glow := light(body, Vector3(0, 2, 1), Color("8e81d9"), 2.0, 7.0, "GateLight")
	glow.name = "GateLight"
	return body


func key_altar(parent: Node, pos: Vector3, color: Color, pedestal: Material, trim: Material) -> StaticBody3D:
	var body: StaticBody3D = attach(parent, StaticBody3D.new(), "KeyAltar")
	body.position = pos
	body.set_script(load("res://scripts/key_altar.gd"))
	body.set("gem_color", color)
	cylinder(body, "Pedestal", Vector3(0, 0.45, 0), 0.7, 0.9, pedestal, false, 8, 0.55)
	cylinder(body, "PedestalTop", Vector3(0, 0.95, 0), 0.62, 0.1, trim, false, 8)
	var collision: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 1.0
	collision.shape = shape
	collision.position.y = 0.5
	return body


func luma(parent: Node, pos: Vector3, yaw: float = 0.4) -> StaticBody3D:
	var body: StaticBody3D = attach(parent, StaticBody3D.new(), "Luma")
	body.position = pos
	body.set_script(load("res://scripts/luma_npc.gd"))
	var visual := model(body, "characters/luma_spirit", "Visual", Vector3.ZERO)
	visual.rotation.y = yaw
	visual.set_script(load("res://scripts/luma_spirit.gd"))
	var collision: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.0, 0.5)
	collision.shape = shape
	collision.position.y = 0.5
	label3d(body, "Luma", Vector3(0, 2.25, 0), Color("c6efe1"))
	return body


func wind(parent: Node, title: String, pos: Vector3, size: Vector3, lift: float, push: Vector3 = Vector3.ZERO, active: bool = true) -> Area3D:
	var area: Area3D = attach(parent, Area3D.new(), title)
	area.set_script(load("res://scripts/wind_zone.gd"))
	area.position = pos
	area.set("size", size)
	area.set("lift", lift)
	area.set("push", push)
	area.set("active", active)
	return area


func player_and_interface(spawn: Vector3) -> void:
	var player: Node3D = attach(world, (load("res://assets/characters/player.tscn") as PackedScene).instantiate(), "Player")
	player.position = spawn
	attach(world, (load("res://assets/ui/hud.tscn") as PackedScene).instantiate(), "HUDLayer")
	var audio: Node = attach(world, Node.new(), "AudioManager")
	audio.set_script(load("res://scripts/audio_manager.gd"))


# --- Ambiente -------------------------------------------------------------------------------------

## config: sky (dict de parámetros de sky_islands.gdshader), ambient, ambient_energy, fog_color, fog_density,
## volumetric (densidad), sun_color, sun_energy, sun_rotation, exposure, glow.
func environment(config: Dictionary) -> void:
	var node: WorldEnvironment = attach(world, WorldEnvironment.new(), "WorldEnvironment")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = shader_mat("res://shaders/sky_islands.gdshader", config.get("sky", {}))
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = config.get("ambient", Color("8a93c4"))
	env.ambient_light_energy = float(config.get("ambient_energy", 0.4))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(config.get("exposure", 0.9))
	env.ssao_enabled = true
	env.ssao_radius = 0.55
	env.ssao_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = float(config.get("glow", 0.8))
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = config.get("fog_color", Color("6a6f9a"))
	env.fog_density = float(config.get("fog_density", 0.004))
	env.fog_sky_affect = float(config.get("fog_sky", 0.08))
	var volumetric := float(config.get("volumetric", 0.0))
	if volumetric > 0.0:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = volumetric
		env.volumetric_fog_albedo = config.get("fog_color", Color("6a6f9a"))
		env.volumetric_fog_emission = config.get("volumetric_emission", Color(0, 0, 0))
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_anisotropy = 0.3
	node.environment = env
	var sun: DirectionalLight3D = attach(world, DirectionalLight3D.new(), "Sun")
	sun.rotation_degrees = config.get("sun_rotation", Vector3(-35, -30, 0))
	sun.light_color = config.get("sun_color", Color("dcd6ff"))
	sun.light_energy = float(config.get("sun_energy", 0.6))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0


func cloud_sea(y: float, params: Dictionary = {}) -> MeshInstance3D:
	var sea: MeshInstance3D = attach(world, MeshInstance3D.new(), "CloudSea")
	var plane := PlaneMesh.new()
	plane.size = Vector2(560, 560)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	sea.mesh = plane
	sea.position = Vector3(0, y, -50)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.material_override = shader_mat("res://shaders/cloud_sea.gdshader", params)
	return sea


func ambient_particles(parent: Node, title: String, center: Vector3, extent: Vector3, color: Color, amount: int = 60,
		rise: float = 0.05, size: float = 0.035) -> GPUParticles3D:
	var particles: GPUParticles3D = attach(parent, GPUParticles3D.new(), title)
	particles.position = center
	particles.amount = amount
	particles.lifetime = 9.0
	particles.preprocess = 6.0
	particles.visibility_aabb = AABB(-extent - Vector3.ONE * 2.0, extent * 2.0 + Vector3.ONE * 4.0)
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = extent
	motion.gravity = Vector3(0.01, rise, 0.005)
	motion.direction = Vector3(0.3, 1.0, 0.1)
	motion.spread = 60.0
	motion.initial_velocity_min = 0.04
	motion.initial_velocity_max = 0.14
	motion.scale_min = size * 0.5
	motion.scale_max = size
	var fade := GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	motion.color_ramp = fade
	particles.process_material = motion
	var point := SphereMesh.new()
	point.radial_segments = 4
	point.rings = 2
	point.radius = 0.5
	point.height = 1.0
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.vertex_color_use_as_albedo = true
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.0
	point.material = glow
	particles.draw_pass_1 = point
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func save(path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(world) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	print("LEVEL_BUILT ", path, " ", world.find_children("*", "", true, false).size(), " nodes")


## Pradera animada (misma técnica que Auralia: multimalla + foliage.gdshader + meadow.gd).
func meadow(zone: Node3D, extent: Vector2, tint: Color, count: int = 600, clear_width: float = 4.3) -> MultiMeshInstance3D:
	var vegetation: MultiMeshInstance3D = attach(zone, MultiMeshInstance3D.new(), "Meadow")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		var angle: float = k * PI / 3.0
		for point in [Vector3(-0.04, 0, 0), Vector3(0.03, 0.42, 0), Vector3(0.06, 0, 0)]:
			surface.set_uv(Vector2(0.5, point.y / 0.42))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point.rotated(Vector3.UP, angle))
	var blade := surface.commit()
	var leaf := ShaderMaterial.new()
	leaf.shader = load("res://shaders/foliage.gdshader")
	leaf.set_shader_parameter("tint", tint)
	leaf.set_shader_parameter("flexibility", 0.3)
	blade.surface_set_material(0, leaf)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = blade
	multi.instance_count = count
	vegetation.multimesh = multi
	vegetation.set_script(load("res://scripts/meadow.gd"))
	vegetation.set("field_extent", extent)
	vegetation.set("field_seed", rng.randi() % 5000)
	vegetation.visibility_range_end = 60
	return vegetation


## Nube de piedra: "static", "crumble" (se desmorona) o "moving" (params.offset / params.period).
func cloud(parent: Node, title: String, pos: Vector3, size: float, kind: String = "static", params: Dictionary = {}) -> Node3D:
	var body: Node3D
	match kind:
		"crumble":
			body = AnimatableBody3D.new()
			attach(parent, body, title)
			body.set_script(load("res://scripts/crumble_platform.gd"))
			body.set("sensor_size", Vector3(3.6 * size, 0.6, 3.6 * size))
		"moving":
			body = AnimatableBody3D.new()
			attach(parent, body, title)
			body.set_script(load("res://scripts/mover.gd"))
			body.set("offset", params.get("offset", Vector3(4, 0, 0)))
			body.set("period", params.get("period", 6.0))
			body.set("phase", params.get("phase", 0.0))
		_:
			body = StaticBody3D.new()
			attach(parent, body, title)
	body.position = pos
	model(body, "environment/cloud_stone", "Visual", Vector3.ZERO, Vector3.ONE * size, rng.randf() * TAU)
	var collision: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
	var shape := CylinderShape3D.new()
	shape.radius = 2.0 * size
	shape.height = 0.5
	collision.shape = shape
	collision.position.y = -0.25
	return body


## Ráfagas de viento decorativas (partículas alargadas que cruzan el cielo).
func wind_streaks(parent: Node, title: String, center: Vector3, extent: Vector3, direction: Vector3, amount: int = 40) -> GPUParticles3D:
	var particles: GPUParticles3D = attach(parent, GPUParticles3D.new(), title)
	particles.position = center
	particles.amount = amount
	particles.lifetime = 3.5
	particles.preprocess = 3.0
	particles.visibility_aabb = AABB(-extent - Vector3.ONE * 10.0, extent * 2.0 + Vector3.ONE * 20.0)
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = extent
	motion.direction = direction.normalized()
	motion.spread = 4.0
	motion.initial_velocity_min = 6.0
	motion.initial_velocity_max = 10.0
	motion.gravity = Vector3.ZERO
	motion.scale_min = 0.6
	motion.scale_max = 1.3
	var fade := GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	fade.gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	motion.color_ramp = fade
	particles.process_material = motion
	var streak := QuadMesh.new()
	streak.size = Vector2(2.2, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1, 1, 1, 0.7)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = material
	particles.draw_pass_1 = streak
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func banner(parent: Node3D, pos: Vector3, dye: Color, pole: Material) -> void:
	cylinder(parent, "BannerPole", pos + Vector3.UP * 1.8, 0.045, 3.6, pole, false, 8)
	box(parent, "BannerCrossbar", pos + Vector3(0, 3.35, 0), Vector3(1.25, 0.06, 0.06), pole, false)
	var cloth: MeshInstance3D = attach(parent, MeshInstance3D.new(), "Banner")
	var grid := PlaneMesh.new()
	grid.orientation = PlaneMesh.FACE_Z
	grid.size = Vector2(1.0, 1.7)
	grid.subdivide_width = 10
	grid.subdivide_depth = 16
	cloth.mesh = grid
	cloth.position = pos + Vector3(0, 2.45, 0.07)
	cloth.material_override = shader_mat("res://shaders/banner.gdshader", {"dye": dye})
