# Construye el plan de juegos (lista ordenada de actividades) para un nodo.
extends RefCounted
class_name ArmadorDePartida

const CatalogoDePistas := preload("res://niveles/GameTrackCatalog.gd")
const CargadorMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const ContentSchemaNormalizerScript := preload(
	"res://sistemas/contenido/ContentSchemaNormalizer.gd"
)
const DatosNodoMapaScript := preload("res://mapas/core/MapNodeData.gd")

const JUEGOS_POR_PARTIDA_DE_NODO := 5
const MAXIMA_DIFICULTAD_POR_JUEGO := 5
const MODOS_SOPORTADOS := [
	DatosNodoMapaScript.MODE_DRAG_DROP,
	DatosNodoMapaScript.MODE_QUIZ_CHOICE,
	DatosNodoMapaScript.MODE_VINCULACION_CONCEPTOS,
	DatosNodoMapaScript.MODE_COMPLETAR_PALABRA,
]
const RUTA_MAPA_POR_PISTA := {
	CatalogoDePistas.TRACK_CELIAQUIA: "res://contenido/mapa/celiaquia_mapa.json",
}
const LOG_PREFIX := "[RunPlan]"
const DIFICULTAD_FACIL := 1
const DIFICULTAD_MEDIA := 3
const DIFICULTAD_DIFICIL := 5
const OBJECTIVE_FIELDS := [
	"objective_label",
	"objective_message",
	"objective_main",
	"objective_sub",
	"objective_action",
	"objective_meal",
	"objective_connector",
	"objective_restriction",
	"objective",
	"meal",
]

static var _cache_dificultad_por_ruta: Dictionary = {}
static var _last_random_combo_by_node_key: Dictionary = {}
static var _session_used_activity_ids_by_request: Dictionary = {}
const SESSION_HISTORY_MAX_PER_REQUEST: int = 6

static var _save_manager_ref: Node = null


static func inicializar_con_save_manager(sm: Node) -> void:
	_save_manager_ref = sm


static func reiniciar_historial_sesion() -> void:
	_session_used_activity_ids_by_request.clear()
	_last_random_combo_by_node_key.clear()


static func construir_plan_de_partida(node_data: MapNodeData) -> Dictionary:
	if node_data == null or not node_data.es_valido():
		print(LOG_PREFIX, " nodo invalido o sin contenido")
		return {}

	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var final_games: Array[Dictionary] = []
	if node_data.tiene_juegos_fijos():
		final_games = construir_juegos_fijos(node_data)
		if final_games.is_empty():
			push_warning(
				"ArmadorDePartida: juegos explicitos invalidos en %s. Se usa legacy."
				% node_data.node_key
			)
	elif node_data.usa_juegos_random():
		final_games = construir_juegos_random(node_data)
		if final_games.is_empty():
			push_warning(
				"ArmadorDePartida: games random sin candidatos validos en %s."
				% node_data.node_key
			)
	if final_games.is_empty() and not node_data.usa_juegos_random():
		var total_juegos: int = obtener_cantidad_de_juegos_para_nodo(node_data.index)
		final_games = construir_juegos_para_nodo(node_data, total_juegos)
	if final_games.is_empty():
		push_error(
			"ArmadorDePartida: no se pudo armar ningun juego para el nodo %s."
			% node_data.node_key
		)
		print(LOG_PREFIX, " nodo=", node_data.node_key, " juegos=0 usa_v1=false")
		return {}
	final_games = _filter_final_games_by_history(node_data.node_key, final_games)
	if final_games.is_empty():
		print("[ArmadorDePartida] pool_exhausted node_key=%s reason=all_used" % node_data.node_key)
		return {}
	if not _validar_final_game_ids(node_data.node_key, final_games):
		print("[ArmadorDePartida] pool_exhausted node_key=%s reason=invalid_plan_ids" % node_data.node_key)
		return {}
	print(
		"[RunPlan] node=%s final=%s"
		% [node_data.node_key, _unir_strings(_extract_final_game_ids(final_games))]
	)

	return {
		"clave_nodo": node_data.node_key,
		"titulo_nodo": node_data.title,
		"clave_pista": node_data.track_key,
		"dificultad": dificultad_base,
		"numero_nivel": node_data.index + 1,
		"indice_juego_actual": 0,
		"total_juegos": final_games.size(),
		"juegos": final_games,
	}


