extends RefCounted
## Fase 7: datos compartidos de los niveles del archipiélago.
## Es la única fuente de verdad para escenas, puntos de control, enemigos, destellos y memorias:
## la usan GameEvents, la validación del guardado (save_store.gd), la carta y el generador de niveles.

const ORDER: Array[String] = ["auralia", "grutas", "cefiro", "observatorio"]

const LEVELS := {
	"auralia": {
		"title": "Auralia", "subtitle": "El Faro Dormido", "chapter": 1,
		"scene": "res://scenes/main_island.tscn", "music": "exploration",
		"key": "", "key_title": "Faro restaurado",
		"checkpoints": [Vector3(0, 0.2, 7), Vector3(0, 0.2, -24), Vector3(0, 4.2, -54), Vector3(0, 4.2, -79)],
		"zones": ["Umbral de Auralia", "Jardín de Ecos", "Paso del Cielo", "Faro de Auralia"],
		"enemies": ["TutorialEcho", "GardenEcho_A", "GardenEcho_B", "SkyEcho", "BeaconEcho"],
		"destellos": 0, "memories": ["lore_1", "lore_2", "lore_3", "lore_4", "lore_5"],
		"map_position": Vector3(0, 0, 0), "color": Color("f1d48b"),
	},
	"grutas": {
		"title": "Grutas Prismáticas", "subtitle": "La luz que se dobla", "chapter": 2,
		"scene": "res://scenes/levels/grutas.tscn", "music": "grutas",
		"key": "key_grutas", "key_title": "Llave del Prisma",
		"checkpoints": [Vector3(0, 0.2, 6), Vector3(0, 0.2, -25), Vector3(0, 0.2, -58.5), Vector3(0, -1.8, -82)],
		"zones": ["Boca de la Gruta", "Salón de los Prismas", "Puente de Cuarzo", "Corazón Prismático"],
		"enemies": ["G_Echo_1", "G_Echo_2", "G_Echo_3", "G_Echo_4", "G_Echo_5", "G_Vigia_1", "G_Vigia_2", "G_Vigia_3"],
		"destellos": 6, "memories": ["lore_g1", "lore_g2"],
		"map_position": Vector3(-26, -3, -18), "color": Color("b18cff"),
	},
	"cefiro": {
		"title": "Picos del Céfiro", "subtitle": "El viento que recuerda", "chapter": 2,
		"scene": "res://scenes/levels/cefiro.tscn", "music": "cefiro",
		"key": "key_cefiro", "key_title": "Llave del Viento",
		"checkpoints": [Vector3(0, 0.2, 6), Vector3(0, 2.2, -37.5), Vector3(0, 3.2, -57), Vector3(0, 14.2, -86)],
		"zones": ["Mirador del Céfiro", "Escalera de Nubes", "Molinos Antiguos", "Cumbre del Céfiro"],
		"enemies": ["C_Echo_1", "C_Echo_2", "C_Echo_3", "C_Echo_4", "C_Cefiro_1", "C_Cefiro_2", "C_Cefiro_3", "C_Cefiro_4"],
		"destellos": 6, "memories": ["lore_c1", "lore_c2"],
		"map_position": Vector3(24, 4, -24), "color": Color("8fe9d6"),
	},
	"observatorio": {
		"title": "Observatorio Estelar", "subtitle": "La señal imposible", "chapter": 2,
		"scene": "res://scenes/levels/observatorio.tscn", "music": "observatorio",
		"key": "key_observatorio", "key_title": "Llave de la Estrella",
		"checkpoints": [Vector3(0, 0.2, 6), Vector3(0, 6.2, -25), Vector3(0, 6.2, -57), Vector3(0, 8.2, -85)],
		"zones": ["Escalinata Nocturna", "Jardín de Constelaciones", "Anillos del Orrery", "Cúpula del Observatorio"],
		"enemies": ["O_Echo_1", "O_Echo_2", "O_Echo_3", "O_Vigia_1", "O_Vigia_2", "O_Cefiro_1", "Heraldo"],
		"destellos": 6, "memories": ["lore_o1", "lore_o2"],
		"map_position": Vector3(0, 12, -52), "color": Color("ffe6a8"),
	},
}

## Memorias del archipiélago (las cinco de Auralia siguen en GameEvents.LORE_TITLES).
const MEMORY_TITLES := {
	"lore_g1": "Los talladores de luz", "lore_g2": "El corazón que no se apaga",
	"lore_c1": "Los guardianes del viento", "lore_c2": "La canción de los molinos",
	"lore_o1": "Maren, la última farolera", "lore_o2": "La noche del eclipse",
}


static func level(id: String) -> Dictionary:
	return LEVELS.get(id, LEVELS["auralia"])


static func exists(id: String) -> bool:
	return LEVELS.has(id)


static func scene_for(id: String) -> String:
	return str(level(id).scene)


static func checkpoints(id: String) -> Array:
	return level(id).checkpoints


static func all_enemies() -> Array[String]:
	var result: Array[String] = []
	for id in ORDER:
		for enemy in LEVELS[id].enemies: result.append(str(enemy))
	return result


static func destello_ids(id: String) -> Array[String]:
	var result: Array[String] = []
	for i in int(level(id).destellos): result.append("d_%s_%d" % [id, i + 1])
	return result


## Nivel previo que debe completarse para desbloquear este ("" = siempre disponible).
static func requirement(id: String) -> String:
	var index := ORDER.find(id)
	return ORDER[index - 1] if index > 0 else ""


static func next_level(id: String) -> String:
	var index := ORDER.find(id)
	return ORDER[index + 1] if index >= 0 and index + 1 < ORDER.size() else ""
