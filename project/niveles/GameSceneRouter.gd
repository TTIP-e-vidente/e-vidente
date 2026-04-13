extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const MAIN_MENU_SCENE_PATH := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const OPTIONS_SCENE_PATH := "res://interface/opciones.tscn"
const PROFILE_SCENE_PATH := "res://interface/auth.tscn"
const QUESTIONS_SCENE_PATH := "res://preguntas/pregunta.tscn"

const BOOK_SCENE_PATH_KEY := "book_scene_path"    # clave en TRACK_DEFINITIONS
const LEVEL_SCENE_PATH_KEY := "level_scene_path"  # clave en TRACK_DEFINITIONS
const RESUME_SCENE_PATH_KEY := "scene_path"        # clave en resume_state


static func go_to_splash(tree: SceneTree) -> void:
	_change_scene_to_path(tree, SPLASH_SCENE_PATH)


static func go_to_main_menu(tree: SceneTree) -> void:
	_change_scene_to_path(tree, MAIN_MENU_SCENE_PATH)


static func go_to_intro(tree: SceneTree) -> void:
	go_to_main_menu(tree)


static func go_to_mode_selector(tree: SceneTree) -> void:
	_change_scene_to_path(tree, MODE_SELECTOR_SCENE_PATH)


static func go_to_archivero(tree: SceneTree) -> void:
	_change_scene_to_path(tree, ARCHIVERO_SCENE_PATH)


static func go_to_options(tree: SceneTree) -> void:
	_change_scene_to_path(tree, OPTIONS_SCENE_PATH)


static func go_to_profile_editor(tree: SceneTree) -> void:
	_change_scene_to_path(tree, PROFILE_SCENE_PATH)


static func go_to_questions(tree: SceneTree) -> void:
	_change_scene_to_path(tree, QUESTIONS_SCENE_PATH)


static func go_to_track_book(tree: SceneTree, track_key: String) -> void:
	_change_scene_to_path(tree, _resolve_track_scene_path(track_key, BOOK_SCENE_PATH_KEY))


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	if level_number > 0:
		Global.set_current_level_number(level_number, track_key)
	_change_scene_to_path(tree, _resolve_track_scene_path(track_key, LEVEL_SCENE_PATH_KEY))


static func go_to_resume(
	tree: SceneTree,
	resume_state: Dictionary,
	fallback_scene: String = ARCHIVERO_SCENE_PATH
) -> void:
	var scene_path := str(resume_state.get(RESUME_SCENE_PATH_KEY, fallback_scene))
	_change_scene_to_path(tree, scene_path)


static func _resolve_track_scene_path(track_key: String, scene_path_key: String) -> String:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	var scene_path := str(track_definition.get(scene_path_key, ARCHIVERO_SCENE_PATH)).strip_edges()
	return scene_path if not scene_path.is_empty() else ARCHIVERO_SCENE_PATH


static func _change_scene_to_path(tree: SceneTree, scene_path: String) -> void:
	tree.change_scene_to_file(scene_path)
