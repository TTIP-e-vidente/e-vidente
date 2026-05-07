extends RefCounted
class_name ArmadorDePartida

const CatalogoDePistas := preload("res://niveles/GameTrackCatalog.gd")
const CargadorMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const DatosNodoMapaScript := preload("res://mapas/core/MapNodeData.gd")

const MAXIMO_JUEGOS_POR_NODO := 5
const MAXIMA_DIFICULTAD_POR_JUEGO := 5
const MODOS_SOPORTADOS := [
	DatosNodoMapaScript.MODE_DRAG_DROP,
	DatosNodoMapaScript.MODE_QUIZ_CHOICE,
	DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS,
]
const RUTA_MAPA_POR_PISTA := {
	CatalogoDePistas.TRACK_CELIAQUIA: "res://contenido/mapas/celiaquia_mapa.json",
}


# Plan de partida
static func construir_plan_de_partida(node_data: MapNodeData) -> Dictionary:
	if node_data == null or not node_data.is_valid():
		return {}

	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var total_juegos: int = obtener_cantidad_de_juegos_para_nodo(node_data.index)
	var juegos: Array[Dictionary] = construir_juegos_para_nodo(node_data, total_juegos)

	return {
		"clave_nodo": node_data.node_key,
		"titulo_nodo": node_data.title,
		"clave_pista": node_data.track_key,
		"dificultad": dificultad_base,
		"numero_nivel": node_data.index + 1,
		"indice_juego_actual": 0,
		"total_juegos": juegos.size(),
		"juegos": juegos,
	}


static func obtener_cantidad_de_juegos_para_nodo(node_index: int) -> int:
	var indice_seguro: int = maxi(0, node_index)
	if indice_seguro == 0:
		return 1
	if indice_seguro <= 2:
		return 2
	if indice_seguro <= 4:
		return 3
	if indice_seguro <= 6:
		return 4
	return MAXIMO_JUEGOS_POR_NODO


# Armado de juegos
static func construir_juegos_para_nodo(node_data: MapNodeData, total_juegos: int) -> Array[Dictionary]:
	var total_juegos_seguro: int = maxi(1, total_juegos)
	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var juegos: Array[Dictionary] = []
	juegos.append(_crear_juego(node_data, 0, dificultad_base))

	var modo_inicial: String = _normalizar_modo(node_data.mode)
	if modo_inicial.is_empty() or total_juegos_seguro == 1:
		return juegos

	var nodos_jugables: Array[MapNodeData] = _cargar_nodos_jugables_de_pista(node_data.track_key)
	var nodos_por_modo: Dictionary = _agrupar_nodos_por_modo(nodos_jugables)
	var indices_por_modo: Dictionary = _calcular_indices_iniciales(nodos_por_modo, node_data)
	var rutas_usadas: Dictionary = {node_data.json_path: true}
	var rotacion_de_modos: Array[String] = _construir_rotacion_de_modos(
		modo_inicial,
		nodos_por_modo
	)

	for indice_juego in range(1, total_juegos_seguro):
		var modo_objetivo: String = rotacion_de_modos[indice_juego % rotacion_de_modos.size()]
		var nodo_elegido: MapNodeData = _elegir_nodo_para_modo(
			nodos_por_modo,
			indices_por_modo,
			rutas_usadas,
			modo_objetivo,
			node_data
		)
		juegos.append(_crear_juego(nodo_elegido, indice_juego, dificultad_base))

	return juegos


# Helpers privados
static func _cargar_nodos_jugables_de_pista(track_key: String) -> Array[MapNodeData]:
	var ruta_mapa: String = str(RUTA_MAPA_POR_PISTA.get(track_key.strip_edges(), "")).strip_edges()
	if ruta_mapa.is_empty():
		return []

	var resultado: Dictionary = CargadorMapaScript.load_map(ruta_mapa)
	if not bool(resultado.get("ok", false)):
		return []

	var nodos_crudos: Variant = resultado.get("data", {}).get("nodes", [])
	var nodos_de_pista: Array[MapNodeData] = []
	if not nodos_crudos is Array:
		return nodos_de_pista

	for raw_node in nodos_crudos:
		var nodo_mapa: MapNodeData = raw_node as MapNodeData
		if nodo_mapa == null:
			continue
		if not _es_modo_soportado(nodo_mapa.mode):
			continue
		nodos_de_pista.append(nodo_mapa)

	return nodos_de_pista


static func _agrupar_nodos_por_modo(nodos_de_pista: Array[MapNodeData]) -> Dictionary:
	var grupos: Dictionary = {}
	for modo in MODOS_SOPORTADOS:
		grupos[modo] = []

	for nodo_de_pista in nodos_de_pista:
		var modo: String = _normalizar_modo(nodo_de_pista.mode)
		if modo.is_empty():
			continue
		var grupo: Array = grupos.get(modo, [])
		grupo.append(nodo_de_pista)
		grupos[modo] = grupo

	return grupos


