extends Area3D

@export var fragment_id: StringName = &"fragment_0"
@export var requires_puzzle: bool = false
var phase: float = 0
var taken: bool = false
@onready var visual: Node3D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if GameEvents.fragment_ids.has(str(fragment_id)):
		queue_free()
	phase = float(hash(str(fragment_id)) % 100) * 0.1


func _process(delta: float) -> void:
	phase += delta
	visible = not requires_puzzle or GameEvents.puzzle_solved
	visual.rotation.y += delta * 0.9
	visual.position.y = sin(phase * 2) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if taken or (requires_puzzle and not GameEvents.puzzle_solved) or not body.is_in_group("player"):
		return
	if GameEvents.collect(fragment_id):
		taken = true
		$Visual.hide()
		$OmniLight3D.hide()
		$GPUParticles3D.emitting = true
		set_deferred("monitoring", false)
		await get_tree().create_timer(0.65).timeout
		queue_free()
