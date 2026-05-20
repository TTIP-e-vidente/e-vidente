extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload("res://niveles/content/GameLevelContentCatalog.gd")
const GameStreakTracker := preload("res://niveles/progress/GameStreakTracker.gd")
const SaveRachaHelperScript := preload(
	"res://interface/save_local/progress/racha/SaveRachaHelper.gd"
)
const SaveCampanaHelperScript := preload(
	"res://interface/save_local/progress/campana/SaveCampanaHelper.gd"
)
const SaveEstadoHelperScript := preload(
	"res://interface/save_local/progress/estado/SaveEstadoHelper.gd"
)

const DEFAULT_PROGRESS_LABEL := "Tu progreso"
const STREAK_SYSTEM_KEY := "streak"
const LOG_PREFIX_PARTIDA_NODO := "[GLOBAL]"
# TODO post-demo: renombrar cuando una migracion de save permita eliminar question_progress.
const QUESTION_PROGRESS_SYSTEM_KEY := "question_progress"

var current_level: int = 1

var _level_content: RefCounted
var _streak_save_helper: RefCounted
var _campaign_save_helper: RefCounted
var _partial_state_save_helper: RefCounted
var _completed_levels_by_track: Dictionary = {}
var _partial_level_state_by_track: Dictionary = {}
var _streak_state: Dictionary = {}
var _extra_progress_system_states: Dictionary = {}
var _playable_node_progress_by_track: Dictionary = {}
var _active_playable_node: Dictionary = {}
var _partida_de_nodo_activa: Dictionary = {}
var _juego_de_nodo_actual: Dictionary = {}
var _nodo_a_continuar: String = ""
var _ultima_finalizacion: Dictionary = {}
var _inicio_nodo_msec: int = 0  # Timestamp para calcular tiempo transcurrido de partida
var _stats_nodo_actual: Dictionary = {}  # Acumulador de aciertos/errores/intentos del nodo
# GameSessionData activo; leido por ResultsFlow al finalizar.
var _game_session_data: Resource = null


func _init() -> void:
	_level_content = GameLevelContentCatalogScript.new()
	_streak_save_helper = SaveRachaHelperScript.new()
	_campaign_save_helper = SaveCampanaHelperScript.new()
	_partial_state_save_helper = SaveEstadoHelperScript.new()
	reiniciar_progreso()


# --- Nivel actual -----------------------------------------------------------

func obtener_actual_nivel_numero() -> int:
	return current_level


func establecer_actual_nivel_numero(level_number: int, track_key: String = "") -> void:
	var max_level: int = _level_content.obtener_maximo_pista_nivel_cantidad(
		GameTrackCatalog.DEFAULT_LEVEL_COUNT
	)
	var key: String = track_key.strip_edges()
	if not key.is_empty() and GameTrackCatalog.tiene_pista(key):
		max_level = obtener_pista_nivel_cantidad(key)
	current_level = 1 if max_level <= 0 else clampi(level_number, 1, max_level)


# --- Progreso de niveles ----------------------------------------------------

func reiniciar_progreso() -> void:
	current_level = 1
	_completed_levels_by_track = {}
	_partial_level_state_by_track = {}
	_streak_state = {}
	_extra_progress_system_states = {}

	_playable_node_progress_by_track = {}
	_active_playable_node = {}
	_partida_de_nodo_activa = {}
	_juego_de_nodo_actual = {}
	_nodo_a_continuar = ""
	_inicio_nodo_msec = 0
	_stats_nodo_actual = {}
	_game_session_data = null
	for track_key in GameTrackCatalog.TRACK_ORDER:
		_asegurar_pista_progreso_existe(track_key)
		_partial_level_state_by_track[track_key] = {}


# --- Sesión de juego activa (GameSessionData) --------------------------------
# Guardada al abrir un nodo; leída por ResultsFlow al mostrar resultados.

func establecer_sesion_de_juego(session_data: Resource) -> void:
	_game_session_data = session_data


