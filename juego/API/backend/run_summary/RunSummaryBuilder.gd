class_name RunSummaryBuilder
extends RefCounted

static func construir(
	restriccion: String,
	id_nodo: String,
	tipo_juego: String,
	puntaje: int,
	precision: float,
	respuestas_correctas: int,
	respuestas_incorrectas: int,
	exp_a_sumar: int,
	completado: bool,
	duracion_segundos: int,
) -> Dictionary:
	return {
		"clientRunId": _generar_id_ejecucion_cliente(),
		"restriction": restriccion,
		"nodeId": id_nodo,
		"gameType": tipo_juego,
		"score": puntaje,
		"accuracy": precision,
		"correctAnswers": respuestas_correctas,
		"wrongAnswers": respuestas_incorrectas,
		"expToAdd": exp_a_sumar,
		"completed": completado,
		"durationSeconds": duracion_segundos,
		"finishedAt": Time.get_datetime_string_from_system(true),
	}


static func _generar_id_ejecucion_cliente() -> String:
	var timestamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var millis := int(Time.get_unix_time_from_system() * 1000.0)
	return "run_%s_%d_%d" % [timestamp, millis, randi()]
