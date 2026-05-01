extends RefCounted
class_name QuestionJsonLoader

const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const PreguntasScript := preload("res://preguntas/recursos/preguntas.gd")
const ERROR_CONTENIDO_NO_DISPONIBLE := (
	"No se pudo cargar el contenido del nodo. Revisa su JSON o el recurso fallback."
)


static func cargar_resultado_desde_datos_nodo(
	datos_nodo: Dictionary,
	etiqueta_origen: String = ""
) -> Dictionary:
	if str(datos_nodo.get("mode", "")).strip_edges() != NodeContentLoaderScript.MODE_QUIZ_CHOICE:
		return _resultado_error(
			"QuestionJsonLoader solo soporta quiz_choice. Archivo: %s" % etiqueta_origen
		)

	var pregunta_recurso: Preguntas = _crear_pregunta(
		datos_nodo.get("content", {}),
		etiqueta_origen
	)
	return _resultado_ok_con_tema(_crear_tema(pregunta_recurso))


static func cargar_tema_desde_sesion(contexto_sesion: Dictionary) -> Dictionary:
	var datos_nodo: Dictionary = contexto_sesion.get("node_data", {})
	if not datos_nodo.is_empty():
		return cargar_resultado_desde_datos_nodo(
			datos_nodo,
			str(contexto_sesion.get("node_json_path", ""))
		)
	return _cargar_fallback_legacy(contexto_sesion)



static func _cargar_fallback_legacy(contexto_sesion: Dictionary) -> Dictionary:
	var ruta_recurso: String = str(contexto_sesion.get("node_resource_path", "")).strip_edges()
	if ruta_recurso.is_empty():
		return _resultado_error(ERROR_CONTENIDO_NO_DISPONIBLE)

	var pregunta_legacy: Preguntas = _cargar_pregunta_legacy(ruta_recurso)
	if pregunta_legacy == null:
		return _resultado_error(ERROR_CONTENIDO_NO_DISPONIBLE)

	return _resultado_ok_con_tema(_crear_tema(pregunta_legacy))


static func _resultado_ok_con_tema(tema: ThemePreg) -> Dictionary:
	return {
		"ok": true,
		"data": {
			"theme": tema
		},
		"error": ""
	}


static func _resultado_error(mensaje: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": mensaje
	}


static func _cargar_pregunta_legacy(ruta_recurso_pregunta: String) -> Preguntas:
	var pregunta_recurso: Variant = load(ruta_recurso_pregunta)
	if pregunta_recurso == null:
		push_warning(
			"QuestionJsonLoader: no se pudo cargar la pregunta fallback: %s"
			% ruta_recurso_pregunta
		)
		return null
	if not pregunta_recurso is Preguntas:
		push_warning(
			"QuestionJsonLoader: el recurso fallback no es una pregunta valida: %s"
			% ruta_recurso_pregunta
		)
		return null
	return pregunta_recurso as Preguntas


static func _crear_tema(pregunta_recurso: Preguntas) -> ThemePreg:
	var tema: ThemePreg = ThemePregScript.new()
	tema.theme = [pregunta_recurso]
	return tema


static func _crear_pregunta(contenido: Dictionary, etiqueta_origen: String) -> Preguntas:
	var respuesta_correcta: String = str(contenido.get("correct_answer", "")).strip_edges()
	var pregunta: Preguntas = PreguntasScript.new()
	pregunta.info_pregunta = str(contenido.get("question", "")).strip_edges()
	pregunta.correct = respuesta_correcta
	pregunta.opciones = _crear_opciones(contenido, respuesta_correcta)
	pregunta.pregunta_imagen = _cargar_visual(
		str(contenido.get("visual_resource", "")).strip_edges(),
		etiqueta_origen
	)
	pregunta.tipo = (
		Enum.TipoPregunta.IMAGEN
		if pregunta.pregunta_imagen != null
		else Enum.TipoPregunta.TEXTO
	)
	return pregunta


static func _crear_opciones(contenido: Dictionary, respuesta_correcta: String) -> Array[String]:
	var opciones: Array[String] = []
	if not respuesta_correcta.is_empty():
		opciones.append(respuesta_correcta)

	for opcion_cruda in contenido.get("wrong_options", []):
		var opcion_incorrecta: String = str(opcion_cruda).strip_edges()
		if opcion_incorrecta.is_empty() or opciones.has(opcion_incorrecta):
			continue
		opciones.append(opcion_incorrecta)

	return opciones


static func _cargar_visual(ruta_visual: String, etiqueta_origen: String) -> Texture2D:
	if ruta_visual.is_empty():
		return null

	var recurso: Variant = load(ruta_visual)
	if recurso is Texture2D:
		return recurso as Texture2D

	push_warning(
		"QuestionJsonLoader: visual_resource invalido (%s). Archivo: %s"
		% [ruta_visual, etiqueta_origen]
	)
	return null
