extends RefCounted
## Fase 7: ilustraciones opcionales hechas fuera del motor (Gemini, ChatGPT...). Si un archivo existe
## en su ruta, el juego lo usa; si no, todo sigue funcionando con el arte procedural.
## Rutas y tamaños recomendados: docs/PROMPTS_IA.md.
##
##   assets/story/chapter2_comic_1.png … _4.png   Viñetas del interludio (16:9 cada una), o bien
##   assets/story/chapter2_comic.png              una sola hoja 2×2 con las cuatro viñetas.
##   assets/story/postcards/<isla>.png            Postal de cada isla en la carta (16:9).
##   assets/ui/portraits/<luma|neri|maren>.png    Retrato para los diálogos (cuadrado, fondo transparente).
##   assets/ui/skills/<habilidad>.png             Icono de cada estrella de la constelación (cuadrado), o
##   assets/ui/skills/skills_sheet.png            una hoja 4×4 en el orden de SKILL_SHEET_ORDER.

const SKILL_SHEET_ORDER := ["core", "pulse_wide", "pulse_quick", "pulse_nova", "pulse_daze", "agile_roll", "stride",
	"double_jump", "serene_glide", "vitality", "ember", "aegis", "compass"]

static var cache: Dictionary = {}
## Carpeta raíz de las ilustraciones (las pruebas la cambian a user:// con imágenes de ensayo).
static var base: String = "res://"


## Carga una imagen importada por Godot o, si aún no se ha importado (recién copiada), directamente del disco.
static func texture(path: String) -> Texture2D:
	if cache.has(path): return cache[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		result = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(path if not path.begins_with("res://") else ProjectSettings.globalize_path(path))
		if image and not image.is_empty():
			image.generate_mipmaps()
			result = ImageTexture.create_from_image(image)
	cache[path] = result
	return result


static func _first(paths: Array) -> Texture2D:
	for path in paths:
		var found := texture(str(path))
		if found: return found
	return null


static func _any(base: String) -> Texture2D:
	return _first([base + ".png", base + ".jpg", base + ".webp"])


## Viñetas de un cómic: cuatro archivos sueltos o una hoja 2×2 recortada.
static func comic_panels(name: String) -> Array[Texture2D]:
	var panels: Array[Texture2D] = []
	for i in range(1, 5):
		var panel := _any(base + "assets/story/%s_%d" % [name, i])
		if panel: panels.append(panel)
	if panels.size() == 4: return panels
	panels.clear()
	var sheet := _any(base + "assets/story/" + name)
	if not sheet: return panels
	var half := sheet.get_size() * 0.5
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(i % 2, i / 2) * half + Vector2(4, 4), half - Vector2(8, 8))
		panels.append(atlas)
	return panels


static func postcard(level_id: String) -> Texture2D:
	return _any(base + "assets/story/postcards/" + level_id)


## Retrato según el nombre que aparece en el diálogo («LUMA · GRUTAS…» → luma).
static func portrait(speaker: String) -> Texture2D:
	var key := speaker.strip_edges().to_lower().get_slice(" ", 0)
	if not key in ["luma", "neri", "maren"]: return null
	return _any(base + "assets/ui/portraits/" + key)


static func skill_icon(skill_id: String) -> Texture2D:
	var single := _any(base + "assets/ui/skills/" + skill_id)
	if single: return single
	var sheet := _any(base + "assets/ui/skills/skills_sheet")
	var index := SKILL_SHEET_ORDER.find(skill_id)
	if not sheet or index < 0: return null
	var cell := sheet.get_size() / 4.0
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2(index % 4, index / 4) * cell + Vector2(2, 2), cell - Vector2(4, 4))
	return atlas
