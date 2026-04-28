extends RefCounted


const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")

const DRAG_DROP_SCENE_PATH := "res://mapas/drag_drop/DragDropNode.tscn"
const DRAG_DROP_STUB_SCENE_PATH := "res://mapas/DragDropNodeStub.tscn"


static func obtener_escena_jugable(modo: String) -> Dictionary:
	match modo:
		NodeContentLoaderScript.MODE_QUIZ_CHOICE:
			return {
				"ok": true,
				"ruta_escena": GameSceneRouter.QUESTIONS_SCENE_PATH,
				"error": ""
			}
		NodeContentLoaderScript.MODE_DRAG_DROP:
			return _resolver_ruta_drag_drop()
		_:
			return {
				"ok": false,
				"ruta_escena": "",
				"error": "PlayableNodeRouter no soporta el modo: %s" % modo
			}


static func _resolver_ruta_drag_drop() -> Dictionary:
	# Fallback seguro para demo si la escena principal no existe.
	var ruta_escena: String = DRAG_DROP_SCENE_PATH
	if not ResourceLoader.exists(ruta_escena):
		if not ResourceLoader.exists(DRAG_DROP_STUB_SCENE_PATH):
			return {
				"ok": false,
				"ruta_escena": "",
				"error": "PlayableNodeRouter no encontro DragDropNode.tscn ni DragDropNodeStub.tscn."
			}
		ruta_escena = DRAG_DROP_STUB_SCENE_PATH

	return {
		"ok": true,
		"ruta_escena": ruta_escena,
		"error": ""
	}
