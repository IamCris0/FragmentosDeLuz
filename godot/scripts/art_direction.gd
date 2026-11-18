extends RefCounted
## Upgrade shared scenery at load time, preserving authored collisions and light nodes.
static var paving_mesh: Mesh
static var paving_material: ShaderMaterial

static func apply(scene: Node) -> void:
	if scene.has_meta("art_redesign_applied"): return
	scene.set_meta("art_redesign_applied", true)
	if not paving_mesh:
		var tile := preload("res://assets/environment/flagstone_beveled.glb").instantiate()
		var piece := tile.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		paving_mesh = piece.mesh
		tile.free()
		paving_material = ShaderMaterial.new()
		paving_material.shader = preload("res://shaders/sanctuary_stone.gdshader")
		paving_material.set_shader_parameter("stone_texture", preload("res://assets/environment/stone_painted.png"))
	for piece: MeshInstance3D in scene.find_children("Mesh", "MeshInstance3D", true, false):
		var box := piece.mesh as BoxMesh
		if not box or not box.size.is_equal_approx(Vector3(1.98, 0.06, 1.98)): continue
		var dimensions := box.size
		piece.mesh = paving_mesh
		piece.scale = dimensions / paving_mesh.get_aabb().size
		piece.material_override = paving_material
		piece.add_to_group("redesigned_flagstone")
	for light: OmniLight3D in scene.find_children("LanternLight", "OmniLight3D", true, false):
		var glass := light.get_parent()
		var plinth := glass.get_parent() as Node3D
		if glass.name != &"AmberGlass" or not plinth or not plinth.has_node("LanternCap"): continue
		for old in plinth.find_children("*", "MeshInstance3D", true, false): old.hide()
		var lantern := preload("res://assets/environment/sanctuary_lantern.glb").instantiate() as Node3D
		lantern.name = "SculptedLantern"
		lantern.position.y = -0.3
		plinth.add_child(lantern)
		lantern.add_to_group("redesigned_lantern")
		light.light_color = Color("8ce8d6")
		light.position.y = 0.12
		light.light_energy = 0.5
