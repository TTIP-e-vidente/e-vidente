extends RefCounted
class_name CargadorDeMapa

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const ContentNormalizerScript := preload("res://sistemas/contenido/ContentNormalizer.gd")
const ContentValidatorScript := preload("res://sistemas/contenido/ContentValidator.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const MapLayoutConfigScript := preload("res://mapas/layout/MapLayoutConfig.gd")
const NODE_JSON_ROOT := "res://contenido/nodos/"
const LOG_PREFIX := "[MAPA]"
const LOG_PREFIX_MAP_LOAD := "[MapLoad]"
const LOG_PREFIX_MAP_NODE := "[MapNode]"
const DIRECT_PLAYABLE_NODE_TYPES := [
	"receta_arrastre",
	"preguntas",
	"vinculacion",
]
const CONTENT_RULES_BY_MODE := {
	MapNodeData.MODE_QUIZ_CHOICE: {
		"root": NODE_JSON_ROOT,
		"folder": "/preguntas/",
	},
	MapNodeData.MODE_DRAG_DROP: {
		"root": NODE_JSON_ROOT,
		"folder": "/arrastre/",
	},
	MapNodeData.MODE_VINCULACION_CONCEPTOS: {
		"root": NODE_JSON_ROOT,
		"folder": "/vinculacion/",
	},
}

static func cargar_mapa(map_json_path: String) -> Dictionary:
	print("%s path=%s" % [LOG_PREFIX_MAP_LOAD, map_json_path])
	var raw_result: Dictionary = leer_archivo_json(map_json_path)
	if not bool(raw_result.get("ok", false)):
		print("%s error=%s" % [LOG_PREFIX_MAP_LOAD, str(raw_result.get("error", ""))])
		return raw_result

	return construir_datos_mapa(raw_result.get("data", {}), str(raw_result.get("path", map_json_path)))


static func leer_archivo_json(map_json_path: String) -> Dictionary:
	return ContentJsonLoaderScript.cargar_json(map_json_path)


static func construir_datos_mapa(raw_map: Dictionary, source_path: String = "") -> Dictionary:
	var normalizado_result: Dictionary = ContentNormalizerScript.normalizar(raw_map, source_path)
	var normalizado_map: Dictionary = normalizado_result.get("data", {})
	if ContentNormalizerScript.es_contenido_v1(normalizado_map):
		return _construir_mapa_v1(normalizado_map, source_path)

	if raw_map.get("nodes") is Dictionary:
		return _construir_mapa_v2(raw_map, source_path)

	var header_error: String = validar_encabezado_mapa(raw_map)
	if not header_error.is_empty():
		return _fallo(header_error)

	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("track_key", "")).strip_edges()
	var title: String = str(raw_map.get("title", "")).strip_edges()
	var nodes_result: Dictionary = construir_nodos(raw_map.get("nodes", []), track_key)
	if not bool(nodes_result.get("ok", false)):
		return nodes_result
	print(
		LOG_PREFIX,
		" legacy id=", map_id,
		" nodos=", (nodes_result.get("data", []) as Array).size()
	)

	return _exito({
		"id": map_id,
		"track_key": track_key,
		"title": title,
		"nodes": nodes_result.get("data", []),
	})


static func _construir_mapa_v1(raw_map: Dictionary, source_path: String) -> Dictionary:
	var validation_result: Dictionary = ContentValidatorScript.validar(raw_map, source_path)
	if not bool(validation_result.get("ok", false)):
		return _fallo(str(validation_result.get("error", "Mapa invalido.")))

	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("categoria", "")).strip_edges()
	var title: String = str(raw_map.get("titulo", "")).strip_edges()
	var nodes_result: Dictionary = construir_nodos(raw_map.get("nodos", []), track_key)
	if not bool(nodes_result.get("ok", false)):
		return nodes_result
	print(LOG_PREFIX, " v1 id=", map_id, " nodos=", (nodes_result.get("data", []) as Array).size())

	return _exito(
		{
			"id": map_id,
			"track_key": track_key,
			"title": title,
			"nodes": nodes_result.get("data", []),
		}
	)


