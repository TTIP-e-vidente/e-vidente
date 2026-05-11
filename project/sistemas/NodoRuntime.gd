extends RefCounted
class_name NodoRuntime

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const ContinuidadScript := preload("res://mapas/logica/ContinuidadDePartidaDeNodo.gd")
const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")
const NodoStatsScript := preload("res://sistemas/NodoStats.gd")
const ResultadoDeNodoScript := preload("res://nodo/ResultadoDeNodo.gd")


static func iniciar(
	tree: SceneTree,
	node_data: MapNodeData,
	return_to: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	if tree == null:
		return _error("Falta SceneTree.")
	if node_data == null or not node_data.is_valid():
		return _error("Nodo invalido o sin contenido.")
	var global_state: Node = _global(tree)
	if global_state == null:
		return _error("No se encontro el autoload Global.")

	var return_to_safe: String = return_to.strip_edges()
	if return_to_safe.is_empty():
		return_to_safe = GameSceneRouter.MAP_SCENE_PATH

	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(node_data)
	if plan.is_empty():
		_limpiar(global_state)
		return _error("No se pudo armar la partida del nodo.")

	plan["escena_de_retorno"] = return_to_safe
	var sesion: Dictionary = _construir_sesion(node_data, return_to_safe)

	_limpiar(global_state)
	global_state.call("establecer_sesion_nodo_jugable_activo", sesion)
	global_state.call("iniciar_partida_de_nodo", plan)

	if not ContinuidadScript.abrir_juego_actual(tree, global_state):
		_limpiar(global_state)
		return _error("No se pudo abrir el primer juego del nodo.")

	return {"ok": true, "error": ""}


static func obtener_actividad_actual(tree: SceneTree) -> Dictionary:
	var global_state: Node = _global(tree)
	if global_state == null:
		return {}
	return global_state.call("obtener_juego_actual_de_partida")


static func avanzar_actividad(
	tree: SceneTree,
	antes_de_abrir_siguiente: Callable = Callable(),
	al_finalizar: Callable = Callable()
) -> bool:
	return ContinuidadScript.continuar_o_finalizar_partida(
		tree,
		antes_de_abrir_siguiente,
		al_finalizar
	)


static func esta_completado(tree: SceneTree) -> bool:
	var global_state: Node = _global(tree)
	if global_state == null:
		return true
	return not bool(global_state.call("hay_siguiente_juego_de_partida"))


static func obtener_dificultad(tree: SceneTree) -> int:
	var global_state: Node = _global(tree)
	if global_state == null:
		return 1
	return global_state.call("obtener_dificultad_del_juego_actual")


static func obtener_tipo_modalidad_actual(tree: SceneTree) -> String:
	return str(obtener_actividad_actual(tree).get("mode", "")).strip_edges()


static func get_exp_base_por_dificultad(difficulty: int) -> int:
	# Delega a NodoProgressionRules — sin números mágicos en este archivo.
	return NodoProgressionRulesScript.get_exp_for_difficulty_value(difficulty)


static func calcular_exp(resultado: Dictionary) -> int:
	# resultado puede incluir: difficulty, correcto (bool), bonus_racha (int)
	var difficulty: int = int(resultado.get("difficulty", resultado.get("dificultad", 1)))
	var correcto: bool = bool(resultado.get("correcto", resultado.get("correct", true)))
	if not correcto:
		return 0
	var exp_base: int = get_exp_base_por_dificultad(difficulty)
	var bonus_racha: int = int(resultado.get("bonus_racha", resultado.get("streak_bonus", 0)))
	return exp_base + bonus_racha


# --- API pública trainee ----------------------------------------------------
# Estos wrappers tienen nombres simples para facilitar el onboarding.
# Internamente delegan a las funciones estáticas de arriba.

# Inicia el flujo de un nodo. Llama a esto desde MapScene al hacer clic en un nodo.
static func iniciar_nodo(
	tree: SceneTree,
	node_data: MapNodeData,
	return_to: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	return iniciar(tree, node_data, return_to)


# Avanza o finaliza el nodo luego de que un mini juego terminó.
# Llama a esto desde Level.gd, pregunta.gd o vincular_conceptos.gd.
static func finalizar_mini_juego(
	tree: SceneTree,
	antes_de_abrir_siguiente: Callable = Callable(),
	al_finalizar: Callable = Callable()
) -> bool:
	return avanzar_actividad(tree, antes_de_abrir_siguiente, al_finalizar)


# Devuelve true si quedan mini juegos después del actual.
static func hay_siguiente_mini_juego(tree: SceneTree) -> bool:
	return not esta_completado(tree)


# Devuelve el estado actual del nodo: índice, total y actividad en curso.
static func obtener_progreso(tree: SceneTree) -> Dictionary:
	var actividad: Dictionary = obtener_actividad_actual(tree)
	return {
		"indice_actual": int(actividad.get("indice_juego_actual", 0)),
		"total": int(actividad.get("total_juegos", 1)),
		"activity_id": str(actividad.get("activity_id", "")),
		"modo": str(actividad.get("mode", "")),
	}


# Devuelve la actividad en curso tal como la usarían los mini juegos.
static func obtener_actividad_actual_trainee(tree: SceneTree) -> Dictionary:
	return obtener_actividad_actual(tree)


# Calcula la precisión basada en el acumulador de stats del nodo actual.
static func calcular_precision(tree: SceneTree) -> int:
	return NodoStatsScript.get_precision(tree)


# Devuelve el tiempo transcurrido del nodo en formato "MM:SS".
static func calcular_tiempo(tree: SceneTree) -> String:
	return NodoStatsScript.get_duration_formatted(tree)


# Calcula la EXP ganada en este nodo según la precisión y los mini juegos jugados.
# Solo para consulta — la persistencia real la maneja ContinuidadDePartidaDeNodo.
static func calcular_exp_final(tree: SceneTree) -> int:
	var global_state: Node = _global(tree)
	if global_state == null:
		return 0
	var partida: Dictionary = {}
	if global_state.has_method("obtener_partida_de_nodo_actual"):
		partida = global_state.call("obtener_partida_de_nodo_actual")
	var juegos: Array = partida.get("juegos", [])
	var dificultad_fallback: int = max(1, int(partida.get("dificultad", 1)))
	var exp_base: int = NodoProgressionRulesScript.calculate_base_exp(juegos, dificultad_fallback)
	var precision_ratio: float = clampf(float(calcular_precision(tree)) / 100.0, 0.0, 1.0)
	return NodoProgressionRulesScript.calculate_final_exp(exp_base, precision_ratio)


## Genera el resultado completo del nodo actual para mostrar en Finalización-Partida.
## Llama a esto antes de finalizar — después de finalizar_nodo() los datos se limpian.
static func crear_resultado_de_nodo(tree: SceneTree) -> Dictionary:
	var global_state: Node = _global(tree)
	if global_state == null:
		return {}
	var partida: Dictionary = {}
	if global_state.has_method("obtener_partida_de_nodo_actual"):
		partida = global_state.call("obtener_partida_de_nodo_actual")
	var juegos: Array = partida.get("juegos", [])
	var dificultad_fallback: int = max(1, int(partida.get("dificultad", 1)))
	var exp_base: int = NodoProgressionRulesScript.calculate_base_exp(juegos, dificultad_fallback)
	var stats: Dictionary = NodoStatsScript.get_stats(tree)
	var aciertos: int = int(stats.get("aciertos", 0))
	var errores: int = int(stats.get("errores", 0))
	var intentos: int = int(stats.get("intentos", 0))
	var precision_ratio: float = NodoProgressionRulesScript.calculate_precision_ratio(aciertos, intentos)
	var precision: int = NodoProgressionRulesScript.calculate_precision(aciertos, intentos)
	var error_pct: int = NodoProgressionRulesScript.calculate_error_percent(errores, intentos)
	var exp_ganada: int = NodoProgressionRulesScript.calculate_final_exp(exp_base, precision_ratio)
	var duration_ms: int = NodoStatsScript.get_duration_ms(tree)
	var tiempo: String = NodoStatsScript.get_duration_formatted(tree)
	var save_manager: Node = tree.root.get_node_or_null("/root/SaveManager")
	var total_exp_after: int = 0
	if save_manager != null and save_manager.has_method("get_total_exp"):
		total_exp_after = int(save_manager.call("get_total_exp"))
	var ranking: int = 0
	if save_manager != null and save_manager.has_method("get_ranking_position"):
		ranking = int(save_manager.call("get_ranking_position"))
	return {
		"exp_base": exp_base,
		"exp_ganada": exp_ganada,
		"precision": precision,
		"error_percent": error_pct,
		"tiempo": tiempo,
		"duration_ms": duration_ms,
		"correct": aciertos,
		"errors": errores,
		"attempts": intentos,
		"total_exp_after_claim": total_exp_after,
		"ranking_position": ranking,
	}


# --- Privados ---------------------------------------------------------------

## Devuelve el resultado del nodo actual como objeto tipado ResultadoDeNodo.
## Conveniente para code que prefiere objetos sobre Dictionaries.
static func crear_resultado_tipado(tree: SceneTree) -> ResultadoDeNodo:
	return ResultadoDeNodoScript.desde_diccionario(crear_resultado_de_nodo(tree))


static func _construir_sesion(node_data: MapNodeData, return_to: String) -> Dictionary:
	return {
		"node_key": node_data.node_key,
		"node_title": node_data.title,
		"json_path": node_data.json_path,
		"activity_id": node_data.activity_id,
		"pack_id": node_data.get_effective_pack_id(),
		"track_key": node_data.track_key,
		"mode": node_data.mode.strip_edges(),
		"level_number": node_data.index + 1,
		"difficulty": node_data.difficulty,
		"return_to": return_to,
	}


static func _limpiar(global_state: Node) -> void:
	if global_state == null:
		return
	if global_state.has_method("limpiar_sesion_nodo_jugable_activo"):
		global_state.call("limpiar_sesion_nodo_jugable_activo")
	if global_state.has_method("finalizar_partida_de_nodo"):
		global_state.call("finalizar_partida_de_nodo")


static func _global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")


static func _error(mensaje: String) -> Dictionary:
	push_error("NodoRuntime: %s" % mensaje)
	return {"ok": false, "error": mensaje}