func obtener_sesion_de_juego() -> Resource:
	return _game_session_data


func limpiar_sesion_de_juego() -> void:
	_game_session_data = null


func marcar_nivel_completado(track_key: String, level_number: int) -> void:
	var key := _obtener_clave_pista_valida(track_key)
	var level_index := _nivel_a_indice(key, level_number)
	if level_index < 0:
		return
	_asegurar_pista_progreso_existe(key)
	_completed_levels_by_track[key][level_index] = true


func es_nivel_desbloqueado(track_key: String, level_number: int) -> bool:
	var key := _obtener_clave_pista_valida(track_key)
	if key.is_empty():
		return level_number <= 1
	if level_number <= 1:
		return true
	return es_nivel_completado(key, level_number - 1)


func es_nivel_completado(track_key: String, level_number: int) -> bool:
	var key := _obtener_clave_pista_valida(track_key)
	var level_index := _nivel_a_indice(key, level_number)
	if level_index < 0:
		return false
	_asegurar_pista_progreso_existe(key)
	return _completed_levels_by_track[key][level_index]


func obtener_progreso_resumen() -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"max_total": _level_content.obtener_total_nivel_cantidad(
			GameTrackCatalog.obtener_total_nivel_cantidad()
		)
	}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var count: int = 0
		for level in range(1, obtener_pista_nivel_cantidad(track_key) + 1):
			if es_nivel_completado(track_key, level):
				count += 1
		summary[track_key] = count
		summary["total"] += count
	return summary


func formatear_progreso_resumen_texto(summary: Dictionary = {}) -> String:
	var by_track: Dictionary = summary if not summary.is_empty() else obtener_progreso_resumen()
	var lines: Array[String] = []
	for track_definition in GameTrackCatalog.obtener_definiciones_pista():
		var key: String = str(track_definition.get("key", "")).strip_edges()
		if key.is_empty():
			continue
		var level_count: int = obtener_pista_nivel_cantidad(key)
		if level_count <= 0:
			continue
		var completed: int = int(by_track.get(key, 0))
		var label: String = GameTrackCatalog.obtener_etiqueta_resumen_pista(
			key,
			GameTrackCatalog.obtener_etiqueta_pista(key, DEFAULT_PROGRESS_LABEL)
		)
		if label.is_empty():
			label = DEFAULT_PROGRESS_LABEL
		lines.append("%s %d/%d" % [label, min(level_count, completed + 1), level_count])
	return "\n".join(lines)


# --- Estado parcial de niveles ---------------------------------------------

func obtener_parcial_nivel_estado(track_key: String, level_number: int) -> Dictionary:
	var key := _obtener_clave_pista_valida(track_key)
	var level := _obtener_numero_nivel_valido(key, level_number)
	if level <= 0:
		return {}
	return _partial_level_state_by_track.get(key, {}).get(level, {})


func establecer_parcial_nivel_estado(
	track_key: String,
	level_number: int,
	state: Dictionary
) -> void:
	var key := _obtener_clave_pista_valida(track_key)
	var level := _obtener_numero_nivel_valido(key, level_number)
	if level <= 0:
		return
	if not _partial_level_state_by_track.has(key):
		_partial_level_state_by_track[key] = {}
	if es_nivel_completado(key, level) or state.is_empty():
		_partial_level_state_by_track[key].erase(level)
	else:
		_partial_level_state_by_track[key][level] = state


func limpiar_parcial_nivel_estado(track_key: String, level_number: int) -> void:
	var key := _obtener_clave_pista_valida(track_key)
	var level := _obtener_numero_nivel_valido(key, level_number)
	if level <= 0:
		return
	if _partial_level_state_by_track.has(key):
		_partial_level_state_by_track[key].erase(level)


# --- Progreso de nodos del mapa --------------------------------------------

