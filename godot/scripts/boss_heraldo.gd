extends Area3D
## Fase 7: Heraldo del Eclipse, jefe del Observatorio Estelar.
## Flota escudado sobre la cúpula y alterna ataques: salvas de orbes, ondas de resonancia y (desde la
## segunda fase) un barrido de sombra que hay que saltar o esquivar. Un pilar estelar cargado
## rompe su escudo al encenderse: el Heraldo desciende con el núcleo expuesto y un pulso de luz
## cercano le arranca uno de sus tres núcleos. Cada núcleo perdido acelera sus ataques.

signal defeated
signal phase_changed(phase: int)

const Orb = preload("res://scripts/light_orb.gd")
const Wave = preload("res://scripts/resonance_wave.gd")
const EXPOSE_TIME := 6.5
const PERIODS := [3.8, 3.2, 2.6]

@export var arena_center: Vector3 = Vector3.ZERO
@export var hover_height: float = 6.0
var health: int = 3
var state: String = "dormant"
var phase: int = 1
var attack_timer: float = 0.0
var windup: float = 0.0
var pending: String = ""
var last_attack: String = ""
var exposed_timer: float = 0.0
var hurt_this_exposure: bool = false
var damage_enabled: bool = true
var player: CharacterBody3D
var visual: Node3D
var corona: Node3D
var mask: Node3D
var shards: Array[Node3D] = []
var shield: MeshInstance3D
var shield_material: ShaderMaterial
var core_light: OmniLight3D
var sweep: MeshInstance3D
var sweep_time: float = 0.0
var sweep_angle: float = 0.0
var sweep_speed: float = 0.0
var sweep_hit: bool = false
var time: float = 0.0
var drift: float = 0.0
var active_pillar: Node
var last_status: Array = []


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 0
	collision_mask = 2
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	# Sin nivel que lo configure (vista previa, pruebas), la arena es la isla que lo contiene.
	if arena_center == Vector3.ZERO and get_parent() is Node3D:
		arena_center = (get_parent() as Node3D).global_position
	visual = get_node_or_null("Visual") as Node3D
	if visual:
		corona = visual.find_child("HeraldoCorona", true, false) as Node3D
		mask = visual.find_child("HeraldoMask", true, false) as Node3D
		for i in 6:
			var shard := visual.find_child("HeraldoShard_%d" % i, true, false) as Node3D
			if shard: shards.append(shard)
	damage_enabled = not ("--qa" in OS.get_cmdline_user_args()) or "--qa-polish" in OS.get_cmdline_user_args()
	shield = MeshInstance3D.new()
	shield.name = "Shield"
	var sphere := SphereMesh.new()
	sphere.radius = 2.7
	sphere.height = 5.4
	shield.mesh = sphere
	shield_material = ShaderMaterial.new()
	shield_material.shader = load("res://shaders/eclipse_shield.gdshader")
	shield.material_override = shield_material
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)
	core_light = OmniLight3D.new()
	core_light.name = "CoreLight"
	core_light.light_color = Color("ff9a5a")
	core_light.light_energy = 1.5
	core_light.omni_range = 9.0
	add_child(core_light)
	sweep = MeshInstance3D.new()
	sweep.name = "ShadowSweep"
	var bar := BoxMesh.new()
	bar.size = Vector3(0.35, 0.35, 12.0)
	sweep.mesh = bar
	var sweep_material := StandardMaterial3D.new()
	sweep_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sweep_material.albedo_color = Color("ff8a4a")
	sweep_material.emission_enabled = true
	sweep_material.emission = Color("ff6a2a")
	sweep_material.emission_energy_multiplier = 3.0
	sweep.material_override = sweep_material
	sweep.top_level = true
	sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sweep.hide()
	add_child(sweep)
	GameEvents.pulse_requested.connect(apply_pulse)
	for pillar in get_tree().get_nodes_in_group("star_pillar"):
		pillar.fired.connect(_on_pillar_fired)
	if GameEvents.purified_ids.has(str(name)):
		state = "purified"
		visible = false
		monitoring = false


func is_threat() -> bool:
	return state in ["fighting", "exposed"] and is_instance_valid(player) and not player.locked


func core_position() -> Vector3:
	return global_position


func start_fight() -> void:
	if state != "dormant": return
	state = "fighting"
	phase = 1
	attack_timer = 2.4
	GameEvents.boss_title = "HERALDO DEL ECLIPSE"
	_charge_pillar()
	_status()