static func validar_encabezado_mapa(raw_map: Dictionary) -> String:
	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("track_key", "")).strip_edges()
	var title: String = str(raw_map.get("title", "")).strip_edges()
	var raw_nodes: Variant = raw_map.get("nodes", null)
	if map_id.is_empty():
		return "El mapa necesita id."
	if track_key.is_empty():
		return "El mapa necesita track_key."
	if title.is_empty():
		return "El mapa necesita title."
	if not raw_nodes is Array:
		return "El mapa necesita nodes como array."
	return ""


static func construir_nodos(raw_nodes: Variant, track_key: String) -> Dictionary:
	if not raw_nodes is Array:
		return _fallo("El mapa necesita nodes como array.")
	var nodes: Array[MapNodeData] = []
	var seen_node_keys: Dictionary = {}
	for index in range((raw_nodes as Array).size()):
		var node_result: Dictionary = _construir_nodo((raw_nodes as Array)[index], track_key, index)
		if not bool(node_result.get("ok", false)):
			return node_result
		var node_data: MapNodeData = node_result.get("data") as MapNodeData
		var clean_node_key: String = node_data.node_key.strip_edges()
		if seen_node_keys.has(clean_node_key):
			return _fallo("El mapa repite node_key: %s" % clean_node_key)
		seen_node_keys[clean_node_key] = true
		nodes.append(node_data)
	return _exito(nodes)


static func _construir_nodo(raw_node: Variant, track_key: String, index: int) -> Dictionary:
	var node_number: int = index + 1
	if raw_node is String:
		return _construir_nodo_desde_referencia(
			{
				"id": str(raw_node).get_file().trim_suffix(".json"),
				"archivo": str(raw_node).strip_edges(),
			},
			track_key,
			index
		)
	if not raw_node is Dictionary:
		return _fallo("El nodo %d del mapa debe ser un objeto." % node_number)
	if _es_referencia_nodo_contenido(raw_node as Dictionary):
		return _construir_nodo_desde_referencia(raw_node as Dictionary, track_key, index)

	var node := MapNodeDataScript.desde_json(raw_node as Dictionary, track_key, index)
	var node_error: String = validar_nodo_mapa(node, node_number)
	if not node_error.is_empty():
		return _fallo(node_error)

	return _exito(node)


static func validar_nodo_mapa(node: MapNodeData, node_number: int = 0) -> String:
	var label: String = "El nodo"
	if node_number > 0:
		label = "El nodo %d" % node_number
	if node.node_key.is_empty():
		return "%s no tiene node_key." % label
	# Los games random no necesitan title/mode/json_path en el nodo.
	if node.tiene_solicitudes_juegos_random():
		return ""
	if node.title.is_empty():
		return "%s no tiene title." % label
	if node.mode.is_empty():
		return "%s no tiene mode." % label
	if not es_modo_mapa_soportado(node.mode):
		return "%s tiene mode no soportado: %s" % [label, node.mode]
	if not node.tiene_ruta_contenido():
		return "%s no tiene json_path ni activity_id." % label
	if node.tiene_juegos_fijos():
		var games_error: String = _validar_juegos_actividad(node, label)
		if not games_error.is_empty():
			if node.json_path.is_empty():
				return games_error
			push_warning("%s. Se usara json_path como fallback." % games_error)
	if not node.activity_id.is_empty():
		var pack_id: String = node.pack_id if not node.pack_id.is_empty() else node.track_key
		var activity_result: Dictionary = NodeContentLoaderScript.has_activity(
			pack_id,
			node.activity_id
		)
		if not bool(activity_result.get("ok", false)):
			var activity_error: String = "%s tiene activity_id invalido: %s" % [
				label,
				str(activity_result.get("error", "")),
			]
			if node.json_path.is_empty():
				return activity_error
			push_warning("%s. Se usara json_path como fallback." % activity_error)
		else:
			return ""
	if not node.node_file_path.is_empty() and not node.tiene_juegos_fijos():
		if not FileAccess.file_exists(node.json_path):
			return "No existe el JSON de %s: %s" % [label.to_lower(), node.json_path]
		return ""
	if node.tiene_juegos_fijos():
		for game_entry in node.obtener_juegos_fijos():
			var file_path: String = str(game_entry.get("archivo", "")).strip_edges()
			if file_path.is_empty() or not FileAccess.file_exists(file_path):
				return "No existe el JSON de %s: %s" % [label.to_lower(), file_path]
		return ""
	var content_rule: Dictionary = CONTENT_RULES_BY_MODE.get(node.mode, {})
	var expected_root: String = str(content_rule.get("root", NODE_JSON_ROOT)).strip_edges()
	if not node.json_path.begins_with(expected_root):
		return "%s debe apuntar a %s. Ruta actual: %s" % [label, expected_root, node.json_path]
	var expected_folder: String = str(content_rule.get("folder", "")).strip_edges()
	if not expected_folder.is_empty() and not node.json_path.contains(expected_folder):
		return "%s debe apuntar a %s para mode=%s. Ruta actual: %s" % [
			label,
			expected_folder,
			node.mode,
			node.json_path,
		]
	if not FileAccess.file_exists(node.json_path):
		return "No existe el JSON de %s: %s" % [label.to_lower(), node.json_path]
	return ""


