extends RefCounted


static func go_to_intro(tree: SceneTree) -> void:
	tree.change_scene_to_file("res://niveles/intro.tscn")


static func go_to_archivero(tree: SceneTree) -> void:
	tree.change_scene_to_file("res://interface/archivero.tscn")


static func go_to_track_book(tree: SceneTree, track_key: String) -> void:
	tree.change_scene_to_file(Global.get_book_scene_path(track_key))


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	if level_number > 0:
		Global.current_level = clampi(level_number, 1, Global.get_track_level_count(track_key))
	tree.change_scene_to_file(Global.get_level_scene_path(track_key))


static func go_to_resume(tree: SceneTree, resume_state: Dictionary, fallback_scene: String = "res://interface/archivero.tscn") -> void:
	tree.change_scene_to_file(str(resume_state.get("scene_path", fallback_scene)))