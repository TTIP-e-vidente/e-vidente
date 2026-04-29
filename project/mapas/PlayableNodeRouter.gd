extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")

const DRAG_DROP_SCENE_PATH := "res://mapas/drag_drop/DragDropNode.tscn"
const DRAG_DROP_STUB_SCENE_PATH := "res://mapas/DragDropNodeStub.tscn"

static func obtener_escena_jugable(modo: String) -> String:
	var modo_limpio: String = modo.strip_edges()
	match modo_limpio:
		NodeContentLoaderScript.MODE_QUIZ_CHOICE:
			return GameSceneRouter.QUESTIONS_SCENE_PATH
		NodeContentLoaderScript.MODE_DRAG_DROP:
			return _obtener_escena_drag_drop()
		_:
			return ""

static func _obtener_escena_drag_drop() -> String:
	if ResourceLoader.exists(DRAG_DROP_SCENE_PATH):
		return DRAG_DROP_SCENE_PATH
	if ResourceLoader.exists(DRAG_DROP_STUB_SCENE_PATH):
		return DRAG_DROP_STUB_SCENE_PATH
	return ""
