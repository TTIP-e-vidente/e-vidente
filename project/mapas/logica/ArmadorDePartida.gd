extends RefCounted
class_name ArmadorDePartida

const CatalogoDePistas := preload("res://niveles/GameTrackCatalog.gd")
const CargadorMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const DatosNodoMapaScript := preload("res://mapas/core/MapNodeData.gd")

const JUEGOS_POR_PARTIDA_DE_NODO := 5
const MAXIMA_DIFICULTAD_POR_JUEGO := 5
const MODOS_SOPORTADOS := [
	DatosNodoMapaScript.MODE_DRAG_DROP,
	DatosNodoMapaScript.MODE_QUIZ_CHOICE,
	DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS,
]
const RUTA_MAPA_POR_PISTA := {
	CatalogoDePistas.TRACK_CELIAQUIA: "res://contenido/mapa/celiaquia_mapa.json",
}
const LOG_PREFIX := "[RunPlan]"
const DIFICULTAD_FACIL := 1
const DIFICULTAD_MEDIA := 3
const DIFICULTAD_DIFICIL := 5

static var _cache_dificultad_por_ruta: Dictionary = {}


# Arma la corrida del nodo sin tocar el JSON original ni abrir escenas.
static func construir_plan_de_partida(node_data: MapNodeData) -> Dictionary:
	if node_data == null or not node_data.is_valid():
		print(LOG_PREFIX, " nodo invalido o sin contenido")
		return {}

	var effective_pack_id: String = node_data.get_effective_pack_id()
	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var juegos: Array[Dictionary] = []
	if node_data.has_explicit_games():
		juegos = construir_juegos_explicitos(node_data)
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
		"%s track=%s node=%s games=%d"
		% [LOG_PREFIX, effective_pack_id, node_data.node_key, juegos.size()]
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
	return _obtener_patron_dificultad_para_nodo(node_index).size()


static func construir_juegos_explicitos(node_data: MapNodeData) -> Array[Dictionary]:
	# Usa exactamente la lista declarada en games; shuffle solo reordena una copia local.
	var juegos: Array[Dictionary] = []
	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var game_entries: Array[Dictionary] = _preparar_game_entries_para_plan(node_data)
	for raw_game in game_entries:
		var game_entry: Dictionary = raw_game as Dictionary
		var pack_id: String = _resolve_pack_id_for_game_entry(game_entry, node_data)
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		var mode: String = str(game_entry.get("mode", game_entry.get("tipo", ""))).strip_edges()
		var datos_juego := {
			"mode": mode,
			"json_path": str(
				game_entry.get("archivo", game_entry.get("json_path", ""))
			).strip_edges(),
			"activity_id": activity_id,
			"pack_id": pack_id,
			"titulo": str(
				game_entry.get("titulo", game_entry.get("title", node_data.title))
			).strip_edges(),
			"clave_nodo_de_origen": node_data.node_key,
		}
		var dificultad_juego: int = int(
			game_entry.get("difficulty", game_entry.get("dificultad", dificultad_base))
		)
		if dificultad_juego <= 0:
			dificultad_juego = dificultad_base
		var juego: Dictionary = _crear_juego_manual(datos_juego, dificultad_juego)
		if str(juego.get("mode", "")).strip_edges().is_empty():
			print(LOG_PREFIX, " juego explicito ignorado por mode invalido: ", game_entry)
			continue
		if (
			str(juego.get("json_path", "")).strip_edges().is_empty()
			and str(juego.get("activity_id", "")).strip_edges().is_empty()
		):
			print(LOG_PREFIX, " juego explicito ignorado por json_path vacio: ", game_entry)
			continue
		juegos.append(juego)
	return juegos