func _charge_pillar() -> void:
	var pillars := get_tree().get_nodes_in_group("star_pillar")
	var candidates: Array = pillars.filter(func(p: Node) -> bool: return p.state == "dormant")
	if candidates.is_empty():
		for p in pillars:
			if p.state != "charged": p.reset()
		candidates = pillars.filter(func(p: Node) -> bool: return p.state == "dormant")
	if candidates.is_empty(): return
	var nearest: Node = candidates[0]
	if is_instance_valid(player):
		# El pilar más lejano obliga a recorrer la cúpula esquivando ataques.
		var best := -1.0
		for p in candidates:
			var distance: float = p.global_position.distance_to(player.global_position)
			if distance > best:
				best = distance
				nearest = p
	active_pillar = nearest
	active_pillar.charge()


func _on_pillar_fired(pillar: Node) -> void:
	if state != "fighting" or pillar != active_pillar:
		pillar.reset()
		return
	pillar.shoot(core_position(), 1.0)
	_expose()


func _expose() -> void:
	state = "exposed"
	exposed_timer = EXPOSE_TIME
	hurt_this_exposure = false
	windup = 0.0
	pending = ""
	_stop_sweep()
	GameEvents.sound_requested.emit("shield_break")
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: shield_material.set_shader_parameter("strength", v), 1.0, 0.0, 0.5)
	_status()


func _recover() -> void:
	state = "fighting"
	attack_timer = 2.2
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: shield_material.set_shader_parameter("strength", v), 0.0, 1.0, 0.8)
	if is_instance_valid(active_pillar):
		if hurt_this_exposure: active_pillar.spend()
		else: active_pillar.reset()
	_charge_pillar()
	_status()


func apply_pulse(origin: Vector3, radius: float, _force: float) -> void:
	if state != "exposed" or hurt_this_exposure: return
	if origin.distance_to(core_position()) > radius + 1.3: return
	hurt_this_exposure = true
	health -= 1
	GameEvents.sound_requested.emit("enemy_hit")
	GameEvents.sound_requested.emit("heraldo_roar")
	core_light.light_energy = 9.0
	if health <= 0:
		_purify()
		return
	phase = 4 - health
	phase_changed.emit(phase)
	GameEvents.toast_requested.emit("El Heraldo pierde un núcleo · quedan %d" % health)
	GameEvents.sound_requested.emit("heraldo_phase")
	exposed_timer = minf(exposed_timer, 1.0)
	_status()


func _purify() -> void:
	state = "purified"
	monitoring = false
	_stop_sweep()
	windup = 0.0
	for orb in get_tree().get_nodes_in_group("enemy_orb"): orb.pop(false)
	for wave in get_tree().get_nodes_in_group("resonance_wave"): wave.queue_free()
	GameEvents.guardian_changed.emit(false, 0, "")
	GameEvents.register_enemy_purified(name)
	GameEvents.sound_requested.emit("heraldo_phase")
	defeated.emit()


func _status() -> void:
	var caption := "ESCUDO DEL ECLIPSE"
	match state:
		"exposed": caption = "NÚCLEO EXPUESTO · ¡PULSO!"
		"fighting":
			if pending == "volley": caption = "CARGANDO ORBES"
			elif pending == "wave": caption = "CARGANDO ONDA"
			elif pending == "sweep" or sweep_time > 0.0: caption = "BARRIDO DE SOMBRA"
			elif is_instance_valid(active_pillar) and active_pillar.state == "charged": caption = "UN PILAR ESTELAR BRILLA"
	var status := [state in ["fighting", "exposed"], health, caption]
	if status != last_status:
		last_status = status
		GameEvents.guardian_changed.emit(status[0], health, caption)


func _physics_process(delta: float) -> void:
	time += delta
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	# Pause the whole encounter, including movement, while control belongs to a modal.
	if is_instance_valid(player) and player.locked:
		_animate(delta)
		return
	match state:
		"fighting": _fight(delta)
		"exposed":
			if not (is_instance_valid(player) and player.locked):
				exposed_timer -= delta
				if exposed_timer <= 0.0: _recover()
	_move(delta)
	_animate(delta)
	_update_sweep(delta)
	if state in ["fighting", "exposed"]: _status()


func _move(delta: float) -> void:
	if state == "purified": return
	drift += delta * (0.25 + phase * 0.05)
	var target := arena_center + Vector3(cos(drift) * 3.0, hover_height + sin(time * 1.3) * 0.3, sin(drift) * 3.0)
	if state == "exposed":
		target = arena_center + Vector3(cos(drift) * 2.2, 1.6, sin(drift) * 2.2 + 2.5)
	elif state == "dormant":
		target = arena_center + Vector3(0, hover_height + sin(time) * 0.2, 0)
	global_position = global_position.lerp(target, 1.0 - exp(-delta * (3.0 if state == "exposed" else 1.2)))


