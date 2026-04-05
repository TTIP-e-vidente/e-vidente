extends SceneTree

var SaveManager
var Global
var failed := false


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

	SaveManager.load_data()
	var level_scene: PackedScene = load("res://niveles/nivel_1/Level.tscn") as PackedScene
	_assert(level_scene != null, "No se pudo cargar la escena del nivel para el test de guardado rapido")
	if level_scene != null:
		var level_instance: Node = level_scene.instantiate()
		root.add_child(level_instance)
		await process_frame

		var save_button: Button = level_instance.get_node("SaveProgressButton")
		var save_feedback_label: Label = level_instance.get_node("SaveFeedbackLabel")

		_assert(save_button != null, "El nivel deberia exponer un boton de guardado rapido")
		_assert(save_feedback_label != null, "El nivel deberia exponer feedback visible al guardar")
		_assert(save_button.tooltip_text.contains("Guardar"), "El boton de guardado rapido deberia explicar su funcion")

		if save_button != null:
			save_button.emit_signal("pressed")
			await process_frame

		_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "El guardado rapido del nivel deberia escribir el save principal")
		_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "manual_save", "El guardado rapido del nivel deberia registrarse como guardado manual")
		_assert(save_feedback_label.text.contains("guardado"), "El nivel deberia informar que el progreso quedo guardado")

		level_instance.queue_free()

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


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


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("LEVEL QUICK SAVE TEST FAILED: %s" % message)