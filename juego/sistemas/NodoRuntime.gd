extends RefCounted
class_name NodoRuntime


const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")
const NodoStatsScript := preload("res://sistemas/NodoStats.gd")
const GameSessionDataScript := preload("res://flow/session/game_session_data.gd")


static func iniciar(
	tree: SceneTree,
	node_data: MapNodeData,
	return_to: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	if tree == null:
		return _error("Falta SceneTree.")
	if node_data == null or not node_data.es_valido():
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

	var sesion_de_partida := _crear_sesion_de_partida(plan, node_data)
	global_state.call("establecer_sesion_de_juego", sesion_de_partida)

	if not ContinuidadDePartidaDeNodo.abrir_juego_actual(tree, global_state):
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
	return ContinuidadDePartidaDeNodo.continuar_o_finalizar_partida(
		tree,
		antes_de_abrir_siguiente,
		al_finalizar
	)


static func esta_completado(tree: SceneTree) -> bool:
	var global_state: Node = _global(tree)
	if global_state == null:
		return true
	return not bool(global_state.call("hay_siguiente_juego_de_partida"))


# --- API pública trainee ----------------------------------------------------
# Estos wrappers tienen nombres simples para facilitar el onboarding.
# Internamente delegan a las funciones estáticas de arriba.

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


# Calcula la precisión basada en el acumulador de stats del nodo actual.
static func calcular_precision(tree: SceneTree) -> int:
	return NodoStatsScript.obtener_precision(tree)


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
	return NodoProgressionRulesScript.calcular_exp_final(exp_base, precision_ratio)


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
	var stats: Dictionary = NodoStatsScript.obtener_estadisticas(tree)
	var aciertos: int = int(stats.get("aciertos", 0))
	var errores: int = int(stats.get("errores", 0))
	var intentos: int = int(stats.get("intentos", 0))
	var precision_ratio: float = NodoProgressionRulesScript.calcular_precision_ratio(
		aciertos, intentos
	)
	var precision: int = NodoProgressionRulesScript.calcular_precision(aciertos, intentos)
	var error_pct: int = NodoProgressionRulesScript.calculate_error_percent(errores, intentos)
	var exp_ganada: int = NodoProgressionRulesScript.calcular_exp_final(exp_base, precision_ratio)
	var duration_ms: int = NodoStatsScript.get_duration_ms(tree)
	var tiempo: String = NodoStatsScript.obtener_duracion_formateada(tree)
	var save_manager: Node = tree.root.get_node_or_null("/root/SaveManager")
	var total_exp_after: int = 0
	if save_manager != null and save_manager.has_method("obtener_exp_total"):
		total_exp_after = int(save_manager.call("obtener_exp_total"))
	var ranking: int = 0
	if save_manager != null and save_manager.has_method("obtener_posicion_ranking"):
		ranking = int(save_manager.call("obtener_posicion_ranking"))
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

static func _crear_sesion_de_partida(plan: Dictionary, node_data: MapNodeData) -> Resource:
	var juegos: Array = plan.get("juegos", [])
	var dificultad: int = max(1, int(plan.get("dificultad", 1)))
	var exp_base: int = NodoProgressionRulesScript.calculate_base_exp(juegos, dificultad)
	var modo: String = node_data.mode.strip_edges()
	if modo.is_empty():
		var primer_juego: Dictionary = juegos[0] if not juegos.is_empty() else {}
		modo = str(primer_juego.get("mode", "")).strip_edges()
	return GameSessionDataScript.crear(
		str(plan.get("clave_pista", "")),
		node_data.node_key,
		modo,
		dificultad,
		exp_base
	)


static func _construir_sesion(node_data: MapNodeData, return_to: String) -> Dictionary:
	return {
		"node_key": node_data.node_key,
		"node_title": node_data.title,
		"json_path": node_data.json_path,
		"activity_id": node_data.activity_id,
		"pack_id": node_data.obtener_pack_id_efectivo(),
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