func _fight(delta: float) -> void:
	if not is_instance_valid(player) or player.locked: return
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_execute(pending)
			pending = ""
		return
	if sweep_time > 0.0: return
	attack_timer -= delta
	if attack_timer > 0.0: return
	var options: Array[String] = ["volley", "wave"]
	if phase >= 2: options.append("sweep")
	options.erase(last_attack)
	pending = options[randi() % options.size()]
	last_attack = pending
	windup = 0.95 if phase < 3 else 0.75
	attack_timer = PERIODS[clampi(phase - 1, 0, 2)]
	GameEvents.sound_requested.emit("guardian_charge" if pending != "volley" else "vigia_charge")


func _execute(kind: String) -> void:
	var ground := Vector3(global_position.x, arena_center.y, global_position.z)
	match kind:
		"volley":
			var count: int = [3, 5, 7][clampi(phase - 1, 0, 2)]
			var origin := core_position()
			var aim := (player.global_position + Vector3.UP * 0.9 - origin).normalized()
			GameEvents.sound_requested.emit("vigia_shot")
			for i in count:
				var orb := Orb.new()
				orb.damage_enabled = damage_enabled
				orb.speed = 5.6
				orb.homing = 0.55
				orb.reason = "Un orbe del Heraldo alcanzó tu luz"
				get_tree().current_scene.add_child(orb)
				orb.launch(origin + aim * 1.2, aim.rotated(Vector3.UP, (i - (count - 1) * 0.5) * 0.22))
		"wave":
			var wave := Wave.new()
			wave.damage_enabled = damage_enabled
			wave.speed = [5.0, 6.0, 7.0][clampi(phase - 1, 0, 2)]
			wave.max_radius = 13.0
			wave.damage = 24.0
			get_tree().current_scene.add_child(wave)
			wave.global_position = ground
			GameEvents.sound_requested.emit("guardian_wave")
		"sweep":
			var to_player := player.global_position - ground
			sweep_angle = atan2(to_player.x, to_player.z) - PI * 0.6
			sweep_speed = (PI * 1.2) / (3.0 if phase < 3 else 2.4)
			sweep_time = 3.0 if phase < 3 else 2.4
			sweep_hit = false
			sweep.show()
			GameEvents.sound_requested.emit("heraldo_laser")


func _update_sweep(delta: float) -> void:
	if sweep_time <= 0.0:
		return
	if is_instance_valid(player) and player.locked:
		return
	sweep_time -= delta
	sweep_angle += sweep_speed * delta
	var pivot := Vector3(global_position.x, arena_center.y + 0.45, global_position.z)
	var direction := Vector3(sin(sweep_angle), 0, cos(sweep_angle))
	sweep.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), pivot + direction * 6.0)
	if not sweep_hit and damage_enabled and is_instance_valid(player):
		var offset := player.global_position - pivot
		var height := player.global_position.y - arena_center.y
		var flat := Vector3(offset.x, 0, offset.z)
		var along := flat.dot(direction)
		var across := (flat - direction * along).length()
		if along > 0.0 and along < 12.0 and across < 0.55 and height < 0.7:
			sweep_hit = true
			if GameEvents.damage_player(26.0, "El barrido del Heraldo te alcanzó"):
				GameEvents.sound_requested.emit("hit")
	if sweep_time <= 0.0: _stop_sweep()


func _stop_sweep() -> void:
	sweep_time = 0.0
	if sweep: sweep.hide()


func _animate(delta: float) -> void:
	if not visual: return
	if is_instance_valid(player) and state != "purified":
		var to_player := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to_player.x, to_player.z), 1.0 - exp(-delta * 3.0))
	if corona: corona.rotation.z += delta * (0.4 + (2.5 if windup > 0.0 else 0.0) + phase * 0.2)
	for i in shards.size():
		var angle := TAU * i / shards.size() + time * (0.5 + phase * 0.15)
		var radius := 1.8 + sin(time * 2.0 + i) * 0.12 + (0.9 if state == "exposed" else 0.0)
		shards[i].position = Vector3(cos(angle) * radius, sin(angle) * radius, -0.6)
	var glow_target := 1.5 + (4.0 if windup > 0.0 else 0.0) + (3.0 if state == "exposed" else 0.0)
	core_light.light_energy = lerpf(core_light.light_energy, glow_target, 1.0 - exp(-delta * 4.0))
	if mask: mask.position.y = sin(time * 3.0) * 0.03
