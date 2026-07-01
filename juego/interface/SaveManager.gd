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
const BackendStoragePathsScript := preload("res://API/backend/BackendStoragePaths.gd")
const GameStreakTrackerScript := preload("res://niveles/progress/GameStreakTracker.gd")

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
const NODE_PROGRESS_BACKUP_PREFIX := "node_progress_backup_"
const GUEST_SAVE_SNAPSHOT_PATH := "user://guest_save_snapshot.json"
const SAVE_SNAPSHOT_PREFIX := "save_snapshot_"
const PROGRESS_RESET_MARKER_PREFIX := "progress_reset_marker_"

var save_data: Dictionary = {}
var has_unsaved_changes: bool = false
var _save_state: String = "idle"
var _loaded_from: String = "default"
var _recovered_from: String = ""
var _last_error: String = ""

var _profile_helper: SaveLocalProfileHelperScript
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
	var racha_en_disco: Dictionary = _obtener_racha_local_desde_save()
	print("[Racha] cargar_datos: racha_leida_del_disco count=", racha_en_disco.get("current_count", "N/A"), " day=", racha_en_disco.get("last_activity_day", "N/A"))
	_global_importar_progreso(saved_progress if saved_progress is Dictionary else {})
	_sincronizar_node_progress_a_global(obtener_todo_progreso_nodos())
	progress_loaded.emit(obtener_perfil_usuario_actual())


func actualizar_perfil_local(
	username: String,
	birth_date: String,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	var validation: Dictionary = _profile_helper.validar_perfil(
		username,
		birth_date,
		email,
		avatar_source_path
	)
	if not bool(validation.get("ok", false)):
		return validation

	var profile: Dictionary = obtener_perfil_usuario_actual()
	var avatar_result: Dictionary = _actualizar_avatar_perfil(profile, avatar_source_path)
	if not bool(avatar_result.get("ok", false)):
		return avatar_result

	_aplicar_actualizaciones_identidad_perfil(profile, username, birth_date, email)
	save_data["profile"] = profile
	return _persistir_perfil_actualizado()


func cargar_textura_avatar(path: String) -> Texture2D:
	return _profile_helper.cargar_textura_avatar(path)


func obtener_textura_avatar_usuario_actual() -> Texture2D:
	var avatar_path: String = obtener_ruta_avatar_usuario_actual()
	if avatar_path.is_empty():
		return null
	return cargar_textura_avatar(avatar_path)


func aplicar_ruta_avatar_descargada(path: String) -> void:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return
	var profile: Dictionary = obtener_perfil_usuario_actual()
	if str(profile.get("avatar_path", "")) == clean_path:
		return
	profile["avatar_path"] = clean_path
	save_data["profile"] = profile
	_marcar_guardado_sucio()
	_guardar_estado_actual("avatar_online_sync", "", {}, false)
	progress_loaded.emit(obtener_perfil_usuario_actual())


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


func obtener_preferencia_notificaciones_mail_local() -> bool:
	return bool(obtener_perfil_usuario_actual().get("email_notifications_enabled", false))


func guardar_preferencia_notificaciones_mail_local(enabled: bool) -> void:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	profile["email_notifications_enabled"] = enabled
	save_data["profile"] = profile
	_marcar_guardado_sucio()
	_guardar_estado_actual("profile_notifications_pref", "", {}, false)


const SETTINGS_KEY_OMITIR_RANKING_POST_PARTIDA := "omitir_ranking_post_partida_invitado"


func omitir_ranking_post_partida_invitado() -> bool:
	if AuthApi.esta_logueado():
		return false
	return bool(_obtener_settings_guardado_actual().get(SETTINGS_KEY_OMITIR_RANKING_POST_PARTIDA, false))


func guardar_omitir_ranking_post_partida_invitado(omitir: bool) -> void:
	var settings: Dictionary = _obtener_settings_guardado_actual()
	settings[SETTINGS_KEY_OMITIR_RANKING_POST_PARTIDA] = omitir
	save_data["settings"] = settings
	_marcar_guardado_sucio()
	_guardar_estado_actual("settings_ranking_pref", "", {}, false)


func obtener_fecha_nacimiento_usuario_actual() -> String:
	return SaveLocalProfileHelperScript.normalizar_fecha_nacimiento(
		obtener_perfil_usuario_actual().get("birth_date", "")
	)


func obtener_edad_usuario_actual() -> int:
	return SaveLocalProfileHelperScript.calcular_edad_desde_fecha_nacimiento(
		obtener_fecha_nacimiento_usuario_actual()
	)


func obtener_ruta_avatar_usuario_actual() -> String:
	return str(obtener_perfil_usuario_actual().get("avatar_path", "")).strip_edges()


func obtener_clave_avatar_perfil() -> String:
	return _resolver_clave_avatar(obtener_perfil_usuario_actual())


func es_ruta_avatar_vinculada(path: String) -> bool:
	var user_key := obtener_clave_avatar_perfil()
	if user_key.is_empty():
		return false
	return _profile_helper.es_ruta_avatar_gestionada(path, _ruta_usuario(AVATARS_DIR), user_key)


func limpiar_avatar_perfil() -> void:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	if str(profile.get("avatar_path", "")).is_empty():
		return
	profile["avatar_path"] = ""
	save_data["profile"] = profile
	_marcar_guardado_sucio()


func vincular_avatar_local_existente_si_hay() -> bool:
	var user_key := obtener_clave_avatar_perfil()
	if user_key.is_empty():
		return false
	var existing_path: String = _profile_helper.buscar_avatar_gestionado_existente(
		_ruta_usuario(AVATARS_DIR), user_key
	)
	if existing_path.is_empty():
		return false
	aplicar_ruta_avatar_descargada(existing_path)
	return true


func migrar_avatar_gestionado_si_posible(source_path: String) -> bool:
	var clean_source := source_path.strip_edges()
	if clean_source.is_empty() or not FileAccess.file_exists(clean_source):
		return false
	var user_key := obtener_clave_avatar_perfil()
	if user_key.is_empty():
		return false
	var profile: Dictionary = obtener_perfil_usuario_actual()
	var migrated: Dictionary = _profile_helper.aplicar_cambio_avatar(
		profile,
		clean_source,
		str(profile.get("avatar_path", "")).strip_edges(),
		_ruta_usuario(AVATARS_DIR),
		user_key
	)
	if not bool(migrated.get("ok", false)):
		return false
	save_data["profile"] = profile
	_marcar_guardado_sucio()
	_guardar_estado_actual("avatar_migrated", "", {}, false)
	progress_loaded.emit(obtener_perfil_usuario_actual())
	return true


func guardar_avatar_bytes_vinculado(bytes: PackedByteArray, extension: String) -> String:
	if bytes.is_empty():
		return ""
	var user_key := obtener_clave_avatar_perfil()
	if user_key.is_empty():
		return ""
	var ext := extension.strip_edges().to_lower()
	if ext.is_empty():
		ext = "png"
	var path: String = _profile_helper.construir_ruta_avatar_gestionada(
		_ruta_usuario(AVATARS_DIR), user_key, ext
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_ruta_usuario(AVATARS_DIR)))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(bytes)
	file.flush()
	file = null
	aplicar_ruta_avatar_descargada(path)
	return path


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
	var racha_global: Dictionary = {}
	if _global_autoload != null and _global_autoload.has_method("obtener_estado_racha"):
		racha_global = _global_autoload.call("obtener_estado_racha")
	print("[Racha] guardar_progreso_en_disco: racha_global_count=", racha_global.get("current_count", "N/A"), " day=", racha_global.get("last_activity_day", "N/A"))
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
	progress_loaded.emit(obtener_perfil_usuario_actual())


