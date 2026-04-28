extends RefCounted


const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")

const DRAG_DROP_SCENE_PATH := "res://mapas/DragDropNode.tscn"
const DRAG_DROP_STUB_SCENE_PATH := "res://mapas/DragDropNodeStub.tscn"


static func resolve_route(node_data: Dictionary) -> Dictionary:
	return get_scene_for_mode(node_data)


static func get_scene_for_mode(node_data: Dictionary) -> Dictionary:
	var mode: String = str(node_data.get("mode", "")).strip_edges()
	match mode:
		NodeContentLoaderScript.MODE_QUIZ_CHOICE:
			return {
				"ok": true,
				"scene_path": GameSceneRouter.QUESTIONS_SCENE_PATH,
				"used_fallback": false,
				"error": ""
			}
		NodeContentLoaderScript.MODE_DRAG_DROP:
			return _resolve_drag_drop_route()
		_:
			return {
				"ok": false,
				"scene_path": "",
				"used_fallback": false,
				"error": "PlayableNodeRouter no soporta el modo: %s" % mode
			}


static func _resolve_drag_drop_route() -> Dictionary:
	# Fallback seguro para demo si la escena principal no existe.
	var scene_path: String = DRAG_DROP_SCENE_PATH
	var used_fallback: bool = false
	if not ResourceLoader.exists(scene_path):
		if not ResourceLoader.exists(DRAG_DROP_STUB_SCENE_PATH):
			return {
				"ok": false,
				"scene_path": "",
				"used_fallback": false,
				"error": "PlayableNodeRouter no encontro DragDropNode.tscn ni DragDropNodeStub.tscn."
			}
		scene_path = DRAG_DROP_STUB_SCENE_PATH
		used_fallback = true

	return {
		"ok": true,
		"scene_path": scene_path,
		"used_fallback": used_fallback,
		"error": ""
	}
