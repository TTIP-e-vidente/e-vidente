extends RefCounted

# PostGameFlowController.gd
# Decide que ocurre despues de mostrar una ensenanza: racha, siguiente juego,
# vuelta al mapa/libro o fallback. No dibuja UI.

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

const POST_GAME_FLOW_STATE_META := "post_game_flow_state"
const LOG_PREFIX := "[POST_GAME]"
const DEBUG_FLOW_LOGS := false
const TARGET_TYPE_STREAK := "streak"
const STEP_STREAK := "streak"
const STEP_NEXT := "next"
const STEP_FALLBACK := "fallback"
const FLOW_SECTION_STATE := "state"
const FLOW_SECTION_TARGETS := "targets"
const FLOW_SECTION_DEBUG := "debug"
const TARGET_KEY_NEXT := "next"
const TARGET_KEY_FALLBACK := "fallback"
const TARGET_KEY_RETURN_TO := "return_to"

static func build_post_game_flow_state(
	previous_streak: Dictionary,
	updated_streak: Dictionary,
	completion_context: Dictionary,
	_streak_feedback: Dictionary = {}
) -> Dictionary:
	print(LOG_PREFIX, " contexto_recibido=", completion_context)
	var next_target: Variant = _build_next_target_from_completion_context(completion_context)
	if next_target is Dictionary and (next_target as Dictionary).is_empty():
		next_target = null

	var fallback_target: Dictionary = _build_fallback_target_from_completion_context(
		completion_context
	)

	var flow_state := {
		FLOW_SECTION_STATE: {
			"streak_was_active": _estaba_activa_antes(previous_streak),
			"timer_finished": false,
		},
		FLOW_SECTION_TARGETS: {
			TARGET_KEY_NEXT: next_target,
			TARGET_KEY_FALLBACK: fallback_target,
			TARGET_KEY_RETURN_TO: _read_completion_return_to(completion_context),
		},
		FLOW_SECTION_DEBUG: {
			"source": _read_completion_source(completion_context),
			"level_number": _read_completion_level_number(completion_context),
			"node_key": _read_completion_node_key(completion_context),
			"track_key": _read_completion_track_key(completion_context),
			"created_by": _read_completion_created_by(completion_context),
			"streak_is_active_now": _esta_activa_hoy(updated_streak),
		},
	}

	print(
		LOG_PREFIX,
		" resultado=",
		completion_context,
		" hay_siguiente=",
		(next_target is Dictionary and not (next_target as Dictionary).is_empty()),
		" return_to=",
		_read_completion_return_to(completion_context)
	)
	_log_flow("Game finished")
	_log_flow("Source: %s" % _get_flow_source(flow_state))
	_log_flow("Streak was active: %s" % _was_streak_active_before_game(flow_state))
	_log_flow("Has next target: %s" % _has_next_target(flow_state))

	debug_log(
		"game_finished",
		{
			"source": _get_flow_source(flow_state),
			"streak_was_active": _was_streak_active_before_game(flow_state),
			"has_next_target": _has_next_target(flow_state),
			"fallback_type": str(_get_fallback_target(flow_state).get("type", "")).strip_edges(),
		}
	)
	return flow_state

static func decide_next_step_after_teaching(
	flow_state: Dictionary,
	timer_finished: Variant = null
) -> String:
	var ready_flow_state: Dictionary = flow_state
	if timer_finished != null:
		ready_flow_state = _with_timer_finished(flow_state, bool(timer_finished))

	if ready_flow_state.is_empty():
		_log_flow("Teaching finished")
		_log_flow("Decision: go_to_fallback")
		return STEP_FALLBACK

	_log_flow("Teaching finished")
	_log_flow("Source: %s" % _get_flow_source(ready_flow_state))
	_log_flow("Streak was active: %s" % _was_streak_active_before_game(ready_flow_state))
	_log_flow("Timer finished: %s" % _did_timer_finish(ready_flow_state))

	if _debe_mostrar_racha(ready_flow_state):
		_log_flow("Decision: show_streak")
		return STEP_STREAK

	if _debe_continuar_siguiente_juego(ready_flow_state):
		_log_flow("Decision: go_to_next_target")
		return STEP_NEXT

	_log_flow("Decision: go_to_fallback")
	return STEP_FALLBACK