func marcar_recompensa_del_mapa_como_vista(map_id: String) -> void:
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
	if not stored is Dictionary:
		return {}
	return ImportadorProgresoOnlineScript.sanitizar_progreso_secuencial(
		(stored as Dictionary).duplicate(true)
	)


func corregir_progreso_nodos_secuencial_en_disco() -> void:
	var stored: Variant = save_data.get("node_progress", {})
	if not stored is Dictionary:
		return
	var original: Dictionary = (stored as Dictionary).duplicate(true)
	var sanitized: Dictionary = ImportadorProgresoOnlineScript.sanitizar_progreso_secuencial(original)
	if sanitized == original:
		return
	save_data["node_progress"] = sanitized
	_sincronizar_node_progress_a_global(sanitized)
	_marcar_guardado_sucio()
	guardar_progreso_en_disco()


func obtener_cuenta_online_vinculada() -> String:
	return str(_obtener_meta_guardado().get("linked_online_username", "")).strip_edges()


func preparar_cuenta_online(usuario: Dictionary) -> void:
	var username := str(usuario.get("username", "")).strip_edges()
	if username.is_empty():
		return

	var linked := obtener_cuenta_online_vinculada()
	var profile_mismatch := _perfil_actual_parece_de_otra_cuenta(usuario)
	if linked == username and not profile_mismatch:
		if _debe_reiniciar_save_por_reset_pendiente(username):
			_preparar_login_con_reset_pendiente(username)
		return

	if linked.is_empty():
		if _perfil_es_invitado():
			_respaldar_snapshot_invitado()
		if _debe_reiniciar_save_por_reset_pendiente(username):
			_preparar_login_con_reset_pendiente(username)
			return
		if _restaurar_snapshot_online(username):
			_restaurar_pendientes_online_si_corresponde(username)
			_establecer_cuenta_online_vinculada(username)
			ArmadorDePartida.reiniciar_historial_sesion()
			_marcar_guardado_sucio()
			if not _escribir_guardado_en_disco(false, "account_restore"):
				push_warning("[Save] No se pudo persistir la restauración de cuenta online.")
				return
			progress_loaded.emit(obtener_perfil_usuario_actual())
			return
		_establecer_cuenta_online_vinculada(username)
		_marcar_guardado_sucio()
		_escribir_guardado_en_disco(false, "account_linked")
		return

	if not linked.is_empty() and linked != username:
		_respaldar_snapshot_online(linked)
		_respaldar_node_progress_por_usuario(linked)
		LocalSyncQueue.archivar_pendientes_de_usuario(linked)
	LocalSyncQueue.descartar_pendientes(
		"account_switch_%s_to_%s" % [linked if not linked.is_empty() else "unknown", username]
	)
	if _debe_reiniciar_save_por_reset_pendiente(username):
		_preparar_login_con_reset_pendiente(username)
		return
	if _restaurar_snapshot_online(username):
		_establecer_cuenta_online_vinculada(username)
	else:
		_reiniciar_progreso_juego_preservando_perfil()
		_limpiar_identidad_perfil_para_cambio_cuenta()
		limpiar_avatar_perfil()
		_establecer_cuenta_online_vinculada(username)
	_restaurar_pendientes_online_si_corresponde(username)
	ArmadorDePartida.reiniciar_historial_sesion()
	_marcar_guardado_sucio()
	if not _escribir_guardado_en_disco(false, "account_switch"):
		push_warning("[Save] No se pudo persistir el cambio de cuenta online.")
		return
	progress_loaded.emit(obtener_perfil_usuario_actual())


func necesita_reset_remoto_antes_de_sync(_progreso_online: Dictionary, username: String = "") -> bool:
	return debe_forzar_reset_remoto_antes_de_sync(username)


func debe_forzar_reset_remoto_antes_de_sync(username: String = "") -> bool:
	return _debe_reiniciar_save_por_reset_pendiente(username)


func sincronizar_con_cuenta_online(usuario: Dictionary, progreso_online: Dictionary) -> void:
	var username := str(usuario.get("username", "")).strip_edges()
	if username.is_empty():
		return

	var linked := obtener_cuenta_online_vinculada()
	if linked != username:
		preparar_cuenta_online(usuario)

	_importar_progreso_online(progreso_online, username)
	_aplicar_parche_perfil_online(usuario)
	_establecer_cuenta_online_vinculada(username)
	_marcar_guardado_sucio()

	if not _escribir_guardado_en_disco(false, "online_sync"):
		push_warning("[Save] No se pudo persistir la sync con la cuenta online.")
		return

	_confirmar_eliminacion_backup(username)
	var racha_post_sync: Dictionary = _obtener_racha_local_desde_save()
	print("[Racha] sincronizar_con_cuenta_online: racha_guardada_final count=", racha_post_sync.get("current_count", "N/A"))
	progress_loaded.emit(obtener_perfil_usuario_actual())


