extends Node3D

var restored: bool = false
var beam: MeshInstance3D
var light: OmniLight3D
var material: ShaderMaterial
var halos: Array[MeshInstance3D] = []
var elapsed: float = 0.0
var island_lights: Array[Node3D] = []


func _ready() -> void:
	position = Vector3(0, 4.1, -92)
	beam = MeshInstance3D.new()
	beam.name = "BeaconColumn"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.55
	cylinder.bottom_radius = 1.2
	cylinder.height = 38
	cylinder.radial_segments = 64
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	beam.mesh = cylinder
	beam.position.y = 19
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/beacon.gdshader")
	material.set_shader_parameter("strength", 0.0)
	beam.material_override = material
	add_child(beam)
	light = OmniLight3D.new()
	light.name = "RestoredLight"
	light.light_color = Color("ffe1a6")
	light.omni_range = 16
	light.light_energy = 0
	light.position.y = 5
	add_child(light)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("f5d582")
	glow.emission_enabled = true
	glow.emission = Color("ffe5a0")
	glow.emission_energy_multiplier = 1.4
	for i in 2:
		var halo := MeshInstance3D.new()
		halo.name = "RestoredHalo%d" % i
		var ring := TorusMesh.new()
		ring.inner_radius = 1.55 + i * 0.65
		ring.outer_radius = ring.inner_radius + 0.055
		ring.rings = 64
		ring.ring_segments = 8
		halo.mesh = ring
		halo.position.y = 4.0 + i * 2.0
		halo.material_override = glow
		add_child(halo)
		halos.append(halo)
	visible = false
	if GameEvents.completed: restore(false)


func _process(delta: float) -> void:
	# Durante la cinemática final el director enciende el faro en el momento exacto.
	if GameEvents.completed and not restored and not GameEvents.cinematic_active: restore(true)
	if not restored: return
	elapsed += delta
	for i in halos.size():
		halos[i].position.y = 4.0 + i * 2.0 + sin(elapsed * 0.7 + i) * 0.2
		halos[i].rotation.x = sin(elapsed * 0.3 + i) * 0.08
	for i in island_lights.size():
		var spark: Node3D = island_lights[i].get_node("Spark")
		spark.position.y = sin(elapsed * 0.9 + i * 1.7) * 0.25


func restore(animate: bool) -> void:
	if restored: return
	restored = true
	visible = true
	var environment: Environment = get_parent().get_node("WorldEnvironment").environment
	if animate:
		GameEvents.sound_requested.emit("beacon_chime")
		var tween := create_tween().set_parallel(true)
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter("strength", value), 0.0, 1.0, 3.0)
		tween.tween_property(light, "light_energy", 3.0, 3.0)
		tween.tween_property(environment, "ambient_light_energy", 0.38, 3.0)
	else:
		material.set_shader_parameter("strength", 1.0)
		light.light_energy = 3.0
		environment.ambient_light_energy = 0.38
	_light_distant_islands(animate)


## Fase 6: las islas lejanas responden al faro con pequeñas luces cálidas.
func _light_distant_islands(animate: bool) -> void:
	var world: Node = get_parent()
	var islands: Array[Node3D] = []
	for child in world.get_children():
		if child is Node3D and child.scene_file_path.ends_with("island_rock.glb") and absf(child.position.x) > 20.0:
			islands.append(child)
	islands.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffe1a0")
	glow.emission_enabled = true
	glow.emission = Color("ffd27a")
	glow.emission_energy_multiplier = 3.0
	var ray_material := StandardMaterial3D.new()
	ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ray_material.albedo_color = Color(1.0, 0.82, 0.5, 0.35)
	ray_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in islands.size():
		var island := islands[i]
		var marker := Node3D.new()
		marker.name = "DistantBeacon%d" % i
		add_child(marker)
		marker.global_position = island.global_position + Vector3.UP * (2.6 * island.scale.y + 0.8)
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.light_color = Color("ffd98f")
		lamp.omni_range = 8.0 * island.scale.x
		lamp.shadow_enabled = false
		marker.add_child(lamp)
		var spark := MeshInstance3D.new()
		spark.name = "Spark"
		var sphere := SphereMesh.new()
		sphere.radius = 0.45
		sphere.height = 0.9
		sphere.radial_segments = 12
		sphere.rings = 6
		spark.mesh = sphere
		spark.material_override = glow
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(spark)
		var ray := MeshInstance3D.new()
		ray.name = "Ray"
		var column := CylinderMesh.new()
		column.top_radius = 0.05
		column.bottom_radius = 0.32
		column.height = 16.0
		column.radial_segments = 10
		column.cap_top = false
		column.cap_bottom = false
		ray.mesh = column
		ray.position.y = 8.0
		ray.material_override = ray_material
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(ray)
		island_lights.append(marker)
		var size := 2.0 + island.scale.x * 0.9
		if not animate:
			lamp.light_energy = 2.4
			spark.scale = Vector3.ONE * size
			continue
		ray.scale = Vector3(1, 0.01, 1)
		lamp.light_energy = 0.0
		spark.scale = Vector3.ONE * 0.01
		var tween := create_tween()
		tween.tween_interval(4.2 + i * 0.32)
		tween.tween_callback(GameEvents.sound_requested.emit.bind("island_chime"))
		tween.set_parallel(true)
		tween.tween_property(lamp, "light_energy", 2.4, 0.9)
		tween.tween_property(spark, "scale", Vector3.ONE * size, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(ray, "scale", Vector3.ONE, 1.4).from(Vector3(1, 0.01, 1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
