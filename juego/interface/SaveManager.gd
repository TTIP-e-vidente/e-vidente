# PUBLICO_TRAINEE
# Fuente de verdad para persistencia local: total_exp, racha, ranking, perfil.
# No decide gameplay. No abre escenas.
extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveDiskWriterScript := preload(
	"res://interface/save_local/write/SaveDiskWriter.gd"
)
const SaveDataSchemaScript := preload(
	"res://interface/save_local/data/SaveDataSchema.gd"
)
const SaveDataLoaderScript := preload(
	"res://interface/save_local/data/SaveDataLoader.gd"
)
const SaveResumeStateScript := preload(
	"res://interface/save_local/data/SaveResumeState.gd"
)
const ImportadorProgresoOnlineScript := preload(
	"res://API/backend/sync/ImportadorProgresoOnline.gd"
)

@warning_ignore("unused_signal")
signal user_registered(profile: Dictionary)
@warning_ignore("unused_signal")
signal progress_saved(profile: Dictionary)
@warning_ignore("unused_signal")
signal progress_loaded(profile: Dictionary)
signal save_status_changed(status: Dictionary)

const SAVE_PATH := SaveDataLoaderScript.SAVE_PATH
const TEMP_SAVE_PATH := SaveDataLoaderScript.TEMP_SAVE_PATH
const BACKUP_SAVE_PATH := SaveDataLoaderScript.BACKUP_SAVE_PATH
const AVATARS_DIR := "user://avatars"
const DEFAULT_PROFILE_NAME := SaveDataSchemaScript.DEFAULT_PROFILE_NAME
const SAVE_VERSION := SaveDataSchemaScript.SAVE_VERSION
const ARCHIVERO_SCENE := SaveDataSchemaScript.ARCHIVERO_SCENE
const RESUME_CONTEXT_HUB := SaveResumeStateScript.RESUME_CONTEXT_HUB
const RESUME_CONTEXT_BOOK := SaveResumeStateScript.RESUME_CONTEXT_BOOK
const RESUME_CONTEXT_LEVEL := SaveResumeStateScript.RESUME_CONTEXT_LEVEL
const LOCAL_SAVE_ID := "local_save"
const LOCAL_SAVE_TITLE := "Partida actual"
const LOCAL_PROFILE_KEY := "local_profile"
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]

var save_data: Dictionary = {}
var has_unsaved_changes: bool = false
var _save_state: String = "idle"
var _loaded_from: String = "default"
var _recovered_from: String = ""
var _last_error: String = ""

var _profile_helper: RefCounted
var _disk_writer: RefCounted
var _schema: RefCounted
var _data_loader: RefCounted
var _resume_helper: RefCounted
var _global_autoload: Node = null


func _init() -> void:
	_profile_helper = SaveLocalProfileHelperScript.new()
	_disk_writer = SaveDiskWriterScript.new()
	_schema = SaveDataSchemaScript.new()
	_data_loader = SaveDataLoaderScript.new()
	_resume_helper = SaveResumeStateScript.new()


