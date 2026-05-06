extends RefCounted
class_name PlanDePartidaDeNodo

const CatalogoDePistas := preload("res://niveles/GameTrackCatalog.gd")
const CargadorMapaScript := preload("res://mapas/core/MapJsonLoader.gd")
const DatosNodoMapaScript := preload("res://mapas/core/MapNodeData.gd")

const MAXIMO_JUEGOS_POR_NODO := 5
const MAXIMA_DIFICULTAD_POR_JUEGO := 5
const RUTA_MAPA_POR_PISTA := {
	CatalogoDePistas.TRACK_CELIAQUIA: "res://contenido/mapas/celiaquia_mapa.json",
}


# Plan de partida
static func construir_plan_de_partida(node_data: MapNodeData) -> Dictionary:
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
		"dificultad": obtener_dificultad_base_del_nodo(node_data),
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
	juegos.append(_construir_entrada_de_juego_con_indice(node_data, 0, dificultad_base))

	var modo_base: String = _normalizar_modo(node_data.mode)
	if modo_base.is_empty():
		return juegos

	var estado_de_seleccion: Dictionary = _construir_estado_de_seleccion_de_juegos(node_data)
	var rotacion_de_modos: Array[String] = _construir_rotacion_de_modos(
		modo_base,
		estado_de_seleccion.get("nodos_por_modo", {})
	)
	_agregar_juegos_restantes(
		juegos,
		node_data,
		total_juegos_seguro,
		rotacion_de_modos,
		dificultad_base,
		estado_de_seleccion
	)

	return juegos


# Helpers privados
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
		DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS: [],
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
	for modo in _obtener_modos_soportados():
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
	var candidato_sin_repetir: MapNodeData = _buscar_candidato_sin_repetir(
		nodos_por_modo,
		indices_siguientes,
		rutas_usadas,
		modo_objetivo
	)
	if candidato_sin_repetir != null:
		return candidato_sin_repetir
	return _buscar_candidato_repetido(
		nodos_por_modo,
		indices_siguientes,
		modo_objetivo,
		nodo_fallback
	)


static func _buscar_candidato_sin_repetir(
	nodos_por_modo: Dictionary,
	indices_siguientes: Dictionary,
	rutas_usadas: Dictionary,
	modo_objetivo: String
) -> MapNodeData:
	var grupo: Array = nodos_por_modo.get(modo_objetivo, [])
	if grupo.is_empty():
		return null

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

	return null


static func _buscar_candidato_repetido(
	nodos_por_modo: Dictionary,
	indices_siguientes: Dictionary,
	modo_objetivo: String,
	nodo_fallback: MapNodeData
) -> MapNodeData:
	var grupo: Array = nodos_por_modo.get(modo_objetivo, [])
	if grupo.is_empty():
		return nodo_fallback

	var indice_inicial: int = int(indices_siguientes.get(modo_objetivo, 0))
	var indice_repetido: int = indice_inicial % grupo.size()
	var candidato_repetido: MapNodeData = grupo[indice_repetido] as MapNodeData
	indices_siguientes[modo_objetivo] = indice_repetido + 1
	if candidato_repetido == null:
		return nodo_fallback
	return candidato_repetido


static func _construir_estado_de_seleccion_de_juegos(node_data: MapNodeData) -> Dictionary:
	var nodos_de_pista: Array[MapNodeData] = _cargar_nodos_de_pista(node_data.track_key)
	var nodos_por_modo: Dictionary = _construir_grupos_por_modo(nodos_de_pista)
	var indices_siguientes: Dictionary = _construir_indices_iniciales(nodos_por_modo, node_data)
	return {
		"nodos_por_modo": nodos_por_modo,
		"indices_siguientes": indices_siguientes,
		"rutas_usadas": {node_data.json_path: true},
	}


static func _agregar_juegos_restantes(
	juegos: Array[Dictionary],
	node_data: MapNodeData,
	total_juegos: int,
	rotacion_de_modos: Array[String],
	dificultad_base: int,
	estado_de_seleccion: Dictionary
) -> void:
	for indice_juego in range(1, total_juegos):
		juegos.append(
			_construir_juego_siguiente(
				node_data,
				rotacion_de_modos,
				indice_juego,
				dificultad_base,
				estado_de_seleccion
			)
		)


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


static func _construir_juego_siguiente(
	node_data: MapNodeData,
	rotacion_de_modos: Array[String],
	indice_juego: int,
	dificultad_base: int,
	estado_de_seleccion: Dictionary
) -> Dictionary:
	var modo_objetivo: String = _obtener_modo_para_juego(rotacion_de_modos, indice_juego)
	var nodos_por_modo: Dictionary = estado_de_seleccion.get("nodos_por_modo", {})
	var indices_siguientes: Dictionary = estado_de_seleccion.get("indices_siguientes", {})
	var rutas_usadas: Dictionary = estado_de_seleccion.get("rutas_usadas", {})
	var nodo_elegido: MapNodeData = _elegir_nodo_para_modo(
		nodos_por_modo,
		indices_siguientes,
		rutas_usadas,
		modo_objetivo,
		node_data
	)
	return _construir_entrada_de_juego_con_indice(nodo_elegido, indice_juego, dificultad_base)


static func _construir_entrada_de_juego(node_data: MapNodeData) -> Dictionary:
	return _construir_entrada_de_juego_con_indice(
		node_data,
		0,
		obtener_dificultad_base_del_nodo(node_data)
	)


static func _construir_entrada_de_juego_con_indice(
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
	modo_base: String,
	nodos_por_modo: Dictionary
) -> Array[String]:
	var rotacion: Array[String] = []
	if not modo_base.is_empty():
		rotacion.append(modo_base)

	for modo in _obtener_modos_soportados():
		if modo == modo_base:
			continue
		var grupo: Array = nodos_por_modo.get(modo, [])
		if grupo.is_empty():
			continue
		rotacion.append(modo)

	if rotacion.is_empty() and not modo_base.is_empty():
		rotacion.append(modo_base)
	return rotacion


static func _obtener_modo_para_juego(rotacion_de_modos: Array[String], indice_juego: int) -> String:
	if rotacion_de_modos.is_empty():
		return ""
	return rotacion_de_modos[indice_juego % rotacion_de_modos.size()]


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
		or modo_limpio == DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS
	)


static func _obtener_modos_soportados() -> Array[String]:
	return [
		DatosNodoMapaScript.MODE_DRAG_DROP,
		DatosNodoMapaScript.MODE_QUIZ_CHOICE,
		DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS,
	]
