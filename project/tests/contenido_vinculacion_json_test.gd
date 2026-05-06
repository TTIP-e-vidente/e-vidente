extends SceneTree

const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var resultado_nodo: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(
		"res://contenido/nodos/celiaquia/vinculacion/vincular_alimentos_seguridad.json"
	)
	_assert(bool(resultado_nodo.get("ok", false)), "No se pudo cargar el JSON de vinculación.")
	if fallo:
		quit(1)
		return

	var resultado_runtime: Dictionary = NodeContentLoaderScript.convertir_vinculacion_a_runtime(
		resultado_nodo.get("data", {})
	)
	_assert(
		bool(resultado_runtime.get("ok", false)),
		"No se pudo convertir la vinculación a runtime."
	)
	if fallo:
		quit(1)
		return

	var datos: Dictionary = resultado_runtime.get("data", {})
	var conceptos_izquierda: Array = datos.get("conceptos_izquierda", [])
	var conceptos_derecha: Array = datos.get("conceptos_derecha", [])
	_assert(conceptos_izquierda.size() >= 2, "Se esperaban al menos dos conceptos a la izquierda.")
	_assert(conceptos_derecha.size() >= 2, "Se esperaban al menos dos conceptos a la derecha.")
	_assert(
		conceptos_izquierda.size() == conceptos_derecha.size(),
		"La cantidad de conceptos debería coincidir en ambos lados."
	)

	quit(1 if fallo else 0)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("VINCULACION TEST FAILED: %s" % mensaje)
