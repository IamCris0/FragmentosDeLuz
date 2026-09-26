extends AnimatableBody3D
## Fase 7: nube de piedra frágil. Tiembla al pisarla, cae y reaparece unos segundos después.

@export var delay: float = 0.9
@export var respawn_time: float = 4.0
@export var sensor_size: Vector3 = Vector3(3.6, 0.6, 3.6)
var state: String = "idle"
var timer: float = 0.0
var visual: Node3D
var shape: CollisionShape3D
var sensor: Area3D
var fall_tween: Tween


func _ready() -> void:
	add_to_group("crumble_platform")
	visual = get_node_or_null("Visual") as Node3D
	shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	sensor = Area3D.new()
	sensor.name = "Sensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var box := CollisionShape3D.new()
	var extents := BoxShape3D.new()
	extents.size = sensor_size
	box.shape = extents
	box.position.y = sensor_size.y * 0.5
	sensor.add_child(box)
	add_child(sensor)
	sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if state != "idle" or not body.is_in_group("player"): return
	state = "shaking"
	timer = delay
	GameEvents.sound_requested.emit("crumble")


func _physics_process(delta: float) -> void:
	match state:
		"shaking":
			timer -= delta
			if visual: visual.position = Vector3(randf_range(-0.06, 0.06), randf_range(-0.03, 0.0), randf_range(-0.06, 0.06))
			if timer <= 0.0: _fall()
		"fallen":
			timer -= delta
			if timer <= 0.0: _restore()


func _fall() -> void:
	state = "fallen"
	timer = respawn_time
	if shape: shape.set_deferred("disabled", true)
	if not visual: return
	if fall_tween: fall_tween.kill()
	fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(visual, "position:y", -7.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(visual, "scale", Vector3.ONE * 0.4, 1.2)
	fall_tween.chain().tween_callback(visual.hide)


func _restore() -> void:
	state = "idle"
	if shape: shape.set_deferred("disabled", false)
	if not visual: return
	if fall_tween: fall_tween.kill()
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE * 0.05
	visual.show()
	fall_tween = create_tween()
	fall_tween.tween_property(visual, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
