extends SceneTree

const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const SaveManagerScript := preload("res://interface/SaveManager.gd")

const MAP_SCENE := "res://mapas/MapScene.tscn"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"
const QUESTION_SCENE := "res://preguntas/pregunta.tscn"
const VINCULAR_SCENE := "res://vincular/VincularConceptos.tscn"
const LEGACY_DRAG_DROP_SCENE := "res://mapas/drag_drop/DragDropNode.tscn"
const TIEMPO_MAXIMO_SMOKE_TEST := 90.0
const NODE_1_KEY := "celiaquia_01_desayuno_basico"
const NODE_5_KEY := "celiaquia_05_intro_mixta"
const NODE_6_KEY := "celiaquia_06_practica_simple"
const NODE_8_KEY := "celiaquia_08_riesgos_basicos"
const NODE_14_KEY := "celiaquia_14_comer_fuera"
const NODE_18_KEY := "celiaquia_18_desafio_final"
const NODE_19_KEY := "celiaquia_19_cocina_segura"
const NODE_25_KEY := "celiaquia_25_etiquetas_y_trazas"
const NODE_30_KEY := "celiaquia_30_desafio_final_extendido"
const GAME_SCENES := [LEVEL_SCENE, QUESTION_SCENE, VINCULAR_SCENE]
const LOG_PREFIX_VALIDATION := "[ManualValidation]"

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
	await _call_and_expect("_on_jugar_pressed", "res://niveles/selector.tscn", "Selector")
	await _call_and_expect("_on_celiaquia_pressed", MAP_SCENE, "Mapa")
	if not failed:
		_validar_mapa_cargado()

	var resultado_nodo_1 := {}
	var firmas_nodo_5 := {}
	var resultado_match_d2 := {}
	var resultado_nodo_8 := {}
	var resultado_match_d3 := {}
	var resultado_nodo_18 := {}
	var resultado_nodo_19 := {}
	var resultado_nodo_25 := {}
	var resultado_nodo_30 := {}

	if not failed:
		resultado_nodo_1 = await _validar_nodo(global_state, NODE_1_KEY, "Nodo 1")
		_check(bool(resultado_nodo_1.get("completed", false)), "Nodo 1 deberia completarse.")
		_check(
			(resultado_nodo_1.get("scene_kinds", []) as Array).has("drag"),
			"Nodo 1 deberia abrir un drag jugable."
		)
		_check(
			bool(resultado_nodo_1.get("teaching_seen", false)),
			"Nodo 1 deberia mostrar ensenanza visual o fallback textual."
		)

	if not failed:
		for run_index in range(4):
			var resultado_nodo_5: Dictionary = await _validar_nodo(
				global_state,
				NODE_5_KEY,
				"Nodo 5 run %d" % (run_index + 1)
			)
			firmas_nodo_5[str(resultado_nodo_5.get("signature", ""))] = true
		_check(firmas_nodo_5.size() > 1, "Nodo 5 deberia variar entre runs.")

	if not failed:
		resultado_match_d2 = await _validar_nodo(global_state, NODE_6_KEY, "Nodo 6")
		_check(
			bool(resultado_match_d2.get("match_seen", false)),
			"Nodo 6 deberia abrir vinculacion de dificultad 2."
		)
		_check(
			int(resultado_match_d2.get("match_pairs_max", 0)) >= 2,
			"La vinculacion de dificultad 2 deberia tener al menos 2 pares."
		)
		_check(bool(resultado_match_d2.get("completed", false)), "Nodo 6 deberia completarse.")

	if not failed:
		resultado_nodo_8 = await _validar_nodo(global_state, NODE_8_KEY, "Nodo 8")
		_check(
			bool(resultado_nodo_8.get("match_seen", false)),
			"Nodo 8 deberia abrir vinculacion de dificultad 2."
		)
		_check(
			int(resultado_nodo_8.get("match_pairs_max", 0)) >= 2,
			"La vinculacion de Nodo 8 deberia tener al menos 2 pares."
		)
		_check(bool(resultado_nodo_8.get("completed", false)), "Nodo 8 deberia completarse.")

	if not failed:
		resultado_match_d3 = await _validar_nodo(global_state, NODE_14_KEY, "Nodo 14")
		_check(
			bool(resultado_match_d3.get("match_seen", false)),
			"Nodo 14 deberia abrir vinculacion de dificultad 3."
		)

	if not failed:
		resultado_nodo_18 = await _validar_nodo(global_state, NODE_18_KEY, "Nodo 18")
		_check(int(resultado_nodo_18.get("plan_total", 0)) == 3, "Nodo 18 deberia armar 3 games.")
		_check(
			_contains_all_scene_kinds(resultado_nodo_18.get("scene_kinds", []) as Array),
			"Nodo 18 deberia mezclar drag, quiz y match."
		)
		_check(bool(resultado_nodo_18.get("completed", false)), "Nodo 18 deberia completarse.")

	if not failed:
		resultado_nodo_19 = await _validar_nodo(global_state, NODE_19_KEY, "Nodo 19")
		_check(int(resultado_nodo_19.get("plan_total", 0)) == 3, "Nodo 19 deberia armar 3 games.")
		_check(
			_contains_all_scene_kinds(resultado_nodo_19.get("scene_kinds", []) as Array),
			"Nodo 19 deberia mezclar drag, quiz y match."
		)
		_check(bool(resultado_nodo_19.get("completed", false)), "Nodo 19 deberia completarse.")

	if not failed:
		resultado_nodo_25 = await _validar_nodo(global_state, NODE_25_KEY, "Nodo 25")
		_check(int(resultado_nodo_25.get("plan_total", 0)) == 3, "Nodo 25 deberia armar 3 games.")
		_check(
			_contains_all_scene_kinds(resultado_nodo_25.get("scene_kinds", []) as Array),
			"Nodo 25 deberia mezclar drag, quiz y match."
		)
		_check(bool(resultado_nodo_25.get("match_seen", false)), "Nodo 25 deberia abrir match.")
		_check(bool(resultado_nodo_25.get("completed", false)), "Nodo 25 deberia completarse.")

	if not failed:
		resultado_nodo_30 = await _validar_nodo(global_state, NODE_30_KEY, "Nodo 30")
		_check(int(resultado_nodo_30.get("plan_total", 0)) == 3, "Nodo 30 deberia armar 3 games.")
		_check(
			_contains_all_scene_kinds(resultado_nodo_30.get("scene_kinds", []) as Array),
			"Nodo 30 deberia mezclar drag, quiz y match."
		)
		_check(bool(resultado_nodo_30.get("match_seen", false)), "Nodo 30 deberia abrir match.")
		_check(bool(resultado_nodo_30.get("completed", false)), "Nodo 30 deberia completarse.")

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
	ItemLevel.is_dragging = null
	_delete_save_files()
	save_manager.cargar_datos()
	global_state.registrar_actividad_racha("smoke_setup", {"track_key": "celiaquia"})


