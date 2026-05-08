extends SceneTree

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var loader_script: Script = load("res://preguntas/QuestionJsonLoader.gd") as Script
	_assert(loader_script != null, "No se pudo cargar QuestionJsonLoader.gd")

	quit(1 if fallo else 0)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("PREGUNTA SCENE LOAD TEST FAILED: %s" % mensaje)