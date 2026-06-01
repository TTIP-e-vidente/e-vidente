extends SceneTree

const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const SaveManagerScript := preload("res://interface/SaveManager.gd")
const ContentIdValidatorScript := preload("res://sistemas/contenido/ContentIdValidator.gd")
var VincularConceptosScript = null  # lazy-loaded en _initialize para evitar error de autoload al compilar

const MAP_SCENE := "res://mapas/MapScene.tscn"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"
const QUESTION_SCENE := "res://preguntas/pregunta.tscn"
const VINCULAR_SCENE := "res://vincular/VincularConceptos.tscn"
const COMPLETAR_PALABRA_SCENE := "res://completar/completar_palabra.tscn"
const LEGACY_DRAG_DROP_SCENE := "res://mapas/drag_drop/DragDropNode.tscn"

const FINALIZACION_PARTIDA_SCENE := "res://mapas/finalizacion_partida.tscn"
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
const AVANCE_DE_NODO_SCRIPT := preload("res://mapas/logica/AvanceDeNodo.gd")
const MODALIDAD_ROUTER_SCRIPT := preload("res://sistemas/ModalidadRouter.gd")
const ARMADOR_DE_PARTIDA_SCRIPT := preload("res://mapas/logica/ArmadorDePartida.gd")
const NODE_CONTENT_LOADER_SCRIPT := preload("res://sistemas/contenido/NodeContentLoader.gd")
const MAP_LAYOUT_CONFIG_SCRIPT := preload("res://mapas/layout/MapLayoutConfig.gd")
const MAP_ROUTE_REGISTRY_SCRIPT := preload("res://mapas/layout/MapRouteRegistry.gd")
const MAP_PATH_LAYOUT_SCRIPT := preload("res://mapas/layout/MapPathLayout.gd")
const MAP_NODE_POSITION_RESOLVER_SCRIPT := preload("res://mapas/layout/MapNodePositionResolver.gd")


class FakeSaveManager:
	extends Node

	var played_global: Array[String] = []
	var completed_by_request: Dictionary = {}
	var completed_global: Array[String] = []
	var reset_called := false

	func get_played_activity_ids() -> Array[String]:
		return played_global.duplicate()

	func get_completed_activity_ids(request_key: String) -> Array[String]:
		var raw_ids: Variant = completed_by_request.get(request_key, [])
		var result: Array[String] = []
		if raw_ids is Array:
			for raw_id in raw_ids:
				result.append(str(raw_id).strip_edges())
		return result

	func get_all_used_activity_ids() -> Array[String]:
		var used_ids: Array[String] = played_global.duplicate()
		for activity_id in completed_global:
			if not used_ids.has(activity_id):
				used_ids.append(activity_id)
		return used_ids

	func get_all_completed_activity_ids() -> Array[String]:
		return completed_global.duplicate()

	func reset_completed_activity_pool(_request_key: String) -> void:
		reset_called = true

	func mark_activity_played(_request_key: String, activity_id: String) -> void:
		var clean_id: String = activity_id.strip_edges()
		if clean_id.is_empty():
			return
		if not played_global.has(clean_id):
			played_global.append(clean_id)
		print("[SaveManager] mark_played activity_id=%s" % clean_id)

	func mark_activity_completed(request_key: String, activity_id: String) -> void:
		var clean_id: String = activity_id.strip_edges()
		if clean_id.is_empty():
			return
		var clean_key: String = request_key.strip_edges()
		if clean_key.is_empty():
			clean_key = "__global__"
		if not completed_global.has(clean_id):
			completed_global.append(clean_id)
		var raw_ids: Variant = completed_by_request.get(clean_key, [])
		var id_list: Array = raw_ids if raw_ids is Array else []
		if not id_list.has(clean_id):
			id_list.append(clean_id)
		completed_by_request[clean_key] = id_list
		print("[SaveManager] mark_completed activity_id=%s" % clean_id)

var failed := false
var prueba_finalizada := false
var _save_files_preserved := false
var _save_file_snapshots: Dictionary = {}


func _initialize() -> void:
	VincularConceptosScript = load("res://vincular/vincular_conceptos.gd")
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
			(resultado_nodo_1.get("scene_kinds", []) as Array).has("completar_palabra"),
			"Nodo 1 deberia abrir completar_palabra (configuracion actual del mapa)."
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

	# --- Tests unitarios de validación de IDs de contenido ---
	if not failed:
		ejecutar_tests_ids_de_contenido()

	# --- Tests unitarios de variación de patrones visuales de vinculación ---
	if not failed:
		ejecutar_tests_vincular_variacion()

	# --- Tests unitarios del sistema de layout automático del mapa ---
	if not failed:
		ejecutar_tests_layout_del_mapa()

	if failed:
		finalizar_con_error()
		return


	_reset_test_state(global_state, save_manager)
	finalizar_ok()


