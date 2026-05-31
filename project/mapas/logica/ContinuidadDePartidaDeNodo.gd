extends RefCounted
class_name ContinuidadDePartidaDeNodo


const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")
const ModalidadRouterScript := preload("res://sistemas/ModalidadRouter.gd")
const LOG_PREFIX_NODE_PROGRESS := "[NodeProgress]"
const LOG_PREFIX_NODE_COMPLETE := "[NodeComplete]"


static func continuar_o_finalizar_partida(
	tree: SceneTree,
	antes_de_abrir_siguiente_juego: Callable = Callable(),
	al_finalizar_partida: Callable = Callable()
) -> bool:
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return false

	_marcar_activity_actual_completada(tree, estado_global)

	if bool(estado_global.call("hay_siguiente_juego_de_partida")):
		if antes_de_abrir_siguiente_juego.is_valid():
			antes_de_abrir_siguiente_juego.call()
		estado_global.call("avanzar_partida_de_nodo")
		return abrir_juego_actual(tree, estado_global)

	var partida_actual: Dictionary = estado_global.call("obtener_partida_de_nodo_actual")
	var node_key: String = str(partida_actual.get("clave_nodo", "")).strip_edges()
	var game_index: int = int(partida_actual.get("indice_juego_actual", 0))
	var _total_games: int = int(partida_actual.get("total_juegos", 0))
	var stats: Dictionary = {}
	if estado_global.has_method("obtener_stats_nodo_actual"):
		stats = estado_global.call("obtener_stats_nodo_actual")
	var percent: float = clampf(float(NodoRuntime.calcular_precision(tree)) / 100.0, 0.0, 1.0)
	var score: int = int(stats.get("aciertos", 0))
	var completed: bool = true
	print(
		"%s node=%s"
		% [LOG_PREFIX_NODE_COMPLETE, node_key]
	)
	print_debug(
		"[Progress] partida finalizada node_key=",
		node_key,
		" game_index=",
		game_index,
		" score=",
		score,
		" percent=",
		percent,
		" completed=",
		completed,
		" result=",
		stats
	)

	_registrar_exp_finalizacion(tree, estado_global, partida_actual)
	# Debe ir antes de finalizar: Global limpia los stats ahí.
	_guardar_precision_nodo(tree, partida_actual)

	estado_global.call("finalizar_partida_de_nodo")
	if al_finalizar_partida.is_valid():
		al_finalizar_partida.call()
	return false


static func hay_siguiente_juego(tree: SceneTree) -> bool:
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return false
	return bool(estado_global.call("hay_siguiente_juego_de_partida"))


static func abrir_juego_actual(tree: SceneTree, estado_global: Node = null) -> bool:
	var estado: Node = estado_global
	if estado == null:
		estado = _obtener_estado_global(tree)
	if estado == null:
		return false

	var juego_actual: Dictionary = estado.call("obtener_juego_actual_de_partida")
	var partida_actual: Dictionary = estado.call("obtener_partida_de_nodo_actual")
	var modo_actual: String = str(juego_actual.get("mode", "")).strip_edges()
	if not _es_modo_jugable_soportado(modo_actual):
		push_error(
			"ContinuidadDePartidaDeNodo: modo no soportado: %s"
			% JSON.stringify(juego_actual)
		)
		return false

	print(
		"%s game=%d/%d activity=%s"
		% [
			LOG_PREFIX_NODE_PROGRESS,
			int(partida_actual.get("indice_juego_actual", 0)) + 1,
			int(partida_actual.get("total_juegos", 0)),
			_resolver_identificador_de_juego(juego_actual),
		]
	)

	print("[NodeOpen] node_key=", str(partida_actual.get("clave_nodo", "")).strip_edges())
	print("[NodeOpen] plan_size=", int(partida_actual.get("total_juegos", 0)))
	print("[NodeOpen] current_activity_id=", _resolver_identificador_de_juego(juego_actual))
	print("[NodeOpen] opening_activity_type=", modo_actual)
	print("[NodeOpen] scene_path=", "") # Scene path might be handled by GameSceneRouter

	_marcar_activity_actual_jugada(tree, juego_actual)
	var router: Node = tree.root.get_node_or_null("GameSceneRouter")
	if router != null and router.has_method("ir_a_modo_jugable"):
		router.call("ir_a_modo_jugable", tree, modo_actual)
	else:
		push_error("[NodeOpen] No se encontró GameSceneRouter o no tiene ir_a_modo_jugable.")
	return true


static func _es_modo_jugable_soportado(modo: String) -> bool:
	# Delega a ModalidadRouter para evitar lista duplicada. Soportado = modo reconocido.
	return not ModalidadRouterScript.normalizar_modo(modo.strip_edges()).is_empty()


static func _obtener_estado_global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")


