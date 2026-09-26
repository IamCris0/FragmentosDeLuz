extends StaticBody3D
## Fase 7: puerta de cristal (o puente de luz) ligada a una bandera del nivel.
## Puerta: se disuelve y deja pasar. Puente (bridge = true): aparece y se vuelve sólido.

@export var flag: String = ""
@export var bridge: bool = false
@export var tint: Color = Color(0.55, 0.38, 1.0)
var open: bool = false
var material: ShaderMaterial


func _ready() -> void:
	add_to_group("crystal_door")
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		material = ShaderMaterial.new()
		material.shader = load("res://shaders/barrier.gdshader")
		material.set_shader_parameter("tint", Vector3(tint.r * 0.4, tint.g * 0.4, tint.b * 0.5))
		material.set_shader_parameter("glow", Vector3(tint.r, tint.g, tint.b))
		mesh.material_override = material
	_apply(flag != "" and GameEvents.level_flag(flag), false)


func set_open(value: bool, animate: bool = true) -> void:
	if value == open: return
	_apply(value, animate)


func _apply(value: bool, animate: bool) -> void:
	open = value
	var solid := open if bridge else not open
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape: shape.set_deferred("disabled", not solid)
	if not material: return
	var visible_target := 1.0 if solid else 0.0
	if not animate:
		material.set_shader_parameter("fade", visible_target)
		visible = solid
		return
	visible = true
	GameEvents.sound_requested.emit("crystal_door" if not bridge else "gate_dissolve")
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("fade", v), 1.0 - visible_target, visible_target, 1.6).set_trans(Tween.TRANS_SINE)
	if not solid: tween.tween_callback(hide)
