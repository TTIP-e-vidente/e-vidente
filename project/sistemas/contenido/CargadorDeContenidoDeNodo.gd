extends RefCounted
class_name CargadorDeContenidoDeNodo

# LEGACY_COMPAT: Usado por Level.gd, QuestionJsonLoader y NodeContentLoader (fallback).
# No agregar lógica nueva aquí; el contenido nuevo entra por NodeContentLoader.

# Carga contenido legacy desde json_path y lo deja en formato runtime.
# El contenido nuevo entra por NodeContentLoader y ActivityAdapter.

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const ContentNormalizerScript := preload("res://sistemas/contenido/ContentNormalizer.gd")
const ContentValidatorScript := preload("res://sistemas/contenido/ContentValidator.gd")
const GameContentFactoryScript := preload("res://sistemas/contenido/GameContentFactory.gd")
const AdaptadorContenidoViejoScript := preload(
	"res://sistemas/contenido/AdaptadorContenidoViejo.gd"
)
const ValidadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/ValidadorDeContenidoDeNodo.gd"
)

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"
const MODE_VINCULACION_CONCEPTOS := "vinculacion_conceptos"


static func cargar_desde_nodo(datos_nodo: Variant) -> Dictionary:
	if datos_nodo == null:
		return _error("Falta el nodo.")

	var ruta_json: String = str(datos_nodo.get("json_path", "")).strip_edges()
	if ruta_json.is_empty():
		return _error("El nodo no tiene json_path.")

	return cargar_desde_ruta(ruta_json)


static func cargar_desde_ruta(ruta_json: String) -> Dictionary:
	var raw_result: Dictionary = ContentJsonLoaderScript.load_json(ruta_json)
	if not bool(raw_result.get("ok", false)):
		return _error(str(raw_result.get("error", "No se pudo cargar el contenido.")))

	var clean_path: String = str(raw_result.get("path", ruta_json)).strip_edges()
	var datos_crudos: Dictionary = raw_result.get("data", {})
	var normalized_result: Dictionary = ContentNormalizerScript.normalize(datos_crudos, clean_path)
	var datos_adaptados: Dictionary = normalized_result.get("data", {})

	if ContentNormalizerScript.is_v1_content(datos_adaptados):
		var validation_result: Dictionary = ContentValidatorScript.validate(
			datos_adaptados,
			clean_path
		)
		if not bool(validation_result.get("ok", false)):
			return _error(str(validation_result.get("error", "Contenido invalido.")))

		var runtime_result: Dictionary = GameContentFactoryScript.create_runtime_game(
			datos_adaptados,
			clean_path
		)
		if not bool(runtime_result.get("ok", false)):
			return _error(str(runtime_result.get("error", "No se pudo convertir el contenido.")))
		datos_adaptados = runtime_result.get("data", {})

	var error_validacion: String = ValidadorDeContenidoDeNodoScript.validar(datos_adaptados)
	if not error_validacion.is_empty():
		push_error("CargadorDeContenidoDeNodo: " + error_validacion)
		return _error(error_validacion)

	return _ok(ValidadorDeContenidoDeNodoScript.limpiar(datos_adaptados))


static func cargar_contenido_nodo(ruta_json_nodo: String) -> Dictionary:
	return cargar_desde_ruta(ruta_json_nodo)


