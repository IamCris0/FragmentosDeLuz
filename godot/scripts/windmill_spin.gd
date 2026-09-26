extends Node3D
## Fase 7: hace girar las aspas (nodo Blades) de un molino. Lento en reposo, rápido al despertar.

@export var spinning: bool = false
@export var idle_speed: float = 0.12
@export var active_speed: float = 1.8
var blades: Node3D
var speed: float = 0.0


func _ready() -> void:
	blades = find_child("Blades", true, false) as Node3D
	speed = active_speed if spinning else idle_speed


func set_spinning(value: bool) -> void:
	spinning = value


func _process(delta: float) -> void:
	speed = move_toward(speed, active_speed if spinning else idle_speed, delta * 0.8)
	if blades: blades.rotation.z += speed * delta
