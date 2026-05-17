# Orquesta avance entre mini juegos y cierre del nodo. Delega cálculos a NodoProgressionRules.
extends RefCounted
class_name ContinuidadDePartidaDeNodo

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")
const LOG_PREFIX_NODE_PROGRESS := "[NodeProgress]"
const LOG_PREFIX_NODE_COMPLETE := "[NodeComplete]"


# Decide si abrir el siguiente juego del plan o cerrar el nodo actual.
static func continuar_o_finalizar_partida(
	tree: SceneTree,
	antes_de_abrir_siguiente_juego: Callable = Callable(),
	al_finalizar_partida: Callable = Callable()
) -> bool:
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return false

	# Marcar la activity actual como completada antes de avanzar/finalizar
	_marcar_activity_actual_completada(tree, estado_global)

	if bool(estado_global.call("hay_siguiente_juego_de_partida")):
		if antes_de_abrir_siguiente_juego.is_valid():
			antes_de_abrir_siguiente_juego.call()
		estado_global.call("avanzar_partida_de_nodo")
		return abrir_juego_actual(tree, estado_global)

	var partida_actual: Dictionary = estado_global.call("obtener_partida_de_nodo_actual")
	print(
		"%s node=%s"
		% [LOG_PREFIX_NODE_COMPLETE, str(partida_actual.get("clave_nodo", "")).strip_edges()]
	)

	# Calcular y persistir EXP antes de limpiar la partida
	_registrar_exp_finalizacion(tree, estado_global, partida_actual)

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
	# Abre el juego actual ya armado por el plan; no altera el orden del nodo.
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
	GameSceneRouter.ir_a_modo_jugable(tree, modo_actual)
	return true


# Helpers privados
static func _es_modo_jugable_soportado(modo: String) -> bool:
	match modo.strip_edges():
		"drag_drop", "quiz_choice", "vinculacion_conceptos", "word_options":
			return true
		_:
			return false


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
	if request_key.is_empty() or activity_id.is_empty():
		return
	if tree == null or tree.root == null:
		return
	var save_manager: Node = tree.root.get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return
	if save_manager.has_method("mark_activity_completed"):
		save_manager.call("mark_activity_completed", request_key, activity_id)


static func _registrar_exp_finalizacion(
	tree: SceneTree,
	estado_global: Node,
	partida_actual: Dictionary
) -> void:
	if tree == null or tree.root == null:
		return
	var save_manager: Node = tree.root.get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return
	var titulo_nodo: String = str(partida_actual.get("titulo_nodo", "")).strip_edges()
	var dificultad_fallback: int = max(1, int(partida_actual.get("dificultad", 1)))

	# EXP base: suma de la EXP individual de cada mini juego según su dificultad
	var juegos: Array = partida_actual.get("juegos", [])
	var exp_base_total: int = _calcular_exp_base_total(juegos, dificultad_fallback)

	# Precision real desde el acumulador de stats del nodo
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

	var precision_ratio: float = NodoProgressionRulesScript.calculate_precision_ratio(aciertos, intentos)
	var precision_percent: int = NodoProgressionRulesScript.calculate_precision(aciertos, intentos)

	# EXP penalizada por precision
	var exp_ganada: int = NodoProgressionRulesScript.calculate_final_exp(exp_base_total, precision_ratio)

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

	# Tiempo transcurrido desde que inicio la partida
	var tiempo_str: String = "—"
	if estado_global.has_method("obtener_tiempo_nodo_formato"):
		tiempo_str = str(estado_global.call("obtener_tiempo_nodo_formato")).strip_edges()

	if estado_global.has_method("establecer_ultima_finalizacion"):
		estado_global.call("establecer_ultima_finalizacion", {
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
	## Delega a NodoProgressionRules para mantener un único punto de definición.
	return NodoProgressionRulesScript.calculate_base_exp(juegos, dificultad_fallback)
