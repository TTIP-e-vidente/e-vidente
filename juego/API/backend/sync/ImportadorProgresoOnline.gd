class_name ImportadorProgresoOnline
extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameStreakTrackerScript := preload("res://niveles/progress/GameStreakTracker.gd")
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const QUESTION_PROGRESS_KEY := "question_progress"
const STREAK_KEY := "streak"

const MENSAJES_APRENDIZAJE_POR_PISTA := {
	GameTrackCatalog.TRACK_CELIAQUIA: "El sello sin TACC ayuda a identificar alimentos seguros.",
}


## Traduce GET /player/me/progress (Postgres) a la forma que usa SaveManager + Global.
##
## | Servidor                         | Save local / runtime                          |
## |----------------------------------|-----------------------------------------------|
## | completedNodes[].node_id         | save_data.node_progress[node_id]              |
## | completedNodes[].best_accuracy   | node_progress[node_id].best_accuracy           |
## | profile.exp_count                | save_data.total_exp                           |
## | progress[].restriction_type      | track_key (CELIAQUIA → celiaquia)             |
## | streak                           | progress.progress_system_states.streak        |
## | completedNodes (por node_id)     | progress_system_states.question_progress      |
static func construir_snapshot_local(progreso_online: Dictionary) -> Dictionary:
	var node_progress := _construir_node_progress(
		progreso_online.get("completedNodes", [])
	)
	var question_progress_by_track := _construir_question_progress_por_track(
		progreso_online.get("completedNodes", [])
	)
	var streak_state := _construir_estado_racha(progreso_online.get("streak", {}))
	var progress_snapshot := {
		"progress_system_states": {
			QUESTION_PROGRESS_KEY: question_progress_by_track.duplicate(true),
			STREAK_KEY: streak_state.duplicate(true),
		}
	}

	return {
		"node_progress": node_progress,
		"total_exp": _calcular_exp_total(progreso_online),
		"streak_state": streak_state,
		"question_progress_by_track": question_progress_by_track,
		"progress_snapshot": progress_snapshot,
	}


