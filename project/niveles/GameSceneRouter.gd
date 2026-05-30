extends Node

# GameSceneRouter.gd
# Punto unico para cambiar de escena.
# Recibe targets simples y decide que escena abrir sin que la UI duplique rutas.

const ModalidadRouter := preload("res://sistemas/ModalidadRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

enum TransitionType { FADE, IRIS }

var _is_transitioning := false

const ROUTE_SPLASH := "splash"
const ROUTE_MAIN_MENU := "main_menu"
const ROUTE_MODE_SELECTOR := "mode_selector"
const ROUTE_MAP := "map"
const ROUTE_ARCHIVERO := "archivero"
const ROUTE_STREAK := "streak"
const ROUTE_OPTIONS := "options"
const ROUTE_PROFILE := "profile"
const ROUTE_QUESTIONS := "questions"
const ROUTE_VINCULACION := "vinculacion"

const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const MAIN_MENU_SCENE_PATH := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const STREAK_SCENE_PATH := "res://interface/components/ProgressManagerRacha.tscn"
const OPTIONS_SCENE_PATH := "res://interface/opciones.tscn"
const PROFILE_SCENE_PATH := "res://interface/auth.tscn"
const QUESTIONS_SCENE_PATH := "res://preguntas/pregunta.tscn"
const LEVEL_SCENE_PATH := "res://niveles/nivel_1/Level.tscn"
const VINCULACION_CONCEPTOS_SCENE_PATH := "res://vincular/VincularConceptos.tscn"
const COMPLETAR_PALABRA_SCENE_PATH := "res://completar/completar_palabra.tscn"
const FINALIZACION_PARTIDA_SCENE_PATH := "res://mapas/finalizacion_partida.tscn"

const ROUTES := {
	ROUTE_SPLASH: SPLASH_SCENE_PATH,
	ROUTE_MAIN_MENU: MAIN_MENU_SCENE_PATH,
	ROUTE_MODE_SELECTOR: MODE_SELECTOR_SCENE_PATH,
	ROUTE_MAP: MAP_SCENE_PATH,
	ROUTE_ARCHIVERO: ARCHIVERO_SCENE_PATH,
	ROUTE_STREAK: STREAK_SCENE_PATH,
	ROUTE_OPTIONS: OPTIONS_SCENE_PATH,
	ROUTE_PROFILE: PROFILE_SCENE_PATH,
	ROUTE_QUESTIONS: QUESTIONS_SCENE_PATH,
	ROUTE_VINCULACION: VINCULACION_CONCEPTOS_SCENE_PATH,
}

const MODE_TO_SCENE_PATH := {
	"drag_drop": LEVEL_SCENE_PATH,
	"quiz_choice": QUESTIONS_SCENE_PATH,
	"vinculacion_conceptos": VINCULACION_CONCEPTOS_SCENE_PATH,
	"completar_palabra": COMPLETAR_PALABRA_SCENE_PATH,
}

const RESUME_SCENE_PATH_KEY := "scene_path"
const CONTINUE_TARGET_RETURN_TO_KEY := "return_to"
const CONTINUE_TARGET_RETURN_SCENE_PATH_KEY := "return_scene_path"
const STREAK_RETURN_TO_META := "streak_return_to"
const STREAK_FEEDBACK_META := "streak_feedback"
const STREAK_CONTINUE_TARGET_META := "streak_continue_target"
const LOG_PREFIX := "[ROUTER]"

static var _preloaded_scenes: Dictionary = {}
static var _pending_preload_paths: Dictionary = {}


# --- Rutas publicas ---------------------------------------------------------

static func go_to_route(
	tree: SceneTree,
	route_name: String,
	fallback_route: String = ROUTE_MODE_SELECTOR
) -> void:
	var scene_path: String = _resolve_route_scene_path(route_name, fallback_route)
	_change_scene_to_path(tree, scene_path)


static func go_to_splash(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_SPLASH)


static func go_to_main_menu(_tree: SceneTree) -> void:
	await TransicionEscenas.change_normal_scene(MAIN_MENU_SCENE_PATH)


static func go_to_mode_selector(_tree: SceneTree) -> void:
	await TransicionEscenas.change_normal_scene(MODE_SELECTOR_SCENE_PATH)


static func go_to_map(_tree: SceneTree) -> void:
	await TransicionEscenas.change_normal_scene(MAP_SCENE_PATH)


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
				router_continue_target.duplicate(true)
			)
		elif tree_root.has_meta(STREAK_CONTINUE_TARGET_META):
			tree_root.remove_meta(STREAK_CONTINUE_TARGET_META)
	await TransicionEscenas.change_scene(STREAK_SCENE_PATH)