static func resolve_post_teaching_flow(
	flow_state: Dictionary,
	timer_finished: bool
) -> Dictionary:
	var ready_flow_state: Dictionary = _with_timer_finished(flow_state, timer_finished)
	var next_step: String = decide_next_step_after_teaching(ready_flow_state)
	if next_step == STEP_STREAK:
		return {"type": TARGET_TYPE_STREAK}
	return _get_target_for_step(ready_flow_state, next_step)


static func resolve_post_teaching_step(
	flow_state: Dictionary,
	timer_finished: bool
) -> String:
	return decide_next_step_after_teaching(flow_state, timer_finished)


static func resolve_post_teaching_target(
	flow_state: Dictionary,
	next_step: String
) -> Dictionary:
	return _get_target_for_step(flow_state, next_step)


static func should_show_streak(flow_state: Dictionary) -> bool:
	if flow_state.is_empty():
		return false
	return _was_streak_inactive_before_game(flow_state)


static func should_go_to_next_target(flow_state: Dictionary) -> bool:
	if flow_state.is_empty():
		return false
	return _did_timer_finish(flow_state) and _has_next_target(flow_state)


static func _debe_mostrar_racha(flow_state: Dictionary) -> bool:
	return should_show_streak(flow_state)


static func _debe_continuar_siguiente_juego(flow_state: Dictionary) -> bool:
	return should_go_to_next_target(flow_state)


static func resolve_after_streak_flow(flow_state: Dictionary) -> Dictionary:
	if flow_state.is_empty():
		return {}
	var fallback_target: Dictionary = _get_fallback_target(flow_state)
	if not fallback_target.is_empty():
		return fallback_target
	return _scene_path_target(_get_return_to(flow_state))


static func navigate_after_teaching(
	tree: SceneTree,
	flow_state: Dictionary,
	streak_feedback: Dictionary = {},
	timer_finished: bool = false
) -> void:
	if tree == null:
		return

	var ready_flow_state: Dictionary = _with_timer_finished(flow_state, timer_finished)
	var next_step: String = decide_next_step_after_teaching(ready_flow_state)
	if next_step == STEP_STREAK:
		_show_streak(tree, ready_flow_state, streak_feedback)
		return

	if next_step == STEP_NEXT:
		_abrir_siguiente_juego(tree, ready_flow_state)
		return
	_volver_a_fallback(tree, ready_flow_state)


static func navigate_after_streak(
	tree: SceneTree,
	fallback_scene_path: String = GameSceneRouter.MAP_SCENE_PATH
) -> void:
	if tree == null:
		return

	var flow_state: Dictionary = consume_flow_state(tree)
	var resolved_target: Dictionary = resolve_after_streak_flow(flow_state)
	if resolved_target.is_empty():
		resolved_target = _scene_path_target(fallback_scene_path)

	_log_flow("Streak finished")
	_log_flow("Decision: go_to_fallback")
	_go_to_target(
		tree,
		flow_state,
		resolved_target,
		STEP_FALLBACK,
		fallback_scene_path,
		"streak"
	)


static func navigate_to_return_target(
	tree: SceneTree,
	return_to: String,
	node_key: String = ""
) -> void:
	if tree == null:
		return

	var return_target: Dictionary = _build_return_target(return_to, node_key)
	var safe_return_to: String = GameSceneRouter.read_return_to(
		return_target,
		return_to
	)

	_clear_flow_state(tree)
	_log_flow("Decision: return_to_target")
	debug_log(
		"return_target",
		{
			"source": "return_target",
			"scene": _describir_escena(return_target),
			"decision": str(return_target.get("type", "scene_path")).strip_edges(),
		}
	)
	GameSceneRouter.go_to_target(
		tree,
		return_target,
		safe_return_to
	)