static func _validar_juegos_actividad(node: MapNodeData, label: String) -> String:
	for game_entry in node.obtener_juegos_fijos():
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			continue
		var pack_id: String = str(
			game_entry.get(
				"pack_id",
				node.pack_id if not node.pack_id.is_empty() else node.track_key
			)
		).strip_edges()
		var activity_result: Dictionary = NodeContentLoaderScript.has_activity(pack_id, activity_id)
		if not bool(activity_result.get("ok", false)):
			return "%s tiene game activity_id invalido: %s" % [
				label,
				str(activity_result.get("error", "")),
			]
	return ""


static func _es_referencia_nodo_contenido(raw_node: Dictionary) -> bool:
	return not str(raw_node.get("archivo", "")).strip_edges().is_empty()


static func _construir_nodo_desde_referencia(
	raw_node: Dictionary,
	track_key: String,
	index: int
) -> Dictionary:
	var node_number: int = index + 1
	var node_path: String = str(raw_node.get("archivo", "")).strip_edges()
	var raw_result: Dictionary = ContentJsonLoaderScript.cargar_json(node_path)
	if not bool(raw_result.get("ok", false)):
		return _fallo(str(raw_result.get("error", "No se pudo cargar el nodo.")))

	var clean_path: String = str(raw_result.get("path", node_path)).strip_edges()
	var normalizado_result: Dictionary = ContentNormalizerScript.normalizar(
		raw_result.get("data", {}),
		clean_path
	)
	var normalizado_node: Dictionary = normalizado_result.get("data", {})
	if not ContentNormalizerScript.es_contenido_v1(normalizado_node):
		return _fallo("El nodo %d debe usar un archivo V1." % node_number)
	var node_type: String = str(normalizado_node.get("tipo", "")).strip_edges()
	if node_type != "nodo" and not DIRECT_PLAYABLE_NODE_TYPES.has(node_type):
		return _fallo("El archivo referenciado no es un nodo jugable valido: %s" % clean_path)

	var validation_result: Dictionary = ContentValidatorScript.validar(
		normalizado_node,
		clean_path
	)
	if not bool(validation_result.get("ok", false)):
		return _fallo(str(validation_result.get("error", "Nodo invalido.")))

	var node := MapNodeDataScript.desde_nodo_v1(
		normalizado_node,
		track_key,
		index,
		raw_node,
		clean_path
	)
	var node_error: String = validar_nodo_mapa(node, node_number)
	if not node_error.is_empty():
		return _fallo(node_error)
	print(
		LOG_PREFIX,
		" nodo_v1=", node.node_key,
		" juegos=", node.obtener_cantidad_juegos_fijos(),
		" mode=", node.mode,
		" json_path=", node.json_path
	)
	return _exito(node)


static func es_modo_mapa_soportado(mode: String) -> bool:
	return CONTENT_RULES_BY_MODE.has(mode.strip_edges())


