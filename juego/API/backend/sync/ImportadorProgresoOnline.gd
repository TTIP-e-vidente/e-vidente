class_name ImportadorProgresoOnline
extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameStreakTrackerScript := preload("res://niveles/progress/GameStreakTracker.gd")
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const QUESTION_PROGRESS_KEY := "question_progress"
const STREAK_KEY := "streak"

const MENSAJES_APRENDIZAJE_POR_PISTA := {
	GameTrackCatalog.TRACK_CELIAQUIA: "El sello sin TACC ayuda a identificar alimentos seguros.",
}


static func construir_snapshot_local(progreso_online: Dictionary) -> Dictionary:
	var parsed := _parsear_completed_nodes(progreso_online.get("completedNodes", []))
	var streak_state := _construir_estado_racha(progreso_online.get("streak", {}))

	return {
		"node_progress": parsed.node_progress,
		"total_exp": _calcular_exp_total(progreso_online),
		"streak_state": streak_state,
		"question_progress_by_track": parsed.question_progress,
		"progress_snapshot": {
			"progress_system_states": {
				QUESTION_PROGRESS_KEY: parsed.question_progress.duplicate(true),
				STREAK_KEY: streak_state.duplicate(true),
			}
		},
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

	for key in ["birth_date", "fecha_nacimiento", "birthDate"]:
		if not usuario.has(key):
			continue
		var birth_date := SaveLocalProfileHelperScript.normalizar_fecha_nacimiento(
			usuario.get(key)
		)
		if not birth_date.is_empty():
			parche["birth_date"] = birth_date
			break

	return parche


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


static func _parsear_completed_nodes(completed_nodes: Variant) -> Dictionary:
	var node_progress: Dictionary = {}
	var question_progress: Dictionary = {}
	if not completed_nodes is Array:
		return {"node_progress": node_progress, "question_progress": question_progress}

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
		var track_key := inferir_track_key_desde_node_id(node_id)
		if not track_key.is_empty():
			if not question_progress.has(track_key):
				question_progress[track_key] = {}
			(question_progress[track_key] as Dictionary)[node_id] = true
	return {"node_progress": node_progress, "question_progress": question_progress}


static func fusionar_node_progress(local: Dictionary, online: Dictionary) -> Dictionary:
	var merged: Dictionary = local.duplicate(true) if local is Dictionary else {}
	if not online is Dictionary:
		return merged
	for raw_node_id in online.keys():
		var node_id := str(raw_node_id).strip_edges()
		if node_id.is_empty():
			continue
		var online_entry: Variant = online[raw_node_id]
		if not online_entry is Dictionary:
			continue
		if not merged.has(node_id):
			merged[node_id] = (online_entry as Dictionary).duplicate(true)
			continue
		var local_entry: Variant = merged[node_id]
		if local_entry is Dictionary:
			merged[node_id] = _fusionar_entrada_node_progress(
				local_entry as Dictionary,
				online_entry as Dictionary
			)
	return merged


static func _fusionar_entrada_node_progress(local: Dictionary, online: Dictionary) -> Dictionary:
	var merged_entry: Dictionary = local.duplicate(true)
	merged_entry["completed"] = bool(local.get("completed", false)) or bool(
		online.get("completed", false)
	)
	merged_entry["best_accuracy"] = maxf(
		float(local.get("best_accuracy", 0.0)),
		float(online.get("best_accuracy", 0.0))
	)
	merged_entry["last_accuracy"] = maxf(
		float(local.get("last_accuracy", merged_entry["best_accuracy"])),
		float(online.get("last_accuracy", online.get("best_accuracy", 0.0)))
	)
	merged_entry["best_percent"] = clampf(
		maxf(float(local.get("best_percent", 0.0)), float(online.get("best_percent", 0.0))),
		0.0,
		1.0
	)
	merged_entry["last_percent"] = clampf(
		maxf(float(local.get("last_percent", 0.0)), float(online.get("last_percent", 0.0))),
		0.0,
		1.0
	)
	return merged_entry


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


static func construir_estado_racha_online(racha_online: Variant) -> Dictionary:
	return _construir_estado_racha(racha_online)


static func fusionar_estado_racha(local: Dictionary, online: Dictionary) -> Dictionary:
	var local_read := GameStreakTrackerScript.leer(local)
	var online_read := GameStreakTrackerScript.leer(online)
	if local_read.is_empty():
		return online_read
	if online_read.is_empty():
		return local_read

	var local_count := int(local_read.get("current_count", 0))
	var online_count := int(online_read.get("current_count", 0))
	var local_day := str(local_read.get("last_activity_day", ""))
	var online_day := str(online_read.get("last_activity_day", ""))

	var today := Time.get_date_string_from_system(true)
	var local_alive := _es_racha_vigente(local_day, today)
	var online_alive := _es_racha_vigente(online_day, today)

	if not local_alive:
		local_count = 0
	if not online_alive:
		online_count = 0

	var ganador: Dictionary
	if local_count > online_count:
		ganador = local_read.duplicate(true)
	elif online_count > local_count:
		ganador = online_read.duplicate(true)
	elif local_day > online_day:
		ganador = local_read.duplicate(true)
	else:
		ganador = online_read.duplicate(true)

	if not local_alive and not online_alive:
		ganador["current_count"] = 0

	ganador["best_count"] = maxi(
		int(local_read.get("best_count", 0)),
		int(online_read.get("best_count", 0))
	)
	return ganador


static func _es_racha_vigente(last_day: String, today: String) -> bool:
	if last_day.is_empty() or today.is_empty():
		return false
	if last_day == today:
		return true
	var unix_last := int(Time.get_unix_time_from_datetime_string(last_day))
	var unix_today := int(Time.get_unix_time_from_datetime_string(today))
	if unix_last <= 0 or unix_today <= 0:
		return false
	var diff_days := int(float(absi(unix_today - unix_last)) / 86400.0)
	return diff_days <= 1


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
