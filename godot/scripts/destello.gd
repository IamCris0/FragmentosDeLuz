extends Area3D
## Fase 7: Destello, la moneda de la Constelación de Neri. Estrella de cuatro puntas que gira,
## flota y deja una estela al recogerse. Seis por isla; se guarda por identificador.

@export var destello_id: String = "d_grutas_1"
## Fase 7: algunos destellos aparecen al resolver un mecanismo (reveal()).
@export var hidden_until_reveal: bool = false
var taken: bool = false
var revealed: bool = true
var phase: float = 0.0
var visual: Node3D
var star: MeshInstance3D
var halo: MeshInstance3D
var light: OmniLight3D
var star_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("destello")
	if GameEvents.destello_ids.has(destello_id):
		queue_free()
		return
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	if not has_node("CollisionShape3D"):
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.85
		shape.shape = sphere
		add_child(shape)
	phase = float(abs(hash(destello_id)) % 100) * 0.1
	body_entered.connect(_on_body_entered)
	_build_visual()
	if hidden_until_reveal:
		revealed = false
		visible = false
		set_deferred("monitoring", false)


func reveal() -> void:
	if revealed or taken: return
	revealed = true
	visible = true
	set_deferred("monitoring", true)
	if visual:
		visual.scale = Vector3.ONE * 0.05
		create_tween().tween_property(visual, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func star_mesh(radius: float = 0.34, inner: float = 0.09, depth: float = 0.1) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in 8:
		var angle := PI * 0.5 + i * PI / 4.0
		var r := radius if i % 2 == 0 else inner
		rim.append(Vector3(cos(angle) * r, sin(angle) * r, 0.0))
	var front := Vector3(0, 0, depth)
	var back := Vector3(0, 0, -depth)
	for i in 8:
		var a: Vector3 = rim[i]
		var b: Vector3 = rim[(i + 1) % 8]
		for tri in [[front, a, b], [back, b, a]]:
			var p: Vector3 = tri[0]
			var q: Vector3 = tri[1]
			var s: Vector3 = tri[2]
			var normal := (q - p).cross(s - p).normalized()
			if normal.dot((p + q + s) / 3.0) < 0.0:
				normal = -normal
				var swap := q
				q = s
				s = swap
			for v in [p, q, s]:
				surface.set_normal(normal)
				surface.add_vertex(v)
	return surface.commit()


func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	star_material = StandardMaterial3D.new()
	star_material.albedo_color = Color("fff4d6")
	star_material.metallic = 0.3
	star_material.roughness = 0.25
	star_material.emission_enabled = true
	star_material.emission = Color("ffd98a")
	star_material.emission_energy_multiplier = 2.6
	star = MeshInstance3D.new()
	star.name = "Star"
	star.mesh = star_mesh()
	star.material_override = star_material
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(star)
	var small := MeshInstance3D.new()
	small.name = "InnerStar"
	small.mesh = star_mesh(0.2, 0.06, 0.12)
	small.material_override = star_material
	small.rotation.z = PI * 0.25
	small.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(small)
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.albedo_color = Color(1.0, 0.82, 0.45, 0.45)
	halo_material.albedo_texture = _halo_texture()
	halo = MeshInstance3D.new()
	halo.name = "Halo"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	halo.mesh = quad
	halo.material_override = halo_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(halo)
	light = OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color("ffd98a")
	light.light_energy = 1.1
	light.omni_range = 3.2
	add_child(light)


static func _halo_texture() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	texture.gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	return texture


func _process(delta: float) -> void:
	if taken or not visual: return
	phase += delta
	visual.rotation.y += delta * 1.6
	visual.position.y = sin(phase * 2.2) * 0.14
	star_material.emission_energy_multiplier = 2.4 + sin(phase * 4.0) * 0.5
	light.light_energy = 1.0 + sin(phase * 4.0) * 0.2


func _on_body_entered(body: Node3D) -> void:
	if taken or not body.is_in_group("player"): return
	collect()


func collect() -> void:
	if taken: return
	if not GameEvents.collect_destello(destello_id): return
	taken = true
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE * 2.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", 1.2, 0.5)
	tween.tween_property(star_material, "albedo_color:a", 0.0, 0.5)
	tween.tween_property(light, "light_energy", 4.0, 0.15)
	tween.chain().tween_property(light, "light_energy", 0.0, 0.3)
	star_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tween.chain().tween_callback(queue_free)