static func _construir_mapa_v2(raw_map: Dictionary, source_path: String) -> Dictionary:
	# Mapa v2: usa nodes como Dictionary ordenado por claves "1", "2", "3".
	var track_key: String = str(
		raw_map.get("track", raw_map.get("track_key", ""))
	).strip_edges()
	if track_key.is_empty():
		return _fallo("El mapa v2 necesita campo 'track'.")
	if int(raw_map.get("version", 0)) <= 0:
		return _fallo("El mapa v2 necesita campo 'version'.")
	var nodes_dict: Dictionary = raw_map.get("nodes", {}) as Dictionary
	if nodes_dict.is_empty():
		return _fallo("El mapa v2 no tiene nodos.")
	var sorted_keys: Array[String] = []
	for raw_key in nodes_dict.keys():
		var order_key: String = str(raw_key).strip_edges()
		if not order_key.is_valid_int() or int(order_key) <= 0:
			return _fallo("El mapa v2 usa una clave de nodo invalida: %s" % order_key)
		sorted_keys.append(order_key)
	sorted_keys.sort_custom(func(a, b): return int(a) < int(b))
	var nodes: Array[MapNodeData] = []
	var seen_node_keys: Dictionary = {}
	for i in range(sorted_keys.size()):
		var order_key: String = str(sorted_keys[i])
		var raw_node_val: Variant = nodes_dict.get(order_key, {})
		if not raw_node_val is Dictionary:
			return _fallo("El nodo '%s' debe ser un objeto." % order_key)
		var node_result: Dictionary = _construir_nodo_v2(
			raw_node_val as Dictionary, track_key, i, order_key
		)
		if not bool(node_result.get("ok", false)):
			return node_result
		var node_data: MapNodeData = node_result.get("data") as MapNodeData
		var clean_node_key: String = node_data.node_key.strip_edges()
		if seen_node_keys.has(clean_node_key):
			return _fallo("El mapa repite node_key: %s" % clean_node_key)
		seen_node_keys[clean_node_key] = true
		nodes.append(node_data)
	if not source_path.is_empty():
		print("%s path=%s" % [LOG_PREFIX_MAP_LOAD, source_path])
	print("%s nodes=%d" % [LOG_PREFIX_MAP_LOAD, nodes.size()])

	var layout_config: MapLayoutConfig = null
	var raw_layout: Variant = raw_map.get("layout", null)
	if raw_layout is Dictionary:
		layout_config = MapLayoutConfigScript.desde_json(raw_layout as Dictionary)

	return _exito({
		"id": track_key,
		"track_key": track_key,
		"title": track_key,
		"nodes": nodes,
		"layout_config": layout_config,
	})


