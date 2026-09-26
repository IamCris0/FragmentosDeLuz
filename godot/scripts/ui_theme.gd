extends RefCounted
## Tipografías y estilos compartidos por el menú, el HUD, el prólogo y las cinemáticas.
## Cinzel (títulos) y Nunito (texto) se distribuyen con licencia SIL OFL 1.1 (assets/fonts/OFL.txt).

const GOLD := Color("f1d48b")
const GOLD_DEEP := Color("d4af37")
const TEAL := Color("4ecdc4")
const TEAL_LIGHT := Color("8fe9d6")
const INK := Color("e9f0e7")
const PANEL := Color(0.036, 0.065, 0.071, 0.95)

static var _cache: Dictionary = {}


static func font(kind: String) -> Font:
	if _cache.has(kind):
		return _cache[kind]
	var files := {
		"title": "res://assets/fonts/Cinzel-Bold.woff2",
		"title_semibold": "res://assets/fonts/Cinzel-SemiBold.woff2",
		"logo": "res://assets/fonts/CinzelDecorative-Bold.woff2",
		"body": "res://assets/fonts/Nunito-Regular.woff2",
		"body_bold": "res://assets/fonts/Nunito-Bold.woff2",
		"body_heavy": "res://assets/fonts/Nunito-ExtraBold.woff2",
	}
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans"])
	var result: Font = fallback
	if files.has(kind) and ResourceLoader.exists(files[kind]):
		var loaded: FontFile = load(files[kind])
		if loaded:
			var variation := FontVariation.new()
			variation.base_font = loaded
			variation.fallbacks = [fallback]
			result = variation
	_cache[kind] = result
	return result


static func panel_style(fill: Color = PANEL, border: Color = Color("8d8763"), margin: float = 24.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	return style


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font("body")
	theme.default_font_size = 16
	var normal := panel_style(Color(0.035, 0.07, 0.075, 0.9), Color("6f6a4e"), 10)
	normal.shadow_size = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1f3d3a")
	hover.border_color = TEAL
	var focus := hover.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("2a5550")
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "CheckButton", empty)
	var check_focus := StyleBoxFlat.new()
	check_focus.bg_color = Color(0, 0, 0, 0)
	check_focus.border_color = GOLD
	check_focus.set_border_width_all(1)
	check_focus.set_corner_radius_all(10)
	theme.set_stylebox("focus", "CheckButton", check_focus)
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, normal)
		theme.set_stylebox("hover", kind, hover)
		theme.set_stylebox("pressed", kind, pressed)
		theme.set_stylebox("focus", kind, focus)
		theme.set_color("font_color", kind, Color("f0e6c7"))
		theme.set_color("font_hover_color", kind, Color("ffffff"))
		theme.set_color("font_focus_color", kind, Color("fff4d2"))
		theme.set_font("font", kind, font("body_bold"))
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color("13282d")
	slider_track.set_corner_radius_all(3)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	var slider_fill := slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = Color("3fb6a8")
	theme.set_stylebox("slider", "HSlider", slider_track)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	theme.set_color("font_color", "Label", INK)
	theme.set_font("normal_font", "RichTextLabel", font("body"))
	theme.set_font("bold_font", "RichTextLabel", font("body_heavy"))
	return theme


static func label(text: String, size: int, color: Color = INK, kind: String = "body") -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font(kind))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.03, 0.85))
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
