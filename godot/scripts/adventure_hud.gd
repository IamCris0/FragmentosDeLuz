extends CanvasLayer

const UI = preload("res://scripts/ui_theme.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ConstellationPanel = preload("res://scripts/constellation_panel.gd")
const LevelData = preload("res://scripts/level_data.gd")
const StoryArt = preload("res://scripts/story_art.gd")
const MAP_SCENE := "res://scenes/archipelago_map.tscn"

var player: CharacterBody3D
var settings: PanelContainer
## Fase 6: las indicaciones cambian a botones de mando cuando se usa uno.
var using_pad: bool = false
const PAD_KEYS := {"interact": "X", "pulse": "Y", "dodge": "B"}
const KEYBOARD_KEYS := {"interact": "E", "pulse": "Q", "dodge": "C"}
var dialog_open: bool = false
var paused: bool = false
var toast_time: float = 0.0
var spoken: String = ""
var revealed: float = 0
var root: Control
var top: Control
var energy_bar: TextureProgressBar
var count_label: Label
var objective_label: Label
var prompt_panel: PanelContainer
var action_label: Label
var zone_label: Label
var toast_label: Label
var dialog: PanelContainer
var speaker_label: Label
var portrait: TextureRect
var dialogue_text: RichTextLabel
var pause_panel: PanelContainer
var journal: PanelContainer
var shade: ColorRect
var volume: HSlider
var confirm_restart: ConfirmationDialog
var tutorial_panel: PanelContainer
var tutorial_label: Label
var threat_panel: PanelContainer
var threat_label: Label
var pulse_bar: TextureProgressBar
var pulse_label: Label
var damage_flash: ColorRect
var pulse_ready: bool = true
var damage_strength: float = 0.0
var dodge_label: Label
var dodge_bar: TextureProgressBar
var guardian_panel: Control
var guardian_caption: Label
var guardian_marks: Array[ColorRect] = []
var guardian_active: bool = false
# --- Fase 7 -------------------------------------------------------------------------------------
var constellation: Control
var destello_label: Label
var destello_gain: Label
var shield_label: Label
var compass_box: Control
var compass_arrow: Label
var compass_text: Label
var level_mode: bool = false


func add(parent: Node, child: Node, node_name: String) -> Node:
	child.name = node_name
	parent.add_child(child)
	return child


func text(parent: Node, name_value: String, value: String, size: int, color: Color = Color("e5ebe3")) -> Label:
	var node: Label = add(parent, Label.new(), name_value)
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.015,0.025,0.035,0.85))
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.036,0.065,0.071,0.95)
	style.border_color = Color("8d8763")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(24)
	return style


func button(parent: Node, node_name: String, caption: String) -> Button:
	var b: Button = add(parent, Button.new(), node_name)
	b.text = caption
	b.custom_minimum_size.y = 42
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 16)
	return b


