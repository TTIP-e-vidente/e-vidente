extends SceneTree

const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var resultado_mapa: Dictionary = CargadorDeMapaScript.load_map(
		"res://contenido/mapas/celiaquia_mapa.json"
	)
	_assert(bool(resultado_mapa.get("ok", false)), "No se pudo cargar el mapa de celiaquia.")
	if fallo:
		quit(1)
		return

	var nodos: Array = resultado_mapa.get("data", {}).get("nodes", [])
	var nodo_uno: Variant = null
	var nodo_temprano: Variant = null
	var nodo_vinculacion: Variant = null
	for nodo in nodos:
		if str(nodo.node_key).strip_edges() == "receta_1_desayuno":
			nodo_uno = nodo
		if str(nodo.node_key).strip_edges() == "receta_2_colacion":
			nodo_temprano = nodo
		if str(nodo.node_key).strip_edges() == "vincular_alimentos_seguridad":
			nodo_vinculacion = nodo

	_assert(nodo_uno != null, "El mapa deberia incluir el primer nodo de celiaquia.")
	_assert(nodo_temprano != null, "El mapa deberia incluir un nodo temprano de arrastre.")
	_assert(nodo_vinculacion != null, "El mapa deberia incluir el nodo de vinculacion.")
	if fallo:
		quit(1)
		return

	var plan_nodo_uno: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo_uno)
	var juegos_nodo_uno: Array = plan_nodo_uno.get("juegos", [])
	_assert(juegos_nodo_uno.size() == 1, "El nodo 1 deberia construir un solo juego.")
	_assert(
		_obtener_ruta_juego(juegos_nodo_uno, 0).ends_with("receta_1_desayuno.json"),
		"El nodo 1 deberia empezar con desayuno."
	)
	_assert(
		str((juegos_nodo_uno[0] as Dictionary).get("mode", "")) == "drag_drop",
		"El nodo 1 deberia iniciar en arrastre."
	)
	_assert(
		_todos_los_juegos_tienen_dificultad(juegos_nodo_uno, 1),
		"El nodo 1 debe mantenerse en dificultad 1."
	)

	var plan_nodo_temprano: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(
		nodo_temprano
	)
	var juegos_nodo_temprano: Array = plan_nodo_temprano.get("juegos", [])
	_assert(juegos_nodo_temprano.size() == 2, "Los nodos tempranos deberian crecer a dos juegos.")
	_assert(
		not _contiene_modo(juegos_nodo_temprano, "vinculacion_conceptos"),
		"La vinculacion no deberia aparecer en nodos tempranos."
	)

	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo_vinculacion)
	var juegos: Array = plan.get("juegos", [])
	_assert(not juegos.is_empty(), "La partida por nodo deberia construir juegos.")
	_assert(juegos.size() == 5, "Los nodos avanzados deberian llegar a 5 juegos.")
	_assert(
		_contiene_modo(juegos, "vinculacion_conceptos"),
		"La partida deberia incluir la modalidad de vinculacion."
	)
	_assert(
		_contiene_modo(juegos, "drag_drop"),
		"La rotacion deberia conservar arrastre cuando existe en la pista."
	)
	_assert(
		_contiene_modo(juegos, "quiz_choice"),
		"La rotacion deberia conservar preguntas cuando existe en la pista."
	)

	quit(1 if fallo else 0)


func _contiene_modo(juegos: Array, modo: String) -> bool:
	for juego in juegos:
		if str((juego as Dictionary).get("mode", "")).strip_edges() == modo:
			return true
	return false


func _obtener_ruta_juego(juegos: Array, indice: int) -> String:
	if indice < 0 or indice >= juegos.size():
		return ""
	return str((juegos[indice] as Dictionary).get("json_path", "")).strip_edges()


func _todos_los_juegos_tienen_dificultad(juegos: Array, dificultad: int) -> bool:
	for juego in juegos:
		if int((juego as Dictionary).get("dificultad", 0)) != dificultad:
			return false
	return true


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("PLAN TEST FAILED: %s" % mensaje)
