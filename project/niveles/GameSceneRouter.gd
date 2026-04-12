extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const SPLASH_SCENE := "res://interface/evidente.tscn"
const MAIN_MENU_SCENE := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE := "res://niveles/selector.tscn"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const OPTIONS_SCENE := "res://interface/opciones.tscn"
const PROFILE_SCENE := "res://interface/auth.tscn"
const QUESTIONS_SCENE := "res://preguntas/pregunta.tscn"


static func go_to_splash(tree: SceneTree) -> void:
	_change_scene_to_path(tree, SPLASH_SCENE)


static func go_to_main_menu(tree: SceneTree) -> void:
	_change_scene_to_path(tree, MAIN_MENU_SCENE)


static func go_to_intro(tree: SceneTree) -> void:
	go_to_main_menu(tree)


static func go_to_mode_selector(tree: SceneTree) -> void:
	_change_scene_to_path(tree, MODE_SELECTOR_SCENE)


static func go_to_archivero(tree: SceneTree) -> void:
	_change_scene_to_path(tree, ARCHIVERO_SCENE)


static func go_to_options(tree: SceneTree) -> void:
	_change_scene_to_path(tree, OPTIONS_SCENE)


static func go_to_profile_editor(tree: SceneTree) -> void:
	_change_scene_to_path(tree, PROFILE_SCENE)


static func go_to_questions(tree: SceneTree) -> void:
	_change_scene_to_path(tree, QUESTIONS_SCENE)


static func go_to_track_book(tree: SceneTree, track_key: String) -> void:
	_change_to_track_book_scene(tree, track_key)


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	_sync_requested_track_level(track_key, level_number)
	_change_to_track_level_scene(tree, track_key)


static func go_to_resume(
	tree: SceneTree,
	resume_state: Dictionary,
	fallback_scene: String = ARCHIVERO_SCENE
) -> void:
	_change_scene_to_path(tree, _resolve_resume_scene_path(resume_state, fallback_scene))


static func _change_to_track_book_scene(tree: SceneTree, track_key: String) -> void:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	var scene_path := str(track_definition.get("book_scene_path", ARCHIVERO_SCENE)).strip_edges()
	_change_scene_to_path(tree, scene_path if not scene_path.is_empty() else ARCHIVERO_SCENE)


static func _change_to_track_level_scene(tree: SceneTree, track_key: String) -> void:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	var scene_path := str(track_definition.get("level_scene_path", ARCHIVERO_SCENE)).strip_edges()
	_change_scene_to_path(tree, scene_path if not scene_path.is_empty() else ARCHIVERO_SCENE)


static func _sync_requested_track_level(track_key: String, level_number: int) -> void:
	if level_number <= 0:
		return
	Global.set_current_level_number(level_number, track_key)


static func _resolve_resume_scene_path(
	resume_state: Dictionary,
	fallback_scene: String
) -> String:
	return str(resume_state.get("scene_path", fallback_scene))


static func _change_scene_to_path(tree: SceneTree, scene_path: String) -> void:
	tree.change_scene_to_file(scene_path)