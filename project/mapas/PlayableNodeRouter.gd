extends RefCounted

# Responsabilidad:
# - Leer `mode` y devolver la escena jugable.
# - Aplicar el fallback simple de `drag_drop`.
# No hace:
# - No carga JSON.
# - No adapta contenido.
# - No ejecuta gameplay.

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")

const DRAG_DROP_SCENE_PATH := "res://mapas/drag_drop/DragDropNode.tscn"
const DRAG_DROP_STUB_SCENE_PATH := "res://mapas/DragDropNodeStub.tscn"

const RUTAS_POR_MODO := {
	NodeContentLoaderScript.MODE_QUIZ_CHOICE: GameSceneRouter.QUESTIONS_SCENE_PATH,
	NodeContentLoaderScript.MODE_DRAG_DROP: DRAG_DROP_SCENE_PATH
}


static func obtener_escena_jugable(mode: String) -> Dictionary:
	var scene_path: String = str(RUTAS_POR_MODO.get(mode, "")).strip_edges()
	if scene_path.is_empty():
		return {
			"ok": false,
			"scene_path": "",
			"used_fallback": false,
			"error": "PlayableNodeRouter no soporta el modo: %s" % mode
		}

	if mode == NodeContentLoaderScript.MODE_DRAG_DROP:
		return _resolver_ruta_drag_drop()

	return {
		"ok": true,
		"scene_path": scene_path,
		"used_fallback": false,
		"error": ""
	}


static func _resolver_ruta_drag_drop() -> Dictionary:
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
