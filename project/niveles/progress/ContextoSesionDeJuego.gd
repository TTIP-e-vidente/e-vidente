extends RefCounted

# ContextoSesionDeJuego.gd
# Normaliza el contexto que consumen las escenas jugables.
# Compatibilidad: mantiene claves nuevas y legacy hasta limpiar escenas antiguas.

static func obtener_contexto_jugable_actual() -> Dictionary:
	var global_autoload: Node = obtener_global()
	if global_autoload == null:
		return {}

	if global_autoload.has_method("obtener_juego_actual_de_partida"):
		var juego_actual: Variant = global_autoload.call("obtener_juego_actual_de_partida")
		if juego_actual is Dictionary and not (juego_actual as Dictionary).is_empty():
			return (juego_actual as Dictionary).duplicate(true)

	if global_autoload.has_method("obtener_sesion_nodo_jugable_activo"):
		var sesion_activa: Variant = global_autoload.call("obtener_sesion_nodo_jugable_activo")
		if sesion_activa is Dictionary:
			return (sesion_activa as Dictionary).duplicate(true)

	return {}


static func normalizar_contexto_jugable(
	contexto_sesion: Dictionary,
	pista_predeterminada: String,
	nivel_predeterminado: int,
	escena_retorno_predeterminada: String
) -> Dictionary:
	if contexto_sesion.is_empty():
		return {}

	var contexto_normalizado: Dictionary = contexto_sesion.duplicate(true)
	var clave_pista: String = str(contexto_sesion.get("track_key", pista_predeterminada)).strip_edges()
	var numero_nivel: int = int(
		contexto_sesion.get("level_number", contexto_sesion.get("nivel_id", nivel_predeterminado))
	)
	var clave_nodo: String = str(contexto_sesion.get("node_key", "")).strip_edges()
	var titulo_nodo: String = str(
		contexto_sesion.get("node_title", contexto_sesion.get("titulo_nodo", ""))
	).strip_edges()
	var ruta_json: String = str(contexto_sesion.get("json_path", "")).strip_edges()
	var activity_id: String = str(contexto_sesion.get("activity_id", "")).strip_edges()
	var pack_id: String = str(contexto_sesion.get("pack_id", clave_pista)).strip_edges()
	var modo: String = str(contexto_sesion.get("mode", contexto_sesion.get("node_mode", ""))).strip_edges()
	var escena_retorno: String = _leer_escena_retorno(
		contexto_sesion,
		escena_retorno_predeterminada
	)
	var pertenece_a_partida_de_nodo: bool = bool(
		contexto_sesion.get("pertenece_a_partida_de_nodo", false)
	)

	contexto_normalizado["track_key"] = clave_pista
	contexto_normalizado["level_number"] = numero_nivel
	contexto_normalizado["nivel_id"] = numero_nivel
	contexto_normalizado["node_key"] = clave_nodo
	contexto_normalizado["node_title"] = titulo_nodo
	contexto_normalizado["titulo_nodo"] = titulo_nodo
	contexto_normalizado["json_path"] = ruta_json
	contexto_normalizado["activity_id"] = activity_id
	contexto_normalizado["pack_id"] = pack_id
	contexto_normalizado["mode"] = modo
	contexto_normalizado["node_mode"] = modo
	contexto_normalizado["return_to"] = escena_retorno
	contexto_normalizado["pertenece_a_partida_de_nodo"] = pertenece_a_partida_de_nodo
	contexto_normalizado["came_from_map"] = not clave_nodo.is_empty()
	return contexto_normalizado


static func obtener_modelo_indicador_actual() -> Dictionary:
	var global_autoload: Node = obtener_global()
	if global_autoload == null or not global_autoload.has_method("obtener_contexto_de_progreso_de_juego"):
		return construir_modelo_indicador({})

	var contexto: Variant = global_autoload.call("obtener_contexto_de_progreso_de_juego")
	if contexto is Dictionary:
		return construir_modelo_indicador(contexto as Dictionary)
	return construir_modelo_indicador({})


static func construir_modelo_indicador(contexto: Dictionary) -> Dictionary:
	return {
		"titulo": str(contexto.get("titulo", contexto.get("titulo_nodo", ""))).strip_edges(),
		"actual": int(contexto.get("actual", contexto.get("indice_juego_actual", 1))),
		"total": int(contexto.get("total", contexto.get("total_juegos", 1))),
	}


static func leer_track_key(ctx: Dictionary, predeterminado: String = "") -> String:
	return ctx.get("track_key", predeterminado)


static func leer_nivel_id(ctx: Dictionary, predeterminado: int = 1) -> int:
	return ctx.get("level_number", predeterminado)


static func leer_node_key(ctx: Dictionary) -> String:
	return ctx.get("node_key", "")


static func leer_return_to(ctx: Dictionary, predeterminado: String = "") -> String:
	return ctx.get("return_to", predeterminado)


static func leer_pertenece_a_nodo(ctx: Dictionary) -> bool:
	return ctx.get("pertenece_a_partida_de_nodo", false)


static func leer_came_from_map(ctx: Dictionary) -> bool:
	return ctx.get("came_from_map", false)


static func _leer_escena_retorno(
	contexto_sesion: Dictionary,
	escena_retorno_predeterminada: String
) -> String:
	var escena_retorno: String = ""
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var router: Node = (main_loop as SceneTree).root.get_node_or_null("GameSceneRouter")
		if router != null and router.has_method("read_return_to"):
			escena_retorno = router.call("read_return_to", contexto_sesion, escena_retorno_predeterminada)
	
	if escena_retorno.is_empty():
		return escena_retorno_predeterminada
	return escena_retorno


static func obtener_global() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	var scene_tree: SceneTree = main_loop as SceneTree
	if scene_tree.root == null:
		return null
	return scene_tree.root.get_node_or_null("/root/Global")


static func obtener_save_manager() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	var scene_tree: SceneTree = main_loop as SceneTree
	if scene_tree.root == null:
		return null
	return scene_tree.root.get_node_or_null("/root/SaveManager")
