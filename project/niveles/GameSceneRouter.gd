extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameStreakDebugScript := preload("res://niveles/progress/GameStreakDebug.gd")

const ROUTE_SPLASH := "splash"
const ROUTE_MAIN_MENU := "main_menu"
const ROUTE_MODE_SELECTOR := "mode_selector"
const ROUTE_MAP := "map"
const ROUTE_ARCHIVERO := "archivero"
const ROUTE_STREAK := "streak"
const ROUTE_OPTIONS := "options"
const ROUTE_PROFILE := "profile"
const ROUTE_QUESTIONS := "questions"

const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const MAIN_MENU_SCENE_PATH := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const STREAK_SCENE_PATH := "res://interface/components/ProgressManagerRacha.tscn"
const OPTIONS_SCENE_PATH := "res://interface/opciones.tscn"
const PROFILE_SCENE_PATH := "res://interface/auth.tscn"
const QUESTIONS_SCENE_PATH := "res://preguntas/pregunta.tscn"

const RESUME_SCENE_PATH_KEY := "scene_path"
const CONTINUE_TARGET_RETURN_TO_KEY := "return_to"
const CONTINUE_TARGET_RETURN_SCENE_PATH_KEY := "return_scene_path"
const STREAK_RETURN_TO_META := "streak_return_to"
const STREAK_FEEDBACK_META := "streak_feedback"
const STREAK_CONTINUE_TARGET_META := "streak_continue_target"

static var _preloaded_scenes: Dictionary = {}
static var _pending_preload_paths: Dictionary = {}


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


static func go_to_streak(
	tree: SceneTree,
	return_to: String = "",
	feedback: Dictionary = {},
	continue_target: Dictionary = {}
) -> void:
	if tree == null:
		return
	var tree_root: Window = tree.get_root()
	var router_continue_target: Dictionary = build_router_target_from_flow_target(
		continue_target
	)
	if tree_root != null:
		set_streak_return_to(tree, return_to)

		if not feedback.is_empty():
			tree_root.set_meta(STREAK_FEEDBACK_META, feedback.duplicate(true))
		elif tree_root.has_meta(STREAK_FEEDBACK_META):
			tree_root.remove_meta(STREAK_FEEDBACK_META)

		if not router_continue_target.is_empty():
			tree_root.set_meta(
				STREAK_CONTINUE_TARGET_META,
				GameStreakDebugScript.sanitize_continue_target(router_continue_target)
			)
		elif tree_root.has_meta(STREAK_CONTINUE_TARGET_META):
			tree_root.remove_meta(STREAK_CONTINUE_TARGET_META)
	_change_scene_to_path(tree, STREAK_SCENE_PATH)


static func go_to_options(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_OPTIONS)


static func go_to_profile_editor(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_PROFILE)


static func go_to_questions(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_QUESTIONS)


static func set_streak_return_to(tree: SceneTree, return_to: String) -> void:
	if tree == null:
		return
	var tree_root: Window = tree.get_root()
	if tree_root == null:
		return
	var safe_return_to: String = return_to.strip_edges()
	if safe_return_to.is_empty():
		if tree_root.has_meta(STREAK_RETURN_TO_META):
			tree_root.remove_meta(STREAK_RETURN_TO_META)
		return
	tree_root.set_meta(STREAK_RETURN_TO_META, safe_return_to)


static func read_streak_return_to(
	tree: SceneTree,
	fallback_scene_path: String = MAP_SCENE_PATH
) -> String:
	if tree == null:
		return fallback_scene_path
	var tree_root: Window = tree.get_root()
	if tree_root == null:
		return fallback_scene_path
	if not tree_root.has_meta(STREAK_RETURN_TO_META):
		return fallback_scene_path
	var return_to: String = str(tree_root.get_meta(STREAK_RETURN_TO_META, "")).strip_edges()
	if return_to.is_empty():
		return fallback_scene_path
	return return_to


static func consume_streak_return_to(
	tree: SceneTree,
	fallback_scene_path: String = MAP_SCENE_PATH
) -> String:
	var safe_return_to: String = read_streak_return_to(tree, fallback_scene_path)
	if tree == null:
		return safe_return_to
	var tree_root: Window = tree.get_root()
	if tree_root != null and tree_root.has_meta(STREAK_RETURN_TO_META):
		tree_root.remove_meta(STREAK_RETURN_TO_META)
	return safe_return_to


