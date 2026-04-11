extends SceneTree

var SaveManager
var Global
var failed := false

const TEST_CASES := [
	{
		"scene_path": "res://niveles/nivel_1/Level.tscn",
		"track_key": "celiaquia"
	},
	{
		"scene_path": "res://niveles/nivel_2/level_vegan.tscn",
		"track_key": "veganismo"
	},
	{
		"scene_path": "res://niveles/nivel_3/Level-Vegan-GF.tscn",
		"track_key": "veganismo_celiaquia"
	},
	{
		"scene_path": "res://niveles/nivel_4/Level-Keto.tscn",
		"track_key": "cetogenica"
	}
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_resolve_singletons()
	_assert(SaveManager != null, "No se encontro el autoload SaveManager")
	_assert(Global != null, "No se encontro el autoload Global")
	if failed:
		quit(1)
		return
	_cleanup_test_files()
	await process_frame
	for test_case in TEST_CASES:
		_cleanup_test_files()
		await process_frame
		await _run_quick_save_case(test_case)
		if failed:
			break

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _run_quick_save_case(test_case: Dictionary) -> void:
	SaveManager.load_data()
	Global.current_level = 2
	var track_key := str(test_case.get("track_key", "")).strip_edges()
	var scene_path := str(test_case.get("scene_path", "")).strip_edges()
	var case_label := "%s (%s)" % [track_key, scene_path]
	print("LEVEL QUICK SAVE TRACE: start %s" % case_label)
	var expected_run_count: int = max(1, Global.get_chapter_run_count(track_key, Global.current_level))
	var level_scene: PackedScene = load(scene_path) as PackedScene
	_assert(level_scene != null, "No se pudo cargar la escena %s para el test de guardado rapido" % case_label)
	if level_scene == null:
		return

	var level_instance: Node = level_scene.instantiate()
	root.add_child(level_instance)
	await process_frame
	_disable_level_audio(level_instance)

	var save_button := level_instance.get_node_or_null("SaveProgressButton") as Button
	var save_feedback_backdrop := level_instance.get_node_or_null("SaveFeedbackBackdrop") as PanelContainer
	var save_feedback_title := level_instance.get_node_or_null("SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackTitle") as Label
	var save_feedback_label := level_instance.get_node_or_null("SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackLabel") as Label
	var manager_level = level_instance.get_node_or_null("ManagerLevel")
	var plato = level_instance.get_node_or_null("Plato")

	_assert(save_button != null, "%s deberia exponer un boton de guardado rapido" % case_label)
	_assert(save_feedback_backdrop != null, "%s deberia exponer una tarjeta visual para el guardado local" % case_label)
	_assert(save_feedback_title != null, "%s deberia exponer un titulo visible para el feedback de guardado" % case_label)
	_assert(save_feedback_label != null, "%s deberia exponer feedback visible al guardar" % case_label)
	_assert(manager_level != null, "%s deberia exponer el ManagerLevel para armar el escenario de prueba" % case_label)
	_assert(plato != null, "%s deberia exponer el Plato para restaurar el guardado parcial" % case_label)
	if save_button == null or save_feedback_backdrop == null or save_feedback_title == null or save_feedback_label == null or manager_level == null or plato == null:
		level_instance.queue_free()
		await process_frame
		return
	_assert(str(manager_level.current_track_key) == track_key, "%s deberia inicializar ManagerLevel con el track correcto" % case_label)
	_assert(not (manager_level.current_run_data as Dictionary).is_empty(), "%s deberia cargar una corrida valida al iniciar la escena" % case_label)

	_assert(save_feedback_backdrop.clip_contents, "%s deberia contener visualmente el texto dentro del panel" % case_label)
	_assert(save_feedback_backdrop.is_ancestor_of(save_feedback_title), "%s deberia montar el titulo dentro de la tarjeta visual" % case_label)
	_assert(save_feedback_backdrop.is_ancestor_of(save_feedback_label), "%s deberia montar el detalle dentro de la tarjeta visual" % case_label)
	_assert(save_button.tooltip_text.contains("Guardar"), "%s deberia explicar la funcion del guardado rapido" % case_label)
	_assert(int(manager_level.get_total_runs()) == expected_run_count, "%s deberia exponer la cantidad de corridas definida para el capitulo actual" % case_label)

	var positive_item = null
	for item in manager_level.lista_items:
		if item.esPositivo:
			positive_item = item
			break
	_assert(positive_item != null, "%s deberia exponer al menos un item positivo para simular un guardado parcial" % case_label)
	if positive_item == null:
		level_instance.queue_free()
		await process_frame
		return

	positive_item.restore_to_plate(plato.global_position)
	plato.restore_positive_item(positive_item)
	save_button.emit_signal("pressed")
	await process_frame
	var first_run_state: Dictionary = Global.get_partial_level_state(track_key, Global.current_level)
	print("LEVEL QUICK SAVE TRACE: first save %s run=%d placed=%d" % [case_label, int(first_run_state.get("run_index", 0)), first_run_state.get("placed_item_ids", []).size()])

	_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "%s deberia escribir el save principal" % case_label)
	_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "manual_save", "%s deberia registrarse como guardado manual" % case_label)
	_assert(save_feedback_label.text.to_lower().contains("guardado"), "%s deberia informar que el progreso quedo guardado" % case_label)
	_assert(save_feedback_backdrop.visible, "%s deberia mostrar el feedback dentro de una tarjeta visible" % case_label)
	_assert(save_feedback_title.text.contains("Guardado"), "%s deberia tener un titulo descriptivo para el feedback" % case_label)
	_assert(save_feedback_label.text.contains("plato"), "%s deberia informar cuantas comidas quedaron dentro del plato" % case_label)
	_assert(first_run_state.get("placed_item_ids", []).size() == 1, "%s deberia persistir la comida correcta ya colocada" % case_label)
	_assert(int(first_run_state.get("run_index", 0)) == 1, "%s deberia persistir que el guardado pertenece a la primera corrida" % case_label)
	_assert(str(first_run_state.get("mechanic_type", "")) == "plate_sort", "%s deberia persistir la mecanica activa del capitulo" % case_label)
	_assert((first_run_state.get("mechanic_state", {}) as Dictionary).has("placed_item_ids"), "%s deberia encapsular el estado parcial de la mecanica" % case_label)
	if expected_run_count > 1:
		_assert(save_feedback_label.text.contains("Corrida 1 de"), "%s deberia informar la corrida actual en el guardado rapido" % case_label)

	level_instance.queue_free()
	await process_frame

	Global.reset_progress()
	var resume_state: Dictionary = SaveManager.load_progress_and_get_resume_state()
	print("LEVEL QUICK SAVE TRACE: first reload %s context=%s level=%d" % [case_label, str(resume_state.get("context", "")), int(resume_state.get("level_number", 0))])
	_assert(str(resume_state.get("context", "")) == SaveManager.RESUME_CONTEXT_LEVEL, "%s deberia mantener la reanudacion dentro del nivel" % case_label)
	_assert(str(resume_state.get("track_key", "")) == track_key, "%s deberia reanudar el track correcto" % case_label)
	_assert(str(resume_state.get("scene_path", "")) == scene_path, "%s deberia reanudar en la escena correcta" % case_label)
	_assert(int(resume_state.get("level_number", 0)) == 2, "%s deberia seguir apuntando al capitulo actual" % case_label)

	var restored_level_instance: Node = level_scene.instantiate()
	root.add_child(restored_level_instance)
	await process_frame
	_disable_level_audio(restored_level_instance)
	var restored_plato = restored_level_instance.get_node_or_null("Plato")
	var restored_manager_level = restored_level_instance.get_node_or_null("ManagerLevel")
	var restored_save_button = restored_level_instance.get_node_or_null("SaveProgressButton") as Button
	_assert(restored_plato != null, "%s deberia exponer el Plato al recargar el guardado" % case_label)
	_assert(restored_manager_level != null, "%s deberia exponer el ManagerLevel al recargar el guardado" % case_label)
	if restored_plato != null:
		_assert(restored_plato.cantAlimentosPos.keys().size() == 1, "%s deberia restaurar la comida correcta dentro del plato" % case_label)
	if restored_manager_level != null:
		_assert(int(restored_manager_level.get_current_run_index()) == 1, "%s deberia restaurar la primera corrida antes de completarla" % case_label)
	print("LEVEL QUICK SAVE TRACE: restored first run %s plate=%d run=%d" % [case_label, restored_plato.cantAlimentosPos.keys().size() if restored_plato != null else -1, int(restored_manager_level.get_current_run_index()) if restored_manager_level != null else -1])

	if expected_run_count > 1 and restored_manager_level != null and restored_save_button != null:
		_assert(restored_manager_level.advance_to_next_run(), "%s deberia poder avanzar a la segunda corrida" % case_label)
		restored_save_button.emit_signal("pressed")
		await process_frame
		var second_run_state: Dictionary = Global.get_partial_level_state(track_key, Global.current_level)
		print("LEVEL QUICK SAVE TRACE: second save %s run=%d placed=%d" % [case_label, int(second_run_state.get("run_index", 0)), second_run_state.get("placed_item_ids", []).size()])
		_assert(int(second_run_state.get("run_index", 0)) == 2, "%s deberia persistir la segunda corrida al guardar de nuevo" % case_label)
	restored_level_instance.queue_free()
	await process_frame

	if expected_run_count > 1:
		Global.reset_progress()
		var second_resume_state: Dictionary = SaveManager.load_progress_and_get_resume_state()
		print("LEVEL QUICK SAVE TRACE: second reload %s context=%s level=%d" % [case_label, str(second_resume_state.get("context", "")), int(second_resume_state.get("level_number", 0))])
		_assert(int(second_resume_state.get("level_number", 0)) == 2, "%s deberia seguir reanudando el mismo capitulo mientras queden corridas pendientes" % case_label)
		var second_restored_level_instance: Node = level_scene.instantiate()
		root.add_child(second_restored_level_instance)
		await process_frame
		_disable_level_audio(second_restored_level_instance)
		var second_restored_manager_level = second_restored_level_instance.get_node_or_null("ManagerLevel")
		_assert(second_restored_manager_level != null, "%s deberia recargar el ManagerLevel en la segunda corrida" % case_label)
		if second_restored_manager_level != null:
			print("LEVEL QUICK SAVE TRACE: restored second run %s run=%d" % [case_label, int(second_restored_manager_level.get_current_run_index())])
			_assert(int(second_restored_manager_level.get_current_run_index()) == 2, "%s deberia retomar exactamente la corrida pendiente" % case_label)
		second_restored_level_instance.queue_free()
		await process_frame


func _resolve_singletons() -> void:
	if SaveManager == null:
		SaveManager = root.get_node_or_null("/root/SaveManager")
	if Global == null:
		Global = root.get_node_or_null("/root/Global")


func _cleanup_test_files() -> void:
	Global.reset_progress()
	for relative_path in [
		SaveManager.SAVE_PATH,
		SaveManager.TEMP_SAVE_PATH,
		SaveManager.BACKUP_SAVE_PATH
	]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	SaveManager.load_data()


func _disable_level_audio(level_instance: Node) -> void:
	var background_player := level_instance.get_node_or_null("Background") as AudioStreamPlayer2D
	if background_player == null:
		return
	background_player.stop()
	background_player.stream = null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("LEVEL QUICK SAVE TEST FAILED: %s" % message)
