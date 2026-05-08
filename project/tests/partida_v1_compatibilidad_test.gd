extends SceneTree

const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_validar_nodo_v1_explicito()
	_validar_fallback_legacy_si_v1_es_invalido()
	quit(1 if fallo else 0)


func _validar_nodo_v1_explicito() -> void:
	var resultado_mapa: Dictionary = CargadorDeMapaScript.load_map(
		"res://contenido/tests/fixtures/mapas/celiaquia_mapa_v1.json"
	)
	_assert(bool(resultado_mapa.get("ok", false)), "El mapa V1 debe cargar.")
	if fallo:
		return
	var nodos: Array = resultado_mapa.get("data", {}).get("nodes", [])
	var nodo_v1: MapNodeData = nodos[0] as MapNodeData
	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo_v1)
	var juegos: Array = plan.get("juegos", [])
	_assert(juegos.size() == 2, "El nodo V1 valido debe usar sus 2 juegos explicitos.")
	_assert(
		str(juegos[0].get("mode", "")) == "drag_drop",
		"El primer juego V1 debe ser arrastre runtime."
	)
	_assert(
		str(juegos[1].get("mode", "")) == "quiz_choice",
		"El segundo juego V1 debe ser preguntas runtime."
	)


func _validar_fallback_legacy_si_v1_es_invalido() -> void:
	var nodo := MapNodeData.new()
	nodo.node_key = "receta_2_colacion"
	nodo.title = "Nodo con V1 invalido"
	nodo.mode = MapNodeData.MODE_DRAG_DROP
	nodo.json_path = "res://contenido/nodos/celiaquia/arrastre/receta_2_colacion.json"
	nodo.track_key = "celiaquia"
	nodo.index = 2
	nodo.game_entries = [
		{
			"id": "juego_roto",
			"tipo": "modo_inexistente",
			"archivo": "",
		}
	]

	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo)
	var juegos: Array = plan.get("juegos", [])
	_assert(
		juegos.size() == ArmadorDePartidaScript.obtener_cantidad_de_juegos_para_nodo(nodo.index),
		"Si V1 explicito es invalido debe volver al plan legacy progresivo."
	)
	_assert(
		str(juegos[0].get("json_path", "")).find("receta_2_colacion.json") >= 0,
		"El fallback debe conservar el nodo legacy."
	)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("PARTIDA V1 COMPATIBILIDAD TEST FAILED: %s" % mensaje)