static func obtener_cantidad_de_juegos_para_nodo(node_index: int) -> int:
	return _obtener_patron_dificultad_para_nodo(node_index).size()


static func construir_juegos_fijos(node_data: MapNodeData) -> Array[Dictionary]:
	# Si games es fijo, usa exactamente esos activity_id.
	var final_games: Array[Dictionary] = []
	var dificultad_base: int = obtener_dificultad_base_del_nodo(node_data)
	var fixed_game_entries: Array[Dictionary] = _prepare_fixed_game_entries(node_data)
	for raw_fixed_game in fixed_game_entries:
		var fixed_game_entry: Dictionary = raw_fixed_game as Dictionary
		var pack_id: String = _resolve_pack_id_for_fixed_game(fixed_game_entry, node_data)
		var activity_id: String = str(fixed_game_entry.get("activity_id", "")).strip_edges()
		var mode: String = str(
			fixed_game_entry.get("mode", fixed_game_entry.get("tipo", ""))
		).strip_edges()
		if mode.is_empty():
			mode = NodeContentLoaderScript.to_runtime_mode(
				str(fixed_game_entry.get("type", "")).strip_edges()
			)
		var datos_juego: Dictionary = {
			"type": str(fixed_game_entry.get("type", "")).strip_edges(),
			"mode": mode,
			"json_path": str(
				fixed_game_entry.get("archivo", fixed_game_entry.get("json_path", ""))
			).strip_edges(),
			"activity_id": activity_id,
			"pack_id": pack_id,
			"titulo": str(
				fixed_game_entry.get("titulo", fixed_game_entry.get("title", node_data.title))
			).strip_edges(),
			"clave_nodo_de_origen": node_data.node_key,
			"track_key": node_data.track_key,
		}
		_copiar_campos_objetivo(fixed_game_entry, datos_juego)
		var dificultad_juego: int = int(
			fixed_game_entry.get(
				"difficulty",
				fixed_game_entry.get("dificultad", dificultad_base)
			)
		)
		if dificultad_juego <= 0:
			dificultad_juego = dificultad_base
		var juego: Dictionary = _crear_juego_manual(datos_juego, dificultad_juego)
		if str(juego.get("mode", "")).strip_edges().is_empty():
			print(LOG_PREFIX, " juego explicito ignorado por mode invalido: ", fixed_game_entry)
			continue
		if (
			str(juego.get("json_path", "")).strip_edges().is_empty()
			and str(juego.get("activity_id", "")).strip_edges().is_empty()
		):
			print(LOG_PREFIX, " juego explicito ignorado por json_path vacio: ", fixed_game_entry)
			continue
		_copiar_allow_repeated_type(fixed_game_entry, juego)
		final_games.append(juego)
	return final_games


static func construir_juegos_random(node_data: MapNodeData) -> Array[Dictionary]:
	var final_games: Array[Dictionary] = []
	if node_data == null or not node_data.tiene_solicitudes_juegos_random():
		return final_games
	var pack_id: String = node_data.obtener_pack_id_efectivo()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var previous_combo: Array[String] = _leer_last_random_combo(node_data.node_key)
	var selected_game_entries: Array[Dictionary] = []
	var selected_combo: Array[String] = []
	for attempt in range(2):
		selected_game_entries = _select_random_game_entries(node_data, pack_id, rng)
		if selected_game_entries.is_empty():
			break
		selected_combo = _normalizar_activity_combo(
			_extract_activity_ids_from_game_entries(selected_game_entries)
		)
		if attempt == 0 and _activity_combos_match(selected_combo, previous_combo):
			print(
				"[RunRequestWarning] node=%s repeated_combo=%s retry=1"
				% [node_data.node_key, _unir_strings(selected_combo)]
			)
			continue
		break
	if selected_game_entries.is_empty():
		return final_games
	if _activity_combos_match(selected_combo, previous_combo) and not previous_combo.is_empty():
		push_warning(
			"ArmadorDePartida: combo random repetido en %s; se reutiliza por falta de alternativas."
			% node_data.node_key
		)
	_store_last_random_combo(node_data.node_key, selected_combo)
	var final_game_entries: Array[Dictionary] = _build_final_game_entries(
		node_data.node_key,
		node_data.shuffle_games,
		selected_game_entries
	)
	for game_entry in final_game_entries:
		var datos_juego: Dictionary = {
			"type": str(game_entry.get("type", "")).strip_edges(),
			"mode": str(game_entry.get("mode", "")).strip_edges(),
			"json_path": str(game_entry.get("json_path", "")).strip_edges(),
			"activity_id": str(game_entry.get("activity_id", "")).strip_edges(),
			"pack_id": str(game_entry.get("pack_id", pack_id)).strip_edges(),
			"titulo": str(game_entry.get("titulo", node_data.title)).strip_edges(),
			"clave_nodo_de_origen": node_data.node_key,
			"track_key": node_data.track_key,
		}
		_copiar_campos_objetivo(game_entry, datos_juego)
		var dificultad_juego: int = int(
			game_entry.get("difficulty", game_entry.get("dificultad", DIFICULTAD_FACIL))
		)
		var juego: Dictionary = _crear_juego_manual(datos_juego, dificultad_juego)
		if str(juego.get("mode", "")).strip_edges().is_empty():
			continue
		juego["request_key"] = str(game_entry.get("request_key", "")).strip_edges()
		_copiar_allow_repeated_type(game_entry, juego)
		final_games.append(juego)
	return final_games


