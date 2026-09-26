extends Control
## Créditos desplazables. Se usan al final del capítulo y desde el menú principal.

signal finished

const Data = preload("res://scripts/credits_data.gd")
const UI = preload("res://scripts/ui_theme.gd")

var scroller: VBoxContainer
var speed: float = 46.0
var running: bool = false
var with_epilogue: bool = false


func build(epilogue: bool = false, chapter: int = 1) -> void:
	with_epilogue = epilogue
	name = "CreditsRoll"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	scroller = VBoxContainer.new()
	scroller.name = "Scroller"
	scroller.alignment = BoxContainer.ALIGNMENT_CENTER
	scroller.add_theme_constant_override("separation", 10)
	scroller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroller)
	if epilogue:
		for line in (Data.EPILOGUE_II if chapter == 2 else Data.EPILOGUE):
			var text := _line(line, 23, UI.INK, "body")
			scroller.add_child(text)
			scroller.add_child(_spacer(26))
		scroller.add_child(_spacer(40))
		scroller.add_child(_line("FIN DEL CAPÍTULO II" if chapter == 2 else "FIN DEL CAPÍTULO I", 30, UI.GOLD, "title"))
		scroller.add_child(_line("LA SEÑAL IMPOSIBLE" if chapter == 2 else "EL FARO DORMIDO", 18, UI.TEAL_LIGHT, "title_semibold"))
		scroller.add_child(_spacer(220))
	var first := true
	for section in Data.SECTIONS:
		var heading := _line(section[0], 44 if first else 21, UI.GOLD, "logo" if first else "title")
		scroller.add_child(heading)
		for entry in section[1]:
			scroller.add_child(_line(entry, 20 if first else 18, UI.INK if not first else UI.TEAL_LIGHT, "body"))
		scroller.add_child(_spacer(120 if first else 54))
		first = false
	resized.connect(_layout)
	_layout.call_deferred()


func _line(value: String, size: int, color: Color, kind: String) -> Label:
	var label := UI.label(value, size, color, kind)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _layout() -> void:
	var width := minf(780.0, size.x - 64.0)
	scroller.custom_minimum_size.x = width
	scroller.size.x = width
	scroller.position.x = (size.x - width) * 0.5
	for child in scroller.get_children():
		if child is Label: child.custom_minimum_size.x = width


func start() -> void:
	scroller.position.y = size.y + 20.0
	running = true


func progress() -> float:
	if not scroller: return 0.0
	return clampf((size.y + 20.0 - scroller.position.y) / maxf(1.0, size.y + scroller.size.y + 20.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if not running:
		return
	scroller.position.y -= speed * delta
	if scroller.position.y + scroller.size.y < -10.0:
		running = false
		finished.emit()
