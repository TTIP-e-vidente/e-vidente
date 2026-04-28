extends RefCounted

const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"
const SCRIPT_PATH := "res://mapas/MapNodeData.gd"
const DICT_KEY_ID := "id"
const DICT_KEY_KIND := "kind"
const DICT_KEY_LABEL := "label"
const DICT_KEY_TRACK_KEY := "track_key"
const DICT_KEY_LEVEL_NUMBER := "level_number"
const DICT_KEY_QUESTION_NUMBER := "question_number"
const DICT_KEY_QUESTION_KEY := "question_key"
const DICT_KEY_QUESTION_JSON_PATH := "question_json_path"
const DICT_KEY_QUESTION_RESOURCE_PATH := "question_resource_path"
const DICT_KEY_ICON_TEXTURE_PATH := "icon_texture_path"
const DICT_KEY_POSITION := "pos"
const DEFAULT_NODE_JSON_DIR := "res://niveles/nodos"
const LEGACY_NODE_JSON_DIR := "res://preguntas/json_nodos"
const DEFAULT_QUESTION_RESOURCE_DIR := "res://preguntas/preguntas_recurso"

var node_id: int = 0
var node_kind: String = NODE_KIND_CHAPTER
var label_text: String = ""
var track_key: String = ""
var level_number: int = 0
var question_number: int = 0
var question_key: String = ""
var question_json_path: String = ""
var question_resource_path: String = ""
var icon_texture_path: String = ""
var node_position: Vector2 = Vector2.ZERO


static func create() -> RefCounted:
	return load(SCRIPT_PATH).new()


static func from_dictionary(node_definition: Dictionary) -> RefCounted:
	var node_data: RefCounted = create()
	node_data.node_id = int(node_definition.get(DICT_KEY_ID, 0))
	node_data.node_kind = normalize_node_kind(
		str(node_definition.get(DICT_KEY_KIND, NODE_KIND_CHAPTER))
	)
	node_data.label_text = str(node_definition.get(DICT_KEY_LABEL, "")).strip_edges()
	node_data.track_key = str(node_definition.get(DICT_KEY_TRACK_KEY, "")).strip_edges()
	node_data.level_number = int(node_definition.get(DICT_KEY_LEVEL_NUMBER, 0))
	node_data.question_number = int(node_definition.get(DICT_KEY_QUESTION_NUMBER, 0))
	node_data.question_key = str(node_definition.get(DICT_KEY_QUESTION_KEY, "")).strip_edges()
	node_data.question_json_path = str(
		node_definition.get(DICT_KEY_QUESTION_JSON_PATH, "")
	).strip_edges()
	node_data.question_resource_path = str(
		node_definition.get(DICT_KEY_QUESTION_RESOURCE_PATH, "")
	).strip_edges()
	node_data.icon_texture_path = str(node_definition.get(DICT_KEY_ICON_TEXTURE_PATH, "")).strip_edges()
	node_data.node_position = node_definition.get(DICT_KEY_POSITION, Vector2.ZERO)
	return node_data


static func from_map_node(map_node: Node2D) -> RefCounted:
	if map_node == null or not map_node.has_method("build_runtime_node_data"):
		return null
	var built_node_data: Variant = map_node.call("build_runtime_node_data")
	if built_node_data is RefCounted:
		return built_node_data as RefCounted
	return null


static func duplicate_from_map_node(map_node: Node2D) -> RefCounted:
	var node_data: RefCounted = from_map_node(map_node)
	if node_data == null:
		return null
	return node_data.duplicate_data()


static func from_selection_payload(selected_target: Variant) -> RefCounted:
	if selected_target is Object and selected_target.has_method("duplicate_data"):
		var duplicated_node_data: Variant = selected_target.call("duplicate_data")
		if duplicated_node_data is RefCounted:
			return duplicated_node_data as RefCounted
	if selected_target is Dictionary:
		return from_dictionary(selected_target as Dictionary)
	if selected_target is Object and selected_target.has_method("to_dictionary"):
		var raw_node_definition: Variant = selected_target.call("to_dictionary")
		if raw_node_definition is Dictionary:
			return from_dictionary(raw_node_definition as Dictionary)
	return null


static func normalize_node_kind(raw_kind: String) -> String:
	return (
		NODE_KIND_QUESTION
		if raw_kind.strip_edges().to_lower() == NODE_KIND_QUESTION
		else NODE_KIND_CHAPTER
	)


