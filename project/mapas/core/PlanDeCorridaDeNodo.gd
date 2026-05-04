extends RefCounted
class_name PlanDeCorridaDeNodo

const CatalogoDePistas := preload("res://niveles/GameTrackCatalog.gd")
const CargadorMapaScript := preload("res://mapas/core/MapJsonLoader.gd")
const DatosNodoMapaScript := preload("res://mapas/core/MapNodeData.gd")

const MAXIMO_JUEGOS_POR_NODO := 5
const RUTA_MAPA_POR_PISTA := {
	CatalogoDePistas.TRACK_CELIAQUIA: "res://contenido/mapas/celiaquia_mapa.json",
}


static func construir_plan_de_corrida(node_data: MapNodeData) -> Dictionary:
	if node_data == null or not node_data.is_valid():
		return {}

	var total_juegos: int = obtener_cantidad_de_juegos_para_nodo(node_data.index)
	var juegos: Array[Dictionary] = construir_juegos_para_nodo(node_data, total_juegos)
	if juegos.is_empty():
		juegos.append(_construir_entrada_de_juego(node_data))

	return {
		"clave_nodo": node_data.node_key,
		"titulo_nodo": node_data.title,
		"clave_pista": node_data.track_key,
		"dificultad": max(1, node_data.difficulty),
		"numero_nivel": node_data.index + 1,
		"indice_juego_actual": 0,
		"total_juegos": juegos.size(),
		"juegos": juegos,
	}


static func obtener_cantidad_de_juegos_para_nodo(node_index: int) -> int:
	return mini(MAXIMO_JUEGOS_POR_NODO, maxi(1, node_index))


static func construir_juegos_para_nodo(node_data: MapNodeData, total_juegos: int) -> Array[Dictionary]:
	var total_juegos_seguro: int = maxi(1, total_juegos)
	var juegos: Array[Dictionary] = []
	var modo_base: String = _normalizar_modo(node_data.mode)
	if modo_base.is_empty():
		juegos.append(_construir_entrada_de_juego(node_data))
		return juegos

	var nodos_de_pista: Array[MapNodeData] = _cargar_nodos_de_pista(node_data.track_key)
	var nodos_por_modo: Dictionary = _construir_grupos_por_modo(nodos_de_pista)
	var indices_siguientes: Dictionary = _construir_indices_iniciales(nodos_por_modo, node_data)
	var rutas_usadas: Dictionary = {}

	juegos.append(_construir_entrada_de_juego(node_data))
	rutas_usadas[node_data.json_path] = true

	for indice_juego in range(1, total_juegos_seguro):
		var modo_objetivo: String = _obtener_modo_para_juego(modo_base, indice_juego)
		var nodo_elegido: MapNodeData = _elegir_nodo_para_modo(
			nodos_por_modo,
			indices_siguientes,
			rutas_usadas,
			modo_objetivo,
			node_data
		)
		juegos.append(_construir_entrada_de_juego(nodo_elegido))

	return juegos


static func _cargar_nodos_de_pista(track_key: String) -> Array[MapNodeData]:
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


static func _construir_grupos_por_modo(nodos_de_pista: Array[MapNodeData]) -> Dictionary:
	var grupos: Dictionary = {
		DatosNodoMapaScript.MODE_DRAG_DROP: [],
		DatosNodoMapaScript.MODE_QUIZ_CHOICE: [],
	}

	for nodo_de_pista in nodos_de_pista:
		var modo: String = _normalizar_modo(nodo_de_pista.mode)
		if modo.is_empty():
			continue
		var grupo: Array = grupos.get(modo, [])
		grupo.append(nodo_de_pista)
		grupos[modo] = grupo

	return grupos


static func _construir_indices_iniciales(nodos_por_modo: Dictionary, node_data: MapNodeData) -> Dictionary:
	var indices_iniciales: Dictionary = {}
	for modo in [DatosNodoMapaScript.MODE_DRAG_DROP, DatosNodoMapaScript.MODE_QUIZ_CHOICE]:
		var grupo: Array = nodos_por_modo.get(modo, [])
		if grupo.is_empty():
			indices_iniciales[modo] = 0
			continue

		var indice_actual: int = _buscar_nodo_en_grupo(grupo, node_data.node_key)
		if indice_actual >= 0:
			indices_iniciales[modo] = indice_actual + 1
			continue

		indices_iniciales[modo] = node_data.index % grupo.size()

	return indices_iniciales


static func _elegir_nodo_para_modo(
	nodos_por_modo: Dictionary,
	indices_siguientes: Dictionary,
	rutas_usadas: Dictionary,
	modo_objetivo: String,
	nodo_fallback: MapNodeData
) -> MapNodeData:
	var grupo: Array = nodos_por_modo.get(modo_objetivo, [])
	if grupo.is_empty():
		return nodo_fallback

	var indice_inicial: int = int(indices_siguientes.get(modo_objetivo, 0))
	for desplazamiento in range(grupo.size()):
		var indice_grupo: int = (indice_inicial + desplazamiento) % grupo.size()
		var candidato: MapNodeData = grupo[indice_grupo] as MapNodeData
		if candidato == null:
			continue
		if rutas_usadas.has(candidato.json_path):
			continue
		indices_siguientes[modo_objetivo] = indice_grupo + 1
		rutas_usadas[candidato.json_path] = true
		return candidato

	var indice_repetido: int = indice_inicial % grupo.size()
	var candidato_repetido: MapNodeData = grupo[indice_repetido] as MapNodeData
	indices_siguientes[modo_objetivo] = indice_repetido + 1
	if candidato_repetido == null:
		return nodo_fallback
	return candidato_repetido


static func _construir_entrada_de_juego(node_data: MapNodeData) -> Dictionary:
	return {
		"mode": _normalizar_modo(node_data.mode),
		"json_path": node_data.json_path,
		"titulo": node_data.title,
		"clave_nodo_de_origen": node_data.node_key,
	}


static func _obtener_modo_para_juego(modo_base: String, indice_juego: int) -> String:
	if indice_juego % 2 == 0:
		return modo_base
	return _obtener_modo_opuesto(modo_base)


static func _obtener_modo_opuesto(mode: String) -> String:
	if mode == DatosNodoMapaScript.MODE_DRAG_DROP:
		return DatosNodoMapaScript.MODE_QUIZ_CHOICE
	return DatosNodoMapaScript.MODE_DRAG_DROP


static func _buscar_nodo_en_grupo(grupo: Array, node_key: String) -> int:
	var clave_nodo_limpia: String = node_key.strip_edges()
	for indice in range(grupo.size()):
		var candidato: MapNodeData = grupo[indice] as MapNodeData
		if candidato == null:
			continue
		if candidato.node_key == clave_nodo_limpia:
			return indice
	return -1


static func _normalizar_modo(mode: String) -> String:
	var modo_limpio: String = mode.strip_edges()
	if _es_modo_soportado(modo_limpio):
		return modo_limpio
	return ""


static func _es_modo_soportado(mode: String) -> bool:
	var modo_limpio: String = mode.strip_edges()
	return (
		modo_limpio == DatosNodoMapaScript.MODE_DRAG_DROP
		or modo_limpio == DatosNodoMapaScript.MODE_QUIZ_CHOICE
	)