func build_ui() -> void:
	root = add(self, Control.new(), "HUD")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var body_font := SystemFont.new()
	body_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans"])
	theme.default_font = body_font
	theme.default_font_size = 16
	var normal := panel_style()
	normal.set_content_margin_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("274845")
	hover.border_color = Color("72d6c8")
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_color("font_color", "Button", Color("f0e6c7"))
	root.theme = theme
	var scrim:TextureRect=add(root,TextureRect.new(),"TopShade")
	scrim.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	scrim.offset_bottom=220
	scrim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shading:=GradientTexture2D.new()
	shading.width=16
	shading.height=256
	shading.fill_from=Vector2.ZERO
	shading.fill_to=Vector2(0,1)
	shading.gradient=Gradient.new()
	shading.gradient.colors=PackedColorArray([Color(0.01,0.025,0.03,.42),Color(0.01,0.025,0.03,0)])
	scrim.texture=shading
	top = add(root, Control.new(), "TopBar")
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var section: Control = add(top, Control.new(), "EnergySection")
	section.position = Vector2(26, 22)
	text(section, "PlayerName", "NERI", 14, Color("e4d3a4")).position = Vector2(78, 0)
	text(section, "EnergyLabel", "ENERGÍA", 10, Color("99b4ac")).position = Vector2(267, 5)
	energy_bar = add(section, TextureProgressBar.new(), "EnergyBar")
	energy_bar.position = Vector2(73, 44)
	energy_bar.size = Vector2(272, 19)
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_bar.nine_patch_stretch = true
	var fill := GradientTexture2D.new()
	fill.width = 256
	fill.height = 16
	fill.gradient = Gradient.new()
	fill.gradient.colors = PackedColorArray([Color("257c84"), Color("6ee0bb")])
	energy_bar.texture_progress = fill
	var dark := GradientTexture2D.new()
	dark.width = 256
	dark.height = 16
	dark.gradient = Gradient.new()
	dark.gradient.colors = PackedColorArray([Color("102126"), Color("102126")])
	energy_bar.texture_under = dark
	energy_bar.value = 100
	var frame: TextureRect = add(section, TextureRect.new(), "StoneFrame")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.texture = load("res://assets/ui/energy_frame.png")
	frame.position = Vector2(0, -7)
	frame.size = Vector2(380, 127)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fragment_section: Control = add(top, Control.new(), "FragmentSection")
	text(fragment_section, "Caption", "FRAGMENTOS DEL FARO", 11, Color("c5c4b3"))
	count_label = text(fragment_section, "CountLabel", "0  /  7", 28, Color("f1d893"))
	count_label.position.y = 18
	count_label.size.x = 165
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var objective_box: Control = add(root, Control.new(), "Objective")
	text(objective_box, "Heading", "EL FARO DORMIDO", 11, Color("d4b878"))
	objective_label = text(objective_box, "Description", "Encuentra a Luma junto al arco antiguo", 15)
	objective_label.position.y = 25
	objective_label.size = Vector2(300, 84)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_panel = add(root, PanelContainer.new(), "TutorialPanel")
	var tutorial_style := panel_style()
	tutorial_style.bg_color = Color(0.026, 0.052, 0.058, 0.86)
	tutorial_style.border_color = Color("4ecdc4")
	tutorial_style.set_content_margin_all(12)
	tutorial_panel.add_theme_stylebox_override("panel", tutorial_style)
	var tutorial_box := VBoxContainer.new()
	tutorial_box.name = "VBoxContainer"
	tutorial_box.add_theme_constant_override("separation", 6)
	tutorial_panel.add_child(tutorial_box)
	text(tutorial_box, "Heading", "GUÍA DE CAMPO", 10, Color("80e5d7"))
	tutorial_label = text(tutorial_box, "Text", "", 14)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.custom_minimum_size = Vector2(300, 48)
	var pulse_panel: Control = add(root, Control.new(), "PulseStatus")
	pulse_label = text(pulse_panel, "PulseLabel", "PULSO Q", 10, Color("9ee6d8"))
	pulse_bar = add(pulse_panel, TextureProgressBar.new(), "PulseBar")
	pulse_bar.position = Vector2(0, 19)
	pulse_bar.size = Vector2(180, 11)
	pulse_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pulse_fill := GradientTexture2D.new()
	pulse_fill.width = 128
	pulse_fill.height = 12
	pulse_fill.gradient = Gradient.new()
	pulse_fill.gradient.colors = PackedColorArray([Color("445c67"), Color("72ead3")])
	pulse_bar.texture_progress = pulse_fill
	var pulse_under := GradientTexture2D.new()
	pulse_under.width = 128
	pulse_under.height = 12
	pulse_under.gradient = Gradient.new()
	pulse_under.gradient.colors = PackedColorArray([Color("13282d"), Color("13282d")])
	pulse_bar.texture_under = pulse_under
	pulse_bar.value = 100
	var dodge_panel: Control = add(root, Control.new(), "DodgeStatus")
	dodge_label = text(dodge_panel, "DodgeLabel", "C  ESQUIVA LISTA", 10, Color("e1d596"))
	dodge_bar = add(dodge_panel, TextureProgressBar.new(), "DodgeBar")
	dodge_bar.position = Vector2(0, 19)
	dodge_bar.size = Vector2(180, 6)
	dodge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_bar.texture_under = pulse_under
	var dodge_fill := GradientTexture2D.new()
	dodge_fill.width = 128
	dodge_fill.height = 8
	dodge_fill.gradient = Gradient.new()
	dodge_fill.gradient.colors = PackedColorArray([Color("92754a"), Color("f2d88b")])
	dodge_bar.texture_progress = dodge_fill
	dodge_bar.value = 100
	guardian_panel = add(root, Control.new(), "GuardianStatus")
	guardian_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guardian_title := text(guardian_panel, "Title", "GUARDIÁN DEL FARO", 16, Color("f3dca1"))
	guardian_title.size.x = 330
	guardian_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var mark: ColorRect = add(guardian_panel, ColorRect.new(), "Core%d" % i)
		mark.position = Vector2(i * 112, 27)
		mark.size = Vector2(106, 7)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guardian_caption = text(guardian_panel, "State", "", 11, Color("e9be81"))
	guardian_caption.position.y = 42
	guardian_caption.size.x = 330
	guardian_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guardian_panel.hide()
	threat_panel = add(root, PanelContainer.new(), "ThreatPanel")
	var threat_style := panel_style()
	threat_style.bg_color = Color(0.12, 0.035, 0.055, 0.82)
	threat_style.border_color = Color("f0b66d")
	threat_style.set_content_margin_all(10)
	threat_panel.add_theme_stylebox_override("panel", threat_style)
	threat_label = text(threat_panel, "ThreatLabel", "ECO CERCA", 14, Color("ffd39a"))
	threat_panel.hide()
	zone_label = text(root, "ZoneTitle", "UMBRAL DE AURALIA", 19, Color("e8dec6"))
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Noto Serif"])
	zone_label.add_theme_font_override("font", title_font)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = text(root, "Toast", "", 16, Color("f2d88b"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel = add(root, PanelContainer.new(), "InteractionPrompt")
	var prompt_style := panel_style()
	prompt_style.set_content_margin_all(12)
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	var prompt_row: HBoxContainer = add(prompt_panel, HBoxContainer.new(), "HBoxContainer")
	prompt_row.add_theme_constant_override("separation", 18)
	text(prompt_row, "KeyLabel", "E", 19, Color("8fe9d6"))
	action_label = text(prompt_row, "ActionLabel", "Hablar con Luma", 16)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_panel.hide()
	var pause_button := button(root, "PauseButton", "Ⅱ")
	pause_button.tooltip_text = "Pausa"
	var journal_button := button(root, "JournalButton", "≡")
	journal_button.tooltip_text = "Diario"
	shade = add(root, ColorRect.new(), "ModalShade")
	shade.color = Color(0.008,0.015,0.023,0.64)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	dialog = add(root, PanelContainer.new(), "Dialogue")
	dialog.add_theme_stylebox_override("panel", panel_style())
	var dialogue_box: VBoxContainer = add(dialog, VBoxContainer.new(), "VBoxContainer")
	dialogue_box.add_theme_constant_override("separation", 16)
	speaker_label = text(dialogue_box, "Speaker", "LUMA", 13, Color("e0c889"))
	dialogue_text = add(dialogue_box, RichTextLabel.new(), "Text")
	dialogue_text.bbcode_enabled = false
	dialogue_text.custom_minimum_size.y = 190
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.add_theme_font_size_override("normal_font_size", 19)
	dialogue_text.add_theme_color_override("default_color", Color("e0e7df"))
	button(dialogue_box, "Continue", "Continuar")
	dialog.hide()
	pause_panel = add(root, PanelContainer.new(), "PauseMenu")
	pause_panel.add_theme_stylebox_override("panel", panel_style())
	var menu: VBoxContainer = add(pause_panel, VBoxContainer.new(), "VBoxContainer")
	menu.add_theme_constant_override("separation", 9)
	text(menu, "Title", "Fragmentos de Luz", 25, Color("e8d3a2"))
	text(menu, "Chapter", "CAPÍTULO I · EL FARO DORMIDO", 11, Color("9eafa5"))
	button(menu, "Resume", "Continuar")
	button(menu, "Journal", "Diario de viaje")
	text(menu, "VolumeLabel", "Volumen general", 13)
	volume = add(menu, HSlider.new(), "Volume")
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.01
	volume.value = 0.7
	volume.custom_minimum_size = Vector2(250, 30)
	for bus in ["Music","Ambience","Effects"]:
		var row:HBoxContainer=add(menu,HBoxContainer.new(),bus+"Row")
		var caption:String={"Music":"Música","Ambience":"Ambiente","Effects":"Efectos"}[bus]
		text(row,"Caption",caption,13).custom_minimum_size.x=95
		var slider:HSlider=add(row,HSlider.new(),bus+"Volume")
		slider.min_value=0.
		slider.max_value=1.
		slider.step=.01
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y=24
	var quality_row:HBoxContainer=add(menu,HBoxContainer.new(),"QualityRow")
	text(quality_row,"Caption","Calidad",13).custom_minimum_size.x=95
	var quality:OptionButton=add(quality_row,OptionButton.new(),"Quality")
	for caption in ["Ligera","Equilibrada","Alta"]:quality.add_item(caption)
	quality.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(menu, "Checkpoint", "Volver al refugio")
	button(menu, "NewGame", "Nueva partida")
	button(menu, "Exit", "Salir")
	pause_panel.hide()
	journal = add(root, PanelContainer.new(), "Journal")
	journal.add_theme_stylebox_override("panel", panel_style())
	var journal_box: VBoxContainer = add(journal, VBoxContainer.new(), "VBoxContainer")
	journal_box.add_theme_constant_override("separation", 18)
	text(journal_box, "Title", "Diario de Neri", 26, Color("e6d39f"))
	var journal_text: RichTextLabel = add(journal_box, RichTextLabel.new(), "Entries")
	journal_text.custom_minimum_size = Vector2(450, 220)
	journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_text.add_theme_font_size_override("normal_font_size", 17)
	text(journal_box, "SaveStatus", "", 14, Color("afc8bf"))
	var journal_actions: HBoxContainer = add(journal_box, HBoxContainer.new(), "Actions")
	journal_actions.add_theme_constant_override("separation", 12)
	button(journal_actions, "Save", "Guardar partida").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(journal_actions, "Close", "Cerrar diario").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal.hide()
	confirm_restart = add(root, ConfirmationDialog.new(), "ConfirmRestart")
	confirm_restart.dialog_text = "¿Empezar una nueva partida? Se reemplazará el progreso de este capítulo."
	confirm_restart.title = "Nueva partida"
	confirm_restart.ok_button_text = "Empezar de nuevo"
	confirm_restart.cancel_button_text = "Cancelar"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not has_node("HUD"): build_ui()
	root = $HUD
	top = $HUD/TopBar
	energy_bar = $HUD/TopBar/EnergySection/EnergyBar
	count_label = $HUD/TopBar/FragmentSection/CountLabel
	objective_label = $HUD/Objective/Description
	prompt_panel = $HUD/InteractionPrompt
	action_label = $HUD/InteractionPrompt/HBoxContainer/ActionLabel
	tutorial_panel = $HUD/TutorialPanel
	tutorial_label = $HUD/TutorialPanel/VBoxContainer/Text
	pulse_bar = $HUD/PulseStatus/PulseBar
	pulse_label = $HUD/PulseStatus/PulseLabel
	threat_panel = $HUD/ThreatPanel
	threat_label = $HUD/ThreatPanel/ThreatLabel
	dodge_label = $HUD/DodgeStatus/DodgeLabel
	dodge_bar = $HUD/DodgeStatus/DodgeBar
	guardian_panel = $HUD/GuardianStatus
	guardian_caption = $HUD/GuardianStatus/State
	for i in 3: guardian_marks.append(get_node("HUD/GuardianStatus/Core%d" % i))
	zone_label = $HUD/ZoneTitle
	toast_label = $HUD/Toast
	dialog = $HUD/Dialogue
	speaker_label = $HUD/Dialogue/VBoxContainer/Speaker
	dialogue_text = $HUD/Dialogue/VBoxContainer/Text
	pause_panel = $HUD/PauseMenu
	journal = $HUD/Journal
	shade = $HUD/ModalShade
	volume = $HUD/PauseMenu/VBoxContainer/Volume
	confirm_restart = $HUD/ConfirmRestart
	damage_flash = ColorRect.new()
	damage_flash.name = "DamageFlash"
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(damage_flash)
	var flash_material := ShaderMaterial.new()
	flash_material.shader = load("res://shaders/damage_edge.gdshader")
	damage_flash.material = flash_material
	GameEvents.player_hit.connect(func(_amount: float, _reason: String) -> void: damage_strength = 0.7)
	$HUD/Dialogue/VBoxContainer/Continue.text = "Continuar"
	$HUD/Dialogue/VBoxContainer/Continue.pressed.connect(close_dialogue)
	$HUD/PauseButton.pressed.connect(toggle_pause)
	$HUD/JournalButton.pressed.connect(open_journal)
	$HUD/PauseMenu/VBoxContainer/Resume.pressed.connect(toggle_pause)
	$HUD/PauseMenu/VBoxContainer/Journal.pressed.connect(open_journal)
	$HUD/PauseMenu/VBoxContainer/Checkpoint.pressed.connect(func() -> void: toggle_pause(); player.respawn())
	$HUD/PauseMenu/VBoxContainer/NewGame.pressed.connect(func() -> void: confirm_restart.popup_centered(Vector2i(460,160)))
	confirm_restart.confirmed.connect(new_game)
	$HUD/PauseMenu/VBoxContainer/Exit.pressed.connect(exit_game)
	$HUD/Journal/VBoxContainer/Actions/Close.pressed.connect(close_journal)
	$HUD/Journal/VBoxContainer/Actions/Save.pressed.connect(func() -> void: GameEvents.save_game(true))
	GameEvents.save_status_changed.connect(func(_success: bool, message: String) -> void: $HUD/Journal/VBoxContainer/SaveStatus.text = message)
	volume.set_value_no_signal(Preferences.volumes.Master)
	volume.value_changed.connect(func(value: float) -> void: Preferences.set_volume("Master",value))
	for bus in ["Music","Ambience","Effects"]:
		var slider:HSlider=get_node("HUD/PauseMenu/VBoxContainer/%sRow/%sVolume"%[bus,bus])
		slider.set_value_no_signal(Preferences.volumes[bus])
		slider.value_changed.connect(func(value: float) -> void: Preferences.set_volume(bus,value))
	var quality:OptionButton=$HUD/PauseMenu/VBoxContainer/QualityRow/Quality
	quality.select(Preferences.quality)
	quality.item_selected.connect(Preferences.set_quality)
	GameEvents.fragments_changed.connect(update_fragments)
	GameEvents.energy_changed.connect(update_energy)
	GameEvents.objective_changed.connect(func(value: String) -> void: objective_label.text = value)
	GameEvents.story_requested.connect(show_dialogue)
	GameEvents.toast_requested.connect(show_toast)
	GameEvents.zone_changed.connect(func(_index: int, title: String) -> void: zone_label.text = title)
	GameEvents.tutorial_changed.connect(update_tutorial)
	GameEvents.threat_changed.connect(update_threat)
	GameEvents.pulse_changed.connect(update_pulse)
	GameEvents.dodge_changed.connect(update_dodge)
	GameEvents.guardian_changed.connect(update_guardian)
	update_tutorial(GameEvents.tutorial_stage, GameEvents.tutorial_text)
	update_threat(GameEvents.active_threats)
	_phase6_ui()
	_phase7_ui()
	get_viewport().size_changed.connect(layout)
	get_viewport().size_changed.connect(func() -> void: _place_portrait.call_deferred())
	layout()


## Fase 6: tipografías propias, panel de ajustes compartido y regreso al menú principal.
func _phase6_ui() -> void:
	root.theme = UI.build_theme()
	for path in ["ZoneTitle", "PauseMenu/VBoxContainer/Title", "Journal/VBoxContainer/Title", "GuardianStatus/Title", "Dialogue/VBoxContainer/Speaker", "Objective/Heading", "TutorialPanel/VBoxContainer/Heading", "TopBar/EnergySection/PlayerName", "TopBar/FragmentSection/Caption"]:
		var node := root.get_node_or_null(path) as Control
		if node: node.add_theme_font_override("font", UI.font("title"))
	for path in ["TopBar/FragmentSection/CountLabel"]:
		var node := root.get_node_or_null(path) as Control
		if node: node.add_theme_font_override("font", UI.font("title_semibold"))
	dialogue_text.add_theme_font_override("normal_font", UI.font("body"))
	($HUD/Journal/VBoxContainer/Entries as RichTextLabel).add_theme_font_override("normal_font", UI.font("body"))
	var menu: VBoxContainer = $HUD/PauseMenu/VBoxContainer
	for path in ["VolumeLabel", "Volume", "MusicRow", "AmbienceRow", "EffectsRow", "QualityRow"]:
		var node := menu.get_node_or_null(path) as Control
		if node: node.hide()
	var settings_button := button(menu, "Settings", "Ajustes")
	menu.move_child(settings_button, menu.get_node("Journal").get_index() + 1)
	settings_button.pressed.connect(open_settings)
	var title_button := button(menu, "MainMenu", "Menú principal")
	menu.move_child(title_button, menu.get_node("Exit").get_index())
	title_button.pressed.connect(return_to_title)
	settings = SettingsPanel.new()
	settings.build()
	root.add_child(settings)
	settings.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if paused:
		pause_panel.show()
		$HUD/PauseMenu/VBoxContainer/Settings.grab_focus()


func open_settings() -> void:
	pause_panel.hide()
	settings.open()


func return_to_title() -> void:
	if not GameEvents.save_game():
		var notice := AcceptDialog.new()
		notice.title = "No se pudo guardar"
		notice.dialog_text = GameEvents.save_status + "\nSigues en la partida para no perder el progreso."
		notice.confirmed.connect(notice.queue_free)
		notice.canceled.connect(notice.queue_free)
		add_child(notice)
		notice.popup_centered(Vector2i(420, 150))
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_menu.tscn")


func layout() -> void:
	var dimensions: Vector2 = get_viewport().get_visible_rect().size
	var narrow: bool = dimensions.x < 1050
	root.get_node("TopBar/FragmentSection").position = Vector2(dimensions.x-218, 30)
	root.get_node("Objective").position = Vector2(40, 127)
	tutorial_panel.position = Vector2(40, dimensions.y - (214 if not narrow else 190))
	tutorial_panel.size = Vector2(342 if not narrow else minf(330, dimensions.x - 80), 94)
	root.get_node("PulseStatus").position = Vector2(40, dimensions.y - 96)
	root.get_node("DodgeStatus").position = Vector2(40, dimensions.y - 52)
	guardian_panel.position = Vector2(dimensions.x - 350, 150) if narrow else Vector2(dimensions.x * 0.5 - 165, 74)
	guardian_panel.size = Vector2(330, 66)
	threat_panel.position = Vector2(dimensions.x*.5-85, dimensions.y-208)
	threat_panel.size = Vector2(170, 43)
	zone_label.position = Vector2(dimensions.x*.5-210, 26 if not narrow else 104)
	zone_label.size = Vector2(420, 32)
	zone_label.visible = dimensions.x >= 800
	toast_label.position = Vector2(dimensions.x*.5-250, dimensions.y-150)
	toast_label.size = Vector2(500, 28)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if narrow:
		tutorial_panel.position = Vector2(24, dimensions.y-285)
		toast_label.position.y = dimensions.y-165
		toast_label.size.y = 48
	prompt_panel.position = Vector2(dimensions.x*.5-165, dimensions.y-91)
	prompt_panel.size = Vector2(330, 48)
	root.get_node("PauseButton").position = Vector2(dimensions.x-72, dimensions.y-77)
	root.get_node("PauseButton").size = Vector2(42,42)
	root.get_node("JournalButton").position = Vector2(dimensions.x-125, dimensions.y-77)
	root.get_node("JournalButton").size = Vector2(42,42)
	dialog.size = Vector2(minf(840, dimensions.x-64), 345)
	dialog.position = Vector2((dimensions.x-dialog.size.x)*.5, dimensions.y-dialog.size.y-35)
	pause_panel.size = Vector2(400, 0)
	pause_panel.size = Vector2(400, pause_panel.get_combined_minimum_size().y)
	pause_panel.position = (dimensions-pause_panel.size)*.5
	if settings:
		settings.size = settings.get_combined_minimum_size()
		settings.position = ((dimensions-settings.size)*.5).max(Vector2.ZERO)
	journal.size = Vector2(minf(680,dimensions.x-64),530)
	journal.position = (dimensions-journal.size)*.5
	journal.get_node("VBoxContainer/Entries").custom_minimum_size.x = journal.size.x-48
	if destello_label:
		root.get_node("DestelloBank").position = Vector2(dimensions.x-218, 84)
		shield_label.position = Vector2(236, dimensions.y - 52)
		compass_box.position = Vector2(dimensions.x*.5-60, 66 if not narrow else 140)


func _process(delta: float) -> void:
	var modal_open: bool = dialog_open or paused or journal.visible
	var modal_open_7: bool = modal_open or (constellation != null and constellation.visible)
	if level_mode:
		tutorial_panel.visible = not modal_open_7 and GameEvents.hint != ""
	else:
		tutorial_panel.visible = not modal_open_7 and not GameEvents.completed and not GameEvents.tutorial_text.is_empty()
	_update_phase7(delta, modal_open_7)
	threat_panel.visible = not modal_open and GameEvents.active_threats > 0
	guardian_panel.visible = guardian_active and not modal_open
	var flash: ShaderMaterial = damage_flash.material
	damage_strength = maxf(0.0, damage_strength - delta * 1.7)
	flash.set_shader_parameter("strength", damage_strength)
	if is_instance_valid(player):
		var item: Node = player.target
		prompt_panel.visible = is_instance_valid(item) and not dialog_open and not paused and not journal.visible
		if prompt_panel.visible: action_label.text = item.current_prompt() if item.has_method("current_prompt") else item.prompt
	if toast_time > 0:
		toast_time -= delta
		toast_label.modulate.a = minf(toast_time,1)
	if dialog_open:
		revealed += delta * 65
		dialogue_text.visible_characters = int(revealed)
	pulse_label.modulate = Color("e6fff9") if pulse_ready else Color("9bb5b4")


func update_fragments(current: int, total: int) -> void:
	count_label.text = "%d  /  %d" % [current,total]


func update_energy(current: float, maximum: float) -> void:
	energy_bar.value = current / maxf(maximum,0.01) * 100


func update_tutorial(_stage: int, value: String) -> void:
	if level_mode: return
	tutorial_label.text = value
	tutorial_panel.visible = value != "" and not GameEvents.completed


func update_threat(count: int) -> void:
	threat_panel.visible = count > 0 and not paused and not dialog_open
	threat_label.text = "ECO CERCA" if count == 1 else "ECOS CERCA x%d" % count


func key(action: String) -> String:
	return (PAD_KEYS if using_pad else KEYBOARD_KEYS)[action]


func update_pulse(ratio: float, ready: bool) -> void:
	pulse_ready = ready
	pulse_bar.value = ratio * 100.0
	if is_instance_valid(player) and player.pulse_charging:
		pulse_label.text = key("pulse") + ("  NOVA LISTA" if player.pulse_charge >= player.NOVA_CHARGE else "  CARGANDO NOVA")
		return
	pulse_label.text = key("pulse") + ("  PULSO LISTO" if ready else ("  SIN ENERGÍA" if ratio >= 0.999 else "  RECARGANDO"))


func update_dodge(ratio: float, ready: bool) -> void:
	dodge_bar.value = ratio * 100.0
	dodge_label.text = key("dodge") + ("  ESQUIVA LISTA" if ready else ("  SIN ENERGÍA" if ratio >= 0.999 else "  RECUPERANDO"))


func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	var desk: bool = event is InputEventKey or event is InputEventMouseButton
	if (pad and not using_pad) or (desk and using_pad):
		using_pad = pad
		var key_label := root.get_node_or_null("InteractionPrompt/HBoxContainer/KeyLabel") as Label
		if key_label: key_label.text = key("interact")


func update_guardian(active: bool, integrity: int, state: String) -> void:
	guardian_active = active
	var guardian_title := guardian_panel.get_node_or_null("Title") as Label
	if guardian_title: guardian_title.text = GameEvents.boss_title
	guardian_caption.text = state
	for i in guardian_marks.size():
		guardian_marks[i].color = Color("f4cb83") if i < integrity else Color("3b4648")


func show_toast(value: String) -> void:
	toast_label.text = value
	toast_time = 4
	toast_label.modulate.a = 1


func show_dialogue(speaker: String, value: String) -> void:
	dialog_open = true
	spoken = value
	revealed = 0
	speaker_label.text = speaker
	_update_portrait(speaker)
	dialogue_text.text = value
	dialogue_text.visible_characters = 0
	dialog.show()
	shade.show()
	player.locked = true
	player.camera_drag=false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Fase 7: retrato opcional del personaje que habla (assets/ui/portraits/, ver docs/PROMPTS_IA.md),
## asomado sobre la esquina superior izquierda del cuadro de diálogo.
func _update_portrait(speaker: String) -> void:
	var art: Texture2D = StoryArt.portrait(speaker)
	if art == null:
		if portrait: portrait.hide()
		return
	if portrait == null:
		portrait = TextureRect.new()
		portrait.name = "DialoguePortrait"
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dialog.get_parent().add_child(portrait)
		dialog.get_parent().move_child(portrait, dialog.get_index() + 1)
	portrait.texture = art
	portrait.show()
	_place_portrait.call_deferred()


func _place_portrait() -> void:
	if portrait == null or not portrait.visible or not dialog.visible: return
	var rect: Rect2 = dialog.get_rect()
	var side: float = clampf(rect.size.y * 0.62, 110.0, 190.0)
	var top: float = rect.position.y - side * 0.78
	if top < 8.0:
		portrait.hide()
		return
	portrait.size = Vector2(side, side)
	portrait.position = Vector2(rect.position.x + 14.0, top)


func close_dialogue() -> void:
	if dialogue_text.visible_characters >= 0 and dialogue_text.visible_characters < spoken.length():
		revealed = spoken.length()
		dialogue_text.visible_characters = -1
		return
	dialog_open = false
	dialog.hide()
	shade.hide()
	if portrait: portrait.hide()
	player.locked = false
	player.interaction_lock = 0.3


func toggle_pause() -> void:
	if GameEvents.cinematic_active: return
	if constellation and constellation.visible:
		constellation.close()
		return
	if settings and settings.visible: settings.hide()
	if dialog_open:
		dialog_open = false
		dialog.hide()
		if portrait: portrait.hide()
	if journal.visible: journal.hide()
	paused = not paused
	pause_panel.visible = paused
	shade.visible = paused
	get_tree().paused = paused
	player.locked = paused
	player.camera_drag = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if paused: $HUD/PauseMenu/VBoxContainer/Resume.grab_focus.call_deferred()


func open_journal() -> void:
	if dialog_open or GameEvents.cinematic_active: return
	if settings and settings.visible: settings.hide()
	pause_panel.hide()
	paused = false
	journal.show()
	shade.show()
	get_tree().paused = true
	player.locked = true
	player.camera_drag=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var entries: RichTextLabel = $HUD/Journal/VBoxContainer/Entries
	$HUD/Journal/VBoxContainer/SaveStatus.text = GameEvents.save_status
	if level_mode:
		entries.text = _level_journal()
		$HUD/Journal/VBoxContainer/Actions/Close.grab_focus.call_deferred()
		return
	entries.text = "AURALIA · LA CIUDAD SUSPENDIDA\n\n" + GameEvents.objective + "\n\n"
	entries.text += "Fragmentos recuperados: %d / 7\n\n" % GameEvents.collected
	entries.text += "Umbral de Auralia -> Jardín de Ecos -> Paso del Cielo -> Faro de Auralia\n\n"
	entries.text += "Pulso de luz: Q. Aturde ecos cercanos y consume energía del escáner.\n"
	entries.text += "Esquiva: C. Una rodada breve; también puedes saltar las ondas del guardián.\n"
	entries.text += "Ecos purificados: %d\n\n" % GameEvents.enemies_purified
	if GameEvents.story_seen.has("luma_intro"):
		entries.text += "Luma: primero la OLA, después el SOL y al final la ESTRELLA.\n\n"
	entries.text += "El jardín ya recuerda su melodía." if GameEvents.puzzle_solved else "Las tres runas esperan su secuencia."
	entries.text += "\n\nMEMORIAS DE AURALIA · %d / %d\n" % [GameEvents.lore_count(), GameEvents.LORE_TOTAL]
	for id in GameEvents.LORE_TITLES:
		entries.text += ("· " + GameEvents.LORE_TITLES[id] + "\n") if GameEvents.story_seen.has(id) else "· ???\n"
	if GameEvents.completed:
		entries.text += "\n" + _archipelago_summary()
	entries.text += "\n\n" + _controls_text()
	$HUD/Journal/VBoxContainer/Actions/Close.grab_focus.call_deferred()


func close_journal() -> void:
	journal.hide()
	shade.hide()
	get_tree().paused = false
	player.locked = false


func new_game() -> void:
	get_tree().paused = false
	GameEvents.reset()
	get_tree().change_scene_to_file("res://scenes/prologue_comic.tscn")


func exit_game() -> void:
	if GameEvents.save_game():
		get_tree().quit()
	else:
		var notice := AcceptDialog.new()
		notice.title = "No se pudo guardar"
		notice.dialog_text = GameEvents.save_status + "\nEl juego permanece abierto."
		notice.confirmed.connect(notice.queue_free)
		notice.canceled.connect(notice.queue_free)
		add_child(notice)
		notice.popup_centered(Vector2i(420, 150))


func _unhandled_input(event: InputEvent) -> void:
	if GameEvents.cinematic_active:
		return
	if constellation and constellation.visible:
		return
	if event.is_action_pressed("constellation") and not dialog_open:
		open_constellation()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if journal.visible: close_journal()
		else: open_journal()
		get_viewport().set_input_as_handled()
	elif dialog_open and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		close_dialogue()
		get_viewport().set_input_as_handled()


# --- Fase 7: destellos, Constelación, pistas de nivel, égida, brújula y carta ----------------------

var constellation_from_pause: bool = false
var compass_target: Node3D
var compass_distance: float = 0.0
var gain_time: float = 0.0


func _phase7_ui() -> void:
	level_mode = GameEvents.level != "auralia"
	var info: Dictionary = LevelData.level(GameEvents.level)
	var bank := Control.new()
	bank.name = "DestelloBank"
	bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bank)
	destello_label = UI.label("✦ %d" % GameEvents.destellos, 20, Color("fff1c9"), "title_semibold")
	destello_label.name = "Count"
	destello_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	destello_label.size = Vector2(165, 28)
	bank.add_child(destello_label)
	destello_gain = UI.label("", 16, UI.GOLD, "body_bold")
	destello_gain.name = "Gain"
	destello_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	destello_gain.size = Vector2(165, 24)
	destello_gain.position.y = 28
	bank.add_child(destello_gain)
	GameEvents.destellos_changed.connect(_on_destellos)
	shield_label = text(root, "ShieldStatus", "", 10, Color("f7d0c4"))
	shield_label.hide()
	GameEvents.shield_changed.connect(_on_shield)
	compass_box = Control.new()
	compass_box.name = "Compass"
	compass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_box.custom_minimum_size = Vector2(120, 64)
	compass_box.draw.connect(_draw_compass)
	root.add_child(compass_box)
	compass_text = UI.label("", 13, Color("fff1c9"), "body_bold")
	compass_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_text.size = Vector2(120, 20)
	compass_text.position = Vector2(0, 44)
	compass_box.add_child(compass_text)
	compass_box.hide()
	var menu: VBoxContainer = $HUD/PauseMenu/VBoxContainer
	var star_button := button(menu, "Constellation", "Constelación")
	menu.move_child(star_button, menu.get_node("Journal").get_index() + 1)
	star_button.pressed.connect(func() -> void: open_constellation(true))
	var map_button := button(menu, "Map", "Carta del archipiélago")
	menu.move_child(map_button, star_button.get_index() + 1)
	map_button.visible = GameEvents.completed
	map_button.pressed.connect(open_map)
	if level_mode:
		(root.get_node("TopBar/FragmentSection/Caption") as Label).text = "DESTELLOS DE LA ISLA"
		count_label.text = "%d  /  %d" % [GameEvents.level_destellos(), int(info.destellos)]
		(root.get_node("Objective/Heading") as Label).text = str(info.title).to_upper()
		($HUD/PauseMenu/VBoxContainer/Chapter as Label).text = "CAPÍTULO II · " + str(info.title).to_upper()
		(root.get_node("TutorialPanel/VBoxContainer/Heading") as Label).text = "GUÍA DE LUMA"
		menu.get_node("NewGame").hide()
		GameEvents.level_progress_changed.connect(_on_level_progress)
		GameEvents.hint_changed.connect(func(value: String) -> void: tutorial_label.text = value)
		tutorial_label.text = GameEvents.hint
		zone_label.text = str(info.title).to_upper()
	elif GameEvents.completed:
		($HUD/PauseMenu/VBoxContainer/Chapter as Label).text = "AURALIA · EL FARO RESTAURADO"
	constellation = ConstellationPanel.new()
	constellation.build()
	root.add_child(constellation)
	constellation.closed.connect(_on_constellation_closed)
	_on_shield(GameEvents.shield_ready, 1.0 if GameEvents.shield_ready else 0.0)


func _on_level_progress(_caption: String, current: int, total: int) -> void:
	count_label.text = "%d  /  %d" % [current, total]


func _on_destellos(balance: int, gained: int) -> void:
	destello_label.text = "✦ %d" % balance
	if gained > 0:
		destello_gain.text = "+%d ✦" % gained
		gain_time = 2.2
		if not GameEvents.story_seen.has("hint_constellation") and not level_mode and not GameEvents.completed:
			GameEvents.story_seen["hint_constellation"] = true
			show_toast("Has ganado un destello. Pulsa K para abrir tu Constelación.")


func _on_shield(ready: bool, ratio: float) -> void:
	if not shield_label: return
	shield_label.visible = GameEvents.has_skill("aegis")
	shield_label.text = "◈  ÉGIDA LISTA" if ready else "◈  ÉGIDA %d %%" % int(ratio * 100.0)
	shield_label.modulate = Color(1, 1, 1, 1) if ready else Color(1, 1, 1, 0.6)


func _update_phase7(delta: float, modal: bool) -> void:
	# El panel de la guía crece hacia arriba: su borde inferior queda fijo sobre los medidores.
	var view := get_viewport().get_visible_rect().size
	tutorial_panel.position.y = view.y - (120.0 if view.x >= 1050 else 191.0) - tutorial_panel.size.y
	if gain_time > 0.0:
		gain_time -= delta
		destello_gain.modulate.a = clampf(gain_time, 0.0, 1.0)
		destello_gain.position.y = 28.0 - (2.2 - gain_time) * 6.0
	var show_compass: bool = level_mode and not modal and GameEvents.has_skill("compass") and is_instance_valid(player)
	compass_target = null
	if show_compass:
		var best := INF
		for node in get_tree().get_nodes_in_group("destello"):
			if not is_instance_valid(node) or not node.is_visible_in_tree() or node.get("taken") == true: continue
			var distance: float = player.global_position.distance_to(node.global_position)
			if distance < best:
				best = distance
				compass_target = node
		compass_distance = best
	compass_box.visible = show_compass and compass_target != null
	if compass_box.visible:
		compass_text.text = "✦ %d m" % int(round(compass_distance))
		compass_box.queue_redraw()


func _draw_compass() -> void:
	if not is_instance_valid(compass_target) or not is_instance_valid(player): return
	var camera := get_viewport().get_camera_3d()
	if not camera: return
	var offset: Vector3 = camera.global_basis.inverse() * (compass_target.global_position - player.global_position)
	var angle := atan2(offset.x, -offset.z)
	var center := Vector2(60, 22)
	var forward := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-forward.y, forward.x)
	var tip := center + forward * 17.0
	var points := PackedVector2Array([tip, center - forward * 9.0 + side * 10.0, center - forward * 3.0, center - forward * 9.0 - side * 10.0])
	compass_box.draw_circle(center, 21.0, Color(0.03, 0.06, 0.07, 0.72))
	compass_box.draw_arc(center, 21.0, 0, TAU, 40, Color(UI.GOLD, 0.6), 1.5, true)
	compass_box.draw_colored_polygon(points, UI.GOLD)


