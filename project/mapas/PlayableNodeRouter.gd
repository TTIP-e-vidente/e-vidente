extends RefCounted


const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")

const DRAG_DROP_SCENE_PATH := "res://mapas/drag_drop/DragDropNode.tscn"
const DRAG_DROP_STUB_SCENE_PATH := "res://mapas/DragDropNodeStub.tscn"


static func obtener_escena_jugable(modo: String) -> Dictionary:
	var modo_limpio: String = modo.strip_edges()
	match modo_limpio:
		NodeContentLoaderScript.MODE_QUIZ_CHOICE:
			return _resultado_ok(GameSceneRouter.QUESTIONS_SCENE_PATH)
		NodeContentLoaderScript.MODE_DRAG_DROP:
			return _obtener_escena_drag_drop()
		_:
			return _resultado_error("PlayableNodeRouter no soporta el modo: %s" % modo_limpio)


static func _obtener_escena_drag_drop() -> Dictionary:
	# Fallback seguro para demo si la escena principal no existe.
	var ruta_escena: String = DRAG_DROP_SCENE_PATH
	if not ResourceLoader.exists(ruta_escena):
		if not ResourceLoader.exists(DRAG_DROP_STUB_SCENE_PATH):
			return _resultado_error(
				"PlayableNodeRouter no encontro DragDropNode.tscn ni DragDropNodeStub.tscn."
			)
		ruta_escena = DRAG_DROP_STUB_SCENE_PATH

	return _resultado_ok(ruta_escena)


static func _resultado_ok(ruta_escena: String) -> Dictionary:
	return {
		"ok": true,
		"ruta_escena": ruta_escena,
		"error": ""
	}


static func _resultado_error(mensaje: String) -> Dictionary:
	return {
		"ok": false,
		"ruta_escena": "",
		"error": mensaje
	}
