class_name BackendStoragePaths
extends RefCounted

const DEFAULT_NAMESPACE := "default"


static func resolver(path: String) -> String:
	if not path.begins_with("user://"):
		return path
	var override_dir: String = OS.get_environment("EVIDENTE_SAVE_DIR").strip_edges()
	if not override_dir.is_empty():
		return override_dir.path_join(path.get_file())
	var espacio_nombres := obtener_namespace()
	if espacio_nombres.is_empty() or espacio_nombres == DEFAULT_NAMESPACE:
		return path
	return "user://%s/%s" % [espacio_nombres, path.trim_prefix("user://")]


static func obtener_namespace() -> String:
	var raw := BackendConfig.obtener_storage_namespace()
	var clean := _sanitizar_namespace(raw)
	return clean if not clean.is_empty() else DEFAULT_NAMESPACE


static func asegurar_directorio_padre(path: String) -> void:
	var dir_path := path.get_base_dir()
	if dir_path.is_empty() or dir_path == "user://":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


static func _sanitizar_namespace(value: String) -> String:
	var lower := value.strip_edges().to_lower()
	var result := ""
	for index in range(lower.length()):
		var ch := lower.substr(index, 1)
		var code := ch.unicode_at(0)
		var is_number := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 122
		if is_number or is_lower:
			result += ch
		elif ch == "-" or ch == "_":
			result += ch
		elif not result.ends_with("-"):
			result += "-"
	return result.strip_edges().trim_prefix("-").trim_suffix("-")
