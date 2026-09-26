extends PanelContainer
## Panel de ajustes compartido por el menú principal y la pausa (fase 6).
## Volúmenes por bus (incluida la voz), calidad, pantalla completa y cámara.

signal closed

const UI = preload("res://scripts/ui_theme.gd")
const BUSES := {"Master": "General", "Music": "Música", "Ambience": "Ambiente", "Effects": "Efectos", "Voice": "Voces"}

var sliders: Dictionary = {}
var quality: OptionButton
var fullscreen: CheckButton
var sensitivity: HSlider
var invert: CheckButton
var difficulty: OptionButton
var close_button: Button


func build() -> void:
	name = "SettingsPanel"
	add_theme_stylebox_override("panel", UI.panel_style())
	theme = UI.build_theme()
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := UI.label("Ajustes", 24, UI.GOLD, "title")
	box.add_child(title)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for bus in BUSES:
		grid.add_child(_caption(BUSES[bus]))
		var slider := HSlider.new()
		slider.name = bus + "Volume"
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(230, 26)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float) -> void: Preferences.set_volume(bus, value))
		grid.add_child(slider)
		sliders[bus] = slider
	grid.add_child(_caption("Calidad"))
	quality = OptionButton.new()
	quality.name = "Quality"
	for caption in ["Ligera", "Equilibrada", "Alta"]: quality.add_item(caption)
	quality.item_selected.connect(Preferences.set_quality)
	grid.add_child(quality)
	grid.add_child(_caption("Dificultad"))
	difficulty = OptionButton.new()
	difficulty.name = "Difficulty"
	difficulty.add_item("Relato (mitad de daño)")
	difficulty.add_item("Aventura")
	difficulty.item_selected.connect(Preferences.set_difficulty)
	grid.add_child(difficulty)
	grid.add_child(_caption("Pantalla completa"))
	fullscreen = CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.toggled.connect(Preferences.set_fullscreen)
	grid.add_child(fullscreen)
	grid.add_child(_caption("Sensibilidad de cámara"))
	sensitivity = HSlider.new()
	sensitivity.name = "CameraSensitivity"
	sensitivity.min_value = 0.3
	sensitivity.max_value = 2.5
	sensitivity.step = 0.05
	sensitivity.custom_minimum_size = Vector2(230, 26)
	sensitivity.value_changed.connect(func(value: float) -> void: Preferences.set_camera(value, invert.button_pressed))
	grid.add_child(sensitivity)
	grid.add_child(_caption("Invertir eje vertical"))
	invert = CheckButton.new()
	invert.name = "InvertY"
	invert.toggled.connect(func(value: bool) -> void: Preferences.set_camera(sensitivity.value, value))
	grid.add_child(invert)
	var hint := UI.label("Mando: stick izquierdo mueve, stick derecho gira la cámara.", 12, Color("9fb8b0"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 380
	box.add_child(hint)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "Volver"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()


func _caption(text: String) -> Label:
	var label := UI.label(text, 14)
	label.custom_minimum_size.x = 150
	return label


func open() -> void:
	for bus in sliders:
		sliders[bus].set_value_no_signal(float(Preferences.volumes.get(bus, 0.8)))
	quality.select(Preferences.quality)
	difficulty.select(Preferences.difficulty)
	fullscreen.set_pressed_no_signal(Preferences.fullscreen)
	sensitivity.set_value_no_signal(Preferences.camera_sensitivity)
	invert.set_pressed_no_signal(Preferences.invert_y)
	show()
	(sliders["Master"] as Control).grab_focus.call_deferred()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()
