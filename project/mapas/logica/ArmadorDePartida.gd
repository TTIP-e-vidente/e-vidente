extends RefCounted
class_name ArmadorDePartida

const CatalogoDePistas := preload("res://niveles/GameTrackCatalog.gd")
const CargadorMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const DatosNodoMapaScript := preload("res://mapas/core/MapNodeData.gd")

const JUEGOS_POR_PARTIDA_DE_NODO := 5
const MAXIMA_DIFICULTAD_POR_JUEGO := 5
const MODOS_SOPORTADOS := [
	DatosNodoMapaScript.MODE_DRAG_DROP,
	DatosNodoMapaScript.MODE_QUIZ_CHOICE,
	DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS,
]
const RUTA_MAPA_POR_PISTA := {
	CatalogoDePistas.TRACK_CELIAQUIA: "res://contenido/mapas/celiaquia_mapa.json",
}
const LOG_PREFIX := "[ARMADOR_PARTIDA]"


# Plan de partida
static func construir_plan_de_partida(node_data: MapNodeData) -> Dictionary:
	if node_data == null or not node_data.is_valid():
		print(LOG_PREFIX, " nodo invalido o sin contenido")
		return {}

	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var juegos: Array[Dictionary] = []
	if node_data.has_explicit_games():
		juegos = construir_juegos_explicitos(node_data)
		print(
			LOG_PREFIX,
			" nodo=", node_data.node_key,
			" juegos_explicitos=", juegos.size(),
			" usa_v1=", not juegos.is_empty()
		)
		if juegos.is_empty():
			push_warning(
				"ArmadorDePartida: juegos explicitos invalidos en %s. Se usa legacy."
				% node_data.node_key
			)
	if juegos.is_empty():
		var total_juegos: int = obtener_cantidad_de_juegos_para_nodo(node_data.index)
		juegos = construir_juegos_para_nodo(node_data, total_juegos)
	if juegos.is_empty():
		push_error(
			"ArmadorDePartida: no se pudo armar ningun juego para el nodo %s."
			% node_data.node_key
		)
		print(LOG_PREFIX, " nodo=", node_data.node_key, " juegos=0 usa_v1=false")
		return {}
	print(
		LOG_PREFIX,
		" nodo=", node_data.node_key,
		" juegos=", juegos.size(),
		" modo_inicial=", str(juegos[0].get("mode", ""))
	)

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
	if indice_seguro <= 0:
		return 1
	if indice_seguro <= 3:
		return 2
	if indice_seguro <= 7:
		return 3
	if indice_seguro <= 11:
		return 4
	return JUEGOS_POR_PARTIDA_DE_NODO


static func construir_juegos_explicitos(node_data: MapNodeData) -> Array[Dictionary]:
	var juegos: Array[Dictionary] = []
	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	for raw_game in node_data.game_entries:
		var game_entry: Dictionary = raw_game as Dictionary
		var datos_juego := {
			"mode": str(game_entry.get("mode", game_entry.get("tipo", ""))).strip_edges(),
			"json_path": str(
				game_entry.get("archivo", game_entry.get("json_path", ""))
			).strip_edges(),
			"titulo": str(
				game_entry.get("titulo", game_entry.get("title", node_data.title))
			).strip_edges(),
			"clave_nodo_de_origen": node_data.node_key,
		}
		var juego: Dictionary = _crear_juego_manual(datos_juego, dificultad_base)
		if str(juego.get("mode", "")).strip_edges().is_empty():
			print(LOG_PREFIX, " juego explicito ignorado por mode invalido: ", game_entry)
			continue
		if str(juego.get("json_path", "")).strip_edges().is_empty():
			print(LOG_PREFIX, " juego explicito ignorado por json_path vacio: ", game_entry)
			continue
		juegos.append(juego)
	return juegos


