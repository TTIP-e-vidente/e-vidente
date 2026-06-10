extends GdUnitTestSuite
class_name TestModalidadPreguntasUxUi

const RUTA_ESCENA_PREGUNTA := "res://preguntas/pregunta.tscn"

const PATH_CONTENEDOR := "Contenido"
const PATH_TEXTO_PREGUNTA := "Contenido/Informacion/Pregunta"
const PATH_CONTENEDOR_OPCIONES := "Contenido/Preguntas"
const PATH_OPCION_1 := "Contenido/Preguntas/Boton1"
const PATH_OPCION_2 := "Contenido/Preguntas/Boton2"
const PATH_PANEL_GAME_OVER := "Contenido/GameOver"
const PATH_LABEL_ACIERTOS := "Contenido/GameOver/Aciertos"
const PATH_LABEL_PUNTAJE := "Contenido/GameOver/Puntaje"
const PATH_BOTON_ATRAS := "Contenido/Atrás"
const PATH_BOTON_JUGAR_NUEVAMENTE := "Contenido/GameOver/JugarNuevamente"
const PATH_BOTON_CONTINUAR := "Contenido/ContinuarJuego"


func test_escena_pregunta_se_instancia_sin_errores() -> void:
	var escena := _instanciar_escena_pregunta()
	assert_object(escena).is_not_null()
	escena.free()


func test_contenedor_y_texto_de_pregunta_estan_en_escena() -> void:
	var escena := _instanciar_escena_pregunta()
	_verificar_que_nodo_existe_en_escena(escena, PATH_CONTENEDOR)
	_verificar_que_nodo_existe_en_escena(escena, PATH_TEXTO_PREGUNTA)
	escena.free()


func test_botones_de_opcion_estan_en_escena() -> void:
	var escena := _instanciar_escena_pregunta()
	_verificar_que_nodo_existe_en_escena(escena, PATH_CONTENEDOR_OPCIONES)
	_verificar_que_nodo_existe_en_escena(escena, PATH_OPCION_1)
	_verificar_que_nodo_existe_en_escena(escena, PATH_OPCION_2)
	escena.free()


func test_botones_de_opcion_visibles_y_habilitados_con_quiz_cargado() -> void:
	var escena := await _instanciar_escena_pregunta_con_quiz_de_prueba_listo()
	var boton_opcion_1 := escena.get_node_or_null(PATH_OPCION_1) as BaseButton
	assert_object(boton_opcion_1).is_not_null()
	assert_bool(boton_opcion_1.visible).is_true()
	assert_bool(boton_opcion_1.disabled).is_false()
	escena.queue_free()


func test_responder_opcion_bloquea_la_escena() -> void:
	var escena := await _instanciar_escena_pregunta_con_quiz_de_prueba_listo()
	var boton_opcion_1 := escena.get_node_or_null(PATH_OPCION_1) as Button
	assert_object(boton_opcion_1).is_not_null()
	escena.manejar_respuesta(boton_opcion_1)
	assert_bool(escena.bloqueado).is_true()
	escena.queue_free()


func test_panel_game_over_y_labels_de_resultado_estan_en_escena() -> void:
	var escena := _instanciar_escena_pregunta()
	_verificar_que_nodo_existe_en_escena(escena, PATH_PANEL_GAME_OVER)
	_verificar_que_nodo_existe_en_escena(escena, PATH_LABEL_ACIERTOS)
	_verificar_que_nodo_existe_en_escena(escena, PATH_LABEL_PUNTAJE)
	escena.free()


func test_botones_atras_reintentar_y_continuar_estan_en_escena() -> void:
	var escena := _instanciar_escena_pregunta()
	_verificar_que_nodo_existe_en_escena(escena, PATH_BOTON_ATRAS)
	_verificar_que_nodo_existe_en_escena(escena, PATH_BOTON_JUGAR_NUEVAMENTE)
	_verificar_que_nodo_existe_en_escena(escena, PATH_BOTON_CONTINUAR)
	escena.free()


func test_boton_atras_habilitado_sin_quiz_cargado() -> void:
	var escena := _instanciar_escena_pregunta()
	var boton_atras := escena.get_node_or_null(PATH_BOTON_ATRAS) as BaseButton
	assert_object(boton_atras).is_not_null()
	assert_bool(boton_atras.disabled).is_false()
	escena.free()


func _instanciar_escena_pregunta() -> Node:
	return (load(RUTA_ESCENA_PREGUNTA) as PackedScene).instantiate()


func _instanciar_escena_pregunta_con_quiz_de_prueba_listo() -> Node:
	var escena := _instanciar_escena_pregunta()
	escena.set("quiz", _crear_theme_preg_con_una_pregunta_texto())
	add_child(escena)
	await get_tree().process_frame
	return escena


func _verificar_que_nodo_existe_en_escena(escena: Node, path_nodo: String) -> void:
	assert_object(escena.get_node_or_null(path_nodo)).is_not_null()


func _crear_theme_preg_con_una_pregunta_texto() -> ThemePreg:
	var pregunta := Preguntas.new()
	pregunta.info_pregunta = "¿El gluten está en el maíz?"
	pregunta.correct = "No"
	pregunta.opciones = ["Sí", "No"]
	pregunta.tipo = Enum.TipoPregunta.TEXTO
	var tema := ThemePreg.new()
	tema.theme = [pregunta]
	return tema
