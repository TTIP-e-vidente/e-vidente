extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const ROUTE_SPLASH := "splash"
const ROUTE_MAIN_MENU := "main_menu"
const ROUTE_MODE_SELECTOR := "mode_selector"
const ROUTE_MAP := "map"
const ROUTE_ARCHIVERO := "archivero"
const ROUTE_OPTIONS := "options"
const ROUTE_PROFILE := "profile"
const ROUTE_QUESTIONS := "questions"

const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const MAIN_MENU_SCENE_PATH := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const OPTIONS_SCENE_PATH := "res://interface/opciones.tscn"
const PROFILE_SCENE_PATH := "res://interface/auth.tscn"
const QUESTIONS_SCENE_PATH := "res://preguntas/pregunta.tscn"

const RESUME_SCENE_PATH_KEY := "scene_path"


static func go_to_route(
	tree: SceneTree,
	route_name: String,
	fallback_route: String = ROUTE_MODE_SELECTOR
) -> void:
	var scene_path: String = _resolve_route_scene_path(route_name, fallback_route)
	_change_scene_to_path(tree, scene_path)


static func go_to_splash(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_SPLASH)


static func go_to_main_menu(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_MAIN_MENU)


static func go_to_mode_selector(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_MODE_SELECTOR)


static func go_to_map(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_MAP)


static func go_to_archivero(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_ARCHIVERO)


static func go_to_options(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_OPTIONS)


static func go_to_profile_editor(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_PROFILE)


static func go_to_questions(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_QUESTIONS)


static func go_to_track_book(tree: SceneTree, track_key: String) -> void:
	var scene_path: String = GameTrackCatalog.get_book_scene_path(track_key)
	if scene_path.is_empty():
		scene_path = MODE_SELECTOR_SCENE_PATH
	_change_scene_to_path(tree, scene_path)


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	_store_requested_level(tree, track_key, level_number)
	var scene_path: String = GameTrackCatalog.get_level_scene_path(track_key)
	if scene_path.is_empty():
		scene_path = MODE_SELECTOR_SCENE_PATH
	_change_scene_to_path(tree, scene_path)


static func go_to_resume(
	tree: SceneTree,
	resume_state: Dictionary,
	fallback_scene: String = MODE_SELECTOR_SCENE_PATH
) -> void:
	var scene_path: String = str(resume_state.get(RESUME_SCENE_PATH_KEY, fallback_scene)).strip_edges()
	var safe_scene_path: String = scene_path if not scene_path.is_empty() else fallback_scene
	_change_scene_to_path(tree, safe_scene_path)


static func _resolve_route_scene_path(route_name: String, fallback_route: String) -> String:
	var scene_path: String = _get_scene_path_for_route(route_name)
	if scene_path.is_empty():
		scene_path = _get_scene_path_for_route(fallback_route)
	if scene_path.is_empty():
		return MODE_SELECTOR_SCENE_PATH
	return scene_path


static func _get_scene_path_for_route(route_name: String) -> String:
	match route_name:
		ROUTE_SPLASH:
			return SPLASH_SCENE_PATH
		ROUTE_MAIN_MENU:
			return MAIN_MENU_SCENE_PATH
		ROUTE_MODE_SELECTOR:
			return MODE_SELECTOR_SCENE_PATH
		ROUTE_MAP:
			return MAP_SCENE_PATH
		ROUTE_ARCHIVERO:
			return ARCHIVERO_SCENE_PATH
		ROUTE_OPTIONS:
			return OPTIONS_SCENE_PATH
		ROUTE_PROFILE:
			return PROFILE_SCENE_PATH
		ROUTE_QUESTIONS:
			return QUESTIONS_SCENE_PATH
	return ""


static func _store_requested_level(
	tree: SceneTree,
	track_key: String,
	level_number: int
) -> void:
	if level_number < 1:
		return
	var global_state := _get_global_state(tree)
	if global_state != null:
		global_state.set_current_level_number(level_number, track_key)


static func _change_scene_to_path(tree: SceneTree, scene_path: String) -> void:
	if tree == null:
		return
	tree.change_scene_to_file(scene_path)


static func _get_global_state(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_root().get_node_or_null("Global")