func marcar_nodo_jugable_completado(track_key: String, node_key: String) -> void:
	var normalized_track_key: String = _obtener_clave_pista_valida(track_key)
	var normalized_node_key: String = node_key.strip_edges()
	if normalized_track_key.is_empty() or normalized_node_key.is_empty():
		return
	var progress_for_track: Dictionary = _playable_node_progress_by_track.get(
		normalized_track_key,
		{}
	)
	progress_for_track[normalized_node_key] = true
	_playable_node_progress_by_track[normalized_track_key] = progress_for_track


func es_nodo_jugable_completado(track_key: String, node_key: String) -> bool:
	var normalized_track_key: String = _obtener_clave_pista_valida(track_key)
	var normalized_node_key: String = node_key.strip_edges()
	if normalized_track_key.is_empty() or normalized_node_key.is_empty():
		return false
	var raw_track_progress: Variant = _playable_node_progress_by_track.get(normalized_track_key, {})
	if not raw_track_progress is Dictionary:
		return false
	return bool(raw_track_progress.get(normalized_node_key, false))


# --- Sesion activa de nodo jugable -----------------------------------------

func establecer_sesion_nodo_jugable_activo(session_state: Dictionary) -> void:
	_active_playable_node = session_state.duplicate(true)


func obtener_sesion_nodo_jugable_activo() -> Dictionary:
	return _active_playable_node.duplicate(true)


func limpiar_sesion_nodo_jugable_activo() -> void:
	_active_playable_node = {}


# --- Partida de nodo ------------------------------------------------------

func iniciar_partida_de_nodo(plan_de_partida: Dictionary) -> void:
	_partida_de_nodo_activa = _normalizar_partida_de_nodo(plan_de_partida)
	_juego_de_nodo_actual = _construir_juego_actual_de_partida(_partida_de_nodo_activa)
	_inicio_nodo_msec = Time.get_ticks_msec()
	_stats_nodo_actual = {"aciertos": 0, "errores": 0, "intentos": 0}
	print(
		LOG_PREFIX_PARTIDA_NODO,
		" iniciar_partida nodo=", str(_partida_de_nodo_activa.get("clave_nodo", "")),
		" total=", int(_partida_de_nodo_activa.get("total_juegos", 0)),
		" juego=", _juego_de_nodo_actual
	)


func obtener_partida_de_nodo_actual() -> Dictionary:
	return _partida_de_nodo_activa.duplicate(true)


func obtener_juego_actual_de_partida() -> Dictionary:
	return _juego_de_nodo_actual.duplicate(true)


func obtener_dificultad_del_juego_actual() -> int:
	if not _juego_de_nodo_actual.is_empty():
		return _obtener_dificultad_del_juego_actual(
			_juego_de_nodo_actual,
			_partida_de_nodo_activa
		)
	var sesion_activa: Dictionary = obtener_sesion_nodo_jugable_activo()
	return max(0, int(sesion_activa.get("difficulty", 0)))


func hay_siguiente_juego_de_partida() -> bool:
	if _partida_de_nodo_activa.is_empty():
		print("[AVANCE] Plan inválido: total=0.")
		return false
	var indice_juego_actual: int = int(_partida_de_nodo_activa.get("indice_juego_actual", 0))
	var total_juegos: int = int(_partida_de_nodo_activa.get("total_juegos", 0))
	if total_juegos <= 0:
		print("[AVANCE] Plan inválido: total=0.")
		return false
	var siguiente_indice: int = indice_juego_actual + 1
	var hay_siguiente: bool = indice_juego_actual + 1 < total_juegos
	print(
		"[AVANCE] indice_actual=",
		" indice_actual=", indice_juego_actual,
		" total=", total_juegos,
		" siguiente_indice=", siguiente_indice,
		" hay_siguiente=", hay_siguiente
	)
	return hay_siguiente