static func go_to_options(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_OPTIONS)


static func go_to_profile_editor(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_PROFILE)


static func go_to_questions(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_QUESTIONS)


static func go_to_vinculacion(tree: SceneTree) -> void:
	go_to_route(tree, ROUTE_VINCULACION)


static func go_to_level(tree: SceneTree) -> void:
	_change_scene_to_path(tree, LEVEL_SCENE_PATH)


static func get_scene_path_for_mode(mode: String) -> String:
	var normalized_mode := ModalidadRouter.normalizar_modo(mode)
	if not MODE_TO_SCENE_PATH.has(normalized_mode):
		push_error(LOG_PREFIX + " Modalidad sin escena asignada: " + str(mode))
		return ""
	return MODE_TO_SCENE_PATH[normalized_mode]


static func ir_a_modo_jugable(tree: SceneTree, content_mode: String) -> void:
	var archivo_actual := _obtener_json_actual_debug(tree)
	print(LOG_PREFIX, " abriendo_siguiente tipo=", content_mode.strip_edges(), " archivo=", archivo_actual)
	
	var scene_path := get_scene_path_for_mode(content_mode)
	if scene_path.is_empty():
		return
		
	await TransicionEscenas.change_scene(scene_path)


static func _obtener_json_actual_debug(tree: SceneTree) -> String:
	var global_state := _get_global_state(tree)
	if global_state != null and global_state.has_method("obtener_juego_actual_de_partida"):
		var juego_actual: Variant = global_state.call("obtener_juego_actual_de_partida")
		if juego_actual is Dictionary:
			return str((juego_actual as Dictionary).get("json_path", "")).strip_edges()
	return ""


# --- Racha ------------------------------------------------------------------

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


# --- Targets ----------------------------------------------------------------

