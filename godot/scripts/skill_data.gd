extends RefCounted
## Fase 7: Constelación de Neri. Doce habilidades en tres ramas que se compran con Destellos.
## "position" es la coordenada de la estrella en el panel (0..1). "requires" es la estrella previa.

const ROOT := "core"
const BRANCHES := {
	"luz": {"title": "Rama de la Luz", "color": Color("f1d48b")},
	"viento": {"title": "Rama del Viento", "color": Color("8fe9d6")},
	"corazon": {"title": "Rama del Corazón", "color": Color("f29e9e")},
}

const SKILLS := {
	"core": {"branch": "", "title": "Corazón del escáner", "cost": 0, "requires": "", "position": Vector2(0.5, 0.56),
		"text": "El origen de la constelación. Cada destello que encuentres puede encender una estrella nueva."},
	# --- Luz -------------------------------------------------------------------------------------
	"pulse_wide": {"branch": "luz", "title": "Pulso amplio", "cost": 2, "requires": "core", "position": Vector2(0.36, 0.38),
		"text": "El pulso de luz alcanza un 25 % más de distancia."},
	"pulse_quick": {"branch": "luz", "title": "Pulso veloz", "cost": 3, "requires": "pulse_wide", "position": Vector2(0.22, 0.24),
		"text": "El escáner se recarga un 30 % más rápido tras cada pulso."},
	"pulse_daze": {"branch": "luz", "title": "Destello cegador", "cost": 3, "requires": "pulse_wide", "position": Vector2(0.4, 0.17),
		"text": "Los ecos quedan aturdidos más tiempo y el pulso deshace los orbes enemigos a mayor distancia."},
	"pulse_nova": {"branch": "luz", "title": "Nova", "cost": 5, "requires": "pulse_quick", "position": Vector2(0.2, 0.07),
		"text": "Mantén el pulso para cargar una nova: más alcance y doble daño. Cuesta 30 de energía."},
	# --- Viento ----------------------------------------------------------------------------------
	"agile_roll": {"branch": "viento", "title": "Rodada ágil", "cost": 2, "requires": "core", "position": Vector2(0.64, 0.38),
		"text": "La esquiva cuesta 7 de energía en vez de 12 y se recupera antes."},
	"stride": {"branch": "viento", "title": "Zancada", "cost": 2, "requires": "agile_roll", "position": Vector2(0.6, 0.17),
		"text": "Correr consume un 40 % menos de energía."},
	"double_jump": {"branch": "viento", "title": "Doble salto", "cost": 3, "requires": "agile_roll", "position": Vector2(0.78, 0.24),
		"text": "Pulsa saltar en el aire para impulsarte una segunda vez."},
	"serene_glide": {"branch": "viento", "title": "Planeo sereno", "cost": 3, "requires": "double_jump", "position": Vector2(0.8, 0.07),
		"text": "Al planear desciendes más despacio y avanzas más rápido. Requiere haber aprendido a planear."},
	# --- Corazón ---------------------------------------------------------------------------------
	"vitality": {"branch": "corazon", "title": "Vitalidad", "cost": 3, "requires": "core", "position": Vector2(0.5, 0.76),
		"text": "La energía máxima sube de 100 a 130."},
	"ember": {"branch": "corazon", "title": "Brasa interior", "cost": 2, "requires": "vitality", "position": Vector2(0.34, 0.86),
		"text": "La energía se regenera un 50 % más rápido y antes tras recibir un golpe."},
	"compass": {"branch": "corazon", "title": "Brújula de destellos", "cost": 2, "requires": "vitality", "position": Vector2(0.66, 0.86),
		"text": "El HUD señala el destello más cercano que aún no has recogido."},
	"aegis": {"branch": "corazon", "title": "Égida de luz", "cost": 5, "requires": "ember", "position": Vector2(0.2, 0.94),
		"text": "Un escudo absorbe un golpe completo. Se recarga en 25 segundos."},
}

## Habilidades concedidas por la historia (no se compran).
const STORY_SKILLS := {
	"glide": {"title": "Planeo", "text": "Mantén saltar en el aire para planear. Las corrientes ascendentes te elevan."},
}


static func skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


static func valid(id: String) -> bool:
	return SKILLS.has(id) or STORY_SKILLS.has(id)


static func total_cost() -> int:
	var total := 0
	for id in SKILLS: total += int(SKILLS[id].cost)
	return total