func avanzar_partida_de_nodo() -> void:
	if not hay_siguiente_juego_de_partida():
		return
	var partida_actualizada: Dictionary = _partida_de_nodo_activa.duplicate(true)
	partida_actualizada["indice_juego_actual"] = int(
		partida_actualizada.get("indice_juego_actual", 0)
	) + 1
	_partida_de_nodo_activa = partida_actualizada
	_juego_de_nodo_actual = _construir_juego_actual_de_partida(partida_actualizada)
	print(
		"[AVANCE] avanzar_partida indice_actual=",
		" avanzar_partida indice_actual=",
		int(_partida_de_nodo_activa.get("indice_juego_actual", 0)),
		" juego=",
		_juego_de_nodo_actual
	)


func finalizar_partida_de_nodo() -> void:
	if not _partida_de_nodo_activa.is_empty():
		print(
			LOG_PREFIX_PARTIDA_NODO,
			" finalizar_partida nodo=",
			str(_partida_de_nodo_activa.get("clave_nodo", ""))
		)
	_partida_de_nodo_activa = {}
	_juego_de_nodo_actual = {}
	_inicio_nodo_msec = 0
	_stats_nodo_actual = {}


func obtener_contexto_de_progreso_de_juego() -> Dictionary:
	if not _partida_de_nodo_activa.is_empty() and not _juego_de_nodo_actual.is_empty():
		return _construir_contexto_de_progreso_de_juego(
			str(_partida_de_nodo_activa.get("titulo_nodo", "")).strip_edges(),
			int(_partida_de_nodo_activa.get("indice_juego_actual", 0)) + 1,
			int(_partida_de_nodo_activa.get("total_juegos", 1)),
			int(_partida_de_nodo_activa.get("dificultad", 0)),
			_juego_de_nodo_actual,
			true
		)

	var sesion_activa: Dictionary = obtener_sesion_nodo_jugable_activo()
	return _construir_contexto_de_progreso_de_juego(
		str(sesion_activa.get("node_title", "")).strip_edges(),
		1,
		1,
		int(sesion_activa.get("difficulty", 0)),
		sesion_activa,
		false
	)


func _normalizar_partida_de_nodo(plan_de_partida: Dictionary) -> Dictionary:
	if plan_de_partida.is_empty():
		return {}
	var juegos: Array[Dictionary] = _duplicar_juegos_de_partida(plan_de_partida.get("juegos", []))
	if juegos.is_empty():
		print(LOG_PREFIX_PARTIDA_NODO, " plan invalido: juegos vacios")
		return {}
	var total_juegos: int = juegos.size()
	var indice_juego_actual: int = clampi(
		int(plan_de_partida.get("indice_juego_actual", 0)),
		0,
		juegos.size() - 1
	)
	return {
		"clave_nodo": str(plan_de_partida.get("clave_nodo", "")).strip_edges(),
		"titulo_nodo": str(plan_de_partida.get("titulo_nodo", "")).strip_edges(),
		"clave_pista": str(plan_de_partida.get("clave_pista", "")).strip_edges(),
		"escena_de_retorno": str(plan_de_partida.get("escena_de_retorno", "")).strip_edges(),
		"dificultad": max(0, int(plan_de_partida.get("dificultad", 0))),
		"numero_nivel": max(1, int(plan_de_partida.get("numero_nivel", 1))),
		"indice_juego_actual": indice_juego_actual,
		"total_juegos": total_juegos,
		"juegos": juegos,
	}


