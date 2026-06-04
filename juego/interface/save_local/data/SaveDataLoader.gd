extends RefCounted

const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveDataSchemaScript := preload(
	"res://interface/save_local/data/SaveDataSchema.gd"
)

const SAVE_PATH := "user://save_data.json"
const TEMP_SAVE_PATH := "user://save_data.tmp.json"
const BACKUP_SAVE_PATH := "user://save_data.backup.json"
const DEFAULT_PROFILE_NAME := SaveDataSchemaScript.DEFAULT_PROFILE_NAME
const SAVE_VERSION := SaveDataSchemaScript.SAVE_VERSION

var _profile_helper: RefCounted
var _schema: RefCounted
var loaded_from: String = "default"
var recovered_from: String = ""
var needs_write: bool = false
var rewrite_reason: String = ""


func _init() -> void:
	_profile_helper = SaveLocalProfileHelperScript.new()
	_schema = SaveDataSchemaScript.new()


func cargar_datos() -> Dictionary:
	_reiniciar_contexto_carga()

	var raw_save: Variant = _leer_primer_archivo_valido()
	if not raw_save is Dictionary:
		print_debug("[Save] creating_new_save reason=", "no_valid_save_file")
		needs_write = true
		return _schema.datos_guardado_predeterminados()

	var loaded_save: Dictionary = raw_save
	if loaded_from != "primary":
		recovered_from = loaded_from
		needs_write = true

	rewrite_reason = _reescribir_motivo(loaded_save)
	if not rewrite_reason.is_empty():
		needs_write = true

	return _normalizar_datos_cargados(loaded_save)


func reparar_estructura(save_snapshot: Dictionary) -> bool:
	var changed := false

	var stored_profile: Variant = save_snapshot.get("profile", {})
	if not stored_profile is Dictionary:
		stored_profile = {}
		changed = true

	var profile: Dictionary = _profile_helper.normalizar_datos_perfil(
		stored_profile,
		DEFAULT_PROFILE_NAME
	)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
		changed = true
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = Time.get_datetime_string_from_system(false, true)
		changed = true
	if str(profile.get("updated_at", "")).is_empty():
		profile["updated_at"] = str(profile.get("created_at", ""))
		changed = true
	save_snapshot["profile"] = profile

	if not save_snapshot.get("progress", {}) is Dictionary:
		save_snapshot["progress"] = {}
		changed = true

	if not save_snapshot.get("node_progress", {}) is Dictionary:
		save_snapshot["node_progress"] = {}
		changed = true

	if not save_snapshot.get("history", []) is Array:
		save_snapshot["history"] = []
		changed = true

	if not save_snapshot.get("played_activity_ids", []) is Array:
		save_snapshot["played_activity_ids"] = []
		changed = true

	if not save_snapshot.get("completed_activity_ids", []) is Array:
		save_snapshot["completed_activity_ids"] = []
		changed = true

	if not save_snapshot.get("completed_activity_ids_by_request", {}) is Dictionary:
		save_snapshot["completed_activity_ids_by_request"] = {}
		changed = true

	if not save_snapshot.get("save_meta", {}) is Dictionary:
		save_snapshot["save_meta"] = _meta_guardado_vacia()
		changed = true
	else:
		save_snapshot["save_meta"] = _schema.normalizar_meta_guardado(
			save_snapshot.get("save_meta", {})
		)

	if save_snapshot.get("total_exp", null) == null:
		save_snapshot["total_exp"] = 0
		changed = true

	return changed


func _reiniciar_contexto_carga() -> void:
	loaded_from = "default"
	recovered_from = ""
	needs_write = false
	rewrite_reason = ""


func _leer_primer_archivo_valido() -> Variant:
	var raw_save: Variant = _leer_archivo_json(SAVE_PATH)
	if raw_save is Dictionary:
		loaded_from = "primary"
		return raw_save

	raw_save = _leer_archivo_json(TEMP_SAVE_PATH)
	if raw_save is Dictionary:
		loaded_from = "temp"
		return raw_save

	raw_save = _leer_archivo_json(BACKUP_SAVE_PATH)
	if raw_save is Dictionary:
		loaded_from = "backup"
		return raw_save

	return null


