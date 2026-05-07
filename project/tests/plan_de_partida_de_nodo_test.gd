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
	_assert(bool(resultado_mapa.get("ok", false)), "No se pudo cargar el mapa de celiaquía.")
	if fallo:
		quit(1)
		return

	var nodos: Array = resultado_mapa.get("data", {}).get("nodes", [])
	var nodo_vinculacion: Variant = null
	for nodo in nodos:
		if str(nodo.node_key).strip_edges() == "vincular_alimentos_seguridad":
			nodo_vinculacion = nodo
			break

	_assert(nodo_vinculacion != null, "El mapa debería incluir el nodo de vinculación.")
	if fallo:
		quit(1)
		return

	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo_vinculacion)
	var juegos: Array = plan.get("juegos", [])
	_assert(not juegos.is_empty(), "La partida por nodo debería construir juegos.")
	_assert(
		_contiene_modo(juegos, "vinculacion_conceptos"),
		"La partida debería incluir la modalidad de vinculación."
	)
	_assert(
		_contiene_modo(juegos, "drag_drop"),
		"La rotación debería conservar arrastre cuando existe en la pista."
	)
	_assert(
		_contiene_modo(juegos, "quiz_choice"),
		"La rotación debería conservar preguntas cuando existe en la pista."
	)

	quit(1 if fallo else 0)


func _contiene_modo(juegos: Array, modo: String) -> bool:
	for juego in juegos:
		if str((juego as Dictionary).get("mode", "")).strip_edges() == modo:
			return true
	return false


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("PLAN TEST FAILED: %s" % mensaje)