static func _select_random_game_entries(
	node_data: MapNodeData,
	pack_id: String,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var selected_game_entries: Array[Dictionary] = []
	var used_types_in_node: Array[String] = []
	# Pre-calcular cuántas veces aparece cada tipo en el nodo.
	# Si un tipo se solicita más de una vez, es intencional (ej: 3 drags seguidos)
	# y se debe respetar sin filtrar por variedad.
	var type_request_counts: Dictionary = {}
	for raw_req in node_data.obtener_solicitudes_juegos_random():
		if not raw_req is Dictionary:
			continue
		var req_type: String = NodeContentLoaderScript.normalizar_random_game_type(
			str((raw_req as Dictionary).get("type", "")).strip_edges()
		)
		if not req_type.is_empty():
			type_request_counts[req_type] = int(type_request_counts.get(req_type, 0)) + 1
	for raw_request in node_data.obtener_solicitudes_juegos_random():
		if not raw_request is Dictionary:
			continue
		var game_request: Dictionary = raw_request as Dictionary
		var requested_type: String = NodeContentLoaderScript.normalizar_random_game_type(
			str(game_request.get("type", "")).strip_edges()
		)
		var requested_difficulty: int = int(game_request.get("difficulty", 0))
		var requested_options_count: int = _leer_requested_options_count(
			game_request,
			requested_type
		)
		if requested_type.is_empty() or requested_difficulty <= 0:
			push_warning(
				"ArmadorDePartida: game random invalido en %s: %s"
				% [node_data.node_key, str(game_request)]
			)
			continue
		# Permitir tipo repetido si: el JSON lo indica explícitamente, o si el nodo
		# solicita ese tipo más de una vez (repetición intencional del diseñador).
		var allow_repeated_type: bool = (
			bool(game_request.get("allow_repeated_type", false))
			or int(type_request_counts.get(requested_type, 1)) > 1
		)
		if not allow_repeated_type and used_types_in_node.has(requested_type):
			print(
				"[ArmadorDePartida] tipo '%s' ya usado en nodo %s, omitido para variedad."
				% [requested_type, node_data.node_key]
			)
			continue
		var used_activity_ids: Array[String] = _extract_activity_ids_from_game_entries(
			selected_game_entries
		)
		var request_key: String = "%s|%d|%d" % [
			requested_type,
			requested_difficulty,
			requested_options_count,
		]
		var used_history_ids: Array[String] = _leer_used_activity_ids(request_key)
		var candidates_result: Dictionary = _resolve_candidates_with_fallback(
			pack_id,
			requested_type,
			requested_difficulty,
			requested_options_count,
			used_activity_ids,
			used_history_ids
		)
		var available_activity_candidates: Array[String] = candidates_result.get("candidates", [])
		var fallback_reason: String = str(candidates_result.get("fallback_reason", ""))
		print(
			"[ArmadorDePartida] total_candidates=%d request=%s used_ids_count=%d available_after_filter=%d"
			% [
				int(candidates_result.get("total_candidates", 0)),
				request_key,
				used_history_ids.size(),
				available_activity_candidates.size(),
			]
		)
		var session_used_ids: Array[String] = _leer_session_used_ids(request_key)
		var candidates_avoiding_session: Array[String] = _filter_out_session_used(
			available_activity_candidates,
			session_used_ids
		)
		var session_avoid_applied: bool = false
		if not candidates_avoiding_session.is_empty():
			if candidates_avoiding_session.size() != available_activity_candidates.size():
				session_avoid_applied = true
				print(
					"[RandomAvoidRepeat] request=%s cand=%d avail=%d prev=%s"
					% [
						request_key,
						available_activity_candidates.size(),
						candidates_avoiding_session.size(),
						_unir_strings(session_used_ids),
					]
				)
			available_activity_candidates = candidates_avoiding_session
		elif not session_used_ids.is_empty() and not available_activity_candidates.is_empty():
			print(
				"[RandomAvoidRepeat] no_alternative=true request=%s cand=%d prev=%s"
				% [
					request_key,
					available_activity_candidates.size(),
					_unir_strings(session_used_ids),
				]
			)
		var selected_activity_id: String = _pick_random_activity_id(
			available_activity_candidates,
			rng
		)
		if selected_activity_id.is_empty():
			print("[ArmadorDePartida] pool_exhausted node_key=%s request=%s" % [
				node_data.node_key,
				request_key,
			])
		elif used_history_ids.has(selected_activity_id):
			push_error(
				"[ArmadorDePartida] selected_activity_id ya usado: %s" % selected_activity_id
			)
			selected_activity_id = ""
		if not selected_activity_id.is_empty():
			_register_session_used_id(request_key, selected_activity_id)
			if session_avoid_applied:
				print(
					"[RandomAvoidRepeat] selected=%s request=%s"
					% [selected_activity_id, request_key]
				)
		var selected_game_entry: Dictionary = {}
		if not selected_activity_id.is_empty():
			selected_game_entry = _build_random_game_entry(
				node_data,
				pack_id,
				selected_activity_id,
				requested_difficulty
			)
			if not selected_game_entry.is_empty():
				selected_game_entry["type"] = requested_type
				selected_game_entry["request_key"] = request_key
				selected_game_entry["allow_repeated_type"] = allow_repeated_type
				_copiar_campos_objetivo(game_request, selected_game_entry)
				print(
					"[ArmadorDePartida] selected_activity_id=%s request=%s"
					% [selected_activity_id, request_key]
				)
		var candidate_summary: String = _unir_strings(available_activity_candidates)
		if not fallback_reason.is_empty() and not selected_game_entry.is_empty():
			if requested_options_count > 0:
				print(
					"[RunRequestWarning] type=%s difficulty=%d options=%d fallback=%s selected=%s"
					% [
						requested_type,
						requested_difficulty,
						requested_options_count,
						fallback_reason,
						selected_activity_id,
					]
				)
			else:
				print(
					"[RunRequestWarning] type=%s difficulty=%d fallback=%s selected=%s"
					% [
						requested_type,
						requested_difficulty,
						fallback_reason,
						selected_activity_id,
					]
				)
		else:
			if requested_options_count > 0:
				print(
					"[RunRequest] type=%s difficulty=%d options=%d candidates=%s selected=%s"
					% [
						requested_type,
						requested_difficulty,
						requested_options_count,
						candidate_summary if not candidate_summary.is_empty() else "-",
						selected_activity_id if not selected_activity_id.is_empty() else "-",
					]
				)
			else:
				print(
					"[RunRequest] type=%s difficulty=%d candidates=%s selected=%s"
					% [
						requested_type,
						requested_difficulty,
						candidate_summary if not candidate_summary.is_empty() else "-",
						selected_activity_id if not selected_activity_id.is_empty() else "-",
					]
				)
		if selected_game_entry.is_empty():
			push_warning(
				"ArmadorDePartida: no se pudo resolver game random %s/%d en %s."
				% [requested_type, requested_difficulty, node_data.node_key]
			)
			continue
		selected_game_entries.append(selected_game_entry)
		var tipo_seleccionado: String = str(selected_game_entry.get("type", "")).strip_edges()
		if not tipo_seleccionado.is_empty() and not used_types_in_node.has(tipo_seleccionado):
			used_types_in_node.append(tipo_seleccionado)
	return selected_game_entries


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

	var resultado: Dictionary = CargadorMapaScript.cargar_mapa(ruta_mapa)
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
	if node_data.tiene_juegos_fijos():
		var dificultad_definida: int = int(node_data.difficulty)
		if dificultad_definida > 0:
			return _limitar_dificultad(dificultad_definida)
	var patron: Array[int] = _obtener_patron_dificultad_para_nodo(node_data.index)
	if patron.is_empty():
		return DIFICULTAD_FACIL
	return patron[0]



static func _crear_juego(
	node_data: MapNodeData,
	dificultad_objetivo: int
) -> Dictionary:
	var modo: String = _normalizar_modo(node_data.mode)
	var juego: Dictionary = {
		"mode": modo,
		"type": "drag" if modo == DatosNodoMapaScript.MODE_DRAG_DROP else "",
		"json_path": node_data.json_path,
		"activity_id": node_data.activity_id,
		"pack_id": node_data.obtener_pack_id_efectivo(),
		"titulo": node_data.title,
		"dificultad": _limitar_dificultad(dificultad_objetivo),
		"difficulty": _limitar_dificultad(dificultad_objetivo),
		"clave_nodo_de_origen": node_data.node_key,
		"track_key": node_data.track_key,
	}
	_normalizar_objetivo_de_arrastre(juego)
	return juego


static func _crear_juego_manual(datos_juego: Dictionary, dificultad: int) -> Dictionary:
	var ruta_json: String = str(datos_juego.get("json_path", "")).strip_edges()
	if not ruta_json.is_empty() and not FileAccess.file_exists(ruta_json):
		push_warning("ArmadorDePartida: no existe el contenido de partida: %s" % ruta_json)
	var modo: String = _normalizar_modo(str(datos_juego.get("mode", "")))
	var juego: Dictionary = {
		"type": str(datos_juego.get("type", "")).strip_edges(),
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
		"track_key": str(datos_juego.get("track_key", "")).strip_edges(),
	}
	_copiar_campos_objetivo(datos_juego, juego)
	_normalizar_objetivo_de_arrastre(juego)
	return juego


static func _copiar_campos_objetivo(origen: Dictionary, destino: Dictionary) -> void:
	for campo in OBJECTIVE_FIELDS:
		if origen.has(campo) and origen.get(campo) != null:
			destino[campo] = origen.get(campo)


static func _copiar_allow_repeated_type(origen: Dictionary, destino: Dictionary) -> void:
	if origen.has("allow_repeated_type"):
		destino["allow_repeated_type"] = bool(origen.get("allow_repeated_type", false))


static func _normalizar_objetivo_de_arrastre(juego: Dictionary) -> void:
	var game_type: String = str(juego.get("type", "")).strip_edges()
	var game_mode: String = str(juego.get("mode", "")).strip_edges()
	if game_type != "drag" and game_mode != DatosNodoMapaScript.MODE_DRAG_DROP:
		return
	var track_key: String = str(juego.get("track_key", "")).strip_edges()
	var node_key: String = str(juego.get("clave_nodo_de_origen", "")).strip_edges()
	juego["objective"] = ContentSchemaNormalizerScript.normalizar_drag_objective(
		juego,
		track_key,
		node_key
	)



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


static func _prepare_fixed_game_entries(node_data: MapNodeData) -> Array[Dictionary]:
	# Shuffle trabaja sobre copias; el JSON original queda intacto.
	return _build_final_game_entries(
		node_data.node_key,
		node_data.shuffle_games,
		node_data.obtener_juegos_fijos()
	)


static func _build_final_game_entries(
	_node_key: String,
	shuffle_games: bool,
	raw_games: Array[Dictionary]
) -> Array[Dictionary]:
	var final_game_entries: Array[Dictionary] = []
	for raw_game in raw_games:
		if raw_game is Dictionary:
			final_game_entries.append((raw_game as Dictionary).duplicate(true))
	var apply_shuffle: bool = shuffle_games and final_game_entries.size() > 1
	if apply_shuffle:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_mezclar_game_entries(final_game_entries, rng)
	return final_game_entries


static func _filter_activity_candidates(
	activity_candidates: Array[String],
	used_activity_ids: Array[String]
) -> Array[String]:
	var filtered_candidates: Array[String] = []
	for candidate_id in activity_candidates:
		if not used_activity_ids.has(candidate_id):
			filtered_candidates.append(candidate_id)
	return filtered_candidates


static func _filtrar_por_modalidades_del_nodo(
	candidatas: Array[String],
	used_types_in_node: Array[String],
	tipo_actual: String
) -> Array[String]:
	## Si el tipo ya fue usado en el nodo, devuelve vacío.
	## Devuelve candidatas sin cambios si el tipo aún no está en used_types_in_node.
	if used_types_in_node.has(tipo_actual):
		return []
	return candidatas


static func _filter_unavailable_activity_candidates(
	activity_candidates: Array[String],
	used_activity_ids: Array[String],
	used_history_ids: Array[String]
) -> Array[String]:
	var candidates_without_used: Array[String] = _filter_activity_candidates(
		activity_candidates,
		used_activity_ids
	)
	if used_history_ids.is_empty():
		return candidates_without_used
	var filtered: Array[String] = []
	for candidate_id in candidates_without_used:
		if used_history_ids.has(candidate_id):
			print("[ContentFilter] skip_used activity_id=%s" % candidate_id)
			continue
		filtered.append(candidate_id)
	return filtered


# Resuelve candidatos para un game request con cadena de fallbacks:
#   1. Exacto (tipo + dificultad + options_count)
#   2. Sin options_count           (solo si options_count > 0)
#   3. Dificultad cercana con options_count  (solo si options_count > 0)
#   4. Dificultad cercana sin options_count  (siempre, si sigue vacío)
# Devuelve {"candidates": Array[String], "fallback_reason": String}.
static func _resolve_candidates_with_fallback(
	pack_id: String,
	requested_type: String,
	requested_difficulty: int,
	requested_options_count: int,
	used_activity_ids: Array[String],
	used_history_ids: Array[String]
) -> Dictionary:
	var total_candidates: int = 0
	var raw_candidates: Array[String] = NodeContentLoaderScript.obtener_candidatos_actividad(
		pack_id, requested_type, requested_difficulty, requested_options_count
	)
	total_candidates += raw_candidates.size()
	var candidates: Array[String] = _filter_unavailable_activity_candidates(
		raw_candidates,
		used_activity_ids,
		used_history_ids
	)
	if not candidates.is_empty():
		return {"candidates": candidates, "fallback_reason": "", "total_candidates": total_candidates}
	if requested_options_count > 0:
		raw_candidates = NodeContentLoaderScript.obtener_candidatos_actividad(
			pack_id, requested_type, requested_difficulty
		)
		total_candidates += raw_candidates.size()
		candidates = _filter_unavailable_activity_candidates(
			raw_candidates,
			used_activity_ids,
			used_history_ids
		)
		if not candidates.is_empty():
			return {
				"candidates": candidates,
				"fallback_reason": "without_options_count",
				"total_candidates": total_candidates,
			}
		raw_candidates = NodeContentLoaderScript.obtener_candidatos_actividad_near(
			pack_id, requested_type, requested_difficulty, requested_options_count
		)
		total_candidates += raw_candidates.size()
		candidates = _filter_unavailable_activity_candidates(
			raw_candidates,
			used_activity_ids,
			used_history_ids
		)
		if not candidates.is_empty():
			return {
				"candidates": candidates,
				"fallback_reason": "near_difficulty_with_options_count",
				"total_candidates": total_candidates,
			}
	raw_candidates = NodeContentLoaderScript.obtener_candidatos_actividad_near(
		pack_id, requested_type, requested_difficulty
	)
	total_candidates += raw_candidates.size()
	candidates = _filter_unavailable_activity_candidates(
		raw_candidates,
		used_activity_ids,
		used_history_ids
	)
	var reason: String = ""
	if not candidates.is_empty():
		reason = (
			"near_difficulty_without_options_count"
			if requested_options_count > 0
			else "near_difficulty"
		)
	return {"candidates": candidates, "fallback_reason": reason, "total_candidates": total_candidates}


static func _filter_out_session_used(
	activity_candidates: Array[String],
	session_used_ids: Array[String]
) -> Array[String]:
	if session_used_ids.is_empty():
		return activity_candidates
	var filtered: Array[String] = []
	for candidate_id in activity_candidates:
		if not session_used_ids.has(candidate_id):
			filtered.append(candidate_id)
	return filtered


static func _leer_used_activity_ids(request_key: String) -> Array[String]:
	var used_ids: Array[String] = []
	if _save_manager_ref == null:
		return used_ids
	if _save_manager_ref.has_method("obtener_todos_ids_actividades_usadas"):
		return _merge_activity_ids(
			used_ids,
			_save_manager_ref.call("obtener_todos_ids_actividades_usadas")
		)
	if _save_manager_ref.has_method("obtener_ids_actividades_jugadas"):
		used_ids = _merge_activity_ids(
			used_ids,
			_save_manager_ref.call("obtener_ids_actividades_jugadas")
		)
	if _save_manager_ref.has_method("obtener_todos_ids_actividades_completadas"):
		used_ids = _merge_activity_ids(
			used_ids,
			_save_manager_ref.call("obtener_todos_ids_actividades_completadas")
		)
	if _save_manager_ref.has_method("obtener_ids_actividades_completadas"):
		used_ids = _merge_activity_ids(
			used_ids,
			_save_manager_ref.call("obtener_ids_actividades_completadas", request_key)
		)
	return used_ids


static func _merge_activity_ids(current_ids: Array[String], raw_ids: Variant) -> Array[String]:
	var result: Array[String] = current_ids.duplicate()
	if not raw_ids is Array:
		return result
	for raw_id in (raw_ids as Array):
		var activity_id: String = str(raw_id).strip_edges()
		if activity_id.is_empty() or result.has(activity_id):
			continue
		result.append(activity_id)
	return result


static func _leer_session_used_ids(request_key: String) -> Array[String]:
	var stored: Variant = _session_used_activity_ids_by_request.get(request_key, [])
	if not stored is Array:
		return []
	var result: Array[String] = []
	for entry in (stored as Array):
		result.append(str(entry))
	return result


static func _register_session_used_id(request_key: String, activity_id: String) -> void:
	if activity_id.is_empty():
		return
	var history: Array[String] = _leer_session_used_ids(request_key)
	history.erase(activity_id)
	history.append(activity_id)
	while history.size() > SESSION_HISTORY_MAX_PER_REQUEST:
		history.pop_front()
	_session_used_activity_ids_by_request[request_key] = history


static func _pick_random_activity_id(
	candidate_ids: Array[String],
	rng: RandomNumberGenerator
) -> String:
	if candidate_ids.is_empty():
		return ""
	return candidate_ids[rng.randi_range(0, candidate_ids.size() - 1)]


static func _filter_out_persistent_completed(
	activity_candidates: Array[String],
	completed_ids: Array[String]
) -> Array[String]:
	if completed_ids.is_empty():
		return activity_candidates
	var filtered: Array[String] = []
	for candidate_id in activity_candidates:
		if not completed_ids.has(candidate_id):
			filtered.append(candidate_id)
	return filtered


static func _leer_requested_options_count(
	game_request: Dictionary,
	requested_type: String
) -> int:
	if requested_type != "quiz":
		return 0
	return maxi(0, int(game_request.get("options_count", 0)))


static func _leer_last_random_combo(node_key: String) -> Array[String]:
	var stored_combo: Variant = _last_random_combo_by_node_key.get(node_key, [])
	if not stored_combo is Array:
		return []
	return _normalizar_activity_combo(stored_combo as Array)


static func _store_last_random_combo(node_key: String, activity_ids: Array[String]) -> void:
	if node_key.strip_edges().is_empty() or activity_ids.is_empty():
		return
	_last_random_combo_by_node_key[node_key] = _normalizar_activity_combo(activity_ids)


static func _normalizar_activity_combo(raw_activity_ids: Array) -> Array[String]:
	var normalizado_ids: Array[String] = []
	for raw_activity_id in raw_activity_ids:
		var activity_id: String = str(raw_activity_id).strip_edges()
		if activity_id.is_empty():
			continue
		normalizado_ids.append(activity_id)
	normalizado_ids.sort()
	return normalizado_ids


static func _activity_combos_match(
	left_combo: Array[String],
	right_combo: Array[String]
) -> bool:
	if left_combo.size() != right_combo.size():
		return false
	for index in range(left_combo.size()):
		if left_combo[index] != right_combo[index]:
			return false
	return not left_combo.is_empty()


static func _build_random_game_entry(
	node_data: MapNodeData,
	pack_id: String,
	selected_activity_id: String,
	requested_difficulty: int
) -> Dictionary:
	var activity_result: Dictionary = NodeContentLoaderScript.cargar_actividad(
		pack_id,
		selected_activity_id
	)
	if not bool(activity_result.get("ok", false)):
		return {}
	var activity_data: Dictionary = activity_result.get("data", {})
	var mode: String = NodeContentLoaderScript.to_runtime_mode(
		str(activity_data.get("mode", "")).strip_edges()
	)
	if not _es_modo_soportado(mode):
		return {}
	var resolved_difficulty: int = int(
		activity_data.get("difficulty", activity_data.get("dificultad", requested_difficulty))
	)
	if resolved_difficulty <= 0:
		resolved_difficulty = requested_difficulty
	return {
		"mode": mode,
		"tipo": mode,
		"json_path": str(activity_data.get("json_path", "")).strip_edges(),
		"activity_id": selected_activity_id,
		"pack_id": pack_id,
		"titulo": node_data.title,
		"difficulty": _limitar_dificultad(resolved_difficulty),
		"dificultad": _limitar_dificultad(resolved_difficulty),
		"clave_nodo_de_origen": node_data.node_key,
	}


static func _mezclar_game_entries(
	game_entries: Array[Dictionary],
	rng: RandomNumberGenerator
) -> void:
	for indice in range(game_entries.size() - 1, 0, -1):
		var indice_aleatorio: int = rng.randi_range(0, indice)
		var valor_temporal: Dictionary = game_entries[indice]
		game_entries[indice] = game_entries[indice_aleatorio]
		game_entries[indice_aleatorio] = valor_temporal


static func _extract_activity_ids_from_game_entries(
	game_entries: Array[Dictionary]
) -> Array[String]:
	var ids: Array[String] = []
	for game_entry in game_entries:
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			activity_id = str(game_entry.get("id", game_entry.get("json_path", ""))).strip_edges()
		ids.append(activity_id)
	return ids


static func _extract_final_game_ids(final_games: Array[Dictionary]) -> Array[String]:
	var final_game_ids: Array[String] = []
	for final_game in final_games:
		final_game_ids.append(str(final_game.get("activity_id", "")).strip_edges())
	return final_game_ids


static func _validar_final_game_ids(node_key: String, final_games: Array[Dictionary]) -> bool:
	var seen_ids: Dictionary = {}
	var is_valid := true
	for game_index in range(final_games.size()):
		var game: Dictionary = final_games[game_index]
		var activity_id: String = str(game.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			push_error(
				"[ArmadorDePartida] Actividad sin id en node_key=%s index=%d. "
				% [node_key, game_index]
				+ "No se puede evitar repeticion."
			)
			is_valid = false
			continue
		if seen_ids.has(activity_id):
			push_error(
				"[ArmadorDePartida] activity_id repetido en plan node_key=%s activity_id=%s"
				% [node_key, activity_id]
			)
			is_valid = false
			continue
		seen_ids[activity_id] = true
	return is_valid


static func _validar_plan_sin_modalidades_repetidas(
	node_key: String,
	final_games: Array[Dictionary]
) -> bool:
	## Verifica que no haya dos juegos del mismo tipo en el plan,
	## salvo que un juego tenga allow_repeated_type = true.
	var tipos_vistos: Dictionary = {}
	for game in final_games:
		var game_type: String = str(game.get("type", game.get("mode", ""))).strip_edges()
		var permite_repetir: bool = bool(game.get("allow_repeated_type", false))
		if game_type.is_empty() or permite_repetir:
			continue
		if tipos_vistos.has(game_type):
			push_error(
				"[ArmadorDePartida] modalidad repetida en plan node_key=%s type=%s"
				% [node_key, game_type]
			)
			return false
		tipos_vistos[game_type] = true
	return true


static func _filter_final_games_by_history(
	node_key: String,
	final_games: Array[Dictionary]
) -> Array[Dictionary]:
	var used_history_ids: Array[String] = _leer_used_activity_ids("")
	if used_history_ids.is_empty():
		return final_games
	var available_games: Array[Dictionary] = []
	for game in final_games:
		var activity_id: String = str(game.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			available_games.append(game)
			continue
		if used_history_ids.has(activity_id):
			print("[ContentFilter] skip_used activity_id=%s node_key=%s" % [
				activity_id,
				node_key,
			])
			continue
		available_games.append(game)
	return available_games


static func _unir_strings(valores: Array[String]) -> String:
	var partes := PackedStringArray()
	for valor in valores:
		partes.append(valor)
	return ",".join(partes)


static func _resolve_pack_id_for_fixed_game(
	fixed_game_entry: Dictionary,
	node_data: MapNodeData
) -> String:
	# Cada game puede venir sin pack_id; en ese caso usa el track del nodo.
	var pack_id: String = str(fixed_game_entry.get("pack_id", "")).strip_edges()
	if not pack_id.is_empty():
		return pack_id
	if node_data != null:
		return node_data.obtener_pack_id_efectivo()
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

	var resultado_json: Dictionary = ContentJsonLoaderScript.cargar_json(ruta_limpia)
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
