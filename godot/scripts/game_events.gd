extends Node

signal fragments_changed(collected: int, total: int)
signal energy_changed(current: float, maximum: float)
signal crystal_activated

const TOTAL: int = 7
var collected: int = 0
var fragment_ids: Dictionary = {}


func collect(fragment_id: StringName) -> bool:
	if fragment_ids.has(fragment_id) or collected >= TOTAL:
		return false
	fragment_ids[fragment_id] = true
	collected += 1
	fragments_changed.emit(collected, TOTAL)
	energy_changed.emit(float(collected), float(TOTAL))
	if collected == TOTAL:
		crystal_activated.emit()
	return true


func reset() -> void:
	collected = 0
	fragment_ids.clear()
	fragments_changed.emit(0, TOTAL)
	energy_changed.emit(0.0, float(TOTAL))