func al_cerrar_sesion_online() -> void:
	var racha_al_salir: Dictionary = _obtener_racha_local_desde_save()
	print("[Racha] al_cerrar_sesion_online: racha_local_antes_save=", racha_al_salir)
	guardar_progreso_en_disco()

	var linked := obtener_cuenta_online_vinculada()
	if linked.is_empty():
		ArmadorDePartida.reiniciar_historial_sesion()
		return

	var racha_online_antes_aislar: Dictionary = racha_al_salir.duplicate(true)
	if _tiene_reset_activo_para_cuenta(linked):
		_persistir_reset_pendiente_usuario(linked)
		LocalSyncQueue.descartar_backup_de_usuario(linked)
		LocalSyncQueue.descartar_pendientes("progress_reset_logout")
	else:
		LocalSyncQueue.archivar_pendientes_de_usuario(linked)
	_respaldar_snapshot_online(linked)
	_restaurar_snapshot_invitado()
	_limpiar_identidad_perfil_para_cambio_cuenta()
	limpiar_avatar_perfil()
	_aislar_racha_invitado_tras_salir_online(racha_online_antes_aislar)
	_limpiar_cuenta_online_vinculada()
	_respaldar_snapshot_invitado()
	ArmadorDePartida.reiniciar_historial_sesion()

	_marcar_guardado_sucio()
	if not _escribir_guardado_en_disco(false, "logout_guest_restore"):
		push_warning("[Save] No se pudo persistir el save invitado tras logout.")
		return

	var racha_guardada: Dictionary = _obtener_racha_local_desde_save()
	print("[Racha] al_cerrar_sesion_online: racha_guardada_en_disco=", racha_guardada)
	progress_loaded.emit(obtener_perfil_usuario_actual())


func activar_modo_invitado_para_juego() -> void:
	var racha_online_antes_aislar: Dictionary = _obtener_racha_local_desde_save()
	var linked := obtener_cuenta_online_vinculada()
	var requiere_aislamiento := (
		not linked.is_empty()
		or not _perfil_es_invitado()
		or _save_parece_arrastrar_cuenta_online(racha_online_antes_aislar)
	)

	if requiere_aislamiento:
		if not linked.is_empty():
			_respaldar_snapshot_online(linked)
			LocalSyncQueue.archivar_pendientes_de_usuario(linked)
		_restaurar_snapshot_invitado()
		_limpiar_identidad_perfil_para_cambio_cuenta()
		_limpiar_cuenta_online_vinculada()
		limpiar_avatar_perfil()
		ArmadorDePartida.reiniciar_historial_sesion()
		BackendSession.limpiar_cache_online()
		if not linked.is_empty():
			_respaldar_snapshot_invitado()
	else:
		ArmadorDePartida.reiniciar_historial_sesion()
		BackendSession.limpiar_cache_online()

	_aplicar_racha_modo_invitado(racha_online_antes_aislar)

	_marcar_guardado_sucio()
	if not _escribir_guardado_en_disco(false, "guest_mode_activate"):
		push_warning("[Save] No se pudo persistir el save invitado.")
		return
	progress_loaded.emit(obtener_perfil_usuario_actual())


func reiniciar_todo_progreso() -> Dictionary:
	var current_profile: Dictionary = obtener_perfil_usuario_actual()
	var linked_username := obtener_cuenta_online_vinculada()
	var remote_ok := true
	var remote_warning := ""
	if AuthApi.esta_logueado():
		var auth_username := str(AuthApi.obtener_usuario_online().get("username", "")).strip_edges()
		if linked_username.is_empty():
			linked_username = auth_username
		elif linked_username != auth_username and not auth_username.is_empty():
			linked_username = auth_username
		var remote_result: Dictionary = await SyncApi.reiniciar_progreso_online("CELIAQUIA")
		remote_ok = bool(remote_result.get("ok", false))
		if not remote_ok:
			remote_warning = AuthApi.mensaje_error(
				remote_result,
				"No se pudo reiniciar el progreso en el servidor."
			)
			push_warning("[Save] Reset remoto falló, se continúa con reset local: ", remote_warning)

	LocalSyncQueue.descartar_pendientes("progress_reset")
	if not linked_username.is_empty():
		_limpiar_backups_y_snapshots_de_reset(linked_username)
		LocalSyncQueue.descartar_backup_de_usuario(linked_username)
	BackendSession.limpiar_cache_progreso_online()

	_reiniciar_datos_guardado_actual(current_profile, true)
	var meta: Dictionary = _obtener_meta_guardado()
	meta["progress_reset_at"] = Time.get_datetime_string_from_system(false, true)
	if not linked_username.is_empty():
		meta["linked_online_username"] = linked_username
		_persistir_reset_pendiente_usuario(linked_username)
	save_data["save_meta"] = meta
	_sincronizar_node_progress_a_global({})

	if not linked_username.is_empty():
		_respaldar_snapshot_online(linked_username)

	if not _escribir_guardado_en_disco(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}
	progress_loaded.emit(current_profile)
	progress_saved.emit(current_profile)
	var message := "Se reinició el progreso del mapa. Tu racha diaria se mantiene."
	if not remote_warning.is_empty():
		message += " " + remote_warning
	return {
		"ok": true,
		"remote_ok": remote_ok,
		"message": message,
		"profile": current_profile,
	}


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
		_ruta_usuario(AVATARS_DIR),
		_resolver_clave_avatar(profile)
	)


func _resolver_clave_avatar(profile: Dictionary) -> String:
	var backend_session := get_node_or_null("/root/BackendSession") if is_inside_tree() else null
	if backend_session != null and backend_session.esta_logueado():
		var online_username := str(backend_session.obtener_usuario()).strip_edges()
		if not online_username.is_empty():
			return online_username
	var linked := obtener_cuenta_online_vinculada()
	if not linked.is_empty():
		return linked
	var username := str(profile.get("username", "")).strip_edges()
	if not username.is_empty() and username != DEFAULT_PROFILE_NAME:
		return username
	return LOCAL_PROFILE_KEY


