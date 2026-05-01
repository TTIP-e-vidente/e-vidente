extends SceneTree

const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ProgressManagerRachaScene := preload(
	"res://interface/components/ProgressManagerRacha.tscn"
)

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	_test_inactive_streak_returns_streak_step()
	_test_active_streak_with_timer_and_next_returns_next_step()
	_test_active_streak_without_timer_returns_fallback_step()
	_test_map_continue_target_normalizes_return_to()
	_test_safe_fallback_uses_return_to_scene()
	await _test_progress_manager_consumes_streak_return_to()

	if failed:
		quit(1)
		return
	quit()


func _test_inactive_streak_returns_streak_step() -> void:
	var flow_state: Dictionary = _make_flow_state(false, false)
	_assert_equal(
		PostGameFlowControllerScript.decide_next_step_after_teaching(flow_state),
		"streak",
		"Racha inactiva debe resolver el paso streak"
	)


func _test_active_streak_with_timer_and_next_returns_next_step() -> void:
	var flow_state: Dictionary = _make_flow_state(
		true,
		true,
		{"type": "track_level", "track_key": "celiaquia", "level_number": 2}
	)
	_assert_equal(
		PostGameFlowControllerScript.decide_next_step_after_teaching(flow_state),
		"next",
		"Racha activa con timer terminado y next target debe resolver next"
	)


func _test_active_streak_without_timer_returns_fallback_step() -> void:
	var flow_state: Dictionary = _make_flow_state(
		true,
		false,
		{"type": "track_level", "track_key": "celiaquia", "level_number": 2}
	)
	_assert_equal(
		PostGameFlowControllerScript.decide_next_step_after_teaching(flow_state),
		"fallback",
		"Racha activa sin timer terminado debe resolver fallback"
	)


func _test_map_continue_target_normalizes_return_to() -> void:
	var internal_target := {
		"type": "map_continue",
		"node_key": "receta_1_desayuno",
		"return_to": "res://mapas/MapScene.tscn",
	}
	var router_target: Dictionary = GameSceneRouter.build_router_target_from_flow_target(
		internal_target
	)

	_assert_equal(
		str(router_target.get("type", "")).strip_edges(),
		"map_continue",
		"El adapter del router debe preservar el tipo map_continue"
	)
	_assert_equal(
		str(router_target.get("node_key", "")).strip_edges(),
		"receta_1_desayuno",
		"El adapter del router debe preservar el node_key"
	)
	_assert_equal(
		str(router_target.get("return_scene_path", "")).strip_edges(),
		"res://mapas/MapScene.tscn",
		"El adapter del router debe traducir return_to a return_scene_path"
	)
	_assert_true(
		not router_target.has("return_to"),
		"El target del router no debe exponer return_to despues de normalizar"
	)


func _test_safe_fallback_uses_return_to_scene() -> void:
	var flow_state: Dictionary = _make_flow_state(
		true,
		false,
		{},
		{},
		"res://niveles/selector.tscn"
	)
	var resolved_target: Dictionary = PostGameFlowControllerScript.resolve_after_streak_flow(
		flow_state
	)

	_assert_equal(
		str(resolved_target.get("type", "")).strip_edges(),
		"scene_path",
		"Sin fallback explicito, la racha debe volver con scene_path seguro"
	)
	_assert_equal(
		str(resolved_target.get("scene_path", "")).strip_edges(),
		"res://niveles/selector.tscn",
		"El fallback seguro debe usar targets.return_to"
	)


func _test_progress_manager_consumes_streak_return_to() -> void:
	var streak_view: Control = ProgressManagerRachaScene.instantiate()
	root.add_child(streak_view)
	await process_frame

	GameSceneRouter.set_streak_return_to(self, "res://interface/archivero.tscn")
	var consumed_return_to: String = str(
		streak_view.call("_consumir_return_to_de_racha")
	).strip_edges()

	_assert_equal(
		consumed_return_to,
		"res://interface/archivero.tscn",
		"ProgressManagerRacha debe consumir el return_to guardado por el router"
	)
	_assert_equal(
		GameSceneRouter.read_streak_return_to(self, GameSceneRouter.MAP_SCENE_PATH),
		GameSceneRouter.MAP_SCENE_PATH,
		"Consumir el return_to debe limpiar el meta de racha"
	)

	streak_view.queue_free()
	await process_frame


func _make_flow_state(
	streak_was_active: bool,
	timer_finished: bool,
	next_target: Dictionary = {},
	fallback_target: Dictionary = {"type": "map"},
	return_to: String = "res://mapas/MapScene.tscn"
) -> Dictionary:
	return {
		"state": {
			"streak_was_active": streak_was_active,
			"timer_finished": timer_finished,
		},
		"targets": {
			"next": next_target.duplicate(true),
			"fallback": fallback_target.duplicate(true),
			"return_to": return_to,
		},
		"debug": {
			"source": "test",
			"created_by": "post_game_flow_controller_test",
		},
	}


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("OK: %s" % message)
		return
	_fail("%s | esperado=%s actual=%s" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("OK: %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("FAILED: %s" % message)