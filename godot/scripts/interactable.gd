extends StaticBody3D

@export_enum("luma", "memory", "resonator", "chest", "lever", "portal") var kind: String = "memory"
@export var item_id: String = ""
@export var prompt: String = "Examinar"
@export_multiline var story_text: String = ""
@export var rune_index: int = 0
var used: bool = false
var lever_tween: Tween


func _ready() -> void:
	add_to_group("interactable")
	used = kind == "chest" and GameEvents.fragment_ids.has(item_id)
	if used and has_node("AnimationPlayer"):
		$AnimationPlayer.play("open")
		$AnimationPlayer.advance(.6)
	if kind=="lever":
		var handle:Node3D=$Visual.find_child("LeverPivot",true,false)
		if handle:handle.rotation.x=.75 if GameEvents.lever_on else 0.


## Fase 7: el portal del faro cambia de texto cuando lleva a la carta del archipiélago.
func current_prompt() -> String:
	if kind == "portal" and GameEvents.completed and GameEvents.story_seen.has("cine_finale"):
		return "Viajar por el archipiélago"
	return prompt


func available() -> bool:
	return not used or kind in ["luma", "memory", "portal", "resonator", "lever"]


func interact(_player: Node3D) -> void:
	match kind:
		"luma":
			GameEvents.story("luma_intro", "LUMA · ARCHIVISTA DE AURALIA", "Llegaste siguiendo una señal, Neri. Yo llevo cien años esperando una respuesta. Cuando el faro se apagó, nuestra ciudad se partió en el cielo.\n\nNo todo lo que quedó aquí quiere volver a despertar. Los ecos del faro se alimentan de energía viva: si se acercan demasiado, usa Q para emitir un pulso de luz.\n\nRecupera los siete fragmentos de su núcleo. En el jardín, despierta primero la OLA, después el SOL y al final la ESTRELLA. El puente recordará el camino.")
			GameEvents.set_objective("Reúne los fragmentos y alcanza el Jardín de Ecos")
		"memory":
			if item_id.begins_with("lore_") and not GameEvents.LORE_TITLES.has(item_id):
				# Fase 7: memorias del archipiélago (dos por isla).
				var first: bool = not GameEvents.story_seen.has(item_id)
				GameEvents.story(item_id, "MEMORIA DEL ARCHIPIÉLAGO", story_text)
				if first:
					GameEvents.toast_requested.emit("Memoria de la isla · %d de %d" % [GameEvents.level_memories(), GameEvents.LevelData.level(GameEvents.level).memories.size()])
			elif item_id.begins_with("lore_"):
				var first_time: bool = not GameEvents.story_seen.has(item_id)
				GameEvents.story(item_id, "MEMORIA DE AURALIA", story_text)
				if first_time:
					GameEvents.toast_requested.emit("Memoria de Auralia · %d de %d" % [GameEvents.lore_count(), GameEvents.LORE_TOTAL])
			else:
				GameEvents.story(item_id, "MEMORIA DEL FARO", story_text)
		"resonator":
			get_tree().current_scene.activate_rune(rune_index)
		"chest":
			if used: return
			used = true
			GameEvents.collect(StringName(item_id))
			GameEvents.sound_requested.emit("chest")
			$AnimationPlayer.play("open")
			GameEvents.story("relic", "EL ÚLTIMO MENSAJE", "Quien encuentre esta reliquia: no reconstruya nuestros muros. Encienda el faro para que los que aún flotan lejos puedan volver a casa.\n\n— El consejo de Auralia")
		"lever":
			GameEvents.lever_on = not GameEvents.lever_on
			GameEvents.sound_requested.emit("lever")
			GameEvents.toast_requested.emit("Ascensor de luz activado" if GameEvents.lever_on else "Ascensor detenido")
			GameEvents.save_game()
			var handle:Node3D=$Visual.find_child("LeverPivot",true,false)
			if handle:
				if lever_tween:lever_tween.kill()
				lever_tween=create_tween()
				lever_tween.tween_property(handle,"rotation:x",.75 if GameEvents.lever_on else 0.,.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"portal":
			if GameEvents.collected < 7 or not GameEvents.puzzle_solved:
				GameEvents.toast_requested.emit("El faro necesita los siete fragmentos y el jardín restaurado")
			elif not GameEvents.completed and not GameEvents.purified_ids.has("BeaconEcho"):
				GameEvents.set_objective("Purifica al guardián del faro con tu pulso de luz")
				GameEvents.toast_requested.emit("El último eco aún retiene el núcleo. Interrumpe sus ataques con Q.")
			elif GameEvents.completed and GameEvents.story_seen.has("cine_finale"):
				# Fase 7: el portal del faro lleva a la Carta del Archipiélago.
				if get_tree().current_scene.has_method("open_map"): get_tree().current_scene.open_map()
				else: GameEvents.toast_requested.emit("El faro brilla sobre Auralia")
			else:
				get_tree().current_scene.start_finale()
