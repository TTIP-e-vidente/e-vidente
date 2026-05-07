extends SceneTree

const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var global := get_root().get_node_or_null("/root/Global")
	_assert(global != null, "El autoload Global debe estar disponible.")
	if fallo:
		quit(1)
		return

	var nodo_multiple: MapNodeData = _obtener_nodo_de_prueba()
	_assert(nodo_multiple != null, "Debe existir un nodo avanzado para probar partida multiple.")
	if fallo:
		quit(1)
		return

	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo_multiple)
	var juegos: Array = plan.get("juegos", [])
	_assert(juegos.size() > 1, "El nodo avanzado debe generar mas de un juego.")
	_assert(int(plan.get("total_juegos", 0)) == juegos.size(), "El total del plan debe coincidir con juegos.")
	if fallo:
		quit(1)
		return

	global.call("finalizar_partida_de_nodo")
	global.call("iniciar_partida_de_nodo", plan)

	var juego_uno: Dictionary = global.call("obtener_juego_actual_de_partida")
	_assert(not juego_uno.is_empty(), "Debe existir juego actual al iniciar partida.")
	_assert(int(juego_uno.get("indice_juego_actual", -1)) == 0, "La partida debe iniciar en Juego 1.")
	_assert(int(juego_uno.get("total_juegos", 0)) == juegos.size(), "Juego 1 debe conocer el total real.")
	_assert(bool(global.call("hay_siguiente_juego_de_partida")), "Juego 1 no debe finalizar una partida multiple.")

	global.call("avanzar_partida_de_nodo")
	var juego_dos: Dictionary = global.call("obtener_juego_actual_de_partida")
	_assert(int(juego_dos.get("indice_juego_actual", -1)) == 1, "Avanzar debe pasar a Juego 2.")
	_assert(int(juego_dos.get("total_juegos", 0)) == juegos.size(), "Juego 2 debe conservar el total real.")

	while bool(global.call("hay_siguiente_juego_de_partida")):
		global.call("avanzar_partida_de_nodo")

	_assert(
		not bool(global.call("hay_siguiente_juego_de_partida")),
		"Solo el ultimo juego debe quedarse sin siguiente."
	)
	global.call("finalizar_partida_de_nodo")
	_assert(
		(global.call("obtener_partida_de_nodo_actual") as Dictionary).is_empty(),
		"Finalizar debe limpiar la partida activa."
	)

	quit(1 if fallo else 0)


func _obtener_nodo_de_prueba() -> MapNodeData:
	var resultado_mapa: Dictionary = CargadorDeMapaScript.load_map(
		"res://contenido/mapas/celiaquia_mapa.json"
	)
	if not bool(resultado_mapa.get("ok", false)):
		return null
	var nodos: Array = resultado_mapa.get("data", {}).get("nodes", [])
	for nodo in nodos:
		var nodo_mapa: MapNodeData = nodo as MapNodeData
		if nodo_mapa == null:
			continue
		if nodo_mapa.index >= 2:
			return nodo_mapa
	return null


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("PARTIDA MULTIPLE TEST FAILED: %s" % mensaje)