func _reset_test_state(global_state, save_manager) -> void:
	global_state.reiniciar_progreso()
	ItemLevel.is_dragging = null
	ARMADOR_DE_PARTIDA_SCRIPT.reset_session_history()
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
			COMPLETAR_PALABRA_SCENE:
				await _completar_escena_completar_palabra(label)

		if failed:
			return result

		var next_scenes: Array[String] = [MAP_SCENE, FINALIZACION_PARTIDA_SCENE]
		next_scenes.append_array(GAME_SCENES)
		await _wait_for_any(next_scenes, "%s continuar" % label)
		if (
			current_scene != null
			and current_scene.scene_file_path == FINALIZACION_PARTIDA_SCENE
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
	await create_timer(1.5).timeout
	if not is_instance_valid(level_scene):
		result["teaching_seen"] = true
		return
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
	# La navegación es diferida (GameSceneRouter + transición).
	# Esperar hasta que la escena Level sea efectivamente reemplazada para que el
	# bucle externo no reingrese a _completar_escena_drag sobre la misma escena.
	for _i in 80:
		await process_frame
		if not is_instance_valid(level_scene):
			return  # liberada — OK
		if current_scene != null and current_scene.scene_file_path != LEVEL_SCENE:
			return  # la escena cambió — OK


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
	if not is_instance_valid(question_scene):
		return  # quiz ya auto-avanzó al siguiente juego
	var continuar := question_scene.get_node_or_null("Contenido/ContinuarJuego") as Control
	_check(continuar != null and continuar.visible, "%s: quiz deberia mostrar continuar." % label)
	if failed:
		return
	question_scene.call("continuar_al_siguiente_nodo")
	# La navegación es diferida (GameSceneRouter + transición).
	# Esperar hasta que la escena quiz sea efectivamente reemplazada para que el
	# bucle externo no reingrese a _completar_escena_quiz sobre la misma escena.
	for _i in 80:
		await process_frame
		if not is_instance_valid(question_scene):
			return  # liberada — OK
		if current_scene != null and current_scene.scene_file_path != QUESTION_SCENE:
			return  # la escena cambió — OK


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
	_verificar_reselect_tras_error(match_scene)
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
	# La navegación al siguiente juego es diferida (GameSceneRouter + transición).
	# Esperar hasta que la escena vincular sea efectivamente reemplazada para que el
	# bucle externo no reingrese a _completar_escena_match sobre la misma escena.
	for _i in 80:
		await process_frame
		if not is_instance_valid(match_scene):
			return  # liberada — OK
		if current_scene != null and current_scene.scene_file_path != VINCULAR_SCENE:
			return  # la escena cambió — OK


func _resolver_vinculacion_correcta(match_scene: Node) -> void:
	var items_izquierda: Array = match_scene.get("items_izquierda") as Array
	var items_derecha: Array = match_scene.get("items_derecha") as Array
	# El primer par se resuelve derecha→izquierda para cubrir la validación bidireccional.
	var primer_par_resuelto := false
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
			if not primer_par_resuelto:
				# Cubrir validación bidireccional: seleccionar derecha primero, luego izquierda.
				match_scene.call("seleccionar_derecha", item_derecha)
				match_scene.call("seleccionar_izquierda", item_izquierda)
				primer_par_resuelto = true
			else:
				match_scene.call("seleccionar_izquierda", item_izquierda)
				match_scene.call("vincular_con_derecha", item_derecha)
			break


func _match_slots_cubren_total(match_scene: Node, total_pares: int) -> bool:
	var items_izquierda: Array = match_scene.get("items_izquierda") as Array
	var items_derecha: Array = match_scene.get("items_derecha") as Array
	if total_pares <= 0:
		return false
	return items_izquierda.size() >= total_pares and items_derecha.size() >= total_pares


func _verificar_reselect_tras_error(match_scene: Node) -> void:
	# Verifica la regla WRONG + click = SELECTED: un item en error debe limpiar su estado
	# y quedar como seleccion_actual cuando el jugador hace click sobre él nuevamente.
	var items_izquierda: Array = match_scene.get("items_izquierda") as Array
	var items_derecha: Array = match_scene.get("items_derecha") as Array

	var iz: ConceptoItem = null
	var der_wrong: ConceptoItem = null

	for raw in items_izquierda:
		var item := raw as ConceptoItem
		if item != null and is_instance_valid(item) and item.visible:
			iz = item
			break
	for raw in items_derecha:
		var item := raw as ConceptoItem
		if item != null and is_instance_valid(item) and item.visible:
			if iz != null and item.par_key != iz.par_key:
				der_wrong = item
				break

	if iz == null or der_wrong == null:
		# Todos los pares comparten clave o no hay items: no se puede probar el caso incorrecto.
		return

	# 1. Crear una vinculación incorrecta.
	match_scene.call("seleccionar_izquierda", iz)
	match_scene.call("vincular_con_derecha", der_wrong)
	_check(iz.tiene_error, "[MatchReselect] item debe tener error tras vincular incorrecto")

	# 2. Re-seleccionar el item en error; la fix debe limpiar el estado.
	match_scene.call("seleccionar_izquierda", iz)
	_check(
		not iz.tiene_error,
		"[MatchReselect] re-click en item con error debe limpiar tiene_error"
	)
	# La vinculacion previa no debe borrarse: el otro extremo se mantiene en WRONG.
	_check(
		iz.vinculada_con != null,
		"[MatchReselect] re-click NO debe limpiar la vinculacion anterior"
	)
	_check(
		der_wrong.tiene_error,
		"[MatchReselect] la otra opción debe permanecer en error"
	)
	_check(
		match_scene.get("seleccion_actual") == iz,
		"[MatchReselect] item reseleccionado debe quedar como seleccion_actual"
	)

	# Restablecer el estado para que _resolver_vinculacion_correcta pueda continuar limpio.
	iz.limpiar_vinculo()
	match_scene.set("seleccion_actual", null)
	match_scene.set("seleccion_derecha_pendiente", null)

func _completar_escena_completar_palabra(label: String) -> void:
	var wo_scene := current_scene
	_check(
		wo_scene.has_method("configurar"),
		"%s: completar_palabra deberia exponer configurar()." % label
	)
	if failed:
		return
	# La escena se autoconfigura en _ready() via NodoRuntime.obtener_actividad_actual().
	# Para el smoke test, presionamos todos los botones disponibles (uno por blank)
	# y luego el ConfirmButton si existe y está habilitado.
	var options_container := (
		wo_scene.get_node_or_null("Control/HBoxContainer") as Container)
	_check(
		options_container != null,
		"%s: completar_palabra deberia tener Control/HBoxContainer." % label
	)
	if failed or options_container == null:
		return

	# Esperar a que los botones estén habilitados (typewriter + reveal son async, ~2s)
	for _w in 240:
		if not is_instance_valid(options_container):
			return
		var hay_habilitado := false
		for child in options_container.get_children():
			if child is Button and not (child as Button).disabled:
				hay_habilitado = true
				break
		if hay_habilitado:
			break
		await process_frame

	if not is_instance_valid(options_container):
		return

	# Recopilar botones disponibles (sin disabled)
	var buttons: Array = []
	for child in options_container.get_children():
		if child is Button and not (child as Button).disabled:
			buttons.append(child as Button)
	_check(
		not buttons.is_empty(),
		"%s: completar_palabra deberia tener botones de opciones." % label
	)
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
	if not is_instance_valid(wo_scene):
		return  # la escena ya avanzó sola — OK
	# Disparar continuar explícitamente para forzar el avance
	# (_al_solicitar_continuar_juego tiene su propio guard _continue_requested).
	if wo_scene.has_method("_al_solicitar_continuar_juego"):
		wo_scene.call("_al_solicitar_continuar_juego")
	# La navegación es diferida. Esperar hasta que la escena sea efectivamente reemplazada.
	for _i in 80:
		await process_frame
		if not is_instance_valid(wo_scene):
			return  # liberada — OK
		if current_scene != null and current_scene.scene_file_path != COMPLETAR_PALABRA_SCENE:
			return  # la escena cambió — OK


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
			# Esperar que la animación de entrada del router termine
			var router = root.get_node_or_null("/root/GameSceneRouter")
			for _j in 40:
				if router == null or not router.get("_is_transitioning"):
					break
				await process_frame
			return
	_check(false, "No se llego a %s (%s)" % [label, expected_path])


func _wait_for_any(expected_paths: Array, label: String) -> void:
	for i in 60:
		if failed or prueba_finalizada:
			return
		await process_frame
		if current_scene != null and expected_paths.has(current_scene.scene_file_path):
			# Esperar que la animación de entrada del router termine
			var router = root.get_node_or_null("/root/GameSceneRouter")
			for _j in 40:
				if router == null or not router.get("_is_transitioning"):
					break
				await process_frame
			return
	_check(false, "No se llego a %s (%s)" % [label, ", ".join(expected_paths)])


func _delete_save_files() -> void:
	var override_dir: String = OS.get_environment("EVIDENTE_SAVE_DIR").strip_edges()
	for path in [
		SaveManagerScript.SAVE_PATH,
		SaveManagerScript.TEMP_SAVE_PATH,
		SaveManagerScript.BACKUP_SAVE_PATH
	]:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
		if not override_dir.is_empty():
			var override_abs: String = override_dir.path_join(path.get_file())
			if FileAccess.file_exists(override_abs):
				DirAccess.remove_absolute(override_abs)


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
	var loader := CARGADOR_COMPLETAR_SCRIPT
	loader.limpiar_cache()
	var result: Dictionary = loader.elegir(1)
	_check(not result.is_empty(), "[WO] pick(1) debe devolver un desafío no vacío")
	_check(result.has("sentence"), "[WO] pick(1) debe tener campo sentence")
	_check(result.has("screen_title"), "[WO] pick(1) debe tener campo screen_title")
	_check(result.has("answers"), "[WO] pick(1) debe tener campo answers")
	_check(result.has("options"), "[WO] pick(1) debe tener campo options")
	_check(result.has("id"), "[WO] pick(1) debe incluir el id del desafío")


func _test_completar_palabra_loader_filtra_dificultad_invalida() -> void:
	var loader := CARGADOR_COMPLETAR_SCRIPT
	loader.limpiar_cache()
	var result: Dictionary = loader.elegir(99)
	_check(result.is_empty(), "[WO] pick(99) debe devolver {} (sin desafíos para esa dificultad)")


func _test_completar_palabra_contrato_json() -> void:
	# Verificar que TODOS los desafíos del JSON cumplen el contrato
	var loader := CARGADOR_COMPLETAR_SCRIPT
	loader.limpiar_cache()
	var all_challenges: Dictionary = loader.cargar_todo()
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
	var loader := CARGADOR_COMPLETAR_SCRIPT
	loader.limpiar_cache()
	_check(not loader.elegir(1).is_empty(), "[WO] debe haber desafíos de dificultad 1")
	_check(not loader.elegir(2).is_empty(), "[WO] debe haber desafíos de dificultad 2")
	_check(not loader.elegir(3).is_empty(), "[WO] debe haber desafíos de dificultad 3")


# ===========================================================================
# Tests unitarios: contrato de contenido y normalización.
# ===========================================================================

func _test_completar_palabra_acepta_formato_trainee() -> void:
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var raw: Dictionary = {
		"id": "word_test",
		"mode": "completar_palabra",
		"difficulty": 1,
		"screen_title": "Elegí la opción correcta",
		"prompt": "El producto apto no tiene ____.",
		"correct_answers": ["gluten"],
		"choices": ["gluten", "sal"],
	}
	var normalized: Dictionary = normalizer.normalize_word_game("word_test", raw)
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
	var old_normalized: Dictionary = normalizer.normalize_word_game("word_old", old_raw)
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
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var explicit_game: Dictionary = {
		"type": "drag",
		"objective": {
			"action": "Prepara",
			"meal": "una cena sin TACC",
			"connector": "para tu amigue",
			"restriction": "celiaquía",
		},
	}
	var explicit_objective: Dictionary = normalizer.normalize_drag_objective(
		explicit_game,
		"celiaquia",
		"celiaquia_14_comer_fuera"
	)
	_check(
		explicit_objective.get("meal", "") == "una cena sin TACC",
		"[DragObjective] debe respetar objective.meal"
	)
	var fallback_objective: Dictionary = normalizer.normalize_drag_objective(
		{"type": "drag"},
		"celiaquia",
		"celiaquia_02_colacion_basica"
	)
	_check(
		fallback_objective.get("meal", "") != "",
		"[DragObjective] debe inferir meal por node_key"
	)
	_check(fallback_objective.get("action", "") != "", "[DragObjective] fallback debe tener action")
	_check(
		fallback_objective.get("connector", "") != "",
		"[DragObjective] fallback debe tener connector"
	)


func _test_celiaquia_mapa_drag_objectives_completos() -> void:
	var map_loader := CARGADOR_DE_MAPA_SCRIPT
	var result: Dictionary = map_loader.load_map("res://contenido/mapa/celiaquia_mapa.json")
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
			_check(
				objective_raw is Dictionary,
				"[DragObjective] drag debe tener objective Dictionary"
			)
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
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var game: Dictionary = {
		"type": "drag",
		"objective_action": "Armá",
		"objective_meal": "una merienda sin TACC",
		"objective_connector": "para tu compañere",
		"objective_restriction": "celiaquía",
	}
	var result: Dictionary = normalizer.normalize_drag_objective(game, "celiaquia", "")
	_check(result.get("action", "") == "Armá", "[DragObjective] formato plano: action")
	_check(
		result.get("meal", "") == "una merienda sin TACC",
		"[DragObjective] formato plano: meal"
	)
	_check(
		result.get("connector", "") == "para tu compañere",
		"[DragObjective] formato plano: connector"
	)
	_check(
		result.get("restriction", "") == "celiaquía",
		"[DragObjective] formato plano: restriction"
	)


func _test_drag_objective_mensaje_viejo() -> void:
	# Acepta objective_message con formato "linea1\nlinea2".
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var game: Dictionary = {
		"type": "drag",
		"objective_label": "Prepará",
		"objective_message": "un almuerzo sin TACC\npara tu amigue con celiaquía",
	}
	var result: Dictionary = normalizer.normalize_drag_objective(game, "celiaquia", "")
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
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var result: Dictionary = normalizer.normalize_drag_objective(
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
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var result: Dictionary = normalizer.normalize_drag_objective(
		{"type": "drag"},
		"celiaquia",
		"celiaquia_03_quiz_gluten"
	)
	_check(
		result.get("restriction", "") == "celiaquía",
		(
			"[DragObjective] celiaquía debe tener restriction=celiaquía, got: %s"
			% result.get("restriction", "")
		)
	)


func _test_drag_objective_renormalizacion_segura() -> void:
	# Un dict ya normalizado {action, meal, connector, restriction} debe sobrevivir
	# una segunda normalización en DragObjectiveText sin perder valores.
	var normalizer := CONTENT_SCHEMA_NORMALIZER_SCRIPT
	var normalized_first: Dictionary = {
		"action": "Cociná",
		"meal": "un desayuno sin TACC",
		"connector": "para tu hermane",
		"restriction": "celiaquía",
	}
	var normalized_second: Dictionary = normalizer.normalize_drag_objective(normalized_first)
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
	var router_script := MODALIDAD_ROUTER_SCRIPT
	var path: String = router_script.resolver_scene_path({"mode": "completar_palabra"})
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


# ===========================================================================
# Tests unitarios: validación de IDs de contenido
# ===========================================================================

func _test_content_id_formato_valido() -> void:
	var validator := ContentIdValidatorScript
	_check(validator.is_valid_format("node_bosque_01"),
		"[ContentId] snake_case válido debe pasar")
	_check(validator.is_valid_format("quiz_001"),
		"[ContentId] prefijo con dígitos debe pasar")
	_check(
		validator.is_valid_format("match_categorias_alimentos"),
		"[ContentId] múltiples palabras debe pasar"
	)
	_check(validator.is_valid_format("drag_food_01"),
		"[ContentId] drag_food prefijo debe pasar")
	_check(validator.is_valid_format("a"),
		"[ContentId] id de un carácter válido debe pasar")


func _test_content_id_formato_invalido() -> void:
	var validator := ContentIdValidatorScript
	_check(not validator.is_valid_format(""), "[ContentId] id vacío debe fallar")
	_check(
		not validator.is_valid_format("Juego 1"),
		"[ContentId] id con espacios y mayúscula debe fallar"
	)
	_check(not validator.is_valid_format("juego 1"),
		"[ContentId] id con espacio debe fallar")
	_check(
		not validator.is_valid_format("1_quiz"),
		"[ContentId] id que empieza con dígito debe fallar"
	)
	_check(not validator.is_valid_format("Node_01"),
		"[ContentId] id con mayúscula debe fallar")
	_check(not validator.is_valid_format("quiz-001"),
		"[ContentId] id con guión debe fallar")


func _test_content_id_no_usa_texto_visible_como_clave() -> void:
	var validator := ContentIdValidatorScript
	_check(
		not validator.is_valid_format("Pregunta difícil"),
		"[ContentId] texto visible como id debe fallar"
	)
	_check(
		validator.is_valid_format("celiaquia_desayuno_basico"),
		"[ContentId] versión snake_case del mismo texto debe pasar"
	)


func _test_validate_activity_ids_detecta_id_faltante() -> void:
	var activities: Array = [
		{"id": "quiz_001", "mode": "quiz"},
		{"mode": "drag"},  # Sin id
	]
	var errors: Array[String] = ContentIdValidatorScript.validate_activity_ids(
		activities, "test.json"
	)
	_check(not errors.is_empty(), "[ContentId] id faltante debe generar error")
	var tiene_missing := false
	for e in errors:
		if "Missing" in e:
			tiene_missing = true
	_check(tiene_missing, "[ContentId] error debe indicar falta de id")


func _test_validate_activity_ids_detecta_id_duplicado() -> void:
	var activities: Array = [
		{"id": "quiz_001", "mode": "quiz"},
		{"id": "quiz_001", "mode": "quiz"},  # Duplicado
	]
	var errors: Array[String] = ContentIdValidatorScript.validate_activity_ids(
		activities, "test.json"
	)
	_check(not errors.is_empty(), "[ContentId] id duplicado debe generar error")
	var tiene_duplicate := false
	for e in errors:
		if "Duplicate" in e:
			tiene_duplicate = true
	_check(tiene_duplicate, "[ContentId] error debe indicar duplicado")


func _test_validate_activity_ids_acepta_ids_unicos() -> void:
	var activities: Array = [
		{"id": "quiz_001", "mode": "quiz"},
		{"id": "drag_001", "mode": "drag"},
		{"id": "match_001", "mode": "match"},
	]
	var errors: Array[String] = ContentIdValidatorScript.validate_activity_ids(
		activities, "test.json"
	)
	var tiene_critico := false
	for e in errors:
		if "Missing" in e or "Duplicate" in e:
			tiene_critico = true
	_check(not tiene_critico, "[ContentId] ids únicos y válidos no deben generar errores críticos")


func _test_filter_uncompleted_filtra_completados() -> void:
	var all_content: Array = [
		{"id": "quiz_001", "mode": "quiz"},
		{"id": "drag_001", "mode": "drag"},
		{"id": "match_001", "mode": "match"},
	]
	var completed_ids: Array[String] = ["quiz_001", "match_001"]
	var available: Array = ContentIdValidatorScript.filter_uncompleted(
		all_content, completed_ids
	)
	_check(available.size() == 1, "[ContentId] filter debe dejar solo los no completados")
	var id_restante: String = str((available[0] as Dictionary).get("id", ""))
	_check(id_restante == "drag_001", "[ContentId] filter debe conservar el id no completado")


func _test_filter_uncompleted_mantiene_todo_sin_historial() -> void:
	var all_content: Array = [
		{"id": "quiz_001"},
		{"id": "drag_001"},
	]
	var available: Array = ContentIdValidatorScript.filter_uncompleted(all_content, [])
	_check(available.size() == 2, "[ContentId] sin historial, filter no debe quitar nada")


func _test_filter_uncompleted_pool_agotado_devuelve_vacio() -> void:
	var all_content: Array = [
		{"id": "quiz_001"},
		{"id": "quiz_002"},
	]
	var completed_ids: Array[String] = ["quiz_001", "quiz_002"]
	var available: Array = ContentIdValidatorScript.filter_uncompleted(
		all_content, completed_ids
	)
	_check(available.is_empty(), "[ContentId] pool agotado debe devolver lista vacía")


# ===========================================================================
# Ejecutor de todos los tests de validación de IDs de contenido
# ===========================================================================

func _test_armador_no_resetea_pool_ni_repite_ids_completados() -> void:
	ARMADOR_DE_PARTIDA_SCRIPT.reset_session_history()
	var fake_save := FakeSaveManager.new()
	var request_key := "drag|1|0"
	var completed_ids: Array[String] = NODE_CONTENT_LOADER_SCRIPT.get_activity_candidates(
		"celiaquia",
		"drag",
		1
	)
	_check(not completed_ids.is_empty(), "[Armador] fixture debe tener drag dificultad 1")
	fake_save.completed_by_request[request_key] = completed_ids.duplicate()
	fake_save.completed_global = completed_ids.duplicate()
	root.add_child(fake_save)
	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(fake_save)

	var node_data: MapNodeData = _get_test_map_node("celiaquia_02_colacion_basica")
	var plan: Dictionary = ARMADOR_DE_PARTIDA_SCRIPT.construir_plan_de_partida(node_data)
	var selected_ids: Array[String] = _extract_plan_activity_ids(plan)

	_check(not fake_save.reset_called, "[Armador] pool agotado no debe resetear historial")
	_check(not selected_ids.is_empty(), "[Armador] debe armar con fallback no completado")
	for selected_id in selected_ids:
		_check(
			not completed_ids.has(selected_id),
			"[Armador] no debe seleccionar activity_id completado: %s" % selected_id
		)

	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(root.get_node_or_null("/root/SaveManager"))
	fake_save.queue_free()


func _test_armador_filtra_ids_jugados_y_completados() -> void:
	var candidates: Array[String] = ["actividad_a", "actividad_b", "actividad_c"]
	var used_in_plan: Array[String] = []
	var used_history: Array[String] = ["actividad_b"]
	var available: Array[String] = ARMADOR_DE_PARTIDA_SCRIPT._filter_unavailable_activity_candidates(
		candidates,
		used_in_plan,
		used_history
	)
	_check(available.size() == 2, "[Armador] filtro debe quitar IDs usados")
	_check(available.has("actividad_a"), "[Armador] filtro debe conservar actividad_a")
	_check(not available.has("actividad_b"), "[Armador] filtro debe quitar actividad_b")
	_check(available.has("actividad_c"), "[Armador] filtro debe conservar actividad_c")


func _test_armador_plan_no_admite_ids_repetidos() -> void:
	var games: Array[Dictionary] = [
		{"activity_id": "actividad_a"},
		{"activity_id": "actividad_a"},
	]
	var valid: bool = ARMADOR_DE_PARTIDA_SCRIPT._validate_final_game_ids("test_node", games)
	_check(not valid, "[Armador] plan con activity_id repetido debe ser invalido")


func _test_save_manager_guarda_played_y_completed_por_id() -> void:
	var save_manager := SaveManagerScript.new()
	save_manager.save_data = {
		"played_activity_ids": [],
		"completed_activity_ids": [],
		"completed_activity_ids_by_request": {},
		"profile": {},
		"progress": {},
		"save_meta": {},
	}
	save_manager.mark_activity_played("quiz|1|0", "actividad_a")
	save_manager.mark_activity_completed("quiz|1|0", "actividad_a")
	_check(
		save_manager.get_played_activity_ids().has("actividad_a"),
		"[SaveManager] mark_played debe guardar activity_id"
	)
	_check(
		save_manager.get_all_completed_activity_ids().has("actividad_a"),
		"[SaveManager] mark_completed debe guardar activity_id global"
	)
	_check(
		save_manager.get_completed_activity_ids("quiz|1|0").has("actividad_a"),
		"[SaveManager] mark_completed debe guardar activity_id por request legacy"
	)


func _get_test_map_node(node_key: String) -> MapNodeData:
	var result: Dictionary = CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	if not bool(result.get("ok", false)):
		return null
	var nodes: Array = result.get("data", {}).get("nodes", [])
	for raw_node in nodes:
		var node_data: MapNodeData = raw_node as MapNodeData
		if node_data != null and node_data.node_key == node_key:
			return node_data
	return null


func _extract_plan_activity_ids(plan: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var games: Array = plan.get("juegos", [])
	for raw_game in games:
		if not raw_game is Dictionary:
			continue
		var activity_id: String = str((raw_game as Dictionary).get("activity_id", "")).strip_edges()
		if not activity_id.is_empty():
			result.append(activity_id)
	return result


# ===========================================================================
# Tests unitarios: filtrado por ID y progresión sin repetición
# ===========================================================================

func _test_armador_plan_rechaza_actividad_sin_id() -> void:
	var games: Array[Dictionary] = [
		{"activity_id": "actividad_a"},
		{"activity_id": ""},  # Sin ID
	]
	var valid: bool = ARMADOR_DE_PARTIDA_SCRIPT._validate_final_game_ids("test_node", games)
	_check(not valid, "[Armador] actividad sin activity_id debe invalidar el plan")


func _test_save_manager_permite_request_key_vacia() -> void:
	# Verifica que mark_played/mark_completed con request_key vacía persiste
	# el activity_id bajo la clave __global__ (cubre juegos fijos y legacy).
	var save_manager := SaveManagerScript.new()
	save_manager.save_data = {
		"completed_activity_ids_by_request": {},
		"profile": {},
		"progress": {},
		"save_meta": {},
	}
	save_manager.mark_activity_played("", "actividad_fija_1")
	_check(
		save_manager.get_all_used_activity_ids().has("actividad_fija_1"),
		"[SaveManager] mark_played con request_key vacío debe registrar activity_id"
	)
	save_manager.mark_activity_completed("", "actividad_fija_2")
	_check(
		save_manager.get_all_used_activity_ids().has("actividad_fija_2"),
		"[SaveManager] mark_completed con request_key vacío debe registrar activity_id"
	)
	var global_ids: Array[String] = save_manager.get_completed_activity_ids("__global__")
	_check(
		global_ids.has("actividad_fija_1") and global_ids.has("actividad_fija_2"),
		"[SaveManager] actividades con key vacía deben guardarse bajo __global__"
	)


func _test_armador_progresion_ids_unicos() -> void:
	# Simula varias rondas consecutivas sobre el mismo nodo y verifica que
	# ningún activity_id se repite entre rondas.
	ARMADOR_DE_PARTIDA_SCRIPT.reset_session_history()
	var fake_save := FakeSaveManager.new()
	root.add_child(fake_save)
	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(fake_save)

	var node_data: MapNodeData = _get_test_map_node(NODE_5_KEY)
	_check(node_data != null, "[Progresion] nodo de prueba debe existir")

	if node_data != null:
		var todos_ids_seleccionados: Array[String] = []
		for _ronda in range(4):
			var plan: Dictionary = ARMADOR_DE_PARTIDA_SCRIPT.construir_plan_de_partida(node_data)
			if plan.is_empty():
				break
			var ids_plan: Array[String] = _extract_plan_activity_ids(plan)
			_check(not ids_plan.is_empty(), "[Progresion] plan debe tener activity_ids")
			for activity_id in ids_plan:
				_check(
					not todos_ids_seleccionados.has(activity_id),
					"[Progresion] activity_id repetido en progresión: %s" % activity_id
				)
				todos_ids_seleccionados.append(activity_id)
				fake_save.mark_activity_played("", activity_id)
				fake_save.mark_activity_completed("", activity_id)
			ARMADOR_DE_PARTIDA_SCRIPT.reset_session_history()

	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(root.get_node_or_null("/root/SaveManager"))
	fake_save.queue_free()


func _test_validacion_detecta_modalidades_repetidas() -> void:
	# _validar_plan_sin_modalidades_repetidas debe rechazar dos juegos del mismo tipo.
	var plan_con_repeticion: Array[Dictionary] = [
		{"activity_id": "actividad_a", "type": "drag", "allow_repeated_type": false},
		{"activity_id": "actividad_b", "type": "drag", "allow_repeated_type": false},
	]
	var es_valido: bool = ARMADOR_DE_PARTIDA_SCRIPT._validar_plan_sin_modalidades_repetidas(
		"test_node",
		plan_con_repeticion
	)
	_check(not es_valido, "[Armador] plan con modalidad repetida debe ser inválido")


func _test_validacion_permite_modalidad_repetida_con_flag() -> void:
	# Con allow_repeated_type=true en el segundo juego, el plan debe ser válido.
	var plan_con_flag: Array[Dictionary] = [
		{"activity_id": "actividad_a", "type": "drag", "allow_repeated_type": false},
		{"activity_id": "actividad_b", "type": "drag", "allow_repeated_type": true},
	]
	var es_valido: bool = ARMADOR_DE_PARTIDA_SCRIPT._validar_plan_sin_modalidades_repetidas(
		"test_node",
		plan_con_flag
	)
	_check(es_valido, "[Armador] plan con allow_repeated_type=true no debe ser inválido")


func _test_armador_plan_nodo_real_sin_modalidades_repetidas() -> void:
	# El plan de un nodo real no debe contener modalidades repetidas (salvo permiso explicit).
	ARMADOR_DE_PARTIDA_SCRIPT.reset_session_history()
	var fake_save := FakeSaveManager.new()
	root.add_child(fake_save)
	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(fake_save)

	var node_data: MapNodeData = _get_test_map_node(NODE_5_KEY)
	if node_data == null:
		ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(root.get_node_or_null("/root/SaveManager"))
		fake_save.queue_free()
		return

	var plan: Dictionary = ARMADOR_DE_PARTIDA_SCRIPT.construir_plan_de_partida(node_data)
	var games: Array = plan.get("juegos", [])
	var plan_array: Array[Dictionary] = []
	for raw_game in games:
		plan_array.append(raw_game as Dictionary)
	var es_valido: bool = ARMADOR_DE_PARTIDA_SCRIPT._validar_plan_sin_modalidades_repetidas(
		NODE_5_KEY,
		plan_array
	)
	_check(es_valido, "[Armador] plan de nodo real no debe tener modalidades repetidas")

	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(root.get_node_or_null("/root/SaveManager"))
	fake_save.queue_free()


func _test_armador_pool_agotado_no_crashea() -> void:
	# Si todos los activity_ids del pool están usados, el plan devuelve vacío sin crashear.
	ARMADOR_DE_PARTIDA_SCRIPT.reset_session_history()
	var fake_save := FakeSaveManager.new()
	root.add_child(fake_save)
	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(fake_save)

	var node_data: MapNodeData = _get_test_map_node(NODE_6_KEY)
	if node_data == null:
		ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(root.get_node_or_null("/root/SaveManager"))
		fake_save.queue_free()
		return

	# Marcar como jugados todos los candidatos de todos los modos soportados.
	for mode in ["drag", "quiz", "vinculacion", "completar"]:
		for dif in [1, 2, 3, 4, 5]:
			var cands: Array[String] = NODE_CONTENT_LOADER_SCRIPT.get_activity_candidates(
				"celiaquia", mode, dif
			)
			for cid in cands:
				fake_save.mark_activity_played("", cid)
				fake_save.mark_activity_completed("", cid)

	var plan: Dictionary = ARMADOR_DE_PARTIDA_SCRIPT.construir_plan_de_partida(node_data)
	_check(
		plan.is_empty(),
		"[Armador] pool agotado debe devolver plan vacío, no crashear"
	)
	_check(not fake_save.reset_called, "[Armador] pool agotado no debe resetear historial")

	ARMADOR_DE_PARTIDA_SCRIPT.init_with_save_manager(root.get_node_or_null("/root/SaveManager"))
	fake_save.queue_free()


func _test_save_manager_precision_no_forzada_al_100() -> void:
	# save_node_accuracy debe conservar la precisión real, no forzar 100%.
	var save_manager := SaveManagerScript.new()
	save_manager.save_data = {
		"node_progress": {},
		"profile": {},
		"progress": {},
		"save_meta": {},
	}
	save_manager.save_node_accuracy("nodo_test", 40.0, 3, 5)
	var prog: Dictionary = save_manager.get_node_progress_entry("nodo_test") \
		if save_manager.has_method("get_node_progress_entry") \
		else save_manager.save_data.get("node_progress", {}).get("nodo_test", {}) as Dictionary
	var last_accuracy: float = float(prog.get("last_accuracy", -1.0))
	var best_percent: float = float(prog.get("best_percent", -1.0))
	_check(
		absf(last_accuracy - 40.0) < 0.01,
		"[SaveManager] last_accuracy debe ser 40, no 100. Obtenido: %s" % str(last_accuracy)
	)
	_check(
		best_percent <= 0.41,
		"[SaveManager] best_percent con precisión 40%% debe ser ≤0.41. Obtenido: %s" % str(best_percent)
	)
	_check(
		bool(prog.get("completed", false)),
		"[SaveManager] completed debe ser true aunque precisión sea 40%%"
	)


func _test_curva_real_mapa_todos_los_nodos_sin_posicion_manual() -> void:
	var result: Dictionary = CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	_check(bool(result.get("ok", false)), "[MapaReal] Debe cargar el JSON exitosamente")
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	var nodes: Array = data.get("nodes", [])
	_check(nodes.size() == 30, "[MapaReal] Debe haber 30 nodos. Obtenido: %d" % nodes.size())

	# Verificar sección layout con route_id = RutaCeliaquia1
	var layout_config: MapLayoutConfig = data.get("layout_config", null) as MapLayoutConfig
	_check(layout_config != null, "[MapaReal] Debe existir layout_config parseado")
	if layout_config != null:
		_check(
			layout_config.obtener_route_id() == "RutaCeliaquia1",
			"[MapaReal] route_id debe ser 'RutaCeliaquia1'. Obtenido: '%s'" % layout_config.obtener_route_id()
		)

	# Ningún nodo debe tener map_position — todos usan la curva
	var nodos_con_pos: int = 0
	var nodos_sin_pos: int = 0
	for raw_node in nodes:
		var nd: MapNodeData = raw_node as MapNodeData
		if nd == null:
			continue
		if nd.has_map_position:
			nodos_con_pos += 1
		else:
			nodos_sin_pos += 1
	_check(nodos_con_pos == 0, "[MapaReal] Ningún nodo debe tener map_position. Con pos: %d" % nodos_con_pos)
	_check(nodos_sin_pos == 30, "[MapaReal] Los 30 nodos deben usar curva. Sin pos: %d" % nodos_sin_pos)

	# Verificar que todos los nodos no tienen map_position
	for raw_node in nodes:
		var nd: MapNodeData = raw_node as MapNodeData
		if nd == null:
			continue
		_check(not nd.has_map_position, "[MapaReal] %s no debe tener map_position" % nd.node_key)



func ejecutar_tests_ids_de_contenido() -> void:
	print("[ContentId] ── Iniciando tests de validación de IDs ──")
	_test_content_id_formato_valido()
	_test_content_id_formato_invalido()
	_test_content_id_no_usa_texto_visible_como_clave()
	_test_validate_activity_ids_detecta_id_faltante()
	_test_validate_activity_ids_detecta_id_duplicado()
	_test_validate_activity_ids_acepta_ids_unicos()
	_test_filter_uncompleted_filtra_completados()
	_test_filter_uncompleted_mantiene_todo_sin_historial()
	_test_filter_uncompleted_pool_agotado_devuelve_vacio()
	_test_armador_filtra_ids_jugados_y_completados()
	_test_armador_no_resetea_pool_ni_repite_ids_completados()
	_test_armador_plan_no_admite_ids_repetidos()
	_test_armador_plan_rechaza_actividad_sin_id()
	_test_save_manager_guarda_played_y_completed_por_id()
	_test_save_manager_permite_request_key_vacia()
	_test_armador_progresion_ids_unicos()
	_test_validacion_detecta_modalidades_repetidas()
	_test_validacion_permite_modalidad_repetida_con_flag()
	_test_armador_plan_nodo_real_sin_modalidades_repetidas()
	_test_armador_pool_agotado_no_crashea()
	_test_save_manager_precision_no_forzada_al_100()
	_test_curva_real_mapa_todos_los_nodos_sin_posicion_manual()
	if not failed:
		print("[ContentId] ✓ Todos los tests pasaron.")
	else:
		printerr("[ContentId] ✗ Al menos un test falló. Revisá los errores arriba.")


# ===========================================================================
# Tests unitarios: variación del patrón visual de vinculación
# ===========================================================================

func _test_match_firma_patron_es_determinista() -> void:
	var pares: Array = [
		{"id": "a_iz", "id_par": "grupo_1"},
		{"id": "b_iz", "id_par": "grupo_2"},
		{"id": "c_iz", "id_par": "grupo_3"},
	]
	var firma1: String = VincularConceptosScript.construir_firma_patron(pares, pares)
	var firma2: String = VincularConceptosScript.construir_firma_patron(pares, pares)
	_check(firma1 == firma2, "[MatchShuffle] misma entrada => misma firma")
	_check(not firma1.is_empty(), "[MatchShuffle] firma no debe estar vacía")


func _test_match_firma_patron_cambia_con_orden() -> void:
	var orden_a: Array = [
		{"id": "a_iz", "id_par": "grupo_1"},
		{"id": "b_iz", "id_par": "grupo_2"},
	]
	var orden_b: Array = [
		{"id": "b_iz", "id_par": "grupo_2"},
		{"id": "a_iz", "id_par": "grupo_1"},
	]
	var firma_az: String = VincularConceptosScript.construir_firma_patron(orden_a, orden_b)
	var firma_za: String = VincularConceptosScript.construir_firma_patron(orden_b, orden_a)
	_check(firma_az != firma_za, "[MatchShuffle] distinto orden => distinta firma")


func _test_match_firma_patron_contiene_ids() -> void:
	var izq: Array = [{"id": "x", "id_par": "par_x"}]
	var der: Array = [{"id": "y", "id_par": "par_x"}]
	var firma: String = VincularConceptosScript.construir_firma_patron(izq, der)
	_check("par_x" in firma, "[MatchShuffle] firma debe contener el id_par")


func _test_match_firma_patron_dos_pares() -> void:
	# El mínimo viable de pares es 2; la firma debe ser válida y distinguible.
	var pares_a: Array = [
		{"id": "a_iz", "id_par": "grupo_1"},
		{"id": "b_iz", "id_par": "grupo_2"},
	]
	var pares_b: Array = [
		{"id": "b_iz", "id_par": "grupo_2"},
		{"id": "a_iz", "id_par": "grupo_1"},
	]
	var firma_a: String = VincularConceptosScript.construir_firma_patron(pares_a, pares_b)
	var firma_b: String = VincularConceptosScript.construir_firma_patron(pares_b, pares_a)
	_check(not firma_a.is_empty(), "[MatchShuffle] 2 pares produce firma válida")
	_check(firma_a != firma_b, "[MatchShuffle] 2 pares: orden distinto => firma distinta")


# ===========================================================================
# Ejecutor de todos los tests de variación de patrones de vinculación
# ===========================================================================

func ejecutar_tests_vincular_variacion() -> void:
	print("[MatchShuffle] ── Iniciando tests de variación de patrones ──")
	_test_match_firma_patron_es_determinista()
	_test_match_firma_patron_cambia_con_orden()
	_test_match_firma_patron_contiene_ids()
	_test_match_firma_patron_dos_pares()
	if not failed:
		print("[MatchShuffle] ✓ Todos los tests pasaron.")
	else:
		printerr("[MatchShuffle] ✗ Al menos un test falló. Revisá los errores arriba.")


# ===========================================================================
# Tests unitarios: layout automático del mapa
# ===========================================================================

func ejecutar_tests_layout_del_mapa() -> void:
	print("[Layout] ── Iniciando tests de layout automático del mapa ──")
	_test_layout_json_tiene_route_id()
	_test_layout_json_nodos_sin_map_position()
	_test_layout_cargador_parsea_layout_config()
	_test_layout_route_registry_encuentra_ruta()
	_test_layout_path_layout_calcula_30_posiciones()
	_test_layout_resolver_calcula_posiciones()
	_test_layout_route_id_invalido_devuelve_vacio()
	_test_layout_cambiar_route_id_cambia_curva()
	_test_layout_ruta_real_tiene_suficientes_puntos()
	_test_layout_ruta2_existe_y_tiene_curva()
	_test_layout_placement_mode_anchors_en_json()
	_test_layout_anchors_posiciones_exactas_por_indice()
	_test_layout_anchors_fallback_curva_pequena()
	if not failed:
		print("[Layout] ✓ Todos los tests de layout pasaron.")
	else:
		printerr("[Layout] ✗ Al menos un test de layout falló.")


func _test_layout_json_tiene_route_id() -> void:
	var result := CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	_check(bool(result.get("ok", false)), "[Layout] CargadorDeMapa carga el mapa")
	var map_data: Dictionary = result.get("data", {})
	var layout_config = map_data.get("layout_config", null)
	_check(layout_config != null, "[Layout] CargadorDeMapa parsea layout_config")
	if layout_config == null:
		return
	_check(not layout_config.route_id.is_empty(), "[Layout] layout_config.route_id no esta vacio")
	_check(
		layout_config.route_id == "RutaCeliaquia1",
		"[Layout] route_id debe ser RutaCeliaquia1"
	)


func _test_layout_json_nodos_sin_map_position() -> void:
	var result := CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	if not bool(result.get("ok", false)):
		return
	var nodes_array: Array = result.get("data", {}).get("nodes", []) as Array
	for nd in nodes_array:
		if nd is MapNodeData and (nd as MapNodeData).has_map_position:
			var nkey: String = (nd as MapNodeData).node_key
			_check(false, "[Layout] Nodo v3 no debe tener map_position: %s" % nkey)
			return
	_check(true, "[Layout] Ningun nodo v3 tiene map_position")


func _test_layout_cargador_parsea_layout_config() -> void:
	var result := CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	var layout_config = result.get("data", {}).get("layout_config", null)
	_check(layout_config != null, "[Layout] layout_config no es null")
	if layout_config == null:
		return
	_check(layout_config is MapLayoutConfig, "[Layout] layout_config es MapLayoutConfig")
	_check(layout_config.is_valid(), "[Layout] layout_config.is_valid() == true")
	_check(layout_config.start_margin >= 0.0, "[Layout] start_margin >= 0")
	_check(layout_config.end_margin >= 0.0, "[Layout] end_margin >= 0")
	_check(layout_config.spacing_factor > 0.0, "[Layout] spacing_factor > 0")


func _test_layout_route_registry_encuentra_ruta() -> void:
	var contenido_test := Node2D.new()
	var ruta_test := Path2D.new()
	ruta_test.name = "RutaCeliaquia1"
	var curva_test := Curve2D.new()
	curva_test.add_point(Vector2(0, 0))
	curva_test.add_point(Vector2(500, 500))
	curva_test.add_point(Vector2(0, 1000))
	ruta_test.curve = curva_test
	contenido_test.add_child(ruta_test)
	var encontrada: Path2D = MAP_ROUTE_REGISTRY_SCRIPT.find_route(contenido_test, "RutaCeliaquia1")
	_check(encontrada != null, "[Layout] MapRouteRegistry encuentra RutaCeliaquia1")
	_check(encontrada is Path2D, "[Layout] La ruta encontrada es Path2D")
	_check(
		encontrada != null
			and encontrada.curve != null
			and encontrada.curve.get_baked_length() > 0.0,
		"[Layout] RutaCeliaquia1 tiene curva con baked_length > 0"
	)
	contenido_test.free()


func _test_layout_path_layout_calcula_30_posiciones() -> void:
	var result := CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	var layout_config = result.get("data", {}).get("layout_config", null)
	if layout_config == null:
		return
	var nodes_array: Array = result.get("data", {}).get("nodes", []) as Array
	var curva_test := Curve2D.new()
	curva_test.add_point(Vector2(0, 0))
	curva_test.add_point(Vector2(0, 3000))
	var posiciones: Array[Vector2] = MAP_PATH_LAYOUT_SCRIPT.calculate_positions(
		curva_test, 30, layout_config
	)
	_check(posiciones.size() == 30, "[Layout] MapPathLayout calcula 30 posiciones para 30 nodos")
	_check(
		posiciones.size() == nodes_array.size(),
		"[Layout] posiciones.size() == nodos.size() (%d)" % nodes_array.size()
	)


func _test_layout_resolver_calcula_posiciones() -> void:
	var result := CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	var layout_config = result.get("data", {}).get("layout_config", null)
	if layout_config == null:
		return
	var contenido_test := Node2D.new()
	var ruta_test := Path2D.new()
	ruta_test.name = "RutaCeliaquia1"
	var curva_test := Curve2D.new()
	curva_test.add_point(Vector2(0, 0))
	curva_test.add_point(Vector2(0, 3000))
	ruta_test.curve = curva_test
	contenido_test.add_child(ruta_test)
	var posiciones: Array[Vector2] = MAP_NODE_POSITION_RESOLVER_SCRIPT.resolve(
		contenido_test, layout_config, 30
	)
	_check(posiciones.size() == 30, "[Layout] MapNodePositionResolver resuelve 30 posiciones")
	contenido_test.free()


func _test_layout_route_id_invalido_devuelve_vacio() -> void:
	var config_invalida := MapLayoutConfig.new()
	config_invalida.route_id = "RutaQueNoExiste"
	var contenido_test := Node2D.new()
	var posiciones: Array[Vector2] = MAP_NODE_POSITION_RESOLVER_SCRIPT.resolve(
		contenido_test, config_invalida, 30
	)
	_check(posiciones.is_empty(), "[Layout] route_id invalido devuelve posiciones vacias")
	contenido_test.free()


func _test_layout_cambiar_route_id_cambia_curva() -> void:
	var contenido_test := Node2D.new()

	var ruta_1 := Path2D.new()
	ruta_1.name = "RutaCeliaquia1"
	var curva_1 := Curve2D.new()
	curva_1.add_point(Vector2(0, 0))
	curva_1.add_point(Vector2(0, 1000))
	ruta_1.curve = curva_1

	var ruta_2 := Path2D.new()
	ruta_2.name = "RutaCeliaquia2"
	var curva_2 := Curve2D.new()
	curva_2.add_point(Vector2(500, 0))
	curva_2.add_point(Vector2(500, 1000))
	ruta_2.curve = curva_2

	contenido_test.add_child(ruta_1)
	contenido_test.add_child(ruta_2)

	var config_1 := MapLayoutConfig.new()
	config_1.route_id = "RutaCeliaquia1"
	config_1.start_margin = 0.0
	config_1.end_margin = 0.0
	config_1.spacing_factor = 1.0

	var config_2 := MapLayoutConfig.new()
	config_2.route_id = "RutaCeliaquia2"
	config_2.start_margin = 0.0
	config_2.end_margin = 0.0
	config_2.spacing_factor = 1.0

	var pos_ruta_1: Array[Vector2] = MAP_NODE_POSITION_RESOLVER_SCRIPT.resolve(
		contenido_test, config_1, 2
	)
	var pos_ruta_2: Array[Vector2] = MAP_NODE_POSITION_RESOLVER_SCRIPT.resolve(
		contenido_test, config_2, 2
	)
	_check(pos_ruta_1.size() == 2, "[Layout] RutaCeliaquia1 resuelve 2 posiciones")
	_check(pos_ruta_2.size() == 2, "[Layout] RutaCeliaquia2 resuelve 2 posiciones")
	_check(
		pos_ruta_1[0] != pos_ruta_2[0],
		"[Layout] Cambiar route_id cambia las posiciones calculadas"
	)
	contenido_test.free()


const MAP_BOARD_SCENE_PATH := "res://mapas/MapBoard.tscn"

func _test_layout_ruta_real_tiene_suficientes_puntos() -> void:
	var map_board_scene: PackedScene = load(MAP_BOARD_SCENE_PATH)
	if map_board_scene == null:
		_check(false, "[Layout] MapBoard.tscn no se pudo cargar")
		return
	var board_instance: Node = map_board_scene.instantiate()
	if board_instance == null:
		_check(false, "[Layout] MapBoard.tscn no se pudo instanciar")
		return
	var contenido: Node = board_instance.get_node_or_null(
		"ScrollContainer/Contenido"
	)
	if contenido == null:
		board_instance.free()
		_check(false, "[Layout] ScrollContainer/Contenido no encontrado en MapBoard")
		return
	var ruta: Path2D = contenido.get_node_or_null("RutaCeliaquia1") as Path2D
	_check(ruta != null, "[Layout] RutaCeliaquia1 existe en MapBoard.tscn")
	if ruta == null:
		board_instance.free()
		return
	_check(ruta is Path2D, "[Layout] RutaCeliaquia1 es Path2D")
	_check(
		ruta.position.is_equal_approx(Vector2.ZERO),
		"[Layout] RutaCeliaquia1.position == Vector2.ZERO"
	)
	_check(
		ruta.scale.is_equal_approx(Vector2.ONE),
		"[Layout] RutaCeliaquia1.scale == Vector2.ONE"
	)
	_check(
		is_equal_approx(ruta.rotation, 0.0),
		"[Layout] RutaCeliaquia1.rotation == 0"
	)
	_check(ruta.curve != null, "[Layout] RutaCeliaquia1 tiene curva")
	if ruta.curve == null:
		board_instance.free()
		return
	_check(
		ruta.curve.point_count >= 30,
		"[Layout] RutaCeliaquia1.curve.point_count >= 30 (actual: %d)" % ruta.curve.point_count
	)
	_check(
		ruta.curve.get_baked_length() > 0.0,
		"[Layout] RutaCeliaquia1.curve.get_baked_length() > 0"
	)
	board_instance.free()


func _test_layout_ruta2_existe_y_tiene_curva() -> void:
	var map_board_scene: PackedScene = load(MAP_BOARD_SCENE_PATH)
	if map_board_scene == null:
		return
	var board_instance: Node = map_board_scene.instantiate()
	var contenido: Node = board_instance.get_node_or_null("ScrollContainer/Contenido")
	if contenido == null:
		board_instance.free()
		return
	var ruta2: Path2D = contenido.get_node_or_null("RutaCeliaquia2") as Path2D
	_check(ruta2 != null, "[Layout] RutaCeliaquia2 existe en MapBoard.tscn")
	if ruta2 != null:
		_check(ruta2.curve != null, "[Layout] RutaCeliaquia2 tiene curva")
		_check(
			ruta2.curve != null and ruta2.curve.get_baked_length() > 0.0,
			"[Layout] RutaCeliaquia2.curve.get_baked_length() > 0"
		)
	board_instance.free()


func _test_layout_placement_mode_anchors_en_json() -> void:
	var result := CARGADOR_DE_MAPA_SCRIPT.load_map("res://contenido/mapa/celiaquia_mapa.json")
	var layout_config: MapLayoutConfig = result.get("data", {}).get("layout_config", null)
	_check(
		layout_config != null,
		"[Layout] layout_config parseado desde JSON"
	)
	if layout_config == null:
		return
	_check(
		layout_config.usa_modo_anchors(),
		"[Layout] placement_mode == 'anchors' en celiaquia_mapa.json"
	)
	_check(
		layout_config.obtener_modo_posicionamiento() == "anchors",
		"[Layout] obtener_modo_posicionamiento() devuelve 'anchors'"
	)


func _test_layout_anchors_posiciones_exactas_por_indice() -> void:
	var curva := Curve2D.new()
	var puntos_esperados: Array[Vector2] = [
		Vector2(100, 200),
		Vector2(300, 400),
		Vector2(500, 100),
	]
	for p in puntos_esperados:
		curva.add_point(p)
	var posiciones: Array[Vector2] = MapPathLayout.calcular_posiciones_por_anchors(curva, 3)
	_check(
		posiciones.size() == 3,
		"[Layout] anchors devuelve 3 posiciones para curva de 3 puntos"
	)
	for i in range(posiciones.size()):
		_check(
			posiciones[i].is_equal_approx(puntos_esperados[i]),
			"[Layout] anchors: nodo %d en punto exacto %s" % [i + 1, puntos_esperados[i]]
		)


func _test_layout_anchors_fallback_curva_pequena() -> void:
	var curva := Curve2D.new()
	curva.add_point(Vector2(0, 0))
	curva.add_point(Vector2(0, 1000))
	# Curva con 2 puntos, pedimos 5 nodos: debe usar fallback sample_baked.
	var posiciones: Array[Vector2] = MapPathLayout.calcular_posiciones_por_anchors(curva, 5)
	_check(
		posiciones.size() == 5,
		"[Layout] anchors fallback: devuelve 5 posiciones con curva de 2 puntos"
	)