static func construir_parche_perfil(usuario: Dictionary) -> Dictionary:
	var parche := {}
	var display_name := str(usuario.get("name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(usuario.get("username", "")).strip_edges()
	if not display_name.is_empty():
		parche["username"] = display_name

	var email := str(usuario.get("mail", usuario.get("email", ""))).strip_edges()
	if not email.is_empty():
		parche["email"] = email

	if usuario.has("age"):
		parche["age"] = max(0, int(usuario.get("age", 0)))

	return parche


## Resumen del panel semanal del perfil, derivado del save local sincronizado.
static func construir_resumen_semanal_desde_save(
	track_key: String = GameTrackCatalog.TRACK_CELIAQUIA,
	node_progress: Dictionary = {}
) -> Dictionary:
	var pista := track_key.strip_edges()
	if pista.is_empty():
		pista = GameTrackCatalog.TRACK_CELIAQUIA

	var map_path := str(
		ArmadorDePartidaScript.RUTA_MAPA_POR_PISTA.get(pista, "")
	).strip_edges()
	var total_nodos := contar_nodos_mapa(map_path)
	var completados := contar_nodos_completados(node_progress, pista)
	var topic := _obtener_etiqueta_pista(pista)

	return {
		"topic": topic,
		"completed": completados,
		"total": maxi(total_nodos, 1),
		"key_learning": _mensaje_aprendizaje_clave(pista, completados, total_nodos),
		"suggestion": _mensaje_sugerencia(completados, total_nodos),
	}


static func contar_nodos_completados(node_progress: Dictionary, track_key: String) -> int:
	var completados := 0
	for raw_node_id in node_progress.keys():
		var node_id := str(raw_node_id).strip_edges()
		if node_id.is_empty():
			continue
		if inferir_track_key_desde_node_id(node_id) != track_key:
			continue
		var entry: Variant = node_progress[raw_node_id]
		if entry is Dictionary and not bool((entry as Dictionary).get("completed", true)):
			continue
		completados += 1
	return completados


static func contar_nodos_mapa(map_json_path: String) -> int:
	if map_json_path.is_empty():
		return 0
	var resultado: Dictionary = CargadorDeMapaScript.cargar_mapa(map_json_path)
	if not resultado.get("ok", false):
		return 0
	var nodos: Variant = resultado.get("nodes", [])
	return nodos.size() if nodos is Array else 0


static func inferir_track_key_desde_node_id(node_id: String) -> String:
	var clean_id := node_id.strip_edges()
	if clean_id.is_empty():
		return ""

	for raw_track_key in GameTrackCatalog.TRACK_ORDER:
		var track_key := str(raw_track_key)
		var definition: Variant = GameTrackCatalog.TRACK_DEFINITIONS.get(track_key, {})
		if definition is Dictionary:
			for raw_prefix in (definition as Dictionary).get("teaching_key_prefixes", []):
				if clean_id.begins_with(str(raw_prefix)):
					return track_key
		if clean_id.begins_with(track_key + "_"):
			return track_key
	return ""


static func restriction_a_track_key(restriction: String) -> String:
	return restriction.strip_edges().to_lower()


static func _construir_node_progress(completed_nodes: Variant) -> Dictionary:
	var node_progress: Dictionary = {}
	if not completed_nodes is Array:
		return node_progress

	for raw_entry in completed_nodes:
		if not raw_entry is Dictionary:
			continue
		var node_id := str(raw_entry.get("node_id", "")).strip_edges()
		if node_id.is_empty():
			continue
		var accuracy := _normalizar_precision(raw_entry.get("best_accuracy", 0))
		var percent := clampf(accuracy / 100.0, 0.0, 1.0)
		node_progress[node_id] = {
			"completed": true,
			"best_accuracy": accuracy,
			"best_percent": percent,
			"last_accuracy": accuracy,
			"last_percent": percent,
		}
	return node_progress


static func _construir_question_progress_por_track(completed_nodes: Variant) -> Dictionary:
	var by_track: Dictionary = {}
	if not completed_nodes is Array:
		return by_track

	for raw_entry in completed_nodes:
		if not raw_entry is Dictionary:
			continue
		var node_id := str(raw_entry.get("node_id", "")).strip_edges()
		if node_id.is_empty():
			continue
		var track_key := inferir_track_key_desde_node_id(node_id)
		if track_key.is_empty():
			continue
		if not by_track.has(track_key):
			by_track[track_key] = {}
		(by_track[track_key] as Dictionary)[node_id] = true
	return by_track


static func _construir_estado_racha(racha_online: Variant) -> Dictionary:
	if not racha_online is Dictionary:
		return {}
	var racha: Dictionary = racha_online as Dictionary
	var streak_state := {
		"current_count": max(0, int(racha.get("current_count", 0))),
		"best_count": max(0, int(racha.get("best_count", 0))),
		"last_activity_day": str(racha.get("last_activity_day", "")),
	}
	return GameStreakTrackerScript.leer(streak_state)


## Normaliza la racha del servidor al formato local validado.
static func construir_estado_racha_online(racha_online: Variant) -> Dictionary:
	return _construir_estado_racha(racha_online)


## Conserva la racha mas avanzada entre save local y servidor.
static func fusionar_estado_racha(local: Dictionary, online: Dictionary) -> Dictionary:
	var local_read := GameStreakTrackerScript.leer(local)
	var online_read := GameStreakTrackerScript.leer(online)
	if local_read.is_empty():
		return online_read
	if online_read.is_empty():
		return local_read

	var local_count := int(local_read.get("current_count", 0))
	var online_count := int(online_read.get("current_count", 0))
	if local_count > online_count:
		return local_read
	if online_count > local_count:
		return online_read

	var local_day := str(local_read.get("last_activity_day", ""))
	var online_day := str(online_read.get("last_activity_day", ""))
	if local_day > online_day:
		return local_read
	return online_read


static func _calcular_exp_total(progreso_online: Dictionary) -> int:
	var exp_total := 0
	var perfil_online: Variant = progreso_online.get("profile", {})
	if perfil_online is Dictionary:
		exp_total = int((perfil_online as Dictionary).get("exp_count", 0))
	if exp_total > 0:
		return exp_total

	for raw_progress in progreso_online.get("progress", []):
		if raw_progress is Dictionary:
			exp_total += int((raw_progress as Dictionary).get("total_exp", 0))
	return max(0, exp_total)


static func _normalizar_precision(raw_value: Variant) -> float:
	var value := float(raw_value)
	if value <= 0.0:
		return 0.0
	return value * 100.0 if value <= 1.0 else value


static func _obtener_etiqueta_pista(track_key: String) -> String:
	var definition: Variant = GameTrackCatalog.TRACK_DEFINITIONS.get(track_key, {})
	if definition is Dictionary:
		var summary_label := str((definition as Dictionary).get("summary_label", "")).strip_edges()
		if not summary_label.is_empty():
			return summary_label
		var label := str((definition as Dictionary).get("label", "")).strip_edges()
		if not label.is_empty():
			return label
	return track_key.capitalize()


static func _mensaje_aprendizaje_clave(
	track_key: String,
	completados: int,
	total_nodos: int
) -> String:
	if completados <= 0:
		return "Todavia no completaste nodos en este mapa. Empeza por el primero desbloqueado."
	if MENSAJES_APRENDIZAJE_POR_PISTA.has(track_key):
		return str(MENSAJES_APRENDIZAJE_POR_PISTA[track_key])
	if completados >= total_nodos and total_nodos > 0:
		return "Completaste todos los desafios de este mapa. Excelente trabajo."
	return "Segui practicando para consolidar lo aprendido en cada nodo."


static func _mensaje_sugerencia(completados: int, total_nodos: int) -> String:
	if completados <= 0:
		return "Entra al mapa y completa tu primer nodo para empezar a sumar progreso."
	if total_nodos > 0 and completados >= total_nodos:
		return "Proba otro mapa o repasa nodos para mejorar tu precision."
	var restantes := maxi(total_nodos - completados, 0)
	return "Te faltan %d desafios para completar el mapa." % restantes
