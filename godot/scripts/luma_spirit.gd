extends Node3D
## Animación procedural de Luma (modelo luma_spirit.glb): flotación, aleteo, parpadeo,
## mirada hacia Neri y gestos al hablar. No necesita esqueleto ni AnimationPlayer.

@export var look_at_player: bool = true
@export var talk_energy: float = 0.0

var time: float = 0.0
var float_node: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var arm_rest: Array[Vector3] = []
var eyes: Array[Node3D] = []
var leaf: Node3D
var leaf_rest: Vector3
var blink_clock: float = 2.5
var blink_time: float = 0.0
var greet_time: float = 0.0
var greeted: bool = false
var player: Node3D
var eye_materials: Array[StandardMaterial3D] = []
var rim_material: ShaderMaterial


func _ready() -> void:
	float_node = find_child("Luma_Float", true, false)
	head = find_child("Luma_HeadPivot", true, false)
	leaf = find_child("Luma_LeafPivot", true, false)
	if leaf: leaf_rest = leaf.rotation
	for side in ["L", "R"]:
		var arm: Node3D = find_child("Luma_Arm_" + side, true, false)
		if arm:
			arms.append(arm)
			arm_rest.append(arm.rotation)
		var eye: Node3D = find_child("Luma_EyePivot_" + side, true, false)
		if eye: eyes.append(eye)
		var eye_mesh: MeshInstance3D = find_child("Luma_Eye_" + side, true, false)
		if eye_mesh and eye_mesh.mesh:
			var source := eye_mesh.mesh.surface_get_material(0) as StandardMaterial3D
			if source:
				var copy := source.duplicate() as StandardMaterial3D
				eye_mesh.set_surface_override_material(0, copy)
				eye_materials.append(copy)
	var shell: MeshInstance3D = find_child("Luma_Head", true, false)
	if shell and ResourceLoader.exists("res://shaders/spirit_rim.gdshader"):
		rim_material = ShaderMaterial.new()
		rim_material.shader = load("res://shaders/spirit_rim.gdshader")
		shell.set_surface_override_material(0, rim_material)
	for piece in find_children("*", "GeometryInstance3D", true, false):
		(piece as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if piece.name.begins_with("Luma_Trim") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if get_node_or_null("/root/GameEvents"):
		GameEvents.story_requested.connect(_on_story)
	time = randf() * 10.0


func _on_story(speaker: String, _text: String) -> void:
	if "LUMA" in speaker.to_upper():
		talk_energy = 1.0


func greet() -> void:
	greet_time = 1.6


func _process(delta: float) -> void:
	time += delta
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	var speaking := talk_energy > 0.0
	var hud: Node = get_tree().current_scene.get_node_or_null("HUDLayer") if get_tree().current_scene else null
	if hud and hud.get("dialog_open") and speaking:
		talk_energy = 1.0
	else:
		talk_energy = maxf(0.0, talk_energy - delta * 0.6)
	if is_instance_valid(player) and not greeted and global_position.distance_to(player.global_position) < 6.0:
		greeted = true
		greet()
	elif is_instance_valid(player) and global_position.distance_to(player.global_position) > 9.0:
		greeted = false
	greet_time = maxf(0.0, greet_time - delta)
	var excite := maxf(talk_energy, greet_time / 1.6)
	if float_node:
		float_node.position.y = sin(time * 1.35) * 0.06 + excite * 0.05 * sin(time * 6.0)
		float_node.rotation.z = sin(time * 0.9) * 0.035
		float_node.rotation.x = sin(time * 0.7 + 1.0) * 0.025
		float_node.rotation.y = TAU * smoothstep(0.0, 1.0, 1.0 - greet_time / 1.6) if greet_time > 0.0 else 0.0
	for i in arms.size():
		var side := -1.0 if i == 0 else 1.0
		var flap := sin(time * (2.2 + excite * 5.5) + i * 0.4) * (0.16 + excite * 0.3)
		arms[i].rotation = arm_rest[i] + Vector3(sin(time * 1.1 + i) * 0.08, flap * side, 0)
	if leaf:
		leaf.rotation = leaf_rest + Vector3(sin(time * 1.3) * 0.08, 0, sin(time * 1.7) * 0.16)
	if head:
		var yaw := 0.0
		if look_at_player and is_instance_valid(player):
			var local := global_transform.affine_inverse() * player.global_position
			if local.length() < 12.0:
				yaw = clampf(atan2(local.x, local.z), -0.75, 0.75)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, 1.0 - exp(-delta * 3.0))
		head.rotation.z = sin(time * 0.8) * 0.06 + (sin(time * 9.0) * 0.04 * talk_energy)
		head.rotation.x = sin(time * 0.6) * 0.03
	blink_clock -= delta
	if blink_clock <= 0.0:
		blink_clock = randf_range(2.2, 5.0)
		blink_time = 0.14
	blink_time = maxf(0.0, blink_time - delta)
	var lid := 0.12 if blink_time > 0.0 else 1.0
	for eye in eyes:
		eye.scale = Vector3(1, 1, lerpf(eye.scale.z, lid, 1.0 - exp(-delta * 40.0)))
	var glow := 3.2 + talk_energy * (1.2 + sin(time * 14.0) * 1.0)
	for material in eye_materials:
		material.emission_energy_multiplier = glow
	if rim_material:
		rim_material.set_shader_parameter("pulse", 0.5 + 0.5 * sin(time * 2.0) + excite * 0.6)
