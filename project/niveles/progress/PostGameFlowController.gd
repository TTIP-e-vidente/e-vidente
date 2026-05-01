extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameStreakDebugScript := preload("res://niveles/progress/GameStreakDebug.gd")

const POST_GAME_FLOW_STATE_META := "post_game_flow_state"
const LOG_PREFIX := "[PostGameFlow]"
const TARGET_TYPE_STREAK := "streak"


static func build_flow_state(
	previous_streak: Dictionary,
	updated_streak: Dictionary,
	completion_context: Dictionary,
	streak_feedback: Dictionary = {}
) -> Dictionary:
	var next_target: Dictionary = _build_next_target(completion_context)
	var fallback_target: Dictionary = _build_fallback_target(completion_context)
	_agregar_vista_previa_mock_racha(fallback_target, streak_feedback)

	var flow_state := {
		"source_name": str(completion_context.get("source_name", "post_game")).strip_edges(),
		"streak_active": _estaba_activa_antes(previous_streak),
		"streak_just_activated": _se_activo_en_esta_partida(
			previous_streak,
			updated_streak,
			streak_feedback
		),
		"streak_timer_finished": false,
		"next_level_available": not next_target.is_empty(),
		"next_level_target": next_target,
		"fallback_target": fallback_target,
		"return_scene_path": _resolver_return_scene_path(completion_context),
		"streak_active_after_completion": _esta_activa_hoy(updated_streak),
	}

	debug_log(
		"partida_terminada",
		{
			"source": flow_state.get("source_name", "post_game"),
			"streak_active": bool(flow_state.get("streak_active", false)),
			"streak_just_activated": bool(flow_state.get("streak_just_activated", false)),
			"streak_active_after_completion": bool(
				flow_state.get("streak_active_after_completion", false)
			),
			"next_level_available": bool(flow_state.get("next_level_available", false)),
			"next_target_type": str(next_target.get("type", "")).strip_edges(),
			"fallback_target_type": str(fallback_target.get("type", "")).strip_edges(),
		}
	)
	return flow_state


static func resolve_post_teaching_flow(
	flow_state: Dictionary,
	streak_timer_finished: bool
) -> Dictionary:
	if flow_state.is_empty():
		return _scene_path_target(GameSceneRouter.MAP_SCENE_PATH)

	if (
		not bool(flow_state.get("streak_active", false))
		or bool(flow_state.get("streak_just_activated", false))
	):
		return {"type": TARGET_TYPE_STREAK}

	if (
		streak_timer_finished
		and bool(flow_state.get("next_level_available", false))
	):
		return _leer_target(flow_state, "next_level_target")

	return resolve_after_streak_flow(flow_state)


static func resolve_after_streak_flow(flow_state: Dictionary) -> Dictionary:
	if flow_state.is_empty():
		return {}
	var fallback_target: Dictionary = _leer_target(flow_state, "fallback_target")
	if not fallback_target.is_empty():
		return fallback_target
	return _scene_path_target(
		str(flow_state.get("return_scene_path", GameSceneRouter.MAP_SCENE_PATH)).strip_edges()
	)


static func navigate_after_teaching(
	tree: SceneTree,
	flow_state: Dictionary,
	streak_feedback: Dictionary = {},
	streak_timer_finished: bool = false
) -> void:
	if tree == null:
		return

	var effective_flow_state: Dictionary = flow_state.duplicate(true)
	effective_flow_state["streak_timer_finished"] = streak_timer_finished
	debug_log(
		"ensenanza_terminada",
		{
			"source": str(effective_flow_state.get("source_name", "post_game")).strip_edges(),
			"streak_active": bool(effective_flow_state.get("streak_active", false)),
			"streak_just_activated": bool(
				effective_flow_state.get("streak_just_activated", false)
			),
			"streak_timer_finished": streak_timer_finished,
		}
	)

	var resolved_target: Dictionary = resolve_post_teaching_flow(
		effective_flow_state,
		streak_timer_finished
	)
	var target_type: String = str(resolved_target.get("type", "")).strip_edges()
	if target_type == TARGET_TYPE_STREAK:
		_store_flow_state(tree, effective_flow_state)
		debug_log(
			"escena_resuelta",
			{
				"source": str(effective_flow_state.get("source_name", "post_game")).strip_edges(),
				"scene": GameSceneRouter.STREAK_SCENE_PATH,
				"decision": TARGET_TYPE_STREAK,
			}
		)
		GameSceneRouter.go_to_streak(
			tree,
			str(
				effective_flow_state.get(
					"return_scene_path",
					GameSceneRouter.MAP_SCENE_PATH
				)
			).strip_edges(),
			streak_feedback,
			resolve_after_streak_flow(effective_flow_state)
		)
		return

	_clear_flow_state(tree)
	debug_log(
		"escena_resuelta",
		{
			"source": str(effective_flow_state.get("source_name", "post_game")).strip_edges(),
			"scene": _describir_escena(resolved_target),
			"decision": target_type,
		}
	)
	GameSceneRouter.go_to_continue_target(
		tree,
		resolved_target,
		_resolver_return_scene_path(effective_flow_state)
	)


