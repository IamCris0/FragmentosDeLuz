extends CanvasLayer

signal channel_requested
signal reset_requested

const TEAL: Color = Color("72ded0")
const GOLD: Color = Color("f6d283")
const WHITE: Color = Color("edf4ef")
var root: Control
var heading: Label
var subtitle: Label
var energy_title: Label
var energy_value: Label
var energy_bar: ProgressBar
var fragment_title: Label
var fragment_value: Label
var status: Label
var prompt: Button
var reset_button: Button
var bar_tween: Tween


func label(text_value: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.03, 0.06, 0.08, 0.8))
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(node)
	return node


func style(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	return box


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	heading = label("FRAGMENTOS DE LUZ", 26, WHITE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = label("S A N T U A R I O   I", 12, GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_title = label("ENERGÍA", 12, WHITE)
	energy_value = label("0%", 12, TEAL)
	energy_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy_bar = ProgressBar.new()
	energy_bar.show_percentage = false
	energy_bar.max_value = 100
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_bar.add_theme_stylebox_override("background", style(Color("273a3d"), Color("7d8b82")))
	energy_bar.add_theme_stylebox_override("fill", style(TEAL, Color("a2f3db")))
	root.add_child(energy_bar)
	fragment_title = label("FRAGMENTOS", 12, WHITE)
	fragment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fragment_value = label("0 / 7", 29, GOLD)
	fragment_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status = label("Cristal de energía", 16, WHITE)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = Button.new()
	prompt.text = "[E]  Canalizar fragmento"
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", WHITE)
	prompt.add_theme_color_override("font_disabled_color", TEAL)
	prompt.add_theme_stylebox_override("normal", style(Color("172c31"), Color("648a82")))
	prompt.add_theme_stylebox_override("hover", style(Color("264a4c"), TEAL))
	prompt.add_theme_stylebox_override("pressed", style(Color("315e5b"), GOLD))
	prompt.add_theme_stylebox_override("disabled", style(Color("182f32"), Color("466d60")))
	prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt.pressed.connect(func() -> void: channel_requested.emit())
	root.add_child(prompt)
	reset_button = Button.new()
	reset_button.text = "↻"
	reset_button.tooltip_text = "Reiniciar santuario"
	reset_button.flat = true
	reset_button.add_theme_font_size_override("font_size", 30)
	reset_button.add_theme_color_override("font_color", WHITE)
	reset_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	root.add_child(reset_button)
	GameEvents.fragments_changed.connect(update_fragments)
	GameEvents.energy_changed.connect(update_energy)
	get_viewport().size_changed.connect(layout)
	layout()


func layout() -> void:
	var size: Vector2 = root.get_viewport_rect().size
	var compact: bool = size.x < 900
	var edge: float = 32.0
	heading.position = Vector2(size.x * 0.5 - 190, 26)
	heading.size = Vector2(380, 38)
	subtitle.position = Vector2(size.x * 0.5 - 160, 65)
	subtitle.size = Vector2(320, 24)
	var row: float = 107 if compact else 35
	energy_title.position = Vector2(edge, row)
	energy_value.position = Vector2(edge + 150, row)
	energy_value.size = Vector2(60, 22)
	energy_bar.position = Vector2(edge, row + 29)
	energy_bar.size = Vector2(210, 10)
	fragment_title.position = Vector2(size.x - edge - 180, row)
	fragment_title.size = Vector2(180, 22)
	fragment_value.position = Vector2(size.x - edge - 150, row + 21)
	fragment_value.size = Vector2(150, 44)
	status.position = Vector2(size.x * 0.5 - 180, size.y - 124)
	status.size = Vector2(360, 26)
	prompt.position = Vector2(size.x * 0.5 - 150, size.y - 82)
	prompt.size = Vector2(300, 48)
	reset_button.position = Vector2(size.x - 78, size.y - 82)
	reset_button.size = Vector2(44, 48)


func update_energy(current: float, maximum: float) -> void:
	var percentage: float = clampf(current / maxf(maximum, 0.001) * 100.0, 0.0, 100.0)
	energy_value.text = "%d%%" % roundi(percentage)
	if bar_tween and bar_tween.is_valid():
		bar_tween.kill()
	bar_tween = create_tween()
	bar_tween.tween_property(energy_bar, "value", percentage, 0.3)


func update_fragments(collected: int, total: int) -> void:
	fragment_value.text = "%d / %d" % [collected, total]
	var complete: bool = collected == total
	status.text = "El santuario ha despertado" if complete else "Cristal de energía"
	prompt.text = "Cristal activado" if complete else "[E]  Canalizar fragmento"
	prompt.disabled = complete