func _construir_juego_actual_de_partida(partida_activa: Dictionary) -> Dictionary:
	if partida_activa.is_empty():
		return {}
	var juegos: Array[Dictionary] = _duplicar_juegos_de_partida(partida_activa.get("juegos", []))
	if juegos.is_empty():
		return {}
	var indice_juego_actual: int = clampi(
		int(partida_activa.get("indice_juego_actual", 0)),
		0,
		juegos.size() - 1
	)
	var juego_actual: Dictionary = juegos[indice_juego_actual].duplicate(true)
	juego_actual["pertenece_a_partida_de_nodo"] = true
	juego_actual["indice_juego_actual"] = indice_juego_actual
	juego_actual["total_juegos"] = juegos.size()
	juego_actual["titulo_nodo"] = str(partida_activa.get("titulo_nodo", "")).strip_edges()
	juego_actual["dificultad"] = _obtener_dificultad_del_juego_actual(juego_actual, partida_activa)
	juego_actual["track_key"] = str(partida_activa.get("clave_pista", "")).strip_edges()
	juego_actual["node_key"] = str(partida_activa.get("clave_nodo", "")).strip_edges()
	juego_actual["node_title"] = str(partida_activa.get("titulo_nodo", "")).strip_edges()
	juego_actual["level_number"] = max(1, int(partida_activa.get("numero_nivel", 1)))
	juego_actual["return_to"] = str(partida_activa.get("escena_de_retorno", "")).strip_edges()
	juego_actual["activity_id"] = str(juego_actual.get("activity_id", "")).strip_edges()
	juego_actual["pack_id"] = str(juego_actual.get("pack_id", juego_actual.get("track_key", ""))).strip_edges()
	return juego_actual


func _duplicar_juegos_de_partida(raw_value: Variant) -> Array[Dictionary]:
	var juegos: Array[Dictionary] = []
	if not raw_value is Array:
		return juegos
	for raw_game in raw_value:
		if raw_game is Dictionary:
			juegos.append((raw_game as Dictionary).duplicate(true))
	return juegos


func _obtener_dificultad_del_juego_actual(
	juego_actual: Dictionary,
	partida_activa: Dictionary
) -> int:
	return max(0, int(juego_actual.get("dificultad", partida_activa.get("dificultad", 0))))


func _construir_contexto_de_progreso_de_juego(
	titulo: String,
	indice_juego_actual: int,
	total_juegos: int,
	dificultad: int,
	fuente: Dictionary,
	pertenece_a_partida_de_nodo: bool
) -> Dictionary:
	var total_juegos_seguro: int = max(1, total_juegos)
	var indice_juego_seguro: int = clampi(max(1, indice_juego_actual), 1, total_juegos_seguro)
	return {
		"actual": indice_juego_seguro,
		"total": total_juegos_seguro,
		"titulo": titulo.strip_edges(),
		"indice_juego_actual": indice_juego_seguro,
		"total_juegos": total_juegos_seguro,
		"dificultad": max(0, dificultad),
		"mode": str(fuente.get("mode", "")).strip_edges(),
		"json_path": str(fuente.get("json_path", "")).strip_edges(),
		"activity_id": str(fuente.get("activity_id", "")).strip_edges(),
		"pack_id": str(fuente.get("pack_id", "")).strip_edges(),
		"titulo_nodo": str(fuente.get("titulo_nodo", titulo)).strip_edges(),
		"pertenece_a_partida_de_nodo": pertenece_a_partida_de_nodo,
	}


# --- Continuacion de mapa ---------------------------------------------------

func solicitar_continuar(nodo_actual: String) -> void:
	_nodo_a_continuar = nodo_actual.strip_edges()


func consumir_nodo_a_continuar() -> String:
	var nodo: String = _nodo_a_continuar
	_nodo_a_continuar = ""
	return nodo


# --- Finalizacion de nodo (EXP) -------------------------------------------

func establecer_ultima_finalizacion(datos: Dictionary) -> void:
	_ultima_finalizacion = datos.duplicate(true)


func obtener_y_limpiar_ultima_finalizacion() -> Dictionary:
	var datos: Dictionary = _ultima_finalizacion.duplicate(true)
	_ultima_finalizacion = {}
	return datos


func hay_ultima_finalizacion() -> bool:
	## Devuelve true si existe una finalizacion de nodo pendiente de mostrar.
	## No limpia los datos — la pantalla de finalización los lee y limpia en su _ready().
	return not _ultima_finalizacion.is_empty()


