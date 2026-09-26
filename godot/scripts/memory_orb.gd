extends Node3D
## Fase 6: «Memoria de Auralia», un eco luminoso coleccionable que cuenta la historia de la ciudad.
## Se construye por código (esfera, anillos, luz y chispas) y se atenúa cuando ya se escuchó.

var time: float = 0.0
var core: MeshInstance3D
var rings: Array[MeshInstance3D] = []
var light: OmniLight3D
var core_material: StandardMaterial3D
var heard: bool = false


func _ready() -> void:
	time = randf() * 10.0
	core_material = StandardMaterial3D.new()
	core_material.albedo_color = Color("fff1c9")
	core_material.emission_enabled = true
	core_material.emission = Color("f9c74f")
	core_material.emission_energy_multiplier = 2.6
	core = MeshInstance3D.new()
	core.name = "Core"
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	core.mesh = sphere
	core.material_override = core_material
	core.position.y = 1.15
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("8ff0e0")
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color.a = 0.8
	for i in 2:
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % i
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34 + i * 0.12
		torus.outer_radius = torus.inner_radius + 0.025
		torus.rings = 40
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = ring_material
		ring.position.y = 1.15
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		rings.append(ring)
	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	var base := CylinderMesh.new()
	base.top_radius = 0.28
	base.bottom_radius = 0.38
	base.height = 0.3
	base.radial_segments = 8
	plinth.mesh = base
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("7d8a86")
	stone.roughness = 0.9
	plinth.material_override = stone
	plinth.position.y = 0.15
	add_child(plinth)
	light = OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color("ffd98a")
	light.light_energy = 1.4
	light.omni_range = 3.5
	light.position.y = 1.15
	add_child(light)
	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 14
	sparks.lifetime = 2.2
	sparks.position.y = 1.15
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.35
	motion.direction = Vector3.UP
	motion.spread = 30
	motion.initial_velocity_min = 0.1
	motion.initial_velocity_max = 0.3
	motion.gravity = Vector3(0, 0.05, 0)
	motion.scale_min = 0.02
	motion.scale_max = 0.04
	sparks.process_material = motion
	var dot := SphereMesh.new()
	dot.radius = 0.5
	dot.height = 1.0
	dot.radial_segments = 4
	dot.rings = 2
	dot.material = core_material
	sparks.draw_pass_1 = dot
	add_child(sparks)


func _process(delta: float) -> void:
	time += delta
	var owner_body := get_parent()
	var id: String = str(owner_body.get("item_id")) if owner_body else ""
	heard = id != "" and GameEvents.story_seen.has(id)
	core.position.y = 1.15 + sin(time * 1.6) * 0.07
	for i in rings.size():
		rings[i].position.y = core.position.y
		rings[i].rotation = Vector3(sin(time * 0.7 + i) * 0.6, time * (0.8 + i * 0.5), cos(time * 0.5 + i) * 0.4)
	var strength := 0.45 if heard else 1.0
	core_material.emission_energy_multiplier = (2.6 + sin(time * 3.0) * 0.4) * strength
	light.light_energy = 1.4 * strength
