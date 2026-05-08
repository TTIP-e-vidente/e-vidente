extends SceneTree

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var global: Node = get_root().get_node_or_null("/root/Global")
	_assert(global != null, "El autoload Global debe estar disponible.")
	if global == null:
		quit(1)
		return

	global.call("finalizar_partida_de_nodo")
	global.call("limpiar_sesion_nodo_jugable_activo")
	global.call(
		"establecer_sesion_nodo_jugable_activo",
		{
			"mode": "vinculacion_conceptos",
			"track_key": "celiaquia",
			"node_key": "vincular_alimentos_seguridad",
			"return_to": "res://mapas/MapScene.tscn",
		}
	)

	_assert(
		bool(global.call("hay_juego_o_nodo_para_continuar")),
		"Global debe detectar una sesion jugable pendiente."
	)
	var destino: Dictionary = global.call("obtener_destino_de_continuacion")
	_assert(
		str(destino.get("type", "")) == "playable_mode",
		"El destino pendiente debe usar el router de modalidad jugable."
	)
	_assert(
		str(destino.get("mode", "")) == "vinculacion_conceptos",
		"El destino pendiente debe conservar la modalidad."
	)

	global.call("limpiar_sesion_nodo_jugable_activo")
	quit(1 if fallo else 0)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("CONTINUACION GLOBAL TEST FAILED: %s" % mensaje)
