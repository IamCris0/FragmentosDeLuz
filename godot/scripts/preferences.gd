extends Node

signal quality_changed(level: int)
signal changed
const PATH: String = "user://preferences.cfg"
var volumes: Dictionary = {"Master": .8, "Music": .7, "Ambience": .65, "Effects": .85, "Voice": .9}
var quality: int = 1
## Fase 6: cámara, pantalla completa y voces.
var camera_sensitivity: float = 1.0
var invert_y: bool = false
var fullscreen: bool = false
## 0 = Relato (mitad de daño), 1 = Aventura (equilibrio original).
var difficulty: int = 1


func _ready() -> void:
	for bus in ["Music","Ambience","Effects","Voice"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			var index: int=AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
			AudioServer.set_bus_send(index,"Master")
	var config:=ConfigFile.new()
	if not GameEvents.is_qa_run() and config.load(PATH)==OK:
		for bus in volumes: volumes[bus]=clampf(float(config.get_value("audio",bus,volumes[bus])),0.,1.)
		quality=clampi(int(config.get_value("graphics","quality",1)),0,2)
		fullscreen=bool(config.get_value("graphics","fullscreen",false))
		camera_sensitivity=clampf(float(config.get_value("controls","camera_sensitivity",1.0)),.3,2.5)
		invert_y=bool(config.get_value("controls","invert_y",false))
		difficulty=clampi(int(config.get_value("gameplay","difficulty",1)),0,1)
	for bus in volumes: apply_volume(bus)
	apply_fullscreen()


func apply_volume(bus: String) -> void:
	var index: int=AudioServer.get_bus_index(bus)
	if index < 0: return
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(float(volumes[bus]),.0001)))
	AudioServer.set_bus_mute(index,float(volumes[bus])<=0)


func set_volume(bus: String, value: float) -> void:
	volumes[bus]=clampf(value,0.,1.)
	apply_volume(bus)
	save()


func set_quality(value: int) -> void:
	quality=clampi(value,0,2)
	quality_changed.emit(quality)
	save()


func set_fullscreen(value: bool) -> void:
	fullscreen=value
	apply_fullscreen()
	save()


func apply_fullscreen() -> void:
	if GameEvents.is_qa_run() or DisplayServer.get_name()=="headless": return
	var mode: DisplayServer.WindowMode=DisplayServer.window_get_mode()
	if fullscreen and mode!=DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and mode==DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func set_camera(sensitivity: float, invert: bool) -> void:
	camera_sensitivity=clampf(sensitivity,.3,2.5)
	invert_y=invert
	save()


func set_difficulty(value: int) -> void:
	difficulty=clampi(value,0,1)
	save()


func save() -> void:
	changed.emit()
	if GameEvents.is_qa_run():return
	var config:=ConfigFile.new()
	for bus in volumes:config.set_value("audio",bus,volumes[bus])
	config.set_value("graphics","quality",quality)
	config.set_value("graphics","fullscreen",fullscreen)
	config.set_value("controls","camera_sensitivity",camera_sensitivity)
	config.set_value("controls","invert_y",invert_y)
	config.set_value("gameplay","difficulty",difficulty)
	config.save(PATH)