func _validar_mapa_cargado() -> void:
	var tablero_mapa := current_scene.get_node_or_null("MapBoard") as Node
	_check(tablero_mapa != null, "El mapa deberia tener el nodo MapBoard")
	_check(
		tablero_mapa != null and tablero_mapa.has_method("obtener_nodos_runtime_mapa"),
		"MapBoard deberia exponer obtener_nodos_runtime_mapa"
	)
	if tablero_mapa == null or not tablero_mapa.has_method("obtener_nodos_runtime_mapa"):
		return
	var nodos_mapa_cargados := current_scene.get("nodos_mapa") as Array
	var nodos_runtime: Array = tablero_mapa.call("obtener_nodos_runtime_mapa") as Array
	var nodos_visibles := 0
	for nodo_runtime in nodos_runtime:
		if nodo_runtime is Node2D and (nodo_runtime as Node2D).visible:
			nodos_visibles += 1
	_check(
		nodos_mapa_cargados != null and not nodos_mapa_cargados.is_empty(),
		"El mapa deberia cargar nodos jugables desde el JSON"
	)
	_check(nodos_mapa_cargados.size() == 30, "El mapa actual deberia tener 30 nodos.")
	_check(
		nodos_runtime.size() >= nodos_mapa_cargados.size(),
		"El mapa deberia tener suficientes nodos visuales para renderizar el JSON."
	)
	_check(
		nodos_visibles == nodos_mapa_cargados.size(),
		"El mapa deberia mostrar los 30 nodos activos del JSON."
	)


