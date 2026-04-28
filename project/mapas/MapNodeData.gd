extends RefCounted

const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"
const SCRIPT_PATH := "res://mapas/MapNodeData.gd"
const NodeContentLegacyScript := preload("res://preguntas/NodeContentLegacy.gd")
const DICT_KEY_ID := "id"
const DICT_KEY_KIND := "kind"
const DICT_KEY_LABEL := "label"
const DICT_KEY_TRACK_KEY := "track_key"
const DICT_KEY_LEVEL_NUMBER := "level_number"
const DICT_KEY_QUESTION_NUMBER := "question_number"
const DICT_KEY_NODE_KEY := "node_key"
const DICT_KEY_NODE_JSON_PATH := "node_json_path"
const DICT_KEY_NODE_RESOURCE_PATH := "node_resource_path"
# TODO post-demo: eliminar lectura legacy cuando no haya escenas o diccionarios usando question_*.
const DICT_KEY_LEGACY_QUESTION_KEY := "question_key"
const DICT_KEY_LEGACY_QUESTION_JSON_PATH := "question_json_path"
const DICT_KEY_LEGACY_QUESTION_RESOURCE_PATH := "question_resource_path"
const DICT_KEY_ICON_TEXTURE_PATH := "icon_texture_path"
const DICT_KEY_POSITION := "pos"
const DEFAULT_NODE_JSON_DIR := "res://niveles/nodos"
const DEFAULT_NODE_RESOURCE_DIR := "res://preguntas/preguntas_recurso"

var node_id: int = 0
var node_kind: String = NODE_KIND_CHAPTER
var label_text: String = ""
var track_key: String = ""
var level_number: int = 0
var question_number: int = 0
var node_key: String = ""
var node_json_path: String = ""
var node_resource_path: String = ""
var icon_texture_path: String = ""
var node_position: Vector2 = Vector2.ZERO


static func crear() -> RefCounted:
	return load(SCRIPT_PATH).new()


static func desde_diccionario(node_definition: Dictionary) -> RefCounted:
	var node_data: RefCounted = crear()
	node_data.node_id = int(node_definition.get(DICT_KEY_ID, 0))
	node_data.node_kind = normalizar_tipo_nodo(
		str(node_definition.get(DICT_KEY_KIND, NODE_KIND_CHAPTER))
	)
	node_data.label_text = str(node_definition.get(DICT_KEY_LABEL, "")).strip_edges()
	node_data.track_key = str(node_definition.get(DICT_KEY_TRACK_KEY, "")).strip_edges()
	node_data.level_number = int(node_definition.get(DICT_KEY_LEVEL_NUMBER, 0))
	node_data.question_number = int(node_definition.get(DICT_KEY_QUESTION_NUMBER, 0))
	node_data.node_key = str(
		node_definition.get(DICT_KEY_NODE_KEY, node_definition.get(DICT_KEY_LEGACY_QUESTION_KEY, ""))
	).strip_edges()
	node_data.node_json_path = str(
		node_definition.get(
			DICT_KEY_NODE_JSON_PATH,
			node_definition.get(DICT_KEY_LEGACY_QUESTION_JSON_PATH, "")
		)
	).strip_edges()
	node_data.node_resource_path = str(
		node_definition.get(
			DICT_KEY_NODE_RESOURCE_PATH,
			node_definition.get(DICT_KEY_LEGACY_QUESTION_RESOURCE_PATH, "")
		)
	).strip_edges()
	node_data.icon_texture_path = str(node_definition.get(DICT_KEY_ICON_TEXTURE_PATH, "")).strip_edges()
	node_data.node_position = node_definition.get(DICT_KEY_POSITION, Vector2.ZERO)
	return node_data


static func desde_nodo_mapa(map_node: Node2D) -> RefCounted:
	if map_node == null or not map_node.has_method("crear_datos_runtime_nodo"):
		return null
	var built_node_data: Variant = map_node.call("crear_datos_runtime_nodo")
	if built_node_data is RefCounted:
		return built_node_data as RefCounted
	return null


static func duplicar_desde_nodo_mapa(map_node: Node2D) -> RefCounted:
	var node_data: RefCounted = desde_nodo_mapa(map_node)
	if node_data == null:
		return null
	return node_data.duplicar_datos()


static func desde_seleccion(selected_target: Variant) -> RefCounted:
	if selected_target is Object and selected_target.has_method("duplicar_datos"):
		var duplicated_node_data: Variant = selected_target.call("duplicar_datos")
		if duplicated_node_data is RefCounted:
			return duplicated_node_data as RefCounted
	if selected_target is Dictionary:
		return desde_diccionario(selected_target as Dictionary)
	if selected_target is Object and selected_target.has_method("a_diccionario"):
		var raw_node_definition: Variant = selected_target.call("a_diccionario")
		if raw_node_definition is Dictionary:
			return desde_diccionario(raw_node_definition as Dictionary)
	return null


