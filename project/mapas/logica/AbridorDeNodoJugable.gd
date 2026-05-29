extends RefCounted
class_name AbridorDeNodoJugable


const NodoRuntimeScript := preload("res://sistemas/NodoRuntime.gd")


static func abrir_nodo(
	tree: SceneTree,
	node_data: MapNodeData,
	ruta_retorno: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	var resultado: Dictionary = NodoRuntimeScript.iniciar(tree, node_data, ruta_retorno)
	if not bool(resultado.get("ok", false)):
		return _resultado_con_error(str(resultado.get("error", "No se pudo abrir el nodo.")))
	return _resultado_ok()


static func _resultado_ok() -> Dictionary:
	return {"ok": true, "error": "", "data": {}}


static func _resultado_con_error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
