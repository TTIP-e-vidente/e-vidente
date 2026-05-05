extends SceneTree

const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const SaveManagerScript := preload("res://interface/SaveManager.gd")

const MAP_SCENE := "res://mapas/MapScene.tscn"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"
const QUESTION_SCENE := "res://preguntas/pregunta.tscn"
const LEGACY_DRAG_DROP_SCENE := "res://mapas/drag_drop/DragDropNode.tscn"
const TIEMPO_MAXIMO_SMOKE_TEST := 8.0

var failed := false
var prueba_finalizada := false


func _initialize() -> void:
	iniciar_timeout_de_seguridad()
	call_deferred("ejecutar_prueba")


func iniciar_timeout_de_seguridad() -> void:
	var temporizador := create_timer(TIEMPO_MAXIMO_SMOKE_TEST)
	temporizador.timeout.connect(fallar_por_timeout)


func fallar_por_timeout() -> void:
	if prueba_finalizada:
		return
	finalizar_con_error("El smoke test superó el tiempo máximo.")


func ejecutar_prueba() -> void:
	await process_frame

	var global_state = root.get_node_or_null("/root/Global")
	var save_manager = root.get_node_or_null("/root/SaveManager")
	_check(global_state != null, "Autoload Global no encontrado")
	_check(save_manager != null, "Autoload SaveManager no encontrado")
	if failed:
		finalizar_con_error()
		return

	_reset_test_state(global_state, save_manager)
	await process_frame


	await _go_to("res://interface/evidente.tscn", "Splash")
	await _call_and_expect("_on_ir_presionado", "res://niveles/intro.tscn", "Intro")
	await _call_and_expect("_on_iniciar_presionado", "res://niveles/selector.tscn", "Selector")
	await _call_and_expect("_on_celiaquia_presionado", MAP_SCENE, "Mapa")
	if not failed:
		var tablero_mapa := current_scene.get_node_or_null("MapBoard") as Node
		_check(tablero_mapa != null, "El mapa deberia tener el nodo MapBoard")
		_check(
			tablero_mapa != null and tablero_mapa.has_method("obtener_nodos_runtime_mapa"),
			"MapBoard deberia exponer obtener_nodos_runtime_mapa"
		)
		if tablero_mapa != null and tablero_mapa.has_method("obtener_nodos_runtime_mapa"):
			var nodos_mapa_cargados := current_scene.get("nodos_mapa") as Array
			var nodos_runtime: Array = tablero_mapa.call("obtener_nodos_runtime_mapa") as Array
			_check(
				nodos_mapa_cargados != null and not nodos_mapa_cargados.is_empty(),
				"El mapa deberia cargar nodos jugables desde el JSON"
			)
			_check(
				nodos_runtime.size() == nodos_mapa_cargados.size(),
				"El mapa deberia renderizar la misma cantidad de nodos que carga del JSON"
			)

	if not failed:
		await _select_first_map_node_and_expect_level()


	if not failed:
		_check_gameplay_scene(global_state)

	if not failed:
		await _continue_to_next_map_node()


	if not failed:
		for i in 3:
			await process_frame
		_check(is_instance_valid(current_scene), "La escena crasheo en los primeros frames")

	if failed:
		finalizar_con_error()
		return


	_reset_test_state(global_state, save_manager)
	finalizar_ok()


func _reset_test_state(global_state, save_manager) -> void:
	global_state.reiniciar_progreso()
	Item_level.is_dragging = null
	_delete_save_files()
	save_manager.cargar_datos()
	global_state.registrar_actividad_racha("smoke_setup", {"track_key": "celiaquia"})


func _check_gameplay_scene(global) -> void:
	var level_scene := current_scene
	var ml = current_scene.get_node_or_null("ManagerLevel")
	_check(ml != null, "Falta nodo ManagerLevel")
	_check(current_scene.get_node_or_null("Plato") != null, "Falta nodo Plato")
	_check(current_scene.get_node_or_null("Globo texto/Meal") != null, "Falta nodo Meal")
	_check(current_scene.get_node_or_null("Globo texto/Condition") != null, "Falta nodo Condition")
	if ml == null:
		return

	_check(
		ml.has_method("obtener_actual_partida_indice"),
		"ManagerLevel sin obtener_actual_partida_indice"
	)
	_check(ml.has_method("obtener_total_partidas"), "ManagerLevel sin obtener_total_partidas")
	if failed:
		return

	_check(str(ml.active_track_key) == "celiaquia", "Track deberia ser celiaquia")
	_check(
		ml.active_run_data is Dictionary and not ml.active_run_data.is_empty(),
		"Sin datos de partida"
	)
	_check(ml.obtener_actual_partida_indice() == 1, "Deberia ser la primera partida")
	_check(ml.obtener_total_partidas() >= 1, "Deberia haber al menos una partida")
	_check(global.obtener_actual_nivel_numero() == 1, "Global deberia estar en capitulo 1")
	_check(
		level_scene.has_method("completar_partida_actual"),
		"El nivel deberia exponer completar_partida_actual"
	)
	_check(
		level_scene.has_method("es_partida_completada"),
		"El nivel deberia exponer es_partida_completada"
	)
	if failed:
		return

	level_scene.completar_partida_actual()
	_check_completed_gameplay_state(level_scene, ml)