static func normalizar_tipo_nodo(raw_kind: String) -> String:
	return (
		NODE_KIND_QUESTION
		if raw_kind.strip_edges().to_lower() == NODE_KIND_QUESTION
		else NODE_KIND_CHAPTER
	)


func duplicar_datos() -> RefCounted:
	return desde_diccionario(a_diccionario())


func a_diccionario() -> Dictionary:
	return {
		DICT_KEY_ID: node_id,
		DICT_KEY_KIND: node_kind,
		DICT_KEY_LABEL: label_text,
		DICT_KEY_TRACK_KEY: track_key,
		DICT_KEY_LEVEL_NUMBER: level_number,
		DICT_KEY_QUESTION_NUMBER: question_number,
		DICT_KEY_NODE_KEY: node_key,
		DICT_KEY_NODE_JSON_PATH: node_json_path,
		DICT_KEY_NODE_RESOURCE_PATH: node_resource_path,
		DICT_KEY_ICON_TEXTURE_PATH: icon_texture_path,
		DICT_KEY_POSITION: node_position,
	}


func es_pregunta() -> bool:
	return node_kind == NODE_KIND_QUESTION


func es_capitulo() -> bool:
	return node_kind == NODE_KIND_CHAPTER


func tiene_destino_jugable() -> bool:
	var resolved_json_path: String = resolver_ruta_json_nodo()
	if not resolved_json_path.is_empty() and FileAccess.file_exists(resolved_json_path):
		return true

	var resolved_resource_path: String = resolver_ruta_recurso_nodo()
	return not resolved_resource_path.is_empty() and ResourceLoader.exists(resolved_resource_path)


func tiene_destino_capitulo() -> bool:
	return level_number > 0


func tiene_destino_runtime() -> bool:
	if es_pregunta():
		return tiene_destino_jugable()
	if es_capitulo():
		return tiene_destino_capitulo()
	return false


func obtener_nivel_id_sesion() -> int:
	return question_number if question_number > 0 else node_id


func obtener_clave_pista_o_default(default_track_key: String) -> String:
	return track_key if not track_key.is_empty() else default_track_key


func crear_contexto_sesion(resolved_track_key: String, return_scene_path: String) -> Dictionary:
	var node_key: String = resolver_clave_nodo()
	var node_json_path: String = resolver_ruta_json_nodo()
	var node_resource_path: String = resolver_ruta_recurso_nodo()
	return {
		"track_key": resolved_track_key,
		"nivel_id": obtener_nivel_id_sesion(),
		"node_key": node_key,
		"node_json_path": node_json_path,
		"node_resource_path": node_resource_path,
		"return_scene_path": return_scene_path
	}


func resolver_clave_nodo() -> String:
	var explicit_key: String = node_key.strip_edges()
	if not explicit_key.is_empty():
		return explicit_key

	var json_key: String = _obtener_nombre_sin_extension(node_json_path)
	if not json_key.is_empty():
		return json_key

	return _obtener_nombre_sin_extension(node_resource_path)


func resolver_ruta_json_nodo() -> String:
	var explicit_path: String = NodeContentLegacyScript.resolver_ruta_json(
		node_json_path.strip_edges()
	)
	if not explicit_path.is_empty():
		return explicit_path

	var candidate_paths: Array[String] = _rutas_json_por_convencion()
	for candidate_path in candidate_paths:
		if FileAccess.file_exists(candidate_path):
			return candidate_path
	if candidate_paths.is_empty():
		return ""
	return candidate_paths[0]


func resolver_ruta_recurso_nodo() -> String:
	var explicit_path: String = node_resource_path.strip_edges()
	if not explicit_path.is_empty():
		return explicit_path

	var resolved_key: String = resolver_clave_nodo()
	if resolved_key.is_empty():
		return ""
	return "%s/%s.tres" % [DEFAULT_NODE_RESOURCE_DIR, resolved_key]


func _obtener_nombre_sin_extension(raw_path: String) -> String:
	var clean_path: String = raw_path.strip_edges()
	if clean_path.is_empty():
		return ""

	var file_name: String = clean_path.get_file().strip_edges()
	var extension_index: int = file_name.rfind(".")
	if extension_index < 0:
		return file_name
	return file_name.substr(0, extension_index)


func _rutas_json_por_convencion() -> Array[String]:
	var candidate_paths: Array[String] = []
	var resolved_key: String = resolver_clave_nodo()
	if resolved_key.is_empty():
		return candidate_paths

	var resolved_track_key: String = track_key.strip_edges()
	if not resolved_track_key.is_empty():
		candidate_paths.append("%s/%s/%s.json" % [DEFAULT_NODE_JSON_DIR, resolved_track_key, resolved_key])
	candidate_paths.append("%s/%s.json" % [DEFAULT_NODE_JSON_DIR, resolved_key])
	return candidate_paths
