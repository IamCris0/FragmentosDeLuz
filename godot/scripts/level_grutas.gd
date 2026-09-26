extends "res://scripts/level_controller.gd"
## Fase 7: Grutas Prismáticas. Los rayos de los emisores se desvían con prismas hasta los
## receptores, que abren la puerta de cristal, el nicho del destello, el puente de luz y el
## corazón prismático donde espera la Llave del Prisma.

const Style = preload("res://scripts/crystal_style.gd")
const OPENS := {"door_0": ["Zones/Mouth/Door_0"], "cache_1": ["Zones/Hall/Door_Cache"], "bridge_1": ["LightBridge"]}
const HINTS := [
	"Pulsa E junto al prisma para girarlo. La flecha dorada indica hacia dónde sale el rayo.",
	"Tres prismas llevan la luz: un receptor tiende el puente y otro abre un nicho. Esquiva los orbes de los vigías con C o deshazlos con Q.",
	"Salta entre las plataformas de cristal. Una se desplaza: espera a que se acerque.",
	"Dos rayos deben llegar a los receptores que flanquean el corazón. Cada uno pasa por dos prismas.",
]

var altar: Node


func setup_level() -> void:
	Style.apply(self, "violet")
	altar = get_node("Zones/Heart/KeyAltar")
	for receptor in get_tree().get_nodes_in_group("beam_receptor"):
		receptor.activated.connect(_on_receptor_activated.bind(str(receptor.flag)))
	if GameEvents.level_flag("heart_open"): altar.reveal(false)
	director.register("grutas_intro", _seq_intro)
	director.register("grutas_heart", _seq_heart)
	director.register("grutas_key", _seq_key)
	_update_objective()
	_update_hint()


func _on_receptor_activated(flag: String) -> void:
	for path in OPENS.get(flag, []):
		var node := get_node_or_null(path)
		if node: node.set_open(true)
	match flag:
		"door_0": GameEvents.toast_requested.emit("La puerta de cristal se abre")
		"cache_1": GameEvents.toast_requested.emit("Un nicho de cristal se abre en el muro este")
		"bridge_1": GameEvents.toast_requested.emit("Un puente de luz cruza la sima")
		"heart_west", "heart_east":
			if GameEvents.level_flag("heart_west") and GameEvents.level_flag("heart_east") and not GameEvents.level_flag("heart_open"):
				GameEvents.set_level_flag("heart_open")
				altar.reveal(true)
				GameEvents.sound_requested.emit("solved")
				if not qa_mode: _heart_awakens()
			else:
				GameEvents.toast_requested.emit("Un rayo alcanza el corazón. Falta el otro.")
	_update_objective()
	_update_hint()


func _heart_awakens() -> void:
	await play_when_free("grutas_heart")
	await say_story("grutas_heart", "LUMA", "¡El corazón prismático late otra vez! La Llave del Prisma está despertando sobre el altar. Tómala, Neri.")


func _update_objective() -> void:
	var text := "Gira el prisma para abrir la puerta de cristal"
	if GameEvents.is_level_done(level_id): text = "Cruza el portal del fondo para volver a la carta"
	elif GameEvents.level_flag("heart_open"): text = "Toma la Llave del Prisma del altar"
	elif GameEvents.zone >= 3: text = "Guía dos rayos hasta los receptores del corazón prismático"
	elif GameEvents.level_flag("bridge_1"): text = "Cruza el puente de luz y desciende hacia el corazón de la gruta"
	elif GameEvents.zone >= 1: text = "Lleva la luz hasta el receptor que tiende el puente"
	elif GameEvents.level_flag("door_0"): text = "Cruza el puente de piedra hacia el Salón de los Prismas"
	GameEvents.set_objective(text)


func _update_hint() -> void:
	if GameEvents.is_level_done(level_id):
		GameEvents.set_hint("")
		return
	if GameEvents.level_flag("heart_open"):
		GameEvents.set_hint("El corazón late: toma la Llave del Prisma del altar que tiene delante.")
		return
	if GameEvents.zone == 0 and GameEvents.level_flag("door_0"):
		GameEvents.set_hint("La puerta está abierta. Los ecos se purifican con Q; cada uno te da un destello.")
		return
	GameEvents.set_hint(HINTS[clampi(GameEvents.zone, 0, 3)])


func zone_entered(_index: int) -> void:
	_update_objective()
	_update_hint()


func theme_for_zone(index: int) -> int:
	return 1 if index >= 3 else 0