func _aplicar_actualizaciones_identidad_perfil(
	profile: Dictionary,
	username: String,
	birth_date: String,
	email: String
) -> void:
	_profile_helper.aplicar_cambios_identidad(profile, username, birth_date, email, DEFAULT_PROFILE_NAME)
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
		print("[Save] _escribir_guardado_en_disco OMITIDO (sin cambios) reason=", reason)
		return true

	var progress: Variant = save_data.get("progress", {})
	print_debug("[Save] saving path=", ProjectSettings.globalize_path(_ruta_usuario(SAVE_PATH)))
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


func _reiniciar_datos_guardado_actual(profile: Dictionary, preserve_streak: bool = true) -> void:
	var settings: Dictionary = _obtener_settings_guardado_actual()
	var streak_a_preservar: Dictionary = {}
	if preserve_streak:
		streak_a_preservar = _obtener_racha_actual_para_preservar()
	if preserve_streak:
		_global_reiniciar_progreso_gameplay()
	else:
		_global_reiniciar_progreso()
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
	if preserve_streak and not streak_a_preservar.is_empty():
		_persistir_racha_en_save(streak_a_preservar)
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


func _global_reiniciar_progreso_gameplay() -> void:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("reiniciar_progreso_gameplay"):
		global_autoload.call("reiniciar_progreso_gameplay")
		return
	_global_reiniciar_progreso()


func _global_establecer_racha(streak_state: Dictionary) -> void:
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


func _limpiar_cuenta_online_vinculada() -> void:
	var meta: Dictionary = _obtener_meta_guardado()
	meta["linked_online_username"] = ""
	save_data["save_meta"] = meta


func _esta_en_modo_invitado_activo() -> bool:
	if not obtener_cuenta_online_vinculada().is_empty():
		return false
	return _perfil_es_invitado()


func _perfil_es_invitado() -> bool:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	var username := str(profile.get("username", "")).strip_edges()
	if not username.is_empty() and username != DEFAULT_PROFILE_NAME:
		return false
	return str(profile.get("email", "")).strip_edges().is_empty()


func _serializar_save_actual() -> Dictionary:
	return save_data.duplicate(true)