func _leer_archivo_json(path: String) -> Variant:
	var actual_path: String = _resolve_save_path(path)
	print_debug("[Save] loading path=", ProjectSettings.globalize_path(actual_path))
	var exists: bool = FileAccess.file_exists(actual_path)
	print_debug("[Save] file_exists=", exists)
	if not exists:
		return null

	var file := FileAccess.open(actual_path, FileAccess.READ)
	if file == null:
		push_warning("[Save] parse failed path=%s error=%s" % [actual_path, "open_failed"])
		return null

	var text := file.get_as_text()
	file = null
	print_debug("[Save] raw_size=", text.length())
	if text.strip_edges().is_empty():
		push_warning("[Save] parse failed path=%s error=%s" % [actual_path, "empty_file"])
		return null

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning(
			"[Save] parse failed path=%s error=%s"
			% [actual_path, json.get_error_message()]
		)
		return null
	if json.data is Dictionary:
		var parsed: Dictionary = (json.data as Dictionary).duplicate(true)
		print_debug("[Save] parsed_ok=", true)
		print_debug("[Save] keys=", parsed.keys())
		return parsed
	print_debug("[Save] parsed_ok=", false)
	push_warning("[Save] parse failed path=%s error=%s" % [actual_path, "root_not_dictionary"])
	return null


static func _resolve_save_path(path: String) -> String:
	var override_dir: String = OS.get_environment("EVIDENTE_SAVE_DIR").strip_edges()
	if override_dir.is_empty():
		return path
	return override_dir.path_join(path.get_file())


func _normalizar_datos_cargados(raw: Dictionary) -> Dictionary:
	var migrated: Dictionary = raw
	if raw.has("users"):
		migrated = _migrar_legacy(raw)

	var source: Dictionary = _aplanar_sesiones_legacy(migrated)
	var normalizado: Dictionary = _schema.datos_guardado_predeterminados()
	normalizado["version"] = int(source.get("version", SAVE_VERSION))

	var source_profile: Variant = source.get("profile", {})
	if source_profile is Dictionary:
		normalizado["profile"] = _profile_helper.normalizar_datos_perfil(
			source_profile,
			DEFAULT_PROFILE_NAME
		)

	var source_progress: Variant = source.get("progress", {})
	if source_progress is Dictionary:
		normalizado["progress"] = (source_progress as Dictionary).duplicate(true)

	normalizado["save_meta"] = _schema.normalizar_meta_guardado(source.get("save_meta", {}))

	var source_resume_state: Variant = source.get("resume_state", {})
	if source_resume_state is Dictionary:
		normalizado["resume_state"] = (source_resume_state as Dictionary).duplicate(true)

	normalizado["history"] = _schema.normalizar_historial(source.get("history", []))
	var source_played: Variant = source.get("played_activity_ids", [])
	if source_played is Array:
		normalizado["played_activity_ids"] = (source_played as Array).duplicate(true)
	var source_completed_global: Variant = source.get("completed_activity_ids", [])
	if source_completed_global is Array:
		normalizado["completed_activity_ids"] = (source_completed_global as Array).duplicate(true)
	var source_completed: Variant = source.get("completed_activity_ids_by_request", {})
	if source_completed is Dictionary:
		normalizado["completed_activity_ids_by_request"] = (source_completed as Dictionary).duplicate(true)
	var normalizado_completed_ids: Variant = normalizado.get("completed_activity_ids", [])
	if normalizado_completed_ids is Array and (normalizado_completed_ids as Array).is_empty():
		normalizado["completed_activity_ids"] = _flatten_completed_activity_ids_by_request(
			normalizado.get("completed_activity_ids_by_request", {})
		)
	normalizado["total_exp"] = max(0, int(source.get("total_exp", 0)))
	var source_node_progress: Variant = source.get("node_progress", {})
	if source_node_progress is Dictionary:
		normalizado["node_progress"] = (source_node_progress as Dictionary).duplicate(true)
	return normalizado


func _reescribir_motivo(raw: Dictionary) -> String:
	if raw.has("users"):
		return "legacy_migration"
	if raw.has("sessions") or raw.has("active_session_id") or raw.has("next_session_number"):
		return "schema_simplification"
	return ""