static func _construir_nodo_v2(
	raw_node: Dictionary,
	track_key: String,
	index: int,
	order_key: String
) -> Dictionary:
	# Cada nodo v2 usa node_key + games + shuffle_games.
	# Valida que games sea homogeneo:
	# - todos String => fixed
	# - todos Dictionary => random
	# - mezcla => error controlado
	var node_key: String = str(raw_node.get("node_key", "")).strip_edges()
	if node_key.is_empty():
		return _fallo("El nodo '%s' no tiene node_key." % order_key)
	var raw_games: Variant = raw_node.get("games", [])
	var raw_legacy_game_slots: Variant = raw_node.get("game_slots", [])
	var has_games: bool = raw_games is Array and not (raw_games as Array).is_empty()
	var has_legacy_random_games: bool = (
		raw_legacy_game_slots is Array and not (raw_legacy_game_slots as Array).is_empty()
	)
	var games_style: String = ""
	if has_games:
		games_style = _detectar_estilo_juegos_v2(raw_games as Array)
	if raw_node.has("game_slots") and not raw_legacy_game_slots is Array:
		return _fallo("Nodo '%s': game_slots debe ser array." % node_key)
	if raw_node.has("games") and not raw_games is Array:
		return _fallo("Nodo '%s': games debe ser array." % node_key)
	if not has_games and not has_legacy_random_games:
		return _fallo("El nodo '%s' necesita games." % node_key)
	if has_games and games_style == "invalid":
		return _fallo("Nodo '%s': games tiene formato invalido." % node_key)
	if has_games and games_style == "mixed":
		push_warning("[MapNode] node=%s games mezcla strings y requests random." % node_key)
		return _fallo(
			"Nodo '%s': games mezcla strings y requests random. Usar un solo tipo." % node_key
		)
	if has_games and games_style == "fixed":
		var games_error: String = _validar_juegos_fijos_v2(raw_games as Array, node_key)
		if not games_error.is_empty():
			return _fallo(games_error)
	if has_games and games_style == "random":
		var requests_error: String = _validar_solicitudes_random_v2(
			raw_games as Array,
			node_key,
			"games"
		)
		if not requests_error.is_empty():
			return _fallo(requests_error)
	if not has_games and has_legacy_random_games:
		push_warning(
			"[MapNode] game_slots legacy detectado. Usar games con objetos random. node=%s"
			% node_key
		)
		var legacy_requests_error: String = _validar_solicitudes_random_v2(
			raw_legacy_game_slots as Array,
			node_key,
			"game_slots"
		)
		if not legacy_requests_error.is_empty():
			return _fallo(legacy_requests_error)
	if has_games and has_legacy_random_games:
		push_warning("Nodo '%s' define games y game_slots. Se prefiere games." % node_key)
	if raw_node.has("shuffle_games") and not (raw_node.get("shuffle_games") is bool):
		return _fallo("Nodo '%s': shuffle_games debe ser bool." % node_key)
	var node: MapNodeData = MapNodeDataScript.desde_json(raw_node, track_key, index)
	if node.title.is_empty():
		node.title = "Nodo %d" % (index + 1)
	if node.usa_juegos_fijos():
		var node_error: String = _hidratar_juegos_fijos_v2(node, track_key)
		if not node_error.is_empty():
			return _fallo(node_error)
		if not node.tiene_ruta_contenido():
			return _fallo("Nodo '%s': games no contiene activity_id valido." % node_key)
		if node.mode.is_empty():
			return _fallo(
				"Nodo '%s': no se pudo determinar mode (activity_id='%s')." % [
					node_key, node.activity_id
				]
			)
		if not es_modo_mapa_soportado(node.mode):
			return _fallo("Nodo '%s' tiene mode no soportado: %s." % [node_key, node.mode])
		print(
			"%s order=%d mode=fixed games=%d shuffle=%s"
			% [
				LOG_PREFIX_MAP_NODE,
				node.order,
				node.obtener_cantidad_juegos_fijos(),
				str(node.shuffle_games),
			]
		)
		return _exito(node)
	print(
		"%s order=%d mode=random requests=%d shuffle=%s"
		% [
			LOG_PREFIX_MAP_NODE,
			node.order,
			node.obtener_cantidad_solicitudes_random(),
			str(node.shuffle_games),
		]
	)
	return _exito(node)


static func _validar_juegos_fijos_v2(raw_games: Array, node_key: String) -> String:
	for game_index in range(raw_games.size()):
		var raw_game: Variant = raw_games[game_index]
		if raw_game is String:
			if str(raw_game).strip_edges().is_empty():
				return "Nodo '%s': games[%d] no puede ser string vacio." % [node_key, game_index]
			continue
		if not raw_game is Dictionary:
			return "Nodo '%s': games[%d] debe ser string u objeto." % [node_key, game_index]
		var game: Dictionary = raw_game as Dictionary
		var activity_id: String = str(game.get("activity_id", "")).strip_edges()
		var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
		if activity_id.is_empty() and file_path.is_empty():
			return "Nodo '%s': games[%d] necesita activity_id o json_path." % [node_key, game_index]
	return ""


static func _validar_solicitudes_random_v2(
	raw_games: Array,
	node_key: String,
	field_name: String
) -> String:
	for game_index in range(raw_games.size()):
		var raw_slot: Variant = raw_games[game_index]
		if not raw_slot is Dictionary:
			return "Nodo '%s': %s[%d] debe ser objeto." % [node_key, field_name, game_index]
		var slot: Dictionary = raw_slot as Dictionary
		if _parece_juego_explicito_v2(slot):
			return "Nodo '%s': %s[%d] no puede mezclar game explicito con request random." % [
				node_key,
				field_name,
				game_index,
			]
		var slot_type: String = _normalizar_tipo_random_v2(
			str(slot.get("type", slot.get("mode", ""))).strip_edges()
		)
		if slot_type.is_empty():
			return "Nodo '%s': %s[%d] tiene type invalido." % [node_key, field_name, game_index]
		var difficulty: int = int(slot.get("difficulty", slot.get("dificultad", 0)))
		if difficulty < 1 or difficulty > 3:
			return "Nodo '%s': %s[%d] tiene difficulty invalida." % [
				node_key,
				field_name,
				game_index,
			]
	return ""


