extends AnimatableBody3D

var start: Vector3
var phase: float = 0.0


func _ready() -> void:
	start = position


func _physics_process(delta: float) -> void:
	if GameEvents.lever_on:
		phase += delta * 0.55
		position = start + Vector3(0, (1.0 - cos(phase)) * 2.0, 0)