func _select_first_map_node_and_expect_level() -> void:
	_check(current_scene != null, "No hay mapa para seleccionar nodo")
	_check(
		current_scene != null and current_scene.has_method("al_seleccionar_nodo"),
		"Mapa no expone al_seleccionar_nodo"
	)
	_check(
		current_scene != null and current_scene.has_method("obtener_nodo_mapa"),
		"Mapa no expone obtener_nodo_mapa"
	)
	if failed:
		return

	var primer_nodo = current_scene.call("obtener_nodo_mapa", "receta_1_desayuno")
	_check(primer_nodo != null, "El mapa deberia tener el nodo receta_1_desayuno")
	if failed:
		return

	current_scene.call("al_seleccionar_nodo", primer_nodo)
	await _wait_for(LEVEL_SCENE, "Nivel")
	_check(
		current_scene != null and current_scene.scene_file_path != LEGACY_DRAG_DROP_SCENE,
		"drag_drop no debe abrir DragDropNode legacy"
	)


func _continue_to_next_map_node() -> void:
	_check(current_scene != null, "No hay nivel para continuar al siguiente nodo")
	_check(
		current_scene != null and current_scene.has_method("continuar_al_siguiente_nodo"),
		"Nivel no expone continuar_al_siguiente_nodo"
	)
	if failed:
		return

	current_scene.call("continuar_al_siguiente_nodo")
	await _wait_for(QUESTION_SCENE, "Pregunta siguiente")


func _check_completed_gameplay_state(level_scene: Node, manager_level) -> void:
	var next_button := level_scene.get_node_or_null("Adelante") as Button
	var back_button := level_scene.get_node_or_null("Atrás") as Button
	var teaching := level_scene.get_node_or_null("Ensenanza") as Sprite2D
	var title := level_scene.get_node_or_null("TituloNivel") as Sprite2D
	var lupa := level_scene.get_node_or_null("Lupa") as Area2D

	_check(level_scene.es_partida_completada(), "El nivel deberia quedar marcado como completado")
	_check(
		next_button != null and not next_button.disabled,
		"La flecha siguiente deberia quedar habilitada"
	)
	_check(
		back_button != null and back_button.disabled,
		"El boton atras deberia quedar deshabilitado"
	)
	_check(teaching != null and teaching.visible, "La ensenanza final deberia quedar visible")
	_check(lupa != null, "Falta nodo Lupa")
	_check(
		title != null and title.material is ShaderMaterial,
		"La escena deberia entrar en blanco y negro al completarse"
	)
	_check(
		next_button != null and next_button.material == null,
		"La flecha siguiente no deberia entrar en blanco y negro"
	)
	if failed:
		return

	var checked_items := 0
	for runtime_item in manager_level.level_items:
		if not is_instance_valid(runtime_item):
			continue
		checked_items += 1
		_check(
			runtime_item.has_method("is_interaction_enabled"),
			"Los items runtime deberian exponer su estado de interaccion"
		)
		_check(
			not runtime_item.is_interaction_enabled(),
			"Los alimentos deberian quedar deshabilitados al completar el nivel"
		)
		var sprite := runtime_item.get_node_or_null("Sprite2D") as Sprite2D
		_check(
			sprite != null and sprite.material is ShaderMaterial,
			"Los alimentos deberian verse en blanco y negro al completar el nivel"
		)
		if failed:
			return

	_check(
		checked_items > 0,
		"El nivel deberia exponer alimentos runtime para validar el bloqueo post-final"
	)


func _go_to(scene_path: String, label: String) -> void:
	if failed or prueba_finalizada:
		return
	_check(change_scene_to_file(scene_path) == OK, "No se pudo abrir %s" % label)
	if not failed:
		await _wait_for(scene_path, label)


func _call_and_expect(
	method: String, expected_scene: String, label: String, args: Array = []
) -> void:
	if failed or prueba_finalizada:
		return
	_check(current_scene != null, "No hay escena antes de %s" % label)
	_check(
		current_scene != null and current_scene.has_method(method),
		"%s no tiene metodo %s" % [label, method]
	)
	if failed:
		return
	current_scene.callv(method, args)
	await _wait_for(expected_scene, label)


func _wait_for(expected_path: String, label: String) -> void:
	for i in 60:
		if failed or prueba_finalizada:
			return
		await process_frame
		if current_scene != null and current_scene.scene_file_path == expected_path:
			return
	_check(false, "No se llego a %s (%s)" % [label, expected_path])


func _delete_save_files() -> void:
	for path in [
		SaveManagerScript.SAVE_PATH,
		SaveManagerScript.TEMP_SAVE_PATH,
		SaveManagerScript.BACKUP_SAVE_PATH
	]:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)


func finalizar_ok() -> void:
	_cerrar_prueba(0)


func finalizar_con_error(mensaje: String = "") -> void:
	if not mensaje.is_empty() and not failed:
		printerr("SMOKE TEST FAILED: %s" % mensaje)
	failed = true
	_cerrar_prueba(1)


func _cerrar_prueba(codigo_salida: int) -> void:
	if prueba_finalizada:
		return
	prueba_finalizada = true
	_stop_audio()
	if is_instance_valid(current_scene):
		var scene = current_scene
		current_scene = null
		scene.free()
	GameChapterAssetCatalog.limpiar_cache_texturas()
	await process_frame
	await process_frame
	quit(codigo_salida)


func _stop_audio() -> void:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	for player in root.find_children("*", "AudioStreamPlayer2D", true, false):
		if player is AudioStreamPlayer2D:
			player.stop()
			player.stream = null


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SMOKE TEST FAILED: %s" % message)
