class_name RunSummarySyncAdapter
extends RefCounted

const LOG_PREFIX := "[BackendSync]"

static func sync_from_post_game(
	tree: SceneTree,
	resultado: Dictionary,
	stats: Dictionary
) -> void:
	# Guard: BackendSession autoload debe estar en el árbol
	var backend: Node = tree.root.get_node_or_null("/root/BackendSession")
	if backend == null:
		print_debug(LOG_PREFIX, " BackendSession no disponible en el árbol")
		return

	# Guard: sin sesión activa no hay nada que sincronizar
	if not backend.is_logged_in():
		print(LOG_PREFIX, " Sin sesión activa, se mantiene guardado local")
		return

	# ── Mapear campos al contrato RunSummary ────────────────────────────────

	# nodeId — clave real del nodo en el mapa
	var node_id: String = str(resultado.get("node_key", "")).strip_edges()
	if node_id.is_empty():
		node_id = "unknown_node"  # TODO: no debería ocurrir en flujo normal

	# restriction — map_id = track_key ("celiaquia" para todos los minijuegos actuales)
	var restriction: String = str(resultado.get("map_id", "")).strip_edges()
	if restriction.is_empty():
		restriction = "celiaquía"  # TODO: leer de config cuando haya múltiples restricciones

	# gameType — modo real del juego (vincular, completar, preguntas, etc.)
	var game_type: String = _leer_game_type(tree, resultado)

	# score — aciertos reales del nodo (real si stats disponible, 0 si no)
	var score: int = int(stats.get("aciertos", 0))

	# accuracy — precisión real como porcentaje float (0.0–100.0)
	var accuracy: float = _resolver_accuracy(resultado, stats)

	# correctAnswers / wrongAnswers — reales
	var correct_answers: int = int(stats.get("aciertos", 0))
	var wrong_answers: int = int(stats.get("errores", 0))

	# expToAdd — EXP calculada real; fallback a exp estimada del resultado
	var exp_to_add: int = int(stats.get("exp_ganada", resultado.get("exp", 0)))

	# completed — resultado real del juego
	var completed: bool = bool(resultado.get("success", false))

	# durationSeconds — tiempo real en segundos enteros (>= 0)
	var elapsed: float = float(stats.get("elapsed_seconds", resultado.get("elapsed_seconds", -1.0)))
	var duration_seconds: int = maxi(0, int(elapsed)) if elapsed >= 0.0 else 0

	var summary: Dictionary = RunSummaryBuilder.build(
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

	print(
		LOG_PREFIX,
		" node=", node_id,
		" game_type=", game_type,
		" score=", score,
		" accuracy=", accuracy,
		" exp=", exp_to_add,
		" completed=", completed,
		" duration_s=", duration_seconds,
	)

	# Fire-and-forget: no await. La coroutine corre en background independientemente.
	# Si falla, BackendSession emitirá sync_failed sin romper el flujo del juego.
	backend.save_progress(summary)


# ── Helpers privados ────────────────────────────────────────────────────────

## Lee el tipo de juego desde GameSessionData.mode_id (fuente más precisa).
## Si no está disponible, cae al activity_id del resultado.
static func _leer_game_type(tree: SceneTree, resultado: Dictionary) -> String:
	var global_node: Node = tree.root.get_node_or_null("/root/Global")
	if global_node != null and global_node.has_method("obtener_sesion_de_juego"):
		var session_data: Resource = global_node.call("obtener_sesion_de_juego") as Resource
		if session_data != null:
			var mode_id: String = str(session_data.get("mode_id", "")).strip_edges()
			if not mode_id.is_empty():
				return mode_id

	# Fallback: activity_id del resultado (ej. "vincular_conceptos_01")
	var activity_id: String = str(resultado.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		return activity_id

	return "unknown_game"  # TODO: este caso no debería ocurrir en flujo normal


## Resuelve accuracy como float 0.0–100.0.
## Prioridad: stats.precision (int 0-100) > resultado.accuracy (0.0-1.0 o 0-100).
static func _resolver_accuracy(resultado: Dictionary, stats: Dictionary) -> float:
	if stats.has("precision"):
		return float(stats.get("precision", 0))

	# Fallback: resultado.accuracy puede llegar como 0.0-1.0 (GDScript float)
	var acc_raw := float(resultado.get("accuracy", 0.0))
	return acc_raw * 100.0 if acc_raw <= 1.0 else acc_raw
