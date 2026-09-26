extends "res://scripts/level_controller.gd"
## Fase 7: Picos del Céfiro. Luma enseña a planear; las corrientes ascendentes elevan a Neri,
## las nubes de piedra se desmoronan y tres válvulas despiertan los molinos y la gran corriente
## que lleva a la cumbre, donde espera la Llave del Viento.

const Style = preload("res://scripts/crystal_style.gd")
const HINTS := [
	"Mantén saltar en el aire para planear. Dentro de una corriente ascendente, planear te eleva.",
	"Algunas nubes de piedra se desmoronan al pisarlas: no te detengas. Los céfiros marcan una línea antes de embestir.",
	"Abre las tres válvulas de viento para despertar los molinos y la gran corriente central.",
	"El viento lateral empuja al planear: corrige el rumbo. La llave espera en el altar de la cumbre.",
]
const VALVES := ["valve_1", "valve_2", "valve_3"]

var altar: Node
var updraft: Node


func setup_level() -> void:
	Style.apply(self, "teal")
	altar = get_node("Zones/Summit/KeyAltar")
	altar.reveal(false)
	updraft = get_node("Zones/Mills/GreatUpdraft")
	for valve in get_tree().get_nodes_in_group("valve"):
		valve.opened.connect(_on_valve_opened)
	for i in VALVES.size():
		var mill := get_node_or_null("Zones/Mills/Windmill_%d" % (i + 1))
		if mill and GameEvents.level_flag(VALVES[i]): mill.set_spinning(true)
	if _valves_open() == VALVES.size(): updraft.set_active(true, false)
	director.register("cefiro_intro", _seq_intro)
	director.register("cefiro_winds", _seq_winds)
	director.register("cefiro_key", _seq_key)
	_update_objective()
	_update_hint()


func _valves_open() -> int:
	var count := 0
	for flag in VALVES:
		if GameEvents.level_flag(flag): count += 1
	return count


func _on_valve_opened(flag: String) -> void:
	var index := VALVES.find(flag)
	var mill := get_node_or_null("Zones/Mills/Windmill_%d" % (index + 1))
	if mill: mill.set_spinning(true)
	var count := _valves_open()
	GameEvents.sound_requested.emit("wind_gust")
	if count < VALVES.size():
		GameEvents.toast_requested.emit("Un molino despierta · %d de %d" % [count, VALVES.size()])
	else:
		GameEvents.toast_requested.emit("¡La gran corriente despierta en el centro de los molinos!")
		GameEvents.sound_requested.emit("solved")
		updraft.set_active(true, true)
		if not qa_mode:
			await play_when_free("cefiro_winds")
	_update_objective()
	_update_hint()


func _update_objective() -> void:
	var text := "Aprende a planear y cruza la Escalera de Nubes"
	if GameEvents.is_level_done(level_id): text = "Cruza el portal de la cumbre para volver a la carta"
	elif GameEvents.zone >= 3: text = "Toma la Llave del Viento en el altar de la cumbre"
	elif _valves_open() == VALVES.size(): text = "Planea dentro de la gran corriente y vuela hasta la cumbre"
	elif GameEvents.zone >= 2: text = "Abre las válvulas de viento de los molinos (%d / 3)" % _valves_open()
	elif GameEvents.zone >= 1: text = "Sube por la rampa hacia los Molinos Antiguos"
	GameEvents.set_objective(text)


func _update_hint() -> void:
	if GameEvents.is_level_done(level_id):
		GameEvents.set_hint("")
		return
	if GameEvents.zone == 2 and _valves_open() == VALVES.size():
		GameEvents.set_hint("Entra en la columna de viento y mantén saltar para planear hacia arriba.")
		return
	GameEvents.set_hint(HINTS[clampi(GameEvents.zone, 0, 3)])


func zone_entered(_index: int) -> void:
	_update_objective()
	_update_hint()


func theme_for_zone(index: int) -> int:
	return 1 if index >= 3 else 0


func audio_spots() -> Array:
	return [["MillWind", Vector3(0, 6, -68), "wind", -8.0, 24.0], ["LookoutWind", Vector3(0, 3, -6), "wind", -14.0, 18.0],
		["SummitWind", Vector3(0, 16, -92), "wind", -10.0, 20.0]]


