extends Control
## Fase 7: «Constelación de Neri», el árbol de habilidades.
## Cada estrella es un botón transparente (foco con teclado o mando) y el tablero dibuja las
## estrellas, las líneas y las etiquetas. Pulsar una estrella comprable la «prepara»; pulsarla de
## nuevo la enciende. Esc / B / K cierran el panel.

signal closed
signal skill_unlocked(id: String)

const UI = preload("res://scripts/ui_theme.gd")
const SkillData = preload("res://scripts/skill_data.gd")
const StoryArt = preload("res://scripts/story_art.gd")
const ARM_TIME := 3.0

var background: ColorRect
var board: Control
var stars: Dictionary = {}
var title_label: Label
var balance_label: Label
var hint_label: Label
var info_panel: PanelContainer
var info_title: Label
var info_branch: Label
var info_icon: TextureRect
var info_cost: Label
var info_text: Label
var info_status: Label
var unlock_button: Button
var close_button: Button
var selected: String = "core"
var armed: String = ""
var armed_time: float = 0.0
var time: float = 0.0
var bursts: Array = []
var font_title: Font
var font_body: Font


func build() -> void:
	name = "Constellation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.build_theme()
	font_title = UI.font("title")
	font_body = UI.font("body_bold")
	background = ColorRect.new()
	background.name = "Sky"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sky := ShaderMaterial.new()
	sky.shader = load("res://shaders/starfield_ui.gdshader")
	background.material = sky
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	board = Control.new()
	board.name = "Board"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(_draw_board)
	add_child(board)
	title_label = UI.label("CONSTELACIÓN DE NERI", 30, UI.GOLD, "title")
	title_label.name = "Title"
	add_child(title_label)
	balance_label = UI.label("✦ 0 destellos", 20, Color("fff1c9"), "title_semibold")
	balance_label.name = "Balance"
	add_child(balance_label)
	hint_label = UI.label("Enter / A: preparar y encender  ·  Esc / B / K: cerrar", 13, Color("a9bdb7"), "body_bold")
	hint_label.name = "Hint"
	add_child(hint_label)
	for id in SkillData.SKILLS:
		var star := Button.new()
		star.name = "Star_" + id
		star.flat = true
		star.focus_mode = Control.FOCUS_ALL
		star.custom_minimum_size = Vector2(54, 54)
		star.size = Vector2(54, 54)
		star.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			star.add_theme_stylebox_override(state, empty)
		star.focus_entered.connect(_select.bind(id))
		star.mouse_entered.connect(star.grab_focus)
		star.pressed.connect(_activate.bind(id))
		add_child(star)
		stars[id] = star
	info_panel = PanelContainer.new()
	info_panel.name = "Info"
	info_panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.03, 0.05, 0.07, 0.9), Color("6f6a4e"), 18))
	add_child(info_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	info_panel.add_child(box)
	info_icon = TextureRect.new()
	info_icon.name = "Icon"
	info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_icon.custom_minimum_size = Vector2(88, 88)
	info_icon.hide()
	box.add_child(info_icon)
	info_branch = UI.label("", 12, UI.TEAL_LIGHT, "title_semibold")
	box.add_child(info_branch)
	info_title = UI.label("", 24, UI.GOLD, "title")
	box.add_child(info_title)
	info_cost = UI.label("", 15, Color("fff1c9"), "body_bold")
	box.add_child(info_cost)
	info_text = UI.label("", 16, UI.INK, "body")
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_text.custom_minimum_size = Vector2(280, 72)
	box.add_child(info_text)
	info_status = UI.label("", 14, Color("f2b880"), "body_bold")
	info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_status)
	unlock_button = Button.new()
	unlock_button.name = "Unlock"
	unlock_button.custom_minimum_size = Vector2(0, 44)
	unlock_button.focus_mode = Control.FOCUS_NONE
	unlock_button.pressed.connect(func() -> void: _try_unlock(selected))
	box.add_child(unlock_button)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "Cerrar"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()
	resized.connect(_layout)
	GameEvents.destellos_changed.connect(func(_balance: int, _gained: int) -> void: refresh())
	GameEvents.skills_changed.connect(refresh)


