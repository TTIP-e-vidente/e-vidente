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

	var keto_scene: PackedScene = load("res://interface/Libro-Keto.tscn") as PackedScene
	_assert(keto_scene != null, "No se pudo cargar el libro de keto")
	if keto_scene != null:
		var keto_instance: Node = keto_scene.instantiate()
		root.add_child(keto_instance)
		await process_frame

		var cap_1 := keto_instance.get_node_or_null("VBoxContainer/Cap1") as Button
		_assert(cap_1 != null, "El libro de keto deberia exponer el acceso al capitulo 1")
		if cap_1 != null:
			cap_1.emit_signal("pressed")
			await process_frame
			await process_frame
			_assert(Global.current_level == 1, "Capitulo 1 de keto deberia fijar el nivel actual en 1")
			_assert(current_scene != null, "Capitulo 1 de keto deberia abrir una escena jugable")
			if current_scene != null:
				_assert(current_scene.scene_file_path == "res://niveles/nivel_4/Level-Keto.tscn", "Capitulo 1 de keto deberia abrir el nivel de keto")
				var manager_level = current_scene.get_node_or_null("ManagerLevel")
				var expected_book: Dictionary = Global.items_segun_track("cetogenica")
				_assert(manager_level != null, "El nivel de keto deberia exponer el ManagerLevel")
				_assert(not expected_book.is_empty(), "Keto deberia resolver su track de progreso")
				if manager_level != null and not expected_book.is_empty():
					_assert(manager_level.nivelActual == expected_book, "Capitulo 1 de keto no deberia reutilizar los datos de otro modo")

		if current_scene != null:
			current_scene.queue_free()
			await process_frame
		elif is_instance_valid(keto_instance):
			keto_instance.queue_free()
			await process_frame

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
	printerr("KETO BOOK TEST FAILED: %s" % message)
