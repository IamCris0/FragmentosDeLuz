extends CharacterBody3D

@export var speed: float = 3.1
@export var sprint_speed: float = 5.4
@export var jump_velocity: float = 6.3
var gravity: float = 18.0
var locked: bool = false
var target: Node3D
var coyote: float = 0.0
var jump_buffer: float = 0.0
var step_time: float = 0.0
var interact_time: float = 0.0
var animator: AnimationPlayer
var playback: AnimationNodeStateMachinePlayback
var animation_names: Dictionary = {}
var sensitivity: float = 0.003
var camera_drag: bool = false
var land_time: float = 0.0
var current_animation: String = ""
var animation_speed: AnimationNodeTimeScale
var pulse_cooldown: float = 0.0
var pulse_time: float = 0.0
var hurt_time: float = 0.0
var regeneration_delay: float = 0.0
const PULSE_COOLDOWN := 2.4
const PULSE_COST := 18.0
const DODGE_COST := 12.0
const DODGE_COOLDOWN := 1.4
const DODGE_DURATION := 0.5
var dodge_time: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD
## Estado de animación forzado por las cinemáticas ("" = automático).
var cinematic_state: String = ""
## Evita que la misma pulsación que cierra un diálogo vuelva a abrirlo.
var interaction_lock: float = 0.0
const PAD_CAMERA_SPEED := 2.6
# --- Fase 7: doble salto, planeo, nova y corrientes de viento -----------------------------------
const NOVA_COST := 30.0
const NOVA_CHARGE := 0.6
const NOVA_FULL := 0.95
const GLIDE_FALL := 2.1
const GLIDE_SPEED := 5.0
var air_jumps: int = 0
var gliding: bool = false
var glide_time: float = 0.0
var pulse_charging: bool = false
var pulse_charge: float = 0.0
## Zonas de viento (scripts/wind_zone.gd) que contienen ahora mismo al jugador.
var wind_zones: Array[Node] = []
var wings: Node3D
var wings_amount: float = 0.0
var charge_glow: OmniLight3D

@onready var visual: Node3D = $Visual
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var animation_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	add_to_group("player")
	arm.add_excluded_object(get_rid())
	_setup_animation()
	GameEvents.player_hit.connect(_on_player_hit)
	GameEvents.player_depleted.connect(respawn)
	_build_wings()
	charge_glow = OmniLight3D.new()
	charge_glow.name = "NovaGlow"
	charge_glow.light_color = Color("ffd98a")
	charge_glow.omni_range = 3.0
	charge_glow.light_energy = 0.0
	charge_glow.position = Vector3(0, 1.1, 0)
	add_child(charge_glow)


func _setup_animation() -> void:
	animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animator:
		push_error("El personaje no contiene AnimationPlayer")
		return
	var machine := AnimationNodeStateMachine.new()
	for state in ["idle", "walk", "run", "jump", "interact", "fall", "land", "wave", "pulse", "hurt", "dodge"]:
		for imported_name in animator.get_animation_list():
			if state in str(imported_name).to_lower():
				animation_names[state] = imported_name
				var clip := AnimationNodeAnimation.new()
				clip.animation = imported_name
				machine.add_node(state, clip, Vector2(animation_names.size() * 180, 0))
				animator.get_animation(imported_name).loop_mode = Animation.LOOP_LINEAR if state in ["idle", "walk", "run", "fall"] else Animation.LOOP_NONE
				break
	for source in animation_names:
		for destination in animation_names:
			if source != destination:
				var transition := AnimationNodeStateMachineTransition.new()
				transition.xfade_time = 0.06 if destination == "dodge" else 0.16
				machine.add_transition(source, destination, transition)
	animation_tree.anim_player = animation_tree.get_path_to(animator)
	var blend:=AnimationNodeBlendTree.new()
	blend.add_node("Locomotion",machine)
	animation_speed=AnimationNodeTimeScale.new()
	blend.add_node("Cadence",animation_speed)
	blend.connect_node("Cadence",0,"Locomotion")
	blend.connect_node("output",0,"Cadence")
	animation_tree.tree_root = blend
	animation_tree.active = true
	playback = animation_tree.get("parameters/Locomotion/playback")
	if animation_names.has("idle"):
		playback.start("idle")