func open() -> void:
	show()
	armed = ""
	_layout()
	refresh()
	var focus := "core"
	for id in SkillData.SKILLS:
		if GameEvents.skill_block_reason(id) == "":
			focus = id
			break
	(stars[focus] as Button).grab_focus.call_deferred()
	_select(focus)
	GameEvents.sound_requested.emit("ui_select")


func close() -> void:
	if not visible: return
	hide()
	armed = ""
	GameEvents.sound_requested.emit("ui_back")
	closed.emit()


func _star_center(id: String) -> Vector2:
	var area := _board_rect()
	var p: Vector2 = SkillData.SKILLS[id].position
	return area.position + Vector2(p.x * area.size.x, p.y * area.size.y)


func _board_rect() -> Rect2:
	var view := size
	var narrow := view.x < 1050
	var info_width := 0.0 if narrow else 360.0
	var top := 86.0
	var bottom := 52.0 if not narrow else 250.0
	var width := minf(view.x - info_width - 80.0, (view.y - top - bottom) * 1.25)
	var height := minf(view.y - top - bottom, width * 0.8)
	var left := 40.0 + (view.x - info_width - 80.0 - width) * 0.5
	return Rect2(Vector2(left, top), Vector2(width, height))


func _layout() -> void:
	var view := size
	var narrow := view.x < 1050
	board.position = Vector2.ZERO
	board.size = view
	(background.material as ShaderMaterial).set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))
	title_label.position = Vector2(40, 24)
	balance_label.position = Vector2(view.x - 260, 30)
	balance_label.size = Vector2(220, 30)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.position = Vector2(40, view.y - 34)
	for id in stars:
		var star: Button = stars[id]
		star.position = _star_center(id) - star.size * 0.5
	_link_focus()
	if narrow:
		info_panel.size = Vector2(view.x - 80, 0)
		info_panel.position = Vector2(40, view.y - 236)
		info_text.custom_minimum_size = Vector2(view.x - 140, 40)
	else:
		info_panel.size = Vector2(330, 0)
		info_panel.position = Vector2(view.x - 370, 110)
		info_text.custom_minimum_size = Vector2(290, 72)


## Cada estrella apunta a la más cercana en cada dirección; en el borde, a sí misma. Así el mando no
## salta a botones que quedan debajo del panel y la cruceta arriba no llega a cerrar la constelación.
func _link_focus() -> void:
	var ids: Array = stars.keys()
	var directions := {SIDE_LEFT: Vector2.LEFT, SIDE_TOP: Vector2.UP, SIDE_RIGHT: Vector2.RIGHT, SIDE_BOTTOM: Vector2.DOWN}
	for i in ids.size():
		var id: String = ids[i]
		var star: Button = stars[id]
		var here := _star_center(id)
		for side in directions:
			var axis: Vector2 = directions[side]
			var best: Button = star
			var best_score := INF
			for other in ids:
				if other == id: continue
				var delta := _star_center(other) - here
				var along := delta.dot(axis)
				if along <= 4.0: continue
				var score := along + absf(delta.cross(axis)) * 2.0
				if score < best_score:
					best_score = score
					best = stars[other]
			star.set_focus_neighbor(side, star.get_path_to(best))
		star.focus_next = star.get_path_to(stars[ids[(i + 1) % ids.size()]])
		star.focus_previous = star.get_path_to(stars[ids[(i - 1 + ids.size()) % ids.size()]])


func _state(id: String) -> String:
	if GameEvents.has_skill(id): return "owned"
	var data: Dictionary = SkillData.SKILLS[id]
	if not GameEvents.has_skill(str(data.requires)): return "locked"
	return "ready" if GameEvents.destellos >= int(data.cost) else "reachable"


func refresh() -> void:
	balance_label.text = "✦ %d destellos" % GameEvents.destellos
	_select(selected)
	board.queue_redraw()


