class_name SincronizadorPartida
extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LOG_PREFIX := "[Sync]"


static func resolver_restriccion(
	tree: SceneTree,
	resultado: Dictionary = {},
	pista_fallback: String = ""
) -> String:
	var explicit := str(resultado.get("map_id", resultado.get("restriction", ""))).strip_edges()
	if not explicit.is_empty():
		return explicit

	if tree != null and tree.root != null:
		var global_node := tree.root.get_node_or_null("/root/Global")
		if global_node != null:
			if global_node.has_method("obtener_partida_de_nodo_actual"):
				var partida: Variant = global_node.call("obtener_partida_de_nodo_actual")
				if partida is Dictionary:
					var partida_dict: Dictionary = partida as Dictionary
					var clave_pista := str(partida_dict.get("clave_pista", "")).strip_edges()
					if not clave_pista.is_empty():
						return clave_pista
			if global_node.has_method("obtener_sesion_nodo_jugable_activo"):
				var sesion: Variant = global_node.call("obtener_sesion_nodo_jugable_activo")
				if sesion is Dictionary:
					var track_key := str((sesion as Dictionary).get("track_key", "")).strip_edges()
					if not track_key.is_empty():
						return track_key
			if global_node.has_method("obtener_sesion_de_juego"):
				var session_data := global_node.call("obtener_sesion_de_juego") as Resource
				if session_data != null:
					var raw_track: Variant = session_data.get("track_key")
					var track_from_session := (
						str(raw_track).strip_edges() if raw_track != null else ""
					)
					if not track_from_session.is_empty():
						return track_from_session

	var fallback := pista_fallback.strip_edges()
	if not fallback.is_empty():
		return fallback

	return GameTrackCatalog.TRACK_CELIAQUIA


static func sincronizar_post_partida(
	tree: SceneTree,
	resultado: Dictionary,
	stats: Dictionary,
	pista_fallback: String = ""
) -> void:
	var node_id := str(resultado.get("node_key", "")).strip_edges()
	if node_id.is_empty():
		node_id = "unknown_node"

	var restriction_raw := resolver_restriccion(tree, resultado, pista_fallback)
	var restriction := RestrictionCodes.normalizar_desde_juego(restriction_raw)
	if restriction.is_empty():
		restriction = RestrictionCodes.CODE_CELIAQUIA

	var game_type := _leer_tipo_juego(tree, resultado)
	var score := int(stats.get("aciertos", 0))
	var accuracy := _resolver_precision(resultado, stats)
	var correct_answers := int(stats.get("aciertos", 0))
	var wrong_answers := int(stats.get("errores", 0))
	var exp_to_add := int(stats.get("exp_ganada", resultado.get("exp", 0)))
	var completed := bool(resultado.get("success", false))
	var elapsed := float(stats.get("elapsed_seconds", resultado.get("elapsed_seconds", -1.0)))
	var duration_seconds := maxi(0, int(elapsed)) if elapsed >= 0.0 else 0

	var summary := construir_resumen(
		restriction, node_id, game_type,
		score, accuracy, correct_answers, wrong_answers,
		exp_to_add, completed, duration_seconds
	)
	LocalSyncQueue.encolar_resumen_partida(summary, AuthApi.obtener_usuario())

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

	if not AuthApi.esta_logueado():
		print(LOG_PREFIX, " Sin sesión activa — RunSummary queda pendiente para el próximo sync")
		return

	SyncApi.reintentar_pendientes()


static func construir_resumen(
	restriccion: String,
	id_nodo: String,
	tipo_juego: String,
	puntaje: int,
	precision: float,
	respuestas_correctas: int,
	respuestas_incorrectas: int,
	exp_a_sumar: int,
	completado: bool,
	duracion_segundos: int,
) -> Dictionary:
	return {
		"clientRunId": _generar_id_cliente(),
		"restriction": restriccion,
		"nodeId": id_nodo,
		"gameType": tipo_juego,
		"score": puntaje,
		"accuracy": precision,
		"correctAnswers": respuestas_correctas,
		"wrongAnswers": respuestas_incorrectas,
		"expToAdd": exp_a_sumar,
		"completed": completado,
		"durationSeconds": duracion_segundos,
		"finishedAt": Time.get_datetime_string_from_system(true) + "Z",
		"localDay": Time.get_date_string_from_system(false),
	}


static func _leer_tipo_juego(tree: SceneTree, resultado: Dictionary) -> String:
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


static func _resolver_precision(resultado: Dictionary, stats: Dictionary) -> float:
	if stats.has("precision"):
		return float(stats.get("precision", 0))
	var acc_raw := float(resultado.get("accuracy", 0.0))
	return acc_raw * 100.0 if acc_raw <= 1.0 else acc_raw


static func _generar_id_cliente() -> String:
	var timestamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var millis := int(Time.get_unix_time_from_system() * 1000.0)
	# Combinar microsegundos del proceso + doble randi() para entropía adicional.
	# Previene colisiones cuando dos partidas terminan en el mismo milisegundo.
	var usec := Time.get_ticks_usec() & 0xFFFFFF
	return "run_%s_%d_%d%06d" % [timestamp, millis, randi(), usec]