static func _calcular_indices_iniciales(nodos_por_modo: Dictionary, node_data: MapNodeData) -> Dictionary:
	var indices_iniciales: Dictionary = {}
	var clave_nodo_actual: String = node_data.node_key.strip_edges()
	for modo in MODOS_SOPORTADOS:
		var grupo: Array = nodos_por_modo.get(modo, [])
		if grupo.is_empty():
			indices_iniciales[modo] = 0
			continue

		var indice_actual := -1
		for indice in range(grupo.size()):
			var candidato: MapNodeData = grupo[indice] as MapNodeData
			if candidato == null:
				continue
			if candidato.node_key == clave_nodo_actual:
				indice_actual = indice
				break

		if indice_actual >= 0:
			indices_iniciales[modo] = indice_actual + 1
			continue

		indices_iniciales[modo] = node_data.index % grupo.size()

	return indices_iniciales


static func _elegir_nodo_para_modo(
	nodos_por_modo: Dictionary,
	indices_por_modo: Dictionary,
	rutas_usadas: Dictionary,
	modo_objetivo: String,
	nodo_fallback: MapNodeData
) -> MapNodeData:
	var grupo: Array = nodos_por_modo.get(modo_objetivo, [])
	if grupo.is_empty():
		return nodo_fallback

	var indice_inicial: int = int(indices_por_modo.get(modo_objetivo, 0))
	for desplazamiento in range(grupo.size()):
		var indice_grupo: int = (indice_inicial + desplazamiento) % grupo.size()
		var candidato: MapNodeData = grupo[indice_grupo] as MapNodeData
		if candidato == null:
			continue
		if rutas_usadas.has(candidato.json_path):
			continue
		indices_por_modo[modo_objetivo] = indice_grupo + 1
		rutas_usadas[candidato.json_path] = true
		return candidato

	var indice_repetido: int = indice_inicial % grupo.size()
	indices_por_modo[modo_objetivo] = indice_repetido + 1
	var candidato_repetido: MapNodeData = grupo[indice_repetido] as MapNodeData
	if candidato_repetido == null:
		return nodo_fallback
	return candidato_repetido


static func obtener_dificultad_base_del_nodo(node_data: MapNodeData) -> int:
	if node_data == null:
		return 1
	var dificultad_definida: int = int(node_data.difficulty)
	if dificultad_definida > 0:
		return _limitar_dificultad(dificultad_definida)
	return _calcular_dificultad_inicial_del_nodo(node_data.index)


static func _calcular_dificultad_inicial_del_nodo(indice_nodo: int) -> int:
	var posicion_nodo: int = maxi(0, indice_nodo)
	if posicion_nodo <= 0:
		return 1
	if posicion_nodo <= 2:
		return 2
	if posicion_nodo <= 4:
		return 2
	if posicion_nodo <= 6:
		return 3
	if posicion_nodo <= 8:
		return 4
	return 5


static func obtener_dificultad_para_juego(node_data: MapNodeData, indice_juego: int) -> int:
	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	return _calcular_dificultad_del_juego(dificultad_base, indice_juego)


static func _crear_juego(
	node_data: MapNodeData,
	indice_juego: int,
	dificultad_base: int
) -> Dictionary:
	return {
		"mode": _normalizar_modo(node_data.mode),
		"json_path": node_data.json_path,
		"titulo": node_data.title,
		"dificultad": _calcular_dificultad_del_juego(dificultad_base, indice_juego),
		"clave_nodo_de_origen": node_data.node_key,
	}


static func _calcular_dificultad_del_juego(dificultad_inicial: int, numero_de_juego: int) -> int:
	var dificultad_segura: int = clampi(dificultad_inicial, 1, MAXIMA_DIFICULTAD_POR_JUEGO)
	var avance_del_juego: int = maxi(0, numero_de_juego)
	return _limitar_dificultad(dificultad_segura + avance_del_juego)


static func _limitar_dificultad(dificultad: int) -> int:
	return clampi(dificultad, 1, MAXIMA_DIFICULTAD_POR_JUEGO)


static func _construir_rotacion_de_modos(
	modo_inicial: String,
	nodos_por_modo: Dictionary
) -> Array[String]:
	var rotacion: Array[String] = []
	rotacion.append(modo_inicial)

	for modo in MODOS_SOPORTADOS:
		if modo == modo_inicial:
			continue
		var grupo: Array = nodos_por_modo.get(modo, [])
		if grupo.is_empty():
			continue
		rotacion.append(modo)

	return rotacion


static func _normalizar_modo(mode: String) -> String:
	var modo_limpio: String = mode.strip_edges()
	if _es_modo_soportado(modo_limpio):
		return modo_limpio
	return ""


static func _es_modo_soportado(mode: String) -> bool:
	return MODOS_SOPORTADOS.has(mode.strip_edges())