func audio_spots() -> Array:
	return [["HeartHum", Vector3(0, -1, -96), "crystal_hum", -4.0, 18.0],
		["HallHum", Vector3(0, 1, -34), "crystal_hum", -12.0, 14.0]]


func intro() -> void:
	if director.should_play("grutas_intro"):
		await director.play("grutas_intro")
	if not GameEvents.story_seen.has("grutas_arrival"):
		await say_story("grutas_arrival", "LUMA · GRUTAS PRISMÁTICAS", "Estas grutas eran el taller de los talladores de luz. Mira esos emisores: todavía guardan un rayo dormido.\n\nAcércate a un prisma y gíralo con E. La flecha dorada marca hacia dónde saldrá la luz. Si el rayo alcanza un receptor, el cristal recordará lo que debía abrir.")
	_update_hint()


func luma_talk() -> void:
	if GameEvents.is_level_done(level_id):
		GameEvents.story("grutas_luma_done", "LUMA", "Las grutas brillan como hace cien años. Cuando quieras, cualquier portal nos devolverá a la carta del archipiélago.")
	elif GameEvents.level_flag("door_0"):
		GameEvents.story("grutas_luma_heart", "LUMA", "Más allá del salón, el corazón prismático espera dos rayos a la vez. Y si ves una cornisa demasiado alta... quizá tu constelación tenga una estrella para ella.")
	else:
		GameEvents.story("grutas_luma_prism", "LUMA", "Sigue el rayo con la mirada: nace en el emisor, se dobla en cada prisma y se detiene al tocar piedra... o un receptor. Gira el prisma hasta que su flecha mire hacia el receptor.")


func key_obtained() -> void:
	_update_objective()
	_update_hint()
	if qa_mode: return
	await play_when_free("grutas_key")
	await say_story("grutas_key", "LUMA", "La Llave del Prisma. Siento cómo el Observatorio responde, muy lejos. Una llave menos, Neri.\n\nEl portal del fondo se ha encendido: nos llevará de vuelta a la carta.")


# --- Cinemáticas ----------------------------------------------------------------------------------

func _seq_intro() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("grutas")
	director.fade_rect.color.a = 1.0
	director.fade(0.0, 1.8, false)
	director.title_card("GRUTAS PRISMÁTICAS", "La luz que se dobla", 5.0)
	await director.path([Vector3(46, 26, 34), Vector3(28, 16, -8), Vector3(14, 9, -40)],
		[Vector3(0, 0, -26), Vector3(0, -1, -50), Vector3(0, -1, -72)], 7.0, 48.0, 44.0)
	director.say("LUMA", "Aquí la luz no se pierde, Neri. Se dobla.", "vo_cine_grutas_1", 3.2)
	await director.path([Vector3(-15, 6, -80), Vector3(-7, 3.2, -87), Vector3(2.5, 1.8, -89)],
		[Vector3(0, -0.5, -96), Vector3(0, 0, -96), Vector3(0, 0.5, -96)], 5.5, 50.0, 42.0)
	director.say("LUMA", "Guía los rayos hasta el corazón y la Llave del Prisma despertará.", "vo_cine_grutas_2", 3.8)
	await director.path([Vector3(0, 7, -14), Vector3(0, 3.2, -3), Vector3(1.2, 1.9, 9.6)],
		[Vector3(0, 1, -8), Vector3(0, 1.4, 1), Vector3(0, 1.5, 5)], 6.0, 55.0, 44.0)
	await director.wait(0.3)


func _seq_heart() -> void:
	var audio := get_node_or_null("AudioManager")
	if audio: audio.set_cinematic_music("grutas_deep")
	var center := Vector3(0, -0.5, -96)
	await director.shot(Vector3(6.5, 1.5, -86), center, Vector3(4.2, 1.0, -89.5), center + Vector3(0, 0.8, 0), 3.4, 50.0, 44.0)
	director.say("LUMA", "El corazón prismático recuerda.", "vo_cine_grutas_3", 2.4)
	await director.orbit(center + Vector3(0, 0.5, 0), 7.5, 1.8, 30.0, -25.0, 4.2, 46.0)
	await director.shot(director.last_shot.position, director.last_shot.look, Vector3(0, 0.6, -86.5), Vector3(0, -0.3, -91.6), 2.6, 46.0, 40.0)


func _seq_key() -> void:
	var center := player.global_position + Vector3.UP * 1.2
	player.cinematic_state = "wave"
	await director.orbit(center, 3.6, 0.6, -40.0, 40.0, 4.5, 44.0)
	player.cinematic_state = ""
