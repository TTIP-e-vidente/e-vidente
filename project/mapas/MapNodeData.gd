extends RefCounted

const NODE_KIND_CHAPTER := "chapter"
# El valor serializado sigue siendo "question" por compatibilidad con escenas ya armadas.
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


static func desde_diccionario(definicion_nodo: Dictionary) -> RefCounted:
	var datos_nodo: RefCounted = crear()
	datos_nodo.node_id = int(definicion_nodo.get(DICT_KEY_ID, 0))
	datos_nodo.node_kind = normalizar_tipo_nodo(
		str(definicion_nodo.get(DICT_KEY_KIND, NODE_KIND_CHAPTER))
	)
	datos_nodo.label_text = _leer_texto(definicion_nodo, DICT_KEY_LABEL)
	datos_nodo.track_key = _leer_texto(definicion_nodo, DICT_KEY_TRACK_KEY)
	datos_nodo.level_number = int(definicion_nodo.get(DICT_KEY_LEVEL_NUMBER, 0))
	datos_nodo.question_number = int(definicion_nodo.get(DICT_KEY_QUESTION_NUMBER, 0))
	datos_nodo.node_key = _leer_texto_con_legacy(
		definicion_nodo,
		DICT_KEY_NODE_KEY,
		DICT_KEY_LEGACY_QUESTION_KEY
	)
	datos_nodo.node_json_path = _leer_texto_con_legacy(
		definicion_nodo,
		DICT_KEY_NODE_JSON_PATH,
		DICT_KEY_LEGACY_QUESTION_JSON_PATH
	)
	datos_nodo.node_resource_path = _leer_texto_con_legacy(
		definicion_nodo,
		DICT_KEY_NODE_RESOURCE_PATH,
		DICT_KEY_LEGACY_QUESTION_RESOURCE_PATH
	)
	datos_nodo.icon_texture_path = _leer_texto(definicion_nodo, DICT_KEY_ICON_TEXTURE_PATH)
	datos_nodo.node_position = definicion_nodo.get(DICT_KEY_POSITION, Vector2.ZERO)
	return datos_nodo


static func desde_nodo_mapa(nodo_mapa: Node2D) -> RefCounted:
	if nodo_mapa == null or not nodo_mapa.has_method("crear_datos_runtime_nodo"):
		return null
	var datos_nodo_creados: Variant = nodo_mapa.call("crear_datos_runtime_nodo")
	if datos_nodo_creados is RefCounted:
		return datos_nodo_creados as RefCounted
	return null


static func duplicar_desde_nodo_mapa(nodo_mapa: Node2D) -> RefCounted:
	var datos_nodo: RefCounted = desde_nodo_mapa(nodo_mapa)
	if datos_nodo == null:
		return null
	return datos_nodo.duplicar_datos()


static func desde_seleccion(seleccion_mapa: Variant) -> RefCounted:
	if seleccion_mapa is Object and seleccion_mapa.has_method("duplicar_datos"):
		var datos_nodo_duplicados: Variant = seleccion_mapa.call("duplicar_datos")
		if datos_nodo_duplicados is RefCounted:
			return datos_nodo_duplicados as RefCounted
	if seleccion_mapa is Dictionary:
		return desde_diccionario(seleccion_mapa as Dictionary)
	if seleccion_mapa is Object and seleccion_mapa.has_method("a_diccionario"):
		var definicion_nodo_cruda: Variant = seleccion_mapa.call("a_diccionario")
		if definicion_nodo_cruda is Dictionary:
			return desde_diccionario(definicion_nodo_cruda as Dictionary)
	return null


