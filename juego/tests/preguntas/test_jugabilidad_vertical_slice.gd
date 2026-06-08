extends GdUnitTestSuite
class_name TestJugabilidadVerticalSlice

const Datos := preload("res://tests/preguntas/jugabilidad_vertical_slice_datos.gd")


func test_todas_las_pantallas_tienen_sus_nodos() -> void:
	for pantalla in Datos.TODAS:
		var escena := _abrir(pantalla["ruta"])
		for nodo in pantalla["nodos"]:
			assert_object(escena.get_node_or_null(nodo)).is_not_null()
		escena.free()


func test_todos_los_botones_existen_y_estan_activos() -> void:
	for pantalla in Datos.TODAS:
		var escena := _abrir(pantalla["ruta"])
		for nombre_boton in pantalla["botones"]:
			var boton := escena.get_node_or_null(nombre_boton) as BaseButton
			assert_object(boton).is_not_null()
			assert_bool(boton.disabled).is_false()
		escena.free()


func test_el_mapa_y_la_finalizacion_tienen_sus_metodos() -> void:
	var mapa := _abrir(Datos.MAPA["ruta"])
	assert_bool(mapa.has_method("obtener_nodo_mapa")).is_true()
	assert_bool(mapa.has_method("abrir_nodo_del_mapa")).is_true()
	mapa.free()

	var finalizacion := _abrir(Datos.FINALIZACION["ruta"])
	assert_bool(finalizacion.has_method("continuar_al_mapa")).is_true()
	finalizacion.free()


func _abrir(ruta: String) -> Node:
	return (load(ruta) as PackedScene).instantiate()
