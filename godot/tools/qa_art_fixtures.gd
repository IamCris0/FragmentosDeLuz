extends RefCounted
## Fase 7: imágenes de ensayo para probar los huecos de ilustraciones externas (scripts/story_art.gd)
## sin tocar las carpetas del proyecto. Se escriben en user://qa_art/ con la misma estructura.

const ROOT := "user://qa_art/"


static func build() -> String:
	for folder in ["assets/story/postcards", "assets/ui/portraits", "assets/ui/skills"]:
		DirAccess.make_dir_recursive_absolute(ROOT + folder)
	var colors := [Color("2f3a56"), Color("4a7b5f"), Color("8c5e3c"), Color("1abfb3")]
	# Hoja 2×2 del interludio y del epílogo (una viñeta por color, con un marco claro).
	for name in ["chapter2_comic", "chapter2_ending"]:
		var sheet := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.WHITE)
		for i in 4:
			var cell := Rect2i(Vector2i(i % 2 * 640 + 6, i / 2 * 360 + 6), Vector2i(628, 348))
			sheet.fill_rect(cell, colors[i])
			sheet.fill_rect(Rect2i(cell.position + Vector2i(250, 120), Vector2i(128, 108)), Color("d4af37"))
		sheet.save_png(ROOT + "assets/story/%s.png" % name)
	for id in ["auralia", "grutas", "cefiro", "observatorio"]:
		var card := Image.create(640, 360, false, Image.FORMAT_RGBA8)
		card.fill(Color("6d5a9e") if id == "grutas" else Color("3a6f8f"))
		card.fill_rect(Rect2i(0, 240, 640, 120), Color("e9e2f5"))
		card.fill_rect(Rect2i(280, 90, 80, 150), Color("f1d48b"))
		card.save_png(ROOT + "assets/story/postcards/%s.png" % id)
	for id in ["luma", "neri", "maren"]:
		var face := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		face.fill(Color(0, 0, 0, 0))
		var tint: Color = {"luma": Color("1abfb3"), "neri": Color("8c5e3c"), "maren": Color("cfe8ff")}[id]
		for y in 256:
			for x in 256:
				if Vector2(x - 128, y - 128).length() < 110: face.set_pixel(x, y, tint)
		face.save_png(ROOT + "assets/ui/portraits/%s.png" % id)
	var icons := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	icons.fill(Color("0b1020"))
	for i in 16:
		var cell := Rect2i(Vector2i(i % 4 * 128 + 16, i / 4 * 128 + 16), Vector2i(96, 96))
		icons.fill_rect(cell, Color.from_hsv(float(i) / 16.0, 0.6, 0.95))
	icons.save_png(ROOT + "assets/ui/skills/skills_sheet.png")
	return ROOT
