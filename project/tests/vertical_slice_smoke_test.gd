extends SceneTree

const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const SaveManagerScript := preload("res://interface/SaveManager.gd")

const MAP_SCENE := "res://mapas/MapScene.tscn"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"
const QUESTION_SCENE := "res://preguntas/pregunta.tscn"
const VINCULAR_SCENE := "res://vincular/VincularConceptos.tscn"
const COMPLETAR_PALABRA_SCENE := "res://completar/completar_palabra.tscn"
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
const GAME_SCENES := [LEVEL_SCENE, QUESTION_SCENE, VINCULAR_SCENE, COMPLETAR_PALABRA_SCENE]
const LOG_PREFIX_VALIDATION := "[ManualValidation]"
const CARGADOR_COMPLETAR_SCRIPT := preload("res://completar/CargadorCompletar.gd")
const CONTENT_SCHEMA_NORMALIZER_SCRIPT := preload(
	"res://sistemas/contenido/ContentSchemaNormalizer.gd"
)
const CARGADOR_DE_MAPA_SCRIPT := preload("res://mapas/logica/CargadorDeMapa.gd")
const MODALIDAD_ROUTER_SCRIPT := preload("res://sistemas/ModalidadRouter.gd")

var failed := false
var prueba_finalizada := false
var _save_files_preserved := false
var _save_file_snapshots: Dictionary = {}


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

	# --- Tests unitarios de completar_palabra (no necesitan escena cargada) ---
	if not failed:
		ejecutar_tests_completar_palabra()

	if failed:
		finalizar_con_error()
		return


	_reset_test_state(global_state, save_manager)
	finalizar_ok()


