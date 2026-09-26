extends CanvasLayer
## Fase 7: interludio en viñetas (mismo lenguaje que el prólogo) para ilustraciones hechas fuera del
## motor. Muestra cada viñeta a pantalla completa con un lento acercamiento, su texto y la narración
## opcional (<voice_prefix><índice>.ogg). Emite `finished` al terminar o al saltarlo.

signal finished

const UI = preload("res://scripts/ui_theme.gd")

var panels: Array[Texture2D] = []
var captions: Array = []
var voice_prefix: String = ""
var index: int = 0
var reveal: float = 0.0
var root: Control
var image: TextureRect
var title_label: Label
var body_label: Label
var progress_label: Label
var advance: Button
var skip: Button
var narrator: AudioStreamPlayer
var motion: Tween
var done: bool = false


func setup(art: Array[Texture2D], texts: Array, voice: String = "") -> void:
	panels = art
	captions = texts
	voice_prefix = voice


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "ComicRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.build_theme()
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("090d16")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	image = TextureRect.new()
	image.name = "Panel"
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(image)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.72)
	shade.anchor_top = 0.72
	shade.anchor_right = 1
	shade.anchor_bottom = 1
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.name = "CaptionBox"
	box.anchor_left = 0.06
	box.anchor_top = 0.73
	box.anchor_right = 0.94
	box.anchor_bottom = 0.97
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	title_label = UI.label("", 30, UI.GOLD, "title")
	box.add_child(title_label)
	body_label = UI.label("", 20, UI.INK, "body_bold")
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	progress_label = UI.label("", 14, Color("b8c6c1"), "body_bold")
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progress_label)
	skip = _button(row, "Saltar")
	advance = _button(row, "Continuar")
	skip.pressed.connect(finish)
	advance.pressed.connect(next)
	narrator = AudioStreamPlayer.new()
	narrator.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Effects"
	add_child(narrator)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show(0)


func _button(parent: Control, caption: String) -> Button:
	var node := Button.new()
	node.text = caption
	node.custom_minimum_size = Vector2(132, 42)
	node.focus_mode = Control.FOCUS_NONE
	parent.add_child(node)
	return node


func _layout() -> void:
	var small := get_viewport().get_visible_rect().size.x < 900
	title_label.add_theme_font_size_override("font_size", 24 if small else 30)
	body_label.add_theme_font_size_override("font_size", 16 if small else 20)


func _show(next_index: int) -> void:
	index = clampi(next_index, 0, panels.size() - 1)
	var item: Dictionary = captions[index] if index < captions.size() else {}
	title_label.text = str(item.get("title", ""))
	body_label.text = str(item.get("text", ""))
	progress_label.text = "%d / %d" % [index + 1, panels.size()]
	advance.text = "Seguir" if index == panels.size() - 1 else "Continuar"
	reveal = 0.0
	image.texture = panels[index]
	image.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	image.scale = Vector2.ONE
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	if motion: motion.kill()
	motion = create_tween()
	motion.tween_property(image, "scale", Vector2.ONE * 1.04, 7.0).set_trans(Tween.TRANS_SINE)
	_narrate()


func _narrate() -> void:
	narrator.stop()
	if voice_prefix == "": return
	var path := "res://assets/audio/voice/%s%d.ogg" % [voice_prefix, index]
	if ResourceLoader.exists(path):
		narrator.stream = load(path)
		narrator.play()


func _process(delta: float) -> void:
	reveal += delta * 58.0
	body_label.visible_characters = mini(int(reveal), body_label.text.length())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		finish()
		get_viewport().set_input_as_handled()


func next() -> void:
	if done: return
	if body_label.visible_characters >= 0 and body_label.visible_characters < body_label.text.length():
		reveal = body_label.text.length()
		body_label.visible_characters = -1
		return
	if index >= panels.size() - 1: finish()
	else: _show(index + 1)


func finish() -> void:
	if done: return
	done = true
	narrator.stop()
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())