func _aplicar_snapshot_en_memoria(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	save_data = snapshot.duplicate(true)
	_reparar_datos_guardado_cargados()
	var saved_progress: Variant = save_data.get("progress", {})
	_global_importar_progreso(saved_progress if saved_progress is Dictionary else {})
	_sincronizar_node_progress_a_global(obtener_todo_progreso_nodos())
	_marcar_guardado_sucio()


func _ruta_usuario(path: String) -> String:
	return BackendStoragePathsScript.resolver(path)


func _escribir_snapshot(path: String, data: Dictionary) -> bool:
	if data.is_empty():
		return false
	BackendStoragePathsScript.asegurar_directorio_padre(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[Save] No se pudo escribir snapshot en ", path)
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file = null
	return true


func _leer_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file = null
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _ruta_snapshot_online(username: String) -> String:
	var safe_name: String = username.strip_edges().to_lower().replace("/", "_").replace("\\", "_")
	return _ruta_usuario("user://" + SAVE_SNAPSHOT_PREFIX + safe_name + ".json")


func _existe_snapshot_online(username: String) -> bool:
	return FileAccess.file_exists(_ruta_snapshot_online(username))


func _respaldar_snapshot_invitado() -> void:
	var snapshot := _serializar_save_actual()
	if snapshot.is_empty():
		return
	if not _escribir_snapshot(_ruta_usuario(GUEST_SAVE_SNAPSHOT_PATH), snapshot):
		push_warning("[Save] No se pudo respaldar snapshot invitado.")
		return
	print("[Save] snapshot invitado guardado nodos=", obtener_todo_progreso_nodos().keys())


func _respaldar_snapshot_online(username: String) -> void:
	if username.is_empty():
		return
	var snapshot := _serializar_save_actual()
	if _tiene_reset_activo_para_cuenta(username):
		snapshot = _serializar_snapshot_online_sin_gameplay(snapshot)
	if snapshot.is_empty():
		return
	var path := _ruta_snapshot_online(username)
	if not _escribir_snapshot(path, snapshot):
		push_warning("[Save] No se pudo respaldar snapshot online para ", username)
		return
	print("[Save] snapshot online guardado username=", username, " nodos=", obtener_todo_progreso_nodos().keys())


func _restaurar_snapshot_invitado() -> bool:
	var snapshot := _leer_snapshot(_ruta_usuario(GUEST_SAVE_SNAPSHOT_PATH))
	if not snapshot.is_empty():
		_aplicar_snapshot_en_memoria(snapshot)
		print("[Save] snapshot invitado restaurado nodos=", obtener_todo_progreso_nodos().keys())
		return true
	var guest_profile: Dictionary = obtener_perfil_usuario_actual().duplicate(true)
	guest_profile["username"] = DEFAULT_PROFILE_NAME
	guest_profile["birth_date"] = ""
	guest_profile["email"] = ""
	_reiniciar_datos_guardado_actual(guest_profile, false)
	print("[Save] sin snapshot invitado: save invitado vacío")
	return false


func _restaurar_snapshot_online(username: String) -> bool:
	if username.is_empty():
		return false
	if _debe_reiniciar_save_por_reset_pendiente(username):
		return false
	var path := _ruta_snapshot_online(username)
	var snapshot := _leer_snapshot(path)
	if snapshot.is_empty():
		return false
	_aplicar_snapshot_en_memoria(snapshot)
	print("[Save] snapshot online restaurado username=", username, " nodos=", obtener_todo_progreso_nodos().keys())
	return true


func _reiniciar_progreso_juego_preservando_perfil() -> void:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	_reiniciar_datos_guardado_actual(profile, false)


func _limpiar_identidad_perfil_para_cambio_cuenta() -> void:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	profile["birth_date"] = ""
	profile["email"] = ""
	profile["username"] = DEFAULT_PROFILE_NAME
	save_data["profile"] = profile


func _perfil_actual_parece_de_otra_cuenta(usuario: Dictionary) -> bool:
	var profile: Dictionary = obtener_perfil_usuario_actual()
	var local_email := str(profile.get("email", "")).strip_edges().to_lower()
	var online_email := str(usuario.get("mail", usuario.get("email", ""))).strip_edges().to_lower()
	if not local_email.is_empty() and not online_email.is_empty() and local_email != online_email:
		return true

	var local_name := str(profile.get("username", "")).strip_edges().to_lower()
	if local_name.is_empty() or local_name == str(DEFAULT_PROFILE_NAME).to_lower():
		return false
	var online_username := str(usuario.get("username", "")).strip_edges().to_lower()
	var online_name := str(usuario.get("name", "")).strip_edges().to_lower()
	return (
		not online_username.is_empty()
		and local_name != online_username
		and (online_name.is_empty() or local_name != online_name)
	)


func aplicar_racha_sincronizada(streak_online: Dictionary) -> void:
	if streak_online.is_empty():
		return
	var local_streak_now: Dictionary = _obtener_racha_local_para_merge()
	var server_streak_norm: Dictionary = ImportadorProgresoOnlineScript.construir_estado_racha_online(streak_online)
	print(
		"[Racha] aplicar_racha_sincronizada: local_count=", local_streak_now.get("current_count", "N/A"),
		" server_count=", server_streak_norm.get("current_count", "N/A")
	)
	var merged: Dictionary = ImportadorProgresoOnlineScript.fusionar_estado_racha(
		local_streak_now,
		server_streak_norm
	)
	if merged.is_empty():
		return
	# Día calendario LOCAL: la racha se registra y se compara en el huso del jugador.
	var today := Time.get_date_string_from_system(false)
	var local_day := str(local_streak_now.get("last_activity_day", ""))
	if local_day == today and str(merged.get("last_activity_day", "")) != today:
		merged["last_activity_day"] = today
		merged["current_count"] = maxi(
			int(merged.get("current_count", 0)),
			int(local_streak_now.get("current_count", 0))
		)
		merged = GameStreakTrackerScript.leer(merged)
	print(
		"[Racha] aplicar_racha_sincronizada: merged_count=", merged.get("current_count", "N/A"),
		" merged_day=", merged.get("last_activity_day", "N/A")
	)
	_global_establecer_racha(merged)
	_persistir_racha_en_save(merged)
	if not _escribir_guardado_en_disco(false, "streak_sync"):
		push_warning("[Save] No se pudo persistir la racha sincronizada.")
		return
	progress_loaded.emit(obtener_perfil_usuario_actual())


func evaluar_perdida_racha_pendiente() -> Dictionary:
	var streak_state: Dictionary = _obtener_racha_local_para_merge()
	if streak_state.is_empty():
		var global_autoload: Node = _obtener_autoload_global()
		if global_autoload != null and global_autoload.has_method("obtener_estado_racha"):
			var global_streak: Variant = global_autoload.call("obtener_estado_racha")
			if global_streak is Dictionary:
				streak_state = (global_streak as Dictionary).duplicate(true)

	if streak_state.is_empty():
		return {"should_show": false}

	var streak_meta: Dictionary = _obtener_meta_racha()
	var resultado: Dictionary = GameStreakTrackerScript.aplicar_vencimiento_si_corresponde(
		streak_state,
		streak_meta
	)
	if not bool(resultado.get("applied", false)):
		return {"should_show": false}

	var updated_state: Dictionary = resultado.get("updated_state", {}) as Dictionary
	_global_establecer_racha(updated_state)
	_persistir_racha_en_save(updated_state)

	if bool(resultado.get("should_show", false)):
		var notify_day: String = str(resultado.get("notify_day", "")).strip_edges()
		if not notify_day.is_empty():
			streak_meta["last_loss_notified_for_day"] = notify_day
			_persistir_meta_racha(streak_meta)
		_escribir_guardado_en_disco(false, "streak_loss")

	return resultado


func _obtener_meta_racha() -> Dictionary:
	var progress: Variant = save_data.get("progress", {})
	if not progress is Dictionary:
		return {}
	var systems: Variant = (progress as Dictionary).get("progress_system_states", {})
	if not systems is Dictionary:
		return {}
	var meta: Variant = (systems as Dictionary).get("streak_meta", {})
	return (meta as Dictionary).duplicate(true) if meta is Dictionary else {}


func _persistir_meta_racha(streak_meta: Dictionary) -> void:
	var progress_snapshot: Dictionary = save_data.get("progress", {}) as Dictionary
	var systems: Dictionary = (
		progress_snapshot.get("progress_system_states", {}) as Dictionary
		if progress_snapshot.get("progress_system_states") is Dictionary
		else {}
	)
	if streak_meta.is_empty():
		systems.erase("streak_meta")
	else:
		systems["streak_meta"] = streak_meta.duplicate(true)
	progress_snapshot["progress_system_states"] = systems
	save_data["progress"] = progress_snapshot


func _obtener_racha_local_desde_save() -> Dictionary:
	var progress: Variant = save_data.get("progress", {})
	if not progress is Dictionary:
		return {}
	var systems: Variant = (progress as Dictionary).get("progress_system_states", {})
	if not systems is Dictionary:
		return {}
	var streak: Variant = (systems as Dictionary).get("streak", {})
	return (streak as Dictionary).duplicate(true) if streak is Dictionary else {}


func _obtener_racha_local_para_merge() -> Dictionary:
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload != null and global_autoload.has_method("obtener_estado_racha"):
		var global_streak: Variant = global_autoload.call("obtener_estado_racha")
		if global_streak is Dictionary and not (global_streak as Dictionary).is_empty():
			return (global_streak as Dictionary).duplicate(true)
	return _obtener_racha_local_desde_save()


func _persistir_racha_en_save(streak_state: Dictionary) -> void:
	var progress_snapshot: Dictionary = save_data.get("progress", {}) as Dictionary
	var systems: Dictionary = (
		progress_snapshot.get("progress_system_states", {}) as Dictionary
		if progress_snapshot.get("progress_system_states") is Dictionary
		else {}
	)
	if streak_state.is_empty():
		systems.erase("streak")
	else:
		systems["streak"] = streak_state.duplicate(true)
	progress_snapshot["progress_system_states"] = systems
	save_data["progress"] = progress_snapshot


func _aislar_racha_invitado_tras_salir_online(racha_online: Dictionary) -> void:
	_aplicar_racha_modo_invitado(racha_online)


func _aplicar_racha_modo_invitado(racha_online_referencia: Dictionary = {}) -> void:
	if not _invitado_tiene_progreso_propio():
		_limpiar_racha_invitado()
		return
	var racha_invitado: Dictionary = _obtener_racha_desde_snapshot_invitado()
	if racha_invitado.is_empty():
		racha_invitado = _obtener_racha_local_desde_save()
	var online_count := int(racha_online_referencia.get("current_count", 0))
	var guest_count := int(racha_invitado.get("current_count", 0))
	if online_count > 0 and guest_count == online_count:
		_limpiar_racha_invitado()
		return
	_global_establecer_racha(racha_invitado)
	_persistir_racha_en_save(racha_invitado)


func _save_parece_arrastrar_cuenta_online(racha_actual: Dictionary) -> bool:
	if not _perfil_es_invitado():
		return true
	if int(racha_actual.get("current_count", 0)) <= 0:
		return false
	return not _invitado_tiene_progreso_propio()


func _obtener_racha_desde_snapshot_invitado() -> Dictionary:
	return _extraer_racha_de_save_snapshot(_leer_snapshot(_ruta_usuario(GUEST_SAVE_SNAPSHOT_PATH)))


func _extraer_racha_de_save_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	var progress: Variant = snapshot.get("progress", {})
	if not progress is Dictionary:
		return {}
	var systems: Variant = (progress as Dictionary).get("progress_system_states", {})
	if not systems is Dictionary:
		return {}
	var streak: Variant = (systems as Dictionary).get("streak", {})
	return (streak as Dictionary).duplicate(true) if streak is Dictionary else {}


func _save_tiene_progreso_propio(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var node_progress: Variant = snapshot.get("node_progress", {})
	if node_progress is Dictionary and not (node_progress as Dictionary).is_empty():
		return true
	if int(snapshot.get("total_exp", 0)) > 0:
		return true
	var summary: Dictionary = _resumir_progreso(snapshot.get("progress", {}))
	return int(summary.get("total", 0)) > 0


func _invitado_tiene_progreso_propio() -> bool:
	return _save_tiene_progreso_propio(save_data)


func _limpiar_racha_invitado() -> void:
	_global_establecer_racha({})
	_persistir_racha_en_save({})


func _sincronizar_global_racha_desde_save() -> void:
	_global_establecer_racha(_obtener_racha_local_desde_save())


func _importar_progreso_online(progreso_online: Dictionary, username: String = "") -> void:
	var snapshot: Dictionary = ImportadorProgresoOnlineScript.construir_snapshot_local(
		progreso_online
	)
	var local_node_progress: Dictionary = obtener_todo_progreso_nodos()
	if not username.is_empty() and not _tiene_reset_activo_para_cuenta(username):
		var backup: Dictionary = _restaurar_node_progress_backup(username)
		if not backup.is_empty():
			print("[Save] backup restaurado para username=", username, " nodos=", backup.keys())
			local_node_progress = ImportadorProgresoOnlineScript.fusionar_node_progress(
				backup, local_node_progress
			)
	if _tiene_reset_activo_para_cuenta(username):
		local_node_progress = {}
		save_data["node_progress"] = {}
		save_data["total_exp"] = 0
	var online_node_progress: Dictionary = (
		snapshot.get("node_progress", {}) as Dictionary
		if snapshot.get("node_progress") is Dictionary
		else {}
	)
	if _tiene_reset_activo_para_cuenta(username):
		online_node_progress = {}
		snapshot["node_progress"] = {}
		snapshot["total_exp"] = 0
		snapshot["progress_snapshot"] = {}
		snapshot["streak_state"] = {}
	elif _debe_rechazar_progreso_gameplay_online_stale(
		online_node_progress,
		int(snapshot.get("total_exp", 0))
	):
		online_node_progress = {}
		snapshot["node_progress"] = {}
		snapshot["total_exp"] = 0
		snapshot["progress_snapshot"] = _global_exportar_progreso()
	save_data["node_progress"] = ImportadorProgresoOnlineScript.fusionar_node_progress(
		local_node_progress,
		online_node_progress
	)
	var local_exp: int = int(save_data.get("total_exp", 0))
	var online_exp: int = int(snapshot.get("total_exp", 0))
	save_data["total_exp"] = (
		local_exp
		if _tiene_reset_activo_para_cuenta(username)
		else maxi(local_exp, online_exp)
	)
	# Leer antes de sobreescribir progress con el snapshot del servidor.
	# El runtime puede tener una actividad local de hoy que todavia no llego al disco.
	var local_streak: Dictionary = _obtener_racha_local_para_merge()
	var server_streak: Dictionary = (
		{} if _tiene_reset_activo_para_cuenta(username)
		else snapshot.get("streak_state", {})
	)
	print(
		"[Racha] _importar_progreso_online: username=", username,
		" local_count=", local_streak.get("current_count", "N/A"),
		" local_day=", local_streak.get("last_activity_day", "N/A"),
		" server_count=", server_streak.get("current_count", "N/A"),
		" server_day=", server_streak.get("last_activity_day", "N/A")
	)
	if _tiene_reset_activo_para_cuenta(username):
		save_data["progress"] = _global_exportar_progreso()
	else:
		save_data["progress"] = snapshot.get("progress_snapshot", {})

	var streak_state: Dictionary
	if _tiene_reset_activo_para_cuenta(username):
		streak_state = local_streak.duplicate(true)
	else:
		streak_state = ImportadorProgresoOnlineScript.fusionar_estado_racha(
			local_streak,
			server_streak
		)
	print("[Racha] _importar_progreso_online: streak_merged_count=", streak_state.get("current_count", "vacío"))
	_global_importar_progreso(save_data.get("progress", {}))
	_global_establecer_racha(streak_state)
	_sincronizar_node_progress_a_global(save_data.get("node_progress", {}))

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


func fusionar_completados_desde_sync(completed_nodes: Array) -> void:
	if completed_nodes.is_empty():
		return
	var snapshot: Dictionary = ImportadorProgresoOnlineScript.construir_snapshot_local(
		{"completedNodes": completed_nodes}
	)
	var online_np: Dictionary = snapshot.get("node_progress", {})
	if online_np.is_empty():
		return
	if _debe_bloquear_merge_post_reset(online_np):
		push_warning(
			"[Save] Ignorando merge post-reset: servidor trae %d nodos y local tiene %d"
			% [online_np.size(), _contar_nodos_completados_locales()]
		)
		return
	var merged: Dictionary = ImportadorProgresoOnlineScript.fusionar_node_progress(
		obtener_todo_progreso_nodos(), online_np
	)
	save_data["node_progress"] = merged
	_sincronizar_node_progress_a_global(merged)
	_marcar_guardado_sucio()
	guardar_progreso_en_disco()
	progress_loaded.emit(obtener_perfil_usuario_actual())


func _contar_nodos_completados_locales() -> int:
	var count := 0
	for entry in obtener_todo_progreso_nodos().values():
		if entry is Dictionary and bool((entry as Dictionary).get("completed", false)):
			count += 1
	return count


func _debe_bloquear_merge_post_reset(online_np: Dictionary) -> bool:
	if not _tiene_reset_activo_para_cuenta(""):
		return false
	if _contar_nodos_completados_locales() == 0:
		return _contar_nodos_completados_en(online_np) > 0
	return _contar_nodos_completados_en(online_np) > _contar_nodos_completados_locales() + 1


func marcar_reset_remoto_pendiente() -> void:
	push_warning("[Save] Reset local activo pero el servidor aún trae progreso previo.")


func confirmar_reset_remoto_completado(
	progreso_online: Dictionary,
	username: String = "",
	remote_reset_confirmado: bool = false
) -> void:
	if not remote_reset_confirmado or not _tiene_reset_activo_para_cuenta(username):
		return
	if not progreso_online.is_empty():
		var snapshot: Dictionary = ImportadorProgresoOnlineScript.construir_snapshot_local(
			progreso_online
		)
		var online_np: Dictionary = (
			snapshot.get("node_progress", {}) as Dictionary
			if snapshot.get("node_progress") is Dictionary
			else {}
		)
		if _contar_nodos_completados_en(online_np) > 0:
			return
		if int(snapshot.get("total_exp", 0)) > 0:
			return
	if _contar_nodos_completados_locales() > 0 or int(save_data.get("total_exp", 0)) > 0:
		return
	_limpiar_flags_reset_usuario(username)


func limpiar_flag_reset_si_servidor_vacio(progreso_online: Dictionary, username: String = "") -> void:
	confirmar_reset_remoto_completado(progreso_online, username, false)


func _tiene_reset_local_activo() -> bool:
	return _tiene_reset_activo_para_cuenta("")


func _tiene_reset_activo_para_cuenta(username: String = "") -> bool:
	var reset_at := str(_obtener_meta_guardado().get("progress_reset_at", "")).strip_edges()
	if not reset_at.is_empty():
		return true
	var user := username.strip_edges()
	if user.is_empty():
		user = obtener_cuenta_online_vinculada()
	if user.is_empty():
		return false
	return _tiene_reset_pendiente_usuario(user)


func _ruta_reset_pendiente_usuario(username: String) -> String:
	var safe_name: String = username.strip_edges().to_lower().replace("/", "_").replace("\\", "_")
	return _ruta_usuario("user://" + PROGRESS_RESET_MARKER_PREFIX + safe_name + ".json")


func _persistir_reset_pendiente_usuario(username: String) -> void:
	if username.is_empty():
		return
	var reset_at := str(_obtener_meta_guardado().get("progress_reset_at", "")).strip_edges()
	if reset_at.is_empty():
		reset_at = Time.get_datetime_string_from_system(false, true)
	var payload := {"username": username, "progress_reset_at": reset_at}
	_escribir_snapshot(_ruta_reset_pendiente_usuario(username), payload)


func _leer_reset_pendiente_usuario(username: String) -> String:
	if username.is_empty():
		return ""
	var marker: Dictionary = _leer_snapshot(_ruta_reset_pendiente_usuario(username))
	return str(marker.get("progress_reset_at", "")).strip_edges()


func _tiene_reset_pendiente_usuario(username: String) -> bool:
	return not _leer_reset_pendiente_usuario(username).is_empty()


func _limpiar_reset_pendiente_usuario(username: String) -> void:
	if username.is_empty():
		return
	var path := _ruta_reset_pendiente_usuario(username)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _limpiar_flags_reset_usuario(username: String) -> void:
	var meta: Dictionary = _obtener_meta_guardado()
	meta.erase("progress_reset_at")
	save_data["save_meta"] = meta
	var user := username.strip_edges()
	if user.is_empty():
		user = obtener_cuenta_online_vinculada()
	_limpiar_reset_pendiente_usuario(user)
	_marcar_guardado_sucio()


func _serializar_snapshot_online_sin_gameplay(snapshot: Dictionary) -> Dictionary:
	var cleaned: Dictionary = snapshot.duplicate(true)
	var streak: Dictionary = _extraer_racha_de_save_snapshot(snapshot)
	cleaned["node_progress"] = {}
	cleaned["total_exp"] = 0
	cleaned["progress"] = {}
	if not streak.is_empty():
		cleaned["progress"] = {
			"progress_system_states": {
				"streak": streak.duplicate(true),
			},
		}
	cleaned["history"] = []
	cleaned["completed_activity_ids_by_request"] = {}
	cleaned["map_reward_seen"] = {}
	cleaned["resume_state"] = _resume_helper.obtener_estado_predeterminado(ARCHIVERO_SCENE)
	return cleaned


func _eliminar_snapshot_online(username: String) -> void:
	if username.is_empty():
		return
	var snapshot_path: String = _ruta_snapshot_online(username)
	if FileAccess.file_exists(snapshot_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(snapshot_path))


func _preparar_login_con_reset_pendiente(username: String) -> void:
	_eliminar_snapshot_online(username)
	LocalSyncQueue.descartar_backup_de_usuario(username)
	LocalSyncQueue.descartar_pendientes("progress_reset_login")
	var reset_at := _leer_reset_pendiente_usuario(username)
	if reset_at.is_empty():
		var snapshot_reset: Dictionary = _leer_snapshot(_ruta_snapshot_online(username))
		var snapshot_meta: Variant = snapshot_reset.get("save_meta", {})
		if snapshot_meta is Dictionary:
			reset_at = str((snapshot_meta as Dictionary).get("progress_reset_at", "")).strip_edges()
	if reset_at.is_empty():
		reset_at = Time.get_datetime_string_from_system(false, true)
	var profile: Dictionary = obtener_perfil_usuario_actual()
	_reiniciar_datos_guardado_actual(profile, true)
	var meta: Dictionary = _obtener_meta_guardado()
	meta["progress_reset_at"] = reset_at
	meta["linked_online_username"] = username
	save_data["save_meta"] = meta
	_persistir_reset_pendiente_usuario(username)
	_establecer_cuenta_online_vinculada(username)
	_sincronizar_node_progress_a_global({})
	ArmadorDePartida.reiniciar_historial_sesion()
	_marcar_guardado_sucio()
	if not _escribir_guardado_en_disco(false, "account_restore_reset_pending"):
		push_warning("[Save] No se pudo persistir login con reset pendiente.")
		return
	progress_loaded.emit(obtener_perfil_usuario_actual())


func _debe_reiniciar_save_por_reset_pendiente(username: String = "") -> bool:
	if _tiene_reset_activo_para_cuenta(username):
		return true
	return _snapshot_online_indica_reset_pendiente(username)


func _snapshot_online_indica_reset_pendiente(username: String) -> bool:
	if username.is_empty():
		return false
	var snapshot := _leer_snapshot(_ruta_snapshot_online(username))
	if snapshot.is_empty():
		return false
	var meta: Variant = snapshot.get("save_meta", {})
	if not meta is Dictionary:
		return false
	return not str((meta as Dictionary).get("progress_reset_at", "")).strip_edges().is_empty()


func _debe_rechazar_progreso_gameplay_online_stale(online_np: Dictionary, online_exp: int) -> bool:
	if not _tiene_reset_activo_para_cuenta(""):
		return false
	var local_completed := _contar_nodos_completados_locales()
	var local_exp := int(save_data.get("total_exp", 0))
	var online_completed := _contar_nodos_completados_en(online_np)
	if local_completed == 0 and local_exp == 0:
		return online_completed > 0 or online_exp > 0
	if online_completed > local_completed:
		return true
	return online_exp > local_exp and local_completed == 0 and local_exp == 0


func _contar_nodos_completados_en(node_progress: Dictionary) -> int:
	var count := 0
	for entry in node_progress.values():
		if entry is Dictionary and bool((entry as Dictionary).get("completed", false)):
			count += 1
	return count


func _restaurar_pendientes_online_si_corresponde(username: String) -> void:
	if _debe_reiniciar_save_por_reset_pendiente(username):
		LocalSyncQueue.descartar_backup_de_usuario(username)
		LocalSyncQueue.descartar_pendientes("progress_reset_restore")
		return
	LocalSyncQueue.restaurar_pendientes_de_usuario(username)


func _limpiar_backups_y_snapshots_de_reset(username: String) -> void:
	if username.is_empty():
		return
	_confirmar_eliminacion_backup(username)
	_eliminar_snapshot_online(username)


func _sincronizar_node_progress_a_global(node_progress: Variant) -> void:
	if not node_progress is Dictionary:
		return
	var global_autoload: Node = _obtener_autoload_global()
	if global_autoload == null:
		return
	if (node_progress as Dictionary).is_empty():
		for track_key in GameTrackCatalog.TRACK_ORDER:
			if global_autoload.has_method("reiniciar_progreso_nodos_pista"):
				global_autoload.call("reiniciar_progreso_nodos_pista", track_key)
		return
	for raw_node_id in (node_progress as Dictionary).keys():
		var node_id := str(raw_node_id).strip_edges()
		if node_id.is_empty():
			continue
		var entry: Variant = node_progress[raw_node_id]
		if not entry is Dictionary or not bool((entry as Dictionary).get("completed", false)):
			continue
		var track_key := ImportadorProgresoOnlineScript.inferir_track_key_desde_node_id(node_id)
		if track_key.is_empty():
			continue
		if global_autoload.has_method("marcar_nodo_jugable_completado"):
			global_autoload.call("marcar_nodo_jugable_completado", track_key, node_id)


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


func _respaldar_node_progress_por_usuario(username: String) -> void:
	if username.is_empty():
		return
	var np: Dictionary = obtener_todo_progreso_nodos()
	if np.is_empty():
		return
	var safe_name: String = username.strip_edges().to_lower().replace("/", "_").replace("\\", "_")
	var path: String = _ruta_usuario("user://" + NODE_PROGRESS_BACKUP_PREFIX + safe_name + ".json")
	BackendStoragePathsScript.asegurar_directorio_padre(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[Save] No se pudo guardar backup de nodos para ", username)
		return
	file.store_string(JSON.stringify(np))
	file.flush()
	file = null
	print("[Save] backup node_progress guardado para username=", username, " nodos=", np.keys())


func _restaurar_node_progress_backup(username: String) -> Dictionary:
	if username.is_empty():
		return {}
	var safe_name: String = username.strip_edges().to_lower().replace("/", "_").replace("\\", "_")
	var path: String = _ruta_usuario("user://" + NODE_PROGRESS_BACKUP_PREFIX + safe_name + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file = null
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _confirmar_eliminacion_backup(username: String) -> void:
	if username.is_empty():
		return
	var safe_name: String = username.strip_edges().to_lower().replace("/", "_").replace("\\", "_")
	var path: String = _ruta_usuario("user://" + NODE_PROGRESS_BACKUP_PREFIX + safe_name + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
		if not recovered_from.is_empty() and FileAccess.file_exists(_ruta_usuario(TEMP_SAVE_PATH)):
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
