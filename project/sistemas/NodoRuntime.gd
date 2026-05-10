extends RefCounted
class_name NodoRuntime

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const ContinuidadScript := preload("res://mapas/logica/ContinuidadDePartidaDeNodo.gd")

const EXP_BASE_DIFICULTAD_1 := 6
const EXP_INCREMENTO_POR_DIFICULTAD := 3


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
	var d: int = maxi(1, difficulty)
	return EXP_BASE_DIFICULTAD_1 + (d - 1) * EXP_INCREMENTO_POR_DIFICULTAD


static func calcular_exp(resultado: Dictionary) -> int:
	# resultado puede incluir: difficulty, correcto (bool), bonus_racha (int)
	var difficulty: int = int(resultado.get("difficulty", resultado.get("dificultad", 1)))
	var correcto: bool = bool(resultado.get("correcto", resultado.get("correct", true)))
	if not correcto:
		return 0
	var exp_base: int = get_exp_base_por_dificultad(difficulty)
	var bonus_racha: int = int(resultado.get("bonus_racha", resultado.get("streak_bonus", 0)))
	return exp_base + bonus_racha


# --- Privados ---------------------------------------------------------------

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
