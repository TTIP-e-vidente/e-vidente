extends SceneTree

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var global: Node = get_root().get_node_or_null("/root/Global")
	var escena: Node = null
	_assert(global != null, "El autoload Global debe estar disponible.")
	if fallo:
		_finalizar_test(global, escena)
		return

	_preparar_contexto_minimo(global)

	var recurso_escena: Resource = load("res://vincular/VincularConceptos.tscn")
	var escena_empaquetada: PackedScene = recurso_escena as PackedScene
	_assert(
		escena_empaquetada != null,
		"La escena VincularConceptos.tscn deberia existir y cargar como PackedScene."
	)
	if fallo:
		_finalizar_test(global, escena)
		return

	escena = escena_empaquetada.instantiate()
	_assert(escena != null, "La escena VincularConceptos.tscn deberia instanciar sin error critico.")
	if fallo:
		_finalizar_test(global, escena)
		return

	get_root().add_child(escena)
	await process_frame
	await process_frame

	var script_principal: Script = escena.get_script() as Script
	var contenedor_izquierda: VBoxContainer = escena.get_node_or_null("Control/VBoxIzquierda") as VBoxContainer
	var contenedor_derecha: VBoxContainer = escena.get_node_or_null("Control/VBoxDerecha") as VBoxContainer
	var line_drawer: Line2D = escena.get_node_or_null("Control/LineDrawer") as Line2D
	var boton_confirmar: Button = escena.get_node_or_null("Control/ConfirmButton") as Button
	var boton_continuar: Button = escena.get_node_or_null("Control/ContinueButton") as Button
	var feedback_label: Label = escena.get_node_or_null("Control/FeedbackLabel") as Label
	var total_pares: int = int(escena.get("total_pares"))

	_assert(script_principal != null, "La escena deberia tener script principal asignado.")
	_assert(
		script_principal != null
			and script_principal.resource_path == "res://vincular/vincular_conceptos.gd",
		"La escena deberia usar el script principal de Vincular Conceptos."
	)
	_assert(contenedor_izquierda != null, "La escena deberia exponer el contenedor izquierdo.")
	_assert(contenedor_derecha != null, "La escena deberia exponer el contenedor derecho.")
	_assert(line_drawer != null, "La escena deberia exponer LineDrawer.")
	_assert(boton_confirmar != null, "La escena deberia crear el boton Confirmar.")
	_assert(boton_continuar != null, "La escena deberia crear el boton Continuar.")
	_assert(feedback_label != null, "La escena deberia crear el feedback label.")
	_assert(total_pares > 0, "La escena deberia cargar al menos un par desde el JSON de vinculación.")
	_assert(not bool(escena.get("bloqueado")), "La escena no deberia quedar bloqueada al iniciar el test.")

	_finalizar_test(global, escena)


func _preparar_contexto_minimo(global: Node) -> void:
	global.call("finalizar_partida_de_nodo")
	global.call("limpiar_sesion_nodo_jugable_activo")
	global.call(
		"establecer_sesion_nodo_jugable_activo",
		{
			"track_key": "celiaquia",
			"level_number": 1,
			"node_key": "vincular_alimentos_seguridad",
			"node_title": "Vincular conceptos",
			"json_path": "res://contenido/nodos/celiaquia/vinculacion/vincular_alimentos_seguridad.json",
			"mode": "vinculacion_conceptos",
			"return_to": "res://mapas/MapScene.tscn",
			"difficulty": 1,
		}
	)


func _finalizar_test(global: Node, escena: Node) -> void:
	if is_instance_valid(escena):
		escena.queue_free()
	if global != null:
		global.call("finalizar_partida_de_nodo")
		global.call("limpiar_sesion_nodo_jugable_activo")
	quit(1 if fallo else 0)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("VINCULAR CONCEPTOS SCENE TEST FAILED: %s" % mensaje)