func intro() -> void:
	if director.should_play("cefiro_intro"):
		await director.play("cefiro_intro")
	if not GameEvents.story_seen.has("cefiro_arrival"):
		await say_story("cefiro_arrival", "LUMA · PICOS DEL CÉFIRO", "Aquí arriba el viento todavía recuerda a los faroleros. Toma: guardé este hilo de luz para ti. Si mantienes el salto en el aire, se abrirá como unas alas.\n\nPlanea sobre el vacío y busca las corrientes que suben: dentro de ellas, el viento te llevará hacia arriba.")
	if not GameEvents.has_skill("glide"):
		GameEvents.grant_story_skill("glide")
		GameEvents.toast_requested.emit("Nueva habilidad: Planeo · mantén saltar en el aire")
		GameEvents.sound_requested.emit("skill_unlock")
	_update_hint()


func luma_talk() -> void:
	if GameEvents.is_level_done(level_id):
		GameEvents.story("cefiro_luma_done", "LUMA", "¿Oyes los molinos? Vuelven a cantar. Solo queda el Observatorio, Neri.")
	elif GameEvents.zone >= 2 or GameEvents.level_flag("zone_2"):
		GameEvents.story("cefiro_luma_mills", "LUMA", "Tres válvulas, tres molinos. Cuando los tres giren, el viento se reunirá en el centro y podrás subir hasta la cumbre planeando.")
	else:
		GameEvents.story("cefiro_luma_glide", "LUMA", "Salta y mantén pulsado: las alas de luz frenan la caída y te dejan avanzar mucho más lejos. Si una nube de piedra tiembla, salta enseguida.")


func key_obtained() -> void:
	_update_objective()
	_update_hint()
	if qa_mode: return
	await play_when_free("cefiro_key")
	await say_story("cefiro_key", "LUMA", "La Llave del Viento. Dos llaves, Neri. El Observatorio ya puede oírnos: el portal de la cumbre nos llevará a la carta.")


# --- Cinemáticas ----------------------------------------------------------------------------------

func _seq_intro() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("cefiro")
	director.fade_rect.color.a = 1.0
	director.fade(0.0, 1.8, false)
	director.title_card("PICOS DEL CÉFIRO", "El viento que recuerda", 5.0)
	await director.path([Vector3(-40, 30, -120), Vector3(-26, 26, -96), Vector3(-10, 22, -78)],
		[Vector3(0, 14, -92), Vector3(0, 12, -80), Vector3(0, 6, -68)], 7.0, 50.0, 46.0)
	director.say("LUMA", "Los molinos callaron hace cien años.", "vo_cine_cefiro_1", 3.0)
	await director.path([Vector3(18, 12, -58), Vector3(12, 8, -40), Vector3(6, 5, -24)],
		[Vector3(0, 4, -68), Vector3(0, 2, -44), Vector3(0, 0, -20)], 6.0, 48.0, 50.0)
	director.say("LUMA", "Despiértalos y el viento te llevará a la cumbre.", "vo_cine_cefiro_2", 3.4)
	await director.path([Vector3(0, 7, -12), Vector3(0, 3.5, -2), Vector3(1.2, 1.9, 9.6)],
		[Vector3(0, 1, -6), Vector3(0, 1.4, 2), Vector3(0, 1.5, 5)], 5.5, 55.0, 44.0)
	await director.wait(0.3)


func _seq_winds() -> void:
	var center := Vector3(0, 3, -68)
	await director.shot(Vector3(14, 8, -54), center + Vector3(0, 2, 0), Vector3(10, 6, -58), center + Vector3(0, 4, 0), 3.0, 50.0, 46.0)
	director.say("LUMA", "¡Los tres molinos cantan! La gran corriente te espera.", "vo_cine_cefiro_3", 3.0)
	await director.path([Vector3(6, 5, -62), Vector3(3, 12, -66), Vector3(2, 22, -72)],
		[center + Vector3(0, 3, 0), center + Vector3(0, 10, 0), Vector3(0, 15, -92)], 5.0, 50.0, 55.0)


func _seq_key() -> void:
	var center := player.global_position + Vector3.UP * 1.2
	player.cinematic_state = "wave"
	await director.orbit(center, 4.0, 1.0, -30.0, 50.0, 4.5, 46.0)
	player.cinematic_state = ""
