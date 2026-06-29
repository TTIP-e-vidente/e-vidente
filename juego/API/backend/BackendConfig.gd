class_name BackendConfig
extends RefCounted

## URL del backend API. Prioridad:
## 1) res://config/backend.local.json (generado desde BACKEND/.env, gitignored)
## 2) res://config/backend.json (default del equipo)
## 3) fallback hardcodeado

const LOCAL_CONFIG_PATH := "res://config/backend.local.json"
const DEFAULT_CONFIG_PATH := "res://config/backend.json"
const FALLBACK_BASE_URL := "http://localhost:3010"

static var _base_url: String = ""
static var _loaded: bool = false
static var _db_kind: String = ""
static var _email_enabled: bool = false
static var _email_via_supabase: bool = false
static var _supabase_functions_url: String = ""
static var _supabase_anon_key: String = ""


static func recargar() -> void:
	_loaded = false
	_base_url = ""
	_db_kind = ""
	_email_enabled = false
	_email_via_supabase = false
	_supabase_functions_url = ""
	_supabase_anon_key = ""
	_cargar()


static func es_supabase() -> bool:
	if not _loaded:
		_cargar()
	return _db_kind == "supabase"


static func email_via_supabase() -> bool:
	if not _loaded:
		_cargar()
	return _email_via_supabase


static func obtener_base_url() -> String:
	if not _loaded:
		_cargar()
	return _base_url


static func obtener_supabase_functions_url() -> String:
	if not _loaded:
		_cargar()
	return _supabase_functions_url


static func obtener_supabase_anon_key() -> String:
	if not _loaded:
		_cargar()
	return _supabase_anon_key


static func obtener_db_kind() -> String:
	if not _loaded:
		_cargar()
	return _db_kind


static func email_habilitado_en_backend() -> bool:
	if not _loaded:
		_cargar()
	return _email_enabled


static func _cargar() -> void:
	_loaded = true
	for config_path in [LOCAL_CONFIG_PATH, DEFAULT_CONFIG_PATH]:
		if _aplicar_config_desde_archivo(config_path):
			return
	_base_url = FALLBACK_BASE_URL
	_db_kind = "unknown"
	_email_enabled = false
	_email_via_supabase = false


static func _aplicar_config_desde_archivo(config_path: String) -> bool:
	var parsed := _leer_config_dict(config_path)
	if parsed.is_empty():
		return false
	var raw_url := str(parsed.get("base_url", "")).strip_edges()
	if raw_url.is_empty():
		return false
	_base_url = raw_url.trim_suffix("/")
	_db_kind = str(parsed.get("db", "")).strip_edges()
	_email_enabled = bool(parsed.get("email_enabled", false))
	_email_via_supabase = bool(parsed.get("email_via_supabase", false))
	_supabase_functions_url = str(parsed.get("supabase_functions_url", "")).strip_edges().trim_suffix("/")
	_supabase_anon_key = str(parsed.get("supabase_anon_key", "")).strip_edges()
	# Staging Supabase: verify por Edge aunque falte anon (fallará con mensaje claro).
	if not _email_via_supabase and _db_kind == "supabase" and not _supabase_functions_url.is_empty():
		_email_via_supabase = true
	elif not _email_via_supabase and not _supabase_functions_url.is_empty() and not _supabase_anon_key.is_empty():
		_email_via_supabase = true
	if OS.is_debug_build():
		var db_label := _db_kind if not _db_kind.is_empty() else "?"
		var mail_label := "brevo" if _email_enabled else "mail-off"
		var verify_label := " · verify→supabase" if _email_via_supabase else ""
		print("[BackendConfig] %s · %s · %s%s" % [_base_url, db_label, mail_label, verify_label])
	return true


static func _leer_config_dict(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return {}
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("BackendConfig: no se pudo abrir %s" % config_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BackendConfig: JSON inválido en %s" % config_path)
		return {}
	return parsed as Dictionary


static func _leer_base_url_desde_archivo(config_path: String) -> String:
	var parsed := _leer_config_dict(config_path)
	var raw_url := str(parsed.get("base_url", "")).strip_edges()
	if raw_url.is_empty():
		return ""
	return raw_url.trim_suffix("/")