static func navigate_after_streak(
	tree: SceneTree,
	fallback_scene_path: String = GameSceneRouter.MAP_SCENE_PATH
) -> void:
	if tree == null:
		return

	var flow_state: Dictionary = consume_flow_state(tree)
	debug_log(
		"racha_terminada",
		{
			"has_flow_state": not flow_state.is_empty(),
			"fallback_scene_path": fallback_scene_path,
		}
	)

	var resolved_target: Dictionary = resolve_after_streak_flow(flow_state)
	if resolved_target.is_empty():
		resolved_target = _scene_path_target(fallback_scene_path)
	debug_log(
		"escena_resuelta",
		{
			"source": "streak",
			"scene": _describir_escena(resolved_target),
			"decision": str(resolved_target.get("type", "scene_path")).strip_edges(),
		}
	)
	GameSceneRouter.go_to_continue_target(tree, resolved_target, fallback_scene_path)


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
	print("%s %s %s" % [LOG_PREFIX, event_name, JSON.stringify(data)])


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


static func _leer_target(flow_state: Dictionary, key: String) -> Dictionary:
	var raw_target: Variant = flow_state.get(key, {})
	if raw_target is Dictionary:
		return GameStreakDebugScript.sanitize_continue_target(raw_target)
	return {}


static func _build_next_target(completion_context: Dictionary) -> Dictionary:
	var node_key: String = str(completion_context.get("node_key", "")).strip_edges()
	if not node_key.is_empty():
		return {
			"type": "map_continue",
			"node_key": node_key,
			"return_scene_path": _resolver_return_scene_path(completion_context),
		}

	var track_key: String = str(completion_context.get("track_key", "")).strip_edges()
	var current_level_number: int = int(completion_context.get("current_level_number", 0))
	var level_count: int = int(completion_context.get("track_level_count", 0))
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


static func _build_fallback_target(completion_context: Dictionary) -> Dictionary:
	var track_key: String = str(completion_context.get("track_key", "")).strip_edges()
	var default_track_key: String = str(
		completion_context.get("default_track_key", track_key)
	).strip_edges()
	var node_key: String = str(completion_context.get("node_key", "")).strip_edges()
	if not node_key.is_empty():
		return {"type": "map"}
	if track_key.is_empty() or track_key == default_track_key:
		return {"type": "map"}
	return {
		"type": "track_book",
		"track_key": track_key,
	}


static func _resolver_return_scene_path(completion_context: Dictionary) -> String:
	var return_scene_path: String = str(
		completion_context.get("return_scene_path", GameSceneRouter.MAP_SCENE_PATH)
	).strip_edges()
	if return_scene_path.is_empty():
		return GameSceneRouter.MAP_SCENE_PATH
	return return_scene_path


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


static func _agregar_vista_previa_mock_racha(
	continue_target: Dictionary,
	streak_feedback: Dictionary = {}
) -> void:
	if not GameStreakDebugScript.is_preview_enabled():
		return
	var current_count: int = int(streak_feedback.get("current_count", 0))
	if current_count <= 0 or current_count >= GameStreakDebugScript.PREVIEW_MAX_COUNT:
		return
	var preview_counts: Array[int] = []
	for preview_count in range(
		current_count + 1,
		GameStreakDebugScript.PREVIEW_MAX_COUNT + 1
	):
		preview_counts.append(preview_count)
	if preview_counts.is_empty():
		return
	continue_target[GameStreakDebugScript.PREVIEW_COUNTS_KEY] = preview_counts


static func _scene_path_target(scene_path: String) -> Dictionary:
	return {"type": "scene_path", "scene_path": scene_path}


static func _describir_escena(target: Dictionary) -> String:
	var target_type: String = str(target.get("type", "")).strip_edges()
	match target_type:
		"map":
			return GameSceneRouter.MAP_SCENE_PATH
		"map_continue":
			return str(
				target.get("return_scene_path", GameSceneRouter.MAP_SCENE_PATH)
			).strip_edges()
		"track_level":
			return "track_level:%s" % str(target.get("track_key", "")).strip_edges()
		"track_book":
			return "track_book:%s" % str(target.get("track_key", "")).strip_edges()
		"scene_path":
			return str(target.get("scene_path", "")).strip_edges()
		_:
			return target_type