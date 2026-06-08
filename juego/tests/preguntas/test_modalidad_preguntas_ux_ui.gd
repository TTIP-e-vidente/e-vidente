extends GdUnitTestSuite
class_name TestModalidadPreguntasUxUi

const RUTA_ESCENA := "res://preguntas/pregunta.tscn"


func test_la_escena_carga_sin_errores() -> void:
	var escena := _abrir()
	assert_object(escena).is_not_null()
	escena.free()


func test_existe_el_contenedor_y_la_pregunta() -> void:
	var escena := _abrir()
	assert_object(escena.get_node_or_null("Contenido")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/Informacion/Pregunta")).is_not_null()
	escena.free()


func test_existen_los_botones_de_respuesta() -> void:
	var escena := _abrir()
	assert_object(escena.get_node_or_null("Contenido/Preguntas")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/Preguntas/Boton1")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/Preguntas/Boton2")).is_not_null()
	escena.free()


func test_los_botones_se_activan_con_pregunta_cargada() -> void:
	var escena := _abrir()
	escena.set("quiz", _crear_pregunta_de_prueba())
	add_child(escena)
	await get_tree().process_frame

	var boton1 := escena.get_node_or_null("Contenido/Preguntas/Boton1") as BaseButton
	assert_object(boton1).is_not_null()
	assert_bool(boton1.visible).is_true()
	assert_bool(boton1.disabled).is_false()
	escena.queue_free()


func test_al_presionar_un_boton_queda_registrado() -> void:
	var escena := _abrir()
	escena.set("quiz", _crear_pregunta_de_prueba())
	add_child(escena)
	await get_tree().process_frame

	var boton1 := escena.get_node_or_null("Contenido/Preguntas/Boton1") as Button
	assert_object(boton1).is_not_null()
	escena.manejar_respuesta(boton1)
	assert_bool(escena.bloqueado).is_true()
	escena.queue_free()


func test_existe_el_panel_de_resultado() -> void:
	var escena := _abrir()
	assert_object(escena.get_node_or_null("Contenido/GameOver")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/GameOver/Aciertos")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/GameOver/Puntaje")).is_not_null()
	escena.free()


func test_existen_los_botones_para_salir() -> void:
	var escena := _abrir()
	assert_object(escena.get_node_or_null("Contenido/Atrás")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/GameOver/JugarNuevamente")).is_not_null()
	assert_object(escena.get_node_or_null("Contenido/ContinuarJuego")).is_not_null()
	escena.free()


func test_el_boton_volver_esta_siempre_habilitado() -> void:
	var escena := _abrir()
	var boton_volver := escena.get_node_or_null("Contenido/Atrás") as BaseButton
	assert_object(boton_volver).is_not_null()
	assert_bool(boton_volver.disabled).is_false()
	escena.free()


func _abrir() -> Node:
	return (load(RUTA_ESCENA) as PackedScene).instantiate()


func _crear_pregunta_de_prueba() -> ThemePreg:
	var pregunta := Preguntas.new()
	pregunta.info_pregunta = "¿El gluten está en el maíz?"
	pregunta.correct = "No"
	pregunta.opciones = ["Sí", "No"]
	pregunta.tipo = Enum.TipoPregunta.TEXTO
	var tema := ThemePreg.new()
	tema.theme = [pregunta]
	return tema
