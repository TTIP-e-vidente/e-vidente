extends RefCounted
class_name MapNodeData

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"
const MODE_VINCULACION_CONCEPTOS := "vinculacion_conceptos"

var node_key: String = ""
var title: String = ""
var mode: String = ""
var json_path: String = ""
var track_key: String = ""
var index: int = 0
var difficulty: int = 0


static func from_json(raw_node: Dictionary, map_track_key: String, node_index: int) -> MapNodeData:
	var node := MapNodeData.new()
	node.node_key = str(raw_node.get("node_key", "")).strip_edges()
	node.title = str(raw_node.get("title", "")).strip_edges()
	node.mode = str(raw_node.get("mode", "")).strip_edges()
	node.json_path = str(raw_node.get("json_path", "")).strip_edges()
	node.track_key = map_track_key.strip_edges()
	node.index = node_index
	node.difficulty = int(raw_node.get("difficulty", 0))
	return node


func is_valid() -> bool:
	return not node_key.is_empty() and has_content_path()


func has_content_path() -> bool:
	return not json_path.is_empty()