func _validar_nodo(global_state: Node, node_key: String, label: String) -> Dictionary:
	_check(
		current_scene != null and current_scene.scene_file_path == MAP_SCENE,
		"%s: deberia iniciar desde mapa." % label
	)
	_check(
		current_scene != null and current_scene.has_method("obtener_nodo_mapa"),
		"%s: el mapa deberia exponer obtener_nodo_mapa." % label
	)
	_check(
		current_scene != null and current_scene.has_method("abrir_nodo_del_mapa"),
		"%s: el mapa deberia exponer abrir_nodo_del_mapa." % label
	)
	if failed:
		return {}

	var node_data = current_scene.call("obtener_nodo_mapa", node_key)
	_check(node_data != null, "%s: no se encontro el nodo %s." % [label, node_key])
	if failed:
		return {}

	current_scene.call("abrir_nodo_del_mapa", node_data)
	await _wait_for_any(GAME_SCENES, label)
	if failed:
		return {}

	var plan: Dictionary = global_state.call("obtener_partida_de_nodo_actual")
	var result := {
		"node_key": node_key,
		"label": label,
		"plan_total": int(plan.get("total_juegos", 0)),
		"activities": [],
		"scene_kinds": [],
		"match_seen": false,
		"match_pairs_max": 0,
		"teaching_seen": false,
		"completed": false,
		"signature": "",
	}
	_check(
		int(result.get("plan_total", 0)) > 0,
		"%s: el plan deberia tener al menos un juego." % label
	)
	if failed:
		return result

	var safety := 0
	while current_scene != null and GAME_SCENES.has(current_scene.scene_file_path):
		if safety >= 8:
			_check(false, "%s: se supero el limite de seguridad al completar el nodo." % label)
			break
		var juego_actual: Dictionary = global_state.call("obtener_juego_actual_de_partida")
		var activity_id: String = str(juego_actual.get("activity_id", "")).strip_edges()
		var scene_kind: String = _scene_kind(current_scene.scene_file_path)
		(result.get("activities", []) as Array).append(activity_id)
		(result.get("scene_kinds", []) as Array).append(scene_kind)
		print(
			"%s node=%s scene=%s activity=%s"
			% [LOG_PREFIX_VALIDATION, node_key, scene_kind, activity_id]
		)

		match current_scene.scene_file_path:
			LEVEL_SCENE:
				await _completar_escena_drag(result, label)
			QUESTION_SCENE:
				await _completar_escena_quiz(label)
			VINCULAR_SCENE:
				await _completar_escena_match(result, label)

		if failed:
			return result

		var next_scenes: Array[String] = [MAP_SCENE, "res://mapas/Finalización-Partida.tscn"]
		next_scenes.append_array(GAME_SCENES)
		await _wait_for_any(next_scenes, "%s continuar" % label)
		if (
			current_scene != null
			and current_scene.scene_file_path == "res://mapas/Finalización-Partida.tscn"
			and current_scene.has_method("continuar_al_mapa")
		):
			current_scene.call("continuar_al_mapa")
			await _wait_for(MAP_SCENE, "%s post-finalizacion" % label)
		safety += 1

	_check(
		current_scene != null and current_scene.scene_file_path == MAP_SCENE,
		"%s: deberia volver al mapa al terminar." % label
	)
	var completed_by_flow := (
		current_scene != null
		and current_scene.scene_file_path == MAP_SCENE
		and (result.get("activities", []) as Array).size() == int(result.get("plan_total", 0))
	)
	result["completed"] = completed_by_flow
	if global_state != null and global_state.has_method("es_nodo_jugable_completado"):
		result["completed"] = bool(result.get("completed", false)) or bool(
			global_state.call("es_nodo_jugable_completado", "celiaquia", node_key)
		)
	result["signature"] = _signature_from_result(result)
	return result


