extends SceneTree
## Fase 7: genera las escenas de las islas del archipiélago.
## Uso: godot --headless --path godot --script res://tools/build_levels.gd -- [grutas] [cefiro] [observatorio]
## Sin argumentos genera todas. Las escenas resultantes (scenes/levels/*.tscn) son editables, pero
## regenerarlas sobrescribe los cambios manuales: guarda una copia antes.

const Kit = preload("res://tools/level_kit.gd")
const BUILDERS := {
	"grutas": "res://tools/levels/grutas_builder.gd",
	"cefiro": "res://tools/levels/cefiro_builder.gd",
	"observatorio": "res://tools/levels/observatorio_builder.gd",
}


func _initialize() -> void:
	build.call_deferred()


func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/levels")
	var requested: Array = []
	for arg in OS.get_cmdline_user_args():
		if BUILDERS.has(arg): requested.append(arg)
	if requested.is_empty(): requested = BUILDERS.keys()
	for id in requested:
		if not ResourceLoader.exists(BUILDERS[id]):
			print("LEVEL_SKIPPED ", id)
			continue
		var world := Node3D.new()
		world.name = str(id).capitalize().replace(" ", "")
		var kit := Kit.new(world, hash(id) % 100000)
		var builder: Script = load(BUILDERS[id])
		builder.build(kit)
		kit.save("res://scenes/levels/%s.tscn" % id)
		world.free()
	quit()
