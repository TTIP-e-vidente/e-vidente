extends GdUnitTestSuite
class_name TestModalidadPreguntas

const RUTA_ESCENA_PREGUNTA := "res://preguntas/pregunta.tscn"
const PATH_TEXTO_PREGUNTA := "Contenido/Informacion/Pregunta"
const PATH_OPCION_1 := "Contenido/Preguntas/Boton1"
const PATH_OPCION_2 := "Contenido/Preguntas/Boton2"
const PATH_PANEL_GAME_OVER := "Contenido/GameOver"
const PATH_LABEL_PUNTAJE := "Contenido/GameOver/Puntaje"

const ENUNCIADO_PRUEBA := "¿El gluten está en el maíz?"
const RESPUESTA_CORRECTA := "No"
const RESPUESTA_INCORRECTA := "Sí"


func test_quiz_cargado_deja_modalidad_lista_para_jugar() -> void:
	var escena := await _preparar_escena_de_preguntas_lista_para_jugar()

	var label_pregunta := escena.get_node_or_null(PATH_TEXTO_PREGUNTA) as Label
	assert_object(label_pregunta) \
		.override_failure_message("No se encontro el label del enunciado.") \
		.is_not_null()
	await _esperar_hasta_que(
		func() -> bool:
			return label_pregunta != null and label_pregunta.text == ENUNCIADO_PRUEBA,
		"El enunciado no termino de mostrarse en pantalla."
	)
	assert_str(label_pregunta.text) \
		.override_failure_message("El enunciado no se mostro en pantalla.") \
		.is_equal(ENUNCIADO_PRUEBA)

	var boton_mala := _buscar_boton_por_texto_de_respuesta(escena, RESPUESTA_INCORRECTA)
	var boton_buena := _buscar_boton_por_texto_de_respuesta(escena, RESPUESTA_CORRECTA)
	assert_object(boton_mala) \
		.override_failure_message('No aparecio la opcion "' + RESPUESTA_INCORRECTA + '".') \
		.is_not_null()
	assert_object(boton_buena) \
		.override_failure_message('No aparecio la opcion "' + RESPUESTA_CORRECTA + '".') \
		.is_not_null()
	assert_bool(boton_mala.visible and boton_buena.visible) \
		.override_failure_message("Las opciones no quedaron visibles.") \
		.is_true()
	assert_bool(not boton_mala.disabled and not boton_buena.disabled) \
		.override_failure_message("Las opciones quedaron deshabilitadas: no se puede jugar.") \
		.is_true()

	escena.queue_free()


func test_respuesta_incorrecta_pinta_boton_rojo() -> void:
	var escena := await _preparar_escena_de_preguntas_lista_para_jugar()
	var boton_mala := _buscar_boton_por_texto_de_respuesta(escena, RESPUESTA_INCORRECTA)
	assert_object(boton_mala).is_not_null()

	_simular_que_el_jugador_toca_una_opcion(boton_mala)
	await get_tree().process_frame

	assert_bool(boton_mala.modulate.is_equal_approx(MiPaleta.FEEDBACK_ERROR)) \
		.override_failure_message("Al fallar, el boton deberia verse rojo.") \
		.is_true()

	escena.queue_free()


func test_respuesta_incorrecta_permite_reintentar() -> void:
	var escena := await _preparar_escena_de_preguntas_lista_para_jugar()
	var boton_mala := _buscar_boton_por_texto_de_respuesta(escena, RESPUESTA_INCORRECTA)
	assert_object(boton_mala).is_not_null()

	_simular_que_el_jugador_toca_una_opcion(boton_mala)
	await _esperar_hasta_que(
		func() -> bool: return not escena.bloqueado,
		"La escena no se desbloqueo: el jugador no puede reintentar."
	)

	assert_bool(escena.bloqueado) \
		.override_failure_message("Tras fallar, la escena deberia desbloquearse.") \
		.is_false()

	escena.queue_free()


