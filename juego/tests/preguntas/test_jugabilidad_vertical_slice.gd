extends GdUnitTestSuite
class_name TestJugabilidadVerticalSlice

const Datos := preload("res://tests/preguntas/jugabilidad_vertical_slice_datos.gd")


func test_cada_pantalla_del_flujo_tiene_nodos_ui_criticos() -> void:
	for pantalla in Datos.TODAS:
		var escena := _instanciar_escena_desde_ruta(pantalla["ruta"])
		for path_nodo in pantalla["nodos"]:
			_verificar_que_existe_nodo_en_pantalla(escena, path_nodo)
		escena.free()


func test_cada_pantalla_del_flujo_tiene_botones_habilitados() -> void:
	for pantalla in Datos.TODAS:
		var escena := _instanciar_escena_desde_ruta(pantalla["ruta"])
		for path_boton in pantalla["botones"]:
			_verificar_que_boton_esta_habilitado_en_pantalla(escena, path_boton)
		escena.free()


func test_mapa_y_finalizacion_exponen_metodos_de_navegacion() -> void:
	var mapa := _instanciar_escena_desde_ruta(Datos.MAPA["ruta"])
	assert_bool(mapa.has_method("obtener_nodo_mapa")).is_true()
	assert_bool(mapa.has_method("abrir_nodo_del_mapa")).is_true()
	mapa.free()

	var finalizacion := _instanciar_escena_desde_ruta(Datos.FINALIZACION["ruta"])
	assert_bool(finalizacion.has_method("continuar_al_mapa")).is_true()
	finalizacion.free()


func _instanciar_escena_desde_ruta(ruta: String) -> Node:
	return (load(ruta) as PackedScene).instantiate()


func _verificar_que_existe_nodo_en_pantalla(escena: Node, path_nodo: String) -> void:
	assert_object(escena.get_node_or_null(path_nodo)).is_not_null()


func _verificar_que_boton_esta_habilitado_en_pantalla(escena: Node, path_boton: String) -> void:
	var boton := escena.get_node_or_null(path_boton) as BaseButton
	assert_object(boton).is_not_null()
	assert_bool(boton.disabled).is_false()
