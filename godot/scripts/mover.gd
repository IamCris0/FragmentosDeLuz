extends AnimatableBody3D
## Fase 7: plataforma que oscila entre su posición inicial y start + offset (movimiento suave).
## Neri se desplaza con ella (AnimatableBody3D sincronizado con la física).

@export var offset: Vector3 = Vector3(6, 0, 0)
@export var period: float = 6.0
@export var phase: float = 0.0
@export var active: bool = true
var start: Vector3
var time: float = 0.0


func _ready() -> void:
	start = position
	time = phase * period
	_apply()


func _physics_process(delta: float) -> void:
	if not active: return
	time += delta
	_apply()


func _apply() -> void:
	position = start + offset * (0.5 - 0.5 * cos(time * TAU / maxf(period, 0.1)))