func test_respuesta_correcta_pinta_boton_verde() -> void:
	var escena := await _preparar_escena_de_preguntas_lista_para_jugar()
	var boton_buena := _buscar_boton_por_texto_de_respuesta(escena, RESPUESTA_CORRECTA)
	assert_object(boton_buena).is_not_null()

	_simular_que_el_jugador_toca_una_opcion(boton_buena)
	await get_tree().process_frame

	assert_bool(boton_buena.modulate.is_equal_approx(MiPaleta.FEEDBACK_OK)) \
		.override_failure_message("Al acertar, el boton deberia verse verde.") \
		.is_true()

	escena.queue_free()


func test_respuesta_correcta_muestra_puntaje_en_panel_final() -> void:
	var escena := await _preparar_escena_de_preguntas_lista_para_jugar()
	var boton_buena := _buscar_boton_por_texto_de_respuesta(escena, RESPUESTA_CORRECTA)
	assert_object(boton_buena).is_not_null()

	_simular_que_el_jugador_toca_una_opcion(boton_buena)
	await _esperar_hasta_que(
		func() -> bool:
			var label := escena.get_node_or_null(PATH_LABEL_PUNTAJE) as Label
			return label != null and label.text == "1/1",
		'El panel final no mostro "1/1" tras acertar.'
	)

	assert_int(escena.puntaje) \
		.override_failure_message("Deberia sumar 1 acierto.") \
		.is_equal(1)

	var panel_final := escena.get_node_or_null(PATH_PANEL_GAME_OVER) as CanvasItem
	assert_object(panel_final) \
		.override_failure_message("No se encontro el panel Game Over.") \
		.is_not_null()
	assert_bool(panel_final.visible) \
		.override_failure_message("El panel final no se mostro al acertar.") \
		.is_true()

	var label_puntaje := escena.get_node_or_null(PATH_LABEL_PUNTAJE) as Label
	assert_object(label_puntaje).is_not_null()
	assert_str(label_puntaje.text) \
		.override_failure_message('El puntaje en pantalla deberia ser "1/1".') \
		.is_equal("1/1")

	escena.queue_free()


func _instanciar_escena_pregunta() -> EscenaPregunta:
	return (load(RUTA_ESCENA_PREGUNTA) as PackedScene).instantiate() as EscenaPregunta


func _preparar_escena_de_preguntas_lista_para_jugar() -> EscenaPregunta:
	var escena := _instanciar_escena_pregunta()
	escena.quiz = _crear_quiz_de_prueba_en_memoria()
	add_child(escena)
	await get_tree().process_frame
	return escena


func _simular_que_el_jugador_toca_una_opcion(boton: Button) -> void:
	boton.pressed.emit()


func _buscar_boton_por_texto_de_respuesta(escena: EscenaPregunta, respuesta: String) -> Button:
	for path_boton in [PATH_OPCION_1, PATH_OPCION_2]:
		var boton := escena.get_node_or_null(path_boton) as Button
		if boton != null and str(boton.get_meta("respuesta")) == respuesta:
			return boton
	return null


func _esperar_hasta_que(condicion: Callable, mensaje_si_falla: String, segundos: float = 5.0) -> void:
	var deadline := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condicion.call():
			return
		await get_tree().process_frame
	assert_bool(false).override_failure_message(mensaje_si_falla).is_true()


func _crear_quiz_de_prueba_en_memoria() -> ThemePreg:
	var pregunta := Preguntas.new()
	pregunta.info_pregunta = ENUNCIADO_PRUEBA
	pregunta.correct = RESPUESTA_CORRECTA
	pregunta.opciones = [RESPUESTA_INCORRECTA, RESPUESTA_CORRECTA]
	pregunta.tipo = Enum.TipoPregunta.TEXTO
	var tema := ThemePreg.new()
	tema.theme = [pregunta]
	return tema