## Alas de luz que aparecen al planear (dos láminas con degradado aditivo).
func _build_wings() -> void:
	wings = Node3D.new()
	wings.name = "LightWings"
	wings.position = Vector3(0, 1.28, -0.12)
	visual.add_child(wings)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/light_wing.gdshader") if ResourceLoader.exists("res://shaders/light_wing.gdshader") else null
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		wing.name = "Wing" + ("L" if side < 0 else "R")
		var quad := QuadMesh.new()
		quad.size = Vector2(1.25, 0.72)
		quad.center_offset = Vector3(0.62 * side, 0, 0)
		wing.mesh = quad
		wing.rotation = Vector3(0, side * -0.35, side * -0.22)
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if material.shader:
			var own := material.duplicate() as ShaderMaterial
			own.set_shader_parameter("side", side)
			wing.material_override = own
		wings.add_child(wing)
	wings.scale = Vector3.ONE * 0.01
	wings.hide()


func _physics_process(delta: float) -> void:
	coyote = 0.12 if is_on_floor() else maxf(coyote - delta, 0)
	jump_buffer = maxf(jump_buffer - delta, 0)
	interact_time = maxf(interact_time - delta, 0)
	land_time=maxf(land_time-delta,0.)
	pulse_time=maxf(pulse_time-delta,0.)
	hurt_time=maxf(hurt_time-delta,0.)
	regeneration_delay=maxf(regeneration_delay-delta,0.)
	pulse_cooldown=maxf(pulse_cooldown-delta,0.)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	dodge_time = maxf(dodge_time - delta, 0.0)
	if is_on_floor(): air_jumps = 0
	if locked:
		dodge_time = 0.0
		jump_buffer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		gliding = false
		pulse_charging = false
		pulse_charge = 0.0
	var was_grounded: bool=is_on_floor()
	var fall_speed: float=velocity.y
	var wind := _wind_forces()
	var axes := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = pivot.global_basis * Vector3(axes.x, 0, axes.y)
	direction.y = 0
	direction = direction.normalized()
	if not locked and Input.is_action_just_pressed("dodge"):
		try_dodge(direction)
	var dodging: bool = dodge_time > 0.0
	# Planeo: mantener saltar en el aire mientras se desciende (habilidad de historia "glide").
	var wants_glide: bool = not locked and not dodging and not is_on_floor() and GameEvents.has_skill("glide") and Input.is_action_pressed("jump") and interaction_lock <= 0.0
	var was_gliding := gliding
	gliding = wants_glide and (velocity.y < 0.6 or gliding or wind.y > 0.0)
	if gliding and not was_gliding:
		glide_time = 0.0
		GameEvents.sound_requested.emit("glide")
	if gliding: glide_time += delta
	if not is_on_floor():
		var lift: float = wind.y
		if gliding:
			velocity.y -= gravity * 0.22 * delta
			var fall_limit: float = -(GLIDE_FALL * (0.65 if GameEvents.has_skill("serene_glide") else 1.0))
			if lift > 0.0:
				velocity.y = move_toward(velocity.y, lift, 16.0 * delta)
			else:
				velocity.y = maxf(velocity.y, fall_limit)
		else:
			velocity.y -= gravity * delta * (0.55 if lift > 0.0 else 1.0)
	var sprinting: bool = not locked and not dodging and not gliding and Input.is_action_pressed("sprint") and GameEvents.energy > 1 and axes.length() > 0.1
	var current_speed: float = sprint_speed if sprinting else speed
	if gliding:
		current_speed = GLIDE_SPEED * (1.2 if GameEvents.has_skill("serene_glide") else 1.0)
		if direction.length() < 0.1:
			direction = visual.global_basis.z * 0.55
	var accel: float = 24.0 if not gliding else 9.0
	velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta)
	velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta)
	if not is_on_floor():
		velocity.x += wind.x * delta * (1.0 if gliding else 0.45)
		velocity.z += wind.z * delta * (1.0 if gliding else 0.45)
	if dodging:
		var roll_speed := lerpf(3.0, 8.5, dodge_time / DODGE_DURATION)
		velocity.x = dodge_direction.x * roll_speed
		velocity.z = dodge_direction.z * roll_speed
		direction = dodge_direction
	if not locked and not dodging and interaction_lock <= 0.0 and Input.is_action_just_pressed("jump"):
		if coyote <= 0.0 and not is_on_floor() and GameEvents.has_skill("double_jump") and air_jumps == 0:
			air_jumps = 1
			velocity.y = jump_velocity * 0.92
			gliding = false
			GameEvents.sound_requested.emit("double_jump")
			_air_burst()
		else:
			jump_buffer = 0.14
	if jump_buffer > 0 and coyote > 0:
		velocity.y = jump_velocity
		jump_buffer = 0
		coyote = 0
		GameEvents.sound_requested.emit("jump")
	_handle_pulse(delta, dodging)
	if direction.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(1, delta * (12 if not gliding else 5)))
	move_and_slide()
	if is_on_floor() and not was_grounded and fall_speed < -3.:
		land_time=.32
		GameEvents.sound_requested.emit("land")
	if is_on_floor(): gliding = false
	if not locked:
		if sprinting:
			GameEvents.set_energy(GameEvents.energy - delta * GameEvents.sprint_drain())
			regeneration_delay = maxf(regeneration_delay, 0.65)
		elif regeneration_delay <= 0.0 and not pulse_charging:
			GameEvents.set_energy(GameEvents.energy + delta * GameEvents.regen_rate())
	var state: String = "idle"
	if dodging: state = "dodge"
	elif hurt_time > 0: state = "hurt"
	elif pulse_time > 0 or pulse_charging: state = "pulse"
	elif gliding: state = "fall"
	elif not is_on_floor(): state = "jump" if velocity.y>0 else "fall"
	elif land_time>0. and direction.length()<.1: state="land"
	elif interact_time > 0: state = "interact"
	elif direction.length() > 0.1: state = "run" if sprinting else "walk"
	if cinematic_state != "" and animation_names.has(cinematic_state): state = cinematic_state
	if playback and animation_names.has(state) and state!=current_animation:
		playback.travel(state)
		current_animation=state
	var horizontal_speed: float=Vector2(velocity.x,velocity.z).length()
	animation_tree.set("parameters/Cadence/scale",clampf(horizontal_speed/2.5,.6,1.6) if state=="walk" else (clampf(horizontal_speed/5.4,.6,1.5) if state=="run" else (0.45 if gliding else 1.)))
	camera.fov=lerpf(camera.fov,(72. if gliding else (69. if sprinting else 65.)),1.-exp(-delta*4.))
	_update_wings(delta)
	if is_on_floor() and not dodging and direction.length() > 0.1:
		step_time += delta
		if step_time > (0.29 if sprinting else 0.33):
			step_time = 0
			GameEvents.sound_requested.emit("step")
	if global_position.y < _fall_limit():
		respawn()
	var cooldown_total: float = GameEvents.pulse_cooldown()
	GameEvents.set_pulse_ready(1.0 - pulse_cooldown / cooldown_total, pulse_cooldown <= 0.0 and GameEvents.energy >= PULSE_COST)
	GameEvents.dodge_changed.emit(1.0 - dodge_cooldown / GameEvents.dodge_cooldown(), dodge_cooldown <= 0.0 and GameEvents.energy >= GameEvents.dodge_cost())
	_pad_camera(delta)
	_find_interaction()
	interaction_lock = maxf(interaction_lock - delta, 0.0)
	if not locked and not dodging and interaction_lock <= 0.0 and Input.is_action_just_pressed("interact") and is_instance_valid(target):
		interact_time = 0.7
		target.interact(self)