func obtener_tiempo_nodo_formato() -> String:
	## Devuelve el tiempo transcurrido desde iniciar_partida_de_nodo() como "m:ss".
	## Retorna "—" si no hay partida activa o no se inició el cronómetro.
	if _inicio_nodo_msec <= 0:
		return "—"
	var elapsed_ms: int = Time.get_ticks_msec() - _inicio_nodo_msec
	var seconds: int = int(elapsed_ms / 1000.0)
	return "%d:%02d" % [int(seconds / 60.0), seconds % 60]


func registrar_resultado_mini_juego(acierto: bool) -> void:
	## Registra 1 intento (acierto o error) para el acumulador de stats del nodo activo.
	## Llamar desde cada modalidad al completar un intento o mini juego.
	_stats_nodo_actual["intentos"] = int(_stats_nodo_actual.get("intentos", 0)) + 1
	if acierto:
		_stats_nodo_actual["aciertos"] = int(_stats_nodo_actual.get("aciertos", 0)) + 1
	else:
		_stats_nodo_actual["errores"] = int(_stats_nodo_actual.get("errores", 0)) + 1


func obtener_stats_nodo_actual() -> Dictionary:
	## Devuelve copia de los stats acumulados del nodo activo.
	return _stats_nodo_actual.duplicate(true)


# --- Continuacion pendiente -------------------------------------------------
# Fuente unica para que las pantallas sepan si deben mostrar la flecha de retomar.

func hay_juego_o_nodo_para_continuar() -> bool:
	return not obtener_destino_de_continuacion().is_empty()


func obtener_destino_de_continuacion() -> Dictionary:
	var destino_partida: Dictionary = _obtener_destino_partida_de_nodo_activa()
	if not destino_partida.is_empty():
		return destino_partida

	var destino_sesion: Dictionary = _obtener_destino_sesion_nodo_activa()
	if not destino_sesion.is_empty():
		return destino_sesion

	var destino_guardado: Dictionary = _obtener_destino_reanudacion_guardada()
	if not destino_guardado.is_empty():
		return destino_guardado

	return {}


func limpiar_continuacion_si_corresponde() -> void:
	if not _partida_de_nodo_activa.is_empty():
		return
	if not _active_playable_node.is_empty():
		return
	_nodo_a_continuar = ""


# --- Estados extra de progreso ---------------------------------------------

func establecer_progreso_sistema_estado(system_key: String, state: Dictionary) -> void:
	var normalized_system_key: String = system_key.strip_edges()
	if normalized_system_key.is_empty():
		return
	if state.is_empty():
		_extra_progress_system_states.erase(normalized_system_key)
		return
	_extra_progress_system_states[normalized_system_key] = state.duplicate(true)


func obtener_progreso_sistema_estado(system_key: String) -> Dictionary:
	var normalized_system_key: String = system_key.strip_edges()
	if normalized_system_key.is_empty():
		return {}
	var raw_state: Variant = _extra_progress_system_states.get(normalized_system_key, {})
	if raw_state is Dictionary:
		return (raw_state as Dictionary).duplicate(true)
	return {}


# --- Racha ------------------------------------------------------------------

func obtener_estado_racha() -> Dictionary:
	return GameStreakTracker.read(_streak_state)


func obtener_modelo_vista_racha() -> Dictionary:
	return GameStreakTracker.view_model(obtener_estado_racha())


func establecer_estado_racha(streak_state: Dictionary) -> void:
	_streak_state = GameStreakTracker.read(streak_state)


func registrar_actividad_racha(activity_type: String, metadata: Dictionary = {}) -> Dictionary:
	var racha_anterior: Dictionary = obtener_estado_racha()
	_streak_state = GameStreakTracker.record(racha_anterior, activity_type, metadata)
	return _streak_state


# --- Catalogo de contenido --------------------------------------------------

func obtener_pista_nivel_cantidad(track_key: String = "") -> int:
	var fallback: int = GameTrackCatalog.obtener_pista_nivel_cantidad(
		track_key, GameTrackCatalog.DEFAULT_LEVEL_COUNT
	)
	return _level_content.obtener_pista_nivel_cantidad(track_key, fallback)


