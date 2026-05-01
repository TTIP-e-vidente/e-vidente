extends SceneTree

const NodeContentLoader := preload("res://sistemas/contenido/NodeContentLoader.gd")

var _fallo: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_probar_quiz_valido()
	_probar_drag_drop_valido()
	_probar_mode_no_soportado()
	_probar_contenido_faltante()
	_probar_json_legacy()
	_probar_ruta_vieja()
	_probar_ruta_de_proyecto()
	await process_frame
	quit(1 if _fallo else 0)


func _probar_quiz_valido() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"res://niveles/nodos/celiaquia/gluten_maiz.json"
	)
	_assert(bool(resultado.get("ok", false)), "Quiz valido deberia cargar correctamente")
	if _fallo:
		return

	var datos_nodo: Dictionary = resultado.get("data", {})
	var contenido: Dictionary = datos_nodo.get("content", {})
	_assert(
		str(datos_nodo.get("mode", "")) == NodeContentLoader.MODE_QUIZ_CHOICE,
		"Quiz valido deberia normalizar mode quiz_choice"
	)
	_assert(str(datos_nodo.get("id", "")) == "gluten_maiz", "Quiz valido deberia conservar id")
	_assert(
		str(contenido.get("question", "")) == "El gluten esta en el maiz?",
		"Quiz valido deberia conservar content.question"
	)


func _probar_drag_drop_valido() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"res://niveles/nodos/celiaquia/armar_plato_sin_tacc.json"
	)
	_assert(bool(resultado.get("ok", false)), "DragDrop valido deberia cargar correctamente")
	if _fallo:
		return

	var datos_nodo: Dictionary = resultado.get("data", {})
	var contenido: Dictionary = datos_nodo.get("content", {})
	var targets: Array = contenido.get("targets", [])
	var items: Array = contenido.get("items", [])
	_assert(
		str(datos_nodo.get("mode", "")) == NodeContentLoader.MODE_DRAG_DROP,
		"DragDrop valido deberia conservar mode drag_drop"
	)
	_assert(targets.size() == 1, "DragDrop valido deberia tener un target")
	_assert(items.size() == 2, "DragDrop valido deberia tener dos items")


func _probar_mode_no_soportado() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"res://tests/fixtures/nodos/modo_no_soportado.json"
	)
	_assert(not bool(resultado.get("ok", false)), "Mode no soportado deberia fallar")
	_assert(
		str(resultado.get("error", "")).contains("Modo no soportado"),
		"Mode no soportado deberia informar error claro"
	)


func _probar_contenido_faltante() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"res://tests/fixtures/nodos/contenido_faltante.json"
	)
	_assert(not bool(resultado.get("ok", false)), "Contenido faltante deberia fallar")
	_assert(
		str(resultado.get("error", "")).contains("wrong_options"),
		"Contenido faltante deberia explicar el campo invalido"
	)


func _probar_json_legacy() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"res://niveles/nodos/ejemplos/ejemplo_select_option_legacy.json"
	)
	_assert(bool(resultado.get("ok", false)), "JSON legacy select_option deberia normalizarse")
	if _fallo:
		return

	var datos_nodo: Dictionary = resultado.get("data", {})
	var contenido: Dictionary = datos_nodo.get("content", {})
	_assert(
		str(datos_nodo.get("mode", "")) == NodeContentLoader.MODE_QUIZ_CHOICE,
		"JSON legacy deberia mapear select_option a quiz_choice"
	)
	_assert(
		str(contenido.get("correct_answer", "")) == "Arroz blanco",
		"JSON legacy deberia conservar la opcion correcta"
	)


func _probar_ruta_vieja() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"res://preguntas/json_nodos/eliminar_gluten.json"
	)
	_assert(bool(resultado.get("ok", false)), "Ruta vieja de preguntas/json_nodos deberia migrar")
	if _fallo:
		return

	var datos_nodo: Dictionary = resultado.get("data", {})
	_assert(
		str(datos_nodo.get("id", "")) == "eliminar_gluten",
		"Ruta vieja deberia resolver el nodo correcto"
	)


func _probar_ruta_de_proyecto() -> void:
	var resultado: Dictionary = NodeContentLoader.cargar_contenido_nodo(
		"project/niveles/nodos/celiaquia/gluten_maiz.json"
	)
	_assert(
		bool(resultado.get("ok", false)),
		"Ruta project/niveles/nodos deberia resolverse a res://"
	)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	_fallo = true
	printerr("NODE CONTENT LOADER TEST FAILED: %s" % mensaje)
