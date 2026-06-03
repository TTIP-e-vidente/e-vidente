class_name RunSummarySyncAdapter
extends RefCounted

const LOG_PREFIX := "[BackendSync]"


static func sync_from_post_game(
	tree: SceneTree,
	resultado: Dictionary,
	stats: Dictionary
) -> void:
	var node_id := str(resultado.get("node_key", "")).strip_edges()
	if node_id.is_empty():
		node_id = "unknown_node"

	var restriction := str(resultado.get("map_id", "")).strip_edges()
	if restriction.is_empty():
		restriction = "celiaquia"

	var game_type := _leer_game_type(tree, resultado)
	var score := int(stats.get("aciertos", 0))
	var accuracy := _resolver_accuracy(resultado, stats)
	var correct_answers := int(stats.get("aciertos", 0))
	var wrong_answers := int(stats.get("errores", 0))
	var exp_to_add := int(stats.get("exp_ganada", resultado.get("exp", 0)))
	var completed := bool(resultado.get("success", false))
	var elapsed := float(stats.get("elapsed_seconds", resultado.get("elapsed_seconds", -1.0)))
	var duration_seconds := maxi(0, int(elapsed)) if elapsed >= 0.0 else 0

	var summary := RunSummaryBuilder.build(
		restriction,
		node_id,
		game_type,
		score,
		accuracy,
		correct_answers,
		wrong_answers,
		exp_to_add,
		completed,
		duration_seconds,
	)
	LocalSyncQueue.enqueue_run_summary(summary)

	print(
		LOG_PREFIX,
		" client_run_id=", summary.get("clientRunId", ""),
		" node=", node_id,
		" game_type=", game_type,
		" score=", score,
		" accuracy=", accuracy,
		" exp=", exp_to_add,
		" completed=", completed,
		" duration_s=", duration_seconds,
	)

	var backend := tree.root.get_node_or_null("/root/BackendSession")
	if backend == null:
		print_debug(LOG_PREFIX, " BackendSession no disponible en el arbol")
		return
	if not backend.is_logged_in():
		print(LOG_PREFIX, " Sin sesion activa, RunSummary queda pending")
		return

	_sync_queued_summary(backend, summary)


static func _sync_queued_summary(backend: Node, summary: Dictionary) -> void:
	var client_run_id := str(summary.get("clientRunId", "")).strip_edges()
	var result: Dictionary = await backend.save_progress(summary)
	if result.get("ok", false):
		LocalSyncQueue.mark_synced(client_run_id)
		return
	LocalSyncQueue.mark_failed(client_run_id, str(result.get("error", "Sync fallida")))


static func _leer_game_type(tree: SceneTree, resultado: Dictionary) -> String:
	var global_node := tree.root.get_node_or_null("/root/Global")
	if global_node != null and global_node.has_method("obtener_sesion_de_juego"):
		var session_data := global_node.call("obtener_sesion_de_juego") as Resource
		if session_data != null:
			var raw_mode_id: Variant = session_data.get("mode_id")
			var mode_id := str(raw_mode_id).strip_edges() if raw_mode_id != null else ""
			if not mode_id.is_empty():
				return mode_id

	var activity_id := str(resultado.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		return activity_id

	return "unknown_game"


static func _resolver_accuracy(resultado: Dictionary, stats: Dictionary) -> float:
	if stats.has("precision"):
		return float(stats.get("precision", 0))

	var acc_raw := float(resultado.get("accuracy", 0.0))
	return acc_raw * 100.0 if acc_raw <= 1.0 else acc_raw
