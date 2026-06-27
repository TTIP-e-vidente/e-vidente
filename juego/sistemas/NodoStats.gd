extends RefCounted

const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")
const _ResultadoScript := preload("res://modalidades/ResultadoDeMiniJuego.gd")

static func registrar(tree: SceneTree, resultado: Dictionary) -> void:
	var global_state: Node = _global(tree)
	if global_state == null:
		return
	var intentos: int = int(resultado.get("attempts", resultado.get("intentos", 1)))
	var correctos: int = int(resultado.get("correct", resultado.get("correctos", resultado.get("aciertos", 0))))
	var errores: int = int(resultado.get("errors", resultado.get("errores", 0)))
	# Normalizar: si no hay attempts explícito, deducirlo
	if intentos <= 0:
		intentos = correctos + errores
	if intentos <= 0:
		intentos = 1
	# Registrar cada intento individualmente en el acumulador de Global
	if global_state.has_method("registrar_resultado_mini_juego"):
		for _i in range(correctos):
			global_state.call("registrar_resultado_mini_juego", true)
		for _i in range(errores):
			global_state.call("registrar_resultado_mini_juego", false)
	elif global_state.has_method("registrar_resultado_mini_juego_multiple"):
		global_state.call("registrar_resultado_mini_juego_multiple", correctos, errores)


## Deduce intentos desde aciertos+errores cuando el contador quedó en 0.
static func normalizar_stats_dict(stats: Dictionary) -> Dictionary:
	var normalizado: Dictionary = stats.duplicate(true)
	var aciertos: int = int(normalizado.get("aciertos", 0))
	var errores: int = int(normalizado.get("errores", 0))
	var intentos: int = int(normalizado.get("intentos", 0))
	if intentos <= 0:
		var deducidos: int = aciertos + errores
		if deducidos > 0:
			normalizado["intentos"] = deducidos
	return normalizado


## Devuelve todos los stats acumulados del nodo activo.
static func obtener_estadisticas(tree: SceneTree) -> Dictionary:
	var global_state: Node = _global(tree)
	if global_state == null or not global_state.has_method("obtener_stats_nodo_actual"):
		return {"aciertos": 0, "errores": 0, "intentos": 0}
	return normalizar_stats_dict(global_state.call("obtener_stats_nodo_actual"))


## Precisión como porcentaje entero 0–100.
static func obtener_precision(tree: SceneTree) -> int:
	var s: Dictionary = obtener_estadisticas(tree)
	return NodoProgressionRulesScript.calcular_precision(
		int(s.get("aciertos", 0)),
		int(s.get("intentos", 0))
	)


## Porcentaje de error como entero 0–100.
static func get_error_percent(tree: SceneTree) -> int:
	var s: Dictionary = obtener_estadisticas(tree)
	return NodoProgressionRulesScript.calculate_error_percent(
		int(s.get("errores", 0)),
		int(s.get("intentos", 0))
	)


## Duración en milisegundos desde que inició el nodo (0 si no hay nodo activo).
static func get_duration_ms(tree: SceneTree) -> int:
	var global_state: Node = _global(tree)
	if global_state == null:
		return 0
	if global_state.has_method("obtener_duracion_nodo_ms"):
		return int(global_state.call("obtener_duracion_nodo_ms"))
	# Fallback: calcular desde el timestamp de inicio guardado en Global
	var inicio: int = int(global_state.get("_inicio_nodo_msec")) if "_inicio_nodo_msec" in global_state else 0
	if inicio <= 0:
		return 0
	return Time.get_ticks_msec() - inicio


## Duración formateada como "M:SS".
static func obtener_duracion_formateada(tree: SceneTree) -> String:
	var global_state: Node = _global(tree)
	if global_state != null and global_state.has_method("obtener_tiempo_nodo_formato"):
		return str(global_state.call("obtener_tiempo_nodo_formato")).strip_edges()
	return NodoProgressionRulesScript.formatear_duracion(get_duration_ms(tree))


## Bridge: registra un ResultadoDeMiniJuego en el acumulador global.
static func registrar_resultado_de_mini_juego(tree: SceneTree, resultado: ResultadoDeMiniJuego) -> void:
	if resultado == null:
		return
	registrar(tree, resultado.a_diccionario())


static func _global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")
