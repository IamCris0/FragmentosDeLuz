extends StaticBody3D
## Fase 7: prisma giratorio. Al interactuar gira 90° en sentido horario; el rayo sale por su cara
## marcada con la flecha dorada (eje -Z del cabezal).

signal rotated(facing: int)

@export var facing: int = 0
@export var fixed: bool = false
@export var prompt: String = "Girar el prisma"
var head: Node3D
var turn_tween: Tween
var yaw: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("prism")
	head = find_child("PrismHead", true, false) as Node3D
	facing = posmod(facing, 4)
	yaw = -facing * PI * 0.5
	if head: head.rotation.y = yaw


func available() -> bool:
	return not fixed


func current_prompt() -> String:
	return prompt


func interact(_player: Node3D) -> void:
	if fixed: return
	turn()


func turn() -> void:
	facing = (facing + 1) % 4
	yaw -= PI * 0.5
	GameEvents.sound_requested.emit("prism_turn")
	if head:
		if turn_tween: turn_tween.kill()
		turn_tween = create_tween()
		turn_tween.tween_property(head, "rotation:y", yaw, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rotated.emit(facing)


## Coloca el prisma en una orientación concreta sin animación (partidas guardadas y pruebas).
func set_facing(value: int) -> void:
	facing = posmod(value, 4)
	yaw = -facing * PI * 0.5
	if turn_tween: turn_tween.kill()
	if head: head.rotation.y = yaw


func beam_point() -> Vector3:
	return global_position + Vector3.UP * 1.25


func output_direction() -> Vector3:
	var direction: Vector3 = -(head.global_basis.z if head else global_basis.z)
	direction.y = 0.0
	return direction.normalized()