static func normalizar_tipo_nodo(tipo_crudo: String) -> String:
	return (
		NODE_KIND_QUESTION
		if tipo_crudo.strip_edges().to_lower() == NODE_KIND_QUESTION
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


func es_nodo_jugable() -> bool:
	return node_kind == NODE_KIND_QUESTION


func es_capitulo() -> bool:
	return node_kind == NODE_KIND_CHAPTER


func tiene_destino_jugable() -> bool:
	var ruta_json_resuelta: String = resolver_ruta_json_nodo()
	if not ruta_json_resuelta.is_empty() and FileAccess.file_exists(ruta_json_resuelta):
		return true

	var ruta_recurso_resuelta: String = resolver_ruta_recurso_nodo()
	return not ruta_recurso_resuelta.is_empty() and ResourceLoader.exists(ruta_recurso_resuelta)


func tiene_destino_capitulo() -> bool:
	return level_number > 0


func tiene_destino_runtime() -> bool:
	if es_nodo_jugable():
		return tiene_destino_jugable()
	if es_capitulo():
		return tiene_destino_capitulo()
	return false


func obtener_nivel_id_sesion() -> int:
	return question_number if question_number > 0 else node_id


func obtener_clave_pista_o_default(clave_pista_default: String) -> String:
	return track_key if not track_key.is_empty() else clave_pista_default


func crear_contexto_sesion(clave_pista_resuelta: String, ruta_escena_retorno: String) -> Dictionary:
	var clave_nodo: String = resolver_clave_nodo()
	var ruta_json_nodo: String = resolver_ruta_json_nodo()
	var ruta_recurso_nodo: String = resolver_ruta_recurso_nodo()
	return {
		"track_key": clave_pista_resuelta,
		"nivel_id": obtener_nivel_id_sesion(),
		"node_key": clave_nodo,
		"node_json_path": ruta_json_nodo,
		"node_resource_path": ruta_recurso_nodo,
		"return_scene_path": ruta_escena_retorno
	}


func resolver_clave_nodo() -> String:
	var clave_explicita: String = node_key.strip_edges()
	if not clave_explicita.is_empty():
		return clave_explicita

	var clave_desde_json: String = _obtener_nombre_sin_extension(node_json_path)
	if not clave_desde_json.is_empty():
		return clave_desde_json

	return _obtener_nombre_sin_extension(node_resource_path)


func resolver_ruta_json_nodo() -> String:
	var ruta_explicita: String = NodeContentLegacyScript.resolver_ruta_json(
		node_json_path.strip_edges()
	)
	if not ruta_explicita.is_empty():
		return ruta_explicita

	var rutas_candidatas: Array[String] = _rutas_json_por_convencion()
	for ruta_candidata in rutas_candidatas:
		if FileAccess.file_exists(ruta_candidata):
			return ruta_candidata
	if rutas_candidatas.is_empty():
		return ""
	return rutas_candidatas[0]


func resolver_ruta_recurso_nodo() -> String:
	var ruta_explicita: String = node_resource_path.strip_edges()
	if not ruta_explicita.is_empty():
		return ruta_explicita

	var clave_resuelta: String = resolver_clave_nodo()
	if clave_resuelta.is_empty():
		return ""
	return "%s/%s.tres" % [DEFAULT_NODE_RESOURCE_DIR, clave_resuelta]


func _obtener_nombre_sin_extension(ruta_cruda: String) -> String:
	var ruta_limpia: String = ruta_cruda.strip_edges()
	if ruta_limpia.is_empty():
		return ""

	var nombre_archivo: String = ruta_limpia.get_file().strip_edges()
	var indice_extension: int = nombre_archivo.rfind(".")
	if indice_extension < 0:
		return nombre_archivo
	return nombre_archivo.substr(0, indice_extension)


func _rutas_json_por_convencion() -> Array[String]:
	var rutas_candidatas: Array[String] = []
	var clave_resuelta: String = resolver_clave_nodo()
	if clave_resuelta.is_empty():
		return rutas_candidatas

	var clave_pista_resuelta: String = track_key.strip_edges()
	if not clave_pista_resuelta.is_empty():
		rutas_candidatas.append(
			"%s/%s/%s.json" % [DEFAULT_NODE_JSON_DIR, clave_pista_resuelta, clave_resuelta]
		)
	rutas_candidatas.append("%s/%s.json" % [DEFAULT_NODE_JSON_DIR, clave_resuelta])
	return rutas_candidatas


static func _leer_texto(definicion_nodo: Dictionary, clave: String, fallback: String = "") -> String:
	return str(definicion_nodo.get(clave, fallback)).strip_edges()


static func _leer_texto_con_legacy(
	definicion_nodo: Dictionary,
	clave_principal: String,
	clave_legacy: String
) -> String:
	return _leer_texto(
		definicion_nodo,
		clave_principal,
		_leer_texto(definicion_nodo, clave_legacy)
	)