static func _detectar_estilo_juegos_v2(raw_games: Array) -> String:
	var has_fixed_games := false
	var has_random_games := false
	for raw_game in raw_games:
		if raw_game is String:
			has_fixed_games = true
			continue
		if not raw_game is Dictionary:
			return "invalid"
		var game: Dictionary = raw_game as Dictionary
		if _parece_solicitud_random_v2(game):
			has_random_games = true
			continue
		if _parece_juego_explicito_v2(game):
			has_fixed_games = true
			continue
		return "invalid"
	if has_fixed_games and has_random_games:
		return "mixed"
	if has_fixed_games:
		return "fixed"
	if has_random_games:
		return "random"
	return "invalid"


static func _parece_solicitud_random_v2(game: Dictionary) -> bool:
	if _parece_juego_explicito_v2(game):
		return false
	return not _normalizar_tipo_random_v2(
		str(game.get("type", game.get("mode", ""))).strip_edges()
	).is_empty()


static func _parece_juego_explicito_v2(game: Dictionary) -> bool:
	var activity_id: String = str(game.get("activity_id", "")).strip_edges()
	var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
	return not activity_id.is_empty() or not file_path.is_empty()


static func _normalizar_tipo_random_v2(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"drag", "drag_food":
			return "drag"
		"quiz":
			return "quiz"
		"match", "vinculacion":
			return "match"
		"completar_palabra":
			return "completar_palabra"
		_:
			return ""


static func _hidratar_juegos_fijos_v2(node: MapNodeData, track_key: String) -> String:
	# Resuelve pack_id y mode de los games fijos sin abrir escenas ni alterar el JSON original.
	if node == null or not node.tiene_juegos_fijos():
		return "Nodo sin games validos."

	var first_fixed: Dictionary = {}
	for game_index in range(node.games.size()):
		if MapNodeData.es_solicitud_juego_random(node.games[game_index]):
			continue
		var game_entry: Dictionary = (node.games[game_index] as Dictionary).duplicate(true)
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			return "Nodo '%s': games no contiene activity_id valido." % node.node_key
		var pack_id: String = str(game_entry.get("pack_id", "")).strip_edges()
		if pack_id.is_empty():
			pack_id = node.obtener_pack_id_efectivo(track_key)
		var activity_result: Dictionary = NodeContentLoaderScript.cargar_actividad(
			pack_id,
			activity_id
		)
		if not bool(activity_result.get("ok", false)):
			return "Nodo '%s': game '%s' invalido: %s" % [
				node.node_key,
				activity_id,
				str(activity_result.get("error", "")),
			]
		var activity_data: Dictionary = activity_result.get("data", {})
		var mode: String = NodeContentLoaderScript.to_runtime_mode(
			str(activity_data.get("mode", "")).strip_edges()
		)
		if not es_modo_mapa_soportado(mode):
			return "Nodo '%s': game '%s' tiene mode no soportado." % [
				node.node_key,
				activity_id,
			]
		game_entry["activity_id"] = activity_id
		game_entry["pack_id"] = pack_id
		game_entry["mode"] = mode
		game_entry["tipo"] = mode
		node.games[game_index] = game_entry
		if first_fixed.is_empty():
			first_fixed = game_entry

	node.activity_id = str(first_fixed.get("activity_id", "")).strip_edges()
	node.pack_id = str(
		first_fixed.get("pack_id", node.obtener_pack_id_efectivo(track_key))
	).strip_edges()
	node.mode = str(first_fixed.get("mode", "")).strip_edges()
	return ""


static func _exito(data: Variant) -> Dictionary:
	return {"ok": true, "error": "", "data": data}


static func _fallo(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
