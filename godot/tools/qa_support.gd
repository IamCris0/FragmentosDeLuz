extends RefCounted


static func output_folder(category: String) -> String:
	var base := OS.get_environment("FDL_QA_OUTPUT")
	if base.is_empty(): base = ProjectSettings.globalize_path("res://../previews/")
	var folder := base.path_join(category)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder + "/"


static func release_audio(root: Node) -> void:
	var players := root.find_children("*", "AudioStreamPlayer", true, false)
	players.append_array(root.find_children("*", "AudioStreamPlayer2D", true, false))
	players.append_array(root.find_children("*", "AudioStreamPlayer3D", true, false))
	for node in players:
		node.stop()
		node.stream = null
	# The audio thread needs wall time to release playback instances. Fixed-FPS
	# scene timers can finish before even one device buffer has been mixed.
	var deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < deadline:
		await root.get_tree().process_frame


static func finish(tree: SceneTree, exit_code: int) -> void:
	tree.paused = true
	await release_audio(tree.root)
	tree.quit(exit_code)
