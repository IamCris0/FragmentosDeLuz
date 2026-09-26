extends StaticBody3D
## Fase 7: válvula de viento de los Picos del Céfiro. Al abrirla gira su rueda, despierta su molino
## y guarda la bandera del nivel.

signal opened(flag: String)

@export var flag: String = "valve_1"
@export var prompt: String = "Abrir la válvula de viento"
var open: bool = false
var wheel: Node3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("valve")
	wheel = find_child("ValveWheel", true, false) as Node3D
	open = GameEvents.level_flag(flag)
	if open and wheel: wheel.rotation.z = -TAU


func available() -> bool:
	return not open


func current_prompt() -> String:
	return prompt


func interact(_player: Node3D) -> void:
	if open: return
	open = true
	GameEvents.sound_requested.emit("valve")
	if wheel:
		var tween := create_tween()
		tween.tween_property(wheel, "rotation:z", -TAU, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameEvents.set_level_flag(flag)
	opened.emit(flag)
