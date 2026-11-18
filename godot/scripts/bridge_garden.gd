extends Node3D

const SCAN := "garden_lantern"
const OPEN := "garden_bridge"
const LAMP := Vector3(1.25, 0, -3.5)
const LENS := Vector3(-2.6, 0, -9)
var deck := Node3D.new()
var lens: Node3D
var sparks: Array[MeshInstance3D] = []
var channel := MeshInstance3D.new()
var glow := StandardMaterial3D.new()
var elapsed := 0.0
var restored := false

class Station extends Node3D:
	var caption: String
	var action: Callable
	var enabled := true

	func _ready() -> void:
		add_to_group("interactable")

	func current_prompt() -> String:
		return caption

	func available() -> bool:
		return enabled

	func interact(_player: Node3D) -> void:
		if enabled: action.call()

func _ready() -> void:
	add_child(deck)
	# The world builder places all first-bridge boxes directly below the world.
	for part in get_parent().get_children():
		if part is Node3D and part.has_node("Mesh") and absf(part.position.x) < 2.1 and part.position.z >= -22 and part.position.z <= -11:
			part.reparent(deck)
	restored = GameEvents.story_seen.has(OPEN) or GameEvents.checkpoint.z < -20 or GameEvents.puzzle_solved
	if restored: GameEvents.story_seen[OPEN] = true
	deck.position.y = 0 if restored else -5
	var lamp := station("Farol", LAMP, "Escanear el farol", scan)
	lamp.add_child(preload("res://assets/environment/sanctuary_lantern.glb").instantiate())
	lens = station("Lente", LENS, "Orientar la lente antigua", align_lens)
	lens.add_child(preload("res://assets/props/prism.glb").instantiate())
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("c89c53")
	brass.metallic = 0.6
	brass.roughness = 0.35
	for i in 2:
		var gimbal := MeshInstance3D.new()
		var rim := TorusMesh.new()
		rim.outer_radius = 0.70 + i * 0.09
		rim.inner_radius = rim.outer_radius - 0.045
		gimbal.mesh = rim
		gimbal.material_override = brass
		gimbal.position.y = 1.05
		gimbal.rotation = Vector3(PI * 0.5, i * PI * 0.38, 0)
		lens.add_child(gimbal)
	lens.rotation.y = 0 if restored else PI * 0.5
	var practice := station("Eco", Vector3(-2, 4, -65), "Escuchar a los faroleros", practice_wave)
	practice.add_child(preload("res://assets/props/beam_receptor.glb").instantiate())
	if GameEvents.story_seen.has("garden_guard_memory"): practice.caption = "Ensayar el salto de resonancia"
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd778") if restored else Color("5af2dc")
	var inlay := BoxMesh.new()
	inlay.size = Vector3(0.065, 0.025, LAMP.distance_to(LENS))
	channel.mesh = inlay
	channel.material_override = glow
	add_child(channel)
	channel.position = (LAMP + LENS) * 0.5 + Vector3.UP * 0.105
	channel.look_at(LENS + Vector3.UP * 0.105)
	var gem := SphereMesh.new()
	gem.radius = 0.065
	gem.height = 0.11
	for i in 18:
		var spark := MeshInstance3D.new()
		spark.mesh = gem
		spark.material_override = glow
		add_child(spark)
		spark.position = LAMP.lerp(LENS, i / 17.0) + Vector3.UP * (0.93 if i == 0 else 0.12)
		sparks.append(spark)
	refresh()

func station(id: String, at: Vector3, caption: String, action: Callable) -> Station:
	var point := Station.new()
	point.name = id
	point.position = at
	point.caption = caption
	point.action = action
	add_child(point)
	return point

func refresh() -> void:
	var scanned := GameEvents.story_seen.has(SCAN)
	channel.visible = scanned or restored
	$Farol.enabled = not scanned and not restored
	$Lente.enabled = not restored
	for i in sparks.size(): sparks[i].visible = i == 0 or scanned or restored

func _process(delta: float) -> void:
	elapsed += delta
	for i in sparks.size():
		sparks[i].scale = Vector3.ONE * (1.0 if restored else 1.15 + 0.65 * sin(elapsed * 4 - i * 0.7))

func scan() -> void:
	GameEvents.story_seen[SCAN] = true
	GameEvents.sound_requested.emit("rune_0")
	GameEvents.set_objective("Sigue el latido del farol hasta la lente")
	refresh()
	GameEvents.save_game()

func practice_wave() -> void:
	if not GameEvents.story_seen.has("garden_guard_memory"):
		GameEvents.story("garden_guard_memory", "MEMORIA · EL ÚLTIMO TURNO", "Una niña tropieza en la pasarela. El guardián extiende los brazos. Un aro de luz barre la piedra y los faroleros saltan a su paso. Al caer, sus lámparas vuelven a arder.\n\nEl eco aún guarda ese movimiento. Actívalo y prueba a saltar.")
		$Eco.caption = "Ensayar el salto de resonancia"
		return
	if $Eco.has_node("Ensayo"): return
	var wave := preload("res://scripts/resonance_wave.gd").new()
	wave.name = "Ensayo"
	wave.damage_enabled = false
	wave.practice = true
	wave.speed = 3.8
	wave.position = Vector3(0, 0, -4)
	$Eco.add_child(wave)
	GameEvents.sound_requested.emit("guardian_wave")

func align_lens() -> void:
	if not GameEvents.story_seen.has(SCAN):
		GameEvents.toast_requested.emit("La lente está fría. Cerca del arco todavía late un farol.")
		return
	restored = true
	GameEvents.story_seen[OPEN] = true
	refresh()
	glow.albedo_color = Color("ffd778")
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(lens, "rotation:y", 0.0, 0.5)
	tween.tween_property(deck, "position:y", 0.0, 1.3)
	GameEvents.sound_requested.emit("rune_0")
	tween.tween_callback(GameEvents.sound_requested.emit.bind("rune_1"))
	GameEvents.set_objective("Cruza el puente restaurado hasta el Jardín de Ecos")
	GameEvents.save_game()