## Altura de caída que devuelve al refugio; los niveles pueden definir la suya (fall_limit).
func _fall_limit() -> float:
	var scene := get_tree().current_scene
	if scene and "fall_limit" in scene: return float(scene.fall_limit)
	return -15.0


func _wind_forces() -> Vector3:
	var total := Vector3.ZERO
	for zone in wind_zones:
		if is_instance_valid(zone) and zone.has_method("force_for"):
			total += zone.force_for(self)
	return total


func _handle_pulse(delta: float, dodging: bool) -> void:
	var nova_skill := GameEvents.has_skill("pulse_nova")
	if locked or dodging:
		pulse_charging = false
		pulse_charge = 0.0
		charge_glow.light_energy = 0.0
		return
	if Input.is_action_just_pressed("light_pulse"):
		if pulse_cooldown <= 0.0 and GameEvents.energy >= PULSE_COST:
			if nova_skill:
				pulse_charging = true
				pulse_charge = 0.0
			else:
				_fire_pulse(false)
		elif pulse_cooldown > 0.0:
			GameEvents.toast_requested.emit("El escáner aún está recargando")
		else:
			GameEvents.toast_requested.emit("Necesitas energía para emitir un pulso")
	if pulse_charging:
		pulse_charge += delta
		charge_glow.light_energy = clampf(pulse_charge / NOVA_FULL, 0.0, 1.0) * 3.0
		var released := not Input.is_action_pressed("light_pulse")
		if released or pulse_charge >= NOVA_FULL:
			pulse_charging = false
			var nova := pulse_charge >= NOVA_CHARGE and GameEvents.energy >= NOVA_COST
			charge_glow.light_energy = 0.0
			pulse_charge = 0.0
			if not nova and GameEvents.energy < PULSE_COST:
				GameEvents.toast_requested.emit("Necesitas energía para emitir un pulso")
			else:
				_fire_pulse(nova)