func open_constellation(from_pause: bool = false) -> void:
	if dialog_open or GameEvents.cinematic_active or not constellation: return
	if settings and settings.visible: settings.hide()
	constellation_from_pause = from_pause or paused
	pause_panel.hide()
	journal.hide()
	paused = false
	shade.hide()
	get_tree().paused = true
	player.locked = true
	player.camera_drag = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	constellation.open()


func _on_constellation_closed() -> void:
	if constellation_from_pause:
		paused = true
		pause_panel.show()
		shade.show()
		$HUD/PauseMenu/VBoxContainer/Constellation.grab_focus.call_deferred()
		return
	get_tree().paused = false
	player.locked = false
	player.interaction_lock = 0.3


func open_map() -> void:
	if not GameEvents.completed: return
	if not GameEvents.save_game():
		var notice := AcceptDialog.new()
		notice.title = "No se pudo guardar"
		notice.dialog_text = GameEvents.save_status + "\nSigues en la partida para no perder el progreso."
		notice.confirmed.connect(notice.queue_free)
		notice.canceled.connect(notice.queue_free)
		add_child(notice)
		notice.popup_centered(Vector2i(420, 150))
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(MAP_SCENE)


func _level_journal() -> String:
	var id: String = GameEvents.level
	var info: Dictionary = LevelData.level(id)
	var body := "%s · %s\n\n%s\n\n" % [str(info.title).to_upper(), str(info.subtitle), GameEvents.objective]
	body += "Destellos de la isla: %d / %d\n" % [GameEvents.level_destellos(id), int(info.destellos)]
	body += "Memorias: %d / %d\n" % [GameEvents.level_memories(id), info.memories.size()]
	body += "%s: %s\n" % [str(info.key_title), "obtenida" if GameEvents.is_level_done(id) else "aún oculta"]
	body += "Destellos para la Constelación: ✦ %d  (K o cruceta arriba)\n\n" % GameEvents.destellos
	body += "RECORRIDO\n" + " -> ".join(PackedStringArray(info.zones)) + "\n\n"
	body += "MEMORIAS DE LA ISLA\n"
	for memory in info.memories:
		body += ("· " + str(LevelData.MEMORY_TITLES.get(memory, "")) + "\n") if GameEvents.story_seen.has(memory) else "· ???\n"
	body += "\n" + _archipelago_summary() + "\n\n" + _controls_text()
	return body