func _select(id: String) -> void:
	if not SkillData.SKILLS.has(id): return
	if selected != id:
		armed = ""
		if visible: GameEvents.sound_requested.emit("ui_move")
	selected = id
	var data: Dictionary = SkillData.SKILLS[id]
	var branch: Dictionary = SkillData.BRANCHES.get(str(data.branch), {})
	info_branch.text = str(branch.get("title", "Origen")).to_upper()
	info_branch.add_theme_color_override("font_color", branch.get("color", UI.TEAL_LIGHT))
	info_title.text = str(data.title)
	info_text.text = str(data.text)
	var icon := StoryArt.skill_icon(id)
	info_icon.texture = icon
	info_icon.visible = icon != null and size.y >= 620
	info_icon.modulate = Color(1, 1, 1, 1) if _state(id) == "owned" else Color(0.75, 0.78, 0.85, 0.8)
	var state := _state(id)
	info_cost.text = "" if id == SkillData.ROOT else ("Coste: ✦ %d" % int(data.cost))
	var reason := GameEvents.skill_block_reason(id)
	if state == "owned":
		info_status.text = "Esta estrella ya brilla."
		info_status.add_theme_color_override("font_color", UI.TEAL_LIGHT)
	elif armed == id:
		info_status.text = "Pulsa otra vez para encenderla."
		info_status.add_theme_color_override("font_color", UI.GOLD)
	else:
		info_status.text = reason if reason != "" else "Lista para encenderse."
		info_status.add_theme_color_override("font_color", Color("f2b880") if reason != "" else UI.GOLD)
	unlock_button.visible = state != "owned"
	unlock_button.disabled = reason != ""
	unlock_button.text = "Encender estrella  ✦ %d" % int(data.cost)
	board.queue_redraw()


func _activate(id: String) -> void:
	_select(id)
	if GameEvents.skill_block_reason(id) != "":
		if not GameEvents.has_skill(id): GameEvents.sound_requested.emit("wrong")
		return
	if armed != id:
		armed = id
		armed_time = ARM_TIME
		_select(id)
		GameEvents.sound_requested.emit("ui_move")
		return
	_try_unlock(id)


func _try_unlock(id: String) -> void:
	if GameEvents.unlock_skill(id):
		armed = ""
		bursts.append({"center": _star_center(id), "time": 0.0, "color": _branch_color(id)})
		skill_unlocked.emit(id)
		refresh()


func _branch_color(id: String) -> Color:
	var branch: Dictionary = SkillData.BRANCHES.get(str(SkillData.SKILLS[id].branch), {})
	return branch.get("color", UI.GOLD)