func duplicate_data() -> RefCounted:
	return from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		DICT_KEY_ID: node_id,
		DICT_KEY_KIND: node_kind,
		DICT_KEY_LABEL: label_text,
		DICT_KEY_TRACK_KEY: track_key,
		DICT_KEY_LEVEL_NUMBER: level_number,
		DICT_KEY_QUESTION_NUMBER: question_number,
		DICT_KEY_QUESTION_KEY: question_key,
		DICT_KEY_QUESTION_JSON_PATH: question_json_path,
		DICT_KEY_QUESTION_RESOURCE_PATH: question_resource_path,
		DICT_KEY_ICON_TEXTURE_PATH: icon_texture_path,
		DICT_KEY_POSITION: node_position,
	}


func is_question() -> bool:
	return node_kind == NODE_KIND_QUESTION


func is_chapter() -> bool:
	return node_kind == NODE_KIND_CHAPTER


func has_question_destination() -> bool:
	var resolved_json_path: String = get_resolved_question_json_path()
	if not resolved_json_path.is_empty() and FileAccess.file_exists(resolved_json_path):
		return true

	var resolved_resource_path: String = get_resolved_question_resource_path()
	return not resolved_resource_path.is_empty() and ResourceLoader.exists(resolved_resource_path)


func has_chapter_destination() -> bool:
	return level_number > 0


func has_runtime_destination() -> bool:
	if is_question():
		return has_question_destination()
	if is_chapter():
		return has_chapter_destination()
	return false


func get_question_session_level_id() -> int:
	return question_number if question_number > 0 else node_id


func get_track_key_or_default(default_track_key: String) -> String:
	return track_key if not track_key.is_empty() else default_track_key


func build_question_session(resolved_track_key: String, return_scene_path: String) -> Dictionary:
	return {
		"track_key": resolved_track_key,
		"nivel_id": get_question_session_level_id(),
		"question_key": get_resolved_question_key(),
		"question_json_path": get_resolved_question_json_path(),
		"question_resource_path": get_resolved_question_resource_path(),
		"return_scene_path": return_scene_path
	}


func get_resolved_question_key() -> String:
	var explicit_key: String = question_key.strip_edges()
	if not explicit_key.is_empty():
		return explicit_key

	var json_key: String = _extract_file_name_without_extension(question_json_path)
	if not json_key.is_empty():
		return json_key

	return _extract_file_name_without_extension(question_resource_path)


func get_resolved_question_json_path() -> String:
	var explicit_path: String = _resolver_ruta_json_legacy(question_json_path.strip_edges())
	if not explicit_path.is_empty():
		return explicit_path

	var resolved_key: String = get_resolved_question_key()
	if resolved_key.is_empty():
		return ""
	return "%s/%s.json" % [DEFAULT_NODE_JSON_DIR, resolved_key]


func get_resolved_question_resource_path() -> String:
	var explicit_path: String = question_resource_path.strip_edges()
	if not explicit_path.is_empty():
		return explicit_path

	var resolved_key: String = get_resolved_question_key()
	if resolved_key.is_empty():
		return ""
	return "%s/%s.tres" % [DEFAULT_QUESTION_RESOURCE_DIR, resolved_key]


func _extract_file_name_without_extension(raw_path: String) -> String:
	var clean_path: String = raw_path.strip_edges()
	if clean_path.is_empty():
		return ""

	var file_name: String = clean_path.get_file().strip_edges()
	var extension_index: int = file_name.rfind(".")
	if extension_index < 0:
		return file_name
	return file_name.substr(0, extension_index)


func _resolver_ruta_json_legacy(raw_path: String) -> String:
	var clean_path: String = raw_path.strip_edges()
	if clean_path.is_empty():
		return ""
	if FileAccess.file_exists(clean_path):
		return clean_path
	if not clean_path.begins_with(LEGACY_NODE_JSON_DIR):
		return clean_path

	var migrated_path: String = clean_path.replace(LEGACY_NODE_JSON_DIR, DEFAULT_NODE_JSON_DIR)
	if FileAccess.file_exists(migrated_path):
		push_warning(
			"MapNodeData: ruta legacy detectada. Usa %s en lugar de %s."
			% [migrated_path, clean_path]
		)
		return migrated_path
	return clean_path