# Armado de juegos
static func construir_juegos_para_nodo(
	node_data: MapNodeData,
	total_juegos: int
) -> Array[Dictionary]:
	var total_juegos_seguro: int = clampi(total_juegos, 1, JUEGOS_POR_PARTIDA_DE_NODO)

	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var juegos: Array[Dictionary] = []
	juegos.append(_crear_juego(node_data, 0, dificultad_base))

	var modo_inicial: String = _normalizar_modo(node_data.mode)
	if modo_inicial.is_empty() or total_juegos_seguro == 1:
		return juegos

	var nodos_jugables: Array[MapNodeData] = _cargar_nodos_jugables_de_pista(node_data.track_key)
	var nodos_por_modo: Dictionary = _agrupar_nodos_por_modo(nodos_jugables)
	var rutas_usadas: Dictionary = {node_data.json_path: true}
	var modos_disponibles: Array[String] = _obtener_modos_disponibles(
		modo_inicial,
		nodos_por_modo,
		node_data,
		dificultad_base
	)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var secuencia_modos: Array[String] = _construir_secuencia_modos(
		modo_inicial,
		modos_disponibles,
		total_juegos_seguro,
		rng
	)

	for indice_juego in range(1, total_juegos_seguro):
		var modo_objetivo: String = secuencia_modos[indice_juego]
		var nodo_elegido: MapNodeData = _elegir_nodo_aleatorio_para_modo(
			nodos_por_modo,
			rutas_usadas,
			modo_objetivo,
			node_data,
			rng
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


static func _elegir_nodo_aleatorio_para_modo(
	nodos_por_modo: Dictionary,
	rutas_usadas: Dictionary,
	modo_objetivo: String,
	nodo_fallback: MapNodeData,
	rng: RandomNumberGenerator
) -> MapNodeData:
	var grupo: Array = nodos_por_modo.get(modo_objetivo, [])
	if grupo.is_empty():
		return nodo_fallback

	var candidatos_sin_repetir: Array[MapNodeData] = []
	for candidato_crudo in grupo:
		var candidato: MapNodeData = candidato_crudo as MapNodeData
		if candidato == null:
			continue
		if rutas_usadas.has(candidato.json_path):
			continue
		candidatos_sin_repetir.append(candidato)

	var candidatos: Array = (
		candidatos_sin_repetir if not candidatos_sin_repetir.is_empty() else grupo
	)
	var indice_elegido: int = rng.randi_range(0, candidatos.size() - 1)
	var nodo_elegido: MapNodeData = candidatos[indice_elegido] as MapNodeData
	if nodo_elegido == null:
		return nodo_fallback
	rutas_usadas[nodo_elegido.json_path] = true
	return nodo_elegido


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


static func _crear_juego_manual(datos_juego: Dictionary, dificultad: int) -> Dictionary:
	var ruta_json: String = str(datos_juego.get("json_path", "")).strip_edges()
	if not FileAccess.file_exists(ruta_json):
		push_warning("ArmadorDePartida: no existe el contenido de partida: %s" % ruta_json)
	var modo: String = _normalizar_modo(str(datos_juego.get("mode", "")))
	return {
		"mode": modo,
		"tipo": modo,
		"json_path": ruta_json,
		"archivo": ruta_json,
		"titulo": str(datos_juego.get("titulo", "")).strip_edges(),
		"dificultad": _limitar_dificultad(dificultad),
		"difficulty": _limitar_dificultad(dificultad),
		"clave_nodo_de_origen": str(datos_juego.get("clave_nodo_de_origen", "")).strip_edges(),
	}


static func _calcular_dificultad_del_juego(dificultad_inicial: int, numero_de_juego: int) -> int:
	var dificultad_segura: int = clampi(dificultad_inicial, 1, MAXIMA_DIFICULTAD_POR_JUEGO)
	if dificultad_segura <= 1:
		return 1
	var avance_del_juego: int = int(floor(float(maxi(0, numero_de_juego)) / 2.0))
	return _limitar_dificultad(dificultad_segura + avance_del_juego)


static func _limitar_dificultad(dificultad: int) -> int:
	return clampi(dificultad, 1, MAXIMA_DIFICULTAD_POR_JUEGO)


static func _obtener_modos_disponibles(
	modo_inicial: String,
	nodos_por_modo: Dictionary,
	node_data: MapNodeData,
	dificultad_base: int
) -> Array[String]:
	var modos_disponibles: Array[String] = []
	modos_disponibles.append(modo_inicial)

	for modo in MODOS_SOPORTADOS:
		var modo_limpio: String = str(modo).strip_edges()
		if modo_limpio == modo_inicial:
			continue
		if (
			modo_limpio == DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS
			and not _puede_usar_vinculacion(node_data, dificultad_base)
		):
			continue
		var grupo: Array = nodos_por_modo.get(modo_limpio, [])
		if grupo.is_empty():
			continue
		modos_disponibles.append(modo_limpio)

	return modos_disponibles


static func _elegir_modo_aleatorio(
	modos_disponibles: Array[String],
	rng: RandomNumberGenerator
) -> String:
	if modos_disponibles.is_empty():
		return ""
	return modos_disponibles[rng.randi_range(0, modos_disponibles.size() - 1)]


static func _construir_secuencia_modos(
	modo_inicial: String,
	modos_disponibles: Array[String],
	total_juegos: int,
	rng: RandomNumberGenerator
) -> Array[String]:
	var secuencia: Array[String] = [modo_inicial]
	var modos_pendientes: Array[String] = []
	for modo in modos_disponibles:
		if modo == modo_inicial:
			continue
		modos_pendientes.append(modo)
	_mezclar_array(modos_pendientes, rng)

	while secuencia.size() < total_juegos:
		if not modos_pendientes.is_empty():
			secuencia.append(modos_pendientes.pop_back())
			continue
		secuencia.append(_elegir_modo_aleatorio(modos_disponibles, rng))
	return secuencia


static func _mezclar_array(valores: Array[String], rng: RandomNumberGenerator) -> void:
	for indice in range(valores.size() - 1, 0, -1):
		var indice_aleatorio: int = rng.randi_range(0, indice)
		var valor_temporal: String = valores[indice]
		valores[indice] = valores[indice_aleatorio]
		valores[indice_aleatorio] = valor_temporal


static func _normalizar_modo(mode: String) -> String:
	var modo_limpio: String = mode.strip_edges()
	if _es_modo_soportado(modo_limpio):
		return modo_limpio
	return ""


static func _es_modo_soportado(mode: String) -> bool:
	return MODOS_SOPORTADOS.has(mode.strip_edges())


static func _puede_usar_vinculacion(node_data: MapNodeData, dificultad_base: int) -> bool:
	if node_data == null:
		return false
	if _normalizar_modo(node_data.mode) == DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS:
		return true
	if dificultad_base >= 4:
		return true
	return node_data.index >= 10