func _fire_pulse(nova: bool) -> void:
	var cost: float = NOVA_COST if nova else PULSE_COST
	pulse_cooldown = GameEvents.pulse_cooldown() * (1.3 if nova else 1.0)
	pulse_time = 0.48
	GameEvents.set_energy(GameEvents.energy - cost)
	regeneration_delay = maxf(regeneration_delay, 1.0)
	var radius: float = GameEvents.pulse_radius() * (1.5 if nova else 1.0)
	GameEvents.request_pulse(global_position + Vector3.UP * 0.85, radius, 1.55 if not nova else 2.4, 2 if nova else 1)
	GameEvents.sound_requested.emit("nova" if nova else "pulse")
	if GameEvents.tutorial_stage < 2 and GameEvents.level == "auralia":
		GameEvents.set_tutorial(2, "Pulso liberado. Q aturde ecos cercanos, pero consume energía.")


func _update_wings(delta: float) -> void:
	if not wings: return
	wings_amount = move_toward(wings_amount, 1.0 if gliding else 0.0, delta * (5.0 if gliding else 3.0))
	wings.visible = wings_amount > 0.01
	if wings.visible:
		var flap := sin(glide_time * 5.0) * 0.06
		wings.scale = Vector3.ONE * maxf(wings_amount, 0.01)
		for wing in wings.get_children():
			var side: float = -1.0 if wing.name == "WingL" else 1.0
			wing.rotation.z = side * (-0.22 + flap)


func _air_burst() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "AirJumpRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.6, 1.0, 0.92, 0.85)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.1
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(2.4, 1, 2.4), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)


