class_name BackendConfig
extends RefCounted

## URL del backend API. Prioridad:
## 1) res://config/backend.local.json (generado desde BACKEND/.env, gitignored)
## 2) res://config/backend.json (default del equipo)
## 3) fallback hardcodeado

const LOCAL_CONFIG_PATH := "res://config/backend.local.json"
const DEFAULT_CONFIG_PATH := "res://config/backend.json"
const FALLBACK_BASE_URL := "http://localhost:3010"
const API_MODE_LOCAL := "local"
const API_MODE_CLOUD := "cloud"
const API_MODE_SUPABASE_EDGE := "supabase_edge"

static var _base_url: String = ""
static var _loaded: bool = false
static var _db_kind: String = ""
static var _email_enabled: bool = false
static var _email_via_supabase: bool = false
static var _supabase_functions_url: String = ""
static var _supabase_anon_key: String = ""
static var _api_mode: String = API_MODE_LOCAL


static func recargar() -> void:
	_loaded = false
	_base_url = ""
	_db_kind = ""
	_email_enabled = false
	_email_via_supabase = false
	_supabase_functions_url = ""
	_supabase_anon_key = ""
	_api_mode = API_MODE_LOCAL
	_cargar()


static func es_supabase() -> bool:
	if not _loaded:
		_cargar()
	return _db_kind == "supabase"


static func es_modo_supabase_edge() -> bool:
	if not _loaded:
		_cargar()
	return _api_mode == API_MODE_SUPABASE_EDGE


static func email_via_supabase() -> bool:
	if not _loaded:
		_cargar()
	return _email_via_supabase


static func obtener_base_url() -> String:
	if not _loaded:
		_cargar()
	return _base_url


static func obtener_api_base_url() -> String:
	if not _loaded:
		_cargar()
	if es_modo_supabase_edge() and not _supabase_functions_url.is_empty():
		return _supabase_functions_url
	return _base_url


static func obtener_api_mode() -> String:
	if not _loaded:
		_cargar()
	return _api_mode


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


static func edge_listo_para_usar() -> bool:
	if not _loaded:
		_cargar()
	if not es_modo_supabase_edge():
		return false
	var url := obtener_api_base_url()
	if url.is_empty() or _url_es_local(url):
		return false
	return not _supabase_anon_key.is_empty()


static func mensaje_sync_requerido() -> String:
	return "En BACKEND ejecutá: npm run sync:godot-config:staging"


static func mensaje_sin_conexion_edge() -> String:
	return (
		"No hay conexión con Supabase Edge.\n"
		+ "1) cd BACKEND\n"
		+ "2) npm run integrate:status\n"
		+ "3) Verificá internet y volvé a Godot (F5)"
	)


static func _url_es_local(url: String) -> bool:
	return url.contains("localhost") or url.contains("127.0.0.1")


static func _cargar() -> void:
	_loaded = true
	if _aplicar_config_desde_archivo(LOCAL_CONFIG_PATH):
		return
	var default_parsed := _leer_config_dict(DEFAULT_CONFIG_PATH)
	if _aplicar_config_desde_archivo(DEFAULT_CONFIG_PATH):
		return
	_api_mode = str(default_parsed.get("api_mode", API_MODE_LOCAL)).strip_edges()
	if _api_mode == API_MODE_SUPABASE_EDGE:
		_db_kind = str(default_parsed.get("db", "supabase")).strip_edges()
		_email_via_supabase = true
		_base_url = ""
		push_warning(
			"BackendConfig: falta backend.local.json con URLs — %s"
			% mensaje_sync_requerido()
		)
		return
	_base_url = FALLBACK_BASE_URL
	_db_kind = "unknown"
	_email_enabled = false
	_email_via_supabase = false
	_api_mode = API_MODE_LOCAL


static func _aplicar_config_desde_archivo(config_path: String) -> bool:
	var parsed := _leer_config_dict(config_path)
	if parsed.is_empty():
		return false

	_api_mode = str(parsed.get("api_mode", API_MODE_LOCAL)).strip_edges()
	if _api_mode.is_empty():
		_api_mode = API_MODE_LOCAL

	_supabase_functions_url = str(parsed.get("supabase_functions_url", "")).strip_edges().trim_suffix("/")
	_supabase_anon_key = str(parsed.get("supabase_anon_key", "")).strip_edges()
	_db_kind = str(parsed.get("db", "")).strip_edges()
	_email_enabled = bool(parsed.get("email_enabled", false))
	_email_via_supabase = bool(parsed.get("email_via_supabase", false))

	var raw_url := str(parsed.get("base_url", "")).strip_edges().trim_suffix("/")
	if raw_url.is_empty() and es_modo_supabase_edge() and not _supabase_functions_url.is_empty():
		_base_url = _supabase_functions_url
	elif raw_url.is_empty():
		return false
	else:
		_base_url = raw_url

	if es_modo_supabase_edge() and _supabase_functions_url.is_empty() and not _base_url.is_empty():
		_supabase_functions_url = _base_url

	# Staging Supabase: verify por Edge aunque falte anon (fallará con mensaje claro).
	if not _email_via_supabase and _db_kind == "supabase" and not _supabase_functions_url.is_empty():
		_email_via_supabase = true
	elif not _email_via_supabase and not _supabase_functions_url.is_empty() and not _supabase_anon_key.is_empty():
		_email_via_supabase = true

	if es_modo_supabase_edge():
		_email_via_supabase = true

	if OS.is_debug_build():
		var db_label := _db_kind if not _db_kind.is_empty() else "?"
		var mail_label := "brevo" if _email_enabled else "mail-off"
		var mode_label := _api_mode if not _api_mode.is_empty() else API_MODE_LOCAL
		var verify_label := " · verify→supabase" if _email_via_supabase else ""
		print(
			"[BackendConfig] %s · %s · %s · api=%s%s"
			% [_base_url, db_label, mail_label, mode_label, verify_label]
		)
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