# Armado de juegos
static func construir_juegos_para_nodo(
	node_data: MapNodeData,
	total_juegos: int
) -> Array[Dictionary]:
	var dificultades_objetivo: Array[int] = _obtener_patron_dificultad_para_nodo(node_data.index)
	var total_juegos_seguro: int = mini(
		clampi(total_juegos, 1, JUEGOS_POR_PARTIDA_DE_NODO),
		dificultades_objetivo.size()
	)
	var juegos: Array[Dictionary] = []
	juegos.append(_crear_juego(node_data, dificultades_objetivo[0]))

	var modo_inicial: String = _normalizar_modo(node_data.mode)
	if modo_inicial.is_empty() or total_juegos_seguro == 1:
		return juegos

	var nodos_jugables: Array[MapNodeData] = _cargar_nodos_jugables_de_pista(node_data.track_key)
	var nodos_por_modo: Dictionary = _agrupar_nodos_por_modo(nodos_jugables)
	var rutas_usadas: Dictionary = {node_data.json_path: true}
	if not node_data.activity_id.is_empty():
		rutas_usadas[node_data.activity_id] = true
	var modos_disponibles: Array[String] = _obtener_modos_disponibles(
		modo_inicial,
		nodos_por_modo,
		node_data,
		dificultades_objetivo
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
		var dificultad_objetivo: int = dificultades_objetivo[indice_juego]
		var nodo_elegido: MapNodeData = _elegir_nodo_aleatorio_para_modo(
			nodos_por_modo,
			rutas_usadas,
			modo_objetivo,
			dificultad_objetivo,
			node_data,
			rng
		)
		juegos.append(_crear_juego(nodo_elegido, dificultad_objetivo))

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
	dificultad_objetivo: int,
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

	var candidatos_por_dificultad: Array[MapNodeData] = _filtrar_candidatos_por_dificultad(
		candidatos_sin_repetir,
		dificultad_objetivo
	)
	if candidatos_por_dificultad.is_empty():
		candidatos_por_dificultad = _filtrar_candidatos_por_dificultad(
			grupo,
			dificultad_objetivo
		)

	var candidatos: Array = []
	if not candidatos_por_dificultad.is_empty():
		candidatos = candidatos_por_dificultad
	elif not candidatos_sin_repetir.is_empty():
		candidatos = candidatos_sin_repetir
	else:
		candidatos = grupo
	var indice_elegido: int = rng.randi_range(0, candidatos.size() - 1)
	var nodo_elegido: MapNodeData = candidatos[indice_elegido] as MapNodeData
	if nodo_elegido == null:
		return nodo_fallback
	rutas_usadas[nodo_elegido.json_path] = true
	return nodo_elegido


static func obtener_dificultad_base_del_nodo(node_data: MapNodeData) -> int:
	if node_data == null:
		return DIFICULTAD_FACIL
	if node_data.has_explicit_games():
		var dificultad_definida: int = int(node_data.difficulty)
		if dificultad_definida > 0:
			return _limitar_dificultad(dificultad_definida)
	var patron: Array[int] = _obtener_patron_dificultad_para_nodo(node_data.index)
	if patron.is_empty():
		return DIFICULTAD_FACIL
	return patron[0]


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
	if node_data == null:
		return DIFICULTAD_FACIL
	var patron: Array[int] = _obtener_patron_dificultad_para_nodo(node_data.index)
	if patron.is_empty():
		return DIFICULTAD_FACIL
	var indice_seguro: int = clampi(indice_juego, 0, patron.size() - 1)
	return patron[indice_seguro]


static func _crear_juego(
	node_data: MapNodeData,
	dificultad_objetivo: int
) -> Dictionary:
	return {
		"mode": _normalizar_modo(node_data.mode),
		"json_path": node_data.json_path,
		"activity_id": node_data.activity_id,
		"pack_id": node_data.pack_id if not node_data.pack_id.is_empty() else node_data.track_key,
		"titulo": node_data.title,
		"dificultad": _limitar_dificultad(dificultad_objetivo),
		"difficulty": _limitar_dificultad(dificultad_objetivo),
		"clave_nodo_de_origen": node_data.node_key,
	}


static func _crear_juego_manual(datos_juego: Dictionary, dificultad: int) -> Dictionary:
	var ruta_json: String = str(datos_juego.get("json_path", "")).strip_edges()
	if not ruta_json.is_empty() and not FileAccess.file_exists(ruta_json):
		push_warning("ArmadorDePartida: no existe el contenido de partida: %s" % ruta_json)
	var modo: String = _normalizar_modo(str(datos_juego.get("mode", "")))
	return {
		"mode": modo,
		"tipo": modo,
		"json_path": ruta_json,
		"archivo": ruta_json,
		"activity_id": str(datos_juego.get("activity_id", "")).strip_edges(),
		"pack_id": str(datos_juego.get("pack_id", "")).strip_edges(),
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
	dificultades_objetivo: Array[int]
) -> Array[String]:
	var modos_disponibles: Array[String] = []
	modos_disponibles.append(modo_inicial)

	for modo in MODOS_SOPORTADOS:
		var modo_limpio: String = str(modo).strip_edges()
		if modo_limpio == modo_inicial:
			continue
		if (
			modo_limpio == DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS
			and not _puede_usar_vinculacion(node_data, dificultades_objetivo)
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


static func _preparar_game_entries_para_plan(node_data: MapNodeData) -> Array[Dictionary]:
	# Shuffle trabaja sobre copias; node_data.games y el JSON original quedan intactos.
	var game_entries: Array[Dictionary] = []
	for raw_game in node_data.game_entries:
		if raw_game is Dictionary:
			game_entries.append((raw_game as Dictionary).duplicate(true))
	var original_ids: Array[String] = _ids_de_game_entries(game_entries)
	var apply_shuffle: bool = node_data.shuffle_games and game_entries.size() > 1
	if apply_shuffle:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_mezclar_game_entries(game_entries, rng)
	var final_ids: Array[String] = _ids_de_game_entries(game_entries)
	print(
		"[RunPlan] node=%s shuffle=%s original=%s final=%s"
		% [
			node_data.node_key,
			str(apply_shuffle),
			_unir_strings(original_ids),
			_unir_strings(final_ids),
		]
	)
	return game_entries


static func _mezclar_game_entries(
	game_entries: Array[Dictionary],
	rng: RandomNumberGenerator
) -> void:
	for indice in range(game_entries.size() - 1, 0, -1):
		var indice_aleatorio: int = rng.randi_range(0, indice)
		var valor_temporal: Dictionary = game_entries[indice]
		game_entries[indice] = game_entries[indice_aleatorio]
		game_entries[indice_aleatorio] = valor_temporal


static func _ids_de_game_entries(game_entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for game_entry in game_entries:
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			activity_id = str(game_entry.get("id", game_entry.get("json_path", ""))).strip_edges()
		ids.append(activity_id)
	return ids


static func _unir_strings(valores: Array[String]) -> String:
	var partes := PackedStringArray()
	for valor in valores:
		partes.append(valor)
	return ",".join(partes)


static func _resolve_pack_id_for_game_entry(
	game_entry: Dictionary,
	node_data: MapNodeData
) -> String:
	var pack_id: String = str(game_entry.get("pack_id", "")).strip_edges()
	if not pack_id.is_empty():
		return pack_id
	if node_data != null:
		return node_data.get_effective_pack_id()
	return "celiaquia"


static func _normalizar_modo(mode: String) -> String:
	var modo_limpio: String = mode.strip_edges()
	if _es_modo_soportado(modo_limpio):
		return modo_limpio
	return ""


static func _es_modo_soportado(mode: String) -> bool:
	return MODOS_SOPORTADOS.has(mode.strip_edges())


static func _puede_usar_vinculacion(
	node_data: MapNodeData,
	dificultades_objetivo: Array[int]
) -> bool:
	if node_data == null:
		return false
	if _normalizar_modo(node_data.mode) == DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS:
		return true
	if _obtener_maxima_dificultad_objetivo(dificultades_objetivo) >= DIFICULTAD_DIFICIL:
		return true
	return node_data.index >= 10


static func _filtrar_candidatos_por_dificultad(
	candidatos_crudos: Array,
	dificultad_objetivo: int
) -> Array[MapNodeData]:
	var coincidencias_exactas: Array[MapNodeData] = []
	var coincidencias_cercanas: Array[MapNodeData] = []
	var mejor_distancia: int = 999

	for candidato_crudo in candidatos_crudos:
		var candidato: MapNodeData = candidato_crudo as MapNodeData
		if candidato == null:
			continue
		var dificultad_candidato: int = _resolver_dificultad_de_nodo(candidato)
		if dificultad_candidato <= 0:
			continue
		if dificultad_candidato == dificultad_objetivo:
			coincidencias_exactas.append(candidato)
			continue
		var distancia: int = absi(dificultad_candidato - dificultad_objetivo)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			coincidencias_cercanas = [candidato]
		elif distancia == mejor_distancia:
			coincidencias_cercanas.append(candidato)

	if not coincidencias_exactas.is_empty():
		return coincidencias_exactas
	return coincidencias_cercanas


static func _resolver_dificultad_de_nodo(node_data: MapNodeData) -> int:
	if node_data == null:
		return 0
	var dificultad_definida: int = int(node_data.difficulty)
	if dificultad_definida > 0:
		return _limitar_dificultad(dificultad_definida)
	return _inferir_dificultad_desde_json_path(node_data.json_path)


static func _inferir_dificultad_desde_json_path(json_path: String) -> int:
	var ruta_limpia: String = json_path.strip_edges()
	if ruta_limpia.is_empty():
		return 0
	if _cache_dificultad_por_ruta.has(ruta_limpia):
		return int(_cache_dificultad_por_ruta.get(ruta_limpia, 0))

	var resultado_json: Dictionary = ContentJsonLoaderScript.load_json(ruta_limpia)
	if not bool(resultado_json.get("ok", false)):
		_cache_dificultad_por_ruta[ruta_limpia] = 0
		return 0

	var datos: Dictionary = resultado_json.get("data", {})
	var dificultad: int = _normalizar_dificultad_cruda(
		datos.get("difficulty", datos.get("dificultad", 0))
	)
	_cache_dificultad_por_ruta[ruta_limpia] = dificultad
	return dificultad


static func _normalizar_dificultad_cruda(raw_value: Variant) -> int:
	if raw_value is int or raw_value is float:
		return _limitar_dificultad(int(raw_value))

	var valor_texto: String = str(raw_value).strip_edges().to_lower()
	match valor_texto:
		"easy":
			return DIFICULTAD_FACIL
		"medium":
			return DIFICULTAD_MEDIA
		"hard":
			return DIFICULTAD_DIFICIL
		_:
			return _limitar_dificultad(int(valor_texto))


static func _obtener_patron_dificultad_para_nodo(node_index: int) -> Array[int]:
	var indice_seguro: int = maxi(0, node_index)
	if indice_seguro <= 0:
		return [DIFICULTAD_FACIL]

	var bloque: int = int(floor(float(indice_seguro - 1) / 2.0))
	match bloque:
		0:
			return [DIFICULTAD_FACIL, DIFICULTAD_FACIL]
		1:
			return [DIFICULTAD_FACIL, DIFICULTAD_MEDIA]
		2:
			return [DIFICULTAD_FACIL, DIFICULTAD_DIFICIL]
		3:
			return [DIFICULTAD_MEDIA, DIFICULTAD_DIFICIL]
		4:
			return [DIFICULTAD_MEDIA, DIFICULTAD_MEDIA]
		_:
			return [DIFICULTAD_DIFICIL, DIFICULTAD_DIFICIL]


static func _obtener_maxima_dificultad_objetivo(dificultades_objetivo: Array[int]) -> int:
	var maxima_dificultad: int = 0
	for dificultad in dificultades_objetivo:
		maxima_dificultad = maxi(maxima_dificultad, int(dificultad))
	return maxima_dificultad
