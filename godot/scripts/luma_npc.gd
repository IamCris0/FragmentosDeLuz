extends StaticBody3D
## Fase 7: Luma acompaña a Neri en cada isla del archipiélago. Lo que dice depende del nivel
## (level_<id>.gd implementa luma_talk()).

@export var prompt: String = "Hablar con Luma"


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("luma")


func available() -> bool:
	return true


func current_prompt() -> String:
	return prompt


func interact(_player: Node3D) -> void:
	var scene := get_tree().current_scene
	if scene.has_method("luma_talk"): scene.luma_talk()