func obtener_capitulo_partida_cantidad(track_key: String, level_number: int) -> int:
	return _level_content.obtener_capitulo_partida_cantidad(track_key, level_number)


func obtener_capitulo_partida_definicion(
	track_key: String, level_number: int, run_index: int = 1
) -> Dictionary:
	return _level_content.obtener_capitulo_partida_definicion(track_key, level_number, run_index)


# --- Exportar / importar progreso ------------------------------------------

func exportar_progreso() -> Dictionary:
	var snapshot: Dictionary = _exportar_campana_progreso()
	_exportar_estados_parciales_nivel(snapshot)
	_exportar_estados_sistema_progreso(snapshot)
	return snapshot


func importar_progreso(snapshot: Dictionary) -> void:
	reiniciar_progreso()
	if snapshot.is_empty():
		return
	_importar_campana_progreso(snapshot)
	_importar_estados_parciales_nivel(snapshot)
	_importar_estados_sistema_progreso(snapshot.get("progress_system_states", {}))


# --- Helpers privados -------------------------------------------------------

func _exportar_campana_progreso() -> Dictionary:
	return _campaign_save_helper.exportar_campana(
		_completed_levels_by_track, current_level, obtener_pista_nivel_cantidad
	)


func _exportar_estados_parciales_nivel(snapshot: Dictionary) -> void:
	snapshot["partial_level_states"] = _partial_state_save_helper.exportar_estado(
		_partial_level_state_by_track
	)


func _exportar_estados_sistema_progreso(snapshot: Dictionary) -> void:
	var systems_state: Dictionary = _construir_snapshot_estados_sistema_progreso()
	if not systems_state.is_empty():
		snapshot["progress_system_states"] = systems_state


func _importar_campana_progreso(snapshot: Dictionary) -> void:
	current_level = _campaign_save_helper.importar_campana(
		snapshot, _completed_levels_by_track, obtener_pista_nivel_cantidad
	)


func _importar_estados_parciales_nivel(snapshot: Dictionary) -> void:
	_partial_level_state_by_track = _partial_state_save_helper.importar_estado(
		snapshot.get("partial_level_states", {}),
		es_nivel_completado,
		obtener_pista_nivel_cantidad
	)


func _construir_snapshot_estados_sistema_progreso() -> Dictionary:
	var systems_state: Dictionary = _duplicar_estados_extra_sistema_progreso()
	_agregar_estado_progreso_racha(systems_state)
	_agregar_estado_progreso_nodos_jugables(systems_state)
	return systems_state


func _duplicar_estados_extra_sistema_progreso() -> Dictionary:
	var systems_state: Dictionary = {}
	for system_key in _extra_progress_system_states.keys():
		var raw_state: Variant = _extra_progress_system_states.get(system_key, {})
		if raw_state is Dictionary:
			systems_state[str(system_key)] = (raw_state as Dictionary).duplicate(true)
	return systems_state


func _agregar_estado_progreso_racha(systems_state: Dictionary) -> void:
	var streak_wrapper: Dictionary = {}
	_streak_save_helper.exportar_racha(streak_wrapper, _streak_state)
	var streak_systems: Variant = streak_wrapper.get("progress_system_states", {})
	if streak_systems is Dictionary:
		systems_state.merge((streak_systems as Dictionary).duplicate(true), true)


func _agregar_estado_progreso_nodos_jugables(systems_state: Dictionary) -> void:
	if not _playable_node_progress_by_track.is_empty():
		systems_state[QUESTION_PROGRESS_SYSTEM_KEY] = (
			_playable_node_progress_by_track.duplicate(true)
		)


func _importar_estados_sistema_progreso(raw_systems_state: Variant) -> void:
	if not raw_systems_state is Dictionary:
		return

	var systems_state: Dictionary = raw_systems_state
	_importar_racha_estado_progreso(systems_state)
	_importar_estado_progreso_nodos_jugables(systems_state)
	_importar_estados_sistema_progreso_personalizados(systems_state)