# target interno:
# - return_to es el nombre principal.
# - return_scene_path queda aceptado solo como compatibilidad legacy.
static func build_router_target_from_flow_target(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	var router_target: Dictionary = GameStreakDebugScript.sanitize_continue_target(target)
	if router_target.has(CONTINUE_TARGET_RETURN_SCENE_PATH_KEY):
		router_target[CONTINUE_TARGET_RETURN_TO_KEY] = read_return_to(router_target, MAP_SCENE_PATH)
		router_target.erase(CONTINUE_TARGET_RETURN_SCENE_PATH_KEY)
	return router_target


static func read_return_to(
	source: Dictionary,
	fallback_scene_path: String = MAP_SCENE_PATH
) -> String:
	if source.is_empty():
		return fallback_scene_path
	var return_to: String = str(
		source.get(
			CONTINUE_TARGET_RETURN_TO_KEY,
			source.get(CONTINUE_TARGET_RETURN_SCENE_PATH_KEY, fallback_scene_path)
		)
	).strip_edges()
	if return_to.is_empty():
		return fallback_scene_path
	return return_to


static func request_scene_preload(scene_path: String) -> void:
	var normalized_scene_path: String = scene_path.strip_edges()
	if normalized_scene_path.is_empty():
		return
	if _preloaded_scenes.has(normalized_scene_path):
		return
	if _pending_preload_paths.has(normalized_scene_path):
		_finalize_scene_preload(normalized_scene_path)
		return
	if ResourceLoader.has_cached(normalized_scene_path):
		var cached_resource: Resource = load(normalized_scene_path)
		if cached_resource is PackedScene:
			_preloaded_scenes[normalized_scene_path] = cached_resource
		return
	var request_error: Error = ResourceLoader.load_threaded_request(
		normalized_scene_path,
		"PackedScene"
	)
	if request_error == OK:
		_pending_preload_paths[normalized_scene_path] = true


static func request_initial_scene_preload() -> void:
	request_scene_preload(MAIN_MENU_SCENE_PATH)
	request_scene_preload(MODE_SELECTOR_SCENE_PATH)
	request_scene_preload(MAP_SCENE_PATH)
	request_scene_preload(
		GameTrackCatalog.obtener_ruta_escena_nivel(GameTrackCatalog.TRACK_CELIAQUIA)
	)


static func go_to_track_book(tree: SceneTree, track_key: String) -> void:
	var scene_path: String = GameTrackCatalog.obtener_ruta_escena_libro(track_key)
	if scene_path.is_empty():
		scene_path = MODE_SELECTOR_SCENE_PATH
	_change_scene_to_path(tree, scene_path)


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	_store_requested_level(tree, track_key, level_number)
	var scene_path: String = GameTrackCatalog.obtener_ruta_escena_nivel(track_key)
	if scene_path.is_empty():
		scene_path = MODE_SELECTOR_SCENE_PATH
	_change_scene_to_path(tree, scene_path)


static func go_to_target(
	tree: SceneTree,
	target: Dictionary,
	fallback_scene_path: String = MODE_SELECTOR_SCENE_PATH
) -> void:
	if tree == null:
		return

	var router_target: Dictionary = build_router_target_from_flow_target(target)
	var target_type: String = str(router_target.get("type", "")).strip_edges()
	match target_type:
		"map":
			_clear_active_playable_session(tree)
			go_to_map(tree)
		"map_continue":
			var global_state := _get_global_state(tree)
			var node_key: String = str(router_target.get("node_key", "")).strip_edges()
			if (
				global_state != null
				and not node_key.is_empty()
				and global_state.has_method("solicitar_continuar")
			):
				global_state.call("solicitar_continuar", node_key)
			_clear_active_playable_session(tree)
			_change_scene_to_path(tree, read_return_to(router_target, MAP_SCENE_PATH))
		"track_level":
			_clear_active_playable_session(tree)
			go_to_track_level(
				tree,
				str(router_target.get("track_key", "")).strip_edges(),
				int(router_target.get("level_number", -1))
			)
		"track_book":
			_clear_active_playable_session(tree)
			go_to_track_book(
				tree,
				str(router_target.get("track_key", "")).strip_edges()
			)
		"scene_path":
			_clear_active_playable_session(tree)
			var scene_path: String = str(
				router_target.get("scene_path", fallback_scene_path)
			).strip_edges()
			_change_scene_to_path(
				tree,
				scene_path if not scene_path.is_empty() else fallback_scene_path
			)
		_:
			_clear_active_playable_session(tree)
			_change_scene_to_path(tree, fallback_scene_path)


static func go_to_continue_target(
	tree: SceneTree,
	continue_target: Dictionary,
	fallback_scene_path: String = MODE_SELECTOR_SCENE_PATH
) -> void:
	go_to_target(tree, continue_target, fallback_scene_path)


static func go_to_resume(
	tree: SceneTree,
	resume_state: Dictionary,
	fallback_scene: String = MODE_SELECTOR_SCENE_PATH
) -> void:
	var scene_path: String = str(
		resume_state.get(RESUME_SCENE_PATH_KEY, fallback_scene)
	).strip_edges()
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
		ROUTE_STREAK:
			return STREAK_SCENE_PATH
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
		global_state.establecer_actual_nivel_numero(level_number, track_key)


static func _change_scene_to_path(tree: SceneTree, scene_path: String) -> void:
	if tree == null:
		return
	var preloaded_scene: PackedScene = _take_preloaded_scene(scene_path)
	if preloaded_scene != null:
		tree.change_scene_to_packed(preloaded_scene)
		return
	tree.change_scene_to_file(scene_path)


static func _take_preloaded_scene(scene_path: String) -> PackedScene:
	var normalized_scene_path: String = scene_path.strip_edges()
	if normalized_scene_path.is_empty():
		return null
	if _preloaded_scenes.has(normalized_scene_path):
		return _preloaded_scenes[normalized_scene_path] as PackedScene
	_finalize_scene_preload(normalized_scene_path)
	if _preloaded_scenes.has(normalized_scene_path):
		return _preloaded_scenes[normalized_scene_path] as PackedScene
	return null


static func _finalize_scene_preload(scene_path: String) -> void:
	if not _pending_preload_paths.has(scene_path):
		return
	var status: int = ResourceLoader.load_threaded_get_status(scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var loaded_resource: Resource = ResourceLoader.load_threaded_get(scene_path)
		if loaded_resource is PackedScene:
			_preloaded_scenes[scene_path] = loaded_resource
		_pending_preload_paths.erase(scene_path)
		return
	if (
		status == ResourceLoader.THREAD_LOAD_FAILED
		or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	):
		_pending_preload_paths.erase(scene_path)


static func _get_global_state(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_root().get_node_or_null("Global")


static func _clear_active_playable_session(tree: SceneTree) -> void:
	var global_state := _get_global_state(tree)
	if global_state != null and global_state.has_method("limpiar_sesion_nodo_jugable_activo"):
		global_state.call("limpiar_sesion_nodo_jugable_activo")
