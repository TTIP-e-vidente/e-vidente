extends RefCounted
class_name EvaluadorDeOpcionPregunta

## Compara la respuesta elegida contra pregunta.correct (normalizado por QuestionJsonLoader).

static func es_correcta(pregunta: Preguntas, respuesta_elegida: String) -> bool:
	if pregunta == null:
		return false
	var respuesta_correcta := pregunta.correct.strip_edges()
	var respuesta := respuesta_elegida.strip_edges()
	if respuesta_correcta.is_empty():
		return false
	return respuesta == respuesta_correcta