func _ready() -> void:
	cargar_datos()
	ArmadorDePartida.inicializar_con_save_manager(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_progreso_en_disco()


func cargar_datos() -> void:
	save_data = _data_loader.cargar_datos()

	var needs_write: bool = bool(_data_loader.needs_write)
	var loaded_from: String = str(_data_loader.loaded_from)
	var recovered_from: String = str(_data_loader.recovered_from)
	var rewrite_reason: String = str(_data_loader.rewrite_reason)
	if _reparar_datos_guardado_cargados():
		needs_write = true

	if needs_write:
		_escribir_despues_reparacion_carga(
			loaded_from,
			recovered_from,
			rewrite_reason
		)
	else:
		has_unsaved_changes = false
		_emitir_estado_guardado("leery", loaded_from)

	var saved_progress: Variant = save_data.get("progress", {})
	print_debug("[Save] loaded_from=", loaded_from)
	print_debug("[Save] profile=", obtener_perfil_usuario_actual())
	var progress_keys: Array = []
	if saved_progress is Dictionary:
		progress_keys = (saved_progress as Dictionary).keys()
	print_debug("[Save] progress_keys=", progress_keys)
	print_debug("[Save] node_progress_keys=", obtener_todo_progreso_nodos().keys())
	_global_importar_progreso(saved_progress if saved_progress is Dictionary else {})
	progress_loaded.emit(obtener_perfil_usuario_actual())


func actualizar_perfil_local(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	var validation: Dictionary = _profile_helper.validar_perfil(
		username,
		age,
		email,
		avatar_source_path
	)
	if not bool(validation.get("ok", false)):
		return validation

	var profile: Dictionary = obtener_perfil_usuario_actual()
	var avatar_result: Dictionary = _actualizar_avatar_perfil(profile, avatar_source_path)
	if not bool(avatar_result.get("ok", false)):
		return avatar_result

	_aplicar_actualizaciones_identidad_perfil(profile, username, age, email)
	save_data["profile"] = profile
	return _persistir_perfil_actualizado()


func cargar_textura_avatar(path: String) -> Texture2D:
	return _profile_helper.cargar_textura_avatar(path)


func obtener_textura_avatar_usuario_actual() -> Texture2D:
	var avatar_path: String = obtener_ruta_avatar_usuario_actual()
	if avatar_path.is_empty():
		return null
	return cargar_textura_avatar(avatar_path)


func obtener_perfil_usuario_actual() -> Dictionary:
	var stored_profile: Variant = save_data.get("profile", {})
	if not stored_profile is Dictionary:
		return {}

	var profile: Dictionary = _profile_helper.normalizar_datos_perfil(
		stored_profile,
		DEFAULT_PROFILE_NAME
	)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
	return profile


func obtener_nombre_usuario_actual() -> String:
	var username: String = str(
		obtener_perfil_usuario_actual().get("username", DEFAULT_PROFILE_NAME)
	).strip_edges()
	return username if not username.is_empty() else DEFAULT_PROFILE_NAME


func obtener_email_usuario_actual() -> String:
	return str(obtener_perfil_usuario_actual().get("email", "")).strip_edges()


func obtener_edad_usuario_actual() -> int:
	return max(0, int(obtener_perfil_usuario_actual().get("age", 0)))


func obtener_ruta_avatar_usuario_actual() -> String:
	return str(obtener_perfil_usuario_actual().get("avatar_path", "")).strip_edges()


func obtener_estado_guardado_actual() -> String:
	return _save_state


func tiene_error_guardado() -> bool:
	return _save_state == "error"


func obtener_ultimo_guardado_en() -> String:
	return str(_obtener_meta_guardado().get("last_saved_at", ""))


func obtener_motivo_ultimo_guardado() -> String:
	return str(_obtener_meta_guardado().get("last_saved_reason", ""))


func obtener_error_ultimo_guardado() -> String:
	return _last_error.strip_edges()


func guardar_progreso_en_disco() -> void:
	_guardar_estado_actual("progress_sync")


func registrar_guardado_manual() -> void:
	var resume: Dictionary = obtener_estado_reanudacion()
	_guardar_estado_actual(
		"manual_save",
		"Guardado manual",
		{
			"type": "manual_save",
			"context": str(resume.get("context", RESUME_CONTEXT_HUB)),
			"track": str(resume.get("track_key", "")),
			"level": int(resume.get("level_number", _global_obtener_numero_nivel_actual()))
		}
	)


func registrar_nivel_completado(track_key: String, level_number: int) -> void:
	_global_limpiar_estado_parcial_nivel(track_key, level_number)
	_actualizar_reanudacion_despues_nivel_completado(track_key, level_number)
	_guardar_estado_actual(
		"level_completed",
		_construir_mensaje_nivel_completado(track_key, level_number),
		{"type": "level_completed", "track": track_key, "level": level_number}
	)


func registrar_sesion_preguntas_completada(question_count: int, score: int) -> void:
	if question_count < 1:
		return

	_global_registrar_actividad_racha(
		"question_session_completed",
		{"question_count": question_count, "score": score}
	)
	_guardar_estado_actual(
		"question_session_completed",
		"Sesion de preguntas completada (%d/%d)" % [score, question_count],
		{
			"type": "question_session_completed",
			"question_count": question_count,
			"score": score
		}
	)



func marcar_actividad_completada(request_key: String, activity_id: String) -> void:
	var clean_key: String = request_key.strip_edges()
	var clean_id: String = activity_id.strip_edges()
	if clean_id.is_empty():
		return
	if clean_key.is_empty():
		clean_key = "__global__"
	var stored: Variant = save_data.get("completed_activity_ids_by_request", {})
	var completed_map: Dictionary = stored if stored is Dictionary else {}
	var raw_ids: Variant = completed_map.get(clean_key, [])
	var id_list: Array = raw_ids if raw_ids is Array else []
	if id_list.has(clean_id):
		return
	id_list.append(clean_id)
	completed_map[clean_key] = id_list
	save_data["completed_activity_ids_by_request"] = completed_map
	_marcar_guardado_sucio()
	print("[PersistentRandom] mark_completed request=%s activity=%s" % [clean_key, clean_id])
	guardar_progreso_en_disco()
	print("[PersistentRandom] save_updated=true")


func obtener_ids_actividades_completadas(request_key: String) -> Array[String]:
	var clean_key: String = request_key.strip_edges()
	var stored: Variant = save_data.get("completed_activity_ids_by_request", {})
	if not stored is Dictionary:
		return []
	var raw_ids: Variant = (stored as Dictionary).get(clean_key, [])
	if not raw_ids is Array:
		return []
	var result: Array[String] = []
	for entry in (raw_ids as Array):
		result.append(str(entry))
	return result


## Marca una actividad como "jugada" en la sesión actual.
## Para request_key vacío (juegos fijos / legacy) usa "__global__" y también
## la guarda en completed_activity_ids_by_request para que el filtro de
## anti-repetición la vea vía obtener_ids_actividades_completadas("__global__").
func marcar_actividad_jugada(request_key: String, activity_id: String) -> void:
	var clean_id: String = activity_id.strip_edges()
	var clean_key: String = request_key.strip_edges()
	if clean_id.is_empty():
		return
	if clean_key.is_empty():
		clean_key = "__global__"
	var played_stored: Variant = save_data.get("played_activity_ids_by_request", {})
	var played_map: Dictionary = played_stored if played_stored is Dictionary else {}
	var raw_played: Variant = played_map.get(clean_key, [])
	var played_list: Array = raw_played if raw_played is Array else []
	if not played_list.has(clean_id):
		played_list.append(clean_id)
		played_map[clean_key] = played_list
		save_data["played_activity_ids_by_request"] = played_map
		_marcar_guardado_sucio()
	# Para clave global también almacenamos en completed para que
	# obtener_ids_actividades_completadas("__global__") las devuelva.
	if clean_key == "__global__":
		var cstored: Variant = save_data.get("completed_activity_ids_by_request", {})
		var cmap: Dictionary = cstored if cstored is Dictionary else {}
		var raw_c: Variant = cmap.get("__global__", [])
		var c_list: Array = raw_c if raw_c is Array else []
		if not c_list.has(clean_id):
			c_list.append(clean_id)
			cmap["__global__"] = c_list
			save_data["completed_activity_ids_by_request"] = cmap
			_marcar_guardado_sucio()


## Devuelve todos los activity_ids jugados (de cualquier request_key).
func obtener_ids_actividades_jugadas() -> Array[String]:
	var stored: Variant = save_data.get("played_activity_ids_by_request", {})
	if not stored is Dictionary:
		return []
	var result: Array[String] = []
	for raw_ids: Variant in (stored as Dictionary).values():
		if not raw_ids is Array:
			continue
		for entry: Variant in (raw_ids as Array):
			var id: String = str(entry).strip_edges()
			if not id.is_empty() and not result.has(id):
				result.append(id)
	return result


## Devuelve todos los activity_ids completados, de cualquier request_key.
func obtener_todos_ids_actividades_completadas() -> Array[String]:
	var stored: Variant = save_data.get("completed_activity_ids_by_request", {})
	if not stored is Dictionary:
		return []
	var result: Array[String] = []
	for raw_ids: Variant in (stored as Dictionary).values():
		if not raw_ids is Array:
			continue
		for entry: Variant in (raw_ids as Array):
			var id: String = str(entry).strip_edges()
			if not id.is_empty() and not result.has(id):
				result.append(id)
	return result


## Devuelve la unión de jugados y completados.
## Usado por ArmadorDePartida._leer_used_activity_ids para el filtro anti-repetición.
func obtener_todos_ids_actividades_usadas() -> Array[String]:
	var result: Array[String] = obtener_ids_actividades_jugadas()
	for id: String in obtener_todos_ids_actividades_completadas():
		if not result.has(id):
			result.append(id)
	return result


func reiniciar_pool_actividades_completadas(request_key: String) -> void:
	var clean_key: String = request_key.strip_edges()
	var stored: Variant = save_data.get("completed_activity_ids_by_request", {})
	if not stored is Dictionary:
		return
	var completed_map: Dictionary = stored as Dictionary
	if completed_map.has(clean_key):
		completed_map.erase(clean_key)
		save_data["completed_activity_ids_by_request"] = completed_map
		_marcar_guardado_sucio()


func depurar_limpiar_historial_actividades() -> void:
	save_data["completed_activity_ids_by_request"] = {}
	_marcar_guardado_sucio()
	print("[PersistentRandom] depurar_limpiar_historial_actividades done")


func obtener_exp_total() -> int:
	return max(0, int(save_data.get("total_exp", 0)))


func sumar_exp(amount: int) -> int:
	if amount <= 0:
		return obtener_exp_total()
	var nuevo_total: int = obtener_exp_total() + amount
	save_data["total_exp"] = nuevo_total
	_marcar_guardado_sucio()
	guardar_progreso_en_disco()
	return nuevo_total


func obtener_posicion_ranking() -> int:
	return _calcular_ranking(obtener_exp_total())


func _calcular_ranking(total: int) -> int:
	if total >= 300:
		return 1
	if total >= 200:
		return 2
	if total >= 120:
		return 3
	if total >= 60:
		return 5
	if total >= 30:
		return 10
	return 20


func guardar_precision_nodo(
	node_id: String,
	accuracy: float,
	completed_games: int = -1,
	total_games: int = -1
) -> void:
	var clean_id: String = node_id.strip_edges()
	if clean_id.is_empty():
		return
	var stored: Variant = save_data.get("node_progress", {})
	var node_progress: Dictionary = stored if stored is Dictionary else {}
	var entry: Dictionary = {}
	if node_progress.has(clean_id):
		var prev: Variant = node_progress[clean_id]
		if prev is Dictionary:
			entry = (prev as Dictionary).duplicate(true)
	var prev_best: float = float(entry.get("best_accuracy", 0.0))
	var percent: float = clampf(accuracy / 100.0, 0.0, 1.0)
	var prev_best_percent: float = float(entry.get("best_percent", prev_best / 100.0))
	var best_percent: float = maxf(prev_best_percent, percent)
	entry["best_accuracy"] = maxf(prev_best, accuracy)
	entry["best_percent"] = best_percent
	entry["last_accuracy"] = accuracy
	entry["last_percent"] = percent
	entry["completed"] = true
	print_debug(
		"[Progress] update node_key=",
		clean_id,
		" best_percent=",
		best_percent,
		" completed=",
		entry["completed"],
		" completed_games=",
		completed_games,
		" total_games=",
		total_games
	)
	node_progress[clean_id] = entry
	save_data["node_progress"] = node_progress
	_marcar_guardado_sucio()
	guardar_progreso_en_disco()


func marcar_recompensa_del_mapa_como_vista(map_id: String) -> void:
	## Marca que la recompensa del mapa ya fue mostrada al jugador.
	## Evita volver a mostrar el cartel CapituloCompletado al recargar el mapa.
	var clean_id: String = map_id.strip_edges()
	if clean_id.is_empty():
		return
	var seen: Variant = save_data.get("map_reward_seen", {})
	var seen_map: Dictionary = seen if seen is Dictionary else {}
	seen_map[clean_id] = true
	save_data["map_reward_seen"] = seen_map
	_marcar_guardado_sucio()
	guardar_progreso_en_disco()
	print("[MapCompletion] marcar_recompensa_del_mapa_como_vista map_id=", clean_id)


func ya_se_mostro_recompensa_del_mapa(map_id: String) -> bool:
	## Devuelve true si ya se mostró la recompensa del mapa al jugador en esta sesión o sesiones anteriores.
	var clean_id: String = map_id.strip_edges()
	if clean_id.is_empty():
		return false
	var seen: Variant = save_data.get("map_reward_seen", {})
	if not seen is Dictionary:
		return false
	return bool((seen as Dictionary).get(clean_id, false))


func obtener_mejor_precision_nodo(node_id: String) -> float:
	var clean_id: String = node_id.strip_edges()
	var stored: Variant = save_data.get("node_progress", {})
	if not stored is Dictionary:
		return 0.0
	var entry: Variant = (stored as Dictionary).get(clean_id, {})
	if not entry is Dictionary:
		return 0.0
	return float((entry as Dictionary).get("best_accuracy", 0.0))


func obtener_todo_progreso_nodos() -> Dictionary:
	var stored: Variant = save_data.get("node_progress", {})
	return (stored as Dictionary).duplicate(true) if stored is Dictionary else {}


func obtener_cuenta_online_vinculada() -> String:
	return str(_obtener_meta_guardado().get("linked_online_username", "")).strip_edges()


## Alinea el save local con la cuenta online activa.
## Si cambió el usuario, reinicia progreso local e importa el del servidor.
func sincronizar_con_cuenta_online(usuario: Dictionary, progreso_online: Dictionary) -> void:
	var username := str(usuario.get("username", "")).strip_edges()
	if username.is_empty():
		return

	var linked := obtener_cuenta_online_vinculada()
	if linked != username:
		_reiniciar_progreso_juego_preservando_perfil()

	_importar_progreso_online(progreso_online)
	_aplicar_parche_perfil_online(usuario)
	_establecer_cuenta_online_vinculada(username)

	if not _escribir_guardado_en_disco(false, "online_sync"):
		push_warning("[Save] No se pudo persistir la sync con la cuenta online.")
		return

	progress_loaded.emit(obtener_perfil_usuario_actual())


func al_cerrar_sesion_online() -> void:
	_establecer_cuenta_online_vinculada("")
	_marcar_guardado_sucio()
	guardar_progreso_en_disco()


func reiniciar_todo_progreso() -> Dictionary:
	var current_profile: Dictionary = obtener_perfil_usuario_actual()
	_reiniciar_datos_guardado_actual(current_profile)
	if not _escribir_guardado_en_disco(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}
	progress_loaded.emit(current_profile)
	progress_saved.emit(current_profile)
	return {"ok": true, "message": "Se reinicio el progreso local.", "profile": current_profile}


func establecer_reanudar_en_libro(track_key: String, allow_level_downgrade: bool = false) -> void:
	if (
		not allow_level_downgrade
		and str(obtener_estado_reanudacion().get("context", RESUME_CONTEXT_HUB)) == RESUME_CONTEXT_LEVEL
	):
		return
	_almacenar_estado_reanudacion(
		_resume_helper.construir_para_libro(track_key, _global_obtener_numero_nivel_actual())
	)


func establecer_reanudar_en_nivel(track_key: String, level_number: int = -1) -> void:
	var level: int = _global_obtener_numero_nivel_actual() if level_number < 1 else level_number
	_almacenar_estado_reanudacion(_resume_helper.construir_para_nivel(track_key, level))


func obtener_estado_reanudacion() -> Dictionary:
	return _resume_helper.resolver_desde_guardado(save_data, ARCHIVERO_SCENE)


func obtener_pista_reanudacion_actual() -> String:
	return _resume_helper.formatear_pista(obtener_estado_reanudacion())


func puede_reanudar_guardado_actual() -> bool:
	var summary: Dictionary = _resumir_progreso(save_data.get("progress", {}))
	if int(summary.get("total", 0)) > 0:
		return true
	if str(obtener_estado_reanudacion().get("context", RESUME_CONTEXT_HUB)) != RESUME_CONTEXT_HUB:
		return true
	return _historial_tiene_jugabilidad(save_data.get("history", []))


func recargar_desde_disco_y_obtener_reanudacion() -> Dictionary:
	cargar_datos()
	var resume_state: Dictionary = obtener_estado_reanudacion()
	var clamped_level_number: int = clampi(
		int(resume_state.get("level_number", _global_obtener_numero_nivel_actual())),
		1,
		max(1, _global_obtener_cantidad_niveles_pista(str(resume_state.get("track_key", ""))))
	)
	_global_establecer_numero_nivel_actual(
		clamped_level_number,
		str(resume_state.get("track_key", ""))
	)
	return resume_state


func obtener_estado_guardado() -> Dictionary:
	var meta: Dictionary = _obtener_meta_guardado()
	var save_summary: Dictionary = obtener_resumen_guardado_actual()
	return {
		"state": _save_state,
		"last_saved_at": str(meta.get("last_saved_at", "")),
		"last_saved_reason": str(meta.get("last_saved_reason", "")),
		"write_count": max(0, int(meta.get("write_count", 0))),
		"last_loaded_from": _loaded_from,
		"recovered_from": _recovered_from,
		"last_error": _last_error,
		"has_unsaved_changes": has_unsaved_changes,
		"save_id": str(save_summary.get("id", "")),
		"save_title": str(save_summary.get("title", "")),
		"save_count": 1 if not save_summary.is_empty() else 0
	}


func obtener_resumen_guardado_actual() -> Dictionary:
	if not puede_reanudar_guardado_actual():
		return {}

	var profile: Dictionary = obtener_perfil_usuario_actual()
	var meta: Dictionary = _obtener_meta_guardado()
	var resume: Dictionary = obtener_estado_reanudacion()
	var progress: Dictionary = _resumir_progreso(save_data.get("progress", {}))
	var updated_at: String = str(meta.get("last_saved_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("updated_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("created_at", ""))

	return {
		"id": LOCAL_SAVE_ID,
		"title": LOCAL_SAVE_TITLE,
		"created_at": str(profile.get("created_at", "")),
		"updated_at": updated_at,
		"resume_hint": _resume_helper.formatear_pista(resume),
		"resume_context": str(resume.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume.get("track_key", "")),
		"resume_level_number": int(resume.get("level_number", 1)),
		"progress_summary": progress,
		"can_resume": true,
		"is_active": true
	}


func obtener_historial_guardado_actual() -> Array:
	var stored: Variant = save_data.get("history", [])
	return stored.duplicate(true) if stored is Array else []


func _obtener_meta_guardado() -> Dictionary:
	return _schema.normalizar_meta_guardado(save_data.get("save_meta", {}))


func _reparar_datos_guardado_cargados() -> bool:
	var needs_write_after_repair: bool = false
	if _data_loader.reparar_estructura(save_data):
		_marcar_guardado_sucio()
		needs_write_after_repair = true
	if _resume_helper.reparar(save_data, ARCHIVERO_SCENE):
		_marcar_guardado_sucio()
		needs_write_after_repair = true
	return needs_write_after_repair


func _actualizar_avatar_perfil(profile: Dictionary, avatar_source_path: String) -> Dictionary:
	var previous_avatar_path: String = str(profile.get("avatar_path", "")).strip_edges()
	return _profile_helper.aplicar_cambio_avatar(
		profile,
		avatar_source_path.strip_edges(),
		previous_avatar_path,
		AVATARS_DIR,
		LOCAL_PROFILE_KEY
	)


func _aplicar_actualizaciones_identidad_perfil(
	profile: Dictionary,
	username: String,
	age: int,
	email: String
) -> void:
	_profile_helper.aplicar_cambios_identidad(profile, username, age, email, DEFAULT_PROFILE_NAME)
	_profile_helper.estampar_timestamps(profile)


func _actualizar_reanudacion_despues_nivel_completado(track_key: String, level_number: int) -> void:
	if level_number < _global_obtener_cantidad_niveles_pista(track_key):
		establecer_reanudar_en_nivel(track_key, level_number + 1)
		return
	_almacenar_estado_reanudacion(_resume_helper.obtener_estado_predeterminado(ARCHIVERO_SCENE))


func _construir_mensaje_nivel_completado(track_key: String, level_number: int) -> String:
	var track_label: String = GameTrackCatalog.obtener_etiqueta_pista(track_key, track_key)
	return "Completaste %s - capitulo %d" % [track_label, level_number]


func _guardar_estado_actual(
	reason: String,
	history_message: String = "",
	history_metadata: Dictionary = {},
	emit_progress_saved: bool = true
) -> bool:
	save_data["profile"] = obtener_perfil_usuario_actual()
	save_data["progress"] = _global_exportar_progreso()
	_marcar_guardado_sucio()
	if not history_message.is_empty():
		_schema.agregar_historial(save_data, history_message, history_metadata)
	if not _escribir_guardado_en_disco(false, reason):
		return false
	if emit_progress_saved:
		progress_saved.emit(obtener_perfil_usuario_actual())
	return true


func _almacenar_estado_reanudacion(raw: Dictionary) -> void:
	var next_resume_state: Dictionary = _resume_helper.normalizar(raw, ARCHIVERO_SCENE)
	var current_resume_state: Dictionary = _resume_helper.normalizar(
		save_data.get("resume_state", {}),
		ARCHIVERO_SCENE
	)
	save_data["resume_state"] = next_resume_state
	if current_resume_state != next_resume_state:
		_marcar_guardado_sucio()


func _escribir_guardado_en_disco(force: bool = false, reason: String = "save") -> bool:
	if not force and not has_unsaved_changes:
		return true

	var progress: Variant = save_data.get("progress", {})
	print_debug("[Save] saving path=", ProjectSettings.globalize_path(SAVE_PATH))
	var progress_keys: Array = (progress as Dictionary).keys() if progress is Dictionary else []
	print_debug("[Save] progress_keys=", progress_keys)
	print_debug("[Save] node_progress_keys=", obtener_todo_progreso_nodos().keys())
	var result: Dictionary = _disk_writer.escribir(save_data, _loaded_from, reason)
	if not bool(result.get("ok", false)):
		print_debug("[Save] write_ok=", false)
		_emitir_estado_guardado(
			"error",
			_loaded_from,
			_recovered_from,
			str(result.get("error_message", "Error desconocido al guardar."))
		)
		return false

	print_debug("[Save] write_ok=", true)
	if bool(result.get("wrote_primary", false)):
		_loaded_from = "primary"
		_recovered_from = ""

	has_unsaved_changes = false
	_emitir_estado_guardado("saved", _loaded_from, _recovered_from)
	return true


func _historial_tiene_jugabilidad(raw_history: Variant) -> bool:
	if not raw_history is Array:
		return false
	for history_entry in raw_history:
		var metadata: Dictionary = _leer_metadata_historial(history_entry)
		if not metadata.is_empty() and GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
			return true
	return false


func _leer_metadata_historial(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var metadata: Variant = entry.get("metadata", {})
	return metadata if metadata is Dictionary else {}


func _resumir_progreso(progress: Variant) -> Dictionary:
	var progress_data: Dictionary = progress if progress is Dictionary else {}
	var summary: Dictionary = {"total": 0, "max_total": 0}
	for raw_track_key in GameTrackCatalog.obtener_claves_pista():
		var track_key: String = str(raw_track_key)
		var flags: Variant = progress_data.get(track_key, [])
		var completed: int = 0
		if flags is Array:
			for flag_value in flags:
				if bool(flag_value):
					completed += 1
		summary[track_key] = completed
		summary["total"] += completed
		summary["max_total"] += _global_obtener_cantidad_niveles_pista(track_key)
	return summary


func _reiniciar_datos_guardado_actual(profile: Dictionary) -> void:
	var settings: Dictionary = _obtener_settings_guardado_actual()
	var streak_state: Dictionary = _obtener_racha_actual_para_preservar()
	_global_reiniciar_progreso()
	_global_establecer_racha(streak_state)
	save_data["profile"] = profile
	if not settings.is_empty():
		save_data["settings"] = settings
	save_data["progress"] = _global_exportar_progreso()
	save_data["history"] = []
	save_data["node_progress"] = {}
	save_data["total_exp"] = 0
	save_data["completed_activity_ids_by_request"] = {}
	save_data["map_reward_seen"] = {}
	save_data["resume_state"] = _resume_helper.obtener_estado_predeterminado(ARCHIVERO_SCENE)
	save_data["save_meta"] = _meta_guardado_vacia()
	_marcar_guardado_sucio()


func _obtener_autoload_global() -> Node:
	if _global_autoload == null or not is_instance_valid(_global_autoload):
		_global_autoload = get_node_or_null("/root/Global")
	return _global_autoload


func _global_importar_progreso(progress_snapshot: Dictionary) -> void:
	print_debug("[GlobalProgress] loaded progress=", progress_snapshot)
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("importar_progreso"):
		global_autoload.call("importar_progreso", progress_snapshot)


func _global_exportar_progreso() -> Dictionary:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload == null or not global_autoload.has_method("exportar_progreso"):
		return {}
	var exported_progress: Variant = global_autoload.call("exportar_progreso")
	if exported_progress is Dictionary:
		return (exported_progress as Dictionary).duplicate(true)
	return {}


func _global_obtener_numero_nivel_actual() -> int:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload == null:
		return 1
	if global_autoload.has_method("obtener_actual_nivel_numero"):
		return int(global_autoload.call("obtener_actual_nivel_numero"))
	return int(global_autoload.get("current_level"))


func _global_establecer_numero_nivel_actual(level_number: int, track_key: String = "") -> void:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload == null:
		return
	if global_autoload.has_method("establecer_actual_nivel_numero"):
		global_autoload.call("establecer_actual_nivel_numero", level_number, track_key)
		return
	global_autoload.set("current_level", level_number)


func _global_obtener_cantidad_niveles_pista(track_key: String) -> int:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("obtener_pista_nivel_cantidad"):
		return int(global_autoload.call("obtener_pista_nivel_cantidad", track_key))
	return GameTrackCatalog.obtener_pista_nivel_cantidad(
		track_key,
		GameTrackCatalog.DEFAULT_LEVEL_COUNT
	)


func _global_limpiar_estado_parcial_nivel(track_key: String, level_number: int) -> void:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("limpiar_parcial_nivel_estado"):
		global_autoload.call("limpiar_parcial_nivel_estado", track_key, level_number)


func _global_registrar_actividad_racha(
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("registrar_actividad_racha"):
		var streak_state: Variant = global_autoload.call(
			"registrar_actividad_racha",
			activity_type,
			metadata
		)
		if streak_state is Dictionary:
			return (streak_state as Dictionary).duplicate(true)
	return {}


func _global_reiniciar_progreso() -> void:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("reiniciar_progreso"):
		global_autoload.call("reiniciar_progreso")


func _global_establecer_racha(streak_state: Dictionary) -> void:
	if streak_state.is_empty():
		return
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("establecer_estado_racha"):
		global_autoload.call("establecer_estado_racha", streak_state)


func _obtener_racha_actual_para_preservar() -> Dictionary:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("obtener_estado_racha"):
		var global_streak: Variant = global_autoload.call("obtener_estado_racha")
		if global_streak is Dictionary and not (global_streak as Dictionary).is_empty():
			return (global_streak as Dictionary).duplicate(true)

	var progress_snapshot: Variant = save_data.get("progress", {})
	if progress_snapshot is Dictionary:
		var systems: Variant = (progress_snapshot as Dictionary).get("progress_system_states", {})
		if systems is Dictionary:
			var streak: Variant = (systems as Dictionary).get("streak", {})
			if streak is Dictionary:
				return (streak as Dictionary).duplicate(true)
	return {}


func _obtener_settings_guardado_actual() -> Dictionary:
	var settings: Variant = save_data.get("settings", {})
	if settings is Dictionary:
		return (settings as Dictionary).duplicate(true)
	return {}


func _meta_guardado_vacia() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0,
		"linked_online_username": "",
	}


func _establecer_cuenta_online_vinculada(username: String) -> void:
	var meta: Dictionary = _obtener_meta_guardado()
	meta["linked_online_username"] = username.strip_edges()
	save_data["save_meta"] = meta


func _reiniciar_progreso_juego_preservando_perfil() -> void:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	_reiniciar_datos_guardado_actual(profile)


func aplicar_racha_sincronizada(streak_online: Dictionary) -> void:
	if streak_online.is_empty():
		return
	var merged: Dictionary = ImportadorProgresoOnlineScript.fusionar_estado_racha(
		_obtener_racha_local_desde_save(),
		ImportadorProgresoOnlineScript.construir_estado_racha_online(streak_online)
	)
	if merged.is_empty():
		return
	_global_establecer_racha(merged)
	_persistir_racha_en_save(merged)
	if not _escribir_guardado_en_disco(false, "streak_sync"):
		push_warning("[Save] No se pudo persistir la racha sincronizada.")
		return
	progress_loaded.emit(obtener_perfil_usuario_actual())


func _obtener_racha_local_desde_save() -> Dictionary:
	var progress: Variant = save_data.get("progress", {})
	if not progress is Dictionary:
		return {}
	var systems: Variant = (progress as Dictionary).get("progress_system_states", {})
	if not systems is Dictionary:
		return {}
	var streak: Variant = (systems as Dictionary).get("streak", {})
	return (streak as Dictionary).duplicate(true) if streak is Dictionary else {}


func _persistir_racha_en_save(streak_state: Dictionary) -> void:
	if streak_state.is_empty():
		return
	var progress_snapshot: Dictionary = save_data.get("progress", {}) as Dictionary
	var systems: Dictionary = (
		progress_snapshot.get("progress_system_states", {}) as Dictionary
		if progress_snapshot.get("progress_system_states") is Dictionary
		else {}
	)
	systems["streak"] = streak_state.duplicate(true)
	progress_snapshot["progress_system_states"] = systems
	save_data["progress"] = progress_snapshot


func _importar_progreso_online(progreso_online: Dictionary) -> void:
	var snapshot: Dictionary = ImportadorProgresoOnlineScript.construir_snapshot_local(
		progreso_online
	)
	var local_node_progress: Dictionary = obtener_todo_progreso_nodos()
	var online_node_progress: Dictionary = snapshot.get("node_progress", {})
	save_data["node_progress"] = ImportadorProgresoOnlineScript.fusionar_node_progress(
		local_node_progress,
		online_node_progress if online_node_progress is Dictionary else {}
	)
	var local_exp: int = int(save_data.get("total_exp", 0))
	var online_exp: int = int(snapshot.get("total_exp", 0))
	save_data["total_exp"] = maxi(local_exp, online_exp)
	save_data["progress"] = snapshot.get("progress_snapshot", {})

	var streak_state: Dictionary = ImportadorProgresoOnlineScript.fusionar_estado_racha(
		_obtener_racha_local_desde_save(),
		snapshot.get("streak_state", {})
	)
	_global_establecer_racha(streak_state)
	_global_importar_progreso(save_data.get("progress", {}))

	var global_autoload: Node = _obtener_autoload_global()
	# Re-sincronizar Global con el merge final (local + online).
	for node_id in save_data.get("node_progress", {}).keys():
		var entry: Variant = save_data["node_progress"][node_id]
		if not entry is Dictionary or not bool((entry as Dictionary).get("completed", false)):
			continue
		var track_key := ImportadorProgresoOnlineScript.inferir_track_key_desde_node_id(
			str(node_id)
		)
		if track_key.is_empty() or global_autoload == null:
			continue
		if global_autoload.has_method("marcar_nodo_jugable_completado"):
			global_autoload.call("marcar_nodo_jugable_completado", track_key, str(node_id))

	save_data["progress"] = _global_exportar_progreso()
	if not streak_state.is_empty():
		var progress_snapshot: Dictionary = save_data.get("progress", {}) as Dictionary
		var systems: Dictionary = (
			progress_snapshot.get("progress_system_states", {}) as Dictionary
			if progress_snapshot.get("progress_system_states") is Dictionary
			else {}
		)
		systems["streak"] = streak_state.duplicate(true)
		systems["question_progress"] = _construir_question_progress_desde_node_progress(
			save_data.get("node_progress", {})
		)
		progress_snapshot["progress_system_states"] = systems
		save_data["progress"] = progress_snapshot


func _construir_question_progress_desde_node_progress(node_progress: Dictionary) -> Dictionary:
	var by_track: Dictionary = {}
	if not node_progress is Dictionary:
		return by_track
	for raw_node_id in node_progress.keys():
		var node_id := str(raw_node_id).strip_edges()
		if node_id.is_empty():
			continue
		var entry: Variant = node_progress[raw_node_id]
		if not entry is Dictionary or not bool((entry as Dictionary).get("completed", false)):
			continue
		var track_key := ImportadorProgresoOnlineScript.inferir_track_key_desde_node_id(node_id)
		if track_key.is_empty():
			continue
		if not by_track.has(track_key):
			by_track[track_key] = {}
		(by_track[track_key] as Dictionary)[node_id] = true
	return by_track


func _aplicar_parche_perfil_online(usuario: Dictionary) -> void:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	var parche: Dictionary = ImportadorProgresoOnlineScript.construir_parche_perfil(usuario)
	for key in parche.keys():
		profile[key] = parche[key]
	save_data["profile"] = profile


func _persistir_perfil_actualizado() -> Dictionary:
	if not _guardar_estado_actual(
		"profile_updated",
		"Perfil local actualizado",
		{"type": "profile_updated"},
		false
	):
		return {"ok": false, "message": "No se pudo escribir el perfil local en disco."}

	var updated_profile: Dictionary = obtener_perfil_usuario_actual()
	user_registered.emit(updated_profile)
	progress_loaded.emit(updated_profile)
	return {"ok": true, "message": "Perfil local actualizado.", "profile": updated_profile}


func _marcar_guardado_sucio() -> void:
	if has_unsaved_changes:
		return
	has_unsaved_changes = true
	_emitir_estado_guardado("dirty", _loaded_from, _recovered_from)


func _emitir_estado_guardado(
	state: String,
	loaded_from: String = "",
	recovered_from: String = "",
	last_error: String = ""
) -> void:
	_save_state = state
	if not loaded_from.is_empty():
		_loaded_from = loaded_from
	_recovered_from = recovered_from
	_last_error = last_error
	save_status_changed.emit(obtener_estado_guardado())


func _escribir_despues_reparacion_carga(
	loaded_from: String,
	recovered_from: String,
	reason: String
) -> void:
	_loaded_from = loaded_from
	_recovered_from = recovered_from
	var effective_reason: String = reason if not reason.is_empty() else "load_repair"
	if not _escribir_guardado_en_disco(true, effective_reason):
		if not recovered_from.is_empty() and FileAccess.file_exists(TEMP_SAVE_PATH):
			has_unsaved_changes = false
			_emitir_estado_guardado("recovered", loaded_from, recovered_from)
		else:
			_emitir_estado_guardado(
				"error",
				loaded_from,
				recovered_from,
				"No se pudo restaurar el save principal en disco."
			)
		return
	if recovered_from.is_empty():
		_emitir_estado_guardado("leery", _loaded_from)
	else:
		_emitir_estado_guardado("recovered", _loaded_from, recovered_from)
