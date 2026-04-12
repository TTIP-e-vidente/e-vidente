extends RefCounted

const SPLASH_SCENE := "res://interface/evidente.tscn"
const MAIN_MENU_SCENE := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE := "res://niveles/selector.tscn"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const OPTIONS_SCENE := "res://interface/opciones.tscn"
const PROFILE_SCENE := "res://interface/auth.tscn"
const QUESTIONS_SCENE := "res://preguntas/pregunta.tscn"


static func go_to_splash(tree: SceneTree) -> void:
	_change_scene(tree, SPLASH_SCENE)


static func go_to_main_menu(tree: SceneTree) -> void:
	_change_scene(tree, MAIN_MENU_SCENE)


static func go_to_intro(tree: SceneTree) -> void:
	go_to_main_menu(tree)


static func go_to_mode_selector(tree: SceneTree) -> void:
	_change_scene(tree, MODE_SELECTOR_SCENE)


static func go_to_archivero(tree: SceneTree) -> void:
	_change_scene(tree, ARCHIVERO_SCENE)


static func go_to_options(tree: SceneTree) -> void:
	_change_scene(tree, OPTIONS_SCENE)


static func go_to_profile_editor(tree: SceneTree) -> void:
	_change_scene(tree, PROFILE_SCENE)


static func go_to_questions(tree: SceneTree) -> void:
	_change_scene(tree, QUESTIONS_SCENE)


static func go_to_track_book(tree: SceneTree, track_key: String) -> void:
	_change_scene(tree, Global.get_book_scene_path(track_key))


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	if level_number > 0:
		Global.current_level = clampi(level_number, 1, Global.get_track_level_count(track_key))
	_change_scene(tree, Global.get_level_scene_path(track_key))


static func go_to_resume(
	tree: SceneTree,
	resume_state: Dictionary,
	fallback_scene: String = ARCHIVERO_SCENE
) -> void:
	_change_scene(tree, str(resume_state.get("scene_path", fallback_scene)))


static func _change_scene(tree: SceneTree, scene_path: String) -> void:
	tree.change_scene_to_file(scene_path)