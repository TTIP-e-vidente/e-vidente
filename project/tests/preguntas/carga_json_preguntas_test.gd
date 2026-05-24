extends GdUnitTestSuite
class_name CargaJsonPreguntasTest

## 8 tests sobre el fixture de ejemplo en contenido/.
## Flujo que se valida: JSON → QuestionJsonLoader → Preguntas → EvaluadorDeOpcionPregunta
const QuestionJsonLoaderScript := preload("res://preguntas/QuestionJsonLoader.gd")
const FIXTURE_PATH := "res://contenido/ejemplos/quiz_choice.json"


# Fase 1 — el JSON existe y el loader lo acepta
func test_fixture_json_se_puede_abrir() -> void:
	var datos := _cargar_json_fixture()
	assert_bool(datos.is_empty()) \
		.override_failure_message("No se pudo abrir el JSON. Ruta: " + FIXTURE_PATH) \
		.is_false()


func test_carga_retorna_ok() -> void:
	var resultado := _cargar_resultado_del_fixture()
	assert_bool(resultado.get("ok", false)) \
		.override_failure_message(
			"QuestionJsonLoader devolvió error: " + str(resultado.get("error", "sin mensaje"))
		) \
		.is_true()


# Fase 2 — el loader construye una pregunta usable
func test_tema_tiene_al_menos_una_pregunta() -> void:
	var preguntas := _obtener_preguntas_del_fixture()
	assert_array(preguntas) \
		.override_failure_message("QuestionJsonLoader no devolvió preguntas.") \
		.is_not_empty()


func test_pregunta_tiene_opciones() -> void:
	var pregunta := _obtener_primera_pregunta()
	assert_object(pregunta).is_not_null()
	assert_array(pregunta.opciones) \
		.override_failure_message("La pregunta no tiene opciones.") \
		.is_not_empty()


func test_existe_opcion_correcta() -> void:
	var pregunta := _obtener_primera_pregunta()
	assert_object(pregunta).is_not_null()
	var correct := pregunta.correct.strip_edges()
	assert_str(correct) \
		.override_failure_message("El campo 'correct_answer' está vacío en el JSON.") \
		.is_not_empty()
	assert_bool(pregunta.opciones.has(correct)) \
		.override_failure_message(
			"La opción correcta '" + correct + "' no está en las opciones."
		) \
		.is_true()


func test_existe_opcion_incorrecta() -> void:
	var pregunta := _obtener_primera_pregunta()
	assert_object(pregunta).is_not_null()
	assert_array(_obtener_opciones_incorrectas(pregunta)) \
		.override_failure_message("La pregunta no tiene opciones incorrectas.") \
		.is_not_empty()


# Fase 3 — EvaluadorDeOpcionPregunta clasifica bien cada opción
func test_evaluar_opcion_correcta() -> void:
	var pregunta := _obtener_primera_pregunta()
	assert_object(pregunta).is_not_null()
	assert_bool(EvaluadorDeOpcionPregunta.es_correcta(pregunta, pregunta.correct)) \
		.override_failure_message("EvaluadorDeOpcionPregunta devolvió false para la opción correcta.") \
		.is_true()


func test_evaluar_opcion_incorrecta() -> void:
	var pregunta := _obtener_primera_pregunta()
	assert_object(pregunta).is_not_null()
	var incorrectas := _obtener_opciones_incorrectas(pregunta)
	assert_array(incorrectas) \
		.override_failure_message("No hay opciones incorrectas en el fixture.") \
		.is_not_empty()
	assert_bool(EvaluadorDeOpcionPregunta.es_correcta(pregunta, incorrectas.front())) \
		.override_failure_message("EvaluadorDeOpcionPregunta devolvió true para una opción incorrecta.") \
		.is_false()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Lee y parsea el JSON del fixture. Retorna {} si falla.
func _cargar_json_fixture() -> Dictionary:
	var archivo := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if archivo == null:
		return {}
	var contenido := archivo.get_as_text()
	archivo.close()
	var datos: Variant = JSON.parse_string(contenido)
	if not datos is Dictionary:
		return {}
	return datos as Dictionary


## Pasa el fixture por QuestionJsonLoader y retorna el Dictionary completo del loader.
func _cargar_resultado_del_fixture() -> Dictionary:
	return QuestionJsonLoaderScript.cargar_resultado_desde_datos_nodo(
		_cargar_json_fixture(), FIXTURE_PATH
	)


## Devuelve el Array de preguntas parseadas. Retorna [] si no hay ninguna.
func _obtener_preguntas_del_fixture() -> Array:
	var resultado := _cargar_resultado_del_fixture()
	var data: Variant = resultado.get("data", null)
	if not data is Dictionary:
		return []
	var tema: ThemePreg = (data as Dictionary).get("theme", null)
	if tema == null:
		return []
	return tema.theme


## Extrae la primera pregunta. Retorna null si no hay ninguna.
func _obtener_primera_pregunta() -> Preguntas:
	var preguntas := _obtener_preguntas_del_fixture()
	if preguntas.is_empty():
		return null
	return preguntas[0]


## Retorna las opciones de la pregunta que no son la correcta.
func _obtener_opciones_incorrectas(pregunta: Preguntas) -> Array:
	if pregunta == null:
		return []
	return pregunta.opciones.filter(
		func(opcion: String) -> bool: return opcion != pregunta.correct
	)
