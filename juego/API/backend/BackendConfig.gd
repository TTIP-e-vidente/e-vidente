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


static func obtener_base_url() -> String:
	if not _loaded:
		_cargar()
	return _base_url


static func _cargar() -> void:
	_loaded = true
	for config_path in [LOCAL_CONFIG_PATH, DEFAULT_CONFIG_PATH]:
		var url := _leer_base_url_desde_archivo(config_path)
		if not url.is_empty():
			_base_url = url
			return
	_base_url = FALLBACK_BASE_URL


static func _leer_base_url_desde_archivo(config_path: String) -> String:
	if not FileAccess.file_exists(config_path):
		return ""
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("BackendConfig: no se pudo abrir %s" % config_path)
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BackendConfig: JSON inválido en %s" % config_path)
		return ""
	var raw_url := str((parsed as Dictionary).get("base_url", "")).strip_edges()
	if raw_url.is_empty():
		return ""
	return raw_url.trim_suffix("/")