static func convertir_arrastre_a_runtime(datos_nodo: Dictionary) -> Dictionary:
	# Compatibilidad temporal: las escenas jugables todavia usan este helper.
	if datos_nodo.is_empty():
		return _error("Nodo vacio o invalido.")

	var modo: String = str(datos_nodo.get("mode", "")).strip_edges()
	if modo != MODE_DRAG_DROP:
		return _error("El nodo no es de tipo drag_drop.")

	var contenido: Variant = datos_nodo.get("content", {})
	if not contenido is Dictionary:
		return _error("Falta la clave content en el JSON de arrastre.")

	var items_variant: Variant = contenido.get("items", [])
	var targets_variant: Variant = contenido.get("targets", [])
	if not items_variant is Array or not targets_variant is Array:
		return _error("El JSON de arrastre requiere 'items' y 'targets' como Arrays.")

	var items: Array = items_variant as Array
	var targets: Array = targets_variant as Array
	if items.is_empty() or targets.is_empty():
		return _error("El JSON de arrastre requiere 'items' y 'targets' no vacios.")

	var datos_runtime := {
		"node_key": str(datos_nodo.get("id", "")).strip_edges(),
		"teaching_key": str(
			contenido.get("teaching_key", datos_nodo.get("teaching_key", ""))
		).strip_edges(),
		"instruction": str(contenido.get("instruction", "")).strip_edges(),
		"items": items.duplicate(true),
		"targets": targets.duplicate(true),
	}
	_agregar_configuracion_arrastre_a_runtime(datos_runtime, contenido)
	return _ok(datos_runtime)


static func convertir_vinculacion_a_runtime(datos_nodo: Dictionary) -> Dictionary:
	# Compatibilidad temporal: las escenas jugables todavia usan este helper.
	if datos_nodo.is_empty():
		return _error("Nodo vacio o invalido.")

	var modo: String = str(datos_nodo.get("mode", "")).strip_edges()
	if modo != MODE_VINCULACION_CONCEPTOS:
		return _error("El nodo no es de tipo vinculacion_conceptos.")

	var contenido: Variant = datos_nodo.get("content", {})
	if not contenido is Dictionary:
		return _error("Falta la clave content en el JSON de vinculacion.")

	var conceptos_izquierda: Variant = contenido.get("conceptos_izquierda", [])
	var conceptos_derecha: Variant = contenido.get("conceptos_derecha", [])
	if not conceptos_izquierda is Array or not conceptos_derecha is Array:
		return _error(
			"La vinculacion requiere conceptos_izquierda y conceptos_derecha como Arrays."
		)

	return _ok({
		"instruccion": str(contenido.get("instruccion", "")).strip_edges(),
		"conceptos_izquierda": (conceptos_izquierda as Array).duplicate(true),
		"conceptos_derecha": (conceptos_derecha as Array).duplicate(true),
		"teaching_key": str(contenido.get("teaching_key", "")).strip_edges(),
	})


static func _agregar_configuracion_arrastre_a_runtime(
	datos_runtime: Dictionary,
	contenido: Dictionary
) -> void:
	for campo in ["elementos_maximos", "distractores_maximos", "mostrar_ayuda_visual"]:
		if not contenido.has(campo):
			continue
		datos_runtime[campo] = contenido.get(campo)


static func _leer_json(ruta_json: String) -> Dictionary:
	var ruta_limpia: String = AdaptadorContenidoViejoScript.resolver_ruta_json(ruta_json)
	if ruta_limpia.is_empty():
		push_error("CargadorDeContenidoDeNodo: falta la ruta del JSON.")
		return {}

	if not FileAccess.file_exists(ruta_limpia):
		push_warning("CargadorDeContenidoDeNodo: no existe el JSON: %s" % ruta_limpia)
		return {}

	var archivo: FileAccess = FileAccess.open(ruta_limpia, FileAccess.READ)
	if archivo == null:
		push_error("CargadorDeContenidoDeNodo: no se pudo abrir el JSON: %s" % ruta_limpia)
		return {}

	var parser := JSON.new()
	var resultado_parseo: Error = parser.parse(archivo.get_as_text())
	if resultado_parseo != OK:
		push_error(
			"CargadorDeContenidoDeNodo: JSON invalido en linea %d: %s Archivo: %s"
			% [parser.get_error_line(), parser.get_error_message(), ruta_limpia]
		)
		return {}

	var datos_parseados: Variant = parser.get_data()
	if not datos_parseados is Dictionary:
		push_error("CargadorDeContenidoDeNodo: el JSON debe ser un objeto: %s" % ruta_limpia)
		return {}

	return datos_parseados as Dictionary


static func _ok(datos: Dictionary) -> Dictionary:
	return {"ok": true, "data": datos, "error": ""}


static func _error(mensaje: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": mensaje}