static func _resolver_identificador_de_juego(juego_actual: Dictionary) -> String:
	var activity_id: String = str(juego_actual.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		return activity_id
	var json_path: String = str(juego_actual.get("json_path", "")).strip_edges()
	if not json_path.is_empty():
		return json_path.get_file().trim_suffix(".json")
	return str(juego_actual.get("clave_nodo_de_origen", "")).strip_edges()


static func _marcar_activity_actual_completada(tree: SceneTree, estado_global: Node) -> void:
	var juego_actual: Dictionary = estado_global.call("obtener_juego_actual_de_partida")
	var request_key: String = str(juego_actual.get("request_key", "")).strip_edges()
	var activity_id: String = str(juego_actual.get("activity_id", "")).strip_edges()
	var save_manager: Node = _get_save_manager(tree)
	if activity_id.is_empty() or save_manager == null:
		return
	save_manager.call("mark_activity_completed", request_key, activity_id)


static func _marcar_activity_actual_jugada(tree: SceneTree, juego_actual: Dictionary) -> void:
	var request_key: String = str(juego_actual.get("request_key", "")).strip_edges()
	var activity_id: String = str(juego_actual.get("activity_id", "")).strip_edges()
	var save_manager: Node = _get_save_manager(tree)
	if activity_id.is_empty() or save_manager == null:
		return
	if save_manager.has_method("mark_activity_played"):
		save_manager.call("mark_activity_played", request_key, activity_id)


static func _guardar_precision_nodo(tree: SceneTree, partida_actual: Dictionary) -> void:
	var node_key: String = str(partida_actual.get("clave_nodo", "")).strip_edges()
	var track_key: String = str(partida_actual.get("clave_pista", "")).strip_edges()
	var save_manager: Node = _get_save_manager(tree)
	if node_key.is_empty() or save_manager == null:
		return
	var precision: int = NodoRuntime.calcular_precision(tree)
	var total_games: int = int(partida_actual.get("total_juegos", 0))
	var completed_games: int = total_games
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global != null and estado_global.has_method("marcar_nodo_jugable_completado"):
		estado_global.call("marcar_nodo_jugable_completado", track_key, node_key)
	print_debug(
		"[Progress] guardando progreso node_key=",
		node_key,
		" completed_games=",
		completed_games,
		" total_games=",
		total_games
	)
	save_manager.call("save_node_accuracy", node_key, float(precision), completed_games, total_games)
	print("%s accuracy=%d node=%s" % [LOG_PREFIX_NODE_COMPLETE, precision, node_key])


static func _get_save_manager(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/SaveManager")


static func _registrar_exp_finalizacion(
	tree: SceneTree,
	estado_global: Node,
	partida_actual: Dictionary
) -> void:
	var save_manager: Node = _get_save_manager(tree)
	if save_manager == null:
		return
	var node_key: String = str(partida_actual.get("clave_nodo", "")).strip_edges()
	var titulo_nodo: String = str(partida_actual.get("titulo_nodo", "")).strip_edges()
	var dificultad_fallback: int = max(1, int(partida_actual.get("dificultad", 1)))

	var juegos: Array = partida_actual.get("juegos", [])
	var exp_base_total: int = _calcular_exp_base_total(juegos, dificultad_fallback)

	var stats: Dictionary = {}
	if estado_global.has_method("obtener_stats_nodo_actual"):
		stats = estado_global.call("obtener_stats_nodo_actual")
	var aciertos: int = int(stats.get("aciertos", 0))
	var errores: int = int(stats.get("errores", 0))
	var intentos: int = int(stats.get("intentos", 0))
	if intentos == 0:
		push_warning(
			"[FlujoBug] Nodo '%s' finalizado con 0 intentos. "
			% titulo_nodo
			+ "¿Las modalidades llamaron registrar_resultado_mini_juego()?"
		)

	var precision_ratio: float = NodoProgressionRulesScript.calculate_precision_ratio(
		aciertos,
		intentos
	)
	var precision_percent: int = NodoProgressionRulesScript.calculate_precision(aciertos, intentos)

	var exp_ganada: int = NodoProgressionRulesScript.calculate_final_exp(
		exp_base_total,
		precision_ratio
	)

	var total_exp_nuevo: int = 0
	if save_manager.has_method("add_exp"):
		total_exp_nuevo = save_manager.call("add_exp", exp_ganada)
	print(
		"%s exp_base=%d precision=%d%% exp_ganada=%d total_exp=%d aciertos=%d errores=%d intentos=%d"
		% [
			LOG_PREFIX_NODE_COMPLETE,
			exp_base_total,
			precision_percent,
			exp_ganada,
			total_exp_nuevo,
			aciertos,
			errores,
			intentos,
		]
	)

	var tiempo_str: String = "—"
	if estado_global.has_method("obtener_tiempo_nodo_formato"):
		tiempo_str = str(estado_global.call("obtener_tiempo_nodo_formato")).strip_edges()

	if estado_global.has_method("establecer_ultima_finalizacion"):
		estado_global.call("establecer_ultima_finalizacion", {
			"node_key": node_key,
			"exp_base": exp_base_total,
			"exp_ganada": exp_ganada,
			"total_exp": total_exp_nuevo,
			"titulo_nodo": titulo_nodo,
			"dificultad": dificultad_fallback,
			"precision": precision_percent,
			"error_percent": NodoProgressionRulesScript.calculate_error_percent(errores, intentos),
			"tiempo": tiempo_str,
			"aciertos": aciertos,
			"errores": errores,
			"intentos": intentos,
		})


static func _calcular_exp_base_total(juegos: Array, dificultad_fallback: int) -> int:
	return NodoProgressionRulesScript.calculate_base_exp(juegos, dificultad_fallback)
