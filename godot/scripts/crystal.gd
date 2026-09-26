extends StaticBody3D

@export_range(0.0, 1.0) var energy: float = 0.0
var clock: float = 0.0
var materials: Array[StandardMaterial3D] = []
var core_material: StandardMaterial3D

@onready var visual: Node3D = $Visual
@onready var local_light: OmniLight3D = $Light


func _ready() -> void:
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var source: Material = instance.mesh.surface_get_material(surface)
			if source is StandardMaterial3D:
				var mat: StandardMaterial3D = source.duplicate() as StandardMaterial3D
				instance.set_surface_override_material(surface, mat)
				materials.append(mat)
				if "Shell" in str(node.name):
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = 0.55
					mat.cull_mode = BaseMaterial3D.CULL_BACK
					mat.emission_enabled = true
					mat.emission_energy_multiplier = 0.18
				elif "Core" in str(node.name):
					core_material = mat
	GameEvents.energy_changed.connect(_on_energy_changed)


func _on_energy_changed(current: float, maximum: float) -> void:
	energy = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	clock += delta
	visual.rotation.y += delta * (0.12 + energy * 0.25)
	visual.position.y = sin(clock * 1.5) * 0.025
	local_light.light_energy = 0.5 + energy * 1.1 + sin(clock * 2.2) * 0.07
	if core_material:
		core_material.emission_energy_multiplier = 0.8 + energy * 1.2 + sin(clock * 2.2) * 0.12