func _completar_escena_drag(result: Dictionary, label: String) -> void:
	var level_scene := current_scene
	var manager_level = level_scene.get_node_or_null("ManagerLevel")
	_check(manager_level != null, "%s: falta nodo ManagerLevel." % label)
	_check(level_scene.get_node_or_null("Plato") != null, "%s: falta nodo Plato." % label)
	_check(
		level_scene.get_node_or_null("Globo texto/Meal") != null,
		"%s: falta nodo Meal." % label
	)
	_check(
		level_scene.get_node_or_null("Globo texto/Condition") != null,
		"%s: falta nodo Condition." % label
	)
	_check(
		level_scene.has_method("completar_partida_actual"),
		"%s: Level deberia exponer completar_partida_actual." % label
	)
	_check(
		level_scene.has_method("es_partida_completada"),
		"%s: Level deberia exponer es_partida_completada." % label
	)
	if failed:
		return

	level_scene.call("completar_partida_actual")
	# La enseñanza aparece tras un timer de 0.8 s en _finalizar_partida_normal.
	# Esperamos 1.5 s reales para que el timer dispare antes de verificar visibilidad.
	await create_timer(1.5).timeout
	_check(
		bool(level_scene.call("es_partida_completada")),
		"%s: drag deberia quedar completado." % label
	)
	var teaching_sprite := level_scene.get_node_or_null("Ensenanza") as Sprite2D
	var teaching_text_layer := level_scene.get_node_or_null("TarjetaEnsenanzaCierre") as Control
	var teaching_seen := (
		(teaching_sprite != null and teaching_sprite.visible)
		or (teaching_text_layer != null and teaching_text_layer.visible)
	)
	result["teaching_seen"] = bool(result.get("teaching_seen", false)) or teaching_seen
	_check(teaching_seen, "%s: drag deberia mostrar ensenanza o fallback." % label)
	_check(
		level_scene.scene_file_path != LEGACY_DRAG_DROP_SCENE,
		"%s: drag no deberia abrir la escena legacy DragDropNode." % label
	)
	if failed:
		return
	level_scene.call("continuar_al_siguiente_nodo")


func _completar_escena_quiz(label: String) -> void:
	var question_scene := current_scene
	var pregunta_label := question_scene.get_node_or_null("Contenido/Informacion/Pregunta") as Label
	_check(pregunta_label != null, "%s: quiz deberia mostrar la pregunta." % label)
	_check(
		question_scene.has_method("_finalizar_quiz"),
		"%s: quiz deberia poder finalizarse." % label
	)
	if failed:
		return
	question_scene.call("_finalizar_quiz")
	for unused_frame in range(3):
		await process_frame
	var continuar := question_scene.get_node_or_null("Contenido/ContinuarJuego") as Control
	_check(continuar != null and continuar.visible, "%s: quiz deberia mostrar continuar." % label)
	if failed:
		return
	question_scene.call("continuar_al_siguiente_nodo")