func _archipelago_summary() -> String:
	var body := "EL ARCHIPIÉLAGO\n"
	for id in LevelData.ORDER:
		if id == "auralia": continue
		var info: Dictionary = LevelData.level(id)
		var state := "completada" if GameEvents.is_level_done(id) else ("disponible" if GameEvents.is_level_unlocked(id) else "sin descubrir")
		body += "· %s: %s · destellos %d/%d\n" % [str(info.title), state, GameEvents.level_destellos(id), int(info.destellos)]
	return body


func _controls_text() -> String:
	var body := "CONTROLES\nTeclado: WASD mover · Shift correr · Espacio saltar · E interactuar · Q pulso · C esquivar · K constelación · clic derecho cámara · Esc pausa · J diario.\n"
	body += "Mando: stick izquierdo mover · stick derecho cámara · A saltar · X interactuar · Y pulso · B esquivar · cruceta arriba constelación · LB/L3 correr · Start pausa · Select diario."
	if GameEvents.has_skill("glide"): body += "\nPlaneo: mantén saltar en el aire. Las corrientes ascendentes te elevan."
	if GameEvents.has_skill("double_jump"): body += "\nDoble salto: pulsa saltar otra vez en el aire."
	if GameEvents.has_skill("pulse_nova"): body += "\nNova: mantén el pulso y suéltalo cuando brille."
	return body