static func consume_flow_state(tree: SceneTree) -> Dictionary:
	if tree == null or tree.root == null:
		return {}
	var root: Window = tree.root
	if not root.has_meta(POST_GAME_FLOW_STATE_META):
		return {}
	var raw_state: Variant = root.get_meta(POST_GAME_FLOW_STATE_META, {})
	root.remove_meta(POST_GAME_FLOW_STATE_META)
	if raw_state is Dictionary:
		return (raw_state as Dictionary).duplicate(true)
	return {}


static func debug_log(event_name: String, data: Dictionary = {}) -> void:
	if not DEBUG_FLOW_LOGS:
		return
	print("%s %s %s" % [LOG_PREFIX, event_name, JSON.stringify(data)])


static func _log_flow(message: String) -> void:
	if not DEBUG_FLOW_LOGS:
		return
	print("%s %s" % [LOG_PREFIX, message])


static func _store_flow_state(tree: SceneTree, flow_state: Dictionary) -> void:
	if tree == null or tree.root == null:
		return
	var root: Window = tree.root
	root.set_meta(POST_GAME_FLOW_STATE_META, flow_state.duplicate(true))


static func _clear_flow_state(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	var root: Window = tree.root
	if root.has_meta(POST_GAME_FLOW_STATE_META):
		root.remove_meta(POST_GAME_FLOW_STATE_META)


static func _with_timer_finished(
	flow_state: Dictionary,
	timer_finished: bool
) -> Dictionary:
	var ready_flow_state: Dictionary = flow_state.duplicate(true)
	var state_section: Dictionary = _get_state_section(ready_flow_state)
	state_section["timer_finished"] = timer_finished
	ready_flow_state[FLOW_SECTION_STATE] = state_section
	return ready_flow_state


static func _show_streak(
	tree: SceneTree,
	flow_state: Dictionary,
	streak_feedback: Dictionary
) -> void:
	_store_flow_state(tree, flow_state)
	debug_log(
		"show_streak",
		{
			"source": _get_flow_source(flow_state),
			"scene": GameSceneRouter.STREAK_SCENE_PATH,
			"decision": STEP_STREAK,
		}
	)
	GameSceneRouter.go_to_streak(
		tree,
		_get_return_to(flow_state),
		streak_feedback,
		resolve_after_streak_flow(flow_state)
	)


static func _abrir_siguiente_juego(tree: SceneTree, flow_state: Dictionary) -> void:
	_go_to_step_target(tree, flow_state, STEP_NEXT)


static func _volver_a_fallback(tree: SceneTree, flow_state: Dictionary) -> void:
	_go_to_step_target(tree, flow_state, STEP_FALLBACK)


static func _go_to_step_target(
	tree: SceneTree,
	flow_state: Dictionary,
	next_step: String
) -> void:
	var resolved_target: Dictionary = _get_target_for_step(flow_state, next_step)
	_go_to_target(tree, flow_state, resolved_target, next_step)


static func _go_to_target(
	tree: SceneTree,
	flow_state: Dictionary,
	resolved_target: Dictionary,
	next_step: String,
	fallback_scene_path: String = "",
	debug_source: String = ""
) -> void:
	if next_step == STEP_NEXT and resolved_target.is_empty():
		push_error("[POST_GAME] No se pudo avanzar: falta siguiente juego o target inválido.")
	_clear_flow_state(tree)
	var safe_source_name: String = debug_source.strip_edges()
	if safe_source_name.is_empty():
		safe_source_name = _get_flow_source(flow_state)
	var safe_fallback_scene_path: String = fallback_scene_path.strip_edges()
	if safe_fallback_scene_path.is_empty():
		safe_fallback_scene_path = _get_return_to(flow_state)
	debug_log(
		"go_to_target",
		{
			"source": safe_source_name,
			"scene": _describir_escena(resolved_target),
			"decision": next_step,
		}
	)
	GameSceneRouter.go_to_target(
		tree,
		resolved_target,
		safe_fallback_scene_path
	)


static func _get_target_for_step(flow_state: Dictionary, next_step: String) -> Dictionary:
	if next_step == STEP_NEXT:
		return _get_next_target(flow_state)
	if flow_state.is_empty():
		return _scene_path_target(GameSceneRouter.MAP_SCENE_PATH)
	return resolve_after_streak_flow(flow_state)


static func _was_streak_active_before_game(flow_state: Dictionary) -> bool:
	return bool(_get_state_section(flow_state).get("streak_was_active", false))


static func _was_streak_inactive_before_game(flow_state: Dictionary) -> bool:
	return not _was_streak_active_before_game(flow_state)


static func _did_timer_finish(flow_state: Dictionary) -> bool:
	return bool(_get_state_section(flow_state).get("timer_finished", false))


static func _has_next_target(flow_state: Dictionary) -> bool:
	return not _get_next_target(flow_state).is_empty()


static func _get_flow_source(flow_state: Dictionary) -> String:
	return str(_get_debug_section(flow_state).get("source", "post_game")).strip_edges()


static func _get_state_section(flow_state: Dictionary) -> Dictionary:
	return _read_flow_section(flow_state, FLOW_SECTION_STATE)


static func _get_targets_section(flow_state: Dictionary) -> Dictionary:
	return _read_flow_section(flow_state, FLOW_SECTION_TARGETS)


static func _get_debug_section(flow_state: Dictionary) -> Dictionary:
	return _read_flow_section(flow_state, FLOW_SECTION_DEBUG)


static func _get_next_target(flow_state: Dictionary) -> Dictionary:
	return _read_flow_target(_get_targets_section(flow_state), TARGET_KEY_NEXT)


static func _get_fallback_target(flow_state: Dictionary) -> Dictionary:
	return _read_flow_target(_get_targets_section(flow_state), TARGET_KEY_FALLBACK)


static func _get_return_to(flow_state: Dictionary) -> String:
	var return_to: String = str(
		_get_targets_section(flow_state).get(TARGET_KEY_RETURN_TO, GameSceneRouter.MAP_SCENE_PATH)
	).strip_edges()
	if return_to.is_empty():
		return GameSceneRouter.MAP_SCENE_PATH
	return return_to


static func _build_return_target(return_to: String, node_key: String) -> Dictionary:
	var safe_return_to: String = return_to.strip_edges()
	if safe_return_to.is_empty():
		safe_return_to = GameSceneRouter.MAP_SCENE_PATH
	var clean_node_key: String = node_key.strip_edges()
	if clean_node_key.is_empty():
		return {
			"type": "scene_path",
			"scene_path": safe_return_to,
		}
	return {
		"type": "map_continue",
		"node_key": clean_node_key,
		TARGET_KEY_RETURN_TO: safe_return_to,
	}


static func _read_flow_section(flow_state: Dictionary, section_name: String) -> Dictionary:
	var raw_section: Variant = flow_state.get(section_name, {})
	if raw_section is Dictionary:
		return raw_section as Dictionary
	return {}


static func _read_flow_target(targets_section: Dictionary, target_name: String) -> Dictionary:
	var raw_target: Variant = targets_section.get(target_name, null)
	if raw_target is Dictionary:
		return (raw_target as Dictionary).duplicate(true)
	return {}


static func _build_next_target_from_completion_context(
	completion_context: Dictionary
) -> Dictionary:
	var node_key: String = _read_completion_node_key(completion_context)
	if _completion_came_from_map(completion_context) and not node_key.is_empty():
		# Una partida de nodo avanza sus juegos con ContinuidadDePartidaDeNodo.
		# Cuando ya llega aca, el nodo termino y debe volver al mapa.
		return {}

	var track_key: String = _read_completion_track_key(completion_context)
	var current_level_number: int = _read_completion_level_number(completion_context)
	var level_count: int = _read_completion_level_count(completion_context)
	if track_key.is_empty() or current_level_number <= 0 or level_count <= 0:
		return {}

	var next_level_number: int = current_level_number + 1
	if next_level_number > level_count:
		return {}

	return {
		"type": "track_level",
		"track_key": track_key,
		"level_number": next_level_number,
	}


static func _build_fallback_target_from_completion_context(
	completion_context: Dictionary
) -> Dictionary:
	if _completion_came_from_map(completion_context):
		return {"type": "scene_path", "scene_path": GameSceneRouter.FINALIZACION_PARTIDA_SCENE_PATH}

	var track_key: String = _read_completion_track_key(completion_context)
	if track_key.is_empty() or _completion_uses_default_track(completion_context):
		return {"type": "map"}
	return {
		"type": "track_book",
		"track_key": track_key,
	}


static func _read_completion_source(completion_context: Dictionary) -> String:
	return str(completion_context.get("source", "post_game")).strip_edges()


static func _read_completion_level_section(completion_context: Dictionary) -> Dictionary:
	var raw_level: Variant = completion_context.get("level", {})
	if raw_level is Dictionary:
		return raw_level as Dictionary
	return {}


static func _read_completion_map_section(completion_context: Dictionary) -> Dictionary:
	var raw_map: Variant = completion_context.get("map", {})
	if raw_map is Dictionary:
		return raw_map as Dictionary
	return {}


static func _read_completion_navigation_section(completion_context: Dictionary) -> Dictionary:
	var raw_navigation: Variant = completion_context.get("navigation", {})
	if raw_navigation is Dictionary:
		return raw_navigation as Dictionary
	return {}


static func _read_completion_debug_section(completion_context: Dictionary) -> Dictionary:
	var raw_debug: Variant = completion_context.get("debug", {})
	if raw_debug is Dictionary:
		return raw_debug as Dictionary
	return {}


static func _read_completion_track_key(completion_context: Dictionary) -> String:
	return str(
		_read_completion_level_section(completion_context).get("track_key", "")
	).strip_edges()


static func _read_completion_level_number(completion_context: Dictionary) -> int:
	return int(_read_completion_level_section(completion_context).get("number", 0))


static func _read_completion_level_count(completion_context: Dictionary) -> int:
	return int(_read_completion_level_section(completion_context).get("track_level_count", 0))


static func _completion_uses_default_track(completion_context: Dictionary) -> bool:
	return bool(_read_completion_level_section(completion_context).get("is_default_track", false))


static func _completion_came_from_map(completion_context: Dictionary) -> bool:
	return bool(_read_completion_map_section(completion_context).get("came_from_map", false))


static func _read_completion_node_key(completion_context: Dictionary) -> String:
	return str(_read_completion_map_section(completion_context).get("node_key", "")).strip_edges()


static func _read_completion_return_to(completion_context: Dictionary) -> String:
	var return_to: String = str(
		_read_completion_navigation_section(completion_context).get(
			"return_to",
			GameSceneRouter.MAP_SCENE_PATH
		)
	).strip_edges()
	if return_to.is_empty():
		return GameSceneRouter.MAP_SCENE_PATH
	return return_to


static func _read_completion_created_by(completion_context: Dictionary) -> String:
	return str(
		_read_completion_debug_section(completion_context).get("created_by", "unknown")
	).strip_edges()


static func _estaba_activa_antes(streak_state: Dictionary) -> bool:
	return _esta_activa_hoy(streak_state)


static func _se_activo_en_esta_partida(
	previous_streak: Dictionary,
	updated_streak: Dictionary,
	streak_feedback: Dictionary
) -> bool:
	if str(streak_feedback.get("feedback_key", "")).strip_edges() == "activated":
		return true
	return not _esta_activa_hoy(previous_streak) and _esta_activa_hoy(updated_streak)


static func _esta_activa_hoy(streak_state: Dictionary) -> bool:
	var current_count: int = int(streak_state.get("current_count", 0))
	if current_count <= 0:
		return false
	return str(streak_state.get("last_activity_day", "")) == Time.get_date_string_from_system(false)


static func _scene_path_target(scene_path: String) -> Dictionary:
	return {"type": "scene_path", "scene_path": scene_path}


static func _describir_escena(target: Dictionary) -> String:
	var target_type: String = str(target.get("type", "")).strip_edges()
	match target_type:
		"map":
			return GameSceneRouter.MAP_SCENE_PATH
		"map_continue":
			return GameSceneRouter.read_return_to(target, GameSceneRouter.MAP_SCENE_PATH)
		"track_level":
			return "track_level:%s" % str(target.get("track_key", "")).strip_edges()
		"track_book":
			return "track_book:%s" % str(target.get("track_key", "")).strip_edges()
		"scene_path":
			return str(target.get("scene_path", "")).strip_edges()
		_:
			return target_type