func _completar_escena_match(result: Dictionary, label: String) -> void:
	var match_scene := current_scene
	var total_pares: int = int(match_scene.get("total_pares"))
	result["match_seen"] = true
	result["match_pairs_max"] = max(int(result.get("match_pairs_max", 0)), total_pares)
	_check(total_pares >= 2, "%s: match deberia exponer al menos 2 pares." % label)
	_check(
		_match_slots_cubren_total(match_scene, total_pares),
		"%s: match deberia tener slots visuales suficientes para sus pares." % label
	)
	if failed:
		return
	_resolver_vinculacion_correcta(match_scene)
	match_scene.call("confirmar")
	for unused_frame in range(3):
		await process_frame
	_check(bool(match_scene.get("validado")), "%s: match deberia validar correctamente." % label)
	if failed:
		return
	var continuar_validacion := match_scene.get_node_or_null("ContinuarJuego") as Control
	_check(
		continuar_validacion != null and continuar_validacion.visible,
		"%s: match deberia mostrar continuar al validar." % label
	)
	if failed:
		return
	match_scene.call("_al_solicitar_continuar_juego")
	for unused_frame in range(3):
		await process_frame
	var continuar_cierre := match_scene.get_node_or_null("ContinuarJuego") as Control
	var feedback_label := match_scene.get_node_or_null("Control/FeedbackLabel") as Label
	var teaching_sprite := match_scene.get_node_or_null("Ensenanza") as Sprite2D
	var cierre_visible := (
		continuar_cierre != null
		and continuar_cierre.visible
		and (
			(teaching_sprite != null and teaching_sprite.visible)
			or (
				feedback_label != null
				and feedback_label.text.contains("Excelente. Completaste las relaciones.")
			)
		)
	)
	_check(cierre_visible, "%s: match deberia mostrar cierre con continuar visible." % label)
	if failed:
		return
	match_scene.call("_al_solicitar_continuar_juego")


func _resolver_vinculacion_correcta(match_scene: Node) -> void:
	var items_izquierda: Array = match_scene.get("items_izquierda") as Array
	var items_derecha: Array = match_scene.get("items_derecha") as Array
	for izquierda in items_izquierda:
		var item_izquierda := izquierda as ConceptoItem
		if item_izquierda == null or not is_instance_valid(item_izquierda):
			continue
		if not item_izquierda.visible:
			continue
		for derecha in items_derecha:
			var item_derecha := derecha as ConceptoItem
			if item_derecha == null or not is_instance_valid(item_derecha):
				continue
			if not item_derecha.visible:
				continue
			if item_izquierda.par_key != item_derecha.par_key:
				continue
			match_scene.call("seleccionar_izquierda", item_izquierda)
			match_scene.call("vincular_con_derecha", item_derecha)
			break


func _match_slots_cubren_total(match_scene: Node, total_pares: int) -> bool:
	var items_izquierda: Array = match_scene.get("items_izquierda") as Array
	var items_derecha: Array = match_scene.get("items_derecha") as Array
	if total_pares <= 0:
		return false
	return items_izquierda.size() >= total_pares and items_derecha.size() >= total_pares


func _scene_kind(scene_path: String) -> String:
	match scene_path:
		LEVEL_SCENE:
			return "drag"
		QUESTION_SCENE:
			return "quiz"
		VINCULAR_SCENE:
			return "match"
		_:
			return scene_path


func _contains_all_scene_kinds(scene_kinds: Array) -> bool:
	return scene_kinds.has("drag") and scene_kinds.has("quiz") and scene_kinds.has("match")


func _signature_from_result(result: Dictionary) -> String:
	var activities: Array = result.get("activities", []) as Array
	var signature_parts := PackedStringArray()
	for activity in activities:
		signature_parts.append(str(activity).strip_edges())
	return "|".join(signature_parts)


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


func _wait_for_any(expected_paths: Array, label: String) -> void:
	for i in 60:
		if failed or prueba_finalizada:
			return
		await process_frame
		if current_scene != null and expected_paths.has(current_scene.scene_file_path):
			return
	_check(false, "No se llego a %s (%s)" % [label, ", ".join(expected_paths)])


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
