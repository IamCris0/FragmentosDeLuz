extends StaticBody3D
## Fase 7: portal de regreso de una isla a la Carta del Archipiélago.
## El de llegada está siempre activo; el de la cumbre se enciende al obtener la llave.

@export var start_active: bool = true
@export var prompt: String = "Volver a la carta del archipiélago"
var active: bool = true
var vortex_material: ShaderMaterial
var light: OmniLight3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("level_gate")
	active = start_active or GameEvents.is_level_done(GameEvents.level)
	var vortex := get_node_or_null("Vortex") as MeshInstance3D
	if vortex: vortex_material = vortex.material_override as ShaderMaterial
	light = get_node_or_null("GateLight") as OmniLight3D
	_apply(false)


func available() -> bool:
	return active


func current_prompt() -> String:
	return prompt


func set_active(value: bool) -> void:
	active = value
	_apply(true)


func _apply(animate: bool) -> void:
	if vortex_material: vortex_material.set_shader_parameter("active", active)
	var vortex := get_node_or_null("Vortex") as Node3D
	if vortex:
		if animate and active:
			vortex.scale = Vector3.ONE * 0.05
			vortex.show()
			create_tween().tween_property(vortex, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			vortex.visible = active
	if light: light.visible = active


func interact(_player: Node3D) -> void:
	if not active: return
	var scene := get_tree().current_scene
	if scene.has_method("open_map"): scene.open_map()