func _reset_test_state(global_state, save_manager) -> void:
	global_state.reiniciar_progreso()
	ItemLevel.is_dragging = null
	_preserve_save_files_once()
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
	var nodos_mapa_cargados: Array = current_scene.get("nodos_mapa") as Array
	var nodos_runtime: Array = tablero_mapa.call("obtener_nodos_runtime_mapa") as Array
	var nodos_visibles := 0
	for nodo_runtime in nodos_runtime:
		if nodo_runtime is Node2D and (nodo_runtime as Node2D).visible:
			nodos_visibles += 1
	_check(
		nodos_mapa_cargados != null and not nodos_mapa_cargados.is_empty(),
		"El mapa deberia cargar nodos jugables desde el JSON"
	)
	_check(nodos_mapa_cargados.size() == 33, "El mapa actual deberia tener 33 nodos.")
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
			COMPLETAR_PALABRA_SCENE:
				await _completar_escena_completar_palabra(label)

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
	# El componente activo de objetivo es DragObjectiveText; los nodos viejos
	# ("Globo texto/Meal", "Globo texto/Condition") siguen en escena pero ocultos.
	var drag_obj_text = level_scene.get_node_or_null("DragObjectiveText")
	_check(
		drag_obj_text != null,
		"%s: falta nodo DragObjectiveText en Level.tscn." % label
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

	# Verificar que DragObjectiveText muestra meal no vacío.
	if drag_obj_text != null and drag_obj_text.has_node("MealLabel"):
		var meal_label := drag_obj_text.get_node("MealLabel") as Label
		_check(
			meal_label != null and not meal_label.text.strip_edges().is_empty(),
			"%s: DragObjectiveText deberia mostrar un meal no vacio." % label
		)
	# Verificar que DragObjectiveText muestra action distinto al fallback vacío.
	if drag_obj_text != null and drag_obj_text.has_node("ActionLabel"):
		var action_label := drag_obj_text.get_node("ActionLabel") as Label
		_check(
			action_label != null and not action_label.text.strip_edges().is_empty(),
			"%s: DragObjectiveText deberia mostrar un action no vacio." % label
		)

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

func _completar_escena_completar_palabra(label: String) -> void:
	var wo_scene := current_scene
	_check(
		wo_scene.has_method("setup"),
		"%s: completar_palabra deberia exponer setup()." % label
	)
	if failed:
		return
	# La escena se autoconfigura en _ready() via NodoRuntime.obtener_actividad_actual().
	# Para el smoke test, presionamos todos los botones disponibles (uno por blank)
	# y luego el ConfirmButton si existe y está habilitado.
	var options_container := wo_scene.get_node_or_null("Control/Container/HBoxContainer") as Container
	_check(
		options_container != null,
		"%s: completar_palabra deberia tener Control/Container/HBoxContainer." % label
	)
	if failed or options_container == null:
		return

	# Recopilar botones disponibles (sin disabled)
	var buttons: Array = []
	for child in options_container.get_children():
		if child is Button and not (child as Button).disabled:
			buttons.append(child as Button)
	_check(not buttons.is_empty(), "%s: completar_palabra deberia tener botones de opciones." % label)
	if failed:
		return

	# Presionar botones uno a uno según la cantidad de blanks
	for btn in buttons:
		if not (btn as Button).disabled:
			(btn as Button).emit_signal("pressed")
			await process_frame
			await process_frame

	# Si hay ConfirmButton habilitado, presionarlo (multi-blank)
	var confirm_btn := wo_scene.get_node_or_null("Control/ConfirmButton") as Button
	if confirm_btn != null and not confirm_btn.disabled and confirm_btn.visible:
		confirm_btn.emit_signal("pressed")
		await process_frame
		await process_frame

	# Esperar a que la validacion y el timer interno (1.5s) finalicen
	await create_timer(2.2).timeout







func _scene_kind(scene_path: String) -> String:
	match scene_path:
		LEVEL_SCENE:
			return "drag"
		QUESTION_SCENE:
			return "quiz"
		VINCULAR_SCENE:
			return "match"
		COMPLETAR_PALABRA_SCENE:
			return "completar_palabra"
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


func _preserve_save_files_once() -> void:
	if _save_files_preserved:
		return
	_save_files_preserved = true
	for path in [
		SaveManagerScript.SAVE_PATH,
		SaveManagerScript.TEMP_SAVE_PATH,
		SaveManagerScript.BACKUP_SAVE_PATH
	]:
		var snapshot := {"exists": false, "text": ""}
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				snapshot["exists"] = true
				snapshot["text"] = file.get_as_text()
		_save_file_snapshots[path] = snapshot


func _restore_preserved_save_files() -> void:
	if not _save_files_preserved:
		return
	for path in _save_file_snapshots.keys():
		var snapshot: Dictionary = _save_file_snapshots[path]
		var abs_path := ProjectSettings.globalize_path(str(path))
		if bool(snapshot.get("exists", false)):
			var file := FileAccess.open(str(path), FileAccess.WRITE)
			if file != null:
				file.store_string(str(snapshot.get("text", "")))
				file.flush()
		elif FileAccess.file_exists(abs_path):
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
	_restore_preserved_save_files()
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


# ===========================================================================
# Tests unitarios: CargadorCompletar
# ===========================================================================

func _test_completar_palabra_loader_carga_json_valido() -> void:
	var Loader := CARGADOR_COMPLETAR_SCRIPT
	Loader.limpiar_cache()
	var result: Dictionary = Loader.pick(1)
	_check(not result.is_empty(), "[WO] pick(1) debe devolver un desafío no vacío")
	_check(result.has("sentence"), "[WO] pick(1) debe tener campo sentence")
	_check(result.has("screen_title"), "[WO] pick(1) debe tener campo screen_title")
	_check(result.has("answers"), "[WO] pick(1) debe tener campo answers")
	_check(result.has("options"), "[WO] pick(1) debe tener campo options")
	_check(result.has("id"), "[WO] pick(1) debe incluir el id del desafío")


func _test_completar_palabra_loader_filtra_dificultad_invalida() -> void:
	var Loader := CARGADOR_COMPLETAR_SCRIPT
	Loader.limpiar_cache()
	var result: Dictionary = Loader.pick(99)
	_check(result.is_empty(), "[WO] pick(99) debe devolver {} (sin desafíos para esa dificultad)")


func _test_completar_palabra_contrato_json() -> void:
	# Verificar que TODOS los desafíos del JSON cumplen el contrato
	var Loader := CARGADOR_COMPLETAR_SCRIPT
	Loader.limpiar_cache()
	var all_challenges: Dictionary = Loader.load_all()
	_check(not all_challenges.is_empty(), "[WO] el JSON debe tener al menos un desafío válido")
	for key in all_challenges.keys():
		var entry: Dictionary = all_challenges[key]
		var answers: Array = entry.get("answers", [])
		var options: Array = entry.get("options", [])
		var sentence: String = str(entry.get("sentence", ""))
		var blank_count: int = CONTENT_SCHEMA_NORMALIZER_SCRIPT.count_blanks(sentence)
		_check(
			blank_count == answers.size(),
			"[WO] '%s': blanks=%d answers=%d — deben coincidir" % [key, blank_count, answers.size()]
		)
		_check(
			CONTENT_SCHEMA_NORMALIZER_SCRIPT.has_all_answers_in_choices(answers, options),
			"[WO] '%s': alguna answer no está en options" % key
		)


func _test_completar_palabra_loader_tiene_dificultades_1_2_3() -> void:
	var Loader := CARGADOR_COMPLETAR_SCRIPT
	Loader.limpiar_cache()
	_check(not Loader.pick(1).is_empty(), "[WO] debe haber desafíos de dificultad 1")
	_check(not Loader.pick(2).is_empty(), "[WO] debe haber desafíos de dificultad 2")
	_check(not Loader.pick(3).is_empty(), "[WO] debe haber desafíos de dificultad 3")


# ===========================================================================
# Tests unitarios: contrato de contenido y normalización.
# ===========================================================================

func _test_completar_palabra_acepta_formato_trainee() -> void:
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var raw: Dictionary = {
		"id": "word_test",
		"mode": "completar_palabra",
		"difficulty": 1,
		"screen_title": "Elegí la opción correcta",
		"prompt": "El producto apto no tiene ____.",
		"correct_answers": ["gluten"],
		"choices": ["gluten", "sal"],
	}
	var normalized: Dictionary = Normalizer.normalize_word_game("word_test", raw)
	_check(
		normalized.get("screen_title", "") == raw.get("screen_title", ""),
		"[WO] screen_title trainee debe conservarse"
	)
	_check(
		normalized.get("screen_title", "") != raw.get("prompt", ""),
		"[WO] prompt no debe usarse como titulo"
	)
	_check(
		normalized.get("sentence", "") == raw.get("prompt", ""),
		"[WO] prompt debe mapear a sentence"
	)
	_check(
		normalized.get("answers", []) == raw.get("correct_answers", []),
		"[WO] correct_answers debe mapear a answers"
	)
	_check(
		normalized.get("options", []) == raw.get("choices", []),
		"[WO] choices debe mapear a options"
	)
	var old_raw: Dictionary = {
		"mode": "completar_palabra",
		"difficulty": 1,
		"sentence": "El producto apto no tiene ____.",
		"answers": ["gluten"],
		"options": ["gluten", "sal"],
	}
	var old_normalized: Dictionary = Normalizer.normalize_word_game("word_old", old_raw)
	_check(
		old_normalized.get("screen_title", "") == "Escogé la palabra que falta",
		"[WO] sin screen_title debe usar fallback"
	)
	_check(
		old_normalized.get("prompt", "") == old_raw.get("sentence", ""),
		"[WO] sentence legacy debe mapear a prompt"
	)
	_check(
		old_normalized.get("correct_answers", []) == old_raw.get("answers", []),
		"[WO] answers legacy debe mapear a correct_answers"
	)
	_check(
		old_normalized.get("choices", []) == old_raw.get("options", []),
		"[WO] options legacy debe mapear a choices"
	)


func _test_drag_objective_anidado_y_fallback() -> void:
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var explicit_game: Dictionary = {
		"type": "drag",
		"objective": {
			"action": "Prepara",
			"meal": "una cena sin TACC",
			"connector": "para tu amigue",
			"restriction": "celiaquía",
		},
	}
	var explicit_objective: Dictionary = Normalizer.normalize_drag_objective(
		explicit_game,
		"celiaquia",
		"celiaquia_14_comer_fuera"
	)
	_check(
		explicit_objective.get("meal", "") == "una cena sin TACC",
		"[DragObjective] debe respetar objective.meal"
	)
	var fallback_objective: Dictionary = Normalizer.normalize_drag_objective(
		{"type": "drag"},
		"celiaquia",
		"celiaquia_02_colacion_basica"
	)
	_check(fallback_objective.get("meal", "") != "", "[DragObjective] debe inferir meal por node_key")
	_check(fallback_objective.get("action", "") != "", "[DragObjective] fallback debe tener action")
	_check(
		fallback_objective.get("connector", "") != "",
		"[DragObjective] fallback debe tener connector"
	)


func _test_celiaquia_mapa_drag_objectives_completos() -> void:
	var MapLoader := CARGADOR_DE_MAPA_SCRIPT
	var result: Dictionary = MapLoader.load_map("res://contenido/mapa/celiaquia_mapa.json")
	_check(bool(result.get("ok", false)), "[DragObjective] celiaquia_mapa debe cargar")
	if not bool(result.get("ok", false)):
		return
	var nodes: Array = result.get("data", {}).get("nodes", [])
	for raw_node in nodes:
		var node = raw_node
		if node == null or not node.has_method("get_random_game_requests"):
			continue
		for game in node.get_random_game_requests():
			if str(game.get("type", "")) != "drag":
				continue
			var objective_raw: Variant = game.get("objective", {})
			_check(objective_raw is Dictionary, "[DragObjective] drag debe tener objective Dictionary")
			if objective_raw is Dictionary:
				var objective: Dictionary = objective_raw as Dictionary
				_check(
					str(objective.get("action", "")).strip_edges() != "",
					"[DragObjective] action no puede quedar vacio"
				)
				_check(
					str(objective.get("meal", "")).strip_edges() != "",
					"[DragObjective] meal no puede quedar vacio"
				)
				_check(
					str(objective.get("connector", "")).strip_edges() != "",
					"[DragObjective] connector no puede quedar vacio"
				)


func _test_drag_objective_formato_plano() -> void:
	# Acepta {objective_action, objective_meal, objective_connector, objective_restriction}.
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var game: Dictionary = {
		"type": "drag",
		"objective_action": "Armá",
		"objective_meal": "una merienda sin TACC",
		"objective_connector": "para tu compañere",
		"objective_restriction": "celiaquía",
	}
	var result: Dictionary = Normalizer.normalize_drag_objective(game, "celiaquia", "")
	_check(result.get("action", "") == "Armá", "[DragObjective] formato plano: action")
	_check(
		result.get("meal", "") == "una merienda sin TACC",
		"[DragObjective] formato plano: meal"
	)
	_check(
		result.get("connector", "") == "para tu compañere",
		"[DragObjective] formato plano: connector"
	)
	_check(result.get("restriction", "") == "celiaquía", "[DragObjective] formato plano: restriction")


func _test_drag_objective_mensaje_viejo() -> void:
	# Acepta objective_message con formato "linea1\nlinea2".
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var game: Dictionary = {
		"type": "drag",
		"objective_label": "Prepará",
		"objective_message": "un almuerzo sin TACC\npara tu amigue con celiaquía",
	}
	var result: Dictionary = Normalizer.normalize_drag_objective(game, "celiaquia", "")
	_check(
		result.get("meal", "") == "un almuerzo sin TACC",
		"[DragObjective] objective_message: meal desde primera línea"
	)
	_check(
		result.get("connector", "") == "para tu amigue con celiaquía",
		"[DragObjective] objective_message: connector desde segunda línea"
	)


func _test_drag_objective_sin_objetivo_usa_fallback() -> void:
	# Sin objective ni campos planos, debe inferir meal por node_key y restriction por track_key.
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var result: Dictionary = Normalizer.normalize_drag_objective(
		{"type": "drag", "difficulty": 1},
		"celiaquia",
		"celiaquia_01_desayuno_basico"
	)
	_check(
		not str(result.get("meal", "")).strip_edges().is_empty(),
		"[DragObjective] sin objective: meal no puede estar vacio"
	)
	_check(
		not str(result.get("action", "")).strip_edges().is_empty(),
		"[DragObjective] sin objective: action no puede estar vacio"
	)
	_check(
		not str(result.get("connector", "")).strip_edges().is_empty(),
		"[DragObjective] sin objective: connector no puede estar vacio"
	)


func _test_drag_restriction_celiaquia_es_celiaquia() -> void:
	# Con track_key="celiaquia" y sin restriction explícita, debe aparecer "celiaquía".
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var result: Dictionary = Normalizer.normalize_drag_objective(
		{"type": "drag"},
		"celiaquia",
		"celiaquia_03_quiz_gluten"
	)
	_check(
		result.get("restriction", "") == "celiaquía",
		"[DragObjective] celiaquía debe tener restriction=celiaquía, got: %s" % result.get("restriction", "")
	)


func _test_drag_objective_renormalizacion_segura() -> void:
	# Un dict ya normalizado {action, meal, connector, restriction} debe sobrevivir
	# una segunda normalización en DragObjectiveText sin perder valores.
	var Normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var normalized_first: Dictionary = {
		"action": "Cociná",
		"meal": "un desayuno sin TACC",
		"connector": "para tu hermane",
		"restriction": "celiaquía",
	}
	var normalized_second: Dictionary = Normalizer.normalize_drag_objective(normalized_first)
	_check(
		normalized_second.get("action", "") == "Cociná",
		"[DragObjective] renormalización: action debe conservarse"
	)
	_check(
		normalized_second.get("meal", "") == "un desayuno sin TACC",
		"[DragObjective] renormalización: meal debe conservarse"
	)
	_check(
		normalized_second.get("connector", "") == "para tu hermane",
		"[DragObjective] renormalización: connector debe conservarse"
	)
	_check(
		normalized_second.get("restriction", "") == "celiaquía",
		"[DragObjective] renormalización: restriction debe conservarse"
	)


func _test_drag_objective_no_layout_runtime() -> void:
	# El script del componente no debe tener funciones que pisen posiciones
	# o tamaños de los labels en runtime. El layout debe vivir en el TSCN.
	const DOT_SCENE := "res://interface/components/DragObjectiveText/DragObjectiveText.tscn"
	var packed := load(DOT_SCENE) as PackedScene
	_check(packed != null, "[DragObjective] DragObjectiveText.tscn debe poder cargarse")
	if packed == null:
		return
	var instance := packed.instantiate()
	_check(
		not instance.has_method("_layout_nodes"),
		"[DragObjective] script no debe tener _layout_nodes() — el layout vive en el TSCN"
	)
	_check(
		not instance.has_method("_layout_labels"),
		"[DragObjective] script no debe tener _layout_labels() — el layout vive en el TSCN"
	)
	_check(
		not instance.has_method("_layout_objective"),
		"[DragObjective] script no debe tener _layout_objective() — el layout vive en el TSCN"
	)
	_check(
		instance.has_method("set_objective"),
		"[DragObjective] script debe exponer set_objective(data: Dictionary)"
	)
	instance.free()


func _test_objective_banner_no_activo() -> void:
	# ObjectiveBanner no debe estar instanciado en Level.tscn.
	# Si Level está en escena, chequearlo; si no, verificar que el packed scene
	# de ObjectiveBanner existe como archivo standalone no referenciado.
	if current_scene == null or current_scene.scene_file_path != LEVEL_SCENE:
		return
	_check(
		current_scene.get_node_or_null("ObjectiveBanner") == null,
		"[DragObjective] ObjectiveBanner no debe existir como nodo activo en Level."
	)


func _test_completar_palabra_router_conoce_modo() -> void:
	var RouterScript := MODALIDAD_ROUTER_SCRIPT
	var path: String = RouterScript.resolver_scene_path({"mode": "completar_palabra"})
	_check(not path.is_empty(), "[WO] ModalidadRouter debe resolver escena para completar_palabra")
	_check(path.ends_with(".tscn"), "[WO] La ruta resuelta debe ser una escena .tscn")


# ===========================================================================
# Ejecutor de todos los tests completar_palabra
# ===========================================================================

func ejecutar_tests_completar_palabra() -> void:
	print("[WordOptions] ── Iniciando tests unitarios ──")
	# JSON y Loader
	_test_completar_palabra_loader_carga_json_valido()
	_test_completar_palabra_loader_filtra_dificultad_invalida()
	_test_completar_palabra_contrato_json()
	_test_completar_palabra_loader_tiene_dificultades_1_2_3()
	_test_completar_palabra_acepta_formato_trainee()
	_test_drag_objective_anidado_y_fallback()
	_test_celiaquia_mapa_drag_objectives_completos()
	# DragObjectiveText
	_test_drag_objective_formato_plano()
	_test_drag_objective_mensaje_viejo()
	_test_drag_objective_sin_objetivo_usa_fallback()
	_test_drag_restriction_celiaquia_es_celiaquia()
	_test_drag_objective_renormalizacion_segura()
	_test_drag_objective_no_layout_runtime()
	_test_objective_banner_no_activo()
	# Integración
	_test_completar_palabra_router_conoce_modo()
	if not failed:
		print("[WordOptions] ✓ Todos los tests pasaron.")
	else:
		printerr("[WordOptions] ✗ Al menos un test falló. Revisá los errores arriba.")
