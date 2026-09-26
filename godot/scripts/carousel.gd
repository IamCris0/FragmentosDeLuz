extends AnimatableBody3D
## Fase 7: plataforma giratoria (carrusel de los molinos, anillos del orrery). Gira sobre su eje Y
## y arrastra a Neri cuando está encima de uno de sus brazos.

@export var period: float = 12.0
@export var active: bool = true
@export var clockwise: bool = true
var angle: float = 0.0


func _ready() -> void:
	angle = rotation.y


func _physics_process(delta: float) -> void:
	if not active: return
	angle += TAU / maxf(period, 0.5) * delta * (-1.0 if clockwise else 1.0)
	rotation.y = angle