func _importar_racha_estado_progreso(systems_state: Dictionary) -> void:
	_streak_state = _streak_save_helper.importar_racha({"progress_system_states": systems_state})


func _importar_estado_progreso_nodos_jugables(systems_state: Dictionary) -> void:
	var estado_progreso_nodos: Variant = systems_state.get(QUESTION_PROGRESS_SYSTEM_KEY, {})
	if estado_progreso_nodos is Dictionary:
		_playable_node_progress_by_track = (estado_progreso_nodos as Dictionary).duplicate(true)


func _importar_estados_sistema_progreso_personalizados(systems_state: Dictionary) -> void:
	for system_key in systems_state.keys():
		var normalized_system_key: String = str(system_key).strip_edges()
		if normalized_system_key == STREAK_SYSTEM_KEY:
			continue
		if normalized_system_key == QUESTION_PROGRESS_SYSTEM_KEY:
			continue
		var raw_state: Variant = systems_state.get(system_key, {})
		if raw_state is Dictionary:
			_extra_progress_system_states[normalized_system_key] = (
				(raw_state as Dictionary).duplicate(true)
			)


func _obtener_clave_pista_valida(track_key: String) -> String:
	var key: String = track_key.strip_edges()
	if key.is_empty() or not GameTrackCatalog.tiene_pista(key):
		return ""
	return key


func _nivel_a_indice(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return -1
	var count: int = obtener_pista_nivel_cantidad(track_key)
	if count <= 0:
		return -1
	return clampi(level_number, 1, count) - 1


func _obtener_numero_nivel_valido(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return 0
	var max_level: int = obtener_pista_nivel_cantidad(track_key)
	return 0 if max_level <= 0 else clampi(level_number, 1, max_level)


func _asegurar_pista_progreso_existe(track_key: String) -> void:
	if _completed_levels_by_track.has(track_key):
		return
	var count: int = obtener_pista_nivel_cantidad(track_key)
	var flags: Array = []
	flags.resize(count)
	flags.fill(false)
	_completed_levels_by_track[track_key] = flags


func _obtener_destino_partida_de_nodo_activa() -> Dictionary:
	if _juego_de_nodo_actual.is_empty():
		return {}
	return _construir_destino_jugable(_juego_de_nodo_actual)


func _obtener_destino_sesion_nodo_activa() -> Dictionary:
	if _active_playable_node.is_empty():
		return {}
	return _construir_destino_jugable(_active_playable_node)


func _construir_destino_jugable(contexto_jugable: Dictionary) -> Dictionary:
	var modo: String = str(
		contexto_jugable.get("mode", contexto_jugable.get("node_mode", ""))
	).strip_edges()
	if modo.is_empty():
		return {}
	return {
		"type": "playable_mode",
		"mode": modo,
		"track_key": str(contexto_jugable.get("track_key", "")).strip_edges(),
		"node_key": str(contexto_jugable.get("node_key", "")).strip_edges(),
		"return_to": str(contexto_jugable.get("return_to", "")).strip_edges(),
	}


func _obtener_destino_reanudacion_guardada() -> Dictionary:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return {}
	if not save_manager.has_method("puede_reanudar_guardado_actual"):
		return {}
	if not bool(save_manager.call("puede_reanudar_guardado_actual")):
		return {}
	if not save_manager.has_method("recargar_desde_disco_y_obtener_reanudacion"):
		return {}
	var estado_reanudacion: Variant = save_manager.call(
		"recargar_desde_disco_y_obtener_reanudacion"
	)
	if not estado_reanudacion is Dictionary:
		return {}
	var estado: Dictionary = (estado_reanudacion as Dictionary).duplicate(true)
	if estado.is_empty():
		return {}
	return {
		"type": "resume",
		"resume_state": estado,
	}
