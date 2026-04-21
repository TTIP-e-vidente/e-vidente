extends RefCounted

const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"
const SCRIPT_PATH := "res://mapas/MapNodeData.gd"

var node_id: int = 0
var node_kind: String = NODE_KIND_CHAPTER
var label_text: String = ""
var track_key: String = ""
var level_number: int = 0
var question_number: int = 0
var question_key: String = ""
var question_resource_path: String = ""
var scene_path: String = ""
var icon_texture_path: String = ""
var node_position: Vector2 = Vector2.ZERO


static func from_dictionary(node_definition: Dictionary) -> RefCounted:
	var node_data: RefCounted = load(SCRIPT_PATH).new()
	node_data.node_id = int(node_definition.get("id", 0))
	node_data.node_kind = normalize_node_kind(str(node_definition.get("kind", NODE_KIND_CHAPTER)))
	node_data.label_text = str(node_definition.get("label", "")).strip_edges()
	node_data.track_key = str(node_definition.get("track_key", "")).strip_edges()
	node_data.level_number = int(node_definition.get("level_number", 0))
	node_data.question_number = int(node_definition.get("question_number", 0))
	node_data.question_key = str(node_definition.get("question_key", "")).strip_edges()
	node_data.question_resource_path = str(node_definition.get("question_resource_path", "")).strip_edges()
	node_data.scene_path = str(node_definition.get("scene_path", node_definition.get("scene", ""))).strip_edges()
	node_data.icon_texture_path = str(node_definition.get("icon_texture_path", "")).strip_edges()
	node_data.node_position = node_definition.get("pos", Vector2.ZERO)
	return node_data


static func normalize_node_kind(raw_kind: String) -> String:
	return (
		NODE_KIND_QUESTION
		if raw_kind.strip_edges().to_lower() == NODE_KIND_QUESTION
		else NODE_KIND_CHAPTER
	)


func duplicate_data() -> RefCounted:
	var duplicated_data: RefCounted = get_script().new()
	duplicated_data.node_id = node_id
	duplicated_data.node_kind = node_kind
	duplicated_data.label_text = label_text
	duplicated_data.track_key = track_key
	duplicated_data.level_number = level_number
	duplicated_data.question_number = question_number
	duplicated_data.question_key = question_key
	duplicated_data.question_resource_path = question_resource_path
	duplicated_data.scene_path = scene_path
	duplicated_data.icon_texture_path = icon_texture_path
	duplicated_data.node_position = node_position
	return duplicated_data


func to_dictionary() -> Dictionary:
	return {
		"id": node_id,
		"kind": node_kind,
		"label": label_text,
		"track_key": track_key,
		"level_number": level_number,
		"question_number": question_number,
		"question_key": question_key,
		"question_resource_path": question_resource_path,
		"scene_path": scene_path,
		"icon_texture_path": icon_texture_path,
		"pos": node_position,
	}


func is_question() -> bool:
	return node_kind == NODE_KIND_QUESTION


func is_chapter() -> bool:
	return node_kind == NODE_KIND_CHAPTER


func has_question_destination() -> bool:
	return not question_resource_path.is_empty()


func has_chapter_destination() -> bool:
	return level_number > 0


func get_question_session_level_id() -> int:
	return question_number if question_number > 0 else node_id


func get_declared_track_key(default_track_key: String) -> String:
	return track_key if not track_key.is_empty() else default_track_key