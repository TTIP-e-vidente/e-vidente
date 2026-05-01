extends SceneTree

const PostGameFlowController := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)

var _fallo: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_probar_racha_no_activa_muestra_racha()
	_probar_racha_activa_con_timer_va_al_siguiente()
	_probar_racha_activa_sin_timer_vuelve_al_mapa()
	_probar_cierre_de_racha_vuelve_al_mapa()
	_probar_sin_estado_post_partida_no_fuerza_mapa()
	await process_frame
	quit(1 if _fallo else 0)


func _probar_racha_no_activa_muestra_racha() -> void:
	var flow_state: Dictionary = PostGameFlowController.build_flow_state(
		_estado_racha(0, false),
		_estado_racha(1, true),
		_contexto_mapa(),
		{"feedback_key": "activated", "current_count": 1, "should_show": true}
	)
	var resolved_target: Dictionary = PostGameFlowController.resolve_post_teaching_flow(
		flow_state,
		true
	)
	_assert(
		str(resolved_target.get("type", "")) == "streak",
		"Si la racha no estaba activa, la ensenanza debe ir a racha"
	)


func _probar_racha_activa_con_timer_va_al_siguiente() -> void:
	var flow_state: Dictionary = PostGameFlowController.build_flow_state(
		_estado_racha(3, true),
		_estado_racha(3, true),
		_contexto_mapa(),
		{}
	)
	var resolved_target: Dictionary = PostGameFlowController.resolve_post_teaching_flow(
		flow_state,
		true
	)
	_assert(
		str(resolved_target.get("type", "")) == "map_continue",
		"Si la racha ya estaba activa y termina el timer, debe continuar al siguiente nodo"
	)


func _probar_racha_activa_sin_timer_vuelve_al_mapa() -> void:
	var flow_state: Dictionary = PostGameFlowController.build_flow_state(
		_estado_racha(3, true),
		_estado_racha(3, true),
		_contexto_mapa(),
		{}
	)
	var resolved_target: Dictionary = PostGameFlowController.resolve_post_teaching_flow(
		flow_state,
		false
	)
	_assert(
		str(resolved_target.get("type", "")) == "map",
		"Si la racha ya estaba activa pero el timer no termino, debe volver al mapa"
	)


func _probar_cierre_de_racha_vuelve_al_mapa() -> void:
	var flow_state: Dictionary = PostGameFlowController.build_flow_state(
		_estado_racha(0, false),
		_estado_racha(1, true),
		_contexto_mapa(),
		{"feedback_key": "activated", "current_count": 1, "should_show": true}
	)
	var resolved_target: Dictionary = PostGameFlowController.resolve_after_streak_flow(flow_state)
	_assert(
		str(resolved_target.get("type", "")) == "map",
		"Al cerrar la racha activada debe volver al mapa"
	)


func _probar_sin_estado_post_partida_no_fuerza_mapa() -> void:
	var resolved_target: Dictionary = PostGameFlowController.resolve_after_streak_flow({})
	_assert(
		resolved_target.is_empty(),
		"Sin estado post-partida, la salida de racha no debe forzar un mapa por defecto"
	)


func _contexto_mapa() -> Dictionary:
	return {
		"source_name": "Test",
		"track_key": "celiaquia",
		"default_track_key": "celiaquia",
		"current_level_number": 1,
		"track_level_count": 14,
		"node_key": "receta_1_desayuno",
		"return_scene_path": "res://mapas/MapScene.tscn",
	}


func _estado_racha(current_count: int, active_today: bool) -> Dictionary:
	return {
		"current_count": current_count,
		"best_count": current_count,
		"last_activity_day": (
			Time.get_date_string_from_system(false)
			if active_today
			else ""
		),
		"last_activity_type": "test",
		"last_track_key": "celiaquia",
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_fallo = true
	push_error(message)