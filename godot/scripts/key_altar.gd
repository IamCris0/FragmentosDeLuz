extends StaticBody3D
## Fase 7: altar de la Llave Estelar de una isla. La llave aparece al resolver la isla
## (reveal) y al tomarla se completa el nivel.

@export var gem_color: Color = Color("b18cff")
@export var revealed: bool = false
@export var prompt: String = "Tomar la llave estelar"
var taken: bool = false
var key: Node3D
var light: OmniLight3D
var time: float = 0.0
var base_height: float = 1.55


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("key_altar")
	taken = GameEvents.is_level_done(GameEvents.level)
	key = Node3D.new()
	key.name = "StarKey"
	key.position.y = base_height
	add_child(key)
	var packed: PackedScene = load("res://assets/props/star_key.glb") if ResourceLoader.exists("res://assets/props/star_key.glb") else null
	if packed:
		var model := packed.instantiate() as Node3D
		model.scale = Vector3.ONE * 0.9
		key.add_child(model)
		var gem := StandardMaterial3D.new()
		gem.albedo_color = gem_color.lightened(0.3)
		gem.emission_enabled = true
		gem.emission = gem_color
		gem.emission_energy_multiplier = 2.8
		gem.roughness = 0.1
		for mesh in model.find_children("*Gem*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = gem
	else:
		var fallback := MeshInstance3D.new()
		fallback.mesh = load("res://scripts/destello.gd").star_mesh(0.4, 0.12, 0.12)
		key.add_child(fallback)
	light = OmniLight3D.new()
	light.light_color = gem_color
	light.light_energy = 2.2
	light.omni_range = 6.0
	light.position.y = base_height
	add_child(light)
	_apply()


func _apply() -> void:
	key.visible = revealed and not taken
	light.visible = revealed and not taken


func reveal(animate: bool = true) -> void:
	if revealed: return
	revealed = true
	_apply()
	if animate and key.visible:
		key.scale = Vector3.ONE * 0.05
		key.position.y = base_height - 1.2
		var tween := create_tween().set_parallel(true)
		tween.tween_property(key, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(key, "position:y", base_height, 1.6).set_trans(Tween.TRANS_SINE)


func available() -> bool:
	return revealed and not taken


func current_prompt() -> String:
	return prompt


func interact(_player: Node3D) -> void:
	if not available(): return
	taken = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(key, "position:y", base_height + 1.4, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(key, "scale", Vector3.ONE * 0.01, 0.8).set_delay(0.4)
	tween.tween_property(light, "light_energy", 0.0, 1.0)
	tween.chain().tween_callback(_apply)
	var scene := get_tree().current_scene
	if scene.has_method("obtain_key"): scene.obtain_key()


func _process(delta: float) -> void:
	if not key.visible: return
	time += delta
	key.rotation.y += delta * 0.8
	if not taken: key.position.y = base_height + sin(time * 1.6) * 0.1