# target interno:
# - return_to es el nombre principal.
# - return_scene_path queda aceptado solo como compatibilidad legacy.
static func build_router_target_from_flow_target(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	var router_target: Dictionary = target.duplicate(true)
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


# --- Precarga ---------------------------------------------------------------

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


# --- Navegacion de tracks ---------------------------------------------------

static func go_to_track_book(_tree: SceneTree, track_key: String) -> void:
	var scene_path: String = GameTrackCatalog.obtener_ruta_escena_libro(track_key)
	if scene_path.is_empty():
		scene_path = MODE_SELECTOR_SCENE_PATH
	await TransicionEscenas.change_scene(scene_path)


static func go_to_track_level(tree: SceneTree, track_key: String, level_number: int = -1) -> void:
	_store_requested_level(tree, track_key, level_number)
	var scene_path: String = GameTrackCatalog.obtener_ruta_escena_nivel(track_key)
	if scene_path.is_empty():
		scene_path = MODE_SELECTOR_SCENE_PATH
	await TransicionEscenas.change_scene(scene_path)


# --- Navegacion por target --------------------------------------------------

static func go_to_target(
	tree: SceneTree,
	target: Dictionary,
	fallback_scene_path: String = MODE_SELECTOR_SCENE_PATH
) -> void:
	if tree == null:
		return

	var router_target: Dictionary = build_router_target_from_flow_target(target)
	var target_type: String = str(router_target.get("type", "")).strip_edges()
	print(LOG_PREFIX, " target=", router_target, " fallback=", fallback_scene_path)
	if target_type.is_empty():
		push_error("[ROUTER] Target inválido: %s" % JSON.stringify(router_target))
		return
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
		"playable_mode":
			ir_a_modo_jugable(
				tree,
				str(router_target.get("mode", "")).strip_edges()
			)
		"resume":
			go_to_resume(
				tree,
				_read_resume_state(router_target),
				fallback_scene_path
			)
		_:
			push_error("[ROUTER] Target inválido: %s" % JSON.stringify(router_target))
			print(LOG_PREFIX, " target_desconocido=", router_target)


static func go_to_continue_target(
	tree: SceneTree,
	fallback_return_to: String = ""
) -> void:
	var fallback_scene_path: String = fallback_return_to.strip_edges()
	if fallback_scene_path.is_empty():
		fallback_scene_path = MODE_SELECTOR_SCENE_PATH
	var global_state := _get_global_state(tree)
	if global_state == null or not global_state.has_method("obtener_destino_de_continuacion"):
		await GameSceneRouter.change_scene(fallback_scene_path)
		return
	var continue_target: Variant = global_state.call("obtener_destino_de_continuacion")
	if not continue_target is Dictionary or (continue_target as Dictionary).is_empty():
		await TransicionEscenas.change_normal_scene(fallback_scene_path)
		return
	go_to_target(tree, continue_target as Dictionary, fallback_scene_path)


# --- Navegacion por target --------------------------------------------------

static func go_to_target(
	tree: SceneTree,
	target: Dictionary,
	fallback_scene_path: String = MODE_SELECTOR_SCENE_PATH
) -> void:
	if tree == null:
		return

	var router_target: Dictionary = build_router_target_from_flow_target(target)
	var target_type: String = str(router_target.get("type", "")).strip_edges()
	print(LOG_PREFIX, " target=", router_target, " fallback=", fallback_scene_path)
	if target_type.is_empty():
		push_error("[ROUTER] Target inválido: %s" % JSON.stringify(router_target))
		return
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
		"playable_mode":
			ir_a_modo_jugable(
				tree,
				str(router_target.get("mode", "")).strip_edges()
			)
		"resume":
			go_to_resume(
				tree,
				_read_resume_state(router_target),
				fallback_scene_path
			)
		_:
			push_error("[ROUTER] Target inválido: %s" % JSON.stringify(router_target))
			print(LOG_PREFIX, " target_desconocido=", router_target)


static func go_to_continue_target(
	tree: SceneTree,
	fallback_return_to: String = ""
) -> void:
	var fallback_scene_path: String = fallback_return_to.strip_edges()
	if fallback_scene_path.is_empty():
		fallback_scene_path = MODE_SELECTOR_SCENE_PATH
	var global_state := _get_global_state(tree)
	if global_state == null or not global_state.has_method("obtener_destino_de_continuacion"):
		_change_scene_to_path(tree, fallback_scene_path)
		return
	var continue_target: Variant = global_state.call("obtener_destino_de_continuacion")
	if not continue_target is Dictionary or (continue_target as Dictionary).is_empty():
		_change_scene_to_path(tree, fallback_scene_path)
		return
	go_to_target(tree, continue_target as Dictionary, fallback_scene_path)


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


static func ir_a_finalizacion_partida(tree: SceneTree, _node_key: String = "", fallback_return_to: String = MAP_SCENE_PATH) -> void:
	if tree == null:
		return
	go_to_target(tree, {"type": "scene_path", "scene_path": FINALIZACION_PARTIDA_SCENE_PATH}, fallback_return_to)


static func ir_a_escena_segura(tree: SceneTree, scene_path: String, fallback_path: String = MAP_SCENE_PATH) -> void:
	if tree == null:
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("GameSceneRouter: path de escena invalido o no encontrado: %s. Redirigiendo al fallback: %s" % [scene_path, fallback_path])
		if fallback_path.is_empty() or not ResourceLoader.exists(fallback_path):
			return
		_change_scene_to_path(tree, fallback_path)
		return
	_change_scene_to_path(tree, scene_path)


# --- Helpers privados -------------------------------------------------------

static func _resolve_route_scene_path(route_name: String, fallback_route: String) -> String:
	var scene_path: String = _get_scene_path_for_route(route_name)
	if scene_path.is_empty():
		scene_path = _get_scene_path_for_route(fallback_route)
	if scene_path.is_empty():
		return MODE_SELECTOR_SCENE_PATH
	return scene_path


static func _get_scene_path_for_route(route_name: String) -> String:
	return str(ROUTES.get(route_name, "")).strip_edges()


static func _read_resume_state(target: Dictionary) -> Dictionary:
	var raw_resume_state: Variant = target.get("resume_state", {})
	if raw_resume_state is Dictionary:
		return (raw_resume_state as Dictionary).duplicate(true)
	return {}


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

# --- Transicion visual ---------------------------------------

func transition_to_scene(scene_path: String, transition_type: int = TransitionType.FADE) -> void:
	if _is_transitioning:
		push_warning("[ROUTER] transition_to_scene ignorado: ya hay una transicion en curso.")
		return

	var normalized_path := scene_path.strip_edges()
	if not ResourceLoader.exists(normalized_path):
		push_error("[ROUTER] transition_to_scene: el path no existe: %s" % normalized_path)
		return

	if not is_instance_valid(TransicionEscenas):
		_change_scene_to_path(get_tree(), normalized_path)
		return

	_is_transitioning = true
	match transition_type:
		TransitionType.IRIS:
			await TransicionEscenas.change_scene(normalized_path)
		_:
			await TransicionEscenas.change_normal_scene(normalized_path)
	_is_transitioning = false


# --- Wrappers  -------------------------------------------------------

func change_scene(scene_path: String) -> void:
	await transition_to_scene(scene_path, TransitionType.IRIS)


func change_normal_scene(scene_path: String) -> void:
	await transition_to_scene(scene_path, TransitionType.FADE)