func _process(delta: float) -> void:
	if not visible: return
	time += delta
	if armed != "":
		armed_time -= delta
		if armed_time <= 0.0:
			armed = ""
			_select(selected)
	for burst in bursts: burst.time += delta
	bursts = bursts.filter(func(burst: Dictionary) -> bool: return burst.time < 1.2)
	board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("constellation"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		for id in stars:
			if stars[id] == focused:
				_activate(id)
				get_viewport().set_input_as_handled()
				return


func _draw_board() -> void:
	# Líneas de la constelación.
	for id in SkillData.SKILLS:
		var data: Dictionary = SkillData.SKILLS[id]
		if str(data.requires) == "": continue
		var a := _star_center(str(data.requires))
		var b := _star_center(id)
		var state := _state(id)
		var color: Color = _branch_color(id)
		if state == "owned":
			board.draw_line(a, b, Color(color, 0.18), 9.0, true)
			board.draw_line(a, b, Color(color, 0.95), 2.4, true)
		elif state in ["ready", "reachable"]:
			var steps := 18
			for i in steps:
				if i % 2 == 1: continue
				var t0 := float(i) / steps
				var t1 := float(i + 1) / steps
				board.draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(color, 0.45 + 0.2 * sin(time * 2.4)), 1.6, true)
		else:
			board.draw_line(a, b, Color(0.5, 0.56, 0.6, 0.18), 1.2, true)
	var focused := get_viewport().gui_get_focus_owner()
	for id in SkillData.SKILLS:
		var center := _star_center(id)
		var state := _state(id)
		var color: Color = _branch_color(id) if id != SkillData.ROOT else Color("fff1c9")
		var radius := 13.0 if id != SkillData.ROOT else 18.0
		var pulse := 0.5 + 0.5 * sin(time * 2.2 + center.x * 0.01)
		match state:
			"owned":
				board.draw_circle(center, radius * 2.4, Color(color, 0.08 + 0.04 * pulse))
				board.draw_circle(center, radius * 1.45, Color(color, 0.22))
				_draw_star(center, radius, color)
			"ready":
				board.draw_circle(center, radius * 1.9, Color(color, 0.06 + 0.1 * pulse))
				board.draw_arc(center, radius * 1.15, 0, TAU, 40, Color(color, 0.8), 2.0, true)
				_draw_star(center, radius * 0.6, Color(color, 0.55))
			"reachable":
				board.draw_arc(center, radius * 1.1, 0, TAU, 40, Color(color, 0.35), 1.5, true)
				_draw_star(center, radius * 0.5, Color(0.7, 0.75, 0.8, 0.45))
			_:
				board.draw_arc(center, radius, 0, TAU, 32, Color(0.6, 0.65, 0.7, 0.22), 1.2, true)
				board.draw_circle(center, 2.5, Color(0.7, 0.75, 0.8, 0.35))
		if focused == stars.get(id):
			board.draw_arc(center, radius * 1.9, time * 1.5, time * 1.5 + TAU * 0.8, 48, Color(UI.GOLD, 0.95), 2.2, true)
		if armed == id:
			board.draw_arc(center, radius * 2.3, 0, TAU * (armed_time / ARM_TIME), 48, Color(1, 1, 1, 0.8), 1.6, true)
		var caption: String = SkillData.SKILLS[id].title
		var width := 170.0
		var label_color := Color(1, 0.96, 0.86, 0.95) if state == "owned" else (Color(0.9, 0.93, 0.9, 0.85) if state != "locked" else Color(0.7, 0.75, 0.78, 0.55))
		board.draw_string(font_body, center + Vector2(-width * 0.5, radius + 22.0), caption, HORIZONTAL_ALIGNMENT_CENTER, width, 14, label_color)
		if state != "owned" and id != SkillData.ROOT:
			board.draw_string(font_body, center + Vector2(-width * 0.5, radius + 38.0), "✦ %d" % int(SkillData.SKILLS[id].cost), HORIZONTAL_ALIGNMENT_CENTER, width, 12, Color(1, 0.9, 0.62, 0.8 if state != "locked" else 0.4))
	# Leyenda de ramas bajo el título (dentro del árbol se solapaba con los nombres de las estrellas).
	var x := 42.0
	for branch_id in SkillData.BRANCHES:
		var branch: Dictionary = SkillData.BRANCHES[branch_id]
		var caption: String = "✦ " + str(branch.title).to_upper()
		board.draw_string(font_title, Vector2(x, 80.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(branch.color, 0.8))
		x += font_title.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 26.0
	for burst in bursts:
		var t: float = burst.time / 1.2
		var c: Color = burst.color
		board.draw_arc(burst.center, 20.0 + t * 90.0, 0, TAU, 48, Color(c, 1.0 - t), 3.0 * (1.0 - t) + 0.5, true)
		for k in 8:
			var angle := TAU * k / 8.0 + t
			var p: Vector2 = burst.center + Vector2(cos(angle), sin(angle)) * (16.0 + t * 70.0)
			board.draw_circle(p, 3.0 * (1.0 - t), Color(c, 1.0 - t))


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := -PI * 0.5 + i * PI / 4.0
		var r := radius if i % 2 == 0 else radius * 0.38
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	board.draw_colored_polygon(points, color)
	board.draw_circle(center, radius * 0.28, Color(1, 1, 1, 0.9))