func _migrar_legacy(raw: Dictionary) -> Dictionary:
	var normalizado: Dictionary = _schema.datos_guardado_predeterminados()
	var user: Dictionary = _resolver_usuario_legacy(raw)
	if user.is_empty():
		return normalizado

	normalizado["profile"] = _profile_helper.normalizar_datos_perfil({
		"username": user.get("username", DEFAULT_PROFILE_NAME),
		"age": user.get("age", 0),
		"email": user.get("email", ""),
		"avatar_path": user.get("avatar_path", ""),
		"created_at": user.get("created_at", ""),
		"updated_at": user.get("updated_at", "")
	}, DEFAULT_PROFILE_NAME)

	var legacy_progress: Variant = user.get("progress", {})
	if legacy_progress is Dictionary:
		normalizado["progress"] = (legacy_progress as Dictionary).duplicate(true)
	var legacy_node_progress: Variant = user.get("node_progress", {})
	if legacy_node_progress is Dictionary:
		normalizado["node_progress"] = (legacy_node_progress as Dictionary).duplicate(true)

	normalizado["save_meta"] = _schema.normalizar_meta_guardado({
		"last_saved_at": user.get("updated_at", ""),
		"last_saved_reason": "legacy_migration",
		"write_count": 0
	})
	normalizado["history"] = _schema.normalizar_historial(user.get("history", []))
	return normalizado


func _resolver_usuario_legacy(raw: Dictionary) -> Dictionary:
	var users: Variant = raw.get("users", {})
	if not users is Dictionary:
		return {}

	var last_key: String = str(raw.get("last_user", ""))
	if users.has(last_key) and users[last_key] is Dictionary:
		return users[last_key]
	if users.is_empty():
		return {}

	var first_key: Variant = users.keys()[0]
	return users[first_key] if users[first_key] is Dictionary else {}


func _aplanar_sesiones_legacy(raw: Dictionary) -> Dictionary:
	var sessions: Variant = raw.get("sessions", {})
	if not sessions is Dictionary:
		return raw

	var active_id: String = str(raw.get("active_session_id", "")).strip_edges()
	var selected: Dictionary = {}
	if sessions.has(active_id) and sessions[active_id] is Dictionary:
		selected = sessions[active_id]
	else:
		var newest_saved_at: String = ""
		for session_id in sessions.keys():
			var session_data: Variant = sessions[session_id]
			if not session_data is Dictionary:
				continue

			var raw_meta: Variant = session_data.get("save_meta", {})
			var last_saved_at: String = ""
			if raw_meta is Dictionary:
				last_saved_at = str(raw_meta.get("last_saved_at", ""))

			var updated_at: String = str(session_data.get("updated_at", last_saved_at))
			if updated_at.is_empty():
				updated_at = str(session_data.get("created_at", ""))

			if selected.is_empty() or updated_at > newest_saved_at:
				selected = session_data
				newest_saved_at = updated_at

	if selected.is_empty():
		return raw

	var flat: Dictionary = raw.duplicate(true)

	var selected_progress: Variant = selected.get("progress", {})
	if selected_progress is Dictionary:
		flat["progress"] = (selected_progress as Dictionary).duplicate(true)

	var selected_save_meta: Variant = selected.get("save_meta", {})
	if selected_save_meta is Dictionary:
		flat["save_meta"] = (selected_save_meta as Dictionary).duplicate(true)

	var selected_resume_state: Variant = selected.get("resume_state", {})
	if selected_resume_state is Dictionary:
		flat["resume_state"] = (selected_resume_state as Dictionary).duplicate(true)

	var selected_node_progress: Variant = selected.get("node_progress", {})
	if selected_node_progress is Dictionary:
		flat["node_progress"] = (selected_node_progress as Dictionary).duplicate(true)

	var selected_played_ids: Variant = selected.get("played_activity_ids", [])
	if selected_played_ids is Array:
		flat["played_activity_ids"] = (selected_played_ids as Array).duplicate(true)

	var selected_completed_ids: Variant = selected.get("completed_activity_ids", [])
	if selected_completed_ids is Array:
		flat["completed_activity_ids"] = (selected_completed_ids as Array).duplicate(true)

	var selected_completed_by_request: Variant = selected.get(
		"completed_activity_ids_by_request",
		{}
	)
	if selected_completed_by_request is Dictionary:
		flat["completed_activity_ids_by_request"] = (
			selected_completed_by_request as Dictionary
		).duplicate(true)

	flat["history"] = _schema.normalizar_historial(selected.get("history", []))
	return flat


func _flatten_completed_activity_ids_by_request(raw_value: Variant) -> Array:
	var result: Array = []
	if not raw_value is Dictionary:
		return result
	for raw_ids in (raw_value as Dictionary).values():
		if not raw_ids is Array:
			continue
		for raw_id in (raw_ids as Array):
			var activity_id: String = str(raw_id).strip_edges()
			if activity_id.is_empty() or result.has(activity_id):
				continue
			result.append(activity_id)
	return result


func _meta_guardado_vacia() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0
	}