func try_dodge(direction: Vector3) -> bool:
	var cost: float = GameEvents.dodge_cost()
	if locked or not is_on_floor() or dodge_cooldown > 0.0 or hurt_time > 0.0 or GameEvents.energy < cost:
		return false
	dodge_direction = direction if direction.length() > 0.1 else visual.global_basis.z
	dodge_direction.y = 0.0
	dodge_direction = dodge_direction.normalized()
	visual.rotation.y = atan2(dodge_direction.x, dodge_direction.z)
	dodge_time = DODGE_DURATION
	dodge_cooldown = GameEvents.dodge_cooldown()
	pulse_time = 0.0
	pulse_charging = false
	jump_buffer = 0.0
	interact_time = 0.0
	regeneration_delay = maxf(regeneration_delay, 0.85)
	GameEvents.damage_grace = maxf(GameEvents.damage_grace, 0.30)
	GameEvents.set_energy(GameEvents.energy - cost)
	GameEvents.dodge_started.emit(global_position, dodge_direction)
	GameEvents.sound_requested.emit("dodge")
	return true


func _find_interaction() -> void:
	target = null
	var closest: float = 2.5
	if locked: return
	for item in get_tree().get_nodes_in_group("interactable"):
		if not item.available(): continue
		var distance_to_item: float = global_position.distance_to(item.global_position)
		if distance_to_item < closest:
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, item.global_position + Vector3.UP * 0.6)
			query.exclude = [get_rid()]
			var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if obstruction.is_empty() or obstruction.get("collider") == item or item.is_ancestor_of(obstruction.get("collider")):
				closest = distance_to_item
				target = item


## Cámara con el stick derecho del mando (fase 6). Respeta sensibilidad e inversión de Preferences.
func _pad_camera(delta: float) -> void:
	if locked or not InputMap.has_action("camera_left"):
		return
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look.length() < 0.01:
		return
	var invert: float = -1.0 if Preferences.invert_y else 1.0
	pivot.rotation.y -= look.x * PAD_CAMERA_SPEED * Preferences.camera_sensitivity * delta
	arm.rotation.x = clampf(arm.rotation.x - look.y * invert * PAD_CAMERA_SPEED * 0.6 * Preferences.camera_sensitivity * delta, -0.85, 0.15)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		camera_drag = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if camera_drag and not locked else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and camera_drag and not locked:
		var invert: float = -1.0 if Preferences.invert_y else 1.0
		pivot.rotation.y -= event.relative.x * sensitivity * Preferences.camera_sensitivity
		arm.rotation.x = clampf(arm.rotation.x - event.relative.y * invert * sensitivity * Preferences.camera_sensitivity, -0.85, 0.15)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: arm.spring_length = maxf(3, arm.spring_length - 0.4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: arm.spring_length = minf(7, arm.spring_length + 0.4)


func respawn() -> void:
	dodge_time = 0.0
	dodge_cooldown = 0.0
	global_position = GameEvents.checkpoint
	velocity = Vector3.ZERO
	gliding = false
	air_jumps = 0
	pulse_charging = false
	pulse_charge = 0.0
	charge_glow.light_energy = 0.0
	GameEvents.damage_grace = 2.5
	GameEvents.set_energy(maxf(GameEvents.energy, 60.0))
	regeneration_delay = 0.0
	pulse_cooldown = 0.0
	hurt_time = 0.0
	pulse_time = 0.0
	GameEvents.toast_requested.emit("La luz te devuelve al último refugio")
	GameEvents.sound_requested.emit("respawn")
	land_time=0.
	camera_drag=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE


func _on_player_hit(_amount: float, _reason: String) -> void:
	dodge_time = 0.0
	hurt_time = 0.34
	pulse_time = 0.0
	pulse_charging = false
	pulse_charge = 0.0
	charge_glow.light_energy = 0.0
	gliding = false
	regeneration_delay = GameEvents.hit_regen_delay